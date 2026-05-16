extends Control
class_name BlockSelect

signal block_selected(block_type: int)
signal closed

const COLS: int = 9
const SLOT_SIZE: int = 56
const BLOCK_S: float = 18.0
const ITEM_ICON_S: float = 22.0
const VISIBLE_ROWS: int = 4      # fixed grid height; extra content scrolls
const SCROLLBAR_W: int = 12
const TITLE_H: int = 40
const TAB_H: int = 36
const SEARCH_H: int = 40
const NAME_H: int = 28
const PANEL_PAD: int = 18

enum Tab { SEARCH, MINERALS, ORES, NATURAL, COLORFUL, TOOLS }
const TAB_NAMES: Array[String] = ["Search", "Minerals", "Ores", "Natural", "Colorful", "Gear"]

const ALL_BLOCKS: Array[int] = [
	Chunk.Block.STONE, Chunk.Block.COBBLESTONE, Chunk.Block.SMOOTH_STONE,
	Chunk.Block.SMOOTH_STONE_SLAB, Chunk.Block.DIRT, Chunk.Block.GRASS,
	Chunk.Block.PLANKS, Chunk.Block.LOG, Chunk.Block.LEAVES, Chunk.Block.SAND,
	Chunk.Block.GLASS, Chunk.Block.WATER, Chunk.Block.LAVA,
	Chunk.Block.BRICK, Chunk.Block.MOSSY_COBBLESTONE, Chunk.Block.BEDROCK,
	Chunk.Block.OBSIDIAN, Chunk.Block.BOOKSHELF, Chunk.Block.SPONGE,
	Chunk.Block.TNT, Chunk.Block.FIRE, Chunk.Block.TORCH,
	Chunk.Block.CRAFTING_TABLE, Chunk.Block.FURNACE, Chunk.Block.COAL_BLOCK,
	Chunk.Block.NETHERRACK, Chunk.Block.NETHER_GOLD_ORE, Chunk.Block.NETHER_QUARTZ_ORE,
	Chunk.Block.CRIMSON_NYLIUM, Chunk.Block.WARPED_NYLIUM,
	Chunk.Block.CRIMSON_STEM, Chunk.Block.WARPED_STEM,
	Chunk.Block.NETHER_WART_BLOCK, Chunk.Block.WARPED_WART_BLOCK,
	Chunk.Block.RED_MUSHROOM, Chunk.Block.BROWN_MUSHROOM,
	Chunk.Block.CRIMSON_FUNGUS, Chunk.Block.WARPED_FUNGUS,
	Chunk.Block.POPPY, Chunk.Block.DANDELION, Chunk.Block.BARRIER,
	Chunk.Block.IRON_BLOCK, Chunk.Block.GOLD_BLOCK, Chunk.Block.DIAMOND_BLOCK,
	Chunk.Block.COAL_ORE, Chunk.Block.IRON_ORE, Chunk.Block.GOLD_ORE, Chunk.Block.DIAMOND_ORE,
	Chunk.Block.WOOL_WHITE, Chunk.Block.WOOL_ORANGE, Chunk.Block.WOOL_MAGENTA,
	Chunk.Block.WOOL_LIGHT_BLUE, Chunk.Block.WOOL_YELLOW, Chunk.Block.WOOL_LIME,
	Chunk.Block.WOOL_PINK, Chunk.Block.WOOL_GRAY, Chunk.Block.WOOL_LIGHT_GRAY,
	Chunk.Block.WOOL_CYAN, Chunk.Block.WOOL_PURPLE, Chunk.Block.WOOL_BLUE,
	Chunk.Block.WOOL_BROWN, Chunk.Block.WOOL_GREEN, Chunk.Block.WOOL_RED,
	Chunk.Block.WOOL_BLACK,
	Items.COAL, Items.RAW_IRON, Items.RAW_GOLD, Items.DIAMOND,
	Items.IRON_INGOT, Items.GOLD_INGOT, Items.QUARTZ,
	Items.STICK, Items.FLINT, Items.LEATHER, Items.APPLE, Items.BREAD,
	Items.WOOD_SWORD, Items.WOOD_PICKAXE, Items.WOOD_AXE, Items.WOOD_SHOVEL, Items.WOOD_HOE,
	Items.STONE_SWORD, Items.STONE_PICKAXE, Items.STONE_AXE, Items.STONE_SHOVEL, Items.STONE_HOE,
	Items.IRON_SWORD, Items.IRON_PICKAXE, Items.IRON_AXE, Items.IRON_SHOVEL, Items.IRON_HOE,
	Items.GOLD_SWORD, Items.GOLD_PICKAXE, Items.GOLD_AXE, Items.GOLD_SHOVEL, Items.GOLD_HOE,
	Items.DIAMOND_SWORD, Items.DIAMOND_PICKAXE, Items.DIAMOND_AXE, Items.DIAMOND_SHOVEL, Items.DIAMOND_HOE,
	Items.IRON_HELMET, Items.IRON_CHESTPLATE, Items.IRON_LEGGINGS, Items.IRON_BOOTS,
	Items.GOLD_HELMET, Items.GOLD_CHESTPLATE, Items.GOLD_LEGGINGS, Items.GOLD_BOOTS,
	Items.DIAMOND_HELMET, Items.DIAMOND_CHESTPLATE, Items.DIAMOND_LEGGINGS, Items.DIAMOND_BOOTS,
	Items.RESTORE_ORB,
]

