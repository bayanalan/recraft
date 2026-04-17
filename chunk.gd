class_name Chunk
extends MeshInstance3D

const SIZE: int = 16
const VOLUME: int = SIZE * SIZE * SIZE

enum Block {
	AIR = 0,
	# Originals (1-10) — IDs preserved for save compat
	STONE = 1,
	COBBLESTONE = 2,
	BRICK = 3,
	DIRT = 4,
	PLANKS = 5,
	LOG = 6,
	LEAVES = 7,
	GLASS = 8,
	SAND = 9,
	GRASS = 10,
	# New additions (11-27)
	MOSSY_COBBLESTONE = 11,
	BEDROCK = 12,
	OBSIDIAN = 13,
	BOOKSHELF = 14,
	SPONGE = 15,
	TNT = 16,
	IRON_BLOCK = 17,
	GOLD_BLOCK = 18,
	COAL_ORE = 19,
	IRON_ORE = 20,
	GOLD_ORE = 21,
	DIAMOND_ORE = 22,
	WOOL_WHITE = 23,
	WOOL_RED = 24,
	WOOL_YELLOW = 25,
	WOOL_GREEN = 26,
	WOOL_BLUE = 27,
	# Special: world boundary bedrock — unbreakable, only generated at y=0
	WORLD_BEDROCK = 28,
	# Fluids
	WATER = 29,
	# Remaining classic-Minecraft wool colors (30-40). IDs appended after
	# WATER to preserve save compatibility for all earlier worlds.
	WOOL_ORANGE = 30,
	WOOL_MAGENTA = 31,
	WOOL_LIGHT_BLUE = 32,
	WOOL_LIME = 33,
	WOOL_PINK = 34,
	WOOL_GRAY = 35,
	WOOL_LIGHT_GRAY = 36,
	WOOL_CYAN = 37,
	WOOL_PURPLE = 38,
	WOOL_BROWN = 39,
	WOOL_BLACK = 40,
	# New additions (41-45): fire, lava, smooth stone / slab, barrier.
	FIRE = 41,
	LAVA = 42,
	SMOOTH_STONE = 43,
	SMOOTH_STONE_SLAB = 44,
	BARRIER = 45,
	POPPY = 46,
	DANDELION = 47,
	TORCH = 48,
}

# Face direction constants
const DIR_YP: int = 0
const DIR_YN: int = 1
const DIR_XP: int = 2
const DIR_XN: int = 3
const DIR_ZP: int = 4
const DIR_ZN: int = 5

const NORMALS: Array[Vector3] = [
	Vector3(0,1,0), Vector3(0,-1,0),
	Vector3(1,0,0), Vector3(-1,0,0),
	Vector3(0,0,1), Vector3(0,0,-1),
]

# 6 vertices per face direction: offsets from block origin
# Each face has 2 triangles = 6 vertices
const FACE_VERTS: Array[Array] = [
	# DIR_YP (top) — at y+1
	[Vector3(0,1,0), Vector3(0,1,1), Vector3(1,1,1), Vector3(0,1,0), Vector3(1,1,1), Vector3(1,1,0)],
	# DIR_YN (bottom) — at y
	[Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1), Vector3(0,0,0), Vector3(1,0,1), Vector3(0,0,1)],
	# DIR_XP (east) — at x+1
	[Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(1,0,0), Vector3(1,1,1), Vector3(1,0,1)],
	# DIR_XN (west) — at x
	[Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,1), Vector3(0,0,0), Vector3(0,1,1), Vector3(0,1,0)],
	# DIR_ZP (south) — at z+1
	[Vector3(0,0,1), Vector3(1,0,1), Vector3(1,1,1), Vector3(0,0,1), Vector3(1,1,1), Vector3(0,1,1)],
	# DIR_ZN (north) — at z
	[Vector3(0,0,0), Vector3(0,1,0), Vector3(1,1,0), Vector3(0,0,0), Vector3(1,1,0), Vector3(1,0,0)],
]

# UV templates per face (flipped V for side faces)
const FACE_UVS: Array[Array] = [
	# DIR_YP
	[Vector2(0,0), Vector2(0,1), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(1,0)],
	# DIR_YN
	[Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(0,1)],
	# DIR_XP (V flipped for side)
	[Vector2(0,1), Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,0), Vector2(1,1)],
	# DIR_XN
	[Vector2(0,1), Vector2(1,1), Vector2(1,0), Vector2(0,1), Vector2(1,0), Vector2(0,0)],
	# DIR_ZP
	[Vector2(0,1), Vector2(1,1), Vector2(1,0), Vector2(0,1), Vector2(1,0), Vector2(0,0)],
	# DIR_ZN
	[Vector2(0,1), Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,0), Vector2(1,1)],
]

# AO corner-to-vertex mapping per face direction
# Which AO corner (0-3) maps to which of the 6 vertices
const FACE_AO_MAP: Array[Array] = [
	[0, 3, 2, 0, 2, 1],  # DIR_YP
	[0, 1, 2, 0, 2, 3],  # DIR_YN
	[0, 1, 2, 0, 2, 3],  # DIR_XP
	[0, 3, 2, 0, 2, 1],  # DIR_XN
	[0, 1, 2, 0, 2, 3],  # DIR_ZP
	[0, 3, 2, 0, 2, 1],  # DIR_ZN
]

# Neighbor offsets per direction
const DIR_OFFSETS: Array[Vector3i] = [
	Vector3i(0,1,0), Vector3i(0,-1,0),
	Vector3i(1,0,0), Vector3i(-1,0,0),
	Vector3i(0,0,1), Vector3i(0,0,-1),
]

# For each face direction, the 4 in-plane neighbor offsets in UV-edge order:
# (u=0, u=1, v=0, v=1). Used to compute the glass connection mask so adjacent
# glass blocks merge their frames. See voxel.gdshader connected_textures.
const GLASS_CONNECT_OFFSETS: Array[Array] = [
	# DIR_YP: UV U=X, V=Z
	[Vector3i(-1,0,0), Vector3i(1,0,0), Vector3i(0,0,-1), Vector3i(0,0,1)],
	# DIR_YN: same mapping
	[Vector3i(-1,0,0), Vector3i(1,0,0), Vector3i(0,0,-1), Vector3i(0,0,1)],
	# DIR_XP: UV U=Z, V=-Y (so v=0 = +Y, v=1 = -Y)
	[Vector3i(0,0,-1), Vector3i(0,0,1), Vector3i(0,1,0), Vector3i(0,-1,0)],
	# DIR_XN: same
	[Vector3i(0,0,-1), Vector3i(0,0,1), Vector3i(0,1,0), Vector3i(0,-1,0)],
	# DIR_ZP: UV U=X, V=-Y
	[Vector3i(-1,0,0), Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0)],
	# DIR_ZN: same
	[Vector3i(-1,0,0), Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0)],
]

