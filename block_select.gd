extends Control
class_name BlockSelect

signal block_selected(block_type: int)
signal closed

const COLS: int = 9
const SLOT_SIZE: int = 56
const BLOCK_S: float = 18.0
const TITLE_H: int = 40
const TAB_H: int = 36
const SEARCH_H: int = 40
const NAME_H: int = 28
const PANEL_PAD: int = 18

# Category IDs — order matches the tab bar left-to-right.
enum Tab { SEARCH, MINERALS, ORES, NATURAL, COLORFUL }
const TAB_NAMES: Array[String] = ["Search", "Minerals", "Ores", "Natural", "Colorful"]

# Master list of every block available in the inventory. The Search tab
# shows this unfiltered; category tabs pull subsets via BLOCK_CATEGORIES.
const ALL_BLOCKS: Array[int] = [
	Chunk.Block.STONE, Chunk.Block.COBBLESTONE, Chunk.Block.SMOOTH_STONE,
	Chunk.Block.SMOOTH_STONE_SLAB, Chunk.Block.DIRT, Chunk.Block.GRASS,
	Chunk.Block.PLANKS, Chunk.Block.LOG, Chunk.Block.LEAVES, Chunk.Block.SAND,
	Chunk.Block.GLASS, Chunk.Block.WATER, Chunk.Block.LAVA,
	Chunk.Block.BRICK, Chunk.Block.MOSSY_COBBLESTONE, Chunk.Block.BEDROCK,
	Chunk.Block.OBSIDIAN, Chunk.Block.BOOKSHELF, Chunk.Block.SPONGE,
	Chunk.Block.TNT, Chunk.Block.FIRE, Chunk.Block.TORCH,
	Chunk.Block.NETHERRACK, Chunk.Block.NETHER_GOLD_ORE, Chunk.Block.NETHER_QUARTZ_ORE,
	Chunk.Block.CRIMSON_NYLIUM, Chunk.Block.WARPED_NYLIUM,
	Chunk.Block.CRIMSON_STEM, Chunk.Block.WARPED_STEM,
	Chunk.Block.NETHER_WART_BLOCK, Chunk.Block.WARPED_WART_BLOCK,
	Chunk.Block.RED_MUSHROOM, Chunk.Block.BROWN_MUSHROOM,
	Chunk.Block.CRIMSON_FUNGUS, Chunk.Block.WARPED_FUNGUS,
	Chunk.Block.POPPY, Chunk.Block.DANDELION, Chunk.Block.BARRIER,
	Chunk.Block.IRON_BLOCK, Chunk.Block.GOLD_BLOCK,
	Chunk.Block.COAL_ORE, Chunk.Block.IRON_ORE, Chunk.Block.GOLD_ORE, Chunk.Block.DIAMOND_ORE,
	Chunk.Block.WOOL_WHITE, Chunk.Block.WOOL_ORANGE, Chunk.Block.WOOL_MAGENTA,
	Chunk.Block.WOOL_LIGHT_BLUE, Chunk.Block.WOOL_YELLOW, Chunk.Block.WOOL_LIME,
	Chunk.Block.WOOL_PINK, Chunk.Block.WOOL_GRAY, Chunk.Block.WOOL_LIGHT_GRAY,
	Chunk.Block.WOOL_CYAN, Chunk.Block.WOOL_PURPLE, Chunk.Block.WOOL_BLUE,
	Chunk.Block.WOOL_BROWN, Chunk.Block.WOOL_GREEN, Chunk.Block.WOOL_RED,
	Chunk.Block.WOOL_BLACK,
]

# Minerals tab — stone family, metal blocks, glass, obsidian.
const MINERALS: Array[int] = [
	Chunk.Block.STONE, Chunk.Block.COBBLESTONE, Chunk.Block.SMOOTH_STONE,
	Chunk.Block.SMOOTH_STONE_SLAB, Chunk.Block.BRICK, Chunk.Block.MOSSY_COBBLESTONE,
	Chunk.Block.OBSIDIAN, Chunk.Block.BEDROCK, Chunk.Block.BARRIER,
	Chunk.Block.IRON_BLOCK, Chunk.Block.GOLD_BLOCK, Chunk.Block.GLASS,
]

# Ores tab — overworld + nether ores.
const ORES: Array[int] = [
	Chunk.Block.COAL_ORE, Chunk.Block.IRON_ORE, Chunk.Block.GOLD_ORE,
	Chunk.Block.DIAMOND_ORE, Chunk.Block.NETHER_GOLD_ORE, Chunk.Block.NETHER_QUARTZ_ORE,
]