const MINERALS: Array[int] = [
	Chunk.Block.STONE, Chunk.Block.COBBLESTONE, Chunk.Block.SMOOTH_STONE,
	Chunk.Block.SMOOTH_STONE_SLAB, Chunk.Block.BRICK, Chunk.Block.MOSSY_COBBLESTONE,
	Chunk.Block.OBSIDIAN, Chunk.Block.BEDROCK, Chunk.Block.BARRIER,
	Chunk.Block.IRON_BLOCK, Chunk.Block.GOLD_BLOCK, Chunk.Block.DIAMOND_BLOCK,
	Chunk.Block.GLASS,
	Chunk.Block.CRAFTING_TABLE, Chunk.Block.FURNACE, Chunk.Block.COAL_BLOCK,
	Items.COAL, Items.RAW_IRON, Items.RAW_GOLD, Items.DIAMOND,
	Items.IRON_INGOT, Items.GOLD_INGOT, Items.QUARTZ,
	Items.RESTORE_ORB,
]

const ORES: Array[int] = [
	Chunk.Block.COAL_ORE, Chunk.Block.IRON_ORE, Chunk.Block.GOLD_ORE,
	Chunk.Block.DIAMOND_ORE, Chunk.Block.NETHER_GOLD_ORE, Chunk.Block.NETHER_QUARTZ_ORE,
]

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
	Chunk.Block.COAL_ORE, Chunk.Block.IRON_ORE, Chunk.Block.GOLD_ORE,
	Chunk.Block.DIAMOND_ORE, Chunk.Block.NETHER_GOLD_ORE, Chunk.Block.NETHER_QUARTZ_ORE,
	Items.STICK, Items.FLINT, Items.LEATHER, Items.APPLE, Items.BREAD,
]

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

const TOOLS_ITEMS: Array[int] = [
	Items.WOOD_SWORD, Items.WOOD_PICKAXE, Items.WOOD_AXE, Items.WOOD_SHOVEL, Items.WOOD_HOE,
	Items.STONE_SWORD, Items.STONE_PICKAXE, Items.STONE_AXE, Items.STONE_SHOVEL, Items.STONE_HOE,
	Items.IRON_SWORD, Items.IRON_PICKAXE, Items.IRON_AXE, Items.IRON_SHOVEL, Items.IRON_HOE,
	Items.GOLD_SWORD, Items.GOLD_PICKAXE, Items.GOLD_AXE, Items.GOLD_SHOVEL, Items.GOLD_HOE,
	Items.DIAMOND_SWORD, Items.DIAMOND_PICKAXE, Items.DIAMOND_AXE, Items.DIAMOND_SHOVEL, Items.DIAMOND_HOE,
	Items.IRON_HELMET, Items.IRON_CHESTPLATE, Items.IRON_LEGGINGS, Items.IRON_BOOTS,
	Items.GOLD_HELMET, Items.GOLD_CHESTPLATE, Items.GOLD_LEGGINGS, Items.GOLD_BOOTS,
	Items.DIAMOND_HELMET, Items.DIAMOND_CHESTPLATE, Items.DIAMOND_LEGGINGS, Items.DIAMOND_BOOTS,
]

var _atlas: Texture2D = null
var _hovered: int = -1        # actual index into _visible_blocks
var _scroll_row: int = 0
var _current_tab: int = Tab.SEARCH
var _search_query: String = ""
var _visible_blocks: Array[int] = []

var _panel_rect: Rect2
var _grid_rect: Rect2
var _grid_origin: Vector2
var _slot_rects: Array[Rect2] = []
var _tab_rects: Array[Rect2] = []

