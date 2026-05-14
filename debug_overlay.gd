extends Control

# ── Constants ───────────────────────────────────────────────────────────────
const REDRAW_INTERVAL: float = 0.1
const HISTORY_SIZE: int = 200
const FONT_SIZE: int = 14
const PAD: float = 6.0
const SAVE_PATH: String = "user://debug_display_modes.cfg"

const MODE_ALWAYS: int = 0  # shown in compact HUD at all times
const MODE_F3: int = 1      # shown only in F3 screen
const MODE_NEVER: int = 2   # never shown

# [key, display_name, column (0=left / 1=right), default_mode]
const ITEM_DEFS: Array = [
	["fps",           "FPS / Frame Time",    0, MODE_F3],
	["xyz",           "Coordinates (XYZ)",   0, MODE_F3],
	["chunk_pos",     "Chunk",               0, MODE_F3],
	["facing",        "Facing",              0, MODE_F3],
	["velocity",      "Velocity",            0, MODE_F3],
	["block",         "Targeted Block",      0, MODE_F3],
	["target_pos",    "Targeted Coords",     0, MODE_F3],
	["biome",         "Biome",               0, MODE_F3],
	["dimension",     "Dimension",           0, MODE_F3],
	["time",          "Time of Day",         0, MODE_F3],
	["held",          "Held Block",          0, MODE_F3],
	["light_level",   "Light Level",         0, MODE_F3],
	["fly_state",     "Player State",        0, MODE_F3],
	["fov",           "FOV",                 0, MODE_F3],
	["tick_rate",     "Game Tick Rate",      0, MODE_F3],
	["chunks_loaded", "Chunks Loaded",       0, MODE_F3],
	["world_seed",    "World Seed",          0, MODE_F3],
	["godot_ver",     "Godot Version",       1, MODE_F3],
	["cpu",           "CPU",                 1, MODE_F3],
	["cpu_cores",     "CPU Cores",           1, MODE_F3],
	["cpu_freq",      "CPU Frequency",       1, MODE_F3],
	["gpu",           "GPU",                 1, MODE_F3],
	["vram_used",     "VRAM Used",           1, MODE_F3],
	["vram_tex",      "VRAM (Textures)",     1, MODE_F3],
	["ram",           "RAM Used",            1, MODE_F3],
	["ram_alloc",     "RAM Allocated",       1, MODE_F3],
	["os_name",       "Operating System",    1, MODE_F3],
	["display",       "Display",             1, MODE_F3],
	["renderer",      "Renderer",            1, MODE_F3],
	["draw_calls",    "Draw Calls",          1, MODE_F3],
	["vertices",      "Vertices/Triangles",  1, MODE_F3],
]

# "_sep" = spacer gap, "_graph" = frametime graph widget.
const LEFT_ORDER: Array = [
	"fps", "_graph", "_sep",
	"xyz", "chunk_pos", "facing", "velocity", "_sep",
	"block", "target_pos", "biome", "dimension", "_sep",
	"time", "held", "_sep",
	"light_level", "fly_state", "fov", "_sep",
	"tick_rate", "chunks_loaded", "world_seed",
]
const RIGHT_ORDER: Array = [
	"godot_ver", "_sep",
	"cpu", "cpu_cores", "cpu_freq", "gpu", "vram_used", "vram_tex", "_sep",
	"ram", "ram_alloc", "_sep",
	"os_name", "display", "renderer", "_sep",
	"draw_calls", "vertices",
]