# --- Water rendering ---
# Maximum water height: water is shorter than a full block.
const WATER_SOURCE_HEIGHT: float = 0.875
# Height contribution when water is "above" a corner (falling water fills
# all the way to the top of the cell).
const WATER_TOP_HEIGHT: float = 1.0

# For each face direction, for each of the 6 vertices, the corner index
# (0-3) if the vertex is on the top edge of the face, else -1.
# Corner 0 = (x=0, z=0), 1 = (x=1, z=0), 2 = (x=1, z=1), 3 = (x=0, z=1).
const WATER_TOP_CORNER_MAP: Array[Array] = [
	# DIR_YP — all 6 vertices are at y=1
	[0, 3, 2, 0, 2, 1],
	# DIR_YN — none (bottom face)
	[-1, -1, -1, -1, -1, -1],
	# DIR_XP (+X side)
	[-1, 1, 2, -1, 2, -1],
	# DIR_XN (-X side)
	[-1, -1, 3, -1, 3, 0],
	# DIR_ZP (+Z side)
	[-1, -1, 2, -1, 2, 3],
	# DIR_ZN (-Z side)
	[-1, 0, 1, -1, 1, -1],
]

# Cells contributing to each corner (in XZ at this cell's y).
# Each corner is shared by 4 cells. Offsets are (dx, dz) at the cell's y.
const WATER_CORNER_CELLS: Array[Array] = [
	# Corner 0: local (x=0, z=0)
	[Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)],
	# Corner 1: local (x=1, z=0)
	[Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0)],
	# Corner 2: local (x=1, z=1)
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	# Corner 3: local (x=0, z=1)
	[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1)],
]

var voxels := PackedByteArray()
# Per-voxel water flow level. 0 = not water (or water with no explicit
# level — treated as full). 1 = source (full height). 2..8 = flowing, getting
# progressively thinner at the top.
var water_level := PackedByteArray()
var chunk_position := Vector3i.ZERO
var world: Node = null
# Set before threaded mesh building so get_voxel uses fast array reads
# instead of cross-chunk Dict lookups. Cleared after mesh data is built.
var _padded: PackedByteArray
var _use_padded: bool = false

# Persistent ArrayMesh
var _arr_mesh := ArrayMesh.new()

# Physics RIDs
var _body_rid: RID
var _shape_rid: RID
var _physics_ready: bool = false

# Slot-based mesh: each face occupies 6 consecutive vertices
# _block_slots maps block local pos -> array of slot start indices
var _block_slots: Dictionary = {}  # Vector3i -> PackedInt32Array
var _free_slots: PackedInt32Array = PackedInt32Array()

# Vertex arrays (fixed capacity, degenerate triangles for empty slots)
var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _slot_count: int = 0  # total slots allocated
var _mesh_dirty: bool = false
var _stored_mat: Material = null
var _water_mat: Material = null
# Tracks whether any water face has been written. Lets `_apply_mesh` skip the
# (expensive) solid/water vertex split when the chunk has no water at all.
var _has_water_faces: bool = false
# Fire / lava faces are rendered via the voxel shader (in the solid surface)
# but MUST NOT be included in the collision mesh — the player walks through
# them. When this flag is set, `_apply_mesh` filters the collision verts to
# drop fire (tile 44) and lava (tile 45).
var _has_noncollidable_faces: bool = false


func _init() -> void:
	voxels.resize(VOLUME)
	voxels.fill(0)
	water_level.resize(VOLUME)
	water_level.fill(0)
	mesh = _arr_mesh


func _ready() -> void:
	_init_physics()


