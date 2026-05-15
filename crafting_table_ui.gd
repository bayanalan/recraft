extends Control

const SLOT_SIZE: int = 48
const BLOCK_S:   float = 14.0
const COLS:      int = 9
const STORAGE_ROWS: int = 3
const CRAFT_SIZE:   int = 3

const BAR_TINT      := Color(0.45, 0.45, 0.45, 0.95)
const BAR_DARK      := Color(0.12, 0.12, 0.13, 1.0)
const BAR_LIGHT     := Color(0.68, 0.68, 0.66, 1.0)
const SLOT_BG       := Color(0.0, 0.0, 0.0, 0.35)
const SLOT_HOVER    := Color(1.0, 1.0, 1.0, 0.25)
const LABEL_COL     := Color(1.0, 1.0, 1.0, 0.95)
const CRAFT_ARROW   := Color(0.90, 0.75, 0.20)

var _atlas: Texture2D = null
var _hud: Node = null

var _cursor_id: int = 0
var _cursor_count: int = 0
var _hover_slot: int = -1

var _craft_ids:    Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var _craft_counts: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var _craft_output_id: int = 0
var _craft_output_count: int = 0

var _panel_rect: Rect2 = Rect2()
var _craft_rects:    Array[Rect2] = []
var _craft_out_rect: Rect2 = Rect2()
var _storage_rects:  Array[Rect2] = []
var _hotbar_rects:   Array[Rect2] = []
var _clear_rect:     Rect2 = Rect2()

var _layout_valid: bool = false


func _ready() -> void:
	_atlas = BlockTextures.create_icon_atlas()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud = get_parent()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open() -> void:
	_craft_ids.fill(0)
	_craft_counts.fill(0)
	_craft_output_id = 0
	_craft_output_count = 0
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout_valid = false
	queue_redraw()


func close() -> void:
	_return_craft_to_inventory()
	_drop_cursor()
	visible = false
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _compute_layout() -> void:
	if _layout_valid:
		return
	_layout_valid = true
	var vp: Vector2 = get_viewport_rect().size
	var cx: float = vp.x * 0.5
	var panel_w: float = float(COLS * SLOT_SIZE + 24)
	var panel_h: float = 460.0
	var px: float = cx - panel_w * 0.5
	var py: float = vp.y * 0.5 - panel_h * 0.5
	_panel_rect = Rect2(px, py, panel_w, panel_h)

	var col_x: float = px + 12
	var row_y: float = py + 48

	# 3x3 craft grid
	_craft_rects.clear()
	for r: int in CRAFT_SIZE:
		for c: int in CRAFT_SIZE:
			_craft_rects.append(Rect2(col_x + c * (SLOT_SIZE + 2), row_y + r * (SLOT_SIZE + 2), SLOT_SIZE, SLOT_SIZE))

	# Output slot (right of 3x3)
	var craft_end_x: float = col_x + CRAFT_SIZE * (SLOT_SIZE + 2)
	_craft_out_rect = Rect2(craft_end_x + 44, row_y + (SLOT_SIZE + 2), SLOT_SIZE, SLOT_SIZE)

	# Clear button
	_clear_rect = Rect2(craft_end_x + 44, row_y + (SLOT_SIZE + 2) * 2 + 8, SLOT_SIZE, 28)

	# Storage grid
	_storage_rects.clear()
	var storage_y: float = row_y + CRAFT_SIZE * (SLOT_SIZE + 2) + 20
	for r: int in STORAGE_ROWS:
		for c: int in COLS:
			_storage_rects.append(Rect2(col_x + c * SLOT_SIZE, storage_y + r * SLOT_SIZE, SLOT_SIZE, SLOT_SIZE))

	# Hotbar
	_hotbar_rects.clear()
	var hotbar_y: float = storage_y + STORAGE_ROWS * SLOT_SIZE + 8
	for c: int in COLS:
		_hotbar_rects.append(Rect2(col_x + c * SLOT_SIZE, hotbar_y, SLOT_SIZE, SLOT_SIZE))