var _search_edit: LineEdit = null
var _scroll_container: ScrollContainer = null
var _scroll_content: Control = null
var _sb_updating: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_atlas = BlockTextures.create_icon_atlas()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
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
	# ScrollContainer covers the grid + scrollbar area.
	# - Handles wheel natively (C++) without intercepting left-clicks on slots.
	# - MOUSE_FILTER_PASS lets left-clicks fall through to BlockSelect._gui_input.
	_scroll_container = ScrollContainer.new()
	_scroll_container.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll_container.follow_focus = false
	var sb := _scroll_container.get_v_scroll_bar()
	sb.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	sb.custom_minimum_size.x = SCROLLBAR_W
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	sb.add_theme_stylebox_override("scroll", sb_track)
	sb.add_theme_stylebox_override("scroll_focus", sb_track)
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color(0.65, 0.65, 0.70, 1.0)
	sb_grab.set_corner_radius_all(2)
	sb.add_theme_stylebox_override("grabber", sb_grab)
	var sb_grab_hl := StyleBoxFlat.new()
	sb_grab_hl.bg_color = Color(0.82, 0.82, 0.88, 1.0)
	sb_grab_hl.set_corner_radius_all(2)
	sb.add_theme_stylebox_override("grabber_highlight", sb_grab_hl)
	sb.add_theme_stylebox_override("grabber_pressed", sb_grab_hl)
	sb.value_changed.connect(_on_scroll_value_changed)
	_scroll_content = Control.new()
	_scroll_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_container.add_child(_scroll_content)
	add_child(_scroll_container)
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
	_scroll_row = 0
	_rebuild_visible_list()
	_recalc_layout()
	_hovered = -1
	queue_redraw()


func _on_search_changed(new_text: String) -> void:
	_search_query = new_text.to_lower().strip_edges()
	_scroll_row = 0
	_rebuild_visible_list()
	_recalc_layout()
	_hovered = -1
	queue_redraw()


func _get_entry_name(id: int) -> String:
	return Items.get_item_name(id) if Items.is_item(id) else BlockIcon.get_block_name(id)


func _total_rows() -> int:
	return maxi(1, int(ceil(float(_visible_blocks.size()) / float(COLS))))


func _max_scroll_row() -> int:
	return maxi(0, _total_rows() - VISIBLE_ROWS)


func _rebuild_visible_list() -> void:
	var source: Array[int]
	match _current_tab:
		Tab.MINERALS: source = MINERALS
		Tab.ORES:     source = ORES
		Tab.NATURAL:  source = NATURAL
		Tab.COLORFUL: source = COLORFUL
		Tab.TOOLS:    source = TOOLS_ITEMS
		_:            source = ALL_BLOCKS
	if _search_query.is_empty():
		_visible_blocks = source.duplicate()
		return
	_visible_blocks = []
	for b: int in source:
		if _search_query in _get_entry_name(b).to_lower():
			_visible_blocks.append(b)


func _on_scroll_value_changed(value: float) -> void:
	if _sb_updating:
		return
	var new_row := clampi(int(value / float(SLOT_SIZE)), 0, _max_scroll_row())
	if new_row == _scroll_row:
		return
	_scroll_row = new_row
	_hovered = -1
	_recalc_layout()
	queue_redraw()


