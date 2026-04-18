class_name PauseMenu
extends CanvasLayer

enum Screen { MAIN, SAVE, LOAD, NEW_WORLD, SETTINGS, VIDEO, CONTROLS, LOADING }

signal resume_requested
signal save_requested(save_name: String)
signal load_requested(save_name: String)
signal new_world_requested(size: int, terrain_type: int, seed: int, world_name: String)
signal view_distance_changed(distance: int)
signal connected_textures_changed(enabled: bool)
signal flying_enabled_changed(enabled: bool)
signal aspect_ratio_changed(ratio: String)
signal gui_scale_changed(factor: float)
signal fullscreen_changed(mode: String)
signal base_fov_changed(fov: float)
signal sprint_toggle_changed(is_toggle: bool)
signal crouch_toggle_changed(is_toggle: bool)
signal mipmaps_changed(enabled: bool)
signal mouse_sensitivity_changed(value: int)
signal quit_requested
signal main_menu_requested

var _current_screen: int = Screen.MAIN
var _content: VBoxContainer
var _title_label: Label
var _font: Font = null

# Loading screen state
var _progress_bar: ProgressBar = null
var _loading_status: Label = null
var _loading_title: String = "Loading..."

# New world options state
# Pre-filled into the Save screen's name field. Set by main.gd from
# the world name chosen at creation (or the loaded save's name).
var default_save_name: String = "My World"
var _nw_size: int = 64
var _nw_terrain: int = World.TerrainType.VANILLA_DEFAULT
var _nw_seed: int = 0  # 0 = random

# Settings state — persisted in the pause menu across session
# Factory defaults — referenced by `_reset_all_settings` and by the slider
# value labels (which append "(Default)" when the current value matches).
const DEFAULT_VIEW_DISTANCE: int = 256
const DEFAULT_BASE_FOV: int = 70
const DEFAULT_MOUSE_SENSITIVITY: int = 100
var view_distance: int = DEFAULT_VIEW_DISTANCE
var connected_textures: bool = true
var flying_enabled: bool = true
var aspect_ratio: String = "Auto"
var gui_scale: float = 1.0
const FULLSCREEN_MODES: Array[String] = ["None", "Borderless", "Exclusive"]
var fullscreen: String = "None"
var base_fov: float = float(DEFAULT_BASE_FOV)
var sprint_toggle: bool = false  # false = Hold mode, true = Toggle mode
var crouch_toggle: bool = false
# Off by default — Minecraft's inventory textures look sharpest at native
# resolution; enabling mipmaps smooths distant blocks at the cost of slight
# pixel-art blur near the camera when looking down long corridors.
var mipmaps: bool = false
# Slider 1-200. 100 = normal sensitivity; 1 = "Sleepy" (barely moves); 200 =
# "WEEEEEE" (frantic). Player scales MOUSE_SENS_BASE by value/100.
var mouse_sensitivity: int = DEFAULT_MOUSE_SENSITIVITY

