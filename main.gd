extends Node3D

@onready var player: Player = $Player
@onready var world: World = $World
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var hud: Node = $HUD

# True while a save (or load) is in progress. Blocks re-entrant save requests
# and prevents the pause menu from being dismissed mid-operation.
var _saving: bool = false
var _current_world_name: String = "My World"
var _last_show_barriers: bool = false
# Dimension state: 0 = overworld, 1 = nether.
var _current_dimension: int = 0
# Cached voxel data for the inactive dimension so we can swap back.
var _overworld_voxels: PackedByteArray = PackedByteArray()
var _nether_voxels: PackedByteArray = PackedByteArray()
var _overworld_player_pos: Vector3 = Vector3.ZERO
var _nether_player_pos: Vector3 = Vector3.ZERO
var _nether_generated: bool = false
var _portal_cooldown: float = 0.0
# True while the player is physically inside a portal block. Must fully
# exit (no portal contact) before the portal can trigger again — prevents
# bouncing back and forth or getting stuck.
var _in_portal: bool = false
# Remembered overworld portal position so the return trip goes to the
# same portal, not a random spawn.
var _overworld_portal_pos: Vector3 = Vector3.ZERO

# --- Day/night cycle ---
# _day_time goes from 0.0 to 1.0 continuously. 0.0 = dawn, 0.25 = noon,
# 0.5 = dusk, 0.75 = midnight. Full cycle = 30 real minutes.
const DAY_CYCLE_BASE_SECONDS: float = 30.0 * 60.0  # 1800s at tick rate 20
var _day_time: float = 0.0   # start at dawn
# Game rules — toggled via chat commands.
var do_daylight_cycle: bool = true
var tick_rate: float = 20.0   # base=20; higher = faster day/night
var noclip: bool = false
# Sun/moon visual nodes — created in _ready.
var _sun_mesh: MeshInstance3D = null
var _moon_mesh: MeshInstance3D = null
# The orbit radius is purely visual — the light direction is computed from
# _day_time, not from the mesh position.
const SKY_ORBIT_RADIUS: float = 200.0
const SUN_SIZE: float = 30.0
const MOON_SIZE: float = 22.0


func _ready() -> void:
	# Apply any persisted key bindings before children start polling Input.
	ControlsConfig.load_into_inputmap()
	_setup_pixel_font()
	_wire_pause_menu()
	get_tree().root.size_changed.connect(_on_window_size_changed)
	if hud != null and hud.has_node("BlockSelect"):
		var bs: Node = hud.get_node("BlockSelect")
		if bs.has_signal("closed"):
			bs.closed.connect(_on_block_select_closed)
	_setup_day_night()
	_start_from_config()


func _start_from_config() -> void:
	# Start paused with the loading overlay so the player never sees a bare
	# empty world before generation/loading finishes.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameConfig.start_mode == GameConfig.StartMode.LOAD_WORLD and GameConfig.save_name != "":
		_current_world_name = GameConfig.save_name
		_on_load_requested(GameConfig.save_name)
	else:
		_on_new_world_requested(
			GameConfig.world_size,
			GameConfig.terrain_type,
			GameConfig.world_seed,
			GameConfig.world_name if GameConfig.world_name != "" else "My World",
		)


func _on_window_size_changed() -> void:
	if pause_menu != null:
		_apply_gui_scale(pause_menu.gui_scale)


func _process(delta: float) -> void:
	# Toggle barrier visibility based on what the player is holding.
	if hud == null or world == null or world.material == null:
		return
	var holding: bool = hud.get_selected_block() == Chunk.Block.BARRIER
	if holding != _last_show_barriers:
		_last_show_barriers = holding
		world.material.set_shader_parameter("show_barriers", holding)
	# Noclip — disable player collision so they pass through blocks.
	if player != null:
		var want_noclip: bool = noclip
		if player.collision_layer != (0 if want_noclip else 1):
			player.collision_layer = 0 if want_noclip else 1
			player.collision_mask = 0 if want_noclip else 1
	# Portal check — teleport only when the player walks INTO a portal, not
	# while they remain inside it. Must fully exit before it fires again.
	_portal_cooldown = maxf(0.0, _portal_cooldown - delta)
	if player != null and world != null:
		var px: int = int(floor(player.global_position.x))
		var py: int = int(floor(player.global_position.y))
		var pz: int = int(floor(player.global_position.z))
		var touching: bool = world.get_voxel(px, py, pz) == Chunk.Block.NETHER_PORTAL \
				or world.get_voxel(px, py + 1, pz) == Chunk.Block.NETHER_PORTAL
		if touching:
			if not _in_portal and _portal_cooldown <= 0.0:
				_in_portal = true
				_switch_dimension()
		else:
			_in_portal = false
	# Day/night cycle — advance time and push lighting to shaders.
	_update_day_night(delta)


