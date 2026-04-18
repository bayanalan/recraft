extends CanvasLayer

var selected_slot: int = 0
var slots: Array[int] = [
	Chunk.Block.STONE,
	Chunk.Block.COBBLESTONE,
	Chunk.Block.DIRT,
	Chunk.Block.GRASS,
	Chunk.Block.PLANKS,
	Chunk.Block.LOG,
	Chunk.Block.LEAVES,
	Chunk.Block.SAND,
	Chunk.Block.GLASS,
]

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
	crosshair.queue_redraw()
	hotbar.queue_redraw()
	if block_select != null:
		block_select.block_selected.connect(_on_block_selected)


var _hud_visible: bool = true

func _unhandled_input(event: InputEvent) -> void:
	# F1 toggles HUD visibility (hotbar, crosshair, overlays). Block-select
	# inventory is excluded — it has its own open/close flow.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_hud_visible = not _hud_visible
		crosshair.visible = _hud_visible
		hotbar.visible = _hud_visible
		water_overlay.visible = _hud_visible and water_overlay.visible
		lava_overlay.visible = _hud_visible and lava_overlay.visible
		if has_node("HeldItem"):
			get_node("HeldItem").visible = _hud_visible
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


# Assign a block to the currently selected hotbar slot.
func set_selected_block(block: int) -> void:
	slots[selected_slot] = block
	hotbar.queue_redraw()


func open_block_select() -> void:
	if block_select != null:
		block_select.open()


func is_block_select_open() -> bool:
	return block_select != null and block_select.visible


func is_chat_open() -> bool:
	var chat: Node = get_node_or_null("Chat")
	return chat != null and chat.is_chat_open()


func _on_block_selected(block: int) -> void:
	set_selected_block(block)