const ASPECT_RATIOS: Array[String] = ["Auto", "4:3", "16:9", "16:10", "21:9", "1:1"]
const GUI_SCALES: Array[float] = [0.5, 0.75, 1.0, 2.0, 3.0, 4.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 10
	visible = false
	_font = load("res://fonts/font.ttf")
	_load_settings()
	_build_ui()


## Pull persisted settings from disk into this node's state vars. Emitting
## the change signals is deferred until main.gd has connected them (see
## main.gd::_wire_pause_menu).
## Append " (Default)" when `v` matches the slider's factory default. Called
## from every slider's value-label formatter so users can see at a glance
## whether they've nudged a setting off of its shipped value.
func _default_suffix(v: int, default_v: int) -> String:
	return " (Default)" if v == default_v else ""


## Pretty-print the sensitivity value: endpoints get flavor names (which
## intentionally skip the default suffix since endpoints are never the
## default), the rest display as plain integers + "(Default)" when at 100.
func _format_sensitivity(v: int) -> String:
	if v <= 1:
		return "Sleepy"
	if v >= 200:
		return "WEEEEEE"
	return str(v) + _default_suffix(v, DEFAULT_MOUSE_SENSITIVITY)


## Same pattern as sensitivity: flavor labels at the endpoints, numeric +
## "(Default)" in between.
func _format_fov(v: int) -> String:
	if v <= 50:
		return "Legally Blind"
	if v >= 120:
		return "I can see everything..."
	return str(v) + _default_suffix(v, DEFAULT_BASE_FOV)


## View distance is always numeric (no flavor endpoints) so the formatter is
## simpler — just the value plus unit, plus the default suffix when matching.
func _format_view_distance(v: int) -> String:
	return "%d blocks%s" % [v, _default_suffix(v, DEFAULT_VIEW_DISTANCE)]


func _load_settings() -> void:
	var data: Dictionary = SettingsConfig.load_all()
	if data.has("view_distance"):
		view_distance = int(data["view_distance"])
	if data.has("connected_textures"):
		connected_textures = bool(data["connected_textures"])
	if data.has("flying_enabled"):
		flying_enabled = bool(data["flying_enabled"])
	if data.has("aspect_ratio"):
		aspect_ratio = str(data["aspect_ratio"])
	if data.has("gui_scale"):
		gui_scale = float(data["gui_scale"])
	if data.has("fullscreen"):
		var fs_val = data["fullscreen"]
		if fs_val is bool:
			fullscreen = "Borderless" if bool(fs_val) else "None"
		else:
			fullscreen = str(fs_val) if str(fs_val) in FULLSCREEN_MODES else "None"
	if data.has("base_fov"):
		base_fov = float(data["base_fov"])
	if data.has("sprint_toggle"):
		sprint_toggle = bool(data["sprint_toggle"])
	if data.has("crouch_toggle"):
		crouch_toggle = bool(data["crouch_toggle"])
	if data.has("mipmaps"):
		mipmaps = bool(data["mipmaps"])
	if data.has("mouse_sensitivity"):
		mouse_sensitivity = clampi(int(data["mouse_sensitivity"]), 1, 200)


## Reset every persisted setting to its factory default, push the new values
## to every listener via the change signals, persist to disk, and rebuild
## the settings screen so all widgets reflect the reset.
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
	view_distance_changed.emit(view_distance)
	connected_textures_changed.emit(connected_textures)
	flying_enabled_changed.emit(flying_enabled)
	aspect_ratio_changed.emit(aspect_ratio)
	gui_scale_changed.emit(gui_scale)
	fullscreen_changed.emit(fullscreen)
	base_fov_changed.emit(base_fov)
	sprint_toggle_changed.emit(sprint_toggle)
	crouch_toggle_changed.emit(crouch_toggle)
	mipmaps_changed.emit(mipmaps)
	mouse_sensitivity_changed.emit(mouse_sensitivity)
	_save_settings()
	if _current_screen == Screen.SETTINGS:
		_show_screen(Screen.SETTINGS)


## Write every persisted setting to disk. Called after any change so the
## user's configuration survives restart.
func _save_settings() -> void:
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


func _build_ui() -> void:
	# Dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# ScrollContainer wraps the menu so at high GUI scales the panel can
	# grow beyond the window; scrollbars appear to navigate it instead of
	# clipping off-screen. When the panel fits, the inner CenterContainer's
	# EXPAND_FILL flags make it grow to the viewport and center the panel.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_scroll_container(scroll)
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	panel_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	panel.add_child(_content)

	_show_screen(Screen.MAIN)


func show_menu() -> void:
	visible = true
	_show_screen(Screen.MAIN)


func hide_menu() -> void:
	visible = false


func show_loading(title: String) -> void:
	_loading_title = title
	visible = true
	_show_screen(Screen.LOADING)


func update_progress(progress: float, status: String) -> void:
	if _progress_bar != null:
		_progress_bar.value = progress * 100.0
	if _loading_status != null:
		_loading_status.text = status


func _clear_content() -> void:
	for child: Node in _content.get_children():
		child.queue_free()


func _show_screen(screen: int) -> void:
	_current_screen = screen
	# Cancel any in-progress rebind — its button is about to be freed.
	_rebinding_action = &""
	_rebinding_button = null
	_clear_content()
	# Small delay not needed — queue_free is deferred, but new children added now
	# won't conflict because old children are removed from tree before next frame.
	# However, we need to make sure old ones are gone before building new ones.
	# Use immediate free() to be safe:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	match screen:
		Screen.MAIN: _build_main()
		Screen.SAVE: _build_save()
		Screen.LOAD: _build_load()
		Screen.NEW_WORLD: _build_new_world()
		Screen.SETTINGS: _build_settings()
		Screen.VIDEO: _build_video_settings()
		Screen.CONTROLS: _build_controls()
		Screen.LOADING: _build_loading()


# --- UI helpers ---

# Global font scale. The UI was authored with the original pixel font at
# size 26. A different font may have larger glyphs at the same point size;
# lower this to compensate. 1.0 = original sizes, 0.5 = half.
const FONT_SCALE: float = 0.5

## Scale a raw authored font size by FONT_SCALE. Use this everywhere instead
## of hardcoding pixel sizes so a font swap only needs one constant change.
static func _fs(size: int) -> int:
	return int(size * FONT_SCALE)

func _apply_font(ctrl: Control, size: int) -> void:
	if _font != null:
		ctrl.add_theme_font_override("font", _font)
	ctrl.add_theme_font_size_override("font_size", _fs(size))


func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(label, 45)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	return label


func _make_subtitle(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(label, 26)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	return label


func _make_button(text: String, min_width: int = 0) -> Button:
	var btn := Button.new()
	btn.text = text
	_apply_font(btn, 22)
	if min_width > 0:
		btn.custom_minimum_size.x = min_width
	_style_button(btn)
	return btn


func _make_label(text: String, size: int = 26, color: Color = Color(0.85, 0.85, 0.85)) -> Label:
	var label := Label.new()
	label.text = text
	_apply_font(label, size)
	label.add_theme_color_override("font_color", color)
	return label


## Give a CheckBox a clearly-visible outlined box (unchecked) and a filled
## box with a tick (checked). Godot's default icon is nearly invisible on
## the dark pause-menu panel.
func _style_checkbox(cb: CheckBox) -> void:
	cb.add_theme_icon_override("unchecked", _CHECKBOX_UNCHECKED)
	cb.add_theme_icon_override("checked", _CHECKBOX_CHECKED)


# Built once and shared by every checkbox — constructed lazily below.
static var _CHECKBOX_UNCHECKED: ImageTexture = _make_check_icon(false)
static var _CHECKBOX_CHECKED: ImageTexture = _make_check_icon(true)


static func _make_check_icon(checked: bool) -> ImageTexture:
	const SIZE: int = 22
	const BORDER: int = 2
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# White outline box.
	var outline := Color(1, 1, 1, 0.95)
	for i: int in SIZE:
		for b: int in BORDER:
			img.set_pixel(i, b, outline)
			img.set_pixel(i, SIZE - 1 - b, outline)
			img.set_pixel(b, i, outline)
			img.set_pixel(SIZE - 1 - b, i, outline)
	if checked:
		# Fill + inner highlight tick (just fill for clear contrast).
		var fill := Color(0.95, 0.95, 0.95, 1.0)
		for y: int in range(BORDER + 1, SIZE - BORDER - 1):
			for x: int in range(BORDER + 1, SIZE - BORDER - 1):
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


# --- Stone-textured button StyleBox generation ---
# Built once at startup, reused for every button. Three states: normal (mid
# stone), hover (brighter), pressed (darker + inverted bevel for a push-in
# feel). The texture tiles across the button interior so large buttons still
# read as stone, and the 2px beveled border gives a Minecraft-style 3D look.
static var _btn_normal_style: StyleBoxTexture = _make_stone_style(0.42, false)
static var _btn_hover_style: StyleBoxTexture = _make_stone_style(0.52, false)
static var _btn_pressed_style: StyleBoxTexture = _make_stone_style(0.30, true)


## Minecraft-style button: flat gray center, 1px dark outer border, 1px
## inner bevel (light top/left, shadow bottom/right). The texture is a
## small 8×8 nine-patch — edges stay fixed at the borders, center stretches
## to any button size. No tiling, no grid, no noise.
static func _make_stone_style(brightness: float, invert_bevel: bool) -> StyleBoxTexture:
	var tex := _make_btn_tex(brightness, invert_bevel)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	# Nine-patch margins: 2px border region on each side stays fixed,
	# everything inside stretches to fill.
	sb.texture_margin_left = 2
	sb.texture_margin_right = 2
	sb.texture_margin_top = 2
	sb.texture_margin_bottom = 2
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func _make_btn_tex(brightness: float, invert_bevel: bool) -> ImageTexture:
	const S: int = 8
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var fill := Color(brightness, brightness, brightness)
	img.fill(fill)
	# Bevel
	var hi_v: float = clampf(brightness + 0.20, 0.0, 1.0)
	var sh_v: float = clampf(brightness - 0.15, 0.0, 1.0)
	var hi := Color(hi_v, hi_v, hi_v)
	var sh := Color(sh_v, sh_v, sh_v)
	if invert_bevel:
		var tmp := hi; hi = sh; sh = tmp
	# Outer 1px dark border
	var edge := Color(0.0, 0.0, 0.0)
	for i: int in S:
		img.set_pixel(i, 0, edge); img.set_pixel(i, S - 1, edge)
		img.set_pixel(0, i, edge); img.set_pixel(S - 1, i, edge)
	# Inner 1px bevel: top + left = highlight, bottom + right = shadow
	for i: int in range(1, S - 1):
		img.set_pixel(i, 1, hi); img.set_pixel(1, i, hi)
	for i: int in range(1, S - 1):
		img.set_pixel(i, S - 2, sh); img.set_pixel(S - 2, i, sh)
	return ImageTexture.create_from_image(img)


func _style_button(btn: Button) -> void:
	# Nearest-neighbor so the bevel pixels stay crisp — no gradient smear.
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.add_theme_stylebox_override("normal", _btn_normal_style)
	btn.add_theme_stylebox_override("hover", _btn_hover_style)
	btn.add_theme_stylebox_override("pressed", _btn_pressed_style)
	btn.add_theme_stylebox_override("focus", _btn_hover_style)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))
	# OptionButtons are Buttons too — apply the same stone look.
	if btn is OptionButton:
		var popup: PopupMenu = (btn as OptionButton).get_popup()
		if popup != null:
			var panel := _make_stone_style(0.32, false)
			popup.add_theme_stylebox_override("panel", panel)
			var hover_item := _make_stone_style(0.50, false)
			popup.add_theme_stylebox_override("hover", hover_item)
			if _font != null:
				popup.add_theme_font_override("font", _font)
			popup.add_theme_font_size_override("font_size", _fs(26))
			popup.add_theme_color_override("font_color", Color(1, 1, 1))
			popup.add_theme_color_override("font_hover_color", Color(1, 1, 1))


