extends Control

## Main menu — shown on launch before any world loads. Provides New World,
## Load World, Settings, and Quit. Styled to match the pause menu's pixel
## aesthetic. When the player picks a world, we set GameConfig statics and
## switch to the game scene.

enum Screen { MAIN, NEW_WORLD, LOAD, SETTINGS, VIDEO, CONTROLS }

const DEFAULT_VIEW_DISTANCE: int = 256
const DEFAULT_BASE_FOV: int = 70
const DEFAULT_MOUSE_SENSITIVITY: int = 100
const VIEW_DISTANCE_MIN: int = 64
const VIEW_DISTANCE_MAX: int = 4096
const VIEW_DISTANCE_STEP: int = 64
const ASPECT_RATIOS: Array[String] = ["Auto", "4:3", "16:9", "16:10", "21:9", "1:1"]
const GUI_SCALES: Array[float] = [0.5, 0.75, 1.0, 2.0, 3.0, 4.0]

# Background shader: zoomed in ~1.5×, barrel distortion for a subtle fish-eye
# curvature, and a slow sine-wave horizontal pan so the panorama drifts.
const _BG_SHADER_CODE: String = "shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	// Slow side-to-side pan (full cycle ~20s).
	uv.x += sin(TIME * 0.3) * 0.06;
	// Zoom toward center (~1.5x).
	uv = vec2(0.5) + (uv - vec2(0.5)) * 0.65;
	// Barrel distortion (fish-eye). Strength 0.35 gives a gentle curve
	// without warping edges into mush.
	vec2 c = uv - vec2(0.5);
	float r2 = dot(c, c);
	uv = c * (1.0 + 0.35 * r2) + vec2(0.5);
	uv = clamp(uv, vec2(0.0), vec2(1.0));
	COLOR = texture(TEXTURE, uv);
}
"

var _font: Font = null
# Logo reference for the idle bob animation (only set on MAIN screen).
var _logo_node: TextureRect = null
var _intro_time: float = 0.0
var _content: VBoxContainer = null
var _current_screen: int = Screen.MAIN

# New-world picker state
var _nw_size: int = 64
var _nw_terrain: int = 1
var _nw_seed: int = 0

# --- Settings state (mirrors pause_menu — same config file) ---
var view_distance: int = DEFAULT_VIEW_DISTANCE
var base_fov: float = float(DEFAULT_BASE_FOV)
var mouse_sensitivity: int = DEFAULT_MOUSE_SENSITIVITY
var connected_textures: bool = true
var flying_enabled: bool = true
var mipmaps: bool = false
var sprint_toggle: bool = false
var crouch_toggle: bool = false
var aspect_ratio: String = "Auto"
var gui_scale: float = 1.0
var fullscreen: String = "None"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_font()
	_load_settings()
	# Load saved key bindings so the Controls screen reflects what the
	# player actually rebound last session — otherwise the first main-menu
	# visit after a rebind would still show the default (W/A/S/D/etc) keys.
	ControlsConfig.load_into_inputmap()
	_apply_fullscreen()
	_apply_gui_scale()
	_build_screen()


func _setup_font() -> void:
	_font = load("res://fonts/font.ttf")
	if _font == null:
		return
	if _font is FontFile:
		var ff: FontFile = _font
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.force_autohinter = false
	ThemeDB.fallback_font = _font
	ThemeDB.fallback_font_size = 10
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 10
	get_tree().root.theme = theme


func _load_settings() -> void:
	var data: Dictionary = SettingsConfig.load_all()
	if data.has("view_distance"): view_distance = int(data["view_distance"])
	if data.has("base_fov"): base_fov = float(data["base_fov"])
	if data.has("mouse_sensitivity"): mouse_sensitivity = clampi(int(data["mouse_sensitivity"]), 1, 200)
	if data.has("connected_textures"): connected_textures = bool(data["connected_textures"])
	if data.has("flying_enabled"): flying_enabled = bool(data["flying_enabled"])
	if data.has("mipmaps"): mipmaps = bool(data["mipmaps"])
	if data.has("sprint_toggle"): sprint_toggle = bool(data["sprint_toggle"])
	if data.has("crouch_toggle"): crouch_toggle = bool(data["crouch_toggle"])
	if data.has("aspect_ratio"): aspect_ratio = str(data["aspect_ratio"])
	if data.has("gui_scale"): gui_scale = float(data["gui_scale"])
	if data.has("fullscreen"):
		var fs_val = data["fullscreen"]
		if fs_val is bool:
			fullscreen = "Borderless" if bool(fs_val) else "None"
		else:
			fullscreen = str(fs_val) if str(fs_val) in PauseMenu.FULLSCREEN_MODES else "None"


