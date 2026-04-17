class_name World
extends Node3D

const CHUNK_SIZE: int = Chunk.SIZE
const MAX_REACH: float = 8.0

# Flatgrass is a thin 5-block slab regardless of world size: 1 bedrock at y=0,
# 3 dirt at y=1..3, 1 grass at y=4. Everything above is air so the full
# `world_size_blocks` vertical is available for building.
const FLATGRASS_GROUND: int = 4

# Non-flatgrass terrain on worlds ≥128 blocks is capped to the bottom 64
# blocks. The rest of the vertical (up to `world_size_blocks`) is the build
# range — empty chunks are only instantiated when the player actually places
# blocks up there.
const LARGE_WORLD_THRESHOLD: int = 128
const LARGE_WORLD_TERRAIN_BASE: int = 20  # max terrain y ≈ base + 14 = 34

enum TerrainType { FLATGRASS, VANILLA_DEFAULT, VANILLA_HILLY }

# Dynamic world size — can be changed via regenerate()
var world_size_blocks: int = 64
var world_size_chunks: int = 4
# World seed — reproducible generation. 0 = pick random at startup.
var world_seed: int = 0

var chunks: Dictionary = {}  # Dictionary[Vector3i, Chunk]
var noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var material: ShaderMaterial
var water_material: ShaderMaterial
var current_terrain_type: int = TerrainType.VANILLA_DEFAULT

var particle_system: ParticleSystem = null
var _bounds_body: StaticBody3D = null

signal generation_progress(progress: float, status: String)


func _ready() -> void:
	_setup_material()
	particle_system = get_parent().get_node_or_null("ParticleSystem") as ParticleSystem
	world_seed = _random_seed()
	ChunkGen.configure_noise(noise, biome_noise, world_seed, TerrainType.VANILLA_DEFAULT)
	_generate_world(TerrainType.VANILLA_DEFAULT)
	_setup_world_bounds()
	set_process(true)


static func _random_seed() -> int:
	var s: int = randi()
	if s == 0:
		s = 1
	return s


## Build (or rebuild) 4 invisible static colliders that fence the playable
## area to [0, world_size_blocks] on the X and Z axes. The walls extend the
## full world height so the player cannot escape no matter how high they go.
func _setup_world_bounds() -> void:
	if _bounds_body != null:
		_bounds_body.queue_free()
		_bounds_body = null
	_bounds_body = StaticBody3D.new()
	_bounds_body.name = "WorldBounds"
	add_child(_bounds_body)

	var size: float = float(world_size_blocks)
	var height: float = float(world_size_blocks)
	var thickness: float = 1.0
	var center_y: float = height * 0.5

	# Each entry: (center_x, center_z, size_x, size_z)
	var walls: Array = [
		[-thickness * 0.5,        size * 0.5,             thickness, size + thickness * 2.0],  # west
		[size + thickness * 0.5,  size * 0.5,             thickness, size + thickness * 2.0],  # east
		[size * 0.5,             -thickness * 0.5,        size + thickness * 2.0, thickness],  # north
		[size * 0.5,              size + thickness * 0.5, size + thickness * 2.0, thickness],  # south
	]
	for w: Array in walls:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w[2], height, w[3])
		cs.shape = box
		cs.position = Vector3(w[0], center_y, w[1])
		_bounds_body.add_child(cs)


## Configure a pair of noise instances (terrain + biome) for a given seed and
## terrain type. Static so worker threads can spin up their own thread-local
## noise instances from the same world_seed.
static func _configure_noise(t_noise: FastNoiseLite, b_noise: FastNoiseLite, seed: int, terrain_type: int) -> void:
	t_noise.seed = seed
	t_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	t_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	t_noise.fractal_lacunarity = 2.0
	t_noise.fractal_gain = 0.5
	if terrain_type == TerrainType.VANILLA_HILLY:
		t_noise.frequency = 0.02
		t_noise.fractal_octaves = 4
	else:
		t_noise.frequency = 0.012
		t_noise.fractal_octaves = 3
	b_noise.seed = seed ^ 0x5A5A5A5A
	b_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	b_noise.frequency = 0.015


func _setup_material() -> void:
	var shader := load("res://voxel.gdshader") as Shader
	material = ShaderMaterial.new()
	material.shader = shader
	var atlas: ImageTexture = BlockTextures.create_atlas()
	material.set_shader_parameter("block_atlas", atlas)

	var water_shader := load("res://water.gdshader") as Shader
	water_material = ShaderMaterial.new()
	water_material.shader = water_shader


## Rebuild the atlas and push it to the shader. Called when the mipmap
## setting toggles — invalidates BlockTextures' cache so the new preference
## takes effect. The hotbar and inventory will pick up the new atlas on
## their next draw because they call `create_atlas()` at `_ready()`; if
## mipmaps toggle mid-session the UI keeps the old atlas reference until
## the scene reloads. (This is rare enough not to wire live.)
func refresh_atlas() -> void:
	BlockTextures.invalidate_cache()
	var atlas: ImageTexture = BlockTextures.create_atlas()
	if material != null:
		material.set_shader_parameter("block_atlas", atlas)


static func _sample_terrain_height(t_noise: FastNoiseLite, wx: int, wz: int, terrain_type: int, world_size: int) -> int:
	var n: float = t_noise.get_noise_2d(float(wx), float(wz))
	var height: int
	if terrain_type == TerrainType.VANILLA_HILLY:
		# 8..48 — already fits in the bottom 64 blocks for any world size.
		height = int((n + 1.0) * 0.5 * 40.0) + 8
	else:
		# Default terrain: keep the bottom 64 blocks as "world" on big builds.
		# Previously base scaled with world_size (~size/3), which made 512³
		# worlds mostly underground. Now for size ≥128 we pin base to a
		# constant so terrain always occupies y=20..34.
		var base: int
		if world_size >= LARGE_WORLD_THRESHOLD:
			base = LARGE_WORLD_TERRAIN_BASE
		else:
			base = maxi(20, world_size / 3)
		height = int((n + 1.0) * 0.5 * 14.0) + base
	return clampi(height, 1, world_size - 2)


func get_terrain_height(wx: int, wz: int) -> int:
	return _sample_terrain_height(noise, wx, wz, current_terrain_type, world_size_blocks)


# Biome IDs
const BIOME_PLAINS: int = 0
const BIOME_BEACH: int = 1


static func _sample_biome(b_noise: FastNoiseLite, wx: int, wz: int) -> int:
	var b: float = b_noise.get_noise_2d(float(wx), float(wz))
	return BIOME_BEACH if b > 0.35 else BIOME_PLAINS


func get_biome(wx: int, wz: int) -> int:
	return _sample_biome(biome_noise, wx, wz)


## Find the highest solid block at the center of the world and return the
## spawn position directly on top of it.
func find_spawn_position() -> Vector3:
	var cx: int = world_size_blocks / 2
	var cz: int = world_size_blocks / 2
	for wy: int in range(world_size_blocks - 1, -1, -1):
		if get_voxel(cx, wy, cz) != Chunk.Block.AIR:
			return Vector3(float(cx) + 0.5, float(wy + 1) + 0.05, float(cz) + 0.5)
	return Vector3(float(cx) + 0.5, float(world_size_blocks) - 1.0, float(cz) + 0.5)


func get_voxel(wx: int, wy: int, wz: int) -> int:
	# Bitwise OR catches all three negatives in one branch.
	var size: int = world_size_blocks
	if (wx | wy | wz) < 0 or wx >= size or wy >= size or wz >= size:
		return 0  # Chunk.Block.AIR
	var chunk: Chunk = chunks.get(Vector3i(wx >> 4, wy >> 4, wz >> 4))
	if chunk == null:
		return 0
	# Inline the chunk voxel lookup to skip a method call and bounds recheck
	return chunk.voxels[(wx & 15) + ((wy & 15) << 4) + ((wz & 15) << 8)]


func get_water_level_at(wx: int, wy: int, wz: int) -> int:
	var size: int = world_size_blocks
	if (wx | wy | wz) < 0 or wx >= size or wy >= size or wz >= size:
		return 0
	var chunk: Chunk = chunks.get(Vector3i(wx >> 4, wy >> 4, wz >> 4))
	if chunk == null:
		return 0
	return chunk.water_level[(wx & 15) + ((wy & 15) << 4) + ((wz & 15) << 8)]


func set_voxel(wx: int, wy: int, wz: int, block_type: int) -> void:
	if wx < 0 or wx >= world_size_blocks or wy < 0 or wy >= world_size_blocks or wz < 0 or wz >= world_size_blocks:
		return
	var cp := Vector3i(wx >> 4, wy >> 4, wz >> 4)
	# Create chunk on demand if it doesn't exist (e.g., building above terrain).
	var chunk: Chunk = _ensure_chunk(cp)
	chunk.set_voxel(wx & 15, wy & 15, wz & 15, block_type)

	# AO reads diagonal neighbors, so any face within a 3x3x3 neighborhood of
	# the changed block may need re-lighting. Dispatch to up to 8 chunks for
	# corner edits and rebuild each affected chunk's mesh exactly once.
	var affected: Dictionary = {}  # Vector3i(chunk) -> Array[Vector3i(local)]
	var size: int = world_size_blocks
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var x: int = wx + dx
				var y: int = wy + dy
				var z: int = wz + dz
				if x < 0 or y < 0 or z < 0 or x >= size or y >= size or z >= size:
					continue
				var ncp := Vector3i(x >> 4, y >> 4, z >> 4)
				if not chunks.has(ncp):
					continue
				var lp := Vector3i(x & 15, y & 15, z & 15)
				if affected.has(ncp):
					affected[ncp].append(lp)
				else:
					affected[ncp] = [lp]

	for acp: Vector3i in affected:
		var ac: Chunk = chunks[acp]
		# If this chunk's visible mesh is a foreign (shared) ArrayMesh — set up
		# by the flatgrass fast path — materialize its own independent mesh
		# before editing, so edits don't leak to siblings sharing the source.
		# The full rebuild already reflects the new voxel state, so skip the
		# incremental face rebuild for this chunk.
		if ac.mesh != ac._arr_mesh:
			_detach_shared_mesh(ac)
			continue
		var locals: Array = affected[acp]
		for lp: Vector3i in locals:
			ac._rebuild_block_faces(lp.x, lp.y, lp.z)
		ac._apply_mesh()


## Rebuild a chunk's own mesh from its current voxels and point `chunk.mesh`
## back at `chunk._arr_mesh`. Used when a chunk needs to leave the flatgrass
## shared-mesh pool (e.g. on first edit).
func _detach_shared_mesh(chunk: Chunk) -> void:
	chunk._padded = _build_padded(chunk)
	chunk._use_padded = true
	chunk.generate_mesh(material, water_material)
	chunk._use_padded = false
	chunk._padded = PackedByteArray()


## DDA voxel raycast. Expects `direction` already normalized.
## Reuses a shared result dict to avoid per-call allocation.
var _raycast_result: Dictionary = {"position": Vector3i.ZERO, "normal": Vector3i.ZERO, "block": 0, "hit": false}