const BLOCK_NAMES: Dictionary = {
	0: "Air", 1: "Stone", 2: "Cobblestone", 3: "Bricks", 4: "Dirt",
	5: "Oak Planks", 6: "Oak Log", 7: "Leaves", 8: "Glass", 9: "Sand",
	10: "Grass Block", 11: "Mossy Cobblestone", 12: "Bedrock",
	13: "Obsidian", 14: "Bookshelf", 15: "Sponge", 16: "TNT",
	17: "Iron Block", 18: "Gold Block", 19: "Coal Ore", 20: "Iron Ore",
	21: "Gold Ore", 22: "Diamond Ore", 23: "White Wool", 24: "Red Wool",
	25: "Yellow Wool", 26: "Green Wool", 27: "Blue Wool", 28: "Bedrock",
	29: "Water", 30: "Orange Wool", 31: "Magenta Wool", 32: "Light Blue Wool",
	33: "Lime Wool", 34: "Pink Wool", 35: "Gray Wool", 36: "Light Gray Wool",
	37: "Cyan Wool", 38: "Purple Wool", 39: "Brown Wool", 40: "Black Wool",
	41: "Fire", 42: "Lava", 43: "Smooth Stone", 44: "Smooth Stone Slab",
	45: "Barrier", 46: "Poppy", 47: "Dandelion", 48: "Torch",
	49: "Netherrack", 50: "Nether Gold Ore", 51: "Nether Quartz Ore",
	52: "Nether Portal", 53: "Crimson Nylium", 54: "Warped Nylium",
	55: "Crimson Stem", 56: "Warped Stem", 57: "Nether Wart Block",
	58: "Warped Wart Block", 59: "Red Mushroom", 60: "Brown Mushroom",
	61: "Crimson Fungus", 62: "Warped Fungus", 63: "Diamond Block",
}

# ── Runtime state ────────────────────────────────────────────────────────────
var frame_times: PackedFloat32Array
var write_idx: int = 0
var filled: bool = false
var _accum: float = 0.0
var _delta_last: float = 0.016

var _main: Node = null
var _player: Node = null
var _world: Node = null
var _font: Font = null

var _lf: Dictionary = {}        # F3 panel labels  (key → Label)
var _la: Dictionary = {}        # always panel labels (key → Label)
var _cfg_btns: Dictionary = {}  # config mode buttons (key → Button)

var _f3_root: Control = null
var _always_root: Control = null
var _cfg_overlay: Control = null
var _graph: Control = null

var _f3_visible: bool = false
var _cfg_visible: bool = false
var _f3_down: bool = false
var _f3_combo_used: bool = false

var _modes: Dictionary = {}   # key → MODE_*
var _sys: Dictionary = {}     # cached static system strings
var _crosshair_was_visible: bool = true
var _cfg_row_idx: int = 0     # alternating row counter, reset per column


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	frame_times.resize(HISTORY_SIZE)
	frame_times.fill(0.0)
	_font = load("res://fonts/font.ttf")
	_main = get_parent()
	_player = _main.get_node_or_null("Player")
	_world  = _main.get_node_or_null("World")
	_load_modes()
	_gather_sys_info()
	_build_f3_ui()
	_build_always_ui()
	_build_config_ui()
	_refresh_visibility()


# ── UI builders ──────────────────────────────────────────────────────────────

func _build_f3_ui() -> void:
	_f3_root = Control.new()
	_f3_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_f3_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_f3_root.visible = false
	add_child(_f3_root)

	# ── Left panel ──
	var lp := _make_panel()
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.anchor_left = 0.0;  lp.anchor_top = 0.0
	lp.anchor_right = 0.0; lp.anchor_bottom = 0.0
	lp.grow_horizontal = Control.GROW_DIRECTION_END
	lp.grow_vertical   = Control.GROW_DIRECTION_END
	lp.offset_left = 4.0;  lp.offset_top = 4.0
	_f3_root.add_child(lp)

	var lv := VBoxContainer.new()
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_theme_constant_override("separation", 2)
	lp.add_child(lv)

	var ver_lbl := _make_label("Recraft 1.0.0 Alpha")
	ver_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	lv.add_child(ver_lbl)

	for entry: String in LEFT_ORDER:
		if entry == "_sep":
			lv.add_child(_sep_node())
		elif entry == "_graph":
			_graph = load("res://frametime_graph.gd").new()
			_graph.custom_minimum_size = Vector2(300, 42)
			lv.add_child(_graph)
		else:
			_lf[entry] = _make_label("...")
			lv.add_child(_lf[entry])

	# ── Right panel ──
	var rp := _make_panel()
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp.anchor_left = 1.0;  rp.anchor_top = 0.0
	rp.anchor_right = 1.0; rp.anchor_bottom = 0.0
	rp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rp.grow_vertical   = Control.GROW_DIRECTION_END
	rp.offset_right = -4.0; rp.offset_top = 4.0
	_f3_root.add_child(rp)

	var rv := VBoxContainer.new()
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_theme_constant_override("separation", 2)
	rp.add_child(rv)

	for entry: String in RIGHT_ORDER:
		if entry == "_sep":
			rv.add_child(_sep_node())
		else:
			_lf[entry] = _make_label("...")
			rv.add_child(_lf[entry])