func _process(delta: float) -> void:
	_intro_time += delta
	# Subtle idle brightness pulse — a gentle glow that keeps the logo
	# feeling alive without any scale/position changes that cause pixel
	# jitter on small pixel-art images.
	if _logo_node != null and is_instance_valid(_logo_node) and _intro_time > 0.8:
		var t: float = _intro_time - 0.8
		var brightness: float = 1.0 + sin(t * 1.2) * 0.08
		_logo_node.modulate = Color(brightness, brightness, brightness, 1.0)


func _apply_fullscreen() -> void:
	match fullscreen:
		"Borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"Exclusive":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_gui_scale() -> void:
	var win: Window = get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var win_size: Vector2i = DisplayServer.window_get_size()
	var max_scale: float = minf(float(win_size.x) / 480.0, float(win_size.y) / 500.0)
	win.content_scale_factor = clampf(gui_scale, 0.5, maxf(0.5, max_scale))


# ======================================================================
#  Screen management
# ======================================================================

func _build_screen() -> void:
	if _content != null:
		_content.queue_free()
		_content = null
	# Background image — cover the full viewport with no pillarboxing.
	# ExpandMode IGNORE_SIZE + StretchMode COVER guarantees all four edges
	# of the image touch or exceed the display, cropping the shorter axis.
	var bg_tex := TextureRect.new()
	var img := load("res://menu.png") as Texture2D
	if img != null:
		bg_tex.texture = img
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Zoomed-in fish-eye with a slow horizontal pan.
	var bg_shader := Shader.new()
	bg_shader.code = _BG_SHADER_CODE
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = bg_shader
	bg_tex.material = bg_mat
	add_child(bg_tex)
	# Semi-transparent dark tint over the image so UI text is readable.
	var tint := ColorRect.new()
	tint.color = Color(0.0, 0.0, 0.0, 0.55)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 4)
	center.add_child(_content)

	match _current_screen:
		Screen.MAIN: _build_main()
		Screen.NEW_WORLD: _build_new_world()
		Screen.LOAD: _build_load()
		Screen.SETTINGS: _build_settings()
		Screen.VIDEO: _build_video_settings()
		Screen.CONTROLS: _build_controls()

	# Version label — bottom-left corner, visible on every screen.
	var ver := Label.new()
	ver.text = "Recraft vA1.0.0"
	if _font != null:
		ver.add_theme_font_override("font", _font)
	ver.add_theme_font_size_override("font_size", PauseMenu._fs(20))
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	ver.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	ver.add_theme_constant_override("shadow_offset_x", 1)
	ver.add_theme_constant_override("shadow_offset_y", 1)
	ver.anchor_left = 0.0
	ver.anchor_top = 1.0
	ver.anchor_right = 0.5
	ver.anchor_bottom = 1.0
	ver.offset_left = 4
	ver.offset_top = -20
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)


func _show_screen(screen: int) -> void:
	_current_screen = screen
	_logo_node = null
	# Remove everything and rebuild — same approach as pause_menu.
	for child in get_children():
		child.queue_free()
	_content = null
	# Defer so queue_free completes before rebuild.
	call_deferred("_build_screen")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _current_screen != Screen.MAIN:
			if _current_screen == Screen.CONTROLS or _current_screen == Screen.VIDEO:
				_show_screen(Screen.SETTINGS)
			else:
				_show_screen(Screen.MAIN)
			get_viewport().set_input_as_handled()


# ======================================================================
#  MAIN screen
# ======================================================================