func raycast_voxel(origin: Vector3, direction: Vector3, max_dist: float = MAX_REACH) -> Dictionary:
	# Assumes direction is already normalized (camera basis is).
	var x: int = floori(origin.x)
	var y: int = floori(origin.y)
	var z: int = floori(origin.z)
	var dx: float = direction.x
	var dy: float = direction.y
	var dz: float = direction.z
	var step_x: int = 1 if dx >= 0.0 else -1
	var step_y: int = 1 if dy >= 0.0 else -1
	var step_z: int = 1 if dz >= 0.0 else -1
	var t_delta_x: float = 1e30 if absf(dx) < 1e-10 else absf(1.0 / dx)
	var t_delta_y: float = 1e30 if absf(dy) < 1e-10 else absf(1.0 / dy)
	var t_delta_z: float = 1e30 if absf(dz) < 1e-10 else absf(1.0 / dz)

	var t_max_x: float = ((float(x + 1) - origin.x) if dx >= 0.0 else (origin.x - float(x))) * t_delta_x
	var t_max_y: float = ((float(y + 1) - origin.y) if dy >= 0.0 else (origin.y - float(y))) * t_delta_y
	var t_max_z: float = ((float(z + 1) - origin.z) if dz >= 0.0 else (origin.z - float(z))) * t_delta_z

	var face_x: int = 0
	var face_y: int = 0
	var face_z: int = 0
	var max_steps: int = int(max_dist * 3.0) + 1
	var size: int = world_size_blocks

	for _i: int in max_steps:
		# Inlined bounds check + voxel lookup (hottest path)
		if (x | y | z) >= 0 and x < size and y < size and z < size:
			var chunk: Chunk = chunks.get(Vector3i(x >> 4, y >> 4, z >> 4))
			if chunk != null:
				var block: int = chunk.voxels[(x & 15) + ((y & 15) << 4) + ((z & 15) << 8)]
				# Fluids are transparent to raycasts — you target the block
				# behind them. Fire, poppies, and dandelions ARE hittable so
				# the player can break them; their full-cell hit position
				# gives them a full-block selection outline as in ClassiCube.
				if block != 0 and block != Chunk.Block.WATER \
					and block != Chunk.Block.LAVA:
					_raycast_result["position"] = Vector3i(x, y, z)
					_raycast_result["normal"] = Vector3i(face_x, face_y, face_z)
					_raycast_result["block"] = block
					_raycast_result["hit"] = true
					return _raycast_result

		if t_max_x < t_max_y:
			if t_max_x < t_max_z:
				if t_max_x > max_dist:
					break
				x += step_x
				t_max_x += t_delta_x
				face_x = -step_x
				face_y = 0
				face_z = 0
			else:
				if t_max_z > max_dist:
					break
				z += step_z
				t_max_z += t_delta_z
				face_x = 0
				face_y = 0
				face_z = -step_z
		else:
			if t_max_y < t_max_z:
				if t_max_y > max_dist:
					break
				y += step_y
				t_max_y += t_delta_y
				face_x = 0
				face_y = -step_y
				face_z = 0
			else:
				if t_max_z > max_dist:
					break
				z += step_z
				t_max_z += t_delta_z
				face_x = 0
				face_y = 0
				face_z = -step_z

	_raycast_result["hit"] = false
	return _raycast_result


# Helper: did the last raycast actually hit something?
func raycast_hit(result: Dictionary) -> bool:
	return result.get("hit", false)


func break_block(origin: Vector3, direction: Vector3) -> bool:
	var hit: Dictionary = raycast_voxel(origin, direction)
	if not hit.get("hit", false):
		return false
	var block: int = hit["block"]
	# World bedrock at the bottom of the world is unbreakable.
	if block == Chunk.Block.WORLD_BEDROCK:
		return false
	var pos: Vector3i = hit["position"]
	if particle_system != null:
		particle_system.spawn_break_burst(Vector3(pos) + Vector3(0.5, 0.5, 0.5), block)
	set_voxel(pos.x, pos.y, pos.z, Chunk.Block.AIR)
	# Breaking a log can orphan nearby natural leaves — schedule them for
	# decay. Placed leaves (water_level[idx] == 1) are skipped by the
	# scheduler, so the check is safe.
	if block == Chunk.Block.LOG:
		_schedule_leaf_decay_around(pos)
	# Wake up any adjacent flowing fluid that can still spread into the
	# newly-opened air cell.
	const NEIGHBORS: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	for off: Vector3i in NEIGHBORS:
		var np: Vector3i = pos + off
		var nb: int = get_voxel(np.x, np.y, np.z)
		if nb != Chunk.Block.WATER and nb != Chunk.Block.LAVA:
			continue
		var n_lvl: int = get_water_level_at(np.x, np.y, np.z)
		if n_lvl <= 0:
			n_lvl = 1
		if n_lvl < 8:
			if nb == Chunk.Block.WATER:
				_water_pending.append(np)
			else:
				_lava_pending.append(np)
	return true


func place_block(origin: Vector3, direction: Vector3, block_type: int, player_aabb: AABB) -> bool:
	var hit: Dictionary = raycast_voxel(origin, direction)
	if not hit.get("hit", false):
		return false
	# Slab-on-slab merge: placing a slab while looking at another slab's top
	# face upgrades the existing slab into a full smooth-stone block rather
	# than placing a new slab in the air cell above.
	var hit_pos: Vector3i = hit["position"]
	var hit_block: int = hit["block"]
	var hit_normal: Vector3i = hit["normal"]
	if block_type == Chunk.Block.SMOOTH_STONE_SLAB \
		and hit_block == Chunk.Block.SMOOTH_STONE_SLAB \
		and hit_normal == Vector3i(0, 1, 0):
		set_voxel(hit_pos.x, hit_pos.y, hit_pos.z, Chunk.Block.SMOOTH_STONE)
		return true
	var place_pos: Vector3i = hit_pos + hit_normal
	if place_pos.x < 0 or place_pos.x >= world_size_blocks:
		return false
	if place_pos.y < 0 or place_pos.y >= world_size_blocks:
		return false
	if place_pos.z < 0 or place_pos.z >= world_size_blocks:
		return false
	# Allow placing on top of any "displaceable" content — air, fluids, fire,
	# or plants. The placed block replaces whatever was there.
	var existing: int = get_voxel(place_pos.x, place_pos.y, place_pos.z)
	if existing != Chunk.Block.AIR and existing != Chunk.Block.WATER \
		and existing != Chunk.Block.LAVA and existing != Chunk.Block.FIRE \
		and existing != Chunk.Block.POPPY and existing != Chunk.Block.DANDELION:
		return false
	# Prevent trapping the player inside a solid block; water is non-collidable
	# so placing water on the player is fine.
	if block_type != Chunk.Block.WATER:
		var block_aabb := AABB(Vector3(place_pos), Vector3.ONE)
		if player_aabb.intersects(block_aabb):
			return false
	# If the placed block is replacing an existing FLUID cell, seed a
	# retract: queue that cell's fluid neighbors so the next tick re-checks
	# their upstream. Flow cells that lose their chain back to a source
	# will evaporate one layer at a time in _tick_fluid.
	if existing == Chunk.Block.WATER or existing == Chunk.Block.LAVA:
		_seed_fluid_retract(place_pos, existing)
	if block_type == Chunk.Block.WATER:
		set_water_voxel(place_pos.x, place_pos.y, place_pos.z, 1)
		_water_pending.append(place_pos)
	elif block_type == Chunk.Block.LAVA:
		set_lava_voxel(place_pos.x, place_pos.y, place_pos.z, 1)
		_lava_pending.append(place_pos)
	elif block_type == Chunk.Block.TNT:
		# TNT detonates instantly on placement — never actually occupies the
		# voxel, so there's no primed-block stage. Creates a small radius
		# crater and spawns break particles for feedback.
		_explode(place_pos, 3)
	else:
		set_voxel(place_pos.x, place_pos.y, place_pos.z, block_type)
		# Tag player-placed leaves so the decay ticker leaves them alone.
		# water_level is unused by non-fluids, so we repurpose it as a
		# 1-byte "placed" flag just for LEAVES.
		if block_type == Chunk.Block.LEAVES:
			var cp := Vector3i(place_pos.x >> 4, place_pos.y >> 4, place_pos.z >> 4)
			var chunk: Chunk = chunks.get(cp)
			if chunk != null:
				var idx: int = (place_pos.x & 15) + ((place_pos.y & 15) << 4) + ((place_pos.z & 15) << 8)
				chunk.water_level[idx] = 1
	return true


## Delete every breakable block within Chebyshev-radius `radius` of `center`
## (cube neighborhood). Spawns particles for each destroyed block so the
## explosion reads visually. Unbreakable blocks (WORLD_BEDROCK) survive.
func _explode(center: Vector3i, radius: int) -> void:
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			for dz: int in range(-radius, radius + 1):
				var p: Vector3i = center + Vector3i(dx, dy, dz)
				if p.x < 0 or p.y < 0 or p.z < 0:
					continue
				if p.x >= world_size_blocks or p.y >= world_size_blocks or p.z >= world_size_blocks:
					continue
				var b: int = get_voxel(p.x, p.y, p.z)
				if b == Chunk.Block.AIR or b == Chunk.Block.WORLD_BEDROCK:
					continue
				if particle_system != null:
					particle_system.spawn_break_burst(Vector3(p) + Vector3(0.5, 0.5, 0.5), b)
				# Water sources caught in the blast drain their flow too.
				if b == Chunk.Block.WATER:
					var lvl: int = get_water_level_at(p.x, p.y, p.z)
					if lvl <= 1:
						_drain_water_component(p)
						continue
				set_voxel(p.x, p.y, p.z, Chunk.Block.AIR)


# --- Water flow ---

const WATER_TICK_INTERVAL: float = 0.25  # 4 blocks/sec = 0.25s per step
var _water_accumulator: float = 0.0
var _water_pending: Array[Vector3i] = []  # positions waiting to spread outward


## Flood-fill the fluid component containing `start` and, if `start` is the
## only level-1 source in it, remove every connected cell. Works for both
## water and lava — pass the fluid type to constrain the flood-fill.
func _drain_fluid_component(start: Vector3i, fluid: int) -> void:
	const NBRS: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	var visited: Dictionary = {start: true}
	var stack: Array[Vector3i] = [start]
	var cells: Array[Vector3i] = []
	while not stack.is_empty():
		var p: Vector3i = stack.pop_back()
		cells.append(p)
		for n: Vector3i in NBRS:
			var q: Vector3i = p + n
			if visited.has(q):
				continue
			if get_voxel(q.x, q.y, q.z) != fluid:
				continue
			visited[q] = true
			stack.push_back(q)
	# Is any OTHER source still here? If so this pool has redundant supply;
	# the broken source alone shouldn't drain the whole thing.
	var has_other_source: bool = false
	for p: Vector3i in cells:
		if p == start:
			continue
		var lvl: int = get_water_level_at(p.x, p.y, p.z)
		if lvl <= 1:
			has_other_source = true
			break
	if has_other_source:
		set_voxel(start.x, start.y, start.z, Chunk.Block.AIR)
		return
	for p: Vector3i in cells:
		set_voxel(p.x, p.y, p.z, Chunk.Block.AIR)


# Legacy name kept so other call sites don't break during refactor.
func _drain_water_component(start: Vector3i) -> void:
	_drain_fluid_component(start, Chunk.Block.WATER)


## Queue every same-fluid neighbor of `pos` so the next tick will check
## whether each of them still has a valid upstream source. Called when
## something disturbs a fluid cell (source replaced by a block, etc.).
func _seed_fluid_retract(pos: Vector3i, fluid: int) -> void:
	const NBRS: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	var queue: Array[Vector3i] = _water_pending if fluid == Chunk.Block.WATER else _lava_pending
	for off: Vector3i in NBRS:
		var np: Vector3i = pos + off
		if get_voxel(np.x, np.y, np.z) == fluid:
			queue.append(np)


## Return true if `pos` has any upstream neighbor for `fluid` (same fluid at
## a lower level, or same fluid directly above — falling in from up). Used
## during the tick to detect cells that have lost their source chain and
## should evaporate.
func _has_fluid_upstream(pos: Vector3i, fluid: int, lvl: int) -> bool:
	# Above = falling inflow.
	if pos.y + 1 < world_size_blocks \
		and get_voxel(pos.x, pos.y + 1, pos.z) == fluid:
		return true
	const HORIZ: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	for off: Vector3i in HORIZ:
		var np: Vector3i = pos + off
		if get_voxel(np.x, np.y, np.z) != fluid:
			continue
		var n_lvl: int = get_water_level_at(np.x, np.y, np.z)
		if n_lvl <= 0:
			n_lvl = 1
		if n_lvl < lvl:
			return true
	return false


## Sets a WATER voxel with an explicit flow level (1=source ... 8=thinnest).
## Must write water_level BEFORE the voxel rebuild runs so the new face mesh
## reads the correct top height.
func set_water_voxel(wx: int, wy: int, wz: int, level: int) -> void:
	_set_fluid_voxel(wx, wy, wz, level, Chunk.Block.WATER)


## Same as set_water_voxel but for lava. Both fluids share `chunk.water_level`
## since a single cell only holds one fluid at a time.
func set_lava_voxel(wx: int, wy: int, wz: int, level: int) -> void:
	_set_fluid_voxel(wx, wy, wz, level, Chunk.Block.LAVA)