## Switch between overworld (0) and nether (1). Saves the current
## dimension's voxels to a cache, then loads or generates the other.
func _switch_dimension() -> void:
	if _saving:
		return
	_saving = true
	_portal_cooldown = 3.0  # prevent instant bounce-back
	var target: int = 1 if _current_dimension == 0 else 0

	# 1. Cache current dimension's voxel data + player position.
	pause_menu.show_loading("Entering " + ("Nether" if target == 1 else "Overworld") + "...")
	await get_tree().process_frame
	world.generation_progress.connect(_on_generation_progress)
	var current_voxels: PackedByteArray = await _collect_voxels()
	if _current_dimension == 0:
		_overworld_voxels = current_voxels
		_overworld_player_pos = player.global_position
	else:
		_nether_voxels = current_voxels
		_nether_player_pos = player.global_position

	# 2. Load or generate the target dimension.
	if target == 1:
		# Going to nether — remember the overworld portal position for return.
		_overworld_portal_pos = player.global_position
		if _nether_generated and _nether_voxels.size() > 0:
			await world.load_from_save(world.world_size_blocks, _nether_voxels, world.world_seed, world.current_terrain_type)
			player.global_position = _nether_player_pos
		else:
			world.dimension = 1
			await world.regenerate_nether(world.world_size_blocks, world.world_seed)
			# Spawn return portal ON the surface so the player can find it.
			var sp: Vector3 = world.find_spawn_position()
			_build_return_portal(int(sp.x), int(sp.y), int(sp.z))
			# Position player just outside the portal, not inside it.
			player.global_position = sp + Vector3(0, 0, -2)
			_nether_generated = true
		world.dimension = 1
	else:
		# Going back to overworld — return to the overworld portal position.
		if _overworld_voxels.size() > 0:
			world.dimension = 0
			await world.load_from_save(world.world_size_blocks, _overworld_voxels, world.world_seed, world.current_terrain_type)
			# Return to remembered portal position, offset slightly so we
			# don't spawn inside the portal and immediately bounce back.
			player.global_position = _overworld_portal_pos + Vector3(2, 0, 0)
		world.dimension = 0

	_current_dimension = target
	player.velocity = Vector3.ZERO
	# Validate the player isn't inside solid blocks or in the void.
	# If the position is invalid, fall back to the world spawn.
	_ensure_valid_position()
	_in_portal = true  # suppress until player walks out
	_portal_cooldown = 1.0
	world.generation_progress.disconnect(_on_generation_progress)

	# Full save after every portal transition so no progress is lost —
	# both the active dimension's voxels and all game state are written.
	if _current_world_name != "" and FileAccess.file_exists("user://saves/" + _current_world_name + ".save"):
		world.generation_progress.connect(_on_generation_progress)
		var gs_save: Dictionary = _build_game_state_dict()
		await world.save_to_file(_current_world_name, player.global_position, gs_save)
		world.generation_progress.disconnect(_on_generation_progress)
		_save_dimension_cache(_current_world_name)
		var state_path: String = "user://saves/" + _current_world_name + ".state"
		var sf: FileAccess = FileAccess.open(state_path, FileAccess.WRITE)
		if sf != null:
			sf.store_string(JSON.stringify(gs_save))
			sf.close()

	_saving = false
	_resume_game()


## Build a small obsidian portal frame + portal blocks near the given
## position so the player can return to the overworld.
func _build_return_portal(wx: int, wy: int, wz: int) -> void:
	# 5 wide × 5 tall frame in the XY plane (interior 3×3), offset 3 blocks
	# in front of spawn so the player doesn't spawn inside it.
	var pz: int = wz + 3
	var size: int = world.world_size_blocks
	if pz >= size - 1:
		pz = wz - 3
	# Clear space and build frame.
	for dx: int in range(-2, 3):
		for dy: int in range(0, 5):
			var bx: int = wx + dx
			var by: int = wy + dy
			if bx < 0 or bx >= size or by < 0 or by >= size or pz < 0 or pz >= size:
				continue
			var is_frame: bool = dx == -2 or dx == 2 or dy == 0 or dy == 4
			if is_frame:
				world.set_voxel(bx, by, pz, Chunk.Block.OBSIDIAN)
			else:
				world.set_voxel(bx, by, pz, Chunk.Block.NETHER_PORTAL)


## Quickly serialize all chunk voxels to a flat PackedByteArray (same format
## as the save file's voxel buffer). Used for dimension caching.
func _collect_voxels() -> PackedByteArray:
	var size: int = world.world_size_blocks
	var data := PackedByteArray()
	data.resize(size * size * size)
	var size2: int = size * size
	for chunk: Chunk in world.chunks.values():
		var cp: Vector3i = chunk.chunk_position
		var bx: int = cp.x << 4
		var by: int = cp.y << 4
		var bz: int = cp.z << 4
		var vox: PackedByteArray = chunk.voxels
		for lz: int in 16:
			var dst_z: int = (bz + lz) * size2
			var src_z: int = lz << 8
			for ly: int in 16:
				var src_start: int = src_z + (ly << 4)
				var dst_start: int = bx + (by + ly) * size + dst_z
				for lx: int in 16:
					data[dst_start + lx] = vox[src_start + lx]
	return data


