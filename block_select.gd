extends Control
class_name BlockSelect

signal block_selected(block_type: int)
signal closed

const COLS: int = 9
const SLOT_SIZE: int = 56
const BLOCK_S: float = 18.0
const TITLE_H: int = 40
const NAME_H: int = 28
const PANEL_PAD: int = 18

# Full inventory ordered by category.
const INVENTORY: Array[int] = [
	# Core terrain
	Chunk.Block.STONE,
	Chunk.Block.COBBLESTONE,
	Chunk.Block.SMOOTH_STONE,
	Chunk.Block.SMOOTH_STONE_SLAB,
	Chunk.Block.DIRT,
	Chunk.Block.GRASS,
	Chunk.Block.PLANKS,
	Chunk.Block.LOG,
	Chunk.Block.LEAVES,
	Chunk.Block.SAND,
	Chunk.Block.GLASS,
	Chunk.Block.WATER,
	Chunk.Block.LAVA,
	# Special building
	Chunk.Block.BRICK,
	Chunk.Block.MOSSY_COBBLESTONE,
	Chunk.Block.BEDROCK,
	Chunk.Block.OBSIDIAN,
	Chunk.Block.BOOKSHELF,
	Chunk.Block.SPONGE,
	Chunk.Block.TNT,
	Chunk.Block.FIRE,
	Chunk.Block.POPPY,
	Chunk.Block.DANDELION,
	Chunk.Block.BARRIER,
	Chunk.Block.IRON_BLOCK,
	Chunk.Block.GOLD_BLOCK,
	# Ores + wool
	Chunk.Block.COAL_ORE,
	Chunk.Block.IRON_ORE,
	Chunk.Block.GOLD_ORE,
	Chunk.Block.DIAMOND_ORE,
	# Wool colors in classic-Minecraft palette order.
	Chunk.Block.WOOL_WHITE,
	Chunk.Block.WOOL_ORANGE,
	Chunk.Block.WOOL_MAGENTA,
	Chunk.Block.WOOL_LIGHT_BLUE,
	Chunk.Block.WOOL_YELLOW,
	Chunk.Block.WOOL_LIME,
	Chunk.Block.WOOL_PINK,
	Chunk.Block.WOOL_GRAY,
	Chunk.Block.WOOL_LIGHT_GRAY,
	Chunk.Block.WOOL_CYAN,
	Chunk.Block.WOOL_PURPLE,
	Chunk.Block.WOOL_BLUE,
	Chunk.Block.WOOL_BROWN,
	Chunk.Block.WOOL_GREEN,
	Chunk.Block.WOOL_RED,
	Chunk.Block.WOOL_BLACK,
]

var _atlas: Texture2D = null
var _hovered: int = -1

# Cached layout rects — recalculated when viewport changes or on open
var _panel_rect: Rect2
var _grid_origin: Vector2
var _slot_rects: Array[Rect2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_atlas = BlockTextures.create_icon_atlas()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	get_viewport().size_changed.connect(_recalc_layout)
	_recalc_layout()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hovered = -1
	_recalc_layout()
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _recalc_layout() -> void:
	var rows: int = int(ceil(float(INVENTORY.size()) / float(COLS)))
	var grid_w: int = COLS * SLOT_SIZE
	var grid_h: int = rows * SLOT_SIZE
	var panel_w: int = grid_w + PANEL_PAD * 2
	var panel_h: int = TITLE_H + grid_h + NAME_H + PANEL_PAD * 2
	var vp: Vector2 = get_viewport_rect().size
	var px: float = floor((vp.x - panel_w) * 0.5)
	var py: float = floor((vp.y - panel_h) * 0.5)
	_panel_rect = Rect2(px, py, panel_w, panel_h)
	_grid_origin = Vector2(px + PANEL_PAD, py + TITLE_H + PANEL_PAD)

	_slot_rects.clear()
	_slot_rects.resize(INVENTORY.size())
	for i: int in INVENTORY.size():
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
	# Dark overlay
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.65))

	# Outer dark border (thick)
	draw_rect(Rect2(_panel_rect.position - Vector2(3, 3), _panel_rect.size + Vector2(6, 6)), Color(0.05, 0.05, 0.06, 1.0))

	# Stone-textured panel background
	_draw_stone_bg(_panel_rect, Color(0.42, 0.42, 0.42, 0.98))

	# Beveled highlights
	var pr := _panel_rect
	draw_rect(Rect2(pr.position.x, pr.position.y, pr.size.x, 2), Color(0.72, 0.72, 0.70))
	draw_rect(Rect2(pr.position.x, pr.position.y, 2, pr.size.y), Color(0.72, 0.72, 0.70))
	draw_rect(Rect2(pr.position.x, pr.position.y + pr.size.y - 2, pr.size.x, 2), Color(0.15, 0.15, 0.16))
	draw_rect(Rect2(pr.position.x + pr.size.x - 2, pr.position.y, 2, pr.size.y), Color(0.15, 0.15, 0.16))

	# Title
	var font: Font = ThemeDB.fallback_font
	var title: String = "Select a Block"
	var title_fs: int = PauseMenu._fs(35)
	var title_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs)
	var title_x: float = pr.position.x + (pr.size.x - title_size.x) * 0.5
	var title_y: float = pr.position.y + title_fs + 4
	# Drop shadow
	draw_string(font, Vector2(title_x + 2, title_y + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(35), Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(title_x, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(35), Color(1, 1, 1, 1.0))

	# Slots
	for i: int in INVENTORY.size():
		var rect: Rect2 = _slot_rects[i]
		# Slot background
		var bg := Color(0.08, 0.08, 0.10, 0.85)
		if i == _hovered:
			bg = Color(0.30, 0.30, 0.35, 0.95)
		draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, rect.size.y - 4), bg)

		# Block preview — proper geometric centering
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5 - BLOCK_S * BlockIcon.CUBE_H * 0.5
		BlockIcon.draw_iso(self, _atlas, cx, cy, BLOCK_S, INVENTORY[i])

		# Hover outline
		if i == _hovered:
			var o := rect
			draw_rect(Rect2(o.position.x, o.position.y, o.size.x, 2), Color(1, 1, 1, 1))
			draw_rect(Rect2(o.position.x, o.position.y + o.size.y - 2, o.size.x, 2), Color(1, 1, 1, 1))
			draw_rect(Rect2(o.position.x, o.position.y, 2, o.size.y), Color(1, 1, 1, 1))
			draw_rect(Rect2(o.position.x + o.size.x - 2, o.position.y, 2, o.size.y), Color(1, 1, 1, 1))

	# Name of hovered block at bottom
	var name_str: String = ""
	if _hovered >= 0:
		name_str = BlockIcon.get_block_name(INVENTORY[_hovered])
	else:
		name_str = "Hover to see block name"
	var name_fs: int = PauseMenu._fs(24)
	var name_size: Vector2 = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs)
	var nx: float = pr.position.x + (pr.size.x - name_size.x) * 0.5
	var ny: float = pr.position.y + pr.size.y - name_fs + 2
	var name_color: Color = Color(0.95, 0.95, 0.95) if _hovered >= 0 else Color(0.55, 0.55, 0.55)
	draw_string(font, Vector2(nx, ny), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(24), name_color)


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


func _hit_test(pos: Vector2) -> int:
	for i: int in _slot_rects.size():
		if _slot_rects[i].has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hover: int = _hit_test(event.position)
		if new_hover != _hovered:
			_hovered = new_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx: int = _hit_test(event.position)
		if idx >= 0:
			block_selected.emit(INVENTORY[idx])
			close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close()
			get_viewport().set_input_as_handled()