func _make_separator(h: int = 8) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	return s


# --- Minecraft-style cubish slider / scrollbar styling ---

## Cube-looking grabber texture used by HSlider. Built once, reused by every
## slider. Light fill + dark 1px border + top/left highlight + bottom/right
## shadow give it a chunky 3D-block read consistent with the voxel art.
static var _SLIDER_GRABBER: ImageTexture = _make_cube_texture(22)
static var _SLIDER_GRABBER_HOVER: ImageTexture = _make_cube_texture(22, true)


static func _make_cube_texture(size: int, hover: bool = false) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := Color(0.12, 0.12, 0.14)
	var fill := Color(0.78, 0.78, 0.80) if not hover else Color(0.92, 0.92, 0.94)
	var hi := Color(1.0, 1.0, 1.0)
	var shadow := Color(0.48, 0.48, 0.50) if not hover else Color(0.58, 0.58, 0.60)
	# Border
	for i: int in size:
		img.set_pixel(i, 0, border)
		img.set_pixel(i, size - 1, border)
		img.set_pixel(0, i, border)
		img.set_pixel(size - 1, i, border)
	# Fill
	for y: int in range(1, size - 1):
		for x: int in range(1, size - 1):
			img.set_pixel(x, y, fill)
	# Top/left highlight (1px inside border)
	for i: int in range(1, size - 1):
		img.set_pixel(i, 1, hi)
		img.set_pixel(1, i, hi)
	# Bottom/right shadow
	for i: int in range(1, size - 1):
		img.set_pixel(i, size - 2, shadow)
		img.set_pixel(size - 2, i, shadow)
	return ImageTexture.create_from_image(img)