func _set_fluid_voxel(wx: int, wy: int, wz: int, level: int, fluid: int) -> void:
	if wx < 0 or wy < 0 or wz < 0:
		return
	if wx >= world_size_blocks or wy >= world_size_blocks or wz >= world_size_blocks:
		return
	var cp := Vector3i(wx >> 4, wy >> 4, wz >> 4)
	var chunk: Chunk = chunks.get(cp)
	if chunk == null:
		return
	var idx: int = (wx & 15) + ((wy & 15) << 4) + ((wz & 15) << 8)
	chunk.water_level[idx] = level
	set_voxel(wx, wy, wz, fluid)
	_check_fluid_reaction(Vector3i(wx, wy, wz), fluid)


## Water + lava adjacency produces a solid:
##   - Lava SOURCE (level 1) + water → OBSIDIAN (the lava cell).
##   - Lava FLOW (level ≥ 2) + water → COBBLESTONE (the lava cell).
## The converted cell is always the LAVA side — water cells are unchanged.
func _check_fluid_reaction(pos: Vector3i, fluid: int) -> void:
	const NBRS: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	if fluid == Chunk.Block.WATER:
		# Water cell just arrived — check each neighbor for lava to convert.
		for off: Vector3i in NBRS:
			var np: Vector3i = pos + off
			if get_voxel(np.x, np.y, np.z) != Chunk.Block.LAVA:
				continue
			var lvl: int = get_water_level_at(np.x, np.y, np.z)
			if lvl <= 1:
				set_voxel(np.x, np.y, np.z, Chunk.Block.OBSIDIAN)
			else:
				set_voxel(np.x, np.y, np.z, Chunk.Block.COBBLESTONE)
	elif fluid == Chunk.Block.LAVA:
		# Lava cell just arrived — if touching water, convert itself based
		# on its OWN level.
		var own_lvl: int = get_water_level_at(pos.x, pos.y, pos.z)
		for off: Vector3i in NBRS:
			var np: Vector3i = pos + off
			if get_voxel(np.x, np.y, np.z) != Chunk.Block.WATER:
				continue
			if own_lvl <= 1:
				set_voxel(pos.x, pos.y, pos.z, Chunk.Block.OBSIDIAN)
			else:
				set_voxel(pos.x, pos.y, pos.z, Chunk.Block.COBBLESTONE)
			return


const LAVA_TICK_INTERVAL: float = 0.375  # 1.5× water — lava flows slower
var _lava_accumulator: float = 0.0
var _lava_pending: Array[Vector3i] = []

# --- Grass spread ---
# Each real-time second, every eligible dirt (with grass neighbor + air above)
# rolls a 7% chance to become grass. To avoid a 12M-voxel sweep, we walk a
# fraction of chunks per real frame (amortizing one full sweep per second)
# and only step into the inner voxel loop for chunks that might plausibly
# contain dirt + grass — identified cheaply via a pre-scan flag.
const GRASS_SPREAD_INTERVAL: float = 1.0
const GRASS_SPREAD_CHANCE: float = 0.07
# Per-frame CPU budget for the grass scan. Picked empirically: 1ms at 1800fps
# is ~1.8 frames worth of headroom, so even a heavily-spreaded scan won't drop
# a noticeable % of the frame. With ~4096 chunks to scan, the whole sweep
# finishes in well under 1s across multiple frames.
const GRASS_SCAN_BUDGET_USEC: int = 1000
var _grass_spread_accum: float = 0.0
var _grass_spread_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# In-progress scan state. `_grass_scan_keys` is a snapshot of chunk positions
# taken at the start of a pass; `_grass_scan_cursor` walks through them across
# frames; `_grass_scan_converted` accumulates dirt→grass conversions until
# the pass completes and we apply + remesh in one batch. A pass is
# "in progress" iff `_grass_scan_cursor < _grass_scan_keys.size()`.
var _grass_scan_keys: Array = []
var _grass_scan_cursor: int = 0
var _grass_scan_converted: Array[Vector3i] = []

# --- Leaf decay ---
# Natural leaves that have lost log support, timer counting down to removal.
# Placed leaves are excluded (we mark them by storing 1 in water_level[idx]).
var _leaf_decay_timers: Dictionary = {}  # Vector3i -> float seconds
var _leaf_decay_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _process(delta: float) -> void:
	# Water flow
	if _water_pending.is_empty():
		_water_accumulator = 0.0
	else:
		_water_accumulator += delta
		while _water_accumulator >= WATER_TICK_INTERVAL:
			_water_accumulator -= WATER_TICK_INTERVAL
			_tick_fluid(Chunk.Block.WATER, _water_pending)
			if _water_pending.is_empty():
				break
	# Lava flow — same physics as water but on its own pending queue and
	# with a longer tick interval so it visibly lags behind water.
	if _lava_pending.is_empty():
		_lava_accumulator = 0.0
	else:
		_lava_accumulator += delta
		while _lava_accumulator >= LAVA_TICK_INTERVAL:
			_lava_accumulator -= LAVA_TICK_INTERVAL
			_tick_fluid(Chunk.Block.LAVA, _lava_pending)
			if _lava_pending.is_empty():
				break

	# Grass spread + leaf decay housekeeping.
	_tick_grass_spread(delta)
	_tick_leaf_decay(delta)


## Advance one tick of a fluid's spread. Shared between water and lava so
## both get the same gravity-first, horizontal-thinning behavior. `fluid` is
## Chunk.Block.WATER or Chunk.Block.LAVA; `pending` is the matching queue.
func _tick_fluid(fluid: int, pending: Array[Vector3i]) -> void:
	var current := pending.duplicate()
	pending.clear()
	const ORTHO: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]

	# Collect new placements first, then apply them + rebuild chunks once.
	var new_positions: Array[Vector3i] = []
	var new_levels: Array[int] = []

	# Cells that evaporated this tick (no upstream). We collect them first
	# then remove + queue neighbors after the main spread pass so the order
	# of operations doesn't disturb upstream checks on still-valid cells.
	var to_evaporate: Array[Vector3i] = []

	for pos: Vector3i in current:
		if get_voxel(pos.x, pos.y, pos.z) != fluid:
			continue
		var cp := Vector3i(pos.x >> 4, pos.y >> 4, pos.z >> 4)
		var chunk: Chunk = chunks.get(cp)
		if chunk == null:
			continue
		var lvl: int = chunk.water_level[(pos.x & 15) + ((pos.y & 15) << 4) + ((pos.z & 15) << 8)]
		if lvl <= 0:
			lvl = 1

		# Flowing cells (level > 1) need a source chain. If no neighbor has a
		# strictly lower level (and no fluid directly above is falling in),
		# the cell lost its source — queue it for evaporation.
		if lvl > 1 and not _has_fluid_upstream(pos, fluid, lvl):
			to_evaporate.append(pos)
			continue

		# Gravity first: if the cell below is air, the fluid falls preserving
		# its level. When falling, skip horizontal spread — fluids prefer to
		# drop vertically.
		if pos.y - 1 >= 0:
			var below := Vector3i(pos.x, pos.y - 1, pos.z)
			if get_voxel(below.x, below.y, below.z) == Chunk.Block.AIR:
				new_positions.append(below)
				new_levels.append(lvl)
				continue

		# Can't flow down — spread horizontally, thinning by one level per step.
		if lvl >= 8:
			continue
		var new_level: int = lvl + 1
		for off: Vector3i in ORTHO:
			var np: Vector3i = pos + off
			if np.x < 0 or np.z < 0 or np.x >= world_size_blocks or np.z >= world_size_blocks:
				continue
			if np.y < 0 or np.y >= world_size_blocks:
				continue
			if get_voxel(np.x, np.y, np.z) != Chunk.Block.AIR:
				continue
			new_positions.append(np)
			new_levels.append(new_level)

	# Shared affected-chunks dict for this whole tick. Batching evaporation
	# into this dict (instead of calling set_voxel per cell) was the main
	# fix for the "draining a pool causes stutter" complaint — a pool of
	# N flow cells used to trigger N chunk remeshes; now they coalesce.
	var affected: Dictionary = {}
	var size: int = world_size_blocks

	const EVAP_NBRS: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	# Evaporate lost-upstream cells in bulk — direct voxel writes, collect
	# 3×3×3 affected regions for a single rebuild pass at the end.
	for p: Vector3i in to_evaporate:
		var ecp := Vector3i(p.x >> 4, p.y >> 4, p.z >> 4)
		var echunk: Chunk = chunks.get(ecp)
		if echunk == null:
			continue
		var eidx: int = (p.x & 15) + ((p.y & 15) << 4) + ((p.z & 15) << 8)
		if echunk.voxels[eidx] != fluid:
			continue
		echunk.voxels[eidx] = Chunk.Block.AIR
		echunk.water_level[eidx] = 0
		# Queue fluid neighbors so their upstream is rechecked next tick.
		for off: Vector3i in EVAP_NBRS:
			var np: Vector3i = p + off
			if get_voxel(np.x, np.y, np.z) == fluid:
				pending.append(np)
		# 3×3×3 rebuild region.
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				for dz: int in range(-1, 2):
					var x: int = p.x + dx
					var y: int = p.y + dy
					var z: int = p.z + dz
					if x < 0 or y < 0 or z < 0 or x >= size or y >= size or z >= size:
						continue
					var ncp := Vector3i(x >> 4, y >> 4, z >> 4)
					if not chunks.has(ncp):
						continue
					var lp := Vector3i(x & 15, y & 15, z & 15)
					if affected.has(ncp):
						(affected[ncp] as Dictionary)[lp] = true
					else:
						affected[ncp] = {lp: true}

	# Write spread placements + extend the same affected dict.
	for i: int in new_positions.size():
		var np: Vector3i = new_positions[i]
		var lvl: int = new_levels[i]
		var cp := Vector3i(np.x >> 4, np.y >> 4, np.z >> 4)
		var chunk: Chunk = chunks.get(cp)
		if chunk == null:
			continue
		# Skip duplicates (the same cell could be queued by multiple neighbors).
		var idx: int = (np.x & 15) + ((np.y & 15) << 4) + ((np.z & 15) << 8)
		if chunk.voxels[idx] == fluid:
			continue
		chunk.water_level[idx] = lvl
		chunk.voxels[idx] = fluid
		if lvl < 8:
			pending.append(np)
		# Water + lava neighbors → obsidian/cobblestone. Check after each
		# spread write so flows that reach the opposite fluid solidify at
		# the contact frame.
		_check_fluid_reaction(np, fluid)
		# 3x3x3 rebuild region for AO correctness.
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				for dz: int in range(-1, 2):
					var x: int = np.x + dx
					var y: int = np.y + dy
					var z: int = np.z + dz
					if x < 0 or y < 0 or z < 0 or x >= size or y >= size or z >= size:
						continue
					var ncp := Vector3i(x >> 4, y >> 4, z >> 4)
					if not chunks.has(ncp):
						continue
					var lp := Vector3i(x & 15, y & 15, z & 15)
					if affected.has(ncp):
						(affected[ncp] as Dictionary)[lp] = true
					else:
						affected[ncp] = {lp: true}

	if affected.is_empty():
		return

	# Rebuild each affected chunk exactly once. Detach from shared meshes
	# first (flatgrass fast path) so incremental edits don't leak to siblings.
	for acp: Vector3i in affected:
		var ac: Chunk = chunks[acp]
		if ac.mesh != ac._arr_mesh:
			_detach_shared_mesh(ac)
			continue
		for lp: Vector3i in (affected[acp] as Dictionary):
			ac._rebuild_block_faces(lp.x, lp.y, lp.z)
		ac._apply_mesh()