# Natural tab — terrain, organic, living, fluids, foliage.
const NATURAL: Array[int] = [
	Chunk.Block.DIRT, Chunk.Block.GRASS, Chunk.Block.SAND,
	Chunk.Block.LOG, Chunk.Block.LEAVES, Chunk.Block.PLANKS,
	Chunk.Block.WATER, Chunk.Block.LAVA, Chunk.Block.FIRE,
	Chunk.Block.NETHERRACK, Chunk.Block.CRIMSON_NYLIUM, Chunk.Block.WARPED_NYLIUM,
	Chunk.Block.CRIMSON_STEM, Chunk.Block.WARPED_STEM,
	Chunk.Block.NETHER_WART_BLOCK, Chunk.Block.WARPED_WART_BLOCK,
	Chunk.Block.POPPY, Chunk.Block.DANDELION,
	Chunk.Block.RED_MUSHROOM, Chunk.Block.BROWN_MUSHROOM,
	Chunk.Block.CRIMSON_FUNGUS, Chunk.Block.WARPED_FUNGUS,
	Chunk.Block.TORCH, Chunk.Block.TNT, Chunk.Block.SPONGE, Chunk.Block.BOOKSHELF,
	# Ores are natural too — they spawn in the world.
	Chunk.Block.COAL_ORE, Chunk.Block.IRON_ORE, Chunk.Block.GOLD_ORE,
	Chunk.Block.DIAMOND_ORE, Chunk.Block.NETHER_GOLD_ORE, Chunk.Block.NETHER_QUARTZ_ORE,
]

# Colorful tab — anything distinctly colored.
const COLORFUL: Array[int] = [
	Chunk.Block.WOOL_WHITE, Chunk.Block.WOOL_ORANGE, Chunk.Block.WOOL_MAGENTA,
	Chunk.Block.WOOL_LIGHT_BLUE, Chunk.Block.WOOL_YELLOW, Chunk.Block.WOOL_LIME,
	Chunk.Block.WOOL_PINK, Chunk.Block.WOOL_GRAY, Chunk.Block.WOOL_LIGHT_GRAY,
	Chunk.Block.WOOL_CYAN, Chunk.Block.WOOL_PURPLE, Chunk.Block.WOOL_BLUE,
	Chunk.Block.WOOL_BROWN, Chunk.Block.WOOL_GREEN, Chunk.Block.WOOL_RED,
	Chunk.Block.WOOL_BLACK,
	Chunk.Block.BRICK,
	Chunk.Block.POPPY, Chunk.Block.DANDELION,
	Chunk.Block.IRON_BLOCK, Chunk.Block.GOLD_BLOCK, Chunk.Block.DIAMOND_ORE,
	Chunk.Block.NETHER_WART_BLOCK, Chunk.Block.WARPED_WART_BLOCK,
	Chunk.Block.CRIMSON_NYLIUM, Chunk.Block.WARPED_NYLIUM,
]

var _atlas: Texture2D = null
var _hovered: int = -1
var _current_tab: int = Tab.SEARCH
var _search_query: String = ""
var _visible_blocks: Array[int] = []  # current tab's filtered list

# Layout caches
var _panel_rect: Rect2
var _grid_origin: Vector2
var _slot_rects: Array[Rect2] = []
var _tab_rects: Array[Rect2] = []

# Search input — only visible on the Search tab.
var _search_edit: LineEdit = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_atlas = BlockTextures.create_icon_atlas()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	# Search input field.
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Type to search..."
	_search_edit.text_changed.connect(_on_search_changed)
	var font: Font = load("res://fonts/font.ttf")
	if font != null:
		_search_edit.add_theme_font_override("font", font)
	_search_edit.add_theme_font_size_override("font_size", PauseMenu._fs(22))
	_search_edit.add_theme_color_override("font_color", Color(1, 1, 1))
	_search_edit.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	_search_edit.add_theme_stylebox_override("normal", PauseMenu._make_stone_style(0.18, true))
	_search_edit.add_theme_stylebox_override("focus", PauseMenu._make_stone_style(0.22, true))
	_search_edit.visible = false
	add_child(_search_edit)
	get_viewport().size_changed.connect(_recalc_layout)
	_rebuild_visible_list()
	_recalc_layout()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hovered = -1
	_search_edit.text = ""
	_search_query = ""
	_rebuild_visible_list()
	_recalc_layout()
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_search_edit.release_focus()
	closed.emit()


func _set_tab(new_tab: int) -> void:
	if new_tab == _current_tab:
		return
	_current_tab = new_tab
	_search_query = ""
	_search_edit.text = ""
	_rebuild_visible_list()
	_recalc_layout()
	_hovered = -1
	queue_redraw()