func _build_always_ui() -> void:
	_always_root = _make_panel()
	_always_root.anchor_left = 0.0;  _always_root.anchor_top = 0.0
	_always_root.anchor_right = 0.0; _always_root.anchor_bottom = 0.0
	_always_root.grow_horizontal = Control.GROW_DIRECTION_END
	_always_root.grow_vertical   = Control.GROW_DIRECTION_END
	_always_root.offset_left = 4.0;  _always_root.offset_top = 4.0
	_always_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_always_root.visible = false
	add_child(_always_root)

	var av := VBoxContainer.new()
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.add_theme_constant_override("separation", 2)
	_always_root.add_child(av)

	for def in ITEM_DEFS:
		var key: String = def[0]
		_la[key] = _make_label("...")
		_la[key].visible = false
		av.add_child(_la[key])


func _build_config_ui() -> void:
	_cfg_overlay = Control.new()
	_cfg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cfg_overlay.visible = false
	add_child(_cfg_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_cfg_overlay.add_child(bg)

	# Panel — same style as pause menu.
	var outer := PanelContainer.new()
	var osb := StyleBoxFlat.new()
	osb.bg_color    = Color(0.12, 0.12, 0.14, 0.95)
	osb.border_color = Color(0.6, 0.6, 0.6, 1.0)
	osb.set_border_width_all(1)
	osb.set_content_margin_all(20)
	outer.add_theme_stylebox_override("panel", osb)
	outer.anchor_left = 0.0; outer.anchor_right  = 1.0
	outer.anchor_top  = 0.0; outer.anchor_bottom = 1.0
	outer.offset_left = 40; outer.offset_right  = -40
	outer.offset_top  = 40; outer.offset_bottom = -85
	_cfg_overlay.add_child(outer)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	outer.add_child(root_vbox)

	# Title
	var title := _make_label("Debug Screen Options")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	var sep0 := HSeparator.new()
	root_vbox.add_child(sep0)

	# Instruction line
	var sub := _make_label("Click a button to cycle:   Always (HUD)  →  F3 screen  →  Never")
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(sub)

	var sep1 := HSeparator.new()
	root_vbox.add_child(sep1)

	# Two-column item list — scrollable, fills available height.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	root_vbox.add_child(scroll)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(cols)

	_cfg_row_idx = 0
	var lcol := _make_cfg_column(cols, "LEFT PANEL")
	for def in ITEM_DEFS:
		if def[2] == 0:
			_add_cfg_row(lcol, def[0], def[1])

	var vdiv := VSeparator.new()
	cols.add_child(vdiv)

	_cfg_row_idx = 0
	var rcol := _make_cfg_column(cols, "RIGHT PANEL")
	for def in ITEM_DEFS:
		if def[2] == 1:
			_add_cfg_row(rcol, def[0], def[1])

	var sep2 := HSeparator.new()
	root_vbox.add_child(sep2)

	var footer := _make_label("F3 + F6   or   Esc   to close")
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(footer)


func _make_cfg_column(parent: HBoxContainer, header_text: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(col)

	var hdr := _make_label(header_text)
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	col.add_child(hdr)

	var rule := HSeparator.new()
	col.add_child(rule)

	return col


func _add_cfg_row(parent: VBoxContainer, key: String, name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(82, 24)
	btn.flat = false
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color",         Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color",   Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85))
	btn.pressed.connect(_on_mode_btn.bind(key))
	_cfg_btns[key] = btn
	row.add_child(btn)

	var lbl := _make_label(name)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)