func _build_main() -> void:
	# Logo image — auto-cropped to remove transparent border pixels so it
	# sits tight at the top of the menu at its natural pixel size.
	var logo_tex: Texture2D = null
	var raw := load("res://logo.png") as Texture2D
	if raw != null:
		var img: Image = raw.get_image()
		if img != null:
			# Crop to the bounding box of non-transparent pixels.
			var used: Rect2i = img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				var cropped := img.get_region(used)
				logo_tex = ImageTexture.create_from_image(cropped)
	# Logo sits outside the VBox layout (added to the root, not _content)
	# so scale animation works freely without the container fighting it.
	if logo_tex != null:
		_logo_node = TextureRect.new()
		_logo_node.texture = logo_tex
		_logo_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo_node.size = Vector2(460, 100)
		_logo_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_logo_node.pivot_offset = Vector2(230, 50)
		# Center horizontally, sit above the button area.
		_logo_node.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_logo_node.anchor_top = 0.22
		_logo_node.anchor_bottom = 0.22
		_logo_node.offset_left = -230
		_logo_node.offset_right = 230
		_logo_node.offset_top = -50
		_logo_node.offset_bottom = 50
		add_child(_logo_node)
	else:
		var title := _make_title("Recraft")
		title.add_theme_font_size_override("font_size", PauseMenu._fs(52))
		_content.add_child(title)
	_content.add_child(_make_separator(124))  # space where the logo sits

	# Buttons in their own VBox so SIZE_EXPAND_FILL stretches them all to
	# the width of the widest label ("Load World"). No fixed min_width.
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 6)
	btn_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(btn_box)

	var btn_nodes: Array[Button] = []
	for entry: Array in [
		["New World", func(): _show_screen(Screen.NEW_WORLD)],
		["Load World", func(): _show_screen(Screen.LOAD)],
		["Settings", func(): _show_screen(Screen.SETTINGS)],
		["Quit", func(): get_tree().quit()],
	]:
		var btn := _make_button(entry[0])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(entry[1])
		btn_box.add_child(btn)
		btn_nodes.append(btn)

	# --- Intro animation: logo drops in from above + scales up, buttons
	# --- fade in one by one with a slight stagger. All via tweens.
	_intro_time = 0.0
	if _logo_node != null:
		_logo_node.modulate.a = 0.0
		_logo_node.scale = Vector2(0.3, 0.3)
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_logo_node, "modulate:a", 1.0, 0.15)
		tw.parallel().tween_property(_logo_node, "scale", Vector2(1.0, 1.0), 0.25)
	for i: int in btn_nodes.size():
		var btn: Button = btn_nodes[i]
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.9, 0.9)
		btn.pivot_offset = btn.size * 0.5
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_interval(0.3 + i * 0.08)
		tw.tween_property(btn, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.25)


# ======================================================================
#  NEW WORLD screen
# ======================================================================

func _build_new_world() -> void:
	_content.add_child(_make_title("New World"))
	_content.add_child(_make_separator(8))

	_content.add_child(_make_label("World Name:", 26))
	var name_edit := _make_line_edit("My World")
	_content.add_child(name_edit)

	_content.add_child(_make_separator(10))
	_content.add_child(_make_label("World Size:", 26))
	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_row.add_theme_constant_override("separation", 6)
	_content.add_child(size_row)

	var sizes: Array[int] = [32, 64, 128, 256, 512]
	var size_btns: Array[Button] = []
	for s: int in sizes:
		var b := _make_button("%d" % s, 66)
		b.pressed.connect(func():
			_nw_size = s
			_highlight_group(size_btns, sizes.find(s))
		)
		size_row.add_child(b)
		size_btns.append(b)
	_highlight_group(size_btns, sizes.find(_nw_size))

	_content.add_child(_make_separator(10))
	_content.add_child(_make_label("Terrain Type:", 26))

	var type_row := HBoxContainer.new()
	type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	type_row.add_theme_constant_override("separation", 6)
	_content.add_child(type_row)

	var type_names: Array[String] = ["Flatgrass", "Default", "Hilly"]
	var type_values: Array[int] = [0, 1, 2]
	var type_btns: Array[Button] = []
	for i: int in type_names.size():
		var b := _make_button(type_names[i], 110)
		var val: int = type_values[i]
		b.pressed.connect(func():
			_nw_terrain = val
			_highlight_group(type_btns, type_values.find(val))
		)
		type_row.add_child(b)
		type_btns.append(b)
	_highlight_group(type_btns, type_values.find(_nw_terrain))

	_content.add_child(_make_separator(10))
	_content.add_child(_make_label("Seed (optional):", 26))
	var seed_edit := _make_line_edit("blank = random")
	if _nw_seed != 0:
		seed_edit.text = str(_nw_seed)
	_content.add_child(seed_edit)

	_content.add_child(_make_separator(14))

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	_content.add_child(action_row)

	var gen_btn := _make_button("Generate", 140)
	gen_btn.pressed.connect(func():
		_nw_seed = _parse_seed(seed_edit.text)
		var wn: String = name_edit.text.strip_edges()
		if wn.is_empty():
			wn = "My World"
		GameConfig.start_mode = GameConfig.StartMode.NEW_WORLD
		GameConfig.world_size = _nw_size
		GameConfig.terrain_type = _nw_terrain
		GameConfig.world_seed = _nw_seed
		GameConfig.world_name = wn
		get_tree().change_scene_to_file("res://main.tscn")
	)
	action_row.add_child(gen_btn)

	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.MAIN))
	action_row.add_child(back)


