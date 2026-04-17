class_name ChunkGen

# Pure, stateless chunk generation. Given (seed, terrain_type, world_size,
# chunk_pos), deterministically produces a padded 18³ voxel buffer for that
# chunk. Safe to call from worker threads — creates thread-local noise
# instances every call (creation is cheap).

const CHUNK_SIZE: int = 16
const VOLUME: int = 4096       # 16³
const PADDED: int = 18         # 16 + 1-voxel border on each side
const PADDED_VOLUME: int = 5832  # 18³
const PADDED_Y: int = 18
const PADDED_Z: int = 324

# Biome IDs — mirror World's
const BIOME_PLAINS: int = 0
const BIOME_BEACH: int = 1

# Terrain types — mirror World.TerrainType
const TERRAIN_FLATGRASS: int = 0
const TERRAIN_VANILLA_DEFAULT: int = 1
const TERRAIN_VANILLA_HILLY: int = 2

# Feature grid spacings
const TREE_GRID: int = 6
const POOL_GRID: int = 10



static func configure_noise(t_noise: FastNoiseLite, b_noise: FastNoiseLite, seed: int, terrain_type: int) -> void:
	t_noise.seed = seed
	t_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	t_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	t_noise.fractal_lacunarity = 2.0
	t_noise.fractal_gain = 0.5
	if terrain_type == TERRAIN_VANILLA_HILLY:
		t_noise.frequency = 0.02
		t_noise.fractal_octaves = 4
	else:
		t_noise.frequency = 0.012
		t_noise.fractal_octaves = 3
	b_noise.seed = seed ^ 0x5A5A5A5A
	b_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	b_noise.frequency = 0.015


static func sample_height(t_noise: FastNoiseLite, wx: int, wz: int, terrain_type: int, world_size: int) -> int:
	var n: float = t_noise.get_noise_2d(float(wx), float(wz))
	var h: int
	if terrain_type == TERRAIN_VANILLA_HILLY:
		h = int((n + 1.0) * 0.5 * 40.0) + 8
	else:
		var base: int = maxi(20, world_size / 3)
		h = int((n + 1.0) * 0.5 * 14.0) + base
	return clampi(h, 1, world_size - 2)


static func sample_biome(b_noise: FastNoiseLite, wx: int, wz: int) -> int:
	var b: float = b_noise.get_noise_2d(float(wx), float(wz))
	return BIOME_BEACH if b > 0.35 else BIOME_PLAINS


## Deterministic 32-bit hash from seed + two ints, used as a per-grid-cell
## RNG seed for feature placement.
static func _hash_cell(seed: int, a: int, b: int) -> int:
	var h: int = seed
	h = ((h * 1103515245) + a * 374761393) & 0x7FFFFFFF
	h = ((h * 1103515245) + b * 668265263) & 0x7FFFFFFF
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	if h == 0:
		h = 1
	return h


## Pre-compute every tree whose voxels could reach any cell of this chunk's
## padded region. Returns an Array of tree dicts with keys: root_x, root_y,
## root_z, trunk_h.
static func _trees_near_chunk(
	chunk_pos: Vector3i, seed: int, terrain_type: int, world_size: int,
	t_noise: FastNoiseLite, b_noise: FastNoiseLite
) -> Array:
	var trees: Array = []
	# Tree canopy spans ±2 blocks in XZ from the root, so any tree whose
	# root is within TREE_REACH blocks of the chunk boundary may touch it.
	const TREE_REACH: int = 3  # 2 for canopy + 1 for padded border
	var min_x: int = chunk_pos.x * CHUNK_SIZE - TREE_REACH
	var max_x: int = chunk_pos.x * CHUNK_SIZE + CHUNK_SIZE + TREE_REACH
	var min_z: int = chunk_pos.z * CHUNK_SIZE - TREE_REACH
	var max_z: int = chunk_pos.z * CHUNK_SIZE + CHUNK_SIZE + TREE_REACH

	var gmin_x: int = int(floor(float(min_x) / float(TREE_GRID)))
	var gmax_x: int = int(floor(float(max_x) / float(TREE_GRID)))
	var gmin_z: int = int(floor(float(min_z) / float(TREE_GRID)))
	var gmax_z: int = int(floor(float(max_z) / float(TREE_GRID)))

	var rng := RandomNumberGenerator.new()
	for gx: int in range(gmin_x, gmax_x + 1):
		for gz: int in range(gmin_z, gmax_z + 1):
			rng.seed = _hash_cell(seed ^ 0xA3C1B7, gx, gz)
			if rng.randf() > 0.3:
				continue
			var off_x: int = rng.randi_range(0, TREE_GRID - 1)
			var off_z: int = rng.randi_range(0, TREE_GRID - 1)
			var root_x: int = gx * TREE_GRID + off_x
			var root_z: int = gz * TREE_GRID + off_z
			if root_x < 2 or root_z < 2:
				continue
			if root_x >= world_size - 2 or root_z >= world_size - 2:
				continue
			var biome: int = sample_biome(b_noise, root_x, root_z)
			if biome != BIOME_PLAINS:
				continue
			var root_y: int = sample_height(t_noise, root_x, root_z, terrain_type, world_size)
			var trunk_h: int = 4 + (rng.randi() % 3)  # 4..6
			if root_y + trunk_h + 2 >= world_size:
				continue
			trees.append({
				"root_x": root_x,
				"root_y": root_y,
				"root_z": root_z,
				"trunk_h": trunk_h,
			})
	return trees