## Once per GRASS_SPREAD_INTERVAL, walk every loaded chunk once and roll a
## 7% conversion chance for each dirt cell that has both a grass neighbor and
## air directly above. Uses batched voxel writes + shared `affected` dict so
## a single tick can convert many cells without per-voxel mesh rebuilds.
func _tick_grass_spread(delta: float) -> void:
	_grass_spread_accum += delta
	# Pass is NOT in progress? If the interval has elapsed, start one — take a
	# snapshot of chunk keys and reset the cursor. If a previous pass is still
	# draining across frames we skip starting a new one; the previous pass is
	# allowed to finish first (avoids stacking scans which would compound).
	if _grass_scan_cursor >= _grass_scan_keys.size():
		if _grass_spread_accum < GRASS_SPREAD_INTERVAL:
			return
		_grass_spread_accum = 0.0
		if chunks.is_empty():
			return
		_grass_scan_keys = chunks.keys()
		_grass_scan_cursor = 0
		_grass_scan_converted.clear()

	# Scan up to BUDGET_USEC worth of chunks this frame. Each voxel loop over
	# a chunk is fast on "empty" (no-dirt) chunks — the byte compare at
	# vox[idx] != DIRT short-circuits in ~20ns. The cost comes from chunks
	# with lots of dirt triggering get_voxel calls for neighbor probes.
	const DIRT: int = Chunk.Block.DIRT
	const GRASS: int = Chunk.Block.GRASS
	var size: int = world_size_blocks
	var rng := _grass_spread_rng
	var chance: float = GRASS_SPREAD_CHANCE
	var deadline: int = Time.get_ticks_usec() + GRASS_SCAN_BUDGET_USEC

	while _grass_scan_cursor < _grass_scan_keys.size():
		var cp: Vector3i = _grass_scan_keys[_grass_scan_cursor]
		_grass_scan_cursor += 1
		var chunk: Chunk = chunks.get(cp)
		if chunk == null:
			continue  # chunk was unloaded between snapshot and scan
		var base_x: int = cp.x << 4
		var base_y: int = cp.y << 4
		var base_z: int = cp.z << 4
		var vox: PackedByteArray = chunk.voxels
		for lz: int in CHUNK_SIZE:
			var vz: int = lz << 8
			for ly: int in CHUNK_SIZE:
				var vy: int = ly << 4
				for lx: int in CHUNK_SIZE:
					if vox[lx + vy + vz] != DIRT:
						continue
					var wx: int = base_x + lx
					var wy: int = base_y + ly
					var wz: int = base_z + lz
					if wy + 1 >= size:
						continue
					if get_voxel(wx, wy + 1, wz) != Chunk.Block.AIR:
						continue
					var has_grass_neighbor: bool = false
					for dy2: int in [-1, 0, 1]:
						if has_grass_neighbor:
							break
						for dz2: int in [-1, 0, 1]:
							if has_grass_neighbor:
								break
							for dx2: int in [-1, 0, 1]:
								if dx2 == 0 and dy2 == 0 and dz2 == 0:
									continue
								if get_voxel(wx + dx2, wy + dy2, wz + dz2) == GRASS:
									has_grass_neighbor = true
									break
					if not has_grass_neighbor:
						continue
					if rng.randf() > chance:
						continue
					_grass_scan_converted.append(Vector3i(wx, wy, wz))
		# After finishing each chunk, check if we've spent our budget. We
		# never abort mid-chunk because the inner loop is tight and the
		# per-chunk cost is bounded — chunk-level granularity is enough.
		if Time.get_ticks_usec() >= deadline:
			return

	# Pass complete — apply all accumulated conversions and rebuild affected
	# chunk meshes. This is the expensive-ish part, but it only fires once
	# per pass (not once per frame), and only affects chunks that actually
	# had a conversion. Empty-conversion passes cost nothing here.
	if _grass_scan_converted.is_empty():
		return
	var affected: Dictionary = {}
	for p: Vector3i in _grass_scan_converted:
		var cp2 := Vector3i(p.x >> 4, p.y >> 4, p.z >> 4)
		var ch2: Chunk = chunks.get(cp2)
		if ch2 == null:
			continue
		var idx: int = (p.x & 15) + ((p.y & 15) << 4) + ((p.z & 15) << 8)
		if ch2.voxels[idx] != DIRT:
			continue
		ch2.voxels[idx] = GRASS
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				for dz: int in range(-1, 2):
					var x: int = p.x + dx
					var y: int = p.y + dy
					var z: int = p.z + dz
					if x < 0 or y < 0 or z < 0 or x >= size or y >= size or z >= size:
						continue
					var ncp := Vector3i(x >> 4, y >> 4, z >> 4)
					if not chunks.has(ncp):
						continue
					var lp := Vector3i(x & 15, y & 15, z & 15)
					if affected.has(ncp):
						(affected[ncp] as Dictionary)[lp] = true
					else:
						affected[ncp] = {lp: true}

	for acp: Vector3i in affected:
		var ac: Chunk = chunks[acp]
		if ac.mesh != ac._arr_mesh:
			_detach_shared_mesh(ac)
			continue
		for lp: Vector3i in (affected[acp] as Dictionary):
			ac._rebuild_block_faces(lp.x, lp.y, lp.z)
		ac._apply_mesh()
	_grass_scan_converted.clear()


## Leaf decay ticker. For each entry in _leaf_decay_timers, decrement by delta;
## when one hits zero, re-check whether any log still supports that leaf (any
## LOG block in a 9×9×9 cube around it). If none, break the leaf; otherwise
## just drop the timer — the leaf got reconnected to support somehow.
func _tick_leaf_decay(delta: float) -> void:
	if _leaf_decay_timers.is_empty():
		return
	var to_decay: Array[Vector3i] = []
	var still_supported: Array[Vector3i] = []
	for pos: Vector3i in _leaf_decay_timers.keys():
		var t: float = _leaf_decay_timers[pos] - delta
		if t > 0.0:
			_leaf_decay_timers[pos] = t
			continue
		# Timer expired.
		if get_voxel(pos.x, pos.y, pos.z) != Chunk.Block.LEAVES:
			still_supported.append(pos)
			continue
		# Natural leaf check (water_level[idx] == 0).
		var cp := Vector3i(pos.x >> 4, pos.y >> 4, pos.z >> 4)
		var chunk: Chunk = chunks.get(cp)
		if chunk == null:
			still_supported.append(pos)
			continue
		var idx: int = (pos.x & 15) + ((pos.y & 15) << 4) + ((pos.z & 15) << 8)
		if chunk.water_level[idx] != 0:
			# Placed leaf — stop tracking, never decays.
			still_supported.append(pos)
			continue
		# Re-check connection-based support at expiry — the player may have
		# placed a new log that reconnects the canopy in the meantime.
		if _leaf_has_log_connection(pos):
			still_supported.append(pos)
			continue
		to_decay.append(pos)

	for p: Vector3i in still_supported:
		_leaf_decay_timers.erase(p)

	if to_decay.is_empty():
		return

	# Break leaves. Under Chebyshev-distance support, removing a leaf can't
	# orphan another leaf (only log positions matter), so no chain decay is
	# needed — all affected leaves were scheduled when their log was broken.
	for p: Vector3i in to_decay:
		if particle_system != null:
			particle_system.spawn_break_burst(Vector3(p) + Vector3(0.5, 0.5, 0.5), Chunk.Block.LEAVES)
		set_voxel(p.x, p.y, p.z, Chunk.Block.AIR)
		_leaf_decay_timers.erase(p)


## Orthogonal 6-neighbor offsets used by the leaf-support BFS.
const _LEAF_NBRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const _LEAF_SUPPORT_STEPS: int = 4


## Connectivity-based support: a leaf is "supported" if, starting from its
## cell, a BFS that can only step through LEAVES reaches a LOG within
## `_LEAF_SUPPORT_STEPS` hops. Matches Minecraft's rule — when the trunk
## is gone, canopy leaves several blocks out still decay because none of
## their leaf-to-leaf paths reach a log anymore.
func _leaf_has_log_connection(pos: Vector3i) -> bool:
	var visited: Dictionary = {pos: true}
	var frontier: Array[Vector3i] = [pos]
	for step: int in _LEAF_SUPPORT_STEPS:
		var next_frontier: Array[Vector3i] = []
		for p: Vector3i in frontier:
			for off: Vector3i in _LEAF_NBRS:
				var np: Vector3i = p + off
				if visited.has(np):
					continue
				visited[np] = true
				var b: int = get_voxel(np.x, np.y, np.z)
				if b == Chunk.Block.LOG:
					return true
				if b == Chunk.Block.LEAVES:
					next_frontier.append(np)
		if next_frontier.is_empty():
			return false
		frontier = next_frontier
	return false


## Called when a LOG breaks: flood-fill the connected leaf component
## starting from the log's position (walks through LEAVES only). For every
## natural, not-yet-scheduled leaf it touches, runs the BFS support check
## and — if the leaf no longer has any log within 4 connected steps —
## schedules it for random 3–10 s decay. This propagates correctly across
## the entire canopy, so felling a trunk kills every leaf the tree had,
## even those further than 4 Chebyshev blocks from the actual break site.
func _schedule_leaf_decay_around(log_pos: Vector3i) -> void:
	var visited: Dictionary = {log_pos: true}
	var stack: Array[Vector3i] = [log_pos]
	while not stack.is_empty():
		var p: Vector3i = stack.pop_back()
		for off: Vector3i in _LEAF_NBRS:
			var np: Vector3i = p + off
			if visited.has(np):
				continue
			visited[np] = true
			if get_voxel(np.x, np.y, np.z) != Chunk.Block.LEAVES:
				continue
			# Keep walking through the connected leaf region.
			stack.append(np)
			if _leaf_decay_timers.has(np):
				continue
			var cp := Vector3i(np.x >> 4, np.y >> 4, np.z >> 4)
			var chunk: Chunk = chunks.get(cp)
			if chunk == null:
				continue
			var idx: int = (np.x & 15) + ((np.y & 15) << 4) + ((np.z & 15) << 8)
			# Placed leaves (water_level[idx] == 1) never decay.
			if chunk.water_level[idx] != 0:
				continue
			if _leaf_has_log_connection(np):
				continue
			_leaf_decay_timers[np] = _leaf_decay_rng.randf_range(3.0, 10.0)


# --- World generation ---

## Max chunk Y layer that can contain terrain or features. Chunks above this
## are only created on demand when the player builds (see _ensure_chunk).
func _max_terrain_chunk_y() -> int:
	var max_h: int
	if current_terrain_type == TerrainType.VANILLA_HILLY:
		max_h = 58  # max terrain ~48 + headroom for tree tops
	elif current_terrain_type == TerrainType.FLATGRASS:
		max_h = FLATGRASS_GROUND + 1  # 5-block slab — fits in one chunk layer
	else:
		if world_size_blocks >= LARGE_WORLD_THRESHOLD:
			max_h = LARGE_WORLD_TERRAIN_BASE + 14 + 10  # base + noise + trees
		else:
			max_h = maxi(20, world_size_blocks / 3) + 14 + 10
	return clampi(max_h / CHUNK_SIZE + 1, 1, world_size_chunks)


func _create_chunk(cp: Vector3i) -> Chunk:
	var chunk := Chunk.new()
	chunk.chunk_position = cp
	chunk.world = self
	chunk.position = Vector3(cp) * CHUNK_SIZE
	# Seed materials so chunks created on-demand via _ensure_chunk (player
	# builds above the generated terrain layer) render with the voxel shader
	# on their first _apply_mesh — without this, the surface is uploaded
	# with no material and the shader's face-culling / alpha-cutout doesn't
	# apply, producing the "I can see through the top block" bug.
	chunk._stored_mat = material
	chunk._water_mat = water_material
	chunks[cp] = chunk
	add_child(chunk)
	return chunk


## Create only the chunk layers that will contain terrain. For 512³ with
## terrain up to ~y=50, this creates ~3 Y-layers instead of 32, reducing
## chunk count by ~90%. Chunks above terrain are created on demand if the
## player builds there (see _ensure_chunk).
func _create_terrain_chunks() -> void:
	var max_cy: int = _max_terrain_chunk_y()
	for cx: int in world_size_chunks:
		for cy: int in max_cy:
			for cz: int in world_size_chunks:
				_create_chunk(Vector3i(cx, cy, cz))


## Get or create a chunk on demand (for building above terrain).
func _ensure_chunk(cp: Vector3i) -> Chunk:
	var chunk: Chunk = chunks.get(cp)
	if chunk != null:
		return chunk
	return _create_chunk(cp)


## Check if a chunk has any non-air voxels. All-air chunks need no mesh.
func _chunk_has_solid(chunk: Chunk) -> bool:
	for i: int in Chunk.VOLUME:
		if chunk.voxels[i] != 0:
			return true
	return false