# ======================================================================
#  LOAD screen
# ======================================================================

func _build_load() -> void:
	_content.add_child(_make_title("Load World"))
	_content.add_child(_make_separator(6))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var saves: Array = SaveSystem.list_saves()
	if saves.is_empty():
		list.add_child(_make_label("  (no saves yet)", 22, Color(0.55, 0.55, 0.55)))
	else:
		for info: Dictionary in saves:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var label_text: String = "%s  (%d)  %s" % [info.name, info.size, SaveSystem.format_timestamp(info.timestamp)]
			var lbl := _make_label(label_text, 22, Color(0.9, 0.9, 0.9))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)

			var btn_load := _make_button("Load")
			_apply_font(btn_load, 22)
			btn_load.pressed.connect(func():
				GameConfig.start_mode = GameConfig.StartMode.LOAD_WORLD
				GameConfig.save_name = info.name
				get_tree().change_scene_to_file("res://main.tscn")
			)
			row.add_child(btn_load)

			var btn_delete := _make_button("Delete")
			_apply_font(btn_delete, 22)
			btn_delete.pressed.connect(func():
				SaveSystem.delete_save(info.name)
				_show_screen(Screen.LOAD)
			)
			row.add_child(btn_delete)

			list.add_child(row)

	_content.add_child(_make_separator(8))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(back_row)
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.MAIN))
	back_row.add_child(back)


# ======================================================================
#  SETTINGS screen (simplified — only fullscreen + GUI scale at menu level)
# ======================================================================

func _save_all_settings() -> void:
	SettingsConfig.save_all({
		"view_distance": view_distance,
		"connected_textures": connected_textures,
		"flying_enabled": flying_enabled,
		"aspect_ratio": aspect_ratio,
		"gui_scale": gui_scale,
		"fullscreen": fullscreen,
		"base_fov": base_fov,
		"sprint_toggle": sprint_toggle,
		"crouch_toggle": crouch_toggle,
		"mipmaps": mipmaps,
		"mouse_sensitivity": mouse_sensitivity,
	})


func _reset_all_settings() -> void:
	view_distance = DEFAULT_VIEW_DISTANCE
	connected_textures = true
	flying_enabled = true
	aspect_ratio = "Auto"
	gui_scale = 1.0
	fullscreen = "None"
	base_fov = float(DEFAULT_BASE_FOV)
	sprint_toggle = false
	crouch_toggle = false
	mipmaps = false
	mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
	_save_all_settings()
	_apply_fullscreen()
	_apply_gui_scale()
	_show_screen(Screen.SETTINGS)