## Query: given (wx, wy, wz), return the tree block for this cell (or 0 if
## the cell isn't part of any tree in the list).
static func _tree_block_at(trees: Array, wx: int, wy: int, wz: int) -> int:
	for tree: Dictionary in trees:
		var rx: int = tree["root_x"]
		var ry: int = tree["root_y"]
		var rz: int = tree["root_z"]
		var trunk_h: int = tree["trunk_h"]
		var top: int = ry + trunk_h
		var dx: int = wx - rx
		var dz: int = wz - rz

		# Trunk column
		if dx == 0 and dz == 0 and wy > ry and wy <= top:
			return Chunk.Block.LOG

		var ax: int = absi(dx)
		var az: int = absi(dz)

		# 5x5 leaf layers at top-1 and top (corners trimmed)
		if (wy == top - 1 or wy == top) and ax <= 2 and az <= 2:
			if dx == 0 and dz == 0:
				continue  # already handled by trunk
			if ax == 2 and az == 2:
				continue  # trimmed corner
			return Chunk.Block.LEAVES

		# 3x3 leaf layer at top+1 (corners trimmed)
		if wy == top + 1 and ax <= 1 and az <= 1:
			if ax == 1 and az == 1:
				continue  # trimmed corner
			return Chunk.Block.LEAVES

		# Single leaf cap at top+2
		if wy == top + 2 and dx == 0 and dz == 0:
			return Chunk.Block.LEAVES

	return 0


## Pre-compute every water pool affecting this chunk. Returns Array of dicts
## with keys: cx, cy (surface y), cz, radius.
static func _pools_near_chunk(
	chunk_pos: Vector3i, seed: int, terrain_type: int, world_size: int,
	t_noise: FastNoiseLite, b_noise: FastNoiseLite
) -> Array:
	var pools: Array = []
	const POOL_REACH: int = 5  # max pool radius + border
	var min_x: int = chunk_pos.x * CHUNK_SIZE - POOL_REACH
	var max_x: int = chunk_pos.x * CHUNK_SIZE + CHUNK_SIZE + POOL_REACH
	var min_z: int = chunk_pos.z * CHUNK_SIZE - POOL_REACH
	var max_z: int = chunk_pos.z * CHUNK_SIZE + CHUNK_SIZE + POOL_REACH

	var gmin_x: int = int(floor(float(min_x) / float(POOL_GRID)))
	var gmax_x: int = int(floor(float(max_x) / float(POOL_GRID)))
	var gmin_z: int = int(floor(float(min_z) / float(POOL_GRID)))
	var gmax_z: int = int(floor(float(max_z) / float(POOL_GRID)))

	var rng := RandomNumberGenerator.new()
	for gx: int in range(gmin_x, gmax_x + 1):
		for gz: int in range(gmin_z, gmax_z + 1):
			rng.seed = _hash_cell(seed ^ 0x5F4D9E, gx, gz)
			if rng.randf() > 0.25:
				continue
			var off_x: int = rng.randi_range(0, POOL_GRID - 1)
			var off_z: int = rng.randi_range(0, POOL_GRID - 1)
			var cx: int = gx * POOL_GRID + off_x
			var cz: int = gz * POOL_GRID + off_z
			if cx < 4 or cz < 4:
				continue
			if cx >= world_size - 4 or cz >= world_size - 4:
				continue
			var cy: int = sample_height(t_noise, cx, cz, terrain_type, world_size)
			if cy < 2:
				continue
			pools.append({
				"cx": cx,
				"cy": cy,
				"cz": cz,
				"radius": 2 + (rng.randi() % 3),  # 2..4
			})
	return pools


## Query: pool override at (wx, wy, wz). Returns one of:
##   -1 : no pool affects this cell (use base terrain)
##    0 : AIR (carved rim)
##    WATER block id
static func _pool_block_at(pools: Array, wx: int, wy: int, wz: int) -> int:
	for pool: Dictionary in pools:
		var cx: int = pool["cx"]
		var cy: int = pool["cy"]
		var cz: int = pool["cz"]
		var radius: int = pool["radius"]
		var dx: int = wx - cx
		var dz: int = wz - cz
		var dist: int = absi(dx) + absi(dz)
		if dist > radius:
			continue
		# Surface rim is carved to air.
		if wy == cy:
			return 0
		# Water sits one block below the rim.
		if wy == cy - 1:
			return Chunk.Block.WATER
	return -1