## Build an 18³ padded voxel buffer from the chunk's own voxels plus its
## neighbors' voxels. Caches the 6 face-neighbor chunks once and reads the
## main 16×16 of each face slab directly from neighbor voxel arrays (1536
## cells, ~10x faster than calling get_voxel per cell). Only the 200 edge +
## corner cells fall back to get_voxel, which touches diagonal chunks.
func _build_padded(chunk: Chunk) -> PackedByteArray:
	var padded := PackedByteArray()
	padded.resize(5832)
	var cp: Vector3i = chunk.chunk_position
	var bx: int = cp.x * CHUNK_SIZE
	var by: int = cp.y * CHUNK_SIZE
	var bz: int = cp.z * CHUNK_SIZE
	# Interior 16³ — direct byte copy.
	var vox: PackedByteArray = chunk.voxels
	for z: int in CHUNK_SIZE:
		var pz_off: int = (z + 1) * 324
		var vz_off: int = z << 8
		for y: int in CHUNK_SIZE:
			var py_off: int = (y + 1) * 18 + pz_off
			var vy_off: int = (y << 4) + vz_off
			for x: int in CHUNK_SIZE:
				padded[x + 1 + py_off] = vox[x + vy_off]

	# Cache the 6 face-neighbor chunks once.
	var nyn: Chunk = chunks.get(Vector3i(cp.x, cp.y - 1, cp.z)) as Chunk
	var nyp: Chunk = chunks.get(Vector3i(cp.x, cp.y + 1, cp.z)) as Chunk
	var nxn: Chunk = chunks.get(Vector3i(cp.x - 1, cp.y, cp.z)) as Chunk
	var nxp: Chunk = chunks.get(Vector3i(cp.x + 1, cp.y, cp.z)) as Chunk
	var nzn: Chunk = chunks.get(Vector3i(cp.x, cp.y, cp.z - 1)) as Chunk
	var nzp: Chunk = chunks.get(Vector3i(cp.x, cp.y, cp.z + 1)) as Chunk

	# ±Y faces — main 16×16 (px=1..16, pz=1..16) direct-read from neighbor.
	if nyn != null:
		var nv: PackedByteArray = nyn.voxels
		for pz: int in 16:
			for px: int in 16:
				padded[(px + 1) + (pz + 1) * 324] = nv[px + (15 << 4) + (pz << 8)]
	else:
		for pz: int in 16:
			for px: int in 16:
				padded[(px + 1) + (pz + 1) * 324] = get_voxel(bx + px, by - 1, bz + pz)
	if nyp != null:
		var nv: PackedByteArray = nyp.voxels
		for pz: int in 16:
			for px: int in 16:
				padded[(px + 1) + 17 * 18 + (pz + 1) * 324] = nv[px + (pz << 8)]
	else:
		for pz: int in 16:
			for px: int in 16:
				padded[(px + 1) + 17 * 18 + (pz + 1) * 324] = get_voxel(bx + px, by + 16, bz + pz)
	# ±X faces — main 16×16 (py=1..16, pz=1..16).
	if nxn != null:
		var nv: PackedByteArray = nxn.voxels
		for pz: int in 16:
			for py: int in 16:
				padded[(py + 1) * 18 + (pz + 1) * 324] = nv[15 + (py << 4) + (pz << 8)]
	else:
		for pz: int in 16:
			for py: int in 16:
				padded[(py + 1) * 18 + (pz + 1) * 324] = get_voxel(bx - 1, by + py, bz + pz)
	if nxp != null:
		var nv: PackedByteArray = nxp.voxels
		for pz: int in 16:
			for py: int in 16:
				padded[17 + (py + 1) * 18 + (pz + 1) * 324] = nv[(py << 4) + (pz << 8)]
	else:
		for pz: int in 16:
			for py: int in 16:
				padded[17 + (py + 1) * 18 + (pz + 1) * 324] = get_voxel(bx + 16, by + py, bz + pz)
	# ±Z faces — main 16×16 (px=1..16, py=1..16).
	if nzn != null:
		var nv: PackedByteArray = nzn.voxels
		for py: int in 16:
			for px: int in 16:
				padded[(px + 1) + (py + 1) * 18] = nv[px + (py << 4) + (15 << 8)]
	else:
		for py: int in 16:
			for px: int in 16:
				padded[(px + 1) + (py + 1) * 18] = get_voxel(bx + px, by + py, bz - 1)
	if nzp != null:
		var nv: PackedByteArray = nzp.voxels
		for py: int in 16:
			for px: int in 16:
				padded[(px + 1) + (py + 1) * 18 + 17 * 324] = nv[px + (py << 4)]
	else:
		for py: int in 16:
			for px: int in 16:
				padded[(px + 1) + (py + 1) * 18 + 17 * 324] = get_voxel(bx + px, by + py, bz + 16)

	# Remaining 200 edge + corner cells (diagonal neighbors) via get_voxel.
	# Y-axis edges: 4 lines × 18 cells = 72 cells at (px∈{0,17}, pz∈{0,17}).
	for py: int in 18:
		var wy: int = by + py - 1
		padded[py * 18] = get_voxel(bx - 1, wy, bz - 1)
		padded[17 + py * 18] = get_voxel(bx + 16, wy, bz - 1)
		padded[py * 18 + 17 * 324] = get_voxel(bx - 1, wy, bz + 16)
		padded[17 + py * 18 + 17 * 324] = get_voxel(bx + 16, wy, bz + 16)
	# X-axis edges on ±Y faces: 4 lines × 16 cells = 64 cells (py∈{0,17}, pz∈{0,17}, px=1..16).
	for px: int in range(1, 17):
		var wx: int = bx + px - 1
		padded[px] = get_voxel(wx, by - 1, bz - 1)
		padded[px + 17 * 18] = get_voxel(wx, by + 16, bz - 1)
		padded[px + 17 * 324] = get_voxel(wx, by - 1, bz + 16)
		padded[px + 17 * 18 + 17 * 324] = get_voxel(wx, by + 16, bz + 16)
	# Z-axis edges on ±Y+±X faces: 4 lines × 16 cells = 64 cells (py∈{0,17}, px∈{0,17}, pz=1..16).
	for pz: int in range(1, 17):
		var wz: int = bz + pz - 1
		padded[pz * 324] = get_voxel(bx - 1, by - 1, wz)
		padded[17 + pz * 324] = get_voxel(bx + 16, by - 1, wz)
		padded[17 * 18 + pz * 324] = get_voxel(bx - 1, by + 16, wz)
		padded[17 + 17 * 18 + pz * 324] = get_voxel(bx + 16, by + 16, wz)

	return padded


## Generate the entire world. Fast column-based terrain gen, then feature
## placement, then padded-buffer mesh building with inlined AO.
func _generate_world(terrain_type: int) -> void:
	current_terrain_type = terrain_type
	world_size_chunks = world_size_blocks / CHUNK_SIZE
	ChunkGen.configure_noise(noise, biome_noise, world_seed, terrain_type)

	# Flatgrass is async (shared voxel buffers + progress yields), so it
	# runs only via regenerate(). First-boot _ready() uses VANILLA_DEFAULT.
	assert(terrain_type != TerrainType.FLATGRASS, "FLATGRASS must go through regenerate() for async generation")

	# Phase 1: create only terrain-layer chunks (skips ~90% for large worlds).
	_create_terrain_chunks()

	# Phase 2: fill voxels — cached chunk refs, no per-voxel Dict lookup.
	var total_cols: int = world_size_chunks * world_size_chunks
	for i: int in total_cols:
		_gen_column_task(i)

	# Phase 3: features.
	var feature_rng := RandomNumberGenerator.new()
	feature_rng.seed = world_seed
	_place_water_pools(feature_rng)
	# Caves first, then ores: caves carve natural mass only (ores are a
	# different block type), so ore veins placed afterward can happen to
	# appear in a cave wall — that's the classic "spot a vein while
	# exploring" moment and costs nothing.
	_carve_caves(feature_rng)
	_place_ores(feature_rng)
	_place_trees(feature_rng)
	_place_flowers(feature_rng)

	# Phase 4: build padded buffer + mesh + upload per chunk.
	# Single-threaded — GDScript's GIL makes WorkerThreadPool serialize
	# anyway, and the mutex overhead makes threading actively slower.
	# The padded buffer gives fast AO (direct array reads instead of
	# Dict lookups), and the inlined _compute_ao_padded eliminates
	# ~108K method dispatches per chunk.
	for chunk: Chunk in chunks.values():
		if not _chunk_has_solid(chunk):
			continue
		chunk._padded = _build_padded(chunk)
		chunk._use_padded = true
		chunk.generate_mesh(material, water_material)
		chunk._use_padded = false
		chunk._padded = PackedByteArray()


## Flatgrass fast path: every chunk at the same Y-layer is identical, so we
## build ONE shared voxel buffer per cy (CoW-assigned to every chunk on that
## layer) + ONE shared mesh per cy (siblings render the same ArrayMesh).
## Async: yields during chunk creation and mesh building so the progress bar
## animates smoothly instead of the main thread freezing.
func _generate_world_flatgrass() -> void:
	var max_cy: int = _max_terrain_chunk_y()
	var ground: int = FLATGRASS_GROUND

	# Phase 1a: precompute one voxel buffer per cy. Since every chunk on this
	# layer is identical in flatgrass, we build a single PackedByteArray and
	# CoW-share it with every chunk — 4096 writes per cy instead of 4096 per
	# chunk.
	generation_progress.emit(0.12, "Preparing layers...")
	await get_tree().process_frame
	var templates: Array[PackedByteArray] = []
	templates.resize(max_cy)
	for cy: int in max_cy:
		var buf := PackedByteArray()
		buf.resize(Chunk.VOLUME)
		for ly: int in CHUNK_SIZE:
			var wy: int = (cy << 4) + ly
			var block: int = 0
			if wy == 0:
				block = Chunk.Block.WORLD_BEDROCK
			elif wy < ground - 3:
				block = Chunk.Block.STONE
			elif wy < ground:
				block = Chunk.Block.DIRT
			elif wy == ground:
				block = Chunk.Block.GRASS
			else:
				continue  # air; buf is already zero-filled
			var row_base: int = ly << 4
			for lz: int in CHUNK_SIZE:
				var dst: int = row_base + (lz << 8)
				for lx: int in CHUNK_SIZE:
					buf[dst + lx] = block
		templates[cy] = buf

	# Phase 1b: create chunks, CoW-assigning the shared voxel buffer per cy.
	# Yields per cx row so the UI paints.
	var row_batch: int = maxi(1, world_size_chunks / 20)
	for cx: int in world_size_chunks:
		for cz: int in world_size_chunks:
			for cy: int in max_cy:
				var chunk: Chunk = _create_chunk(Vector3i(cx, cy, cz))
				chunk.voxels = templates[cy]
		if (cx + 1) % row_batch == 0 or cx == world_size_chunks - 1:
			var p: float = 0.12 + 0.50 * float(cx + 1) / float(world_size_chunks)
			generation_progress.emit(p, "Creating chunks... %d/%d" % [cx + 1, world_size_chunks])
			await get_tree().process_frame

	# Phase 2: build one template mesh per cy layer, then clone into a
	# standalone shared ArrayMesh for siblings at the same cy.
	generation_progress.emit(0.64, "Building meshes...")
	await get_tree().process_frame
	var mid_cx: int = world_size_chunks / 2
	var mid_cz: int = world_size_chunks / 2

	for cy: int in max_cy:
		var template: Chunk = chunks.get(Vector3i(mid_cx, cy, mid_cz))
		if template == null or not _chunk_has_solid(template):
			continue

		template._padded = _build_padded(template)
		template._use_padded = true
		template.generate_mesh(material, water_material)
		template._use_padded = false
		template._padded = PackedByteArray()

		# Clone the template's surface data into a SEPARATE ArrayMesh. The
		# template keeps its own `_arr_mesh` for its own rendering; siblings
		# share this clone. This way, editing the template rebuilds only
		# `template._arr_mesh`, leaving the shared mesh intact.
		var tmpl_mesh: ArrayMesh = template._arr_mesh
		var shared_mesh := ArrayMesh.new()
		var surf_count: int = tmpl_mesh.get_surface_count()
		var solid_verts := PackedVector3Array()
		for s: int in surf_count:
			var arrays: Array = tmpl_mesh.surface_get_arrays(s)
			shared_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat: Material = tmpl_mesh.surface_get_material(s)
			if mat != null:
				shared_mesh.surface_set_material(s, mat)
			# Surface 0 is solid (see _apply_mesh ordering); use it for collision.
			if s == 0:
				solid_verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array

		for cx: int in world_size_chunks:
			for cz: int in world_size_chunks:
				if cx == mid_cx and cz == mid_cz:
					continue  # template already rendered via its own _arr_mesh
				var chunk: Chunk = chunks.get(Vector3i(cx, cy, cz))
				if chunk == null:
					continue
				chunk._stored_mat = material
				chunk._water_mat = water_material
				chunk.mesh = shared_mesh
				if chunk._physics_ready:
					PhysicsServer3D.shape_set_data(chunk._shape_rid, {"faces": solid_verts, "backface_collision": true})

		var p: float = 0.64 + 0.34 * float(cy + 1) / float(max_cy)
		generation_progress.emit(p, "Sharing layer meshes... %d/%d" % [cy + 1, max_cy])
		await get_tree().process_frame