## Settings hub — FOV + GUI Scale at top, buttons to Video and Controls.
func _build_settings() -> void:
	const RESET_W: int = 78
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 0)
	_content.add_child(top_row)
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(RESET_W, 0)
	_apply_font(reset_btn, 18)
	_style_button(reset_btn)
	reset_btn.pressed.connect(_reset_all_settings)
	top_row.add_child(reset_btn)
	var title := _make_title("Settings")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)
	var right_spacer := Control.new()
	right_spacer.custom_minimum_size = Vector2(RESET_W, 0)
	top_row.add_child(right_spacer)

	_content.add_child(_make_separator(16))

	_content.add_child(_make_label("Field of View:", 26))
	var fov_label := _make_label(_format_fov(int(round(base_fov))), 24, Color(0.85, 0.85, 0.85))
	fov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fov_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(fov_label)
	var fov_slider := HSlider.new()
	fov_slider.min_value = 50.0
	fov_slider.max_value = 120.0
	fov_slider.step = 1.0
	fov_slider.value = base_fov
	fov_slider.custom_minimum_size = Vector2(380, 28)
	_style_slider(fov_slider)
	fov_slider.value_changed.connect(func(v: float):
		base_fov = v
		fov_label.text = _format_fov(int(round(base_fov)))
		_save_all_settings()
	)
	_content.add_child(fov_slider)
	_content.add_child(_make_separator(16))

	_content.add_child(_make_label("GUI Scale:", 26))
	var gs_opt := OptionButton.new()
	_apply_font(gs_opt, 29)
	gs_opt.custom_minimum_size = Vector2(380, 44)
	for factor: float in GUI_SCALES:
		var lbl: String
		if factor == float(int(factor)):
			lbl = "%dx" % int(factor)
		else:
			lbl = "%.1fx" % factor
		gs_opt.add_item(lbl)
	gs_opt.selected = maxi(0, GUI_SCALES.find(gui_scale))
	_style_button(gs_opt)
	gs_opt.item_selected.connect(func(idx: int):
		gui_scale = GUI_SCALES[idx]
		_apply_gui_scale()
		_save_all_settings()
	)
	_content.add_child(gs_opt)

	_content.add_child(_make_separator(24))

	var btn_video := _make_button("Video Settings", 280)
	btn_video.pressed.connect(func(): _show_screen(Screen.VIDEO))
	_content.add_child(btn_video)
	_content.add_child(_make_separator(6))

	var btn_ctrl := _make_button("Controls", 280)
	btn_ctrl.pressed.connect(func(): _show_screen(Screen.CONTROLS))
	_content.add_child(btn_ctrl)

	_content.add_child(_make_separator(20))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(back_row)
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.MAIN))
	back_row.add_child(back)


## Video sub-screen.
func _build_video_settings() -> void:
	_content.add_child(_make_title("Video Settings"))
	_content.add_child(_make_separator(8))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_scroll_container(scroll)
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_make_label("View Distance:", 26))
	var vd_label := _make_label(_format_view_distance(view_distance), 24, Color(0.85, 0.85, 0.85))
	vd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vd_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(vd_label)
	var vd_slider := HSlider.new()
	vd_slider.min_value = VIEW_DISTANCE_MIN
	vd_slider.max_value = VIEW_DISTANCE_MAX
	vd_slider.step = VIEW_DISTANCE_STEP
	vd_slider.value = view_distance
	vd_slider.custom_minimum_size = Vector2(380, 28)
	_style_slider(vd_slider)
	vd_slider.value_changed.connect(func(v: float):
		view_distance = int(v)
		vd_label.text = _format_view_distance(view_distance)
		_save_all_settings()
	)
	list.add_child(vd_slider)
	list.add_child(_make_separator(16))

	_add_checkbox(list, "Connected Textures", connected_textures, func(v: bool):
		connected_textures = v; _save_all_settings())
	_add_checkbox(list, "Mipmaps", mipmaps, func(v: bool):
		mipmaps = v; _save_all_settings())

	list.add_child(_make_separator(16))

	list.add_child(_make_label("Aspect Ratio:", 26))
	var ar_opt := OptionButton.new()
	_apply_font(ar_opt, 29)
	ar_opt.custom_minimum_size = Vector2(380, 44)
	for n: String in ASPECT_RATIOS:
		ar_opt.add_item(n)
	ar_opt.selected = maxi(0, ASPECT_RATIOS.find(aspect_ratio))
	_style_button(ar_opt)
	ar_opt.item_selected.connect(func(idx: int):
		aspect_ratio = ASPECT_RATIOS[idx]; _save_all_settings())
	list.add_child(ar_opt)
	list.add_child(_make_separator(16))

	list.add_child(_make_label("Fullscreen:", 26))
	var fs_opt := OptionButton.new()
	_apply_font(fs_opt, 29)
	fs_opt.custom_minimum_size = Vector2(380, 44)
	for mode_name: String in PauseMenu.FULLSCREEN_MODES:
		fs_opt.add_item(mode_name)
	fs_opt.selected = maxi(0, PauseMenu.FULLSCREEN_MODES.find(fullscreen))
	_style_button(fs_opt)
	fs_opt.item_selected.connect(func(idx: int):
		fullscreen = PauseMenu.FULLSCREEN_MODES[idx]
		_apply_fullscreen()
		_save_all_settings()
	)
	list.add_child(fs_opt)

	_content.add_child(_make_separator(20))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(back_row)
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	back_row.add_child(back)


