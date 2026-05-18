class_name ItemDrop
extends CharacterBody3D

## Physical item drop. Spawns with a brief arc, lands on the ground, bobs,
## and is collected when the player walks within range.
## Uses CharacterBody3D + move_and_slide() for solid collision identical to
## the player: no edge-glitching, falls when the block below is removed.

const DROP_SIZE: float = 0.32
const COLLIDER_RADIUS: float = 0.13  # sphere collider radius
const MESH_HOVER: float = 0.08       # visual offset of mesh above body centre
const BOB_AMP: float = 0.06
const BOB_FREQ: float = 2.0
const SPIN_SPEED: float = 2.3
const GRAVITY: float = 22.0
const DESPAWN_TIME: float = 600.0
const MERGE_RADIUS: float = 0.8
const MERGE_CHECK_INTERVAL: float = 2.0

# Cylindrical attraction zone
const H_ATTRACT: float = 1.5
const V_ATTRACT_MIN: float = -0.5
const V_ATTRACT_MAX: float = 2.0
const ATTRACT_BASE_SPEED: float = 9.0
const COLLECT_DIST: float = 0.35

var item_id: int = 0
var item_count: int = 1

var _mesh: MeshInstance3D = null
var _is_item_drop: bool = false
var _is_sprite_block: bool = false
var _time: float = 0.0
var _despawn_timer: float = DESPAWN_TIME
var _collected: bool = false
var _attracting: bool = false
var _pickup_immune: float = 0.0

var _world: Node = null
var _player: Node = null
var _merge_timer: float = 0.0
var _sub_meshes: Array[MeshInstance3D] = []
var _light_timer: float = 0.0
var _item_base_color: Color = Color.WHITE

static var _item_tex_cache: Dictionary = {}


func setup(id: int, count: int, atlas: ImageTexture, world_ref: Node, player_ref: Node) -> void:
	item_id = id
	item_count = count
	_world = world_ref
	_player = player_ref
	_is_item_drop = Items.is_item(id)
	_is_sprite_block = not _is_item_drop and BlockIcon._is_sprite_block(id)
	_merge_timer = randf_range(0.3, 1.2)
	add_to_group("item_drops")

	# Collide with world geometry (layer 1) but don't occupy the player's layer,
	# so items never physically block the player.
	collision_layer = 4
	collision_mask = 1
	up_direction = Vector3.UP
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(55.0)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = COLLIDER_RADIUS
	col.shape = sphere
	add_child(col)

	# Initial pop-out arc
	var angle: float = randf() * TAU
	var hspeed: float = randf_range(0.8, 2.0)
	velocity = Vector3(cos(angle) * hspeed, randf_range(3.0, 5.0), sin(angle) * hspeed)

	_mesh = MeshInstance3D.new()
	_mesh.scale = Vector3(DROP_SIZE, DROP_SIZE, DROP_SIZE)
	_mesh.position.y = MESH_HOVER
	if _is_item_drop:
		_mesh.mesh = _build_billboard_mesh()
		_mesh.material_override = _build_item_material(id)
		_fetch_item_texture(id)
	elif _is_sprite_block:
		_mesh.mesh = _build_sprite_mesh(id)
		_mesh.material_override = _build_block_material(atlas)
	else:
		_mesh.mesh = _build_cube_mesh(id)
		_mesh.material_override = _build_block_material(atlas)
	add_child(_mesh)


func set_thrown(vel: Vector3) -> void:
	velocity = vel
	_pickup_immune = 1.0


func _physics_process(delta: float) -> void:
	if _collected:
		return

	if _attracting:
		if _player == null or not is_instance_valid(_player):
			_attracting = false
			return
		var target: Vector3 = _player.global_position + Vector3(0.0, 0.7, 0.0)
		var to_target: Vector3 = target - global_position
		var dist: float = to_target.length()
		if dist < COLLECT_DIST:
			_collect()
			return
		var t: float = clampf(1.0 - dist / (H_ATTRACT * 1.5), 0.0, 1.0)
		var speed: float = ATTRACT_BASE_SPEED * (1.0 + t * 6.0)
		# Fly directly — bypasses walls the same way the original did.
		global_position += to_target.normalized() * speed * delta
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	move_and_slide()

	if global_position.y < -20.0:
		queue_free()


