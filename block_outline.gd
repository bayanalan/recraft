class_name BlockOutline
extends MeshInstance3D

const INFLATE: float = 0.003
const TILE: int = 16

var _break_mesh: MeshInstance3D = null
var _break_mat: StandardMaterial3D = null
var _crack_textures: Array = []
var _current_stage: int = -1

# Crack pixel deltas — new pixels added at each stage. Applied cumulatively:
# the texture for stage N shows the union of all stages 0..N. Coordinates are
# [x, y] on a 16×16 grid, (0,0) = top-left, impact center at ~(8,8).
const _CRACK_DELTA: Array = [
	# Stage 0: first hit — tiny initial crack, 2 short arms from center
	[[8,8],[9,7],[10,6],[7,9],[6,10],[11,5]],
	# Stage 1: arms extend, horizontal spread starts
	[[5,11],[7,8],[9,8],[8,7],[8,9],[12,4],[4,12]],
	# Stage 2: new diagonal branches appear, arms grow
	[[7,7],[9,9],[10,8],[6,8],[13,3],[3,13],[11,6],[6,11]],
	# Stage 3: cracks approach edges, secondary branches
	[[14,2],[2,14],[8,6],[8,10],[11,8],[5,8],[12,7],[4,9],
	 [7,6],[9,10],[12,6],[4,10],[6,5],[10,11]],
	# Stage 4: nearly broken — dense near-edge cracking
	[[15,1],[1,15],[8,5],[8,11],[13,8],[3,8],[7,5],[9,11],
	 [13,6],[3,10],[11,4],[5,12],[12,9],[4,7],[6,4],[10,12],
	 [2,13],[14,3],[5,3],[11,13],[3,7],[13,9],[7,14],[9,2]],
]


func _ready() -> void:
	# Wireframe outline cube — 12 edges as 24 line-primitive vertices.
	var verts := PackedVector3Array()
	var a: float = -INFLATE
	var b: float = 1.0 + INFLATE
	verts.append(Vector3(a,a,a)); verts.append(Vector3(b,a,a))
	verts.append(Vector3(b,a,a)); verts.append(Vector3(b,a,b))
	verts.append(Vector3(b,a,b)); verts.append(Vector3(a,a,b))
	verts.append(Vector3(a,a,b)); verts.append(Vector3(a,a,a))
	verts.append(Vector3(a,b,a)); verts.append(Vector3(b,b,a))
	verts.append(Vector3(b,b,a)); verts.append(Vector3(b,b,b))
	verts.append(Vector3(b,b,b)); verts.append(Vector3(a,b,b))
	verts.append(Vector3(a,b,b)); verts.append(Vector3(a,b,a))
	verts.append(Vector3(a,a,a)); verts.append(Vector3(a,b,a))
	verts.append(Vector3(b,a,a)); verts.append(Vector3(b,b,a))
	verts.append(Vector3(b,a,b)); verts.append(Vector3(b,b,b))
	verts.append(Vector3(a,a,b)); verts.append(Vector3(a,b,b))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0, 1)
	mat.vertex_color_use_as_albedo = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	arr_mesh.surface_set_material(0, mat)
	mesh = arr_mesh
	visible = false

	_generate_crack_textures()

	# Crack overlay — sits just outside the block surface via slight inflation.
	var box := BoxMesh.new()
	box.size = Vector3(1.006, 1.006, 1.006)
	_break_mat = StandardMaterial3D.new()
	_break_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_break_mat.albedo_color = Color(1, 1, 1, 1)
	_break_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_break_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_break_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_break_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_break_mesh = MeshInstance3D.new()
	_break_mesh.mesh = box
	_break_mesh.material_override = _break_mat
	_break_mesh.position = Vector3(0.5, 0.5, 0.5)
	_break_mesh.visible = false
	add_child(_break_mesh)


func _generate_crack_textures() -> void:
	_crack_textures.clear()
	# cumulative set: key = y*TILE+x → true
	var cumulative: Dictionary = {}

	for stage in _CRACK_DELTA:
		# Accumulate this stage's pixels into the running set.
		for px in stage:
			cumulative[px[1] * TILE + px[0]] = true

		var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)

		# Shadow pass — 1-pixel feathered border around crack pixels so the
		# cracks read as recessed grooves rather than flat painted lines.
		for key: int in cumulative:
			var cx: int = key % TILE
			var cy: int = key / TILE
			for dx: int in range(-1, 2):
				for dy: int in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var sx: int = cx + dx
					var sy: int = cy + dy
					if sx < 0 or sy < 0 or sx >= TILE or sy >= TILE:
						continue
					if not cumulative.has(sy * TILE + sx):
						img.set_pixel(sx, sy, Color(0.0, 0.0, 0.0, 0.30))

		# Main crack pixels drawn on top of the shadow pass.
		for key: int in cumulative:
			img.set_pixel(key % TILE, key / TILE, Color(0.0, 0.0, 0.0, 0.88))

		_crack_textures.append(ImageTexture.create_from_image(img))


func show_at(block_pos: Vector3i) -> void:
	global_position = Vector3(block_pos)
	visible = true


func set_break_progress(progress: float) -> void:
	if _break_mesh == null:
		return
	if progress <= 0.0:
		_break_mesh.visible = false
		_current_stage = -1
		return
	_break_mesh.visible = visible
	var stage: int = clampi(int(progress * _crack_textures.size()), 0, _crack_textures.size() - 1)
	if stage != _current_stage:
		_current_stage = stage
		_break_mat.albedo_texture = _crack_textures[stage]


func hide_outline() -> void:
	visible = false
	if _break_mesh != null:
		_break_mesh.visible = false