# ======================================================================
#  CONTROLS screen
# ======================================================================

var _rebinding_action: StringName = &""
var _rebinding_button: Button = null

func _build_controls() -> void:
	_content.add_child(_make_title("Controls"))
	_content.add_child(_make_separator(8))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_scroll_container(scroll)
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_make_label("Mouse Sensitivity:", 26))
	var ms_label := _make_label(_format_sensitivity(mouse_sensitivity), 24, Color(0.85, 0.85, 0.85))
	ms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ms_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(ms_label)
	var ms_slider := HSlider.new()
	ms_slider.min_value = 1
	ms_slider.max_value = 200
	ms_slider.step = 1
	ms_slider.value = mouse_sensitivity
	ms_slider.custom_minimum_size = Vector2(380, 28)
	_style_slider(ms_slider)
	ms_slider.value_changed.connect(func(v: float):
		mouse_sensitivity = int(v)
		ms_label.text = _format_sensitivity(mouse_sensitivity)
		_save_all_settings()
	)
	list.add_child(ms_slider)
	list.add_child(_make_separator(16))

	list.add_child(_make_label("Sprint Mode:", 26))
	var sprint_opt := OptionButton.new()
	_apply_font(sprint_opt, 29)
	sprint_opt.custom_minimum_size = Vector2(380, 44)
	sprint_opt.add_item("Hold")
	sprint_opt.add_item("Toggle")
	sprint_opt.selected = 1 if sprint_toggle else 0
	_style_button(sprint_opt)
	sprint_opt.item_selected.connect(func(idx: int):
		sprint_toggle = idx == 1; _save_all_settings())
	list.add_child(sprint_opt)
	list.add_child(_make_separator(16))

	list.add_child(_make_label("Crouch Mode:", 26))
	var crouch_opt := OptionButton.new()
	_apply_font(crouch_opt, 29)
	crouch_opt.custom_minimum_size = Vector2(380, 44)
	crouch_opt.add_item("Hold")
	crouch_opt.add_item("Toggle")
	crouch_opt.selected = 1 if crouch_toggle else 0
	_style_button(crouch_opt)
	crouch_opt.item_selected.connect(func(idx: int):
		crouch_toggle = idx == 1; _save_all_settings())
	list.add_child(crouch_opt)
	list.add_child(_make_separator(16))

	_add_checkbox(list, "Enable Flying", flying_enabled, func(v: bool):
		flying_enabled = v; _save_all_settings())

	list.add_child(_make_separator(20))
	list.add_child(_make_label("Key Bindings (click to rebind, Esc cancels):", 22, Color(0.7, 0.7, 0.7)))
	list.add_child(_make_separator(4))

	for entry: Array in ControlsConfig.ACTIONS:
		var action: StringName = entry[0]
		var label_text: String = entry[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_lbl := _make_label(label_text, 26, Color(0.9, 0.9, 0.9))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var code: int = ControlsConfig.get_action_physical_keycode(action)
		var btn := _make_button(ControlsConfig.keycode_to_string(code), 180)
		btn.pressed.connect(_start_rebind.bind(action, btn))
		row.add_child(btn)
		list.add_child(row)

	_content.add_child(_make_separator(16))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(back_row)
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	back_row.add_child(back)


func _start_rebind(action: StringName, btn: Button) -> void:
	if _rebinding_button != null and _rebinding_button != btn:
		var prev_code: int = ControlsConfig.get_action_physical_keycode(_rebinding_action)
		_rebinding_button.text = ControlsConfig.keycode_to_string(prev_code)
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "Press any key..."


func _input(event: InputEvent) -> void:
	if _rebinding_action == &"":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var ek: InputEventKey = event
	if ek.keycode == KEY_ESCAPE:
		var prev: int = ControlsConfig.get_action_physical_keycode(_rebinding_action)
		_rebinding_button.text = ControlsConfig.keycode_to_string(prev)
	else:
		var code: int = ek.physical_keycode
		if code == 0:
			code = ek.keycode
		ControlsConfig.set_action_key(_rebinding_action, code)
		# Persist immediately so the rebind survives quitting the main menu,
		# restarting the game, or picking a different world. Mirrors
		# pause_menu.gd's rebind handler — previously missing here, which
		# meant menu-side rebinds lived only in the in-memory InputMap.
		ControlsConfig.save()
		_rebinding_button.text = ControlsConfig.keycode_to_string(code)
	_rebinding_action = &""
	_rebinding_button = null
	get_viewport().set_input_as_handled()


# ======================================================================
#  Helpers
# ======================================================================

static func _parse_seed(text: String) -> int:
	var t := text.strip_edges()
	if t.is_empty():
		return 0
	if t.is_valid_int():
		var n := int(t)
		return n if n != 0 else 1
	return hash(t)


func _apply_font(ctrl: Control, size: int) -> void:
	if _font != null:
		ctrl.add_theme_font_override("font", _font)
	ctrl.add_theme_font_size_override("font_size", PauseMenu._fs(size))


func _make_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(lbl, 38)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	return lbl


func _make_label(text: String, size: int = 26, color: Color = Color(0.85, 0.85, 0.85)) -> Label:
	var lbl := Label.new()
	lbl.text = text
	_apply_font(lbl, size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_button(text: String, min_width: int = 0) -> Button:
	var btn := Button.new()
	btn.text = text
	_apply_font(btn, 22)
	if min_width > 0:
		btn.custom_minimum_size.x = min_width
	_style_button(btn)
	return btn


# Reuse the same stone-textured StyleBox generation as PauseMenu.
static var _btn_normal_style: StyleBoxTexture = PauseMenu._make_stone_style(0.42, false)
static var _btn_hover_style: StyleBoxTexture = PauseMenu._make_stone_style(0.52, false)
static var _btn_pressed_style: StyleBoxTexture = PauseMenu._make_stone_style(0.30, true)


func _style_button(btn: Button) -> void:
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.add_theme_stylebox_override("normal", _btn_normal_style)
	btn.add_theme_stylebox_override("hover", _btn_hover_style)
	btn.add_theme_stylebox_override("pressed", _btn_pressed_style)
	btn.add_theme_stylebox_override("focus", _btn_hover_style)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))
	if btn is OptionButton:
		var popup: PopupMenu = (btn as OptionButton).get_popup()
		if popup != null:
			popup.add_theme_stylebox_override("panel", PauseMenu._make_stone_style(0.32, false))
			popup.add_theme_stylebox_override("hover", PauseMenu._make_stone_style(0.50, false))
			if _font != null:
				popup.add_theme_font_override("font", _font)
			popup.add_theme_font_size_override("font_size", PauseMenu._fs(26))
			popup.add_theme_color_override("font_color", Color(1, 1, 1))
			popup.add_theme_color_override("font_hover_color", Color(1, 1, 1))


