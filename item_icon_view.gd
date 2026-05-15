extends Control
class_name ItemIconView

var _icon_id: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	Items.draw_item_icon(self, 32.0, 32.0, 32.0, _icon_id)