func _process(delta: float) -> void:
	if _collected:
		return

	_time += delta
	_despawn_timer -= delta
	if _despawn_timer <= 0.0:
		queue_free()
		return

	if _world != null and is_instance_valid(_world) and _world.has_method("get_voxel"):
		var gp: Vector3 = global_position
		if _world.get_voxel(int(floor(gp.x)), int(floor(gp.y)), int(floor(gp.z))) == Chunk.Block.LAVA:
			queue_free()
			return

	_merge_timer -= delta
	if _merge_timer <= 0.0:
		_merge_timer = MERGE_CHECK_INTERVAL
		_try_merge()

	if _pickup_immune > 0.0:
		_pickup_immune -= delta

	# ── Mesh orientation ──────────────────────────────────────────────────────
	if _mesh != null:
		if _is_item_drop or _is_sprite_block:
			if _player != null and is_instance_valid(_player):
				var to_player: Vector3 = _player.global_position - global_position
				to_player.y = 0.0
				if to_player.length_squared() > 0.001:
					_mesh.rotation.y = atan2(to_player.x, to_player.z)
		else:
			_mesh.rotation.y = _time * SPIN_SPEED

	# ── Bob + attract shrink ───────────────────────────────────────────────────
	if _mesh != null:
		if _attracting:
			if _player != null and is_instance_valid(_player):
				var dist: float = global_position.distance_to(_player.global_position)
				var sf: float = clampf(dist / H_ATTRACT, 0.08, 1.0)
				_mesh.scale = Vector3.ONE * DROP_SIZE * sf
		elif is_on_floor():
			_mesh.scale = Vector3.ONE * DROP_SIZE
			_mesh.position.y = MESH_HOVER + sin(_time * BOB_FREQ) * BOB_AMP
		else:
			_mesh.position.y = MESH_HOVER

	# ── Lighting update for block drops ──────────────────────────────────────
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.5
		_update_local_light()

	# ── Attract zone check ────────────────────────────────────────────────────
	if _pickup_immune <= 0.0 and not _attracting \
			and _player != null and is_instance_valid(_player):
		var pp: Vector3 = _player.global_position
		var dx: float = global_position.x - pp.x
		var dz: float = global_position.z - pp.z
		var v_off: float = global_position.y - pp.y
		if dx * dx + dz * dz < H_ATTRACT * H_ATTRACT \
				and v_off > V_ATTRACT_MIN and v_off < V_ATTRACT_MAX:
			_attracting = true
			if _mesh != null:
				_mesh.scale = Vector3.ONE * DROP_SIZE