func _make_separator(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _make_line_edit(placeholder: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	_apply_font(le, 29)
	le.custom_minimum_size.y = 45
	le.custom_minimum_size.x = 380
	le.add_theme_stylebox_override("normal", PauseMenu._make_stone_style(0.18, true))
	le.add_theme_stylebox_override("focus", PauseMenu._make_stone_style(0.22, true))
	le.add_theme_color_override("font_color", Color(1, 1, 1))
	le.add_theme_color_override("font_placeholder_color", Color(0.45, 0.45, 0.45))
	return le


func _default_suffix(v: int, default_v: int) -> String:
	return " (Default)" if v == default_v else ""

func _format_sensitivity(v: int) -> String:
	if v <= 1: return "Sleepy"
	if v >= 200: return "WEEEEEE"
	return str(v) + _default_suffix(v, DEFAULT_MOUSE_SENSITIVITY)

func _format_fov(v: int) -> String:
	if v <= 50: return "Legally Blind"
	if v >= 120: return "I can see everything..."
	return str(v) + _default_suffix(v, DEFAULT_BASE_FOV)

func _format_view_distance(v: int) -> String:
	return "%d blocks%s" % [v, _default_suffix(v, DEFAULT_VIEW_DISTANCE)]


func _add_checkbox(parent: Control, text: String, initial: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var cb := CheckBox.new()
	cb.button_pressed = initial
	cb.text = text
	_apply_font(cb, 26)
	cb.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_style_checkbox(cb)
	cb.toggled.connect(callback)
	row.add_child(cb)


# --- Checkbox icons (shared static textures) ---
static var _CB_UNCHECKED: ImageTexture = _make_check_icon(false)
static var _CB_CHECKED: ImageTexture = _make_check_icon(true)

static func _make_check_icon(checked: bool) -> ImageTexture:
	const S: int = 22
	const B: int = 2
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline := Color(1, 1, 1, 0.95)
	for i: int in S:
		for b: int in B:
			img.set_pixel(i, b, outline)
			img.set_pixel(i, S - 1 - b, outline)
			img.set_pixel(b, i, outline)
			img.set_pixel(S - 1 - b, i, outline)
	if checked:
		var fill := Color(0.95, 0.95, 0.95, 1.0)
		for y: int in range(B + 1, S - B - 1):
			for x: int in range(B + 1, S - B - 1):
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)

func _style_checkbox(cb: CheckBox) -> void:
	cb.add_theme_icon_override("unchecked", _CB_UNCHECKED)
	cb.add_theme_icon_override("checked", _CB_CHECKED)


# --- Slider styling ---
static var _SLIDER_GRABBER: ImageTexture = _make_cube_tex(22, false)
static var _SLIDER_GRABBER_HOVER: ImageTexture = _make_cube_tex(22, true)

static func _make_cube_tex(size: int, hover: bool) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := Color(0.12, 0.12, 0.14)
	var fill_c := Color(0.78, 0.78, 0.80) if not hover else Color(0.92, 0.92, 0.94)
	var hi := Color(1.0, 1.0, 1.0)
	var shadow := Color(0.48, 0.48, 0.50) if not hover else Color(0.58, 0.58, 0.60)
	for i: int in size:
		img.set_pixel(i, 0, border); img.set_pixel(i, size - 1, border)
		img.set_pixel(0, i, border); img.set_pixel(size - 1, i, border)
	for y: int in range(1, size - 1):
		for x: int in range(1, size - 1):
			img.set_pixel(x, y, fill_c)
	for i: int in range(1, size - 1):
		img.set_pixel(i, 1, hi); img.set_pixel(1, i, hi)
	for i: int in range(1, size - 1):
		img.set_pixel(i, size - 2, shadow); img.set_pixel(size - 2, i, shadow)
	return ImageTexture.create_from_image(img)

func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.10, 0.10, 0.12)
	track.border_color = Color(0.50, 0.50, 0.52)
	track.set_border_width_all(2)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.60, 0.60, 0.62)
	fill.border_color = Color(0.85, 0.85, 0.87)
	fill.set_border_width_all(2)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _SLIDER_GRABBER)
	s.add_theme_icon_override("grabber_highlight", _SLIDER_GRABBER_HOVER)
	s.add_theme_icon_override("grabber_disabled", _SLIDER_GRABBER)