# ── UI helpers ───────────────────────────────────────────────────────────────

func _make_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.46)
	sb.set_content_margin_all(PAD)
	pc.add_theme_stylebox_override("panel", sb)
	return pc


func _make_label(t: String) -> Label:
	var lbl := Label.new()
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.text = t
	return lbl


func _sep_node() -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	return sp


# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or (event as InputEventKey).is_echo():
		return
	var kc: int = (event as InputEventKey).keycode
	var pressed: bool = (event as InputEventKey).pressed

	if kc == KEY_F3:
		if pressed:
			_f3_down = true
			_f3_combo_used = false
		else:
			_f3_down = false
			if not _f3_combo_used:
				_toggle_f3()
		get_viewport().set_input_as_handled()
		return

	if kc == KEY_F6 and _f3_down and pressed:
		_f3_combo_used = true
		_toggle_config()
		get_viewport().set_input_as_handled()
		return

	if kc == KEY_ESCAPE and _cfg_visible and pressed:
		_toggle_config()
		get_viewport().set_input_as_handled()


func _toggle_f3() -> void:
	_f3_visible = not _f3_visible
	_f3_root.visible = _f3_visible
	_always_root.visible = _has_always_items() and not _f3_visible


func _toggle_config() -> void:
	# Don't open on top of the pause menu's own pause.
	if not _cfg_visible and get_tree().paused:
		return
	_cfg_visible = not _cfg_visible
	_cfg_overlay.visible = _cfg_visible

	var hud_node: Node = _main.get_node_or_null("HUD") if _main != null else null
	var crosshair: Node = hud_node.get_node_or_null("Crosshair") if hud_node != null else null

	if _cfg_visible:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_f3_root.visible = false
		_always_root.visible = false
		if crosshair != null:
			_crosshair_was_visible = crosshair.visible
			crosshair.visible = false
	else:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_f3_root.visible = _f3_visible
		_always_root.visible = _has_always_items() and not _f3_visible
		if crosshair != null:
			crosshair.visible = _crosshair_was_visible


func _has_always_items() -> bool:
	for def in ITEM_DEFS:
		if _modes.get(def[0], def[3]) == MODE_ALWAYS:
			return true
	return false


func _on_mode_btn(key: String) -> void:
	_modes[key] = (_modes.get(key, MODE_F3) + 1) % 3
	_save_modes()
	_refresh_visibility()


# ── Visibility sync ──────────────────────────────────────────────────────────

func _refresh_visibility() -> void:
	var any_always: bool = false
	for def in ITEM_DEFS:
		var key: String = def[0]
		var mode: int = _modes.get(key, def[3])
		var in_f3: bool = (mode != MODE_NEVER)
		var in_always: bool = (mode == MODE_ALWAYS)
		if in_always:
			any_always = true
		if key in _lf:
			_lf[key].visible = in_f3
		if key in _la:
			_la[key].visible = in_always
		if key in _cfg_btns:
			_update_btn_style(_cfg_btns[key], mode)

	_always_root.visible = any_always and not _f3_visible and not _cfg_visible