func _on_search_changed(new_text: String) -> void:
	_search_query = new_text.to_lower().strip_edges()
	_rebuild_visible_list()
	_recalc_layout()
	_hovered = -1
	queue_redraw()


func _rebuild_visible_list() -> void:
	var source: Array[int]
	match _current_tab:
		Tab.MINERALS: source = MINERALS
		Tab.ORES: source = ORES
		Tab.NATURAL: source = NATURAL
		Tab.COLORFUL: source = COLORFUL
		_: source = ALL_BLOCKS
	if _search_query.is_empty():
		_visible_blocks = source.duplicate()
		return
	_visible_blocks = []
	for b: int in source:
		var name: String = BlockIcon.get_block_name(b).to_lower()
		if _search_query in name:
			_visible_blocks.append(b)


func _recalc_layout() -> void:
	var count: int = _visible_blocks.size()
	var rows: int = maxi(1, int(ceil(float(count) / float(COLS))))
	var grid_w: int = COLS * SLOT_SIZE
	var grid_h: int = rows * SLOT_SIZE
	var show_search: bool = _current_tab == Tab.SEARCH
	var search_area: int = SEARCH_H if show_search else 0
	var panel_w: int = grid_w + PANEL_PAD * 2
	var panel_h: int = TITLE_H + TAB_H + search_area + grid_h + NAME_H + PANEL_PAD * 2
	var vp: Vector2 = get_viewport_rect().size
	var px: float = floor((vp.x - panel_w) * 0.5)
	var py: float = floor((vp.y - panel_h) * 0.5)
	_panel_rect = Rect2(px, py, panel_w, panel_h)

	# Tab button rects — evenly spaced across the tab row.
	var tab_y: float = py + TITLE_H
	var tab_w: float = float(panel_w - PANEL_PAD * 2) / float(TAB_NAMES.size())
	_tab_rects.clear()
	for i: int in TAB_NAMES.size():
		_tab_rects.append(Rect2(px + PANEL_PAD + i * tab_w, tab_y, tab_w, TAB_H))

	# Search input rect.
	if show_search:
		_search_edit.visible = true
		_search_edit.position = Vector2(px + PANEL_PAD, tab_y + TAB_H)
		_search_edit.size = Vector2(panel_w - PANEL_PAD * 2, SEARCH_H - 4)
	else:
		_search_edit.visible = false

	_grid_origin = Vector2(px + PANEL_PAD, tab_y + TAB_H + search_area + PANEL_PAD)

	_slot_rects.clear()
	_slot_rects.resize(count)
	for i: int in count:
		var col: int = i % COLS
		var row: int = i / COLS
		_slot_rects[i] = Rect2(
			_grid_origin.x + col * SLOT_SIZE,
			_grid_origin.y + row * SLOT_SIZE,
			SLOT_SIZE, SLOT_SIZE)