## Worker-thread-safe terrain column generation. Pre-computes heights and
## biomes for all 256 surface cells in this chunk column, then iterates each
## chunk layer and builds a local PackedByteArray for it, assigning the whole
## buffer to chunk.voxels at the end. Keeping the buffer as a single local
## reference avoids Copy-on-Write overhead on every write.
func _gen_column_task(i: int) -> void:
	var cx: int = i / world_size_chunks
	var cz: int = i % world_size_chunks
	# Cache chunk refs for this column — avoids a Dict lookup + Vector3i
	# allocation on every single voxel write (~20x faster).
	var max_cy: int = _max_terrain_chunk_y()
	var col: Array = []
	col.resize(max_cy)
	for cy: int in max_cy:
		col[cy] = chunks[Vector3i(cx, cy, cz)]
	for lx: int in CHUNK_SIZE:
		for lz: int in CHUNK_SIZE:
			var wx: int = cx * CHUNK_SIZE + lx
			var wz: int = cz * CHUNK_SIZE + lz
			var height: int = get_terrain_height(wx, wz)
			var biome: int = get_biome(wx, wz)
			var top_block: int = Chunk.Block.GRASS
			var sub_block: int = Chunk.Block.DIRT
			if biome == BIOME_BEACH:
				top_block = Chunk.Block.SAND
				sub_block = Chunk.Block.SAND
			(col[0] as Chunk).set_voxel(lx, 0, lz, Chunk.Block.WORLD_BEDROCK)
			for wy: int in range(1, height + 1):
				var block: int
				if wy == height:
					block = top_block
				elif wy > height - 4:
					block = sub_block
				else:
					block = Chunk.Block.STONE
				(col[wy >> 4] as Chunk).set_voxel(lx, wy & 15, lz, block)


# --- Tree generation ---

func _gen_set(wx: int, wy: int, wz: int, block: int) -> void:
	if wx < 0 or wy < 0 or wz < 0:
		return
	if wx >= world_size_blocks or wy >= world_size_blocks or wz >= world_size_blocks:
		return
	var cp := Vector3i(wx >> 4, wy >> 4, wz >> 4)
	var chunk: Chunk = chunks.get(cp)
	if chunk != null:
		chunk.set_voxel(wx & 15, wy & 15, wz & 15, block)


func _gen_set_leaf(wx: int, wy: int, wz: int) -> void:
	# Only overwrite air so leaves don't replace trunk logs.
	if get_voxel(wx, wy, wz) == Chunk.Block.AIR:
		_gen_set(wx, wy, wz, Chunk.Block.LEAVES)


## Direct-write a water block during generation. Sets water_level first so
## the value survives the chunk's set_voxel (which clears the level for any
## non-water block).
func _gen_set_water(wx: int, wy: int, wz: int, level: int) -> void:
	if wx < 0 or wy < 0 or wz < 0:
		return
	if wx >= world_size_blocks or wy >= world_size_blocks or wz >= world_size_blocks:
		return
	var cp := Vector3i(wx >> 4, wy >> 4, wz >> 4)
	var chunk: Chunk = chunks.get(cp)
	if chunk == null:
		return
	var idx: int = (wx & 15) + ((wy & 15) << 4) + ((wz & 15) << 8)
	chunk.water_level[idx] = level
	chunk.voxels[idx] = Chunk.Block.WATER


func _find_surface_y(wx: int, wz: int) -> int:
	for wy: int in range(world_size_blocks - 1, -1, -1):
		if get_voxel(wx, wy, wz) != Chunk.Block.AIR:
			return wy
	return -1


## Scatter small water ponds around the world. Each pond is a carved hollow
## dug one block into the terrain and filled with full-height water blocks
## (all level 1). Thinning only applies to flowing water from a player-placed
## source, not to static ponds.
func _place_water_pools(rng: RandomNumberGenerator) -> void:
	var attempts: int = maxi(6, (world_size_blocks * world_size_blocks) / 256)
	for _i: int in attempts:
		var cx: int = rng.randi_range(4, world_size_blocks - 5)
		var cz: int = rng.randi_range(4, world_size_blocks - 5)
		var gy: int = _find_surface_y(cx, cz)
		if gy < 2:
			continue
		var surf: int = get_voxel(cx, gy, cz)
		if surf != Chunk.Block.GRASS and surf != Chunk.Block.SAND:
			continue

		# Beach-adjacent ponds always pass; otherwise only ~25% of the time.
		var near_beach: bool = get_biome(cx, cz) == BIOME_BEACH
		if not near_beach:
			for d: int in [-2, 2]:
				if get_biome(cx + d, cz) == BIOME_BEACH or get_biome(cx, cz + d) == BIOME_BEACH:
					near_beach = true
					break
		if not near_beach and rng.randf() > 0.25:
			continue

		var radius: int = rng.randi_range(2, 4)
		# Water sits one block below the original surface so it reads as
		# "in the ground" rather than sitting on top of the terrain.
		var water_y: int = gy - 1
		if water_y < 1:
			continue

		# Flatness precheck: every cell in the disk must have surface exactly
		# at gy. Rejects pools on cliffs / slopes where the pool would be
		# buried (surface above gy) or unsupported (surface below gy). Hilly
		# terrain still gets pools — just on flat pockets.
		var flat: bool = true
		for dx: int in range(-radius, radius + 1):
			for dz: int in range(-radius, radius + 1):
				var dist: int = absi(dx) + absi(dz)
				if dist > radius:
					continue
				var tx: int = cx + dx
				var tz: int = cz + dz
				if tx < 1 or tz < 1 or tx >= world_size_blocks - 1 or tz >= world_size_blocks - 1:
					flat = false
					break
				if _find_surface_y(tx, tz) != gy:
					flat = false
					break
			if not flat:
				break
		if not flat:
			continue

		for dx: int in range(-radius, radius + 1):
			for dz: int in range(-radius, radius + 1):
				var dist: int = absi(dx) + absi(dz)
				if dist > radius:
					continue
				var tx: int = cx + dx
				var tz: int = cz + dz
				# Carve the original surface to air — this is the pond rim.
				_gen_set(tx, gy, tz, Chunk.Block.AIR)
				# All pond water is full-height (level 1).
				_gen_set_water(tx, water_y, tz, 1)

		# Seal the pool rim — a single ring of cells at dist == radius + 1.
		# Only the sideways boundary at water_y is touched; we never place
		# blocks above (that would cover the pool) or around individual
		# interior water blocks. Terrain already provides the bottom seal
		# because the flatness check guarantees solid ground below water_y.
		for dx: int in range(-(radius + 1), radius + 2):
			for dz: int in range(-(radius + 1), radius + 2):
				if absi(dx) + absi(dz) != radius + 1:
					continue
				var tx: int = cx + dx
				var tz: int = cz + dz
				if tx < 0 or tz < 0 or tx >= world_size_blocks or tz >= world_size_blocks:
					continue
				if get_voxel(tx, water_y, tz) == Chunk.Block.AIR:
					_gen_set(tx, water_y, tz, Chunk.Block.DIRT)


## Place a simple oak-like tree: trunk of LOG + layered LEAVES canopy.
## `wy` is the ground block (grass). The trunk starts at wy+1.
func _place_tree(wx: int, wy: int, wz: int, rng: RandomNumberGenerator) -> void:
	var trunk_h: int = rng.randi_range(4, 6)
	var top: int = wy + trunk_h
	if top + 2 >= world_size_blocks:
		return
	# Trunk
	for i: int in trunk_h:
		_gen_set(wx, wy + 1 + i, wz, Chunk.Block.LOG)
	# 5x5 leaf layers at top-1 and top (trimmed corners)
	for dy: int in [-1, 0]:
		var y: int = top + dy
		for dx: int in range(-2, 3):
			for dz: int in range(-2, 3):
				if dx == 0 and dz == 0:
					continue
				# Trim corners, occasionally fill them in
				if absi(dx) == 2 and absi(dz) == 2 and rng.randf() < 0.6:
					continue
				_gen_set_leaf(wx + dx, y, wz + dz)
	# 3x3 layer at top+1 (with occasional trimmed corners)
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			if absi(dx) == 1 and absi(dz) == 1 and rng.randf() < 0.35:
				continue
			_gen_set_leaf(wx + dx, top + 1, wz + dz)
	# Single leaf cap
	_gen_set_leaf(wx, top + 2, wz)


## Scatter poppies + dandelions in patches on grass surfaces. Runs AFTER
## trees are placed so flowers can't overwrite trunks/canopy (the grass
## check also guards against that). Each patch is one flower type with
## 1-5 flowers offset ±2 from a jittered grid center — "patches" per the
## user's spec, not per-cell uniform scatter.
## --- Cave carving ---
##
## "Worm" style: each cave is a moving point that steps along a drifting
## direction, carving a sphere at every step. Small chance each step of a
## larger bubble for cavern rooms. Density scales with world XZ area, and
## each cave starts underground (at least CAVE_MIN_SURFACE_DEPTH below the
## surface). Carving replaces only natural mass (stone/dirt/grass/sand) so
## water pools and bedrock stay intact.
# Cave density tuned so the underground is well-connected but the surface
# stays intact. Radii are small (Minecraft-style thin winding tunnels) with
# rare wider bubbles. Deeper caves grow ~30% bigger at bedrock. Each carve
# step checks the LOCAL surface height and refuses to carve within
# CAVE_MIN_SURFACE_DEPTH blocks of it — that's the key guard that keeps
# caves from breaching the terrain surface.
const CAVE_DENSITY_PER_M2: float = 1.0 / 300.0
const CAVE_MIN_LENGTH: int = 50
const CAVE_MAX_LENGTH: int = 140
const CAVE_MIN_RADIUS: float = 1.0
const CAVE_MAX_RADIUS: float = 1.8
const CAVE_BUBBLE_CHANCE: float = 0.03
const CAVE_MIN_SURFACE_DEPTH: int = 4
const CAVE_DEPTH_SCALE: float = 0.3

func _carve_caves(rng: RandomNumberGenerator) -> void:
	var count: int = int(world_size_blocks * world_size_blocks * CAVE_DENSITY_PER_M2)
	for _i: int in count:
		# ~15% of caves begin at the surface and carve downward, creating
		# natural cave entrances you can walk into. The rest start deep.
		var is_entrance: bool = rng.randf() < 0.15
		_carve_cave_worm(rng, is_entrance)