func _update_btn_style(btn: Button, mode: int) -> void:
	const LABELS: PackedStringArray = ["Always", "F3", "Never"]
	btn.text = LABELS[mode]
	# Flat solid-color backgrounds — no texture, no gradient.
	# Brightness encodes the mode: Always lightest (most "on"), Never darkest.
	var bg: Color
	match mode:
		MODE_ALWAYS: bg = Color(0.30, 0.30, 0.30)
		MODE_F3:     bg = Color(0.20, 0.20, 0.20)
		_:           bg = Color(0.12, 0.12, 0.12)
	var border := Color(0.55, 0.55, 0.55)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = bg; sb_n.border_color = border
	sb_n.set_border_width_all(1); sb_n.set_content_margin_all(4)
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = bg.lightened(0.12); sb_h.border_color = Color(0.75, 0.75, 0.75)
	sb_h.set_border_width_all(1); sb_h.set_content_margin_all(4)
	var sb_p := StyleBoxFlat.new()
	sb_p.bg_color = bg.darkened(0.1); sb_p.border_color = border
	sb_p.set_border_width_all(1); sb_p.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal",  sb_n)
	btn.add_theme_stylebox_override("hover",   sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus",   sb_h)


# ── Frame loop ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	frame_times[write_idx] = delta * 1000.0
	write_idx = (write_idx + 1) % HISTORY_SIZE
	if write_idx == 0:
		filled = true

	if not _f3_visible and not _has_always_items():
		return

	_accum += delta
	if _accum < REDRAW_INTERVAL:
		return
	_accum = 0.0
	_delta_last = delta

	_update_labels()
	if _graph != null:
		_graph.queue_redraw()


# ── Label data population ────────────────────────────────────────────────────

func _put(key: String, value: String) -> void:
	if key in _lf:
		_lf[key].text = value
	if key in _la and _la[key].visible:
		_la[key].text = value


func _update_labels() -> void:
	# ── FPS ──────────────────────────────────────────────────────────
	var fps: int = int(Engine.get_frames_per_second())
	var low: int = _compute_1pct_low()
	var fps_col: Color
	if fps >= 60:    fps_col = Color(0.3, 1.0, 0.3)
	elif fps >= 30:  fps_col = Color(1.0, 1.0, 0.3)
	else:            fps_col = Color(1.0, 0.4, 0.4)
	var fps_text: String = "%d FPS  •  %d 1%% low  •  %.1f ms" % [fps, low, _delta_last * 1000.0]
	_put("fps", fps_text)
	if "fps" in _lf: _lf["fps"].add_theme_color_override("font_color", fps_col)
	if "fps" in _la: _la["fps"].add_theme_color_override("font_color", fps_col)

	# ── Player-based data ─────────────────────────────────────────────
	if _player != null:
		var pos: Vector3 = _player.global_position
		_put("xyz", "XYZ:  %.2f  /  %.2f  /  %.2f" % [pos.x, pos.y, pos.z])

		var cx: int = int(floor(pos.x / 16.0))
		var cy: int = int(floor(pos.y / 16.0))
		var cz: int = int(floor(pos.z / 16.0))
		var lx: int = int(floor(pos.x)) & 15
		var ly: int = int(floor(pos.y)) & 15
		var lz: int = int(floor(pos.z)) & 15
		_put("chunk_pos", "Chunk:  %d  %d  %d  in  %d  %d  %d" % [lx, ly, lz, cx, cy, cz])

		var head: Node3D = _player.get_node_or_null("Head")
		if head != null:
			var yaw_deg: float = fmod(rad_to_deg(head.rotation.y) + 360.0, 360.0)
			const DIRS: PackedStringArray = ["N", "NW", "W", "SW", "S", "SE", "E", "NE"]
			var dir: String = DIRS[int((yaw_deg + 22.5) / 45.0) % 8]
			var pitch_deg: float = rad_to_deg(head.rotation.x)
			_put("facing", "Facing:  %s  (%.1f°  pitch %.1f°)" % [dir, yaw_deg, pitch_deg])

		var vel: Vector3 = _player.velocity
		var spd_h: float = Vector2(vel.x, vel.z).length()
		_put("velocity", "Velocity:  %.2f m/s  (H: %.2f  V: %.2f)" % [vel.length(), spd_h, abs(vel.y)])

		var cam: Camera3D = _player.get_node_or_null("Head/Camera3D")
		if cam != null and _world != null:
			var hit: Dictionary = _world.raycast_voxel(cam.global_position, -cam.global_basis.z)
			if hit.get("hit", false):
				var bid: int = hit.get("block", 0)
				var hp: Vector3i = hit.get("position", Vector3i.ZERO)
				_put("block",      "Block:  " + BLOCK_NAMES.get(bid, "Unknown (%d)" % bid))
				_put("target_pos", "Target:  %d  %d  %d" % [hp.x, hp.y, hp.z])
			else:
				_put("block",      "Block:  —")
				_put("target_pos", "Target:  —")

		# Biome
		var bx: int = int(floor(pos.x))
		var bz: int = int(floor(pos.z))
		if _world != null and _main != null:
			if _main._current_dimension == 0:
				var bid: int = _world.get_biome(bx, bz)
				_put("biome", "Biome:  " + (["Plains", "Beach"][bid] if bid < 2 else "Unknown"))
			else:
				var bid: int = _world.get_nether_biome(bx, bz)
				_put("biome", "Biome:  " + (["Nether Wastes", "Crimson Forest", "Warped Forest"][bid] if bid < 3 else "Unknown"))

		# FOV
		if cam != null:
			_put("fov", "FOV:  %.0f°" % cam.fov)

		# Light level — sky from day cycle + block from nearby emitters
		var sky_lv: int = 0
		if _main != null:
			var brightness: float = max(0.0, sin(_main._day_time * TAU))
			sky_lv = int(brightness * 15.0)
		var blk_lv: int = 0
		if _world != null and "light_emitters" in _world:
			for ep: Vector3i in _world.light_emitters:
				var lvl: int = _world.light_emitters[ep]
				var dist: float = pos.distance_to(Vector3(ep))
				var att: float = max(0.0, 1.0 - dist / float(max(1, lvl)))
				blk_lv = max(blk_lv, int(att * 15.0))
		_put("light_level", "Light:  Sky %d  Block %d" % [sky_lv, blk_lv])

		# Player state
		var state: String
		if _player.is_flying:
			state = "Flying"
		elif not _player.is_on_floor():
			state = "In Air"
		elif _player.is_sprinting:
			state = "Sprinting"
		elif Input.is_action_pressed("crouch"):
			state = "Crouching"
		else:
			state = "Walking"
		_put("fly_state", "State:  " + state)

	# ── Dimension ─────────────────────────────────────────────────────
	if _main != null:
		_put("dimension", "Dimension:  " + ("The Nether" if _main._current_dimension == 1 else "Overworld"))

		# Time of day
		var t: float = _main._day_time
		var ticks: int = int(t * 24000.0) % 24000
		var real_min: int = int(fmod(t * 1440.0 + 360.0, 1440.0))
		var phase: String
		if   ticks < 1500:  phase = "Dawn"
		elif ticks < 6000:  phase = "Morning"
		elif ticks < 12000: phase = "Day"
		elif ticks < 13800: phase = "Dusk"
		elif ticks < 22200: phase = "Night"
		else:               phase = "Dawn"
		_put("time", "Time:  %d  (%s)  [%02d:%02d]" % [ticks, phase, real_min / 60, real_min % 60])

		_put("tick_rate", "Tick Rate:  %.0f" % _main.tick_rate)

	# ── World data ────────────────────────────────────────────────────
	if _world != null:
		if "chunks" in _world:
			_put("chunks_loaded", "Chunks Loaded:  %d" % _world.chunks.size())
		if "world_seed" in _world:
			_put("world_seed", "World Seed:  %d" % _world.world_seed)

	# ── Held block ────────────────────────────────────────────────────
	var hud_node: Node = _main.get_node_or_null("HUD") if _main != null else null
	if hud_node != null and "slots" in hud_node and "selected_slot" in hud_node:
		var bid: int = hud_node.slots[hud_node.selected_slot]
		_put("held", "Held:  " + BLOCK_NAMES.get(bid, "Unknown"))

	# ── Static system info ────────────────────────────────────────────
	for key: String in ["godot_ver", "cpu", "cpu_cores", "cpu_freq", "gpu", "os_name", "renderer"]:
		if key in _sys:
			_put(key, _sys[key])

	# ── Dynamic system info ───────────────────────────────────────────
	var vram_bytes: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var vtex_bytes: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	_put("vram_used", "VRAM Used:  %.1f MB" % (vram_bytes / 1048576.0))
	_put("vram_tex",  "VRAM Textures:  %.1f MB" % (vtex_bytes / 1048576.0))

	var ram_mb: float  = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var ram_max_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0
	_put("ram",       "RAM Used:  %.1f MB" % ram_mb)
	_put("ram_alloc", "RAM Allocated:  %.1f MB" % ram_max_mb)

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_put("display", "Display:  %d × %d" % [int(vp_size.x), int(vp_size.y)])

	var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var vt: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	_put("draw_calls", "Draw Calls:  %d" % dc)
	_put("vertices",   "Triangles:  %s" % _fmt_large(vt))


# ── System info (gathered once at startup) ───────────────────────────────────

func _gather_sys_info() -> void:
	var vi: Dictionary = Engine.get_version_info()
	_sys["godot_ver"] = "Godot %d.%d.%d" % [vi.major, vi.minor, vi.patch]

	var cpu_name: String = OS.get_processor_name()
	_sys["cpu"]       = "CPU:  " + (cpu_name.substr(0, 44) + "…" if cpu_name.length() > 44 else cpu_name)
	_sys["cpu_cores"] = "CPU Cores:  %d logical" % OS.get_processor_count()
	_sys["cpu_freq"]  = "CPU Freq:  " + _get_cpu_freq()

	var gpu_name: String = RenderingServer.get_video_adapter_name()
	_sys["gpu"]      = "GPU:  " + (gpu_name.substr(0, 44) + "…" if gpu_name.length() > 44 else gpu_name)
	_sys["os_name"]  = "OS:  " + OS.get_name()
	_sys["renderer"] = "Renderer:  Forward+"


func _get_cpu_freq() -> String:
	var name: String = OS.get_processor_name()
	var at: int = name.find("@")
	if at >= 0:
		return name.substr(at + 2).strip_edges()
	if OS.get_name() == "macOS":
		var out: Array = []
		if OS.execute("sysctl", ["-n", "hw.cpufrequency_max"], out) == 0 and out.size() > 0:
			var hz: int = int(out[0].strip_edges())
			if hz > 0:
				return "%.2f GHz" % (hz / 1_000_000_000.0)
		return "Performance cores"
	if OS.get_name() == "Linux":
		var f := FileAccess.open("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq", FileAccess.READ)
		if f != null:
			var khz: float = float(f.get_as_text().strip_edges())
			f.close()
			if khz > 0.0:
				return "%.2f GHz" % (khz / 1_000_000.0)
	if OS.get_name() == "Windows":
		var out: Array = []
		if OS.execute("cmd", ["/c", "wmic cpu get MaxClockSpeed /value"], out) == 0 and out.size() > 0:
			for line: String in out[0].split("\n"):
				if line.begins_with("MaxClockSpeed="):
					return "%.2f GHz" % (float(line.split("=")[1].strip_edges()) / 1000.0)
	return "N/A"


# ── Persistence ───────────────────────────────────────────────────────────────

func _save_modes() -> void:
	var cfg := ConfigFile.new()
	for key: String in _modes:
		cfg.set_value("modes", key, _modes[key])
	cfg.save(SAVE_PATH)


func _load_modes() -> void:
	for def in ITEM_DEFS:
		_modes[def[0]] = def[3]
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for key: String in _modes.keys():
			if cfg.has_section_key("modes", key):
				_modes[key] = cfg.get_value("modes", key, _modes[key])


# ── Utilities ────────────────────────────────────────────────────────────────

func _compute_1pct_low() -> int:
	var n: int = HISTORY_SIZE if filled else write_idx
	if n == 0:
		return 0
	var samples: PackedFloat32Array = frame_times.slice(0, n)
	samples.sort()
	var low_count: int = maxi(1, n / 100)
	var sum_ms: float = 0.0
	for i: int in range(n - low_count, n):
		sum_ms += samples[i]
	var avg_ms: float = sum_ms / float(low_count)
	return 0 if avg_ms <= 0.0 else int(1000.0 / avg_ms)


func _fmt_large(n: int) -> String:
	if n >= 1_000_000:
		return "%.1fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (n / 1_000.0)
	return str(n)