func _setup_day_night() -> void:
	_sun_mesh = _make_sky_body(SUN_SIZE, _make_sun_texture())
	add_child(_sun_mesh)
	_moon_mesh = _make_sky_body(MOON_SIZE, _make_moon_texture())
	add_child(_moon_mesh)


func _make_sky_body(size: float, tex: ImageTexture) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Procedural 16×16 sun texture — bright yellow-white circle with warm
## corona rays extending to the corners, pixel-art style.
static func _make_sun_texture() -> ImageTexture:
	const S: int = 16
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(7.5, 7.5)
	for y: int in S:
		for x: int in S:
			var d: float = Vector2(x, y).distance_to(center)
			if d < 4.5:
				# Bright core — white center fading to warm yellow
				var t: float = d / 4.5
				var r: float = lerpf(1.0, 1.0, t)
				var g: float = lerpf(1.0, 0.85, t)
				var b: float = lerpf(0.9, 0.35, t)
				img.set_pixel(x, y, Color(r, g, b, 1.0))
			elif d < 6.5:
				# Orange corona ring
				img.set_pixel(x, y, Color(1.0, 0.65, 0.15, 1.0))
	# Ray spokes — 4 cardinal + 4 diagonal, 1px wide
	for i: int in range(0, 3):
		var off: int = 5 + i
		# Cardinal rays (up/down/left/right)
		img.set_pixel(7, off, Color(1.0, 0.8, 0.2, 1.0))
		img.set_pixel(8, off, Color(1.0, 0.8, 0.2, 1.0))
		img.set_pixel(7, S - 1 - off, Color(1.0, 0.8, 0.2, 1.0))
		img.set_pixel(8, S - 1 - off, Color(1.0, 0.8, 0.2, 1.0))
		img.set_pixel(off, 7, Color(1.0, 0.8, 0.2, 1.0))
		img.set_pixel(off, 8, Color(1.0, 0.8, 0.2, 1.0))
		img.set_pixel(S - 1 - off, 7, Color(1.0, 0.8, 0.2, 1.0))
		img.set_pixel(S - 1 - off, 8, Color(1.0, 0.8, 0.2, 1.0))
	# Short diagonal rays
	for i: int in range(0, 2):
		var off: int = 5 + i
		var opp: int = S - 1 - off
		img.set_pixel(off, off, Color(1.0, 0.7, 0.15, 1.0))
		img.set_pixel(opp, off, Color(1.0, 0.7, 0.15, 1.0))
		img.set_pixel(off, opp, Color(1.0, 0.7, 0.15, 1.0))
		img.set_pixel(opp, opp, Color(1.0, 0.7, 0.15, 1.0))
	return ImageTexture.create_from_image(img)


## Procedural 16×16 moon texture — gray-blue circle with dark crater spots,
## clearly distinct from the sun.
static func _make_moon_texture() -> ImageTexture:
	const S: int = 16
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(7.5, 7.5)
	# Base moon disc
	for y: int in S:
		for x: int in S:
			var d: float = Vector2(x, y).distance_to(center)
			if d < 6.5:
				var t: float = d / 6.5
				var r: float = lerpf(0.85, 0.65, t)
				var g: float = lerpf(0.88, 0.70, t)
				var b: float = lerpf(0.95, 0.80, t)
				img.set_pixel(x, y, Color(r, g, b, 1.0))
	# Dark craters — a few fixed spots
	var craters: Array[Vector2i] = [
		Vector2i(5, 6), Vector2i(6, 6),
		Vector2i(9, 4), Vector2i(10, 4), Vector2i(9, 5),
		Vector2i(7, 9), Vector2i(8, 9), Vector2i(8, 10),
		Vector2i(5, 10),
		Vector2i(10, 8),
	]
	var crater_col := Color(0.55, 0.58, 0.65, 1.0)
	for c: Vector2i in craters:
		if c.x >= 0 and c.x < S and c.y >= 0 and c.y < S:
			var d: float = Vector2(c.x, c.y).distance_to(center)
			if d < 6.0:
				img.set_pixel(c.x, c.y, crater_col)
	return ImageTexture.create_from_image(img)