func _carve_cave_worm(rng: RandomNumberGenerator, is_entrance: bool) -> void:
	var size: int = world_size_blocks
	var sx: int = rng.randi_range(4, size - 5)
	var sz: int = rng.randi_range(4, size - 5)
	var surface: int = _find_surface_y(sx, sz)
	if surface < 12:
		return  # terrain too thin for a meaningful cave here

	var sy: int
	if is_entrance:
		# Entrance caves start just below the surface and aim downward.
		sy = surface - 2
	else:
		# Underground caves: start deep, biased toward bottom.
		var max_sy: int = surface - CAVE_MIN_SURFACE_DEPTH
		var min_sy: int = 3
		if min_sy >= max_sy:
			return
		var t: float = rng.randf()
		t = t * t
		sy = min_sy + int(t * float(max_sy - min_sy))
	if sy < 3:
		return

	# Depth fraction 0..1 (0 = surface, 1 = bedrock). Drives radius + length
	# scaling so deeper caves are slightly bigger.
	var depth_frac: float = 1.0 - float(sy) / float(surface) if surface > 0 else 0.0
	var depth_mult: float = 1.0 + depth_frac * CAVE_DEPTH_SCALE

	var yaw: float = rng.randf_range(0.0, TAU)
	# Entrance caves point downward initially; underground caves are roughly
	# horizontal with a slight random pitch.
	var pitch: float
	if is_entrance:
		pitch = rng.randf_range(-0.6, -0.3)  # negative = downward
	else:
		pitch = rng.randf_range(-0.3, 0.3)
	var x: float = float(sx) + 0.5
	var y: float = float(sy) + 0.5
	var z: float = float(sz) + 0.5
	var length: int = int(rng.randi_range(CAVE_MIN_LENGTH, CAVE_MAX_LENGTH) * depth_mult)
	var base_radius: float = rng.randf_range(CAVE_MIN_RADIUS, CAVE_MAX_RADIUS) * depth_mult

	for _step: int in length:
		var cp: float = cos(pitch)
		x += cos(yaw) * cp
		y += sin(pitch)
		z += sin(yaw) * cp
		if x < 2.0 or x >= float(size - 2):
			return
		if z < 2.0 or z >= float(size - 2):
			return
		# Floor at y=3 so caves never expose the bedrock layer at y=0.
		# (y=1 is stone, y=0 is WORLD_BEDROCK — keeping y>=3 leaves at
		# least two solid blocks as a roof over bedrock.)
		if y < 3.0 or y >= float(size - 2):
			return
		yaw += rng.randf_range(-0.35, 0.35)
		pitch += rng.randf_range(-0.15, 0.15)
		pitch = clampf(pitch, -0.6, 0.6)
		# Surface guard for NON-entrance caves: skip carving near the
		# surface. Entrance caves are exempt for their first ~15 steps so
		# they can actually breach the surface to create a walkable opening.
		if not is_entrance or _step > 15:
			var local_surface: int = _find_surface_y(int(x), int(z))
			if local_surface >= 0 and int(y) > local_surface - CAVE_MIN_SURFACE_DEPTH:
				continue
		var r: float
		if rng.randf() < CAVE_BUBBLE_CHANCE:
			r = base_radius * rng.randf_range(1.5, 2.0)
		else:
			r = base_radius * rng.randf_range(0.85, 1.15)
		_carve_sphere(x, y, z, r)


## Set every natural-mass voxel inside a sphere to AIR. The chunk reference
## is cached across inner-loop iterations so contiguous voxels that share a
## chunk skip the Dict lookup — a sphere of radius 3 typically spans 1-8
## chunks but writes ~113 voxels, so the cache hits most of the time.
## Writes `voxels[idx]` directly (skipping set_voxel's water_level clear)
## because source blocks are never water/lava here.
func _carve_sphere(cx: float, cy: float, cz: float, r: float) -> void:
	var r_i: int = int(ceil(r))
	var r2: float = r * r
	var size: int = world_size_blocks
	var last_cp := Vector3i(-9999, -9999, -9999)
	var last_chunk: Chunk = null
	for dy: int in range(-r_i, r_i + 1):
		var wy: int = int(cy + float(dy))
		if wy < 3 or wy >= size:
			continue  # keep at least 2 solid blocks above bedrock (y=0)
		for dz: int in range(-r_i, r_i + 1):
			var wz: int = int(cz + float(dz))
			if wz < 0 or wz >= size:
				continue
			for dx: int in range(-r_i, r_i + 1):
				var dd: int = dx * dx + dy * dy + dz * dz
				if float(dd) > r2:
					continue
				var wx: int = int(cx + float(dx))
				if wx < 0 or wx >= size:
					continue
				var cp := Vector3i(wx >> 4, wy >> 4, wz >> 4)
				if cp != last_cp:
					last_cp = cp
					last_chunk = chunks.get(cp)
				if last_chunk == null:
					continue
				var idx: int = (wx & 15) + ((wy & 15) << 4) + ((wz & 15) << 8)
				var b: int = last_chunk.voxels[idx]
				# Only replace natural mass. Leaves water pools, tree logs
				# (placed later), and bedrock untouched.
				if b == Chunk.Block.STONE \
						or b == Chunk.Block.DIRT \
						or b == Chunk.Block.GRASS \
						or b == Chunk.Block.SAND:
					last_chunk.voxels[idx] = Chunk.Block.AIR


## --- Ore veins ---
##
## Each entry: [block, count_per_1000_m2, max_y_fraction, vein_min, vein_max].
## `max_y_fraction` is a fraction of the local surface height — a 0.5 fraction
## on a column with surface y=40 allows ore up to y=20. This gives the
## "slightly more ore deeper" behavior naturally: deeper tiers have narrower
## y ranges so their total count concentrates at depth, while coal etc. is
## spread across the whole underground.
const ORE_CONFIGS: Array = [
	[Chunk.Block.COAL_ORE, 20.0, 1.0, 4, 10],
	[Chunk.Block.IRON_ORE, 14.0, 0.85, 3, 8],
	[Chunk.Block.GOLD_ORE, 6.0, 0.50, 2, 5],
	[Chunk.Block.DIAMOND_ORE, 3.0, 0.25, 1, 4],
]


func _place_ores(rng: RandomNumberGenerator) -> void:
	var size: int = world_size_blocks
	var area: int = size * size
	for config: Array in ORE_CONFIGS:
		var block: int = config[0]
		var per_1k: float = config[1]
		var max_y_frac: float = config[2]
		var vein_min: int = config[3]
		var vein_max: int = config[4]
		var count: int = int(float(area) * per_1k / 1000.0)
		for _i: int in count:
			var x: int = rng.randi_range(1, size - 2)
			var z: int = rng.randi_range(1, size - 2)
			var surface: int = _find_surface_y(x, z)
			if surface < 8:
				continue  # skip thin terrain / pool holes
			var max_y: int = int(float(surface) * max_y_frac)
			if max_y <= 3:
				continue
			# Slight extra bias toward the bottom of the allowed range: a
			# squared random makes 0..1→0..1 with density weighted toward 0.
			# Mixed 70/30 with uniform so the bias is subtle, not cliff-like.
			var t: float = rng.randf()
			if rng.randf() < 0.7:
				t = t * t
			var y: int = 2 + int(t * float(max_y - 2))
			var vein_size: int = rng.randi_range(vein_min, vein_max)
			_place_ore_vein(x, y, z, vein_size, block, rng)


## Random-walk a small vein of `count` ore blocks from (cx, cy, cz). Only
## replaces STONE — dirt, air, and other ores stay put. Chunk reference
## isn't cached here because the walk scatters across chunks and a vein is
## tiny (3-10 blocks); the caching overhead wouldn't pay off.
func _place_ore_vein(cx: int, cy: int, cz: int, count: int, block: int, rng: RandomNumberGenerator) -> void:
	var placed: int = 0
	var attempts: int = 0
	var x: int = cx
	var y: int = cy
	var z: int = cz
	var size: int = world_size_blocks
	var max_attempts: int = count * 3
	while placed < count and attempts < max_attempts:
		attempts += 1
		x += rng.randi_range(-1, 1)
		y += rng.randi_range(-1, 1)
		z += rng.randi_range(-1, 1)
		if x < 0 or x >= size or y < 1 or y >= size or z < 0 or z >= size:
			continue
		var cp := Vector3i(x >> 4, y >> 4, z >> 4)
		var chunk: Chunk = chunks.get(cp)
		if chunk == null:
			continue
		var idx: int = (x & 15) + ((y & 15) << 4) + ((z & 15) << 8)
		if chunk.voxels[idx] == Chunk.Block.STONE:
			chunk.voxels[idx] = block
			placed += 1


func _place_flowers(rng: RandomNumberGenerator) -> void:
	var cell: int = 8                     # grid spacing between potential patch centers
	var patch_chance: float = 0.60        # "not rare but not uncommon"
	var radius: int = 2                   # max Chebyshev offset of flower from center
	for gx: int in range(2, world_size_blocks - 2, cell):
		for gz: int in range(2, world_size_blocks - 2, cell):
			if rng.randf() > patch_chance:
				continue
			# Patch center (jittered within the grid cell).
			var cx: int = gx + rng.randi_range(0, cell - 1)
			var cz: int = gz + rng.randi_range(0, cell - 1)
			# One flower type per patch — uniform look, Minecraft-style.
			var block: int = Chunk.Block.POPPY if rng.randf() < 0.5 else Chunk.Block.DANDELION
			var count: int = rng.randi_range(1, 5)
			for _i: int in count:
				var wx: int = cx + rng.randi_range(-radius, radius)
				var wz: int = cz + rng.randi_range(-radius, radius)
				if wx < 0 or wx >= world_size_blocks:
					continue
				if wz < 0 or wz >= world_size_blocks:
					continue
				# Find the surface. Only place on grass (beaches skip), and
				# only when the cell directly above is air (so we don't
				# clobber tree trunks or existing flowers in overlapping
				# patches).
				var gy: int = _find_surface_y(wx, wz)
				if gy < 0:
					continue
				if get_voxel(wx, gy, wz) != Chunk.Block.GRASS:
					continue
				if gy + 1 >= world_size_blocks:
					continue
				if get_voxel(wx, gy + 1, wz) != Chunk.Block.AIR:
					continue
				_gen_set(wx, gy + 1, wz, block)


func _place_trees(rng: RandomNumberGenerator) -> void:
	# Coarse grid so trees are spaced out; ~30% of grid cells get a tree.
	var cell: int = 6
	for gx: int in range(2, world_size_blocks - 2, cell):
		for gz: int in range(2, world_size_blocks - 2, cell):
			if rng.randf() > 0.3:
				continue
			var wx: int = gx + rng.randi_range(0, cell - 1)
			var wz: int = gz + rng.randi_range(0, cell - 1)
			if wx < 2 or wx >= world_size_blocks - 2:
				continue
			if wz < 2 or wz >= world_size_blocks - 2:
				continue
			# Find surface — must be grass (no trees on beaches).
			var gy: int = -1
			for wy: int in range(world_size_blocks - 1, -1, -1):
				var b: int = get_voxel(wx, wy, wz)
				if b != Chunk.Block.AIR:
					if b == Chunk.Block.GRASS:
						gy = wy
					break
			if gy < 0:
				continue
			if gy + 8 >= world_size_blocks:
				continue
			_place_tree(wx, gy, wz, rng)


# --- Async regeneration (emits progress signal) ---

func regenerate(size: int, terrain_type: int, seed: int = 0) -> void:
	generation_progress.emit(0.02, "Clearing old world...")
	_water_pending.clear()
	_water_accumulator = 0.0
	await get_tree().process_frame

	for chunk: Chunk in chunks.values():
		chunk.queue_free()
	chunks.clear()
	await get_tree().process_frame
	await get_tree().process_frame

	world_size_blocks = size
	world_size_chunks = size / CHUNK_SIZE
	current_terrain_type = terrain_type
	world_seed = seed if seed != 0 else _random_seed()
	ChunkGen.configure_noise(noise, biome_noise, world_seed, terrain_type)

	if terrain_type == TerrainType.FLATGRASS:
		generation_progress.emit(0.10, "Generating flatgrass...")
		await get_tree().process_frame
		await _generate_world_flatgrass()
		_setup_world_bounds()
		generation_progress.emit(1.0, "Done!")
		return

	generation_progress.emit(0.05, "Creating chunks...")
	await get_tree().process_frame

	_create_terrain_chunks()

	generation_progress.emit(0.10, "Generating terrain...")
	await get_tree().process_frame

	var total_cols: int = world_size_chunks * world_size_chunks
	var terrain_batch: int = maxi(1, total_cols / 20)
	for i: int in total_cols:
		_gen_column_task(i)
		if (i + 1) % terrain_batch == 0:
			generation_progress.emit(0.10 + 0.25 * float(i + 1) / float(total_cols), "Generating terrain... %d/%d" % [i + 1, total_cols])
			await get_tree().process_frame

	generation_progress.emit(0.38, "Placing features...")
	await get_tree().process_frame
	var feature_rng := RandomNumberGenerator.new()
	feature_rng.seed = world_seed
	_place_water_pools(feature_rng)
	# Caves first, then ores: caves carve natural mass only (ores are a
	# different block type), so ore veins placed afterward can happen to
	# appear in a cave wall — that's the classic "spot a vein while
	# exploring" moment and costs nothing.
	_carve_caves(feature_rng)
	_place_ores(feature_rng)
	_place_trees(feature_rng)
	_place_flowers(feature_rng)

	generation_progress.emit(0.42, "Building meshes...")
	await get_tree().process_frame

	var all_chunks: Array = chunks.values()
	var total: int = all_chunks.size()
	var mesh_batch: int = maxi(1, total / 40)
	var meshed: int = 0
	for j: int in total:
		var chunk: Chunk = all_chunks[j]
		if _chunk_has_solid(chunk):
			chunk._padded = _build_padded(chunk)
			chunk._use_padded = true
			chunk.generate_mesh(material, water_material)
			chunk._use_padded = false
			chunk._padded = PackedByteArray()
			meshed += 1
		if (j + 1) % mesh_batch == 0 or j == total - 1:
			generation_progress.emit(0.42 + 0.55 * float(j + 1) / float(total), "Building meshes... %d/%d" % [meshed, total])
			await get_tree().process_frame

	_setup_world_bounds()
	generation_progress.emit(1.0, "Done!")