## Apply a cubish / Minecraft-ish look to an HSlider: flat dark track with a
## beveled fill and a block-grabber.
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


## Apply the cubish look to a VScrollBar / HScrollBar: dark track with a
## beveled block thumb.
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


## Style both scrollbars of a ScrollContainer.
func _style_scroll_container(sc: ScrollContainer) -> void:
	_style_scrollbar(sc.get_v_scroll_bar())
	_style_scrollbar(sc.get_h_scroll_bar())
	# Prevent jitter when scrolling past bounds (especially over remote
	# input like Steam Link that may flood scroll events). Disabling
	# follow_focus prevents auto-scroll triggered by focused children;
	# clamping allow_greater/allow_lesser prevents overshoot bounce.
	sc.follow_focus = false
	var vb: VScrollBar = sc.get_v_scroll_bar()
	vb.allow_greater = false
	vb.allow_lesser = false
	var hb: HScrollBar = sc.get_h_scroll_bar()
	hb.allow_greater = false
	hb.allow_lesser = false


## Parse a seed string. Empty -> 0 (random). A pure int -> parsed. Otherwise
## hash the string to a stable int so text seeds ("hello") are reproducible.
static func _parse_seed(text: String) -> int:
	var t := text.strip_edges()
	if t.is_empty():
		return 0
	if t.is_valid_int():
		var n := int(t)
		return n if n != 0 else 1
	return hash(t)


# Dark recessed stone for text input fields — looks like a carved slot.
static var _input_style: StyleBoxTexture = _make_stone_style(0.18, true)
static var _input_focus_style: StyleBoxTexture = _make_stone_style(0.22, true)

func _make_line_edit(placeholder: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	_apply_font(le, 29)
	le.custom_minimum_size.y = 45
	le.add_theme_stylebox_override("normal", _input_style)
	le.add_theme_stylebox_override("focus", _input_focus_style)
	le.add_theme_color_override("font_color", Color(1, 1, 1))
	le.add_theme_color_override("font_placeholder_color", Color(0.45, 0.45, 0.45))
	return le


# --- Main screen ---

func _build_main() -> void:
	_content.add_child(_make_title("RECRAFT"))
	_content.add_child(_make_subtitle("-- Paused --"))
	_content.add_child(_make_separator(12))

	var btn_resume := _make_button("Resume", 280)
	btn_resume.pressed.connect(func(): resume_requested.emit())
	_content.add_child(btn_resume)

	var btn_save := _make_button("Save World", 280)
	btn_save.pressed.connect(func(): _show_screen(Screen.SAVE))
	_content.add_child(btn_save)

	var btn_load := _make_button("Load World", 280)
	btn_load.pressed.connect(func(): _show_screen(Screen.LOAD))
	_content.add_child(btn_load)

	var btn_new := _make_button("New World", 280)
	btn_new.pressed.connect(func(): _show_screen(Screen.NEW_WORLD))
	_content.add_child(btn_new)

	var btn_settings := _make_button("Settings", 280)
	btn_settings.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	_content.add_child(btn_settings)

	_content.add_child(_make_separator(6))

	var btn_menu := _make_button("Main Menu", 280)
	btn_menu.pressed.connect(func(): main_menu_requested.emit())
	_content.add_child(btn_menu)


# --- Save screen ---

func _build_save() -> void:
	_content.add_child(_make_title("Save World"))
	_content.add_child(_make_separator(6))

	_content.add_child(_make_label("Save name:", 26))

	var name_edit := _make_line_edit("Enter save name...")
	name_edit.text = default_save_name
	_content.add_child(name_edit)

	var save_row := HBoxContainer.new()
	save_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(save_row)
	var btn_save := _make_button("  Save  ", 140)
	btn_save.pressed.connect(func():
		var n: String = SaveSystem.sanitize_name(name_edit.text)
		if n.length() > 0:
			save_requested.emit(n)
			_show_screen(Screen.SAVE)  # refresh list
	)
	save_row.add_child(btn_save)

	_content.add_child(_make_separator(8))

	_content.add_child(_make_label("Existing saves (click to overwrite):", 24, Color(0.75, 0.75, 0.75)))

	# Scrollable save list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 160
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll_container(scroll)
	_content.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)

	var saves: Array = SaveSystem.list_saves()
	if saves.is_empty():
		list.add_child(_make_label("  (no saves yet)", 22, Color(0.55, 0.55, 0.55)))
	else:
		for info: Dictionary in saves:
			var row := _make_save_row_overwrite(info, name_edit)
			list.add_child(row)

	_content.add_child(_make_separator(8))
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.MAIN))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back)
	_content.add_child(back_row)