func _update_day_night(delta: float) -> void:
	if not is_instance_valid(player):
		return
	# Advance clock — wraps at 1.0. Gated by doDaylightCycle game rule.
	# tick_rate scales the speed: base 20 = normal, 40 = 2× speed, etc.
	if do_daylight_cycle:
		var speed: float = tick_rate / 20.0
		_day_time = fmod(_day_time + delta * speed / DAY_CYCLE_BASE_SECONDS, 1.0)

	# Sun angle: 0 at dawn (horizon), PI/2 at noon (top), PI at dusk, 2PI back.
	var angle: float = _day_time * TAU

	# Position sun/moon in the sky relative to the player. They orbit in a
	# circle so they look like fixed celestial objects — not billboards.
	# look_at orients the quad face toward the player each frame.
	var cam_pos: Vector3 = player.global_position
	var sun_offset := Vector3(-cos(angle), sin(angle), -0.3).normalized() * SKY_ORBIT_RADIUS
	var moon_offset := Vector3(cos(angle), -sin(angle), -0.3).normalized() * SKY_ORBIT_RADIUS
	if _sun_mesh != null:
		_sun_mesh.global_position = cam_pos + sun_offset
		_sun_mesh.look_at(cam_pos, Vector3.UP)
		_sun_mesh.visible = _current_dimension == 0 and sin(angle) > -0.15
	if _moon_mesh != null:
		_moon_mesh.global_position = cam_pos + moon_offset
		_moon_mesh.look_at(cam_pos, Vector3.UP)
		_moon_mesh.visible = _current_dimension == 0 and sin(angle) < 0.15

	# Lighting interpolation based on sun altitude.
	# sun_alt: 1.0 at noon, 0.0 at horizon, negative at night.
	var sun_alt: float = sin(angle)
	# day_factor: 1.0 during full day, 0.0 at night, smooth transition at
	# dawn/dusk over a ~10% band of the cycle.
	var day_factor: float = smoothstep(-0.15, 0.2, sun_alt)

	# Ambient + sky light — nether has constant dim reddish lighting, no cycle.
	var ambient: Vector3
	var sky_light: Vector3
	if _current_dimension == 1:
		ambient = Vector3(0.18, 0.08, 0.06)
		sky_light = Vector3(0.30, 0.15, 0.10)
	else:
		var day_ambient := Vector3(0.20, 0.22, 0.28)
		var night_ambient := Vector3(0.08, 0.09, 0.14)
		ambient = day_ambient * day_factor + night_ambient * (1.0 - day_factor)
		var day_sky_light := Vector3(0.58, 0.56, 0.50)
		sky_light = day_sky_light * day_factor

	# Sky color — nether has a constant dark red sky, no day/night cycle.
	var sky: Color
	if _current_dimension == 1:
		sky = Color(0.18, 0.04, 0.02)
	else:
		var day_sky := Color(0.53, 0.76, 0.98)
		var night_sky := Color(0.02, 0.02, 0.06)
		var sunset_sky := Color(0.85, 0.45, 0.20)
		if sun_alt > 0.15:
			sky = day_sky
		elif sun_alt > -0.05:
			var t2: float = (sun_alt + 0.05) / 0.20
			sky = night_sky.lerp(sunset_sky, t2) if t2 < 0.5 else sunset_sky.lerp(day_sky, (t2 - 0.5) * 2.0)
		else:
			sky = night_sky

	# Push to all three shaders — just two uniforms now (no direction).
	var ambient_col := Color(ambient.x, ambient.y, ambient.z)
	var sky_light_col := Color(sky_light.x, sky_light.y, sky_light.z)
	var fog_col := sky
	for mat: ShaderMaterial in _get_all_shader_materials():
		mat.set_shader_parameter("sky_light", sky_light_col)
		mat.set_shader_parameter("ambient_light", ambient_col)
	# Fog color matches sky so the horizon blends correctly at any time of day.
	if world.material != null:
		world.material.set_shader_parameter("fog_color", fog_col)
	if world.water_material != null:
		world.water_material.set_shader_parameter("fog_color", fog_col)

	# Update the WorldEnvironment background to match.
	var env_node: WorldEnvironment = get_node_or_null("WorldEnvironment")
	if env_node != null and env_node.environment != null:
		env_node.environment.background_color = sky

	# Push nearest block lights to shaders.
	_push_block_lights()


func _push_block_lights() -> void:
	if world == null or not is_instance_valid(player):
		return
	var cam_pos: Vector3 = player.global_position
	const MAX_LIGHTS: int = 64
	const MAX_DIST_SQ: float = 256.0  # 16² — don't bother with lights beyond 16 blocks
	# Collect nearby emitters sorted by distance.
	var nearby: Array = []  # [dist_sq, Vector3i, level]
	for pos: Vector3i in world.light_emitters:
		var wpos := Vector3(pos.x + 0.5, pos.y + 0.5, pos.z + 0.5)
		var d2: float = cam_pos.distance_squared_to(wpos)
		# Extend range check to the emitter's max radius (level blocks).
		var lvl: int = world.light_emitters[pos]
		var max_r: float = float(lvl) + 16.0  # player can be up to 16 blocks from visible surface
		if d2 > max_r * max_r:
			continue
		nearby.append([d2, pos, lvl])
	# Sort by distance (closest first) and take up to MAX_LIGHTS.
	nearby.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var count: int = mini(nearby.size(), MAX_LIGHTS)
	var light_data: Array = []
	for i: int in count:
		var pos: Vector3i = nearby[i][1]
		var lvl: int = nearby[i][2]
		light_data.append(Plane(float(pos.x) + 0.5, float(pos.y) + 0.5, float(pos.z) + 0.5, float(lvl)))
	# Pad remainder with zero-range lights so the shader loop is safe.
	while light_data.size() < MAX_LIGHTS:
		light_data.append(Plane(0, 0, 0, 0))
	# Push to both voxel and water shaders.
	for mat: ShaderMaterial in _get_all_shader_materials():
		mat.set_shader_parameter("block_light_count", count)
		mat.set_shader_parameter("block_lights", light_data)


