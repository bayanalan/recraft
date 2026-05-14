extends CanvasLayer

var selected_slot: int = 0
var slots: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]

var inventory: Inventory = Inventory.new()
var player_health: int = 20
var player_max_health: int = 20
var player_armor: int = 0

@onready var crosshair: Control = $Crosshair
@onready var hotbar: Control = $Hotbar
@onready var block_select: Control = $BlockSelect
@onready var water_overlay: ColorRect = $WaterOverlay
@onready var lava_overlay: ColorRect = $LavaOverlay


func set_underwater(in_water: bool) -> void:
	if water_overlay != null:
		water_overlay.visible = in_water and _hud_visible


func set_in_lava(in_lava: bool) -> void:
	if lava_overlay != null:
		lava_overlay.visible = in_lava and _hud_visible


func _ready() -> void:
	# Seed hotbar with classic blocks for new survival worlds
	var starter: Array[int] = [
		Chunk.Block.STONE, Chunk.Block.COBBLESTONE, Chunk.Block.DIRT,
		Chunk.Block.GRASS, Chunk.Block.PLANKS, Chunk.Block.LOG,
		Chunk.Block.LEAVES, Chunk.Block.SAND, Chunk.Block.GLASS,
	]
	for i: int in 9:
		inventory.set_slot(i, starter[i], 64)
	_sync_slots_from_inventory()

	crosshair.queue_redraw()
	hotbar.queue_redraw()
	if block_select != null:
		block_select.block_selected.connect(_on_block_selected)


func _sync_slots_from_inventory() -> void:
	for i: int in 9:
		slots[i] = inventory.ids[i]
	if hotbar != null:
		hotbar.queue_redraw()


var _hud_visible: bool = true

func _unhandled_input(event: InputEvent) -> void:
	# F1 toggles HUD visibility
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_hud_visible = not _hud_visible
		crosshair.visible = _hud_visible
		hotbar.visible = _hud_visible
		water_overlay.visible = _hud_visible and water_overlay.visible
		lava_overlay.visible = _hud_visible and lava_overlay.visible
		if has_node("HeldItem"):
			get_node("HeldItem").visible = _hud_visible
		if has_node("HealthDisplay"):
			get_node("HealthDisplay").visible = _hud_visible
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_slot = (selected_slot - 1 + slots.size()) % slots.size()
			hotbar.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_slot = (selected_slot + 1) % slots.size()
			hotbar.queue_redraw()

	if event is InputEventKey and event.pressed:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var idx: int = key - KEY_1
			if idx < slots.size():
				selected_slot = idx
				hotbar.queue_redraw()


func get_selected_block() -> int:
	return slots[selected_slot]


func set_selected_block(block: int) -> void:
	inventory.set_slot(selected_slot, block, 64)
	slots[selected_slot] = block
	hotbar.queue_redraw()


func update_health(hp: int) -> void:
	player_health = hp
	var hd: Node = get_node_or_null("HealthDisplay")
	if hd != null:
		hd.queue_redraw()


func get_armor_value() -> int:
	var total: int = 0
	for i: int in 4:
		total += Items.get_armor_value(inventory.armor_ids[i])
	player_armor = total
	return total


func give_item(id: int, count: int) -> bool:
	var leftover: int = inventory.give_item(id, count)
	_sync_slots_from_inventory()
	return leftover == 0


func open_inventory() -> void:
	var inv_ui: Node = get_node_or_null("InventoryUI")
	if inv_ui != null and inv_ui.has_method("open"):
		inv_ui.open()


func close_inventory() -> void:
	var inv_ui: Node = get_node_or_null("InventoryUI")
	if inv_ui != null and inv_ui.has_method("close"):
		inv_ui.close()


func open_crafting_table() -> void:
	var ct_ui: Node = get_node_or_null("CraftingTableUI")
	if ct_ui != null and ct_ui.has_method("open"):
		ct_ui.open()


func open_furnace(pos: Vector3i) -> void:
	var f_ui: Node = get_node_or_null("FurnaceUI")
	if f_ui != null and f_ui.has_method("open"):
		f_ui.open(pos)


func open_block_select() -> void:
	if block_select != null:
		block_select.open()


func is_block_select_open() -> bool:
	return block_select != null and block_select.visible


func is_inventory_open() -> bool:
	var inv_ui: Node = get_node_or_null("InventoryUI")
	return inv_ui != null and inv_ui.visible


func is_chat_open() -> bool:
	var chat: Node = get_node_or_null("Chat")
	return chat != null and chat.is_chat_open()


func _on_block_selected(block: int) -> void:
	set_selected_block(block)
