extends Control

const SLOT_SIZE: int = 48
const BLOCK_S: float = 14.0
const COLS: int = 9
const STORAGE_ROWS: int = 3
const CRAFT_SIZE: int = 2  # 2x2 crafting grid

const BAR_TINT       := Color(0.45, 0.45, 0.45, 0.95)
const BAR_DARK       := Color(0.12, 0.12, 0.13, 1.0)
const BAR_LIGHT      := Color(0.68, 0.68, 0.66, 1.0)
const SLOT_BG        := Color(0.0, 0.0, 0.0, 0.35)
const SLOT_HOVER     := Color(1.0, 1.0, 1.0, 0.25)
const SLOT_SELECTED  := Color(1.0, 1.0, 1.0, 0.98)
const LABEL_COL      := Color(1.0, 1.0, 1.0, 0.95)
const CRAFT_ARROW    := Color(0.90, 0.75, 0.20)

var _atlas: Texture2D = null
var _hud: Node = null

# Cursor item (held while dragging)
var _cursor_id: int = 0
var _cursor_count: int = 0
var _cursor_durability: int = 0
var _hover_slot: int = -1  # which slot the mouse is over

# Drag-split state
var _lmb_down: bool = false
var _rmb_down: bool = false
var _lmb_drag_active: bool = false
var _rmb_drag_active: bool = false
var _drag_slots: Array[int] = []

# Crafting grid: 4 slots (2x2)
var _craft_ids:    Array[int] = [0, 0, 0, 0]
var _craft_counts: Array[int] = [0, 0, 0, 0]
var _craft_output_id: int = 0
var _craft_output_count: int = 0

# Layout rects (computed in _compute_layout)
var _panel_rect: Rect2 = Rect2()
var _armor_rects:   Array[Rect2] = []
var _craft_rects:   Array[Rect2] = []
var _craft_out_rect: Rect2 = Rect2()
var _storage_rects: Array[Rect2] = []
var _hotbar_rects:  Array[Rect2] = []

var _layout_valid: bool = false


func _ready() -> void:
	_atlas = BlockTextures.create_icon_atlas()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud = get_parent()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout_valid = false
	_update_craft_output()
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
	var panel_h: float = 490.0
	var px: float = cx - panel_w * 0.5
	var py: float = vp.y * 0.5 - panel_h * 0.5
	_panel_rect = Rect2(px, py, panel_w, panel_h)

	var col_x: float = px + 12
	var row_y: float = py + 48

	# Armor slots (4 tall, left side)
	_armor_rects.clear()
	for i: int in 4:
		_armor_rects.append(Rect2(col_x, row_y + i * (SLOT_SIZE + 4), SLOT_SIZE, SLOT_SIZE))

	# Crafting grid (2x2, center)
	_craft_rects.clear()
	var craft_x: float = col_x + SLOT_SIZE + 20
	var craft_y: float = row_y
	for r: int in CRAFT_SIZE:
		for c: int in CRAFT_SIZE:
			_craft_rects.append(Rect2(craft_x + c * (SLOT_SIZE + 2), craft_y + r * (SLOT_SIZE + 2), SLOT_SIZE, SLOT_SIZE))
	# Output slot (right of craft grid, with arrow)
	_craft_out_rect = Rect2(craft_x + CRAFT_SIZE * (SLOT_SIZE + 2) + 40, craft_y + (SLOT_SIZE + 2) / 2.0, SLOT_SIZE, SLOT_SIZE)

	# Storage grid (3x9)
	_storage_rects.clear()
	var storage_y: float = row_y + 4 * (SLOT_SIZE + 4) + 16
	for r: int in STORAGE_ROWS:
		for c: int in COLS:
			_storage_rects.append(Rect2(col_x + c * SLOT_SIZE, storage_y + r * SLOT_SIZE, SLOT_SIZE, SLOT_SIZE))

	# Hotbar (1x9)
	_hotbar_rects.clear()
	var hotbar_y: float = storage_y + STORAGE_ROWS * SLOT_SIZE + 8
	for c: int in COLS:
		_hotbar_rects.append(Rect2(col_x + c * SLOT_SIZE, hotbar_y, SLOT_SIZE, SLOT_SIZE))