func _get_all_shader_materials() -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = []
	if world != null and world.material != null:
		mats.append(world.material)
	if world != null and world.water_material != null:
		mats.append(world.water_material)
	var ps: ParticleSystem = get_node_or_null("ParticleSystem") as ParticleSystem
	if ps != null and ps._mesh_material != null:
		mats.append(ps._mesh_material)
	return mats


func _on_block_select_closed() -> void:
	if player != null:
		player._capture_cooldown = 0.25


func _setup_pixel_font() -> void:
	var font: Font = load("res://fonts/font.ttf")
	if font == null:
		push_warning("Failed to load res://fonts/font.ttf — open Godot editor to (re)import it")
		return

	# Configure for crisp pixel rendering
	if font is FontFile:
		var ff: FontFile = font
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.force_autohinter = false

	# 1. ThemeDB.fallback_font — used by direct draw_string() calls (hotbar, debug overlay)
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 10

	# 2. Root theme — cascades to all Control descendants (labels, buttons, line edits)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 10
	get_tree().root.theme = theme


func _wire_pause_menu() -> void:
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.quit_requested.connect(_quit_game)
	pause_menu.main_menu_requested.connect(_on_main_menu_requested)
	pause_menu.save_requested.connect(_on_save_requested)
	pause_menu.load_requested.connect(_on_load_requested)
	pause_menu.new_world_requested.connect(_on_new_world_requested)
	pause_menu.view_distance_changed.connect(_on_view_distance_changed)
	pause_menu.connected_textures_changed.connect(_on_connected_textures_changed)
	pause_menu.flying_enabled_changed.connect(_on_flying_enabled_changed)
	pause_menu.aspect_ratio_changed.connect(_on_aspect_ratio_changed)
	pause_menu.gui_scale_changed.connect(_on_gui_scale_changed)
	pause_menu.fullscreen_changed.connect(_on_fullscreen_changed)
	pause_menu.base_fov_changed.connect(_on_base_fov_changed)
	pause_menu.sprint_toggle_changed.connect(_on_sprint_toggle_changed)
	pause_menu.crouch_toggle_changed.connect(_on_crouch_toggle_changed)
	pause_menu.mipmaps_changed.connect(_on_mipmaps_changed)
	pause_menu.mouse_sensitivity_changed.connect(_on_mouse_sensitivity_changed)
	# Apply the pause menu's initial settings to the camera / shader / player / window.
	_on_view_distance_changed(pause_menu.view_distance)
	_on_connected_textures_changed(pause_menu.connected_textures)
	_on_flying_enabled_changed(pause_menu.flying_enabled)
	_on_aspect_ratio_changed(pause_menu.aspect_ratio)
	_on_gui_scale_changed(pause_menu.gui_scale)
	_on_fullscreen_changed(pause_menu.fullscreen)
	_on_base_fov_changed(pause_menu.base_fov)
	_on_sprint_toggle_changed(pause_menu.sprint_toggle)
	_on_crouch_toggle_changed(pause_menu.crouch_toggle)
	_on_mipmaps_changed(pause_menu.mipmaps)
	_on_mouse_sensitivity_changed(pause_menu.mouse_sensitivity)


func _on_view_distance_changed(distance: int) -> void:
	var dist_f: float = float(distance)
	# Camera.far must extend past both the fog fade-out AND the sky orbit
	# so the sun/moon aren't frustum-clipped.
	if player != null and player.camera != null:
		player.camera.far = maxf(dist_f + 16.0, SKY_ORBIT_RADIUS + 20.0)
	# Voxel + water shaders need to know the render distance so they can ease
	# fragments toward fog_color over the outer ~25% of the radius (matches
	# the shader's smoothstep band). Pass the nominal distance, not the
	# extended one.
	if world != null:
		if world.material != null:
			world.material.set_shader_parameter("view_distance", dist_f)
		if world.water_material != null:
			world.water_material.set_shader_parameter("view_distance", dist_f)


func _on_connected_textures_changed(enabled: bool) -> void:
	if world != null and world.material != null:
		world.material.set_shader_parameter("connected_textures", enabled)


