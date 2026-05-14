extends Control

const SLOT_SIZE:  int = 48
const BLOCK_S:    float = 14.0
const COLS:       int = 9
const STORAGE_ROWS: int = 3

const BAR_TINT    := Color(0.45, 0.45, 0.45, 0.95)
const BAR_DARK    := Color(0.12, 0.12, 0.13, 1.0)
const BAR_LIGHT   := Color(0.68, 0.68, 0.66, 1.0)
const SLOT_BG     := Color(0.0, 0.0, 0.0, 0.35)
const SLOT_HOVER  := Color(1.0, 1.0, 1.0, 0.25)
const LABEL_COL   := Color(1.0, 1.0, 1.0, 0.95)
const FIRE_ON     := Color(0.98, 0.52, 0.10)
const FIRE_OFF    := Color(0.35, 0.35, 0.35)
const ARROW_COL   := Color(0.90, 0.75, 0.20)

const SMELT_TIME:     float = 10.0
const COAL_FUEL_TIME: float = 80.0

# Smelting recipes: input id -> output id
const SMELT_RECIPES: Dictionary = {
	Items.RAW_IRON:             Items.IRON_INGOT,
	Items.RAW_GOLD:             Items.GOLD_INGOT,
	Chunk.Block.IRON_ORE:       Items.IRON_INGOT,
	Chunk.Block.GOLD_ORE:       Items.GOLD_INGOT,
	Chunk.Block.SAND:           Chunk.Block.GLASS,
}

var _atlas: Texture2D = null
var _hud: Node = null

# The furnace position in the world (used as key for persistent state)
var furnace_pos: Vector3i = Vector3i.ZERO

# Furnace state
var input_id:    int = 0
var input_count: int = 0
var fuel_id:     int = 0
var fuel_count:  int = 0
var output_id:   int = 0
var output_count: int = 0
var smelt_time:   float = 0.0   # remaining time for current item
var fuel_remaining: float = 0.0  # fuel left in seconds
var _is_smelting: bool = false
var _smelt_total: float = SMELT_TIME

var _cursor_id: int = 0
var _cursor_count: int = 0
var _hover_slot: int = -1

var _panel_rect:    Rect2 = Rect2()
var _input_rect:    Rect2 = Rect2()
var _fuel_rect:     Rect2 = Rect2()
var _output_rect:   Rect2 = Rect2()
var _storage_rects: Array[Rect2] = []
var _hotbar_rects:  Array[Rect2] = []
var _layout_valid:  bool = false

const S_INPUT:  int = 5000
const S_FUEL:   int = 5001
const S_OUTPUT: int = 5002
func _storage_slot_index(i: int) -> int: return 3000 + i
func _hotbar_slot_index(i: int) -> int:  return 4000 + i


func _ready() -> void:
	_atlas = BlockTextures.create_icon_atlas()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud = get_parent()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(pos: Vector3i) -> void:
	furnace_pos = pos
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout_valid = false
	queue_redraw()


func close() -> void:
	_return_contents()
	_drop_cursor()
	visible = false
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _return_contents() -> void:
	var inv: Inventory = _get_inv()
	if inv == null:
		return
	if input_id != 0:
		inv.give_item(input_id, input_count)
		input_id = 0; input_count = 0
	if fuel_id != 0:
		inv.give_item(fuel_id, fuel_count)
		fuel_id = 0; fuel_count = 0
	if output_id != 0:
		inv.give_item(output_id, output_count)
		output_id = 0; output_count = 0
	smelt_time = 0.0
	_is_smelting = false
	if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
		_hud._sync_slots_from_inventory()


func _drop_cursor() -> void:
	if _cursor_id != 0:
		var inv: Inventory = _get_inv()
		if inv != null:
			inv.give_item(_cursor_id, _cursor_count)
		_cursor_id = 0; _cursor_count = 0
		if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
			_hud._sync_slots_from_inventory()


func _process(delta: float) -> void:
	if not visible:
		return
	_tick(delta)
	queue_redraw()