func _draw() -> void:
	if not visible:
		return
	_compute_layout()
	var font: Font = ThemeDB.fallback_font

	# Panel background
	_draw_stone_bg(_panel_rect, BAR_TINT)
	draw_rect(Rect2(_panel_rect.position.x - 2, _panel_rect.position.y - 2, _panel_rect.size.x + 4, 2), BAR_DARK)
	draw_rect(Rect2(_panel_rect.position.x - 2, _panel_rect.position.y + _panel_rect.size.y, _panel_rect.size.x + 4, 2), BAR_DARK)
	draw_rect(Rect2(_panel_rect.position.x - 2, _panel_rect.position.y - 2, 2, _panel_rect.size.y + 4), BAR_DARK)
	draw_rect(Rect2(_panel_rect.position.x + _panel_rect.size.x, _panel_rect.position.y - 2, 2, _panel_rect.size.y + 4), BAR_DARK)

	draw_string(font, Vector2(_panel_rect.position.x + 12, _panel_rect.position.y + 28),
		"Inventory", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(20), LABEL_COL)

	var inv: Inventory = _hud.inventory if _hud != null and "inventory" in _hud else null

	# Armor slots
	for i: int in 4:
		var r: Rect2 = _armor_rects[i]
		var hover: bool = _hover_slot == _armor_slot_index(i)
		_draw_slot(r, hover)
		if inv != null and inv.armor_ids[i] != 0:
			_draw_item_centered(r, inv.armor_ids[i], 1, inv.armor_durabilities[i])

	# Crafting grid
	for i: int in _craft_rects.size():
		var r: Rect2 = _craft_rects[i]
		var hover: bool = _hover_slot == _craft_slot_index(i)
		_draw_slot(r, hover)
		if _craft_ids[i] != 0:
			_draw_item_centered(r, _craft_ids[i], _craft_counts[i])

	# Arrow between craft grid and output
	var arrow_cx: float = _craft_rects[1].position.x + _craft_rects[1].size.x + 8
	var arrow_cy: float = _craft_rects[0].position.y + SLOT_SIZE * 0.5 + (SLOT_SIZE + 2) * 0.5
	draw_string(font, Vector2(arrow_cx, arrow_cy + 8), ">",
		HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(22), CRAFT_ARROW)

	# Craft output slot
	var out_hover: bool = _hover_slot == _craft_out_slot_index()
	_draw_slot(_craft_out_rect, out_hover, _craft_output_id != 0)
	if _craft_output_id != 0:
		_draw_item_centered(_craft_out_rect, _craft_output_id, _craft_output_count)

	# Storage
	draw_string(font, Vector2(_panel_rect.position.x + 12, _storage_rects[0].position.y - 6),
		"Storage", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(14), Color(0.8, 0.8, 0.8))
	for i: int in _storage_rects.size():
		var r: Rect2 = _storage_rects[i]
		var slot_idx: int = Inventory.HOTBAR_SIZE + i
		var hover: bool = _hover_slot == _storage_slot_index(i)
		_draw_slot(r, hover)
		if inv != null and inv.ids[slot_idx] != 0:
			_draw_item_centered(r, inv.ids[slot_idx], inv.counts[slot_idx], inv.durabilities[slot_idx])

	# Hotbar
	for i: int in _hotbar_rects.size():
		var r: Rect2 = _hotbar_rects[i]
		var hover: bool = _hover_slot == _hotbar_slot_index(i)
		_draw_slot(r, hover)
		if inv != null and inv.ids[i] != 0:
			_draw_item_centered(r, inv.ids[i], inv.counts[i], inv.durabilities[i])

	# Cursor item (follows mouse)
	if _cursor_id != 0:
		var mp: Vector2 = get_viewport().get_mouse_position()
		_draw_item_at(mp.x, mp.y, _cursor_id, _cursor_count)

	# Tooltip
	if _hover_slot >= 0 and _cursor_id == 0:
		_draw_tooltip(font)


func _draw_slot(r: Rect2, hovered: bool, bright: bool = false) -> void:
	draw_rect(r, SLOT_BG)
	if hovered:
		draw_rect(r, SLOT_HOVER)
	if bright:
		draw_rect(r, Color(0.9, 0.85, 0.2, 0.15))
	# Bevel
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), BAR_DARK)
	draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), BAR_DARK)
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 1, r.size.x, 1), BAR_LIGHT)
	draw_rect(Rect2(r.position.x + r.size.x - 1, r.position.y, 1, r.size.y), BAR_LIGHT)