func _recalc_layout() -> void:
	_scroll_row = clampi(_scroll_row, 0, _max_scroll_row())

	var grid_w: int = COLS * SLOT_SIZE
	var grid_h: int = VISIBLE_ROWS * SLOT_SIZE
	var show_search: bool = _current_tab == Tab.SEARCH
	var search_area: int = SEARCH_H if show_search else 0
	var panel_w: int = grid_w + PANEL_PAD * 2 + SCROLLBAR_W + 4
	var panel_h: int = TITLE_H + TAB_H + search_area + grid_h + NAME_H + PANEL_PAD * 2
	var vp: Vector2 = get_viewport_rect().size
	var px: float = floor((vp.x - panel_w) * 0.5)
	var py: float = floor((vp.y - panel_h) * 0.5)
	_panel_rect = Rect2(px, py, panel_w, panel_h)

	var tab_y: float = py + TITLE_H
	var tab_w: float = float(panel_w - PANEL_PAD * 2) / float(TAB_NAMES.size())
	_tab_rects.clear()
	for i: int in TAB_NAMES.size():
		_tab_rects.append(Rect2(px + PANEL_PAD + i * tab_w, tab_y, tab_w, TAB_H))

	if show_search:
		_search_edit.visible = true
		_search_edit.position = Vector2(px + PANEL_PAD, tab_y + TAB_H)
		_search_edit.size = Vector2(grid_w, SEARCH_H - 4)
	else:
		_search_edit.visible = false

	_grid_origin = Vector2(px + PANEL_PAD, tab_y + TAB_H + search_area + PANEL_PAD)
	_grid_rect = Rect2(_grid_origin, Vector2(grid_w, grid_h))

	# Slot rects for the visible window only.
	_slot_rects.clear()
	var first: int = _scroll_row * COLS
	var last: int = mini(first + VISIBLE_ROWS * COLS, _visible_blocks.size())
	for i: int in range(first, last):
		var local_i: int = i - first
		var col: int = local_i % COLS
		var row: int = local_i / COLS
		_slot_rects.append(Rect2(
			_grid_origin.x + col * SLOT_SIZE,
			_grid_origin.y + row * SLOT_SIZE,
			SLOT_SIZE, SLOT_SIZE))

	# Position ScrollContainer over grid + scrollbar area and sync scroll.
	if _scroll_container != null:
		_scroll_container.position = _grid_origin
		_scroll_container.size = Vector2(_grid_rect.size.x + SCROLLBAR_W + 2, _grid_rect.size.y)
		_scroll_content.custom_minimum_size = Vector2(1, _total_rows() * SLOT_SIZE)
		_sb_updating = true
		_scroll_container.scroll_vertical = _scroll_row * SLOT_SIZE
		_sb_updating = false


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
	var title: String = "Creative Inventory"
	var title_fs: int = PauseMenu._fs(32)
	var title_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs)
	var title_x: float = pr.position.x + (pr.size.x - title_size.x) * 0.5
	var title_y: float = pr.position.y + title_fs + 2
	draw_string(font, Vector2(title_x + 2, title_y + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(title_x, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, Color(1, 1, 1, 1.0))

	var tab_fs: int = PauseMenu._fs(17)
	for i: int in _tab_rects.size():
		var tr: Rect2 = _tab_rects[i]
		var active: bool = i == _current_tab
		var bg := Color(0.22, 0.22, 0.25, 0.95) if active else Color(0.12, 0.12, 0.14, 0.85)
		draw_rect(tr, bg)
		var border_col := Color(1, 1, 0.5) if active else Color(0.45, 0.45, 0.47)
		draw_rect(Rect2(tr.position.x, tr.position.y, tr.size.x, 2), border_col)
		draw_rect(Rect2(tr.position.x, tr.position.y, 2, tr.size.y), border_col)
		draw_rect(Rect2(tr.position.x + tr.size.x - 2, tr.position.y, 2, tr.size.y), border_col)
		var text: String = TAB_NAMES[i]
		var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs)
		var tx: float = tr.position.x + (tr.size.x - ts.x) * 0.5
		var ty: float = tr.position.y + (tr.size.y + ts.y) * 0.5 - 4
		var col: Color = Color(1, 1, 1) if active else Color(0.75, 0.75, 0.75)
		draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs, col)

	# Slots — only the visible window.
	var first: int = _scroll_row * COLS
	for i: int in _slot_rects.size():
		var actual_idx: int = first + i
		var rect: Rect2 = _slot_rects[i]
		var bg := Color(0.30, 0.30, 0.35, 0.95) if actual_idx == _hovered else Color(0.08, 0.08, 0.10, 0.85)
		draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, rect.size.y - 4), bg)
		var cx: float = rect.position.x + rect.size.x * 0.5
		var entry_id: int = _visible_blocks[actual_idx]
		if Items.is_item(entry_id):
			var cy: float = rect.position.y + rect.size.y * 0.5
			Items.draw_item_icon(self, cx, cy, ITEM_ICON_S, entry_id)
		else:
			var cy: float = rect.position.y + rect.size.y * 0.5 - BLOCK_S * BlockIcon.CUBE_H * 0.5
			BlockIcon.draw_iso(self, _atlas, cx, cy, BLOCK_S, entry_id)
		if actual_idx == _hovered:
			draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 2), Color(1, 1, 1, 1))
			draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 2, rect.size.x, 2), Color(1, 1, 1, 1))
			draw_rect(Rect2(rect.position.x, rect.position.y, 2, rect.size.y), Color(1, 1, 1, 1))
			draw_rect(Rect2(rect.position.x + rect.size.x - 2, rect.position.y, 2, rect.size.y), Color(1, 1, 1, 1))

	# Hover name.
	var name_str: String
	if _hovered >= 0 and _hovered < _visible_blocks.size():
		name_str = _get_entry_name(_visible_blocks[_hovered])
	elif _visible_blocks.is_empty():
		name_str = "No results match" if not _search_query.is_empty() else ""
	else:
		name_str = "Scroll to browse  |  Click to pick"
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
			return _scroll_row * COLS + i   # actual index into _visible_blocks
	return -1


func _hit_test_tab(pos: Vector2) -> int:
	for i: int in _tab_rects.size():
		if _tab_rects[i].has_point(pos):
			return i
	return -1


func _scroll_by(delta: int) -> void:
	var new_row: int = clampi(_scroll_row + delta, 0, _max_scroll_row())
	if new_row != _scroll_row:
		_scroll_row = new_row
		_hovered = -1
		_recalc_layout()
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or (event.keycode == KEY_E and not _search_edit.has_focus()):
			close()
			get_viewport().set_input_as_handled()


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
				accept_event()
				return
			var idx: int = _hit_test_slot(event.position)
			if idx >= 0 and idx < _visible_blocks.size():
				block_selected.emit(_visible_blocks[idx])
				close()