func _draw() -> void:
	if not visible:
		return
	_compute_layout()
	var font: Font = ThemeDB.fallback_font

	_draw_stone_bg(_panel_rect, BAR_TINT)
	draw_rect(Rect2(_panel_rect.position.x - 2, _panel_rect.position.y - 2, _panel_rect.size.x + 4, 2), BAR_DARK)
	draw_rect(Rect2(_panel_rect.position.x - 2, _panel_rect.position.y + _panel_rect.size.y, _panel_rect.size.x + 4, 2), BAR_DARK)
	draw_rect(Rect2(_panel_rect.position.x - 2, _panel_rect.position.y - 2, 2, _panel_rect.size.y + 4), BAR_DARK)
	draw_rect(Rect2(_panel_rect.position.x + _panel_rect.size.x, _panel_rect.position.y - 2, 2, _panel_rect.size.y + 4), BAR_DARK)

	draw_string(font, Vector2(_panel_rect.position.x + 12, _panel_rect.position.y + 28),
		"Crafting Table", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(20), LABEL_COL)

	var inv: Inventory = _get_inv()

	# Craft grid
	for i: int in _craft_rects.size():
		var r: Rect2 = _craft_rects[i]
		_draw_slot(r, _hover_slot == _craft_slot_index(i))
		if _craft_ids[i] != 0:
			_draw_item_centered(r, _craft_ids[i], _craft_counts[i])

	# Arrow
	var arrow_cx: float = _craft_rects[2].position.x + _craft_rects[2].size.x + 10
	var arrow_cy: float = _craft_rects[3].position.y + SLOT_SIZE * 0.5 + 6
	draw_string(font, Vector2(arrow_cx, arrow_cy), "->", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(20), CRAFT_ARROW)

	# Output slot
	_draw_slot(_craft_out_rect, _hover_slot == _craft_out_slot_index(), _craft_output_id != 0)
	if _craft_output_id != 0:
		_draw_item_centered(_craft_out_rect, _craft_output_id, _craft_output_count)

	# Clear button
	draw_rect(_clear_rect, BAR_DARK)
	draw_rect(Rect2(_clear_rect.position.x + 1, _clear_rect.position.y + 1, _clear_rect.size.x - 2, _clear_rect.size.y - 2), Color(0.35, 0.35, 0.38))
	draw_string(font, Vector2(_clear_rect.position.x + 8, _clear_rect.position.y + 18),
		"Clear", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(15), LABEL_COL)

	# Storage
	draw_string(font, Vector2(_panel_rect.position.x + 12, _storage_rects[0].position.y - 6),
		"Storage", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(14), Color(0.8, 0.8, 0.8))
	for i: int in _storage_rects.size():
		var r: Rect2 = _storage_rects[i]
		_draw_slot(r, _hover_slot == _storage_slot_index(i))
		if inv != null:
			var si: int = Inventory.HOTBAR_SIZE + i
			if inv.ids[si] != 0:
				_draw_item_centered(r, inv.ids[si], inv.counts[si])

	# Hotbar
	for i: int in _hotbar_rects.size():
		var r: Rect2 = _hotbar_rects[i]
		_draw_slot(r, _hover_slot == _hotbar_slot_index(i))
		if inv != null and inv.ids[i] != 0:
			_draw_item_centered(r, inv.ids[i], inv.counts[i])

	# Cursor
	if _cursor_id != 0:
		var mp: Vector2 = get_viewport().get_mouse_position()
		_draw_item_at(mp.x, mp.y, _cursor_id, _cursor_count)


func _draw_slot(r: Rect2, hovered: bool, bright: bool = false) -> void:
	draw_rect(r, SLOT_BG)
	if hovered:
		draw_rect(r, SLOT_HOVER)
	if bright:
		draw_rect(r, Color(0.9, 0.85, 0.2, 0.15))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), BAR_DARK)
	draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), BAR_DARK)
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 1, r.size.x, 1), BAR_LIGHT)
	draw_rect(Rect2(r.position.x + r.size.x - 1, r.position.y, 1, r.size.y), BAR_LIGHT)


func _draw_item_centered(r: Rect2, id: int, count: int) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	var cy: float = r.position.y + r.size.y * 0.5 - BLOCK_S * BlockIcon.CUBE_H * 0.5
	_draw_item_at(cx, cy, id, count)


func _draw_item_at(cx: float, cy: float, id: int, count: int) -> void:
	if Items.is_block(id):
		BlockIcon.draw_iso(self, _atlas, cx, cy, BLOCK_S, id)
	else:
		Items.draw_item_icon(self, cx, cy + BLOCK_S * BlockIcon.CUBE_H * 0.5, BLOCK_S * 1.0, id)
	if count > 1:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(cx + 8, cy + BLOCK_S * BlockIcon.CUBE_H + 14),
			str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(18), Color(1, 1, 1))


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


func _craft_slot_index(i: int) -> int:    return 2000 + i
func _craft_out_slot_index() -> int:       return 2999
func _storage_slot_index(i: int) -> int:  return 3000 + i
func _hotbar_slot_index(i: int) -> int:   return 4000 + i


func _get_inv() -> Inventory:
	if _hud != null and "inventory" in _hud:
		return _hud.inventory
	return null