func _draw_item_centered(r: Rect2, id: int, count: int, durability: int = 0) -> void:
	var cx: float = r.position.x + r.size.x * 0.5
	var cy: float = r.position.y + r.size.y * 0.5 - BLOCK_S * BlockIcon.CUBE_H * 0.5
	_draw_item_at(cx, cy, id, count)
	if durability > 0 and id != 0:
		var max_dur: int = Items.get_max_durability(id)
		if max_dur > 0:
			var frac: float = float(durability) / float(max_dur)
			var dur_col: Color
			if frac > 0.5:
				dur_col = Color(0.17, 0.73, 0.17)
			elif frac > 0.25:
				dur_col = Color(0.93, 0.84, 0.12)
			elif frac > 0.1:
				dur_col = Color(0.82, 0.35, 0.08)
			else:
				dur_col = Color(0.85, 0.10, 0.10)
			var bar_max_w: float = r.size.x - 10
			var bar_w: float = maxf(1.0, bar_max_w * frac)
			draw_rect(Rect2(r.position.x + 5, r.position.y + r.size.y - 8, bar_max_w, 3), Color(0, 0, 0, 1.0))
			draw_rect(Rect2(r.position.x + 5, r.position.y + r.size.y - 8, bar_w, 3), dur_col)


func _draw_item_at(cx: float, cy: float, id: int, count: int) -> void:
	if Items.is_block(id):
		BlockIcon.draw_iso(self, _atlas, cx, cy, BLOCK_S, id)
	else:
		Items.draw_item_icon(self, cx, cy + BLOCK_S * BlockIcon.CUBE_H * 0.5, BLOCK_S * 1.0, id)
	if count > 1:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(cx + 8, cy + BLOCK_S * BlockIcon.CUBE_H + 14),
			str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(18), Color(1, 1, 1))


func _draw_tooltip(font: Font) -> void:
	var name_str: String = _get_hover_item_name()
	if name_str.is_empty():
		return
	var hover_id: int = _get_hover_item_id()
	var dur: int = _get_hover_item_durability()
	var max_dur: int = Items.get_max_durability(hover_id) if hover_id != 0 else 0
	var show_dur: bool = dur > 0 and max_dur > 0
	var tw: float = maxf(float(name_str.length()) * 7.0 + 12.0, 130.0 if show_dur else 0.0)
	var mp: Vector2 = get_viewport().get_mouse_position()
	var tx: float = mp.x + 12
	var ty: float = mp.y - 28
	var box_h: float = 22.0 + (20.0 if show_dur else 0.0)
	draw_rect(Rect2(tx - 4, ty - 16, tw + 8, box_h), Color(0.1, 0.1, 0.1, 0.85))
	draw_string(font, Vector2(tx, ty), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(16), LABEL_COL)
	if show_dur:
		var dur_str: String = "Durability: %d / %d" % [dur, max_dur]
		draw_string(font, Vector2(tx, ty + 18), dur_str, HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(13), Color(0.75, 0.75, 0.75))


func _get_hover_item_name() -> String:
	var inv: Inventory = _get_inv()
	if inv == null:
		return ""
	if _hover_slot >= _hotbar_slot_index(0) and _hover_slot < _hotbar_slot_index(0) + 9:
		var i: int = _hover_slot - _hotbar_slot_index(0)
		return Items.get_item_name(inv.ids[i]) if inv.ids[i] != 0 else ""
	if _hover_slot >= _storage_slot_index(0) and _hover_slot < _storage_slot_index(0) + 27:
		var i: int = _hover_slot - _storage_slot_index(0)
		return Items.get_item_name(inv.ids[Inventory.HOTBAR_SIZE + i]) if inv.ids[Inventory.HOTBAR_SIZE + i] != 0 else ""
	if _hover_slot >= _armor_slot_index(0) and _hover_slot < _armor_slot_index(0) + 4:
		var i: int = _hover_slot - _armor_slot_index(0)
		return Items.get_item_name(inv.armor_ids[i]) if inv.armor_ids[i] != 0 else ""
	if _hover_slot >= _craft_slot_index(0) and _hover_slot < _craft_slot_index(0) + 4:
		var i: int = _hover_slot - _craft_slot_index(0)
		return Items.get_item_name(_craft_ids[i]) if _craft_ids[i] != 0 else ""
	if _hover_slot == _craft_out_slot_index():
		return Items.get_item_name(_craft_output_id) if _craft_output_id != 0 else ""
	return ""


