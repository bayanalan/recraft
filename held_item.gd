extends Control

## First-person held-item display. Shows the currently-selected hotbar block
## as a small 3D cube (or flat sprite for plant blocks) in the bottom-right
## corner. Plays a short rotate-forward "swing" animation whenever the
## player breaks or places a block.
##
## Rendering isolation:
##   - Dedicated SubViewport with its own World3D so the held item can't pick
##     up fog / sky / directional lights from the main scene.
##   - Orthographic camera guarantees no perspective foreshortening, so the
##     cube always reads as a perfectly-proportioned cube (no "warping").
##   - Square viewport + square container keep the aspect ratio at 1:1 so
##     textures don't stretch.
##   - Dedicated shader matches voxel.gdshader's tile sampling math but
##     skips fog / block lights / portals.

const VIEWPORT_SIZE: int = 512              # square, keeps aspect at 1:1
const BASE_DISPLAY_SIZE: int = 520          # on-screen size in UI pixels
# Negative margins push the container past the screen edge so the cube
# partially clips off-screen — matches Minecraft's first-person view where
# the held item "extends" beyond the visible frame.
const MARGIN_RIGHT: float = -155.0
const MARGIN_BOTTOM: float = -155.0

# Ortho frustum half-height. Sized just slightly bigger than the cube's
# full silhouette (≈0.866 for a 1×1×1 rotated diagonally) so the cube
# visually dominates the display while still leaving a little swing margin.
const CAMERA_ORTHO_SIZE: float = 2.0

# Idle pose — cube centered in its viewport (the whole viewport already
# sits in the bottom-right corner of the screen, so we don't need to offset
# the mesh inside it). Angles chosen to show the top, front, and right
# faces in a classic Minecraft three-quarter view.
#
# In Godot, positive X-rotation rotates +Y toward +Z (toward the camera at
# +Z), so a +25° X tilt exposes the top face. Swing forward = top tips away
# from the camera = NEGATIVE X delta.
const IDLE_ROT_X: float = 0.436         # +25° — exposes top face
const IDLE_ROT_Y: float = 0.524         # +30° — quarter turn for 3-face view
const IDLE_POS := Vector3(0.0, 0.0, 0.0)

# Swing animation — quick rotation-forward tap with a small downward dip
# and return. Sine curve peaks at mid-swing. Kept short and subtle so rapid
# clicks don't feel sluggish or flail-y.
const SWING_DURATION: float = 0.18
const SWING_ROT_X_DELTA: float = -0.524 # -30° — noticeable tip without over-swing
const SWING_POS_Y_DELTA: float = -0.06  # small chop

var _container: SubViewportContainer = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _mesh_instance: MeshInstance3D = null
var _material: ShaderMaterial = null
var _atlas: ImageTexture = null

# -1 = forces rebuild on first _process so the mesh matches the hotbar.
var _current_block: int = -1
# -1 = idle; otherwise holds elapsed swing time in seconds.
var _swing_time: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_atlas = BlockTextures.create_atlas()
	_build_viewport()
	_position_container()
	get_viewport().size_changed.connect(_position_container)
	set_process(true)


func _build_viewport() -> void:
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.stretch_shrink = 1
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nearest-neighbor scale so the pixel-art textures stay crisp when the
	# SubViewport is composited down to the display size.
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEWPORT_SIZE, VIEWPORT_SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	# Own World3D: the held item's scene is fully isolated — no ambient from
	# main.tscn's WorldEnvironment, no chunks visible, no fog.
	_viewport.own_world_3d = true
	_container.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.near = 0.05
	_camera.far = 10.0
	_camera.position = Vector3(0, 0, 3)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_viewport.add_child(_camera)

	_material = ShaderMaterial.new()
	_material.shader = load("res://held_item.gdshader") as Shader
	_material.set_shader_parameter("block_atlas", _atlas)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.position = IDLE_POS
	_mesh_instance.rotation = Vector3(IDLE_ROT_X, IDLE_ROT_Y, 0)
	_mesh_instance.material_override = _material
	_viewport.add_child(_mesh_instance)


func _position_container() -> void:
	if _container == null:
		return
	_container.anchor_left = 1.0
	_container.anchor_right = 1.0
	_container.anchor_top = 1.0
	_container.anchor_bottom = 1.0
	_container.offset_left = -BASE_DISPLAY_SIZE - MARGIN_RIGHT
	_container.offset_right = -MARGIN_RIGHT
	_container.offset_top = -BASE_DISPLAY_SIZE - MARGIN_BOTTOM
	_container.offset_bottom = -MARGIN_BOTTOM