func _init_physics() -> void:
	if _physics_ready:
		return
	_body_rid = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(_body_rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(_body_rid, get_world_3d().space)
	PhysicsServer3D.body_set_state(_body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
	_shape_rid = PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.body_add_shape(_body_rid, _shape_rid)
	_physics_ready = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _physics_ready:
		PhysicsServer3D.free_rid(_body_rid)
		PhysicsServer3D.free_rid(_shape_rid)


func _idx(x: int, y: int, z: int) -> int:
	return x + (y << 4) + (z << 8)


func get_voxel(x: int, y: int, z: int) -> int:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE and z >= 0 and z < SIZE:
		return voxels[_idx(x, y, z)]
	if _use_padded:
		var px: int = x + 1
		var py: int = y + 1
		var pz: int = z + 1
		if px >= 0 and px < 18 and py >= 0 and py < 18 and pz >= 0 and pz < 18:
			return _padded[px + py * 18 + pz * 324]
		return Block.AIR
	if world != null:
		return world.get_voxel(
			chunk_position.x * SIZE + x,
			chunk_position.y * SIZE + y,
			chunk_position.z * SIZE + z)
	return Block.AIR


func get_water_level_local(x: int, y: int, z: int) -> int:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE and z >= 0 and z < SIZE:
		return water_level[_idx(x, y, z)]
	if _use_padded:
		var px: int = x + 1
		var py: int = y + 1
		var pz: int = z + 1
		if px >= 0 and px < 18 and py >= 0 and py < 18 and pz >= 0 and pz < 18:
			return 1 if _padded[px + py * 18 + pz * 324] == Block.WATER else 0
		return 0
	if world != null:
		return world.get_water_level_at(
			chunk_position.x * SIZE + x,
			chunk_position.y * SIZE + y,
			chunk_position.z * SIZE + z)
	return 0


## Water height from a level (1..8). Source = WATER_SOURCE_HEIGHT.
static func _water_height_from_level(lvl: int) -> float:
	if lvl <= 0:
		lvl = 1
	return WATER_SOURCE_HEIGHT * float(9 - lvl) / 8.0


## Compute the 4 top-face corner heights for a fluid block (water OR lava).
## Each corner looks at the 4 cells sharing it; if a cell's block above is
## the same fluid, the corner snaps up to WATER_TOP_HEIGHT (falling fluid),
## otherwise uses the cell's own level-based height. Corners take the maximum
## contribution, so adjacent fluid blocks at different levels meet smoothly
## instead of showing a hard staircase.
func _compute_fluid_corners(x: int, y: int, z: int, out_heights: PackedFloat32Array, fluid: int) -> void:
	var own_lvl: int = water_level[_idx(x, y, z)]
	if own_lvl <= 0:
		own_lvl = 1
	var own_h: float = _water_height_from_level(own_lvl)

	for ci: int in 4:
		var max_h: float = 0.0
		var contributed: bool = false
		var cells: Array = WATER_CORNER_CELLS[ci]
		for k: int in 4:
			var off: Vector2i = cells[k]
			var cx: int = x + off.x
			var cz: int = z + off.y
			# Same fluid directly above -> falling fluid, full height.
			if get_voxel(cx, y + 1, cz) == fluid:
				if WATER_TOP_HEIGHT > max_h:
					max_h = WATER_TOP_HEIGHT
				contributed = true
				continue
			if get_voxel(cx, y, cz) == fluid:
				var n_lvl: int = get_water_level_local(cx, y, cz)
				var h: float = _water_height_from_level(n_lvl)
				if h > max_h:
					max_h = h
				contributed = true
		if not contributed:
			max_h = own_h
		out_heights[ci] = max_h


func set_voxel(x: int, y: int, z: int, value: int) -> void:
	var idx: int = _idx(x, y, z)
	voxels[idx] = value
	# Level array is shared between water and lava — clear it for anything
	# else so stale values don't leak across block types.
	if value != Block.WATER and value != Block.LAVA:
		water_level[idx] = 0


static func _tile_index(block_type: int, face_dir: int) -> float:
	match block_type:
		Block.STONE: return 0.0
		Block.COBBLESTONE: return 1.0
		Block.BRICK: return 2.0
		Block.DIRT: return 3.0
		Block.PLANKS: return 4.0
		Block.LOG:
			return 6.0 if face_dir == DIR_YP or face_dir == DIR_YN else 5.0
		Block.LEAVES: return 7.0
		Block.GLASS: return 8.0
		Block.SAND: return 9.0
		Block.GRASS:
			return 10.0 if face_dir == DIR_YP else (3.0 if face_dir == DIR_YN else 11.0)
		Block.MOSSY_COBBLESTONE: return 12.0
		Block.BEDROCK: return 13.0
		Block.OBSIDIAN: return 14.0
		Block.BOOKSHELF:
			# Top/bottom = planks (tile 4), sides = bookshelf (tile 15)
			return 4.0 if face_dir == DIR_YP or face_dir == DIR_YN else 15.0
		Block.SPONGE: return 16.0
		Block.TNT:
			if face_dir == DIR_YP: return 17.0
			elif face_dir == DIR_YN: return 19.0
			else: return 18.0
		Block.IRON_BLOCK: return 20.0
		Block.GOLD_BLOCK: return 21.0
		Block.COAL_ORE: return 22.0
		Block.IRON_ORE: return 23.0
		Block.GOLD_ORE: return 24.0
		Block.DIAMOND_ORE: return 25.0
		Block.WOOL_WHITE: return 26.0
		Block.WOOL_RED: return 27.0
		Block.WOOL_YELLOW: return 28.0
		Block.WOOL_GREEN: return 29.0
		Block.WOOL_BLUE: return 30.0
		Block.WOOL_ORANGE: return 33.0
		Block.WOOL_MAGENTA: return 34.0
		Block.WOOL_LIGHT_BLUE: return 35.0
		Block.WOOL_LIME: return 36.0
		Block.WOOL_PINK: return 37.0
		Block.WOOL_GRAY: return 38.0
		Block.WOOL_LIGHT_GRAY: return 39.0
		Block.WOOL_CYAN: return 40.0
		Block.WOOL_PURPLE: return 41.0
		Block.WOOL_BROWN: return 42.0
		Block.WOOL_BLACK: return 43.0
		Block.FIRE: return 44.0
		Block.LAVA: return 45.0
		Block.SMOOTH_STONE: return 46.0
		Block.SMOOTH_STONE_SLAB: return 46.0  # reuses smooth stone tile
		Block.BARRIER: return 47.0
		Block.POPPY: return 48.0
		Block.DANDELION: return 49.0
		Block.TORCH: return 50.0
		Block.WORLD_BEDROCK: return 13.0  # same texture as BEDROCK
		Block.WATER: return 32.0
	return 0.0


## Return true if `b` is an opaque full-cube block — anything that fully
## hides the adjacent neighbor's face. Fluids, fire, glass, barrier, slabs,
## and plants are NOT opaque (they don't fill the whole cell or the shader
## renders them with alpha-cut), so neighbors should still draw against
## them.
static func _is_opaque_neighbor(b: int) -> bool:
	if b == 0:
		return false
	if b == Block.WATER or b == Block.LAVA or b == Block.FIRE:
		return false
	if b == Block.GLASS or b == Block.BARRIER:
		return false
	if b == Block.SMOOTH_STONE_SLAB:
		return false
	if b == Block.POPPY or b == Block.DANDELION or b == Block.TORCH:
		return false
	return true


func _vao(s1: int, s2: int, c: int) -> int:
	if s1 == 1 and s2 == 1:
		return 0
	return 3 - (s1 + s2 + c)


## 256-byte lookup: 1 = block IDs that occlude (cast ambient occlusion),
## 0 = transparent / partial-volume blocks that shouldn't. Barriers, glass,
## fluids, fire, plants, and slabs all return 0 so they don't darken their
## neighbors. Shared between `_is_solid` (method path) and `_compute_ao_padded`
## (fast path) so both AO paths agree.
static var _AO_OPAQUE: PackedByteArray = _build_ao_opaque_table()


static func _build_ao_opaque_table() -> PackedByteArray:
	var t := PackedByteArray()
	t.resize(256)
	for i: int in 256:
		t[i] = 1 if _is_opaque_neighbor(i) else 0
	return t


func _is_solid(x: int, y: int, z: int) -> int:
	return _AO_OPAQUE[get_voxel(x, y, z)]


# Compute AO for 4 corners of a face (standard path for live edits)
func _compute_ao(x: int, y: int, z: int, face_dir: int) -> PackedFloat32Array:
	var ao := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	var nx: int; var ny: int; var nz: int
	match face_dir:
		DIR_YP:
			ny = y + 1
			ao[0] = float(_vao(_is_solid(x-1,ny,z), _is_solid(x,ny,z-1), _is_solid(x-1,ny,z-1))) / 3.0
			ao[1] = float(_vao(_is_solid(x+1,ny,z), _is_solid(x,ny,z-1), _is_solid(x+1,ny,z-1))) / 3.0
			ao[2] = float(_vao(_is_solid(x+1,ny,z), _is_solid(x,ny,z+1), _is_solid(x+1,ny,z+1))) / 3.0
			ao[3] = float(_vao(_is_solid(x-1,ny,z), _is_solid(x,ny,z+1), _is_solid(x-1,ny,z+1))) / 3.0
		DIR_YN:
			ny = y - 1
			ao[0] = float(_vao(_is_solid(x-1,ny,z), _is_solid(x,ny,z-1), _is_solid(x-1,ny,z-1))) / 3.0
			ao[1] = float(_vao(_is_solid(x+1,ny,z), _is_solid(x,ny,z-1), _is_solid(x+1,ny,z-1))) / 3.0
			ao[2] = float(_vao(_is_solid(x+1,ny,z), _is_solid(x,ny,z+1), _is_solid(x+1,ny,z+1))) / 3.0
			ao[3] = float(_vao(_is_solid(x-1,ny,z), _is_solid(x,ny,z+1), _is_solid(x-1,ny,z+1))) / 3.0
		DIR_XP:
			nx = x + 1
			ao[0] = float(_vao(_is_solid(nx,y-1,z), _is_solid(nx,y,z-1), _is_solid(nx,y-1,z-1))) / 3.0
			ao[1] = float(_vao(_is_solid(nx,y+1,z), _is_solid(nx,y,z-1), _is_solid(nx,y+1,z-1))) / 3.0
			ao[2] = float(_vao(_is_solid(nx,y+1,z), _is_solid(nx,y,z+1), _is_solid(nx,y+1,z+1))) / 3.0
			ao[3] = float(_vao(_is_solid(nx,y-1,z), _is_solid(nx,y,z+1), _is_solid(nx,y-1,z+1))) / 3.0
		DIR_XN:
			nx = x - 1
			ao[0] = float(_vao(_is_solid(nx,y-1,z), _is_solid(nx,y,z-1), _is_solid(nx,y-1,z-1))) / 3.0
			ao[1] = float(_vao(_is_solid(nx,y+1,z), _is_solid(nx,y,z-1), _is_solid(nx,y+1,z-1))) / 3.0
			ao[2] = float(_vao(_is_solid(nx,y+1,z), _is_solid(nx,y,z+1), _is_solid(nx,y+1,z+1))) / 3.0
			ao[3] = float(_vao(_is_solid(nx,y-1,z), _is_solid(nx,y,z+1), _is_solid(nx,y-1,z+1))) / 3.0
		DIR_ZP:
			nz = z + 1
			ao[0] = float(_vao(_is_solid(x-1,y,nz), _is_solid(x,y-1,nz), _is_solid(x-1,y-1,nz))) / 3.0
			ao[1] = float(_vao(_is_solid(x+1,y,nz), _is_solid(x,y-1,nz), _is_solid(x+1,y-1,nz))) / 3.0
			ao[2] = float(_vao(_is_solid(x+1,y,nz), _is_solid(x,y+1,nz), _is_solid(x+1,y+1,nz))) / 3.0
			ao[3] = float(_vao(_is_solid(x-1,y,nz), _is_solid(x,y+1,nz), _is_solid(x-1,y+1,nz))) / 3.0
		DIR_ZN:
			nz = z - 1
			ao[0] = float(_vao(_is_solid(x-1,y,nz), _is_solid(x,y-1,nz), _is_solid(x-1,y-1,nz))) / 3.0
			ao[1] = float(_vao(_is_solid(x+1,y,nz), _is_solid(x,y-1,nz), _is_solid(x+1,y-1,nz))) / 3.0
			ao[2] = float(_vao(_is_solid(x+1,y,nz), _is_solid(x,y+1,nz), _is_solid(x+1,y+1,nz))) / 3.0
			ao[3] = float(_vao(_is_solid(x-1,y,nz), _is_solid(x,y+1,nz), _is_solid(x-1,y+1,nz))) / 3.0
	return ao


## Fast AO for the padded-buffer path. Eliminates ALL method calls
## (_is_solid, get_voxel, _idx, _vao) by inlining everything as direct
## _padded[] array reads. Called ~3000x per surface chunk, saves ~108K
## method dispatches per chunk vs the standard _compute_ao path.
func _compute_ao_padded(x: int, y: int, z: int, face_dir: int, ao: PackedFloat32Array) -> void:
	var p: PackedByteArray = _padded
	# Center in padded coords
	var ci: int = (x + 1) + (y + 1) * 18 + (z + 1) * 324
	var ni: int
	var s0: int; var s1: int; var s2: int; var s3: int
	var c0: int; var c1: int; var c2: int; var c3: int
	# AO lookups go through the opacity table so transparent / partial-volume
	# blocks (barrier, glass, fluids, fire, plants, slab) don't cast shadows.
	var ao_op: PackedByteArray = _AO_OPAQUE
	match face_dir:
		DIR_YP:
			ni = ci + 18
			s0 = ao_op[p[ni - 1]]        # x-1
			s1 = ao_op[p[ni + 1]]        # x+1
			s2 = ao_op[p[ni - 324]]      # z-1
			s3 = ao_op[p[ni + 324]]      # z+1
			c0 = ao_op[p[ni - 1 - 324]]  # x-1,z-1
			c1 = ao_op[p[ni + 1 - 324]]  # x+1,z-1
			c2 = ao_op[p[ni + 1 + 324]]  # x+1,z+1
			c3 = ao_op[p[ni - 1 + 324]]  # x-1,z+1
			ao[0] = float(0 if s0 == 1 and s2 == 1 else 3 - (s0 + s2 + c0)) / 3.0
			ao[1] = float(0 if s1 == 1 and s2 == 1 else 3 - (s1 + s2 + c1)) / 3.0
			ao[2] = float(0 if s1 == 1 and s3 == 1 else 3 - (s1 + s3 + c2)) / 3.0
			ao[3] = float(0 if s0 == 1 and s3 == 1 else 3 - (s0 + s3 + c3)) / 3.0
		DIR_YN:
			ni = ci - 18
			s0 = ao_op[p[ni - 1]]
			s1 = ao_op[p[ni + 1]]
			s2 = ao_op[p[ni - 324]]
			s3 = ao_op[p[ni + 324]]
			c0 = ao_op[p[ni - 1 - 324]]
			c1 = ao_op[p[ni + 1 - 324]]
			c2 = ao_op[p[ni + 1 + 324]]
			c3 = ao_op[p[ni - 1 + 324]]
			ao[0] = float(0 if s0 == 1 and s2 == 1 else 3 - (s0 + s2 + c0)) / 3.0
			ao[1] = float(0 if s1 == 1 and s2 == 1 else 3 - (s1 + s2 + c1)) / 3.0
			ao[2] = float(0 if s1 == 1 and s3 == 1 else 3 - (s1 + s3 + c2)) / 3.0
			ao[3] = float(0 if s0 == 1 and s3 == 1 else 3 - (s0 + s3 + c3)) / 3.0
		DIR_XP:
			ni = ci + 1
			s0 = ao_op[p[ni - 18]]       # y-1
			s1 = ao_op[p[ni + 18]]       # y+1
			s2 = ao_op[p[ni - 324]]      # z-1
			s3 = ao_op[p[ni + 324]]      # z+1
			c0 = ao_op[p[ni - 18 - 324]]
			c1 = ao_op[p[ni + 18 - 324]]
			c2 = ao_op[p[ni + 18 + 324]]
			c3 = ao_op[p[ni - 18 + 324]]
			ao[0] = float(0 if s0 == 1 and s2 == 1 else 3 - (s0 + s2 + c0)) / 3.0
			ao[1] = float(0 if s1 == 1 and s2 == 1 else 3 - (s1 + s2 + c1)) / 3.0
			ao[2] = float(0 if s1 == 1 and s3 == 1 else 3 - (s1 + s3 + c2)) / 3.0
			ao[3] = float(0 if s0 == 1 and s3 == 1 else 3 - (s0 + s3 + c3)) / 3.0
		DIR_XN:
			ni = ci - 1
			s0 = ao_op[p[ni - 18]]
			s1 = ao_op[p[ni + 18]]
			s2 = ao_op[p[ni - 324]]
			s3 = ao_op[p[ni + 324]]
			c0 = ao_op[p[ni - 18 - 324]]
			c1 = ao_op[p[ni + 18 - 324]]
			c2 = ao_op[p[ni + 18 + 324]]
			c3 = ao_op[p[ni - 18 + 324]]
			ao[0] = float(0 if s0 == 1 and s2 == 1 else 3 - (s0 + s2 + c0)) / 3.0
			ao[1] = float(0 if s1 == 1 and s2 == 1 else 3 - (s1 + s2 + c1)) / 3.0
			ao[2] = float(0 if s1 == 1 and s3 == 1 else 3 - (s1 + s3 + c2)) / 3.0
			ao[3] = float(0 if s0 == 1 and s3 == 1 else 3 - (s0 + s3 + c3)) / 3.0
		DIR_ZP:
			ni = ci + 324
			s0 = ao_op[p[ni - 1]]        # x-1
			s1 = ao_op[p[ni + 1]]        # x+1
			s2 = ao_op[p[ni - 18]]       # y-1
			s3 = ao_op[p[ni + 18]]       # y+1
			c0 = ao_op[p[ni - 1 - 18]]
			c1 = ao_op[p[ni + 1 - 18]]
			c2 = ao_op[p[ni + 1 + 18]]
			c3 = ao_op[p[ni - 1 + 18]]
			ao[0] = float(0 if s0 == 1 and s2 == 1 else 3 - (s0 + s2 + c0)) / 3.0
			ao[1] = float(0 if s1 == 1 and s2 == 1 else 3 - (s1 + s2 + c1)) / 3.0
			ao[2] = float(0 if s1 == 1 and s3 == 1 else 3 - (s1 + s3 + c2)) / 3.0
			ao[3] = float(0 if s0 == 1 and s3 == 1 else 3 - (s0 + s3 + c3)) / 3.0
		_: # DIR_ZN
			ni = ci - 324
			s0 = ao_op[p[ni - 1]]
			s1 = ao_op[p[ni + 1]]
			s2 = ao_op[p[ni - 18]]
			s3 = ao_op[p[ni + 18]]
			c0 = ao_op[p[ni - 1 - 18]]
			c1 = ao_op[p[ni + 1 - 18]]
			c2 = ao_op[p[ni + 1 + 18]]
			c3 = ao_op[p[ni - 1 + 18]]
			ao[0] = float(0 if s0 == 1 and s2 == 1 else 3 - (s0 + s2 + c0)) / 3.0
			ao[1] = float(0 if s1 == 1 and s2 == 1 else 3 - (s1 + s2 + c1)) / 3.0
			ao[2] = float(0 if s1 == 1 and s3 == 1 else 3 - (s1 + s3 + c2)) / 3.0
			ao[3] = float(0 if s0 == 1 and s3 == 1 else 3 - (s0 + s3 + c3)) / 3.0


# --- Slot management ---

func _alloc_slot() -> int:
	if _free_slots.size() > 0:
		var slot: int = _free_slots[_free_slots.size() - 1]
		_free_slots.resize(_free_slots.size() - 1)
		return slot
	# Grow arrays
	var slot: int = _slot_count * 6
	_slot_count += 1
	var needed: int = _slot_count * 6
	if needed > _verts.size():
		var cap: int = maxi(needed * 2, 4096)
		_verts.resize(cap)
		_normals.resize(cap)
		_colors.resize(cap)
		_uvs.resize(cap)
		_uv2s.resize(cap)
	return slot


func _free_slot(start: int) -> void:
	# Zero out vertices (degenerate triangle)
	var zero := Vector3.ZERO
	for i: int in 6:
		_verts[start + i] = zero
		_normals[start + i] = zero
		_colors[start + i] = Color(0, 0, 0, 0)
	_free_slots.append(start)


## Write one of the two crossed quads that make up a plant-style mesh (fire,
## poppy, dandelion). Slot holds 6 verts forming a flat vertical rectangle
## diagonal across the cell — two of these, rotated 90° to each other, create
## the classic Minecraft X-shape inside the voxel.
## `diagonal` is 0 for the -X,-Z → +X,+Z plane, 1 for +X,-Z → -X,+Z.
func _write_plant_quad(slot_start: int, bx: int, by: int, bz: int, block_type: int, diagonal: int, facing: int = 0) -> void:
	var origin := Vector3(bx, by, bz)
	var tile: float = _tile_index(block_type, DIR_YP)
	var tile_uv2 := Vector2(tile, 0.0)
	const E: float = 0.001
	var a: Vector3; var b: Vector3; var c: Vector3; var d: Vector3
	if diagonal == 0:
		a = origin + Vector3(E,   0, E)
		b = origin + Vector3(1-E, 0, 1-E)
		c = origin + Vector3(1-E, 1, 1-E)
		d = origin + Vector3(E,   1, E)
	else:
		a = origin + Vector3(1-E, 0, E)
		b = origin + Vector3(E,   0, 1-E)
		c = origin + Vector3(E,   1, 1-E)
		d = origin + Vector3(1-E, 1, E)
	# Wall-mounted torch: the base (bottom) presses against the wall block,
	# the flame tip (top) leans away. This matches Minecraft's wall torches
	# where the stick visually connects to the wall face.
	# facing: 0=upright, 1=south(+Z), 2=north(-Z), 3=east(+X), 4=west(-X).
	if facing > 0 and block_type == Block.TORCH:
		var wall_dir := Vector3.ZERO
		match facing:
			1: wall_dir = Vector3(0, 0, 1)   # wall is to the south (+Z)
			2: wall_dir = Vector3(0, 0, -1)  # wall is to the north (-Z)
			3: wall_dir = Vector3(1, 0, 0)   # wall is to the east (+X)
			4: wall_dir = Vector3(-1, 0, 0)  # wall is to the west (-X)
		# Bottom vertices shift toward the wall so the base touches it.
		# Top vertices shift away so the flame leans outward.
		a += wall_dir * 0.4
		b += wall_dir * 0.4
		c -= wall_dir * 0.25
		d -= wall_dir * 0.25
	# Two triangles: (a, b, c) and (a, c, d). Winding arbitrary since the
	# shader uses cull_disabled and plants look correct from both sides.
	var verts := [a, b, c, a, c, d]
	# UVs map across the full tile (0,0 bottom-left → 1,1 top-right).
	# We want (0,1) at verts a (bottom-left), (1,1) at b, (1,0) at c, (0,0) at d.
	var uvs := [
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0),
		Vector2(0, 1), Vector2(1, 0), Vector2(0, 0),
	]
	# Normal can be (0,1,0) for plant lighting — arbitrary since cull_disabled
	# and we want the plant to read evenly from any angle.
	var normal := Vector3(0, 1, 0)
	for i: int in 6:
		var vi: int = slot_start + i
		_verts[vi] = verts[i]
		_normals[vi] = normal
		_uvs[vi] = uvs[i]
		_uv2s[vi] = tile_uv2
		# Full-bright, no AO darkening on plants (matches Minecraft).
		_colors[vi] = Color(1, 1, 1, 1)


## Auto-detect torch orientation from surrounding blocks. If there's a solid
## block directly below → upright (0). Otherwise scan N/S/E/W for a solid
## neighbor and return the facing that leans toward it. Falls back to upright.
func _detect_torch_facing(lx: int, ly: int, lz: int) -> int:
	# Check below — uses get_voxel which handles cross-chunk lookups.
	if _is_solid_for_torch(get_voxel(lx, ly - 1, lz)):
		return 0  # ground below, stand upright
	# No ground — lean toward the first solid horizontal neighbor.
	if _is_solid_for_torch(get_voxel(lx, ly, lz + 1)):
		return 1  # solid to south (+Z)
	if _is_solid_for_torch(get_voxel(lx, ly, lz - 1)):
		return 2  # solid to north (-Z)
	if _is_solid_for_torch(get_voxel(lx + 1, ly, lz)):
		return 3  # solid to east (+X)
	if _is_solid_for_torch(get_voxel(lx - 1, ly, lz)):
		return 4  # solid to west (-X)
	return 0  # nothing nearby, stand upright


static func _is_solid_for_torch(b: int) -> bool:
	if b == Block.AIR or b == Block.WATER or b == Block.LAVA:
		return false
	if b == Block.FIRE or b == Block.POPPY or b == Block.DANDELION or b == Block.TORCH:
		return false
	if b == Block.GLASS or b == Block.BARRIER:
		return false
	return b > 0


## True if `b` should render as a crossed-quad plant mesh instead of a cube.
static func _is_plant(b: int) -> bool:
	return b == Block.FIRE or b == Block.POPPY or b == Block.DANDELION or b == Block.TORCH


func _write_face(slot_start: int, bx: int, by: int, bz: int, face_dir: int, block_type: int, ao: PackedFloat32Array, water_corners: PackedFloat32Array = PackedFloat32Array(), connect_mask: int = 0) -> void:
	var origin := Vector3(bx, by, bz)
	var normal: Vector3 = NORMALS[face_dir]
	var tile: float = _tile_index(block_type, face_dir)
	var fv: Array = FACE_VERTS[face_dir]
	var fuv: Array = FACE_UVS[face_dir]
	var fao: Array = FACE_AO_MAP[face_dir]
	var tile_uv2 := Vector2(tile, 0.0)

	# If the block is water and we have corner heights, rewrite top-edge
	# vertices with per-corner heights so adjacent water blocks slope together.
	# Apply level-based corner heights for both fluids.
	var is_water: bool = (block_type == Block.WATER or block_type == Block.LAVA) and water_corners.size() == 4

	# Glass connect mask packed into COLOR.r (0..15 / 15.0). Non-glass faces
	# leave it at 1.0 — the shader only reads COLOR.r for glass tiles. Glass
	# ALWAYS encodes its mask (even when 0 for isolated blocks); otherwise
	# the shader's round(1.0 * 15.0) = 15 would discard all four frame edges
	# and the block would render as a fully-transparent quad.
	var mask_r: float = 1.0
	if block_type == Block.GLASS:
		mask_r = float(connect_mask) / 15.0

	# Slab: vertices at y+1 drop to y+0.5 so the block is half-height.
	var is_slab: bool = block_type == Block.SMOOTH_STONE_SLAB

	for i: int in 6:
		var vi: int = slot_start + i
		var v: Vector3 = origin + fv[i]
		if is_water:
			var corner_idx: int = WATER_TOP_CORNER_MAP[face_dir][i]
			if corner_idx >= 0:
				v.y = origin.y + water_corners[corner_idx]
		if is_slab and v.y > origin.y + 0.5:
			v.y = origin.y + 0.5
		_verts[vi] = v
		_normals[vi] = normal
		_uvs[vi] = fuv[i]
		_uv2s[vi] = tile_uv2
		_colors[vi] = Color(mask_r, 1.0, 1.0, ao[fao[i]])


# --- Build faces for a single block ---

func _rebuild_block_faces(x: int, y: int, z: int) -> void:
	var key := Vector3i(x, y, z)

	# Free old slots for this block
	if _block_slots.has(key):
		var old_slots: PackedInt32Array = _block_slots[key]
		for s: int in old_slots.size():
			_free_slot(old_slots[s])
		_block_slots.erase(key)

	var block: int = get_voxel(x, y, z)
	if block == Block.AIR:
		return

	# Plant mesh (fire, flowers, torches): two crossed quads.
	if _is_plant(block):
		var torch_facing: int = 0
		if block == Block.TORCH:
			torch_facing = _detect_torch_facing(x, y, z)
		var plant_slots := PackedInt32Array()
		for q: int in 2:
			var ps: int = _alloc_slot()
			_write_plant_quad(ps, x, y, z, block, q, torch_facing)
			plant_slots.append(ps)
		_has_noncollidable_faces = true
		if plant_slots.size() > 0:
			_block_slots[key] = plant_slots
		return

	var is_water: bool = block == Block.WATER
	var is_fluid: bool = is_water or block == Block.LAVA
	var water_corners := PackedFloat32Array()
	if is_fluid:
		water_corners.resize(4)
		_compute_fluid_corners(x, y, z, water_corners, block)

	var new_slots := PackedInt32Array()

	for dir: int in 6:
		var off: Vector3i = DIR_OFFSETS[dir]
		var nx: int = x + off.x
		var ny: int = y + off.y
		var nz: int = z + off.z
		var neighbor: int = get_voxel(nx, ny, nz)

		var draw_face: bool = false

		if is_water or block == Block.LAVA:
			# Fluid faces: draw only against air (adjacent solids draw their
			# own face; adjacent same-fluid cells cull the shared surface).
			draw_face = neighbor == Block.AIR
		elif block == Block.GLASS:
			# Glass only draws frames on air-facing sides — matches Minecraft.
			draw_face = neighbor == Block.AIR
		elif block == Block.FIRE:
			# Fire is alpha-cut and non-collidable; only expose its flame
			# against air so it doesn't overlap adjacent solids.
			draw_face = neighbor == Block.AIR
		elif block == Block.BARRIER:
			# Barrier is invisible unless held (shader uniform). Draw every
			# face that isn't shared with another barrier so collision stays
			# watertight around isolated barriers.
			draw_face = neighbor != Block.BARRIER
		elif block == Block.SMOOTH_STONE_SLAB:
			# Slab: draws ALL 6 faces regardless of neighbors because its
			# top half is air inside the cell — adjacent blocks can't hide
			# any of its surfaces. Modified vertex positions in _write_face
			# give it half-height. Potential z-fighting vs adjacent full
			# blocks at the slab's side planes is tolerated for now.
			draw_face = true
		else:
			# Solid non-glass: draw against any transparent / partial-volume
			# neighbor so the face stays visible through plants, fluids, etc.
			draw_face = not _is_opaque_neighbor(neighbor)

		if not draw_face:
			continue

		var ao: PackedFloat32Array = _compute_ao(x, y, z, dir)
		var mask: int = 0
		if block == Block.GLASS:
			var offs: Array = GLASS_CONNECT_OFFSETS[dir]
			for i: int in 4:
				var o: Vector3i = offs[i]
				if get_voxel(x + o.x, y + o.y, z + o.z) == Block.GLASS:
					mask |= (1 << i)
		var slot: int = _alloc_slot()
		_write_face(slot, x, y, z, dir, block, ao, water_corners, mask)
		new_slots.append(slot)
		if is_water:
			_has_water_faces = true
		if block == Block.FIRE or block == Block.LAVA:
			_has_noncollidable_faces = true

	if new_slots.size() > 0:
		_block_slots[key] = new_slots


# --- Full build (initial world gen) ---

## Builds the mesh arrays (vertex data + slot tracking) but does NOT upload
## to the GPU. When `_use_padded` is set, takes the fast path: inlined
## neighbor reads directly from the padded buffer (no `get_voxel` method
## calls) and an enclosed-solid early skip that collapses fully-buried
## voxels to a single array test. Iteration order is z,y,x so the inner
## loop walks voxels[] with stride 1 (cache-friendly). Slow path uses
## get_voxel for cross-chunk neighbor lookups.
func build_mesh_data(mat: Material = null, water_mat: Material = null) -> void:
	_stored_mat = mat
	_water_mat = water_mat
	_block_slots.clear()
	_free_slots.resize(0)
	_slot_count = 0
	_has_water_faces = false
	_has_noncollidable_faces = false
	_verts.resize(0)
	_normals.resize(0)
	_colors.resize(0)
	_uvs.resize(0)
	_uv2s.resize(0)

	var ao_buf := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	var use_fast: bool = _use_padded
	var p: PackedByteArray = _padded  # CoW-aliased ref; no copy until write
	var new_slots := PackedInt32Array()
	new_slots.resize(6)
	# Neighbor block buffer — indexed by DIR_YP..DIR_ZN so the inner face
	# loop can read `neighbor = neighbors[dir]` without a match statement.
	var neighbors := PackedByteArray()
	neighbors.resize(6)
	var w: int = Block.WATER
	var g: int = Block.GLASS

	for z: int in SIZE:
		var vz: int = z << 8
		var pz: int = (z + 1) * 324
		for y: int in SIZE:
			var vy: int = y << 4
			var py: int = (y + 1) * 18
			for x: int in SIZE:
				var block: int = voxels[x + vy + vz]
				if block == Block.AIR:
					continue

				if _is_plant(block):
					var tf: int = 0
					if block == Block.TORCH:
						tf = _detect_torch_facing(x, y, z)
					var plant_slots := PackedInt32Array()
					for q: int in 2:
						var ps: int = _alloc_slot()
						_write_plant_quad(ps, x, y, z, block, q, tf)
						plant_slots.append(ps)
					_has_noncollidable_faces = true
					_block_slots[Vector3i(x, y, z)] = plant_slots
					continue

				# Fetch 6 neighbors via inlined padded reads when possible.
				# Order matches DIR_YP=0, DIR_YN=1, DIR_XP=2, DIR_XN=3, DIR_ZP=4, DIR_ZN=5.
				if use_fast:
					var pi: int = (x + 1) + py + pz
					neighbors[0] = p[pi + 18]
					neighbors[1] = p[pi - 18]
					neighbors[2] = p[pi + 1]
					neighbors[3] = p[pi - 1]
					neighbors[4] = p[pi + 324]
					neighbors[5] = p[pi - 324]
				else:
					neighbors[0] = get_voxel(x, y + 1, z)
					neighbors[1] = get_voxel(x, y - 1, z)
					neighbors[2] = get_voxel(x + 1, y, z)
					neighbors[3] = get_voxel(x - 1, y, z)
					neighbors[4] = get_voxel(x, y, z + 1)
					neighbors[5] = get_voxel(x, y, z - 1)

				var is_water: bool = block == w
				var is_lava: bool = block == Block.LAVA
				var is_fire: bool = block == Block.FIRE
				var is_glass: bool = block == g
				var is_barrier: bool = block == Block.BARRIER
				var is_slab: bool = block == Block.SMOOTH_STONE_SLAB

				# Enclosed-solid skip. Skip only if block is a regular opaque
				# solid (not a special case) and ALL 6 neighbors are opaque
				# solids too (anything non-transparent).
				if not is_water and not is_lava and not is_fire \
					and not is_glass and not is_barrier and not is_slab:
					var n0: int = neighbors[0]
					var n1: int = neighbors[1]
					var n2: int = neighbors[2]
					var n3: int = neighbors[3]
					var n4: int = neighbors[4]
					var n5: int = neighbors[5]
					if _is_opaque_neighbor(n0) and _is_opaque_neighbor(n1) \
						and _is_opaque_neighbor(n2) and _is_opaque_neighbor(n3) \
						and _is_opaque_neighbor(n4) and _is_opaque_neighbor(n5):
						continue

				var water_corners := PackedFloat32Array()
				if is_water or is_lava:
					water_corners.resize(4)
					_compute_fluid_corners(x, y, z, water_corners, block)

				var slot_count_for_block: int = 0

				for dir: int in 6:
					var neighbor: int = neighbors[dir]

					var draw_face: bool
					if is_water or is_lava or is_fire or is_glass:
						# Transparent/alpha-cut blocks draw only against air.
						draw_face = neighbor == Block.AIR
					elif is_barrier:
						# Barrier draws every face not shared with another
						# barrier so collision remains correct.
						draw_face = neighbor != Block.BARRIER
					elif is_slab:
						# Slab: draws all 6 faces (half-height top).
						draw_face = true
					else:
						# Regular solid: draw against any non-opaque neighbor
						# (air, fluids, glass, fire, barrier, slab, plants).
						draw_face = not _is_opaque_neighbor(neighbor)

					if not draw_face:
						continue

					if use_fast:
						_compute_ao_padded(x, y, z, dir, ao_buf)
					else:
						var ao_tmp: PackedFloat32Array = _compute_ao(x, y, z, dir)
						ao_buf[0] = ao_tmp[0]
						ao_buf[1] = ao_tmp[1]
						ao_buf[2] = ao_tmp[2]
						ao_buf[3] = ao_tmp[3]

					var mask: int = 0
					if is_glass:
						var offs: Array = GLASS_CONNECT_OFFSETS[dir]
						for i: int in 4:
							var o: Vector3i = offs[i]
							if get_voxel(x + o.x, y + o.y, z + o.z) == g:
								mask |= (1 << i)

					var slot: int = _alloc_slot()
					_write_face(slot, x, y, z, dir, block, ao_buf, water_corners, mask)
					new_slots[slot_count_for_block] = slot
					slot_count_for_block += 1
					if is_water:
						_has_water_faces = true
					if is_fire or is_lava:
						_has_noncollidable_faces = true

				if slot_count_for_block > 0:
					var final_slots := PackedInt32Array()
					final_slots.resize(slot_count_for_block)
					for si: int in slot_count_for_block:
						final_slots[si] = new_slots[si]
					_block_slots[Vector3i(x, y, z)] = final_slots


func generate_mesh(mat: Material = null, water_mat: Material = null) -> void:
	build_mesh_data(mat, water_mat)
	_apply_mesh()


# --- Apply arrays to mesh (splits into solid + water surfaces) ---

func _apply_mesh() -> void:
	var total_verts: int = _slot_count * 6
	_arr_mesh.clear_surfaces()

	if total_verts == 0:
		if _physics_ready:
			PhysicsServer3D.shape_set_data(_shape_rid, {"faces": PackedVector3Array(), "backface_collision": true})
		# Ensure mesh points to our own ArrayMesh (may have been shared from
		# a flatgrass template — switch back to own on edit).
		mesh = _arr_mesh
		return

	# Trim arrays to actual used size
	_verts.resize(total_verts)
	_normals.resize(total_verts)
	_colors.resize(total_verts)
	_uvs.resize(total_verts)
	_uv2s.resize(total_verts)

	# Fast path: chunk has no water AND no non-collidable faces → skip the
	# split loop and upload the whole vertex buffer as the solid surface
	# directly, using it verbatim as collision too.
	if not _has_water_faces and not _has_noncollidable_faces:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
		_arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if _stored_mat != null:
			_arr_mesh.surface_set_material(0, _stored_mat)
		if _physics_ready:
			PhysicsServer3D.shape_set_data(_shape_rid, {"faces": _verts, "backface_collision": true})
		mesh = _arr_mesh
		return

	# Split the combined vertex arrays into solid (opaque) and water
	# (transparent) surfaces. Water is identified by UV2.x == 32 (water tile).
	var solid_verts := PackedVector3Array()
	var solid_normals := PackedVector3Array()
	var solid_colors := PackedColorArray()
	var solid_uvs := PackedVector2Array()
	var solid_uv2s := PackedVector2Array()
	solid_verts.resize(total_verts)
	solid_normals.resize(total_verts)
	solid_colors.resize(total_verts)
	solid_uvs.resize(total_verts)
	solid_uv2s.resize(total_verts)

	var water_verts := PackedVector3Array()
	var water_normals := PackedVector3Array()
	var water_colors := PackedColorArray()
	var water_uvs := PackedVector2Array()
	var water_uv2s := PackedVector2Array()
	water_verts.resize(total_verts)
	water_normals.resize(total_verts)
	water_colors.resize(total_verts)
	water_uvs.resize(total_verts)
	water_uv2s.resize(total_verts)

	var s_count: int = 0
	var w_count: int = 0
	var i: int = 0
	while i < total_verts:
		var is_water_face: bool = _uv2s[i].x == 32.0
		if is_water_face:
			for j: int in 6:
				water_verts[w_count + j] = _verts[i + j]
				water_normals[w_count + j] = _normals[i + j]
				water_colors[w_count + j] = _colors[i + j]
				water_uvs[w_count + j] = _uvs[i + j]
				water_uv2s[w_count + j] = _uv2s[i + j]
			w_count += 6
		else:
			for j: int in 6:
				solid_verts[s_count + j] = _verts[i + j]
				solid_normals[s_count + j] = _normals[i + j]
				solid_colors[s_count + j] = _colors[i + j]
				solid_uvs[s_count + j] = _uvs[i + j]
				solid_uv2s[s_count + j] = _uv2s[i + j]
			s_count += 6
		i += 6

	solid_verts.resize(s_count)
	solid_normals.resize(s_count)
	solid_colors.resize(s_count)
	solid_uvs.resize(s_count)
	solid_uv2s.resize(s_count)

	water_verts.resize(w_count)
	water_normals.resize(w_count)
	water_colors.resize(w_count)
	water_uvs.resize(w_count)
	water_uv2s.resize(w_count)

	# Surface 0: solid (opaque)
	if s_count > 0:
		var s_arrays: Array = []
		s_arrays.resize(Mesh.ARRAY_MAX)
		s_arrays[Mesh.ARRAY_VERTEX] = solid_verts
		s_arrays[Mesh.ARRAY_NORMAL] = solid_normals
		s_arrays[Mesh.ARRAY_COLOR] = solid_colors
		s_arrays[Mesh.ARRAY_TEX_UV] = solid_uvs
		s_arrays[Mesh.ARRAY_TEX_UV2] = solid_uv2s
		_arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s_arrays)
		if _stored_mat != null:
			_arr_mesh.surface_set_material(_arr_mesh.get_surface_count() - 1, _stored_mat)

	# Surface 1: water (transparent, drawn after opaque by render_mode blend_mix)
	if w_count > 0:
		var w_arrays: Array = []
		w_arrays.resize(Mesh.ARRAY_MAX)
		w_arrays[Mesh.ARRAY_VERTEX] = water_verts
		w_arrays[Mesh.ARRAY_NORMAL] = water_normals
		w_arrays[Mesh.ARRAY_COLOR] = water_colors
		w_arrays[Mesh.ARRAY_TEX_UV] = water_uvs
		w_arrays[Mesh.ARRAY_TEX_UV2] = water_uv2s
		_arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, w_arrays)
		if _water_mat != null:
			_arr_mesh.surface_set_material(_arr_mesh.get_surface_count() - 1, _water_mat)

	# Collision: filter fire (tile 44), lava (tile 45), poppy (48), and
	# dandelion (49) out of the solid verts so the player walks through them.
	# Water is already handled (it went to the water surface, not solid_verts).
	if _physics_ready:
		var col_verts: PackedVector3Array
		if _has_noncollidable_faces:
			col_verts = PackedVector3Array()
			col_verts.resize(s_count)
			var cc: int = 0
			var k: int = 0
			while k < s_count:
				var tid: float = solid_uv2s[k].x
				if tid != 44.0 and tid != 45.0 and tid != 48.0 and tid != 49.0 and tid != 50.0:
					for jj: int in 6:
						col_verts[cc + jj] = solid_verts[k + jj]
					cc += 6
				k += 6
			col_verts.resize(cc)
		else:
			col_verts = solid_verts
		PhysicsServer3D.shape_set_data(_shape_rid, {"faces": col_verts, "backface_collision": true})
	# Ensure mesh points to our own ArrayMesh (may have been shared from
	# a flatgrass template — switch back to own on edit).
	mesh = _arr_mesh


func generate_collision() -> void:
	if not _physics_ready:
		_init_physics()
	if _slot_count > 0:
		PhysicsServer3D.shape_set_data(_shape_rid, {"faces": _verts, "backface_collision": true})

func clear_collision() -> void:
	if _physics_ready:
		PhysicsServer3D.shape_set_data(_shape_rid, {"faces": PackedVector3Array(), "backface_collision": true})