func _get_hover_item_id() -> int:
	var inv: Inventory = _get_inv()
	if inv == null:
		return 0
	if _hover_slot >= _hotbar_slot_index(0) and _hover_slot < _hotbar_slot_index(0) + 9:
		return inv.ids[_hover_slot - _hotbar_slot_index(0)]
	if _hover_slot >= _storage_slot_index(0) and _hover_slot < _storage_slot_index(0) + 27:
		return inv.ids[Inventory.HOTBAR_SIZE + (_hover_slot - _storage_slot_index(0))]
	if _hover_slot >= _armor_slot_index(0) and _hover_slot < _armor_slot_index(0) + 4:
		return inv.armor_ids[_hover_slot - _armor_slot_index(0)]
	if _hover_slot >= _craft_slot_index(0) and _hover_slot < _craft_slot_index(0) + 4:
		return _craft_ids[_hover_slot - _craft_slot_index(0)]
	if _hover_slot == _craft_out_slot_index():
		return _craft_output_id
	return 0


func _get_hover_item_durability() -> int:
	var inv: Inventory = _get_inv()
	if inv == null:
		return 0
	if _hover_slot >= _hotbar_slot_index(0) and _hover_slot < _hotbar_slot_index(0) + 9:
		var i: int = _hover_slot - _hotbar_slot_index(0)
		return inv.durabilities[i] if i < inv.durabilities.size() else 0
	if _hover_slot >= _storage_slot_index(0) and _hover_slot < _storage_slot_index(0) + 27:
		var i: int = Inventory.HOTBAR_SIZE + (_hover_slot - _storage_slot_index(0))
		return inv.durabilities[i] if i < inv.durabilities.size() else 0
	if _hover_slot >= _armor_slot_index(0) and _hover_slot < _armor_slot_index(0) + 4:
		var i: int = _hover_slot - _armor_slot_index(0)
		return inv.armor_durabilities[i] if i < inv.armor_durabilities.size() else 0
	return 0


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


# Slot index helpers — encode a namespace into a single int
func _armor_slot_index(i: int) -> int:    return 1000 + i
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
	for i: int in 4:
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
		_cursor_durability = 0
		if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
			_hud._sync_slots_from_inventory()


func _slot_rect_at_mouse(mp: Vector2) -> int:
	for i: int in 4:
		if _armor_rects.size() > i and _armor_rects[i].has_point(mp):
			return _armor_slot_index(i)
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
		var slot: int = _slot_rect_at_mouse(event.position)
		_hover_slot = slot
		var inv: Inventory = _get_inv()
		if inv != null and slot >= 0:
			if _lmb_down and _cursor_id != 0:
				_lmb_drag_active = true
				if not _drag_slots.has(slot):
					_drag_slots.append(slot)
			elif _rmb_down and _cursor_id != 0:
				if not _drag_slots.has(slot):
					_drag_slots.append(slot)
					_rmb_drag_active = true
					_deposit_one_to_slot(slot, inv)
					if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
						_hud._sync_slots_from_inventory()
		queue_redraw()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_Q and _cursor_id != 0:
			_cursor_id = 0
			_cursor_count = 0
			_cursor_durability = 0
			queue_redraw()
		# 1-9: swap hovered slot with the corresponding hotbar slot
		if event.keycode >= KEY_1 and event.keycode <= KEY_9 and _cursor_id == 0:
			var key_idx: int = event.keycode - KEY_1  # 0-8
			var inv: Inventory = _get_inv()
			if inv != null and _hover_slot >= 0:
				var did_swap: bool = false
				if _hover_slot >= _storage_slot_index(0) and _hover_slot < _storage_slot_index(27):
					var si: int = Inventory.HOTBAR_SIZE + (_hover_slot - _storage_slot_index(0))
					_swap_inv_slots(inv, si, key_idx)
					did_swap = true
				elif _hover_slot >= _hotbar_slot_index(0) and _hover_slot < _hotbar_slot_index(9):
					var hi: int = _hover_slot - _hotbar_slot_index(0)
					if hi != key_idx:
						_swap_inv_slots(inv, hi, key_idx)
						did_swap = true
				if did_swap:
					if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
						_hud._sync_slots_from_inventory()
					queue_redraw()
					get_viewport().set_input_as_handled()

	if event is InputEventMouseButton:
		_compute_layout()
		var mp: Vector2 = event.position
		var inv: Inventory = _get_inv()
		if inv == null:
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_down = true
				_lmb_drag_active = false
				_drag_slots.clear()
				var slot: int = _slot_rect_at_mouse(mp)
				if slot >= 0:
					_handle_left_click(slot, inv, event.shift_pressed)
					queue_redraw()
					if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
						_hud._sync_slots_from_inventory()
			else:
				if _lmb_drag_active:
					_finish_lmb_drag(inv)
				_lmb_down = false
				_lmb_drag_active = false
				_drag_slots.clear()
				queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_rmb_down = true
				_rmb_drag_active = false
				_drag_slots.clear()
				var slot: int = _slot_rect_at_mouse(mp)
				if slot >= 0:
					_handle_right_click(slot, inv)
					queue_redraw()
					if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
						_hud._sync_slots_from_inventory()
			else:
				_rmb_down = false
				_rmb_drag_active = false
				_drag_slots.clear()
				queue_redraw()
			get_viewport().set_input_as_handled()