func _make_save_row_overwrite(info: Dictionary, name_edit: LineEdit) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info_text: String = "%s  (%d³)  %s" % [info.name, info.size, SaveSystem.format_timestamp(info.timestamp)]
	var label := _make_label(info_text, 22, Color(0.9, 0.9, 0.9))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var btn := _make_button("Overwrite")
	_apply_font(btn, 22)
	btn.pressed.connect(func():
		name_edit.text = info.name
		save_requested.emit(info.name)
		_show_screen(Screen.SAVE)
	)
	row.add_child(btn)

	return row


# --- Load screen ---

func _build_load() -> void:
	_content.add_child(_make_title("Load World"))
	_content.add_child(_make_separator(6))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll_container(scroll)
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
			list.add_child(_make_save_row_load(info))

	_content.add_child(_make_separator(8))
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.MAIN))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_child(back)
	_content.add_child(back_row)


func _make_save_row_load(info: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var info_text: String = "%s  (%d³)  %s" % [info.name, info.size, SaveSystem.format_timestamp(info.timestamp)]
	var label := _make_label(info_text, 22, Color(0.9, 0.9, 0.9))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var btn_load := _make_button("Load")
	_apply_font(btn_load, 22)
	btn_load.pressed.connect(func():
		load_requested.emit(info.name))
	row.add_child(btn_load)

	var btn_delete := _make_button("Delete")
	_apply_font(btn_delete, 22)
	btn_delete.pressed.connect(func():
		SaveSystem.delete_save(info.name)
		_show_screen(Screen.LOAD))
	row.add_child(btn_delete)

	return row


# --- New World screen ---

func _build_new_world() -> void:
	_content.add_child(_make_title("New World"))
	_content.add_child(_make_separator(8))

	_content.add_child(_make_label("World Name:", 26))
	var nw_name_edit := _make_line_edit("My World")
	_content.add_child(nw_name_edit)

	_content.add_child(_make_separator(10))

	# Size selector
	_content.add_child(_make_label("World Size:", 26))

	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_row.add_theme_constant_override("separation", 6)
	_content.add_child(size_row)

	var sizes: Array[int] = [32, 64, 128, 256, 512]
	var size_btns: Array[Button] = []
	for s: int in sizes:
		var b := _make_button("%d³" % s, 66)
		b.pressed.connect(func():
			_nw_size = s
			_update_size_buttons(size_btns, sizes)
		)
		size_row.add_child(b)
		size_btns.append(b)
	_update_size_buttons(size_btns, sizes)

	_content.add_child(_make_separator(10))

	# Seed input (optional)
	_content.add_child(_make_label("Seed (optional):", 26))
	var seed_edit := _make_line_edit("blank = random")
	if _nw_seed != 0:
		seed_edit.text = str(_nw_seed)
	_content.add_child(seed_edit)

	_content.add_child(_make_separator(10))

	# Terrain type selector
	_content.add_child(_make_label("Terrain Type:", 26))

	var type_row := HBoxContainer.new()
	type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	type_row.add_theme_constant_override("separation", 6)
	_content.add_child(type_row)

	var flat_btn := _make_button("Flatgrass", 110)
	var default_btn := _make_button("Default", 110)
	var hilly_btn := _make_button("Hilly", 110)
	var type_btns: Array[Button] = [flat_btn, default_btn, hilly_btn]
	var type_values: Array[int] = [
		World.TerrainType.FLATGRASS,
		World.TerrainType.VANILLA_DEFAULT,
		World.TerrainType.VANILLA_HILLY,
	]
	type_row.add_child(flat_btn)
	type_row.add_child(default_btn)
	type_row.add_child(hilly_btn)

	flat_btn.pressed.connect(func():
		_nw_terrain = World.TerrainType.FLATGRASS
		_update_terrain_buttons(type_btns, type_values)
	)
	default_btn.pressed.connect(func():
		_nw_terrain = World.TerrainType.VANILLA_DEFAULT
		_update_terrain_buttons(type_btns, type_values)
	)
	hilly_btn.pressed.connect(func():
		_nw_terrain = World.TerrainType.VANILLA_HILLY
		_update_terrain_buttons(type_btns, type_values)
	)
	_update_terrain_buttons(type_btns, type_values)

	_content.add_child(_make_separator(14))

	# Generate + Back
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	_content.add_child(action_row)

	var gen_btn := _make_button("Generate", 140)
	gen_btn.pressed.connect(func():
		_nw_seed = _parse_seed(seed_edit.text)
		var wn: String = nw_name_edit.text.strip_edges()
		if wn.is_empty():
			wn = "My World"
		new_world_requested.emit(_nw_size, _nw_terrain, _nw_seed, wn)
	)
	action_row.add_child(gen_btn)

	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.MAIN))
	action_row.add_child(back)