func _tick(delta: float) -> void:
	if not _is_smelting:
		# Try to start smelting
		if input_id != 0 and SMELT_RECIPES.has(input_id) and fuel_remaining <= 0.0:
			# Need fuel
			if fuel_id == Items.COAL and fuel_count > 0:
				fuel_count -= 1
				if fuel_count == 0:
					fuel_id = 0
				fuel_remaining = COAL_FUEL_TIME
				_is_smelting = true
				smelt_time = SMELT_TIME
				_smelt_total = SMELT_TIME
		elif input_id != 0 and SMELT_RECIPES.has(input_id) and fuel_remaining > 0.0:
			_is_smelting = true
			smelt_time = SMELT_TIME
			_smelt_total = SMELT_TIME
		return

	# Already smelting
	if input_id == 0 or not SMELT_RECIPES.has(input_id):
		_is_smelting = false
		smelt_time = 0.0
		return

	fuel_remaining = maxf(0.0, fuel_remaining - delta)
	smelt_time = maxf(0.0, smelt_time - delta)

	if smelt_time <= 0.0:
		# Finish smelting one item
		var result_id: int = SMELT_RECIPES.get(input_id, 0)
		if result_id != 0:
			var ms: int = Items.get_max_stack(result_id)
			if output_count < ms and (output_id == result_id or output_id == 0):
				output_id = result_id
				output_count += 1
				input_count -= 1
				if input_count <= 0:
					input_id = 0
					input_count = 0
		_is_smelting = false
		smelt_time = 0.0

		# Refuel if possible and input remains
		if input_id != 0 and SMELT_RECIPES.has(input_id):
			if fuel_remaining <= 0.0 and fuel_id == Items.COAL and fuel_count > 0:
				fuel_count -= 1
				if fuel_count == 0: fuel_id = 0
				fuel_remaining = COAL_FUEL_TIME
			if fuel_remaining > 0.0:
				_is_smelting = true
				smelt_time = SMELT_TIME
				_smelt_total = SMELT_TIME


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

	# Input (top-left)
	_input_rect = Rect2(col_x + 10, row_y, SLOT_SIZE, SLOT_SIZE)
	# Fuel (below input)
	_fuel_rect = Rect2(col_x + 10, row_y + SLOT_SIZE + 16, SLOT_SIZE, SLOT_SIZE)
	# Output (right)
	_output_rect = Rect2(col_x + 10 + SLOT_SIZE + 80, row_y + SLOT_SIZE * 0.5 - SLOT_SIZE * 0.5, SLOT_SIZE, SLOT_SIZE)

	# Storage
	_storage_rects.clear()
	var storage_y: float = row_y + SLOT_SIZE * 2 + 40
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
		"Furnace", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(20), LABEL_COL)

	var inv: Inventory = _get_inv()

	# Labels
	draw_string(font, Vector2(_input_rect.position.x, _input_rect.position.y - 14),
		"Input", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(13), Color(0.8, 0.8, 0.8))
	draw_string(font, Vector2(_fuel_rect.position.x, _fuel_rect.position.y - 14),
		"Fuel", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(13), Color(0.8, 0.8, 0.8))
	draw_string(font, Vector2(_output_rect.position.x, _output_rect.position.y - 14),
		"Output", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(13), Color(0.8, 0.8, 0.8))

	# Input slot
	_draw_slot(_input_rect, _hover_slot == S_INPUT)
	if input_id != 0:
		_draw_item_centered(_input_rect, input_id, input_count)

	# Fire animation between input/output
	var fire_x: float = _fuel_rect.position.x + SLOT_SIZE * 0.5 - 6
	var fire_y: float = _fuel_rect.position.y - 12
	_draw_fire_indicator(fire_x, fire_y)

	# Fuel slot
	_draw_slot(_fuel_rect, _hover_slot == S_FUEL)
	if fuel_id != 0:
		_draw_item_centered(_fuel_rect, fuel_id, fuel_count)

	# Progress arrow
	var arrow_x: float = _input_rect.position.x + SLOT_SIZE + 10
	var arrow_y: float = _input_rect.position.y + SLOT_SIZE * 0.5 + 6
	_draw_progress_arrow(arrow_x, arrow_y)

	# Output slot
	_draw_slot(_output_rect, _hover_slot == S_OUTPUT, output_id != 0)
	if output_id != 0:
		_draw_item_centered(_output_rect, output_id, output_count)

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
	draw_string(font, Vector2(_panel_rect.position.x + 12, _hotbar_rects[0].position.y - 6),
		"Hotbar", HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(14), Color(0.8, 0.8, 0.8))
	for i: int in _hotbar_rects.size():
		var r: Rect2 = _hotbar_rects[i]
		_draw_slot(r, _hover_slot == _hotbar_slot_index(i))
		if inv != null and inv.ids[i] != 0:
			_draw_item_centered(r, inv.ids[i], inv.counts[i])

	# Cursor
	if _cursor_id != 0:
		var mp: Vector2 = get_viewport().get_mouse_position()
		_draw_item_at(mp.x, mp.y, _cursor_id, _cursor_count)