func _handle_left_click(slot: int, inv: Inventory, shift: bool) -> void:
	# Craft output: take result, consume inputs
	if slot == _craft_out_slot_index():
		if _craft_output_id == 0:
			return
		if shift:
			# Take as many as possible
			while _craft_output_id != 0:
				var leftover: int = inv.give_item(_craft_output_id, _craft_output_count)
				if leftover > 0:
					break
				_consume_craft_inputs(1)
				_update_craft_output()
		else:
			if _cursor_id == 0 or _cursor_id == _craft_output_id:
				var take: int = _craft_output_count
				var max_s: int = Items.get_max_stack(_craft_output_id)
				var new_count: int = _cursor_count + take
				if new_count <= max_s:
					_cursor_id = _craft_output_id
					_cursor_count = new_count
					_consume_craft_inputs(1)
					_update_craft_output()
		return

	# Armor slots
	if slot >= _armor_slot_index(0) and slot < _armor_slot_index(4):
		var ai: int = slot - _armor_slot_index(0)
		if shift and _cursor_id == 0:
			# Shift-click armor out
			if inv.armor_ids[ai] != 0:
				inv.give_item(inv.armor_ids[ai], 1)
				inv.armor_ids[ai] = 0
			return
		if _cursor_id == 0:
			# Pick up armor
			if inv.armor_ids[ai] != 0:
				_cursor_id = inv.armor_ids[ai]
				_cursor_count = 1
				_cursor_durability = inv.armor_durabilities[ai]
				inv.armor_ids[ai] = 0
				inv.armor_durabilities[ai] = 0
		else:
			# Place armor if it fits this slot
			if (_cursor_id >= 250 and _cursor_id <= 265) and Items.get_armor_slot(_cursor_id) == ai:
				var old_id: int = inv.armor_ids[ai]
				var old_dur: int = inv.armor_durabilities[ai]
				inv.armor_ids[ai] = _cursor_id
				inv.armor_durabilities[ai] = _cursor_durability
				_cursor_id = old_id
				_cursor_count = 1 if old_id != 0 else 0
				_cursor_durability = old_dur if old_id != 0 else 0
		return

	# Craft grid
	if slot >= _craft_slot_index(0) and slot < _craft_slot_index(4):
		var ci: int = slot - _craft_slot_index(0)
		if _cursor_id == 0:
			if shift:
				# Return to inventory
				if _craft_ids[ci] != 0:
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
				var tmp_count: int = _craft_counts[ci]
				_craft_ids[ci] = _cursor_id
				_craft_counts[ci] = _cursor_count
				_cursor_id = tmp_id
				_cursor_count = tmp_count
			_update_craft_output()
		return

	# Storage or hotbar
	var inv_slot: int = _resolve_inv_slot(slot)
	if inv_slot < 0:
		return

	if shift and _cursor_id == 0:
		# Shift-click: move between hotbar and storage
		var id: int = inv.ids[inv_slot]
		var count: int = inv.counts[inv_slot]
		if id == 0:
			return
		inv.ids[inv_slot] = 0
		inv.counts[inv_slot] = 0
		# Move to opposite region
		var target_start: int
		var target_end: int
		if inv_slot < Inventory.HOTBAR_SIZE:
			target_start = Inventory.HOTBAR_SIZE
			target_end = Inventory.TOTAL_SLOTS
		else:
			target_start = 0
			target_end = Inventory.HOTBAR_SIZE
		var leftover: int = count
		var max_s: int = Items.get_max_stack(id)
		for ti: int in range(target_start, target_end):
			if leftover <= 0:
				break
			if inv.ids[ti] == id and inv.counts[ti] < max_s:
				var add: int = mini(leftover, max_s - inv.counts[ti])
				inv.counts[ti] += add
				leftover -= add
		for ti: int in range(target_start, target_end):
			if leftover <= 0:
				break
			if inv.ids[ti] == 0:
				inv.ids[ti] = id
				inv.counts[ti] = mini(leftover, max_s)
				leftover -= inv.counts[ti]
		if leftover > 0:
			inv.ids[inv_slot] = id
			inv.counts[inv_slot] = leftover
		return

	if _cursor_id == 0:
		# Pick up
		_cursor_id = inv.ids[inv_slot]
		_cursor_count = inv.counts[inv_slot]
		_cursor_durability = inv.durabilities[inv_slot]
		inv.ids[inv_slot] = 0
		inv.counts[inv_slot] = 0
		inv.durabilities[inv_slot] = 0
	else:
		# Place or swap
		if inv.ids[inv_slot] == 0:
			inv.ids[inv_slot] = _cursor_id
			inv.counts[inv_slot] = _cursor_count
			inv.durabilities[inv_slot] = _cursor_durability
			_cursor_id = 0
			_cursor_count = 0
			_cursor_durability = 0
		elif inv.ids[inv_slot] == _cursor_id:
			var max_s: int = Items.get_max_stack(_cursor_id)
			var add: int = mini(_cursor_count, max_s - inv.counts[inv_slot])
			if add > 0:
				inv.counts[inv_slot] += add
				_cursor_count -= add
				if _cursor_count == 0:
					_cursor_id = 0
					_cursor_durability = 0
			else:
				# Slot is full (e.g. two tools of the same type) — swap with durability
				var tmp_count: int = inv.counts[inv_slot]
				var tmp_dur: int = inv.durabilities[inv_slot]
				inv.counts[inv_slot] = _cursor_count
				inv.durabilities[inv_slot] = _cursor_durability
				_cursor_count = tmp_count
				_cursor_durability = tmp_dur
		else:
			var tmp_id: int = inv.ids[inv_slot]
			var tmp_count: int = inv.counts[inv_slot]
			var tmp_dur: int = inv.durabilities[inv_slot]
			inv.ids[inv_slot] = _cursor_id
			inv.counts[inv_slot] = _cursor_count
			inv.durabilities[inv_slot] = _cursor_durability
			_cursor_id = tmp_id
			_cursor_count = tmp_count
			_cursor_durability = tmp_dur