func _try_merge() -> void:
	if _collected or not is_inside_tree():
		return
	var my_pos: Vector3 = global_position
	for node: Node in get_tree().get_nodes_in_group("item_drops"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as ItemDrop
		if other == null or other._collected or other.item_id != item_id:
			continue
		if my_pos.distance_to(other.global_position) > MERGE_RADIUS:
			continue
		item_count += other.item_count
		other._collected = true
		other.queue_free()
		_update_visual_stack()


func _visual_count() -> int:
	if item_count >= 50: return 5
	if item_count >= 20: return 4
	if item_count >= 5:  return 3
	if item_count >= 2:  return 2
	return 1


func _update_visual_stack() -> void:
	for sm: MeshInstance3D in _sub_meshes:
		if is_instance_valid(sm):
			sm.queue_free()
	_sub_meshes.clear()
	if _mesh == null:
		return
	var vc: int = _visual_count()
	if vc <= 1:
		return
	const OFFSETS: Array[Vector3] = [
		Vector3(0.55,  0.0,  0.45),
		Vector3(-0.50, 0.05, -0.55),
		Vector3(0.50,  0.10, -0.50),
		Vector3(-0.45, 0.15,  0.50),
	]
	var mat: Material = _mesh.material_override
	for i: int in range(vc - 1):
		var sm := MeshInstance3D.new()
		sm.mesh = _mesh.mesh
		sm.material_override = mat
		sm.scale = Vector3.ONE * 0.82
		sm.position = OFFSETS[i]
		_mesh.add_child(sm)
		_sub_meshes.append(sm)


func _update_local_light() -> void:
	if _mesh == null or not is_instance_valid(_mesh):
		return
	var mat: Material = _mesh.material_override
	if _world == null or not is_instance_valid(_world) or not _world.has_method("get_sky_access"):
		return
	var wx: int = int(global_position.x)
	var wy: int = int(global_position.y + 0.5)
	var wz: int = int(global_position.z)
	var sky: float = _world.get_sky_access(wx, wy, wz)
	var glow: float = 0.0
	for lpos: Vector3i in _world.light_emitters:
		var wlpos := Vector3(lpos.x + 0.5, lpos.y + 0.5, lpos.z + 0.5)
		var lvl: int = _world.light_emitters[lpos]
		var dist: float = global_position.distance_to(wlpos)
		glow = maxf(glow, maxf(0.0, 1.0 - dist / float(lvl)))
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat as ShaderMaterial
		sm.set_shader_parameter("sky_access", sky)
		sm.set_shader_parameter("block_glow", glow)
	elif mat is StandardMaterial3D:
		const CAVE_AMBIENT_F: float = 0.05
		const MIN_BRIGHT: float = 0.12
		var bright: float = maxf(MIN_BRIGHT, CAVE_AMBIENT_F + sky * 0.8 + glow * 0.55)
		(mat as StandardMaterial3D).albedo_color = _item_base_color * bright


func _build_billboard_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	const HS: float = 0.5
	verts.append(Vector3(-HS, -HS, 0.0)); verts.append(Vector3(HS, -HS, 0.0)); verts.append(Vector3(HS, HS, 0.0))
	verts.append(Vector3(-HS, -HS, 0.0)); verts.append(Vector3(HS, HS, 0.0)); verts.append(Vector3(-HS, HS, 0.0))
	for _i: int in 6:
		normals.append(Vector3(0.0, 0.0, 1.0))
	uvs.append(Vector2(0, 1)); uvs.append(Vector2(1, 1)); uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 1)); uvs.append(Vector2(1, 0)); uvs.append(Vector2(0, 0))
	for _i: int in 6:
		uv2s.append(Vector2(0.0, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_sprite_mesh(block_type: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var tile_idx: float = Chunk._tile_index(block_type, Chunk.DIR_YP)
	const HS: float = 0.5
	verts.append(Vector3(-HS, -HS, 0.0)); verts.append(Vector3(HS, -HS, 0.0)); verts.append(Vector3(HS, HS, 0.0))
	verts.append(Vector3(-HS, -HS, 0.0)); verts.append(Vector3(HS, HS, 0.0)); verts.append(Vector3(-HS, HS, 0.0))
	for _i: int in 6:
		normals.append(Vector3(0.0, 0.0, 1.0))
	uvs.append(Vector2(0, 1)); uvs.append(Vector2(1, 1)); uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 1)); uvs.append(Vector2(1, 0)); uvs.append(Vector2(0, 0))
	for _i: int in 6:
		uv2s.append(Vector2(tile_idx, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_cube_mesh(block_type: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for dir: int in 6:
		var tile_idx: float = Chunk._tile_index(block_type, dir)
		var face_verts: Array = Chunk.FACE_VERTS[dir]
		var face_uvs: Array = Chunk.FACE_UVS[dir]
		var normal: Vector3 = Chunk.NORMALS[dir]
		for i: int in 6:
			verts.append(face_verts[i] - Vector3(0.5, 0.5, 0.5))
			normals.append(normal)
			uvs.append(face_uvs[i])
			uv2s.append(Vector2(tile_idx, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var amesh := ArrayMesh.new()
	amesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return amesh


func _build_item_material(id: int) -> StandardMaterial3D:
	_item_base_color = Items.get_item_color(id)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _item_base_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _fetch_item_texture(id: int) -> void:
	if _item_tex_cache.has(id):
		_apply_item_texture(_item_tex_cache[id])
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	get_tree().root.add_child(vp)
	var ctrl := ItemIconView.new()
	ctrl.size = Vector2(64.0, 64.0)
	ctrl._icon_id = id
	vp.add_child(ctrl)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self):
		vp.queue_free()
		return
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	var tex := ImageTexture.create_from_image(img)
	_item_tex_cache[id] = tex
	if is_instance_valid(self) and _mesh != null:
		_apply_item_texture(tex)


func _apply_item_texture(tex: ImageTexture) -> void:
	if not is_instance_valid(_mesh):
		return
	_item_base_color = Color.WHITE
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.1
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat
	for sm: MeshInstance3D in _sub_meshes:
		if is_instance_valid(sm):
			sm.material_override = mat


func _build_block_material(atlas: ImageTexture) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://held_item.gdshader") as Shader
	mat.set_shader_parameter("block_atlas", atlas)
	return mat


func _collect() -> void:
	if _collected:
		return
	_collected = true
	if _player != null and is_instance_valid(_player):
		var hud = _player.get("hud")
		if hud != null and hud.has_method("give_item"):
			hud.give_item(item_id, item_count)
	queue_free()