# Selected button highlight: swap to a brighter stone style with a yellow
# tinted modulate. Uses StyleBoxTexture.modulate_color so it works with the
# stone textures (no border_color on StyleBoxTexture).
static var _btn_selected_style: StyleBoxTexture = _make_stone_style(0.55, false)

func _update_size_buttons(btns: Array[Button], sizes: Array[int]) -> void:
	for i: int in btns.size():
		if sizes[i] == _nw_size:
			var sel := _btn_selected_style.duplicate() as StyleBoxTexture
			sel.modulate_color = Color(1.0, 1.0, 0.7)
			btns[i].add_theme_stylebox_override("normal", sel)
		else:
			btns[i].add_theme_stylebox_override("normal", _btn_normal_style)


func _update_terrain_buttons(btns: Array[Button], values: Array[int]) -> void:
	for i: int in btns.size():
		if values[i] == _nw_terrain:
			var sel := _btn_selected_style.duplicate() as StyleBoxTexture
			sel.modulate_color = Color(1.0, 1.0, 0.7)
			btns[i].add_theme_stylebox_override("normal", sel)
		else:
			btns[i].add_theme_stylebox_override("normal", _btn_normal_style)


# --- Loading screen ---

func _build_loading() -> void:
	_content.add_child(_make_title(_loading_title))
	_content.add_child(_make_separator(20))

	_loading_status = _make_label("Starting...", 26, Color(0.9, 0.9, 0.9))
	_loading_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_loading_status)

	_content.add_child(_make_separator(10))

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.custom_minimum_size = Vector2(400, 28)
	_progress_bar.show_percentage = true
	if _font != null:
		_progress_bar.add_theme_font_override("font", _font)
	_progress_bar.add_theme_font_size_override("font_size", _fs(22))

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.10)
	bg_style.border_color = Color(0.5, 0.5, 0.5)
	bg_style.set_border_width_all(2)
	_progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.35, 0.78, 0.35)
	fill_style.border_color = Color(0.5, 0.9, 0.5)
	fill_style.set_border_width_all(1)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

	_content.add_child(_progress_bar)
	_content.add_child(_make_separator(12))


# --- Settings screen ---

# 64-block granularity — min aligned to the step so all visible tick values
# are clean multiples of 64 (64, 128, 192, ..., 4096). Default 256 lands on
# a tick naturally.
const VIEW_DISTANCE_MIN: int = 64
const VIEW_DISTANCE_MAX: int = 4096
const VIEW_DISTANCE_STEP: int = 64


## Top-level settings hub — shows the most-tweaked options at the top (FOV
## and GUI Scale) plus buttons to dive into Video Settings and Controls.
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

	# FOV at the top — most-tweaked visual setting.
	_content.add_child(_make_label("Field of View:", 26))
	var fov_value_label := _make_label(_format_fov(int(round(base_fov))), 24, Color(0.85, 0.85, 0.85))
	fov_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fov_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(fov_value_label)
	var fov_slider := HSlider.new()
	fov_slider.min_value = 50.0
	fov_slider.max_value = 120.0
	fov_slider.step = 1.0
	fov_slider.value = base_fov
	fov_slider.custom_minimum_size = Vector2(380, 28)
	_style_slider(fov_slider)
	fov_slider.value_changed.connect(func(v: float):
		base_fov = v
		fov_value_label.text = _format_fov(int(round(base_fov)))
		base_fov_changed.emit(base_fov)
		_save_settings()
	)
	_content.add_child(fov_slider)

	_content.add_child(_make_separator(16))

	# GUI Scale near the top — also frequently adjusted.
	_content.add_child(_make_label("GUI Scale:", 26))
	var gs_option := OptionButton.new()
	_apply_font(gs_option, 29)
	gs_option.custom_minimum_size = Vector2(380, 44)
	for factor: float in GUI_SCALES:
		var label: String
		if factor == float(int(factor)):
			label = "%dx" % int(factor)
		else:
			label = "%.1fx" % factor
		gs_option.add_item(label)
	gs_option.selected = maxi(0, GUI_SCALES.find(gui_scale))
	_style_button(gs_option)
	gs_option.item_selected.connect(func(idx: int):
		gui_scale = GUI_SCALES[idx]
		gui_scale_changed.emit(gui_scale)
		_save_settings()
	)
	_content.add_child(gs_option)

	_content.add_child(_make_separator(24))

	# Sub-screens.
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