func _handle_right_click(slot: int, inv: Inventory) -> void:
	if slot == _craft_out_slot_index():
		_handle_left_click(slot, inv, false)
		return

	if slot >= _craft_slot_index(0) and slot < _craft_slot_index(4):
		var ci: int = slot - _craft_slot_index(0)
		if _cursor_id != 0:
			# Place one
			if _craft_ids[ci] == 0 or _craft_ids[ci] == _cursor_id:
				_craft_ids[ci] = _cursor_id
				_craft_counts[ci] = _craft_counts[ci] + 1
				_cursor_count -= 1
				if _cursor_count == 0:
					_cursor_id = 0
				_update_craft_output()
		else:
			# Pick up half
			if _craft_ids[ci] != 0:
				var half: int = ceili(float(_craft_counts[ci]) / 2.0)
				_cursor_id = _craft_ids[ci]
				_cursor_count = half
				_craft_counts[ci] -= half
				if _craft_counts[ci] == 0:
					_craft_ids[ci] = 0
				_update_craft_output()
		return

	var inv_slot: int = _resolve_inv_slot(slot)
	if inv_slot < 0:
		return

	if _cursor_id != 0:
		# Place one
		if inv.ids[inv_slot] == 0 or inv.ids[inv_slot] == _cursor_id:
			var max_s: int = Items.get_max_stack(_cursor_id)
			if inv.counts[inv_slot] < max_s:
				inv.ids[inv_slot] = _cursor_id
				inv.counts[inv_slot] = inv.counts[inv_slot] + 1
				_cursor_count -= 1
				if _cursor_count == 0:
					_cursor_id = 0
	else:
		# Pick up half
		if inv.ids[inv_slot] != 0:
			var half: int = ceili(float(inv.counts[inv_slot]) / 2.0)
			_cursor_id = inv.ids[inv_slot]
			_cursor_count = half
			_cursor_durability = inv.durabilities[inv_slot]
			inv.counts[inv_slot] -= half
			if inv.counts[inv_slot] == 0:
				inv.ids[inv_slot] = 0
				inv.durabilities[inv_slot] = 0