## Generate 18³ padded voxels for a chunk. This includes this chunk's
## interior 16³ voxels plus the 1-voxel border from neighbor chunks, all
## computed deterministically from seed. The mesh builder reads directly
## from this buffer so no cross-chunk lookups are needed.
## Pass pre-created noise instances to avoid the ~2ms Resource allocation
## cost per call. If null, creates them locally (for one-off calls).
static func generate_padded_voxels(
	chunk_pos: Vector3i, seed: int, terrain_type: int, world_size: int,
	t_noise: FastNoiseLite = null, b_noise: FastNoiseLite = null
) -> PackedByteArray:
	if t_noise == null:
		t_noise = FastNoiseLite.new()
		b_noise = FastNoiseLite.new()
		configure_noise(t_noise, b_noise, seed, terrain_type)

	var base_x: int = chunk_pos.x * CHUNK_SIZE - 1
	var base_y: int = chunk_pos.y * CHUNK_SIZE - 1
	var base_z: int = chunk_pos.z * CHUNK_SIZE - 1

	# Pre-compute heights and per-column top/sub blocks for the full 18x18
	# XZ slice (including border).
	var heights := PackedInt32Array()
	heights.resize(PADDED * PADDED)
	var top_blocks := PackedByteArray()
	top_blocks.resize(PADDED * PADDED)
	var sub_blocks := PackedByteArray()
	sub_blocks.resize(PADDED * PADDED)

	for pz: int in PADDED:
		for px: int in PADDED:
			var wx: int = base_x + px
			var wz: int = base_z + pz
			var ci: int = px + pz * PADDED
			if wx < 0 or wz < 0 or wx >= world_size or wz >= world_size:
				heights[ci] = -1
				top_blocks[ci] = Chunk.Block.GRASS
				sub_blocks[ci] = Chunk.Block.DIRT
				continue
			heights[ci] = sample_height(t_noise, wx, wz, terrain_type, world_size)
			var biome: int = sample_biome(b_noise, wx, wz)
			if biome == BIOME_BEACH:
				top_blocks[ci] = Chunk.Block.SAND
				sub_blocks[ci] = Chunk.Block.SAND
			else:
				top_blocks[ci] = Chunk.Block.GRASS
				sub_blocks[ci] = Chunk.Block.DIRT

	# Pre-compute features affecting this chunk.
	var trees: Array = _trees_near_chunk(chunk_pos, seed, terrain_type, world_size, t_noise, b_noise)
	var pools: Array = _pools_near_chunk(chunk_pos, seed, terrain_type, world_size, t_noise, b_noise)

	# Fill the padded voxel buffer.
	var padded := PackedByteArray()
	padded.resize(PADDED_VOLUME)
	# PackedByteArray.resize() already zero-fills, so air cells are correct
	# by default.

	for pz: int in PADDED:
		for px: int in PADDED:
			var ci: int = px + pz * PADDED
			var h: int = heights[ci]
			if h < 0:
				continue  # out of world in XZ → all air
			var tb: int = top_blocks[ci]
			var sb: int = sub_blocks[ci]
			var wx: int = base_x + px
			var wz: int = base_z + pz

			for py: int in PADDED:
				var wy: int = base_y + py
				if wy < 0 or wy >= world_size:
					continue  # leave as air
				var block: int
				if wy == 0:
					block = Chunk.Block.WORLD_BEDROCK
				elif wy > h:
					block = 0
				elif wy == h:
					block = tb
				elif wy > h - 4:
					block = sb
				else:
					block = Chunk.Block.STONE

				# Pools override surface cells.
				if not pools.is_empty() and wy >= h - 1 and wy <= h:
					var pool_block: int = _pool_block_at(pools, wx, wy, wz)
					if pool_block >= 0:
						block = pool_block

				# Trees override air above the terrain.
				if not trees.is_empty() and wy > h and wy <= h + 10:
					var tb_block: int = _tree_block_at(trees, wx, wy, wz)
					if tb_block != 0:
						block = tb_block

				padded[px + py * PADDED_Y + pz * PADDED_Z] = block

	return padded


## Extract the interior 16³ voxels from a padded 18³ buffer into a fresh
## PackedByteArray. This is what the Chunk node stores as .voxels.
static func extract_interior(padded: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(VOLUME)
	for z: int in CHUNK_SIZE:
		for y: int in CHUNK_SIZE:
			for x: int in CHUNK_SIZE:
				var pidx: int = (x + 1) + (y + 1) * PADDED_Y + (z + 1) * PADDED_Z
				out[x + (y << 4) + (z << 8)] = padded[pidx]
	return out
