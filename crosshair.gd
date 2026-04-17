extends Control

const SIZE: int = 12
const THICK: int = 2


func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size / 2.0 - global_position
	var col := Color(1, 1, 1, 0.8)

	# Horizontal bar
	draw_rect(Rect2(center.x - SIZE, center.y - THICK / 2.0, SIZE * 2, THICK), col)
	# Vertical bar
	draw_rect(Rect2(center.x - THICK / 2.0, center.y - SIZE, THICK, SIZE * 2), col)
