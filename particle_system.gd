class_name ParticleSystem
extends MultiMeshInstance3D

# CPU-driven particle system for block break bursts.
# Uses a single MultiMesh with INSTANCE_CUSTOM data for per-particle tile + fade.
#
# Optimization notes:
# - Swap-remove for O(1) particle death (no array shifting).
# - Direct buffer writes via multimesh.buffer = _buffer (one transfer per frame).
# - Basis rows are preset once at init; the per-frame hot loop only writes the
#   3 origin floats and the 4 custom_data floats (7 floats per live particle).
# - visible_instance_count set to active count so GPU draws only live particles.
# - set_process(false) when idle for zero idle cost.

const MAX_PARTICLES: int = 384
const BURST_COUNT: int = 8
const PARTICLE_SIZE: float = 0.12
const GRAVITY: float = 14.0
const LIFETIME: float = 0.9
const FADE_FRAC: float = 0.35  # last 35% of life fades out
const DRAG: float = 0.6
# 4x4 sub-region offsets (u, v = 0, 0.25, 0.5, 0.75)
const SUB_STEPS: PackedFloat32Array = [0.0, 0.25, 0.5, 0.75]

# 12 transform floats + 4 INSTANCE_CUSTOM floats = 16 floats per instance
const STRIDE: int = 16

var _multimesh: MultiMesh
var _buffer: PackedFloat32Array
# Retained so the mipmap settings refresh can re-bind the rebuilt atlas.
var _mesh_material: ShaderMaterial = null

# Parallel arrays — indexed [0, _active_count)
var _positions: PackedVector3Array
var _velocities: PackedVector3Array
var _lifetimes: PackedFloat32Array  # time remaining
var _tiles: PackedFloat32Array      # atlas tile index
var _sub_u: PackedFloat32Array
var _sub_v: PackedFloat32Array
var _active_count: int = 0


func _ready() -> void:
	# Mesh
	var box := BoxMesh.new()
	box.size = Vector3(PARTICLE_SIZE, PARTICLE_SIZE, PARTICLE_SIZE)

	# Material — shared shader
	var mat := ShaderMaterial.new()
	mat.shader = load("res://particles.gdshader") as Shader
	var atlas: ImageTexture = BlockTextures.create_atlas()
	mat.set_shader_parameter("block_atlas", atlas)
	box.material = mat
	_mesh_material = mat

	# MultiMesh
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = false
	_multimesh.use_custom_data = true
	_multimesh.mesh = box
	_multimesh.instance_count = MAX_PARTICLES
	_multimesh.visible_instance_count = 0
	multimesh = _multimesh

	# Pre-size parallel arrays
	_positions.resize(MAX_PARTICLES)
	_velocities.resize(MAX_PARTICLES)
	_lifetimes.resize(MAX_PARTICLES)
	_tiles.resize(MAX_PARTICLES)
	_sub_u.resize(MAX_PARTICLES)
	_sub_v.resize(MAX_PARTICLES)

	# Pre-initialize buffer with identity basis rows
	_buffer.resize(MAX_PARTICLES * STRIDE)
	for i: int in MAX_PARTICLES:
		var o: int = i * STRIDE
		# Basis row 0
		_buffer[o + 0] = 1.0
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = 0.0  # origin.x (updated per frame)
		# Basis row 1
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = 1.0
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = 0.0  # origin.y
		# Basis row 2
		_buffer[o + 8] = 0.0
		_buffer[o + 9] = 0.0
		_buffer[o + 10] = 1.0
		_buffer[o + 11] = 0.0  # origin.z
		# Custom data (tile_idx, fade, sub_u, sub_v) — updated per frame
		_buffer[o + 12] = 0.0
		_buffer[o + 13] = 0.0
		_buffer[o + 14] = 0.0
		_buffer[o + 15] = 0.0

	set_process(false)


## Spawn a break-burst at the center of a block of the given type.
func spawn_break_burst(world_pos: Vector3, block_type: int) -> void:
	var rng_face_base: int = randi()

	for k: int in BURST_COUNT:
		if _active_count >= MAX_PARTICLES:
			return

		# Pick a random face of the block so particles sample textures fairly.
		var face: int = (rng_face_base + k) % 6
		var tile: float = Chunk._tile_index(block_type, face)

		var idx: int = _active_count
		_active_count += 1

		_positions[idx] = world_pos + Vector3(
			randf_range(-0.15, 0.15),
			randf_range(-0.15, 0.15),
			randf_range(-0.15, 0.15),
		)
		_velocities[idx] = Vector3(
			randf_range(-2.0, 2.0),
			randf_range(2.5, 5.5),
			randf_range(-2.0, 2.0),
		)
		_lifetimes[idx] = LIFETIME
		_tiles[idx] = tile
		_sub_u[idx] = SUB_STEPS[randi() & 3]
		_sub_v[idx] = SUB_STEPS[randi() & 3]

	set_process(true)


func _process(delta: float) -> void:
	if _active_count == 0:
		_multimesh.visible_instance_count = 0
		set_process(false)
		return

	var drag_mul: float = 1.0 - DRAG * delta
	if drag_mul < 0.0:
		drag_mul = 0.0
	var gravity_dv: float = GRAVITY * delta
	var fade_start: float = LIFETIME * FADE_FRAC
	var fade_inv: float = 1.0 / fade_start

	var i: int = 0
	while i < _active_count:
		var life: float = _lifetimes[i] - delta
		if life <= 0.0:
			# Swap-remove
			var last: int = _active_count - 1
			if i != last:
				_positions[i] = _positions[last]
				_velocities[i] = _velocities[last]
				_lifetimes[i] = _lifetimes[last]
				_tiles[i] = _tiles[last]
				_sub_u[i] = _sub_u[last]
				_sub_v[i] = _sub_v[last]
			_active_count = last
			continue

		# Integrate
		var vel: Vector3 = _velocities[i]
		vel.y -= gravity_dv
		vel.x *= drag_mul
		vel.z *= drag_mul
		_velocities[i] = vel
		var pos: Vector3 = _positions[i] + vel * delta
		_positions[i] = pos
		_lifetimes[i] = life

		# Fade = 1.0 for first (LIFETIME - fade_start) seconds, linear down to 0
		var fade: float = 1.0
		if life < fade_start:
			fade = life * fade_inv

		# Write to buffer (only origin + custom data)
		var o: int = i * STRIDE
		_buffer[o + 3] = pos.x
		_buffer[o + 7] = pos.y
		_buffer[o + 11] = pos.z
		_buffer[o + 12] = _tiles[i]
		_buffer[o + 13] = fade
		_buffer[o + 14] = _sub_u[i]
		_buffer[o + 15] = _sub_v[i]

		i += 1

	_multimesh.buffer = _buffer
	_multimesh.visible_instance_count = _active_count


## Re-bind the (possibly rebuilt) block atlas onto the particle material. Used
## when the mipmap setting toggles and the atlas is regenerated.
func refresh_atlas() -> void:
	if _mesh_material == null:
		return
	_mesh_material.set_shader_parameter("block_atlas", BlockTextures.create_atlas())