func _resolve_inv_slot(slot: int) -> int:
	if slot >= _hotbar_slot_index(0) and slot < _hotbar_slot_index(9):
		return slot - _hotbar_slot_index(0)
	if slot >= _storage_slot_index(0) and slot < _storage_slot_index(27):
		return Inventory.HOTBAR_SIZE + (slot - _storage_slot_index(0))
	return -1


func _finish_lmb_drag(inv: Inventory) -> void:
	if _cursor_id == 0 or _drag_slots.size() < 2:
		return
	var valid_slots: Array[int] = []
	for s: int in _drag_slots:
		var inv_slot: int = _resolve_inv_slot(s)
		if inv_slot < 0:
			continue
		var ms: int = Items.get_max_stack(_cursor_id)
		if inv.ids[inv_slot] == 0 or (inv.ids[inv_slot] == _cursor_id and inv.counts[inv_slot] < ms):
			valid_slots.append(inv_slot)
	if valid_slots.is_empty():
		return
	var per_slot: int = maxi(1, _cursor_count / valid_slots.size())
	var remaining: int = _cursor_count
	for inv_slot: int in valid_slots:
		if remaining <= 0:
			break
		var ms: int = Items.get_max_stack(_cursor_id)
		var current: int = inv.counts[inv_slot] if inv.ids[inv_slot] == _cursor_id else 0
		var space: int = ms - current
		var deposit: int = mini(per_slot, mini(remaining, space))
		if deposit <= 0:
			continue
		inv.ids[inv_slot] = _cursor_id
		inv.counts[inv_slot] = current + deposit
		remaining -= deposit
	_cursor_count = remaining
	if _cursor_count == 0:
		_cursor_id = 0
	if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
		_hud._sync_slots_from_inventory()


func _deposit_one_to_slot(slot: int, inv: Inventory) -> void:
	var inv_slot: int = _resolve_inv_slot(slot)
	if inv_slot < 0 or _cursor_id == 0:
		return
	var ms: int = Items.get_max_stack(_cursor_id)
	if (inv.ids[inv_slot] == 0 or inv.ids[inv_slot] == _cursor_id) and inv.counts[inv_slot] < ms:
		inv.ids[inv_slot] = _cursor_id
		inv.counts[inv_slot] += 1
		_cursor_count -= 1
		if _cursor_count == 0:
			_cursor_id = 0


func _swap_inv_slots(inv: Inventory, a: int, b: int) -> void:
	var tmp_id: int = inv.ids[a]
	var tmp_count: int = inv.counts[a]
	var tmp_dur: int = inv.durabilities[a]
	inv.ids[a] = inv.ids[b]
	inv.counts[a] = inv.counts[b]
	inv.durabilities[a] = inv.durabilities[b]
	inv.ids[b] = tmp_id
	inv.counts[b] = tmp_count
	inv.durabilities[b] = tmp_dur


func _consume_craft_inputs(times: int) -> void:
	for _t: int in times:
		for i: int in 4:
			if _craft_ids[i] != 0:
				_craft_counts[i] -= 1
				if _craft_counts[i] <= 0:
					_craft_ids[i] = 0
					_craft_counts[i] = 0