func _on_flying_enabled_changed(enabled: bool) -> void:
	if player != null:
		player.flying_enabled = enabled
		# If flying gets disabled mid-flight, drop out of it so the player
		# doesn't get stuck hovering with no way to descend.
		if not enabled and player.is_flying:
			player.is_flying = false
			player.velocity.y = 0.0


# Aspect ratio reference sizes. Magnitude is picked so the window-fitting
# scale factor stays in a similar ballpark across ratios — this keeps the
# pixel density of the UI from swinging wildly when the user picks a
# different aspect.
const _ASPECT_SIZES: Dictionary = {
	"Auto":  Vector2i(1280, 720),
	"4:3":   Vector2i(1200, 900),
	"16:9":  Vector2i(1280, 720),
	"16:10": Vector2i(1280, 800),
	"21:9":  Vector2i(1400, 600),
	"1:1":   Vector2i(960, 960),
}


func _on_aspect_ratio_changed(ratio: String) -> void:
	var win: Window = get_tree().root
	var size: Vector2i = _ASPECT_SIZES.get(ratio, Vector2i(1280, 720))
	# CANVAS_ITEMS lets content_scale_factor drive GUI scale while still
	# respecting content_scale_aspect for letterbox/pillarbox.
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_size = size
	# "Auto" fills the whole window; named ratios letterbox to keep aspect.
	if ratio == "Auto":
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


## Minimum size (in unscaled UI coords) the menu panel needs to stay usable.
## Used to cap GUI scale so the menu always fits on-screen the way Minecraft
## auto-reduces scale on smaller windows.
const _MIN_UI_W: float = 480.0
const _MIN_UI_H: float = 500.0


func _on_gui_scale_changed(factor: float) -> void:
	_apply_gui_scale(factor)


## Apply `requested` GUI scale, capping it so the pause menu always fits in
## the current window. Mirrors Minecraft's behavior where a too-large scale
## setting silently falls back to the largest that still fits.
func _apply_gui_scale(requested: float) -> void:
	var win: Window = get_tree().root
	var win_size: Vector2i = DisplayServer.window_get_size()
	var max_x: float = float(win_size.x) / _MIN_UI_W
	var max_y: float = float(win_size.y) / _MIN_UI_H
	var max_scale: float = minf(max_x, max_y)
	# Floor of 0.5 matches our smallest dropdown option.
	var effective: float = clampf(requested, 0.5, maxf(0.5, max_scale))
	# CANVAS_ITEMS mode is required for content_scale_factor to take effect.
	if win.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_factor = effective


func _on_fullscreen_changed(mode: String) -> void:
	match mode:
		"Borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"Exclusive":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_base_fov_changed(fov: float) -> void:
	if player != null:
		player.set_base_fov(fov)


func _on_sprint_toggle_changed(is_toggle: bool) -> void:
	if player != null:
		player.sprint_toggle_mode = is_toggle
		# Switching modes should cancel any currently-latched sprint so the
		# player isn't stuck in an ambiguous state.
		player._sprint_latched = false


func _on_crouch_toggle_changed(is_toggle: bool) -> void:
	if player != null:
		player.crouch_toggle_mode = is_toggle
		player._crouch_latched = false


func _on_mouse_sensitivity_changed(value: int) -> void:
	if player != null:
		player.set_mouse_sensitivity(value)


func _on_mipmaps_changed(enabled: bool) -> void:
	# Tell BlockTextures the new preference, then rebuild everything that
	# holds the atlas. The world's chunks don't need re-meshing — only the
	# shader's sampler binding changes.
	BlockTextures.set_mipmaps(enabled)
	if world != null:
		world.refresh_atlas()
	var ps: ParticleSystem = get_node_or_null("ParticleSystem") as ParticleSystem
	if ps != null:
		ps.refresh_atlas()