func _draw_fire_indicator(x: float, y: float) -> void:
	var on: bool = _is_smelting and fuel_remaining > 0.0
	var col: Color = FIRE_ON if on else FIRE_OFF
	# Small flame icon (5x8 pixels)
	draw_rect(Rect2(x + 1, y + 0, 3, 2), col)
	draw_rect(Rect2(x + 0, y + 1, 5, 2), col)
	draw_rect(Rect2(x + 0, y + 3, 5, 3), col.lightened(0.2) if on else col)
	draw_rect(Rect2(x + 1, y + 6, 3, 2), col.darkened(0.2) if on else col)
	if on:
		draw_rect(Rect2(x + 1, y + 1, 1, 3), Color(1.0, 0.9, 0.4))


func _draw_progress_arrow(x: float, y: float) -> void:
	var progress: float = 0.0
	if _is_smelting and _smelt_total > 0.0:
		progress = 1.0 - (smelt_time / _smelt_total)
	var bar_w: float = 30.0
	var filled_w: float = bar_w * progress
	draw_rect(Rect2(x, y - 4, bar_w, 8), FIRE_OFF)
	if filled_w > 0:
		draw_rect(Rect2(x, y - 4, filled_w, 8), ARROW_COL)
	# Arrow tip
	draw_rect(Rect2(x + bar_w, y - 6, 2, 12), ARROW_COL)
	draw_rect(Rect2(x + bar_w + 2, y - 4, 2, 8), ARROW_COL)
	draw_rect(Rect2(x + bar_w + 4, y - 2, 2, 4), ARROW_COL)


func _draw_slot(r: Rect2, hovered: bool, bright: bool = false) -> void:
	draw_rect(r, SLOT_BG)
	if hovered: draw_rect(r, SLOT_HOVER)
	if bright:  draw_rect(r, Color(0.9, 0.85, 0.2, 0.15))
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
		Items.draw_item_icon(self, cx, cy + BLOCK_S * BlockIcon.CUBE_H * 0.5, BLOCK_S * 2.0, id)
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
			if w <= 0 or h <= 0: continue
			draw_texture_rect_region(_atlas, Rect2(dx, dy, w, h), Rect2(Vector2(0, 0), Vector2(w, h)), tint)


func _get_inv() -> Inventory:
	if _hud != null and "inventory" in _hud:
		return _hud.inventory
	return null


