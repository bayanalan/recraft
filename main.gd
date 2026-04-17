extends Node3D

@onready var player: Player = $Player
@onready var world: World = $World
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var hud: Node = $HUD

# True while a save (or load) is in progress. Blocks re-entrant save requests
# and prevents the pause menu from being dismissed mid-operation.
var _saving: bool = false
# The user-chosen name for this world, used as the default save name.
var _current_world_name: String = "My World"
# Cached barrier-visibility state so we don't push a shader parameter every
# frame when the value hasn't changed.
var _last_show_barriers: bool = false


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
	# GameConfig tells us whether the main menu asked for a new world or a
	# loaded save. If we arrived here without going through the main menu
	# (e.g. F5 in the editor), fall back to a default 256 world.
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


func _process(_delta: float) -> void:
	# Toggle barrier visibility based on what the player is holding.
	if hud == null or world == null or world.material == null:
		return
	var holding: bool = hud.get_selected_block() == Chunk.Block.BARRIER
	if holding != _last_show_barriers:
		_last_show_barriers = holding
		world.material.set_shader_parameter("show_barriers", holding)


func _on_block_select_closed() -> void:
	# Swallow whatever LMB/RMB state is held at the moment the inventory
	# closes — otherwise the very click that picked a block will also count
	# as a break/place in the first gameplay frame.
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
	# Camera.far is extended slightly past the nominal view distance so the
	# shader's distance fog can reach full opacity (sky-color) BEFORE a face
	# gets frustum-clipped. Otherwise the user sees a sharp clip edge even
	# though the fog would have covered it a few meters further out.
	if player != null and player.camera != null:
		player.camera.far = dist_f + 16.0
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
	get_tree().quit()


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
	var ok: bool = await world.save_to_file(save_name, player.global_position)
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