## Auto-pause the game whenever the OS-level application focus leaves the
## window (alt-tab, switching spaces, minimize). NOTIFICATION_WM_WINDOW_FOCUS_OUT
## would fire for child/popup windows too — we want app-level only.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# If the game is already paused (menu open, loading, saving), don't
		# interfere — just let the existing state continue.
		if not get_tree().paused and not _saving:
			_pause_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Escape toggles pause menu (only when game isn't already paused — pause menu handles its own Escape)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not get_tree().paused:
			_pause_game()
			get_viewport().set_input_as_handled()

	# E opens the block inventory (only while game is active)
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if not get_tree().paused and hud != null:
			hud.open_block_select()
			get_viewport().set_input_as_handled()


func _pause_game() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu.show_menu()


func _resume_game() -> void:
	pause_menu.hide_menu()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _quit_game() -> void:
	_auto_save_state()
	get_tree().quit()


func _on_main_menu_requested() -> void:
	_auto_save_state()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")


## Quick-save game state (day_time, gamerules) to the current world's save
## file. Called automatically on quit and main-menu so the user never loses
## gamerule changes even without an explicit save. Only writes if a save
## for this world already exists (never creates a new save silently).
## Make sure the player isn't inside solid blocks or below the world. If
## the current position is invalid, teleport to the world spawn point.
func _ensure_valid_position() -> void:
	if player == null or world == null:
		return
	var pos: Vector3 = player.global_position
	var px: int = int(floor(pos.x))
	var py: int = int(floor(pos.y))
	var pz: int = int(floor(pos.z))
	var size: int = world.world_size_blocks
	# Out of bounds → respawn.
	if px < 0 or px >= size or pz < 0 or pz >= size or py < 1 or py >= size:
		player.global_position = world.find_spawn_position()
		return
	# Check if feet or head are inside a solid block.
	var feet: int = world.get_voxel(px, py, pz)
	var head: int = world.get_voxel(px, py + 1, pz)
	var solid_feet: bool = feet != Chunk.Block.AIR and feet != Chunk.Block.WATER \
		and feet != Chunk.Block.LAVA and feet != Chunk.Block.FIRE \
		and feet != Chunk.Block.NETHER_PORTAL and feet != Chunk.Block.POPPY \
		and feet != Chunk.Block.DANDELION and feet != Chunk.Block.TORCH
	var solid_head: bool = head != Chunk.Block.AIR and head != Chunk.Block.WATER \
		and head != Chunk.Block.LAVA and head != Chunk.Block.FIRE \
		and head != Chunk.Block.NETHER_PORTAL and head != Chunk.Block.POPPY \
		and head != Chunk.Block.DANDELION and head != Chunk.Block.TORCH
	if solid_feet or solid_head:
		# Try moving up to find air.
		for dy: int in range(1, 20):
			var check_y: int = py + dy
			if check_y + 1 >= size:
				break
			var f2: int = world.get_voxel(px, check_y, pz)
			var h2: int = world.get_voxel(px, check_y + 1, pz)
			if f2 == Chunk.Block.AIR and h2 == Chunk.Block.AIR:
				player.global_position = Vector3(pos.x, float(check_y), pos.z)
				return
		# Still stuck — use world spawn.
		player.global_position = world.find_spawn_position()
	# Check there's ground somewhere below (not falling into void).
	elif py > 0:
		var has_ground: bool = false
		for dy: int in range(py, -1, -1):
			var b: int = world.get_voxel(px, dy, pz)
			if b != Chunk.Block.AIR and b != Chunk.Block.WATER:
				has_ground = true
				break
		if not has_ground:
			player.global_position = world.find_spawn_position()


## Build the complete game state dictionary for saving. Used by explicit
## save, auto-save, and portal-transition save to stay consistent.
func _build_game_state_dict() -> Dictionary:
	return {
		"day_time": _day_time,
		"do_daylight_cycle": do_daylight_cycle,
		"tick_rate": tick_rate,
		"noclip": noclip,
		"current_dimension": _current_dimension,
		"nether_generated": _nether_generated,
		"overworld_portal_x": _overworld_portal_pos.x,
		"overworld_portal_y": _overworld_portal_pos.y,
		"overworld_portal_z": _overworld_portal_pos.z,
		"overworld_player_x": _overworld_player_pos.x,
		"overworld_player_y": _overworld_player_pos.y,
		"overworld_player_z": _overworld_player_pos.z,
		"nether_player_x": _nether_player_pos.x,
		"nether_player_y": _nether_player_pos.y,
		"nether_player_z": _nether_player_pos.z,
	}


func _save_dimension_cache(save_name: String) -> void:
	# Save the inactive dimension's voxels so both dimensions persist.
	var nether_path: String = "user://saves/" + save_name + ".nether"
	if _current_dimension == 0 and _nether_voxels.size() > 0:
		var f: FileAccess = FileAccess.open(nether_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_nether_voxels)
			f.close()
	elif _current_dimension == 1 and _overworld_voxels.size() > 0:
		# The main .save file has the nether (active); cache overworld.
		var ow_path: String = "user://saves/" + save_name + ".overworld"
		var f: FileAccess = FileAccess.open(ow_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_overworld_voxels)
			f.close()


func _load_dimension_cache(save_name: String) -> void:
	var nether_path: String = "user://saves/" + save_name + ".nether"
	if FileAccess.file_exists(nether_path):
		var f: FileAccess = FileAccess.open(nether_path, FileAccess.READ)
		if f != null:
			_nether_voxels = f.get_buffer(f.get_length())
			f.close()
			_nether_generated = true


func _auto_save_state() -> void:
	var save_name: String = _current_world_name
	if save_name.is_empty():
		return
	# Check the save file exists — don't create a new one silently.
	var path: String = "user://saves/" + save_name + ".save"
	if not FileAccess.file_exists(path):
		return
	# Re-save the full world with current game state. This reuses the
	# existing save flow (which collects voxels + writes everything).
	# Since we're about to leave the scene, run it synchronously.
	var gs: Dictionary = _build_game_state_dict()
	# Write just the game state as a sidecar JSON file.
	var state_path: String = "user://saves/" + save_name + ".state"
	var f: FileAccess = FileAccess.open(state_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(gs))
		f.close()


func _on_save_requested(save_name: String) -> void:
	if _saving:
		return  # already saving — ignore double-click / re-entry
	_saving = true
	pause_menu.show_loading("Saving World")
	# Let the LOADING screen paint before the save starts. Without this yield,
	# small worlds finish saving before the progress bar ever draws.
	await get_tree().process_frame
	await get_tree().process_frame
	world.generation_progress.connect(_on_generation_progress)
	var t_start: int = Time.get_ticks_msec()
	var gs: Dictionary = _build_game_state_dict()
	var ok: bool = await world.save_to_file(save_name, player.global_position, gs)
	# Also save the inactive dimension's cached voxels as a sidecar file.
	if ok:
		_save_dimension_cache(save_name)
	world.generation_progress.disconnect(_on_generation_progress)
	if ok:
		print("Saved: ", save_name)
	# Ensure the "Saved!" state stays visible long enough to read, even on
	# tiny worlds that save in milliseconds. Caps at 600 ms total.
	const MIN_VISIBLE_MS: int = 600
	var elapsed: int = Time.get_ticks_msec() - t_start
	if elapsed < MIN_VISIBLE_MS:
		await get_tree().create_timer(float(MIN_VISIBLE_MS - elapsed) / 1000.0).timeout
	# Return to the pause menu's main screen — user was here before saving.
	pause_menu.show_menu()
	_saving = false


func _on_load_requested(save_name: String) -> void:
	if _saving:
		return
	_saving = true
	_current_world_name = save_name
	pause_menu.default_save_name = save_name
	var data: Dictionary = SaveSystem.load_world(save_name)
	if data.is_empty():
		_saving = false
		return
	pause_menu.show_loading("Loading World")
	await get_tree().process_frame
	world.generation_progress.connect(_on_generation_progress)
	await world.load_from_save(int(data["size"]), data["voxels"], int(data.get("seed", 0)), int(data.get("terrain_type", 1)))
	world.generation_progress.disconnect(_on_generation_progress)
	var pp: Vector3 = data["player_pos"]
	player.global_position = pp
	player.velocity = Vector3.ZERO
	# Restore game state — prefer the .state sidecar (written on every quit)
	# over the in-save blob (only written on explicit save). This ensures
	# gamerule changes that weren't explicitly saved still persist.
	var gs: Dictionary = {}
	var state_path: String = "user://saves/" + save_name + ".state"
	if FileAccess.file_exists(state_path):
		var sf: FileAccess = FileAccess.open(state_path, FileAccess.READ)
		if sf != null:
			var parsed: Variant = JSON.parse_string(sf.get_as_text())
			sf.close()
			if parsed is Dictionary:
				gs = parsed
	if gs.is_empty():
		gs = data.get("game_state", {})
	if gs.has("day_time"):
		_day_time = float(gs["day_time"])
	if gs.has("do_daylight_cycle"):
		do_daylight_cycle = bool(gs["do_daylight_cycle"])
	if gs.has("tick_rate"):
		tick_rate = float(gs["tick_rate"])
	if gs.has("noclip"):
		noclip = bool(gs["noclip"])
	if gs.has("current_dimension"):
		_current_dimension = int(gs["current_dimension"])
		world.dimension = _current_dimension
	if gs.has("nether_generated"):
		_nether_generated = bool(gs["nether_generated"])
	if gs.has("overworld_portal_x"):
		_overworld_portal_pos = Vector3(
			float(gs["overworld_portal_x"]),
			float(gs["overworld_portal_y"]),
			float(gs["overworld_portal_z"]),
		)
	if gs.has("overworld_player_x"):
		_overworld_player_pos = Vector3(
			float(gs["overworld_player_x"]),
			float(gs["overworld_player_y"]),
			float(gs["overworld_player_z"]),
		)
	if gs.has("nether_player_x"):
		_nether_player_pos = Vector3(
			float(gs["nether_player_x"]),
			float(gs["nether_player_y"]),
			float(gs["nether_player_z"]),
		)
	_load_dimension_cache(save_name)
	_saving = false
	_resume_game()


func _on_new_world_requested(size: int, terrain_type: int, seed: int = 0, world_name: String = "My World") -> void:
	if _saving:
		return
	_saving = true
	_current_world_name = world_name
	pause_menu.default_save_name = world_name
	pause_menu.show_loading("Generating World")
	await get_tree().process_frame
	world.generation_progress.connect(_on_generation_progress)
	await world.regenerate(size, terrain_type, seed)
	world.generation_progress.disconnect(_on_generation_progress)
	player.global_position = world.find_spawn_position()
	player.velocity = Vector3.ZERO
	_saving = false
	_resume_game()


func _on_generation_progress(progress: float, status: String) -> void:
	pause_menu.update_progress(progress, status)