# --- Save / Load voxel data ---

## Save the world to disk. Emits `generation_progress` during voxel
## collection + file write so the UI can show a progress bar (wired the
## same way as load_from_save / regenerate). Returns true on success.
##
## Fast path: iterates the populated chunks rather than calling get_voxel
## size³ times. All-air regions of the output buffer are already zero from
## resize(), so chunks that don't exist contribute nothing. For a 512³
## world this collects in ~500ms instead of minutes.
func save_to_file(save_name: String, player_pos: Vector3) -> bool:
	# "Preparing save..." — timer-based yield so the progress bar is visible
	# even on small worlds (which otherwise finish between frames, invisible).
	generation_progress.emit(0.04, "Preparing save...")
	await get_tree().create_timer(0.12).timeout

	var size: int = world_size_blocks
	var size2: int = size * size
	var data := PackedByteArray()
	data.resize(size * size * size)  # zero-initialized ⇒ air in all-air regions

	generation_progress.emit(0.10, "Collecting voxels...")
	await get_tree().create_timer(0.08).timeout

	var all_chunks: Array = chunks.values()
	var total: int = all_chunks.size()
	var batch: int = maxi(1, total / 30)
	for i: int in total:
		var chunk: Chunk = all_chunks[i]
		var cp: Vector3i = chunk.chunk_position
		var base_x: int = cp.x << 4
		var base_y: int = cp.y << 4
		var base_z: int = cp.z << 4
		var vox: PackedByteArray = chunk.voxels
		for lz: int in CHUNK_SIZE:
			var dst_z_off: int = (base_z + lz) * size2
			var src_z_off: int = lz << 8
			for ly: int in CHUNK_SIZE:
				var src_start: int = src_z_off + (ly << 4)
				var dst_start: int = base_x + (base_y + ly) * size + dst_z_off
				for lx: int in CHUNK_SIZE:
					data[dst_start + lx] = vox[src_start + lx]
		if (i + 1) % batch == 0 or i == total - 1:
			var p: float = 0.10 + 0.78 * float(i + 1) / float(total)
			generation_progress.emit(p, "Collecting voxels... %d/%d" % [i + 1, total])
			await get_tree().process_frame

	generation_progress.emit(0.90, "Writing file...")
	await get_tree().create_timer(0.10).timeout
	var ok: bool = SaveSystem.save_world(save_name, size, data, player_pos, world_seed, current_terrain_type)
	generation_progress.emit(1.0, "Saved!" if ok else "Save failed!")
	# Brief hold on the final state so the user registers the result.
	await get_tree().create_timer(0.20).timeout
	return ok


func load_from_save(size: int, voxel_data: PackedByteArray, seed: int = 0, terrain_type: int = TerrainType.VANILLA_DEFAULT) -> void:
	generation_progress.emit(0.02, "Clearing world...")
	_water_pending.clear()
	_water_accumulator = 0.0
	await get_tree().process_frame

	for chunk: Chunk in chunks.values():
		chunk.queue_free()
	chunks.clear()
	await get_tree().process_frame
	await get_tree().process_frame

	world_size_blocks = size
	world_size_chunks = size / CHUNK_SIZE
	world_seed = seed if seed != 0 else _random_seed()
	current_terrain_type = terrain_type

	generation_progress.emit(0.05, "Scanning save data...")
	await get_tree().process_frame

	# Phase 0: pre-scan a height-map from the flat save data. For every
	# world column (wx, wz) we find the topmost non-air y by scanning
	# downward. This tells us the maximum chunk-Y per 16×16 chunk column
	# so Phase 1 can skip all-air chunks (~90-97% of a 512³ world) without
	# touching their bytes — the single biggest speedup for large worlds.
	var size2: int = size * size
	var n_chunks: int = world_size_chunks
	# max_cy_col[cx + cz * n_chunks] = highest cy that has content.
	var max_cy_col := PackedInt32Array()
	max_cy_col.resize(n_chunks * n_chunks)
	max_cy_col.fill(-1)
	# Scan all columns — average early-exit after ~30 bytes so the total is
	# ~(size² × 30) iterations for a 512 world ≈ 8M. Fast.
	var scan_batch: int = maxi(1, size / 10)
	for wz: int in size:
		var wz_base: int = wz * size2
		var cz: int = wz >> 4
		for wx: int in size:
			var cx: int = wx >> 4
			var col_idx: int = cx + cz * n_chunks
			# If we already know this chunk column goes to the very top,
			# no point scanning more columns in it.
			if max_cy_col[col_idx] >= n_chunks - 1:
				continue
			var base: int = wz_base + wx
			for wy: int in range(size - 1, -1, -1):
				if voxel_data[base + wy * size] != 0:
					var cy: int = wy >> 4
					if cy > max_cy_col[col_idx]:
						max_cy_col[col_idx] = cy
					break
		if (wz + 1) % scan_batch == 0:
			generation_progress.emit(0.05 + 0.05 * float(wz + 1) / float(size), "Scanning...")
			await get_tree().process_frame

	generation_progress.emit(0.10, "Loading voxels...")
	await get_tree().process_frame

	# Phase 1: iterate only the chunk positions flagged as having content by
	# the height-map pre-scan. For each, bulk-copy the 4096 bytes from the
	# flat save data into a fresh chunk voxels array. No per-voxel Dict
	# lookups — the chunk is created once per position. Water-level is set
	# inline during the copy so we don't need a second pass.
	var total_content: int = 0
	for i: int in max_cy_col.size():
		if max_cy_col[i] >= 0:
			total_content += max_cy_col[i] + 1
	var loaded: int = 0
	var yield_every: int = maxi(1, total_content / 30)
	for cz: int in n_chunks:
		for cx: int in n_chunks:
			var max_cy: int = max_cy_col[cx + cz * n_chunks]
			if max_cy < 0:
				continue
			for cy: int in range(0, max_cy + 1):
				var bx: int = cx << 4
				var by: int = cy << 4
				var bz: int = cz << 4
				var cp := Vector3i(cx, cy, cz)
				var chunk: Chunk = _create_chunk(cp)
				for lz: int in 16:
					var row_z: int = (bz + lz) * size2
					var lz_off: int = lz << 8
					for ly: int in 16:
						var src: int = row_z + (by + ly) * size + bx
						var dst: int = (ly << 4) + lz_off
						for lx: int in 16:
							var v: int = voxel_data[src + lx]
							if ly == 0 and by == 0:
								v = Chunk.Block.WORLD_BEDROCK
							chunk.voxels[dst + lx] = v
							if v == Chunk.Block.WATER:
								chunk.water_level[dst + lx] = 1
				loaded += 1
				if loaded % yield_every == 0:
					var p: float = 0.10 + 0.30 * float(loaded) / float(maxi(1, total_content))
					generation_progress.emit(p, "Loading voxels... %d/%d chunks" % [loaded, total_content])
					await get_tree().process_frame

	generation_progress.emit(0.40, "Building meshes...")
	await get_tree().process_frame

	# Phase 2: mesh by cy layer, using the shared-mesh fast path when every
	# chunk at a layer has identical voxels (the flatgrass case + any world
	# where buried stone layers are fully solid). Non-uniform layers fall
	# back to per-chunk meshing. Collision + _arr_mesh remain per-chunk so
	# edits safely detach (see _detach_shared_mesh) without leaking to
	# siblings — the same contract flatgrass gen uses.
	var cy_to_chunks: Dictionary = {}  # int -> Array[Chunk]
	for chunk: Chunk in chunks.values():
		var cy: int = chunk.chunk_position.y
		if cy_to_chunks.has(cy):
			(cy_to_chunks[cy] as Array).append(chunk)
		else:
			cy_to_chunks[cy] = [chunk]

	var total: int = chunks.size()
	var processed: int = 0
	var meshed: int = 0
	var shared_layers: int = 0
	# Yield every MESH_YIELD_BATCH chunks so no single blocking run exceeds
	# ~50ms even on large layers with 1000+ non-uniform chunks.
	const MESH_YIELD_BATCH: int = 16
	for cy: int in cy_to_chunks:
		var layer: Array = cy_to_chunks[cy]
		var n: int = layer.size()
		var ref_chunk: Chunk = layer[0]

		# Uniformity check — compare every chunk's voxel + water_level array
		# against the reference. PackedByteArray == is a fast byte compare.
		var uniform: bool = n > 1
		if uniform:
			var ref_vox: PackedByteArray = ref_chunk.voxels
			var ref_wat: PackedByteArray = ref_chunk.water_level
			for k: int in range(1, n):
				var c: Chunk = layer[k]
				if c.voxels != ref_vox or c.water_level != ref_wat:
					uniform = false
					break

		if uniform and _chunk_has_solid(ref_chunk):
			ref_chunk._padded = _build_padded(ref_chunk)
			ref_chunk._use_padded = true
			ref_chunk.generate_mesh(material, water_material)
			ref_chunk._use_padded = false
			ref_chunk._padded = PackedByteArray()

			var tmpl_mesh: ArrayMesh = ref_chunk._arr_mesh
			var shared_mesh := ArrayMesh.new()
			var solid_verts := PackedVector3Array()
			for s: int in tmpl_mesh.get_surface_count():
				var arrays: Array = tmpl_mesh.surface_get_arrays(s)
				shared_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var mat: Material = tmpl_mesh.surface_get_material(s)
				if mat != null:
					shared_mesh.surface_set_material(s, mat)
				if s == 0:
					solid_verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array

			for k: int in range(1, n):
				var c: Chunk = layer[k]
				c._stored_mat = material
				c._water_mat = water_material
				c.mesh = shared_mesh
				if c._physics_ready:
					PhysicsServer3D.shape_set_data(c._shape_rid, {"faces": solid_verts, "backface_collision": true})
			meshed += n
			processed += n
			shared_layers += 1
			generation_progress.emit(0.40 + 0.57 * float(processed) / float(maxi(1, total)),
				"Building meshes... %d/%d (%d shared)" % [meshed, total, shared_layers])
			await get_tree().process_frame
		else:
			# Per-chunk fallback — yield every MESH_YIELD_BATCH chunks so
			# large non-uniform layers (surface layer with caves/ores, often
			# 1000+ chunks) don't freeze the game for 15+ seconds.
			var since_yield: int = 0
			for c: Chunk in layer:
				if _chunk_has_solid(c):
					c._padded = _build_padded(c)
					c._use_padded = true
					c.generate_mesh(material, water_material)
					c._use_padded = false
					c._padded = PackedByteArray()
					meshed += 1
				processed += 1
				since_yield += 1
				if since_yield >= MESH_YIELD_BATCH:
					since_yield = 0
					generation_progress.emit(0.40 + 0.57 * float(processed) / float(maxi(1, total)),
						"Building meshes... %d/%d" % [meshed, total])
					await get_tree().process_frame

	_setup_world_bounds()
	generation_progress.emit(1.0, "Done!")