func _draw() -> void:
	if _atlas == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(_panel_rect.position - Vector2(3, 3), _panel_rect.size + Vector2(6, 6)), Color(0.05, 0.05, 0.06, 1.0))
	_draw_stone_bg(_panel_rect, Color(0.42, 0.42, 0.42, 0.98))
	var pr := _panel_rect
	draw_rect(Rect2(pr.position.x, pr.position.y, pr.size.x, 2), Color(0.72, 0.72, 0.70))
	draw_rect(Rect2(pr.position.x, pr.position.y, 2, pr.size.y), Color(0.72, 0.72, 0.70))
	draw_rect(Rect2(pr.position.x, pr.position.y + pr.size.y - 2, pr.size.x, 2), Color(0.15, 0.15, 0.16))
	draw_rect(Rect2(pr.position.x + pr.size.x - 2, pr.position.y, 2, pr.size.y), Color(0.15, 0.15, 0.16))

	var font: Font = ThemeDB.fallback_font
	var title: String = "Blocks"
	var title_fs: int = PauseMenu._fs(32)
	var title_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs)
	var title_x: float = pr.position.x + (pr.size.x - title_size.x) * 0.5
	var title_y: float = pr.position.y + title_fs + 2
	draw_string(font, Vector2(title_x + 2, title_y + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(title_x, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, Color(1, 1, 1, 1.0))

	# Tab bar.
	var tab_fs: int = PauseMenu._fs(20)
	for i: int in _tab_rects.size():
		var tr: Rect2 = _tab_rects[i]
		var active: bool = i == _current_tab
		var bg := Color(0.22, 0.22, 0.25, 0.95) if active else Color(0.12, 0.12, 0.14, 0.85)
		draw_rect(tr, bg)
		# Top-right highlight for active tab.
		var border_col := Color(1, 1, 0.5) if active else Color(0.45, 0.45, 0.47)
		draw_rect(Rect2(tr.position.x, tr.position.y, tr.size.x, 2), border_col)
		draw_rect(Rect2(tr.position.x, tr.position.y, 2, tr.size.y), border_col)
		draw_rect(Rect2(tr.position.x + tr.size.x - 2, tr.position.y, 2, tr.size.y), border_col)
		# Label.
		var text: String = TAB_NAMES[i]
		var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs)
		var tx: float = tr.position.x + (tr.size.x - ts.x) * 0.5
		var ty: float = tr.position.y + (tr.size.y + ts.y) * 0.5 - 4
		var col: Color = Color(1, 1, 1) if active else Color(0.75, 0.75, 0.75)
		draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs, col)

	# Slots.
	for i: int in _visible_blocks.size():
		var rect: Rect2 = _slot_rects[i]
		var bg := Color(0.08, 0.08, 0.10, 0.85)
		if i == _hovered:
			bg = Color(0.30, 0.30, 0.35, 0.95)
		draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, rect.size.y - 4), bg)
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5 - BLOCK_S * BlockIcon.CUBE_H * 0.5
		BlockIcon.draw_iso(self, _atlas, cx, cy, BLOCK_S, _visible_blocks[i])
		if i == _hovered:
			var o := rect
			draw_rect(Rect2(o.position.x, o.position.y, o.size.x, 2), Color(1, 1, 1, 1))
			draw_rect(Rect2(o.position.x, o.position.y + o.size.y - 2, o.size.x, 2), Color(1, 1, 1, 1))
			draw_rect(Rect2(o.position.x, o.position.y, 2, o.size.y), Color(1, 1, 1, 1))
			draw_rect(Rect2(o.position.x + o.size.x - 2, o.position.y, 2, o.size.y), Color(1, 1, 1, 1))

	# Name of hovered block (or empty-state hint).
	var name_str: String
	if _hovered >= 0 and _hovered < _visible_blocks.size():
		name_str = BlockIcon.get_block_name(_visible_blocks[_hovered])
	elif _visible_blocks.is_empty():
		name_str = "No blocks match" if not _search_query.is_empty() else ""
	else:
		name_str = "Hover to see block name"
	var name_fs: int = PauseMenu._fs(22)
	var name_size: Vector2 = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs)
	var nx: float = pr.position.x + (pr.size.x - name_size.x) * 0.5
	var ny: float = pr.position.y + pr.size.y - name_fs + 2
	var name_color: Color = Color(0.95, 0.95, 0.95) if _hovered >= 0 else Color(0.55, 0.55, 0.55)
	draw_string(font, Vector2(nx, ny), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs, name_color)


func _draw_stone_bg(rect: Rect2, tint: Color) -> void:
	if _atlas == null:
		draw_rect(rect, tint)
		return
	var tile_px: int = 16
	var tiles_x: int = int(ceil(rect.size.x / float(tile_px)))
	var tiles_y: int = int(ceil(rect.size.y / float(tile_px)))
	for ty: int in tiles_y:
		for tx: int in tiles_x:
			var dx: float = rect.position.x + tx * tile_px
			var dy: float = rect.position.y + ty * tile_px
			var w: float = minf(float(tile_px), rect.position.x + rect.size.x - dx)
			var h: float = minf(float(tile_px), rect.position.y + rect.size.y - dy)
			if w <= 0 or h <= 0:
				continue
			draw_texture_rect_region(_atlas, Rect2(dx, dy, w, h), Rect2(Vector2(0, 0), Vector2(w, h)), tint)


func _hit_test_slot(pos: Vector2) -> int:
	for i: int in _slot_rects.size():
		if _slot_rects[i].has_point(pos):
			return i
	return -1


func _hit_test_tab(pos: Vector2) -> int:
	for i: int in _tab_rects.size():
		if _tab_rects[i].has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hover: int = _hit_test_slot(event.position)
		if new_hover != _hovered:
			_hovered = new_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tab_idx: int = _hit_test_tab(event.position)
		if tab_idx >= 0:
			_set_tab(tab_idx)
			return
		var idx: int = _hit_test_slot(event.position)
		if idx >= 0 and idx < _visible_blocks.size():
			block_selected.emit(_visible_blocks[idx])
			close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or (event.keycode == KEY_E and not _search_edit.has_focus()):
			close()
			get_viewport().set_input_as_handled()