func _style_scrollbar(sb: ScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.10, 0.10, 0.12)
	track.border_color = Color(0.40, 0.40, 0.42)
	track.set_border_width_all(2)
	sb.add_theme_stylebox_override("scroll", track)
	sb.add_theme_stylebox_override("scroll_focus", track)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.60, 0.60, 0.62)
	grabber.border_color = Color(0.88, 0.88, 0.90)
	grabber.set_border_width_all(2)
	sb.add_theme_stylebox_override("grabber", grabber)
	var grabber_hover := grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(0.72, 0.72, 0.74)
	sb.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	var grabber_pressed := grabber.duplicate() as StyleBoxFlat
	grabber_pressed.bg_color = Color(0.45, 0.45, 0.47)
	sb.add_theme_stylebox_override("grabber_pressed", grabber_pressed)

func _style_scroll_container(sc: ScrollContainer) -> void:
	_style_scrollbar(sc.get_v_scroll_bar())
	_style_scrollbar(sc.get_h_scroll_bar())


func _highlight_group(btns: Array[Button], active_idx: int) -> void:
	for i: int in btns.size():
		if i == active_idx:
			var sel := PauseMenu._btn_selected_style.duplicate() as StyleBoxTexture
			sel.modulate_color = Color(1.0, 1.0, 0.7)
			btns[i].add_theme_stylebox_override("normal", sel)
		else:
			btns[i].add_theme_stylebox_override("normal", _btn_normal_style)