## Video sub-screen: view distance, connected textures, mipmaps, aspect
## ratio, fullscreen.
func _build_video_settings() -> void:
	_content.add_child(_make_title("Video Settings"))
	_content.add_child(_make_separator(8))

	# Wrap every setting widget in a ScrollContainer so a GUI scale too large
	# to fit on screen can still be changed back — the user can scroll to
	# any option including the GUI Scale dropdown.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_scroll_container(scroll)
	_content.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_make_label("View Distance:", 26))

	var vd_value_label := _make_label(_format_view_distance(view_distance), 24, Color(0.85, 0.85, 0.85))
	vd_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vd_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(vd_value_label)

	var slider := HSlider.new()
	slider.min_value = VIEW_DISTANCE_MIN
	slider.max_value = VIEW_DISTANCE_MAX
	slider.step = VIEW_DISTANCE_STEP
	slider.value = view_distance
	slider.custom_minimum_size = Vector2(380, 28)
	_style_slider(slider)
	slider.value_changed.connect(func(v: float):
		view_distance = int(v)
		vd_value_label.text = _format_view_distance(view_distance)
		view_distance_changed.emit(view_distance)
		_save_settings()
	)
	list.add_child(slider)
	list.add_child(_make_separator(16))

	# Connected Textures toggle.
	var ct_row := HBoxContainer.new()
	ct_row.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_child(ct_row)
	var ct_checkbox := CheckBox.new()
	ct_checkbox.button_pressed = connected_textures
	ct_checkbox.text = "Connected Textures"
	_apply_font(ct_checkbox, 26)
	ct_checkbox.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_style_checkbox(ct_checkbox)
	ct_checkbox.toggled.connect(func(v: bool):
		connected_textures = v
		connected_textures_changed.emit(v)
		_save_settings()
	)
	ct_row.add_child(ct_checkbox)

	# Mipmaps toggle.
	var mm_row := HBoxContainer.new()
	mm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_child(mm_row)
	var mm_checkbox := CheckBox.new()
	mm_checkbox.button_pressed = mipmaps
	mm_checkbox.text = "Mipmaps"
	_apply_font(mm_checkbox, 26)
	mm_checkbox.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_style_checkbox(mm_checkbox)
	mm_checkbox.toggled.connect(func(v: bool):
		mipmaps = v
		mipmaps_changed.emit(v)
		_save_settings()
	)
	mm_row.add_child(mm_checkbox)

	list.add_child(_make_separator(16))

	# Aspect Ratio dropdown.
	list.add_child(_make_label("Aspect Ratio:", 26))
	var ar_option := OptionButton.new()
	_apply_font(ar_option, 29)
	ar_option.custom_minimum_size = Vector2(380, 44)
	for name: String in ASPECT_RATIOS:
		ar_option.add_item(name)
	ar_option.selected = maxi(0, ASPECT_RATIOS.find(aspect_ratio))
	_style_button(ar_option)
	ar_option.item_selected.connect(func(idx: int):
		aspect_ratio = ASPECT_RATIOS[idx]
		aspect_ratio_changed.emit(aspect_ratio)
		_save_settings()
	)
	list.add_child(ar_option)

	list.add_child(_make_separator(16))

	# Fullscreen dropdown.
	list.add_child(_make_label("Fullscreen:", 26))
	var fs_option := OptionButton.new()
	_apply_font(fs_option, 29)
	fs_option.custom_minimum_size = Vector2(380, 44)
	for mode_name: String in FULLSCREEN_MODES:
		fs_option.add_item(mode_name)
	fs_option.selected = maxi(0, FULLSCREEN_MODES.find(fullscreen))
	_style_button(fs_option)
	fs_option.item_selected.connect(func(idx: int):
		fullscreen = FULLSCREEN_MODES[idx]
		fullscreen_changed.emit(fullscreen)
		_save_settings()
	)
	list.add_child(fs_option)

	_content.add_child(_make_separator(20))

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(back_row)
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	back_row.add_child(back)

# --- Controls screen ---

# When non-empty, any key press is swallowed into this rebind instead of
# reaching the rest of the UI.
var _rebinding_action: StringName = &""
var _rebinding_button: Button = null


