class_name BlockOutline
extends MeshInstance3D

# Slight inflation to prevent z-fighting with block faces
const INFLATE: float = 0.003


func _ready() -> void:
	# Build a wireframe cube as 12 line segments (24 vertices)
	var verts := PackedVector3Array()
	var a: float = -INFLATE
	var b: float = 1.0 + INFLATE

	# Bottom face (4 edges)
	verts.append(Vector3(a, a, a)); verts.append(Vector3(b, a, a))
	verts.append(Vector3(b, a, a)); verts.append(Vector3(b, a, b))
	verts.append(Vector3(b, a, b)); verts.append(Vector3(a, a, b))
	verts.append(Vector3(a, a, b)); verts.append(Vector3(a, a, a))

	# Top face (4 edges)
	verts.append(Vector3(a, b, a)); verts.append(Vector3(b, b, a))
	verts.append(Vector3(b, b, a)); verts.append(Vector3(b, b, b))
	verts.append(Vector3(b, b, b)); verts.append(Vector3(a, b, b))
	verts.append(Vector3(a, b, b)); verts.append(Vector3(a, b, a))

	# Vertical edges (4)
	verts.append(Vector3(a, a, a)); verts.append(Vector3(a, b, a))
	verts.append(Vector3(b, a, a)); verts.append(Vector3(b, b, a))
	verts.append(Vector3(b, a, b)); verts.append(Vector3(b, b, b))
	verts.append(Vector3(a, a, b)); verts.append(Vector3(a, b, b))

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


func show_at(block_pos: Vector3i) -> void:
	global_position = Vector3(block_pos)
	visible = true


func hide_outline() -> void:
	visible = false