func _update_craft_output() -> void:
	var grid: Array[int] = []
	grid.assign(_craft_ids)
	var result: Dictionary = Crafting.match_recipe(grid, CRAFT_SIZE)
	if result.is_empty():
		_craft_output_id = 0
		_craft_output_count = 0
	else:
		_craft_output_id = result["id"]
		_craft_output_count = result["count"]


func _return_craft_to_inventory() -> void:
	var inv: Inventory = _get_inv()
	if inv == null:
		return
	for i: int in 9:
		if _craft_ids[i] != 0:
			inv.give_item(_craft_ids[i], _craft_counts[i])
			_craft_ids[i] = 0
			_craft_counts[i] = 0
	_craft_output_id = 0
	_craft_output_count = 0
	if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
		_hud._sync_slots_from_inventory()


func _drop_cursor() -> void:
	if _cursor_id != 0:
		var inv: Inventory = _get_inv()
		if inv != null:
			inv.give_item(_cursor_id, _cursor_count)
		_cursor_id = 0
		_cursor_count = 0
		if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
			_hud._sync_slots_from_inventory()


func _slot_rect_at_mouse(mp: Vector2) -> int:
	for i: int in _craft_rects.size():
		if _craft_rects[i].has_point(mp):
			return _craft_slot_index(i)
	if _craft_out_rect.has_point(mp):
		return _craft_out_slot_index()
	for i: int in _storage_rects.size():
		if _storage_rects[i].has_point(mp):
			return _storage_slot_index(i)
	for i: int in _hotbar_rects.size():
		if _hotbar_rects[i].has_point(mp):
			return _hotbar_slot_index(i)
	return -1


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		_compute_layout()
		_hover_slot = _slot_rect_at_mouse(event.position)
		queue_redraw()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_Q and _cursor_id != 0:
			_cursor_id = 0
			_cursor_count = 0
			queue_redraw()

	if event is InputEventMouseButton and event.pressed:
		_compute_layout()
		# Check clear button
		if _clear_rect.has_point(event.position):
			_return_craft_to_inventory()
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

		var mp: Vector2 = event.position
		var slot: int = _slot_rect_at_mouse(mp)
		if slot < 0:
			return
		var inv: Inventory = _get_inv()
		if inv == null:
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(slot, inv, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(slot, inv)
		queue_redraw()
		if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
			_hud._sync_slots_from_inventory()
		get_viewport().set_input_as_handled()


func _handle_left_click(slot: int, inv: Inventory, shift: bool) -> void:
	if slot == _craft_out_slot_index():
		if _craft_output_id == 0:
			return
		if shift:
			while _craft_output_id != 0:
				var leftover: int = inv.give_item(_craft_output_id, _craft_output_count)
				if leftover > 0:
					break
				_consume_craft_inputs(1)
				_update_craft_output()
		else:
			if _cursor_id == 0 or _cursor_id == _craft_output_id:
				var max_s: int = Items.get_max_stack(_craft_output_id)
				if _cursor_count + _craft_output_count <= max_s:
					_cursor_id = _craft_output_id
					_cursor_count += _craft_output_count
					_consume_craft_inputs(1)
					_update_craft_output()
		return

	if slot >= _craft_slot_index(0) and slot < _craft_slot_index(9):
		var ci: int = slot - _craft_slot_index(0)
		if _cursor_id == 0:
			if shift and _craft_ids[ci] != 0:
				inv.give_item(_craft_ids[ci], _craft_counts[ci])
				_craft_ids[ci] = 0
				_craft_counts[ci] = 0
				_update_craft_output()
			else:
				_cursor_id = _craft_ids[ci]
				_cursor_count = _craft_counts[ci]
				_craft_ids[ci] = 0
				_craft_counts[ci] = 0
				_update_craft_output()
		else:
			if _craft_ids[ci] == 0:
				_craft_ids[ci] = _cursor_id
				_craft_counts[ci] = _cursor_count
				_cursor_id = 0
				_cursor_count = 0
			elif _craft_ids[ci] == _cursor_id:
				var add: int = mini(_cursor_count, Items.MAX_STACK - _craft_counts[ci])
				_craft_counts[ci] += add
				_cursor_count -= add
				if _cursor_count == 0:
					_cursor_id = 0
			else:
				var tmp_id: int = _craft_ids[ci]
				var tmp_c: int = _craft_counts[ci]
				_craft_ids[ci] = _cursor_id
				_craft_counts[ci] = _cursor_count
				_cursor_id = tmp_id
				_cursor_count = tmp_c
			_update_craft_output()
		return

	var inv_slot: int = _resolve_inv_slot(slot)
	if inv_slot < 0:
		return

	if shift and _cursor_id == 0:
		var id: int = inv.ids[inv_slot]
		var count: int = inv.counts[inv_slot]
		if id == 0:
			return
		inv.ids[inv_slot] = 0
		inv.counts[inv_slot] = 0
		var ts: int = 0 if inv_slot < Inventory.HOTBAR_SIZE else Inventory.HOTBAR_SIZE
		var te: int = Inventory.HOTBAR_SIZE if inv_slot < Inventory.HOTBAR_SIZE else Inventory.TOTAL_SLOTS
		var lft: int = count
		var ms: int = Items.get_max_stack(id)
		for ti: int in range(ts, te):
			if lft <= 0: break
			if inv.ids[ti] == id and inv.counts[ti] < ms:
				var a: int = mini(lft, ms - inv.counts[ti])
				inv.counts[ti] += a; lft -= a
		for ti: int in range(ts, te):
			if lft <= 0: break
			if inv.ids[ti] == 0:
				inv.ids[ti] = id; inv.counts[ti] = mini(lft, ms); lft -= inv.counts[ti]
		if lft > 0:
			inv.ids[inv_slot] = id; inv.counts[inv_slot] = lft
		return

	if _cursor_id == 0:
		_cursor_id = inv.ids[inv_slot]
		_cursor_count = inv.counts[inv_slot]
		inv.ids[inv_slot] = 0
		inv.counts[inv_slot] = 0
	else:
		if inv.ids[inv_slot] == 0:
			inv.ids[inv_slot] = _cursor_id
			inv.counts[inv_slot] = _cursor_count
			_cursor_id = 0; _cursor_count = 0
		elif inv.ids[inv_slot] == _cursor_id:
			var ms: int = Items.get_max_stack(_cursor_id)
			var a: int = mini(_cursor_count, ms - inv.counts[inv_slot])
			inv.counts[inv_slot] += a; _cursor_count -= a
			if _cursor_count == 0: _cursor_id = 0
		else:
			var ti: int = inv.ids[inv_slot]
			var tc: int = inv.counts[inv_slot]
			inv.ids[inv_slot] = _cursor_id; inv.counts[inv_slot] = _cursor_count
			_cursor_id = ti; _cursor_count = tc


func _handle_right_click(slot: int, inv: Inventory) -> void:
	if slot == _craft_out_slot_index():
		_handle_left_click(slot, inv, false)
		return
	if slot >= _craft_slot_index(0) and slot < _craft_slot_index(9):
		var ci: int = slot - _craft_slot_index(0)
		if _cursor_id != 0:
			if _craft_ids[ci] == 0 or _craft_ids[ci] == _cursor_id:
				_craft_ids[ci] = _cursor_id
				_craft_counts[ci] += 1
				_cursor_count -= 1
				if _cursor_count == 0: _cursor_id = 0
				_update_craft_output()
		else:
			if _craft_ids[ci] != 0:
				var half: int = ceili(float(_craft_counts[ci]) / 2.0)
				_cursor_id = _craft_ids[ci]
				_cursor_count = half
				_craft_counts[ci] -= half
				if _craft_counts[ci] == 0: _craft_ids[ci] = 0
				_update_craft_output()
		return
	var inv_slot: int = _resolve_inv_slot(slot)
	if inv_slot < 0: return
	if _cursor_id != 0:
		if inv.ids[inv_slot] == 0 or inv.ids[inv_slot] == _cursor_id:
			var ms: int = Items.get_max_stack(_cursor_id)
			if inv.counts[inv_slot] < ms:
				inv.ids[inv_slot] = _cursor_id
				inv.counts[inv_slot] += 1
				_cursor_count -= 1
				if _cursor_count == 0: _cursor_id = 0
	else:
		if inv.ids[inv_slot] != 0:
			var half: int = ceili(float(inv.counts[inv_slot]) / 2.0)
			_cursor_id = inv.ids[inv_slot]
			_cursor_count = half
			inv.counts[inv_slot] -= half
			if inv.counts[inv_slot] == 0: inv.ids[inv_slot] = 0


func _resolve_inv_slot(slot: int) -> int:
	if slot >= _hotbar_slot_index(0) and slot < _hotbar_slot_index(9):
		return slot - _hotbar_slot_index(0)
	if slot >= _storage_slot_index(0) and slot < _storage_slot_index(27):
		return Inventory.HOTBAR_SIZE + (slot - _storage_slot_index(0))
	return -1


func _consume_craft_inputs(times: int) -> void:
	for _t: int in times:
		for i: int in 9:
			if _craft_ids[i] != 0:
				_craft_counts[i] -= 1
				if _craft_counts[i] <= 0:
					_craft_ids[i] = 0
					_craft_counts[i] = 0