func _slot_rect_at_mouse(mp: Vector2) -> int:
	if _input_rect.has_point(mp):  return S_INPUT
	if _fuel_rect.has_point(mp):   return S_FUEL
	if _output_rect.has_point(mp): return S_OUTPUT
	for i: int in _storage_rects.size():
		if _storage_rects[i].has_point(mp): return _storage_slot_index(i)
	for i: int in _hotbar_rects.size():
		if _hotbar_rects[i].has_point(mp): return _hotbar_slot_index(i)
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

	if event is InputEventMouseButton and event.pressed:
		_compute_layout()
		var mp: Vector2 = event.position
		var slot: int = _slot_rect_at_mouse(mp)
		if slot < 0: return
		var inv: Inventory = _get_inv()
		if inv == null: return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(slot, inv, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(slot, inv)
		queue_redraw()
		if _hud != null and _hud.has_method("_sync_slots_from_inventory"):
			_hud._sync_slots_from_inventory()
		get_viewport().set_input_as_handled()


func _handle_left_click(slot: int, inv: Inventory, shift: bool) -> void:
	if slot == S_OUTPUT:
		if output_id == 0: return
		if _cursor_id == 0 or _cursor_id == output_id:
			var ms: int = Items.get_max_stack(output_id)
			var can_add: int = ms - _cursor_count
			if can_add > 0:
				var take: int = mini(output_count, can_add)
				_cursor_id = output_id
				_cursor_count += take
				output_count -= take
				if output_count == 0: output_id = 0
		return

	if slot == S_INPUT:
		if _cursor_id == 0:
			if shift and input_id != 0:
				inv.give_item(input_id, input_count)
				input_id = 0; input_count = 0
			else:
				_cursor_id = input_id; _cursor_count = input_count
				input_id = 0; input_count = 0
		else:
			if input_id == 0:
				input_id = _cursor_id; input_count = _cursor_count
				_cursor_id = 0; _cursor_count = 0
			elif input_id == _cursor_id:
				var ms: int = Items.get_max_stack(_cursor_id)
				var a: int = mini(_cursor_count, ms - input_count)
				input_count += a; _cursor_count -= a
				if _cursor_count == 0: _cursor_id = 0
			else:
				var ti: int = input_id; var tc: int = input_count
				input_id = _cursor_id; input_count = _cursor_count
				_cursor_id = ti; _cursor_count = tc
		return

	if slot == S_FUEL:
		if _cursor_id == 0:
			if shift and fuel_id != 0:
				inv.give_item(fuel_id, fuel_count)
				fuel_id = 0; fuel_count = 0
			else:
				_cursor_id = fuel_id; _cursor_count = fuel_count
				fuel_id = 0; fuel_count = 0
		else:
			if fuel_id == 0:
				fuel_id = _cursor_id; fuel_count = _cursor_count
				_cursor_id = 0; _cursor_count = 0
			elif fuel_id == _cursor_id:
				var ms: int = Items.get_max_stack(_cursor_id)
				var a: int = mini(_cursor_count, ms - fuel_count)
				fuel_count += a; _cursor_count -= a
				if _cursor_count == 0: _cursor_id = 0
			else:
				var ti: int = fuel_id; var tc: int = fuel_count
				fuel_id = _cursor_id; fuel_count = _cursor_count
				_cursor_id = ti; _cursor_count = tc
		return

	var inv_slot: int = _resolve_inv_slot(slot)
	if inv_slot < 0: return

	if shift and _cursor_id == 0:
		var id: int = inv.ids[inv_slot]; var cnt: int = inv.counts[inv_slot]
		if id == 0: return
		inv.ids[inv_slot] = 0; inv.counts[inv_slot] = 0
		var ts: int = 0 if inv_slot < Inventory.HOTBAR_SIZE else Inventory.HOTBAR_SIZE
		var te: int = Inventory.HOTBAR_SIZE if inv_slot < Inventory.HOTBAR_SIZE else Inventory.TOTAL_SLOTS
		var lft: int = cnt; var ms: int = Items.get_max_stack(id)
		for ti: int in range(ts, te):
			if lft <= 0: break
			if inv.ids[ti] == id and inv.counts[ti] < ms:
				var a: int = mini(lft, ms - inv.counts[ti]); inv.counts[ti] += a; lft -= a
		for ti: int in range(ts, te):
			if lft <= 0: break
			if inv.ids[ti] == 0:
				inv.ids[ti] = id; inv.counts[ti] = mini(lft, ms); lft -= inv.counts[ti]
		if lft > 0: inv.ids[inv_slot] = id; inv.counts[inv_slot] = lft
		return

	if _cursor_id == 0:
		_cursor_id = inv.ids[inv_slot]; _cursor_count = inv.counts[inv_slot]
		inv.ids[inv_slot] = 0; inv.counts[inv_slot] = 0
	else:
		if inv.ids[inv_slot] == 0:
			inv.ids[inv_slot] = _cursor_id; inv.counts[inv_slot] = _cursor_count
			_cursor_id = 0; _cursor_count = 0
		elif inv.ids[inv_slot] == _cursor_id:
			var ms: int = Items.get_max_stack(_cursor_id)
			var a: int = mini(_cursor_count, ms - inv.counts[inv_slot])
			inv.counts[inv_slot] += a; _cursor_count -= a
			if _cursor_count == 0: _cursor_id = 0
		else:
			var ti: int = inv.ids[inv_slot]; var tc: int = inv.counts[inv_slot]
			inv.ids[inv_slot] = _cursor_id; inv.counts[inv_slot] = _cursor_count
			_cursor_id = ti; _cursor_count = tc


func _handle_right_click(slot: int, inv: Inventory) -> void:
	if slot == S_OUTPUT:
		_handle_left_click(slot, inv, false)
		return
	if slot == S_INPUT or slot == S_FUEL:
		_handle_left_click(slot, inv, false)
		return
	var inv_slot: int = _resolve_inv_slot(slot)
	if inv_slot < 0: return
	if _cursor_id != 0:
		if inv.ids[inv_slot] == 0 or inv.ids[inv_slot] == _cursor_id:
			var ms: int = Items.get_max_stack(_cursor_id)
			if inv.counts[inv_slot] < ms:
				inv.ids[inv_slot] = _cursor_id; inv.counts[inv_slot] += 1
				_cursor_count -= 1
				if _cursor_count == 0: _cursor_id = 0
	else:
		if inv.ids[inv_slot] != 0:
			var half: int = ceili(float(inv.counts[inv_slot]) / 2.0)
			_cursor_id = inv.ids[inv_slot]; _cursor_count = half
			inv.counts[inv_slot] -= half
			if inv.counts[inv_slot] == 0: inv.ids[inv_slot] = 0


func _resolve_inv_slot(slot: int) -> int:
	if slot >= _hotbar_slot_index(0) and slot < _hotbar_slot_index(9):
		return slot - _hotbar_slot_index(0)
	if slot >= _storage_slot_index(0) and slot < _storage_slot_index(27):
		return Inventory.HOTBAR_SIZE + (slot - _storage_slot_index(0))
	return -1