func _build_controls() -> void:
	_content.add_child(_make_title("Controls"))
	_content.add_child(_make_separator(8))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_scroll_container(scroll)
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Mouse sensitivity.
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
		mouse_sensitivity_changed.emit(mouse_sensitivity)
		_save_settings()
	)
	list.add_child(ms_slider)

	list.add_child(_make_separator(16))

	# Sprint Mode dropdown.
	list.add_child(_make_label("Sprint Mode:", 26))
	var sprint_option := OptionButton.new()
	_apply_font(sprint_option, 29)
	sprint_option.custom_minimum_size = Vector2(380, 44)
	sprint_option.add_item("Hold")
	sprint_option.add_item("Toggle")
	sprint_option.selected = 1 if sprint_toggle else 0
	_style_button(sprint_option)
	sprint_option.item_selected.connect(func(idx: int):
		sprint_toggle = idx == 1
		sprint_toggle_changed.emit(sprint_toggle)
		_save_settings()
	)
	list.add_child(sprint_option)
	list.add_child(_make_separator(16))

	# Crouch Mode dropdown.
	list.add_child(_make_label("Crouch Mode:", 26))
	var crouch_option := OptionButton.new()
	_apply_font(crouch_option, 29)
	crouch_option.custom_minimum_size = Vector2(380, 44)
	crouch_option.add_item("Hold")
	crouch_option.add_item("Toggle")
	crouch_option.selected = 1 if crouch_toggle else 0
	_style_button(crouch_option)
	crouch_option.item_selected.connect(func(idx: int):
		crouch_toggle = idx == 1
		crouch_toggle_changed.emit(crouch_toggle)
		_save_settings()
	)
	list.add_child(crouch_option)
	list.add_child(_make_separator(16))

	# Enable Flying checkbox.
	var fly_row := HBoxContainer.new()
	fly_row.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_child(fly_row)
	var fly_cb := CheckBox.new()
	fly_cb.button_pressed = flying_enabled
	fly_cb.text = "Enable Flying"
	_apply_font(fly_cb, 26)
	fly_cb.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_style_checkbox(fly_cb)
	fly_cb.toggled.connect(func(v: bool):
		flying_enabled = v
		flying_enabled_changed.emit(v)
		_save_settings()
	)
	fly_row.add_child(fly_cb)

	list.add_child(_make_separator(20))
	list.add_child(_make_label("Key Bindings (click to rebind, Esc cancels):", 22, Color(0.7, 0.7, 0.7)))
	list.add_child(_make_separator(4))

	for entry: Array in ControlsConfig.ACTIONS:
		list.add_child(_make_controls_row(entry[0], entry[1]))

	_content.add_child(_make_separator(20))

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(back_row)
	var back := _make_button("Back", 140)
	back.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	back_row.add_child(back)


func _make_controls_row(action: StringName, label_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := _make_label(label_text, 26, Color(0.9, 0.9, 0.9))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var code: int = ControlsConfig.get_action_physical_keycode(action)
	var btn := _make_button(ControlsConfig.keycode_to_string(code), 180)
	btn.pressed.connect(_start_rebind.bind(action, btn))
	row.add_child(btn)
	return row


func _start_rebind(action: StringName, btn: Button) -> void:
	# Cancel any previous rebind-in-progress cleanly.
	if _rebinding_button != null and _rebinding_button != btn:
		var prev_code: int = ControlsConfig.get_action_physical_keycode(_rebinding_action)
		_rebinding_button.text = ControlsConfig.keycode_to_string(prev_code)
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "Press any key..."


# Back to main on Escape if on a submenu
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _current_screen == Screen.LOADING:
			return  # cannot escape from loading screen
		if _current_screen == Screen.MAIN:
			resume_requested.emit()
		elif _current_screen == Screen.CONTROLS or _current_screen == Screen.VIDEO:
			_show_screen(Screen.SETTINGS)
		else:
			_show_screen(Screen.MAIN)
		get_viewport().set_input_as_handled()


## High-priority input handler — catches key presses during a rebind before
## buttons / the Escape handler can react to them.
func _input(event: InputEvent) -> void:
	if _rebinding_action == &"":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var ek: InputEventKey = event
	if ek.keycode == KEY_ESCAPE:
		# Cancel — restore the button text to whatever's currently bound.
		var prev: int = ControlsConfig.get_action_physical_keycode(_rebinding_action)
		_rebinding_button.text = ControlsConfig.keycode_to_string(prev)
	else:
		var code: int = ek.physical_keycode
		if code == 0:
			code = ek.keycode
		ControlsConfig.set_action_key(_rebinding_action, code)
		ControlsConfig.save()
		# Rebuild the Controls screen so any OTHER action that lost this
		# key (duplicate-binding dedupe) now shows "Unbound" correctly.
		_rebinding_action = &""
		_rebinding_button = null
		get_viewport().set_input_as_handled()
		if _current_screen == Screen.CONTROLS:
			_show_screen(Screen.CONTROLS)
		return
	_rebinding_action = &""
	_rebinding_button = null
	get_viewport().set_input_as_handled()