func _process(delta: float) -> void:
	# Mirror the hotbar selection. Cheap poll — no need for signal plumbing.
	var hud: Node = get_parent()
	if hud != null and hud.has_method("get_selected_block"):
		var sel: int = hud.get_selected_block()
		if sel != _current_block:
			_set_block(sel)

	if _swing_time >= 0.0:
		_swing_time += delta
		if _swing_time >= SWING_DURATION:
			_swing_time = -1.0
			_mesh_instance.position = IDLE_POS
			_mesh_instance.rotation = Vector3(IDLE_ROT_X, IDLE_ROT_Y, 0)
		else:
			# sin(π·t) sweeps 0 → 1 → 0 over the clip, so the pose tweens out
			# at mid-swing and snaps back without needing a separate return leg.
			var s: float = sin((_swing_time / SWING_DURATION) * PI)
			_mesh_instance.rotation = Vector3(
				IDLE_ROT_X + SWING_ROT_X_DELTA * s,
				IDLE_ROT_Y,
				0.0,
			)
			_mesh_instance.position = IDLE_POS + Vector3(0.0, SWING_POS_Y_DELTA * s, 0.0)


func _set_block(block_type: int) -> void:
	_current_block = block_type
	if block_type == Chunk.Block.AIR:
		_mesh_instance.mesh = null
		_container.visible = false
		return
	_container.visible = true
	_mesh_instance.mesh = _build_mesh_for(block_type)


## Build an ArrayMesh representing `block_type` as it should appear in hand.
## Cube blocks use Chunk.FACE_VERTS / FACE_UVS so every face shows the
## correct atlas tile (grass top/side/bottom differ, TNT differs, etc.).
## Sprite blocks render as a single camera-facing quad to match the
## inventory view — a crossed-quad mesh would look odd in isolation.
func _build_mesh_for(block_type: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()

	if BlockIcon._is_sprite_block(block_type):
		var tile_idx: float = Chunk._tile_index(block_type, Chunk.DIR_YP)
		# Flat quad centered on origin, facing +Z (camera).
		const HS: float = 0.5
		verts.append(Vector3(-HS, -HS, 0)); verts.append(Vector3( HS, -HS, 0)); verts.append(Vector3( HS,  HS, 0))
		verts.append(Vector3(-HS, -HS, 0)); verts.append(Vector3( HS,  HS, 0)); verts.append(Vector3(-HS,  HS, 0))
		# Normal (0,1,0) instead of (0,0,1) so the shader's face_shade treats
		# the sprite like a top face (bright) — matches chunk.gd's plant mesh
		# which uses the same trick so flowers/torches render full-bright.
		for i: int in 6:
			normals.append(Vector3(0, 1, 0))
		# UVs follow the plant-quad convention from chunk.gd:_write_plant_quad
		# — v=1 at the bottom so the sprite isn't upside-down.
		uvs.append(Vector2(0, 1)); uvs.append(Vector2(1, 1)); uvs.append(Vector2(1, 0))
		uvs.append(Vector2(0, 1)); uvs.append(Vector2(1, 0)); uvs.append(Vector2(0, 0))
		for i: int in 6:
			uv2s.append(Vector2(tile_idx, 0))
	else:
		for dir: int in 6:
			var tile_idx: float = Chunk._tile_index(block_type, dir)
			var face_verts: Array = Chunk.FACE_VERTS[dir]
			var face_uvs: Array = Chunk.FACE_UVS[dir]
			var normal: Vector3 = Chunk.NORMALS[dir]
			for i: int in 6:
				var v: Vector3 = face_verts[i]
				# Chunk.FACE_VERTS are in [0,1] cell coords; recenter the cube
				# on the origin so rotation happens around its own center.
				verts.append(v - Vector3(0.5, 0.5, 0.5))
				normals.append(normal)
				uvs.append(face_uvs[i])
				uv2s.append(Vector2(tile_idx, 0))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Kick off the rotate-forward swing. Safe to call while one is already in
## progress — it restarts from frame zero, which matches rapid-click
## responsiveness (each click visibly registers).
func swing() -> void:
	_swing_time = 0.0


## Called by main.gd when the atlas is rebuilt (mipmap toggle). Keeps the
## held item in sync with the placed-block texture source.
func refresh_atlas() -> void:
	_atlas = BlockTextures.create_atlas()
	if _material != null:
		_material.set_shader_parameter("block_atlas", _atlas)


## Exposes the held-item shader material so main.gd can add it to the list
## that receives every frame's sky_light / ambient_light push. Named with
## "block_" prefix to avoid colliding with CanvasItem.get_material().
func get_block_material() -> ShaderMaterial:
	return _material
