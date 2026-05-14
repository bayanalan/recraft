extends Control

const HEART_SIZE: int = 18
const HEART_GAP: int = 2
const NUM_HEARTS: int = 10
const ROW_H: int = HEART_SIZE + 4

# Colors for the heart pixel art
const HEART_RED      := Color(0.80, 0.15, 0.15)
const HEART_DARK_RED := Color(0.45, 0.05, 0.05)
const HEART_EMPTY    := Color(0.35, 0.35, 0.35, 0.90)
const HEART_OUTLINE  := Color(0.08, 0.08, 0.08)
const ARMOR_COL      := Color(0.70, 0.78, 0.82)
const ARMOR_DARK     := Color(0.40, 0.45, 0.50)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var hud: Node = get_parent()
	if hud == null:
		return
	var hp: int = hud.player_health if hud.has_method("update_health") or "player_health" in hud else 20
	var max_hp: int = hud.player_max_health if "player_max_health" in hud else 20
	var armor: int = hud.player_armor if "player_armor" in hud else 0

	var vp: Vector2 = get_viewport_rect().size

	# Position above the hotbar
	var hotbar_h: float = 54.0 + 12.0
	var total_w: float = float(NUM_HEARTS * (HEART_SIZE + HEART_GAP) - HEART_GAP)
	var start_x: float = (vp.x - total_w) / 2.0
	var start_y: float = vp.y - hotbar_h - ROW_H - 4.0

	# Draw armor bar above hearts if player has armor
	if armor > 0:
		var armor_y: float = start_y - ROW_H
		_draw_armor_bar(start_x, armor_y, armor)
		start_y = armor_y + ROW_H

	# Draw hearts
	var half_hearts: int = clampi(hp, 0, max_hp)
	for i: int in NUM_HEARTS:
		var hx: float = start_x + float(i) * float(HEART_SIZE + HEART_GAP)
		var filled_halves: int = clamp(half_hearts - i * 2, 0, 2)
		_draw_heart(hx, start_y, filled_halves)


func _draw_heart(x: float, y: float, filled_halves: int) -> void:
	# 9x9 pixel heart shape — classic Minecraft heart outline
	# The heart shape as a 9x9 bitmask (rows from top to bottom)
	const MASK: Array[int] = [
		0b000000000,
		0b011001100,
		0b111111110,
		0b111111110,
		0b111111110,
		0b011111100,
		0b001111000,
		0b000110000,
		0b000000000,
	]
	for py: int in 9:
		var row: int = MASK[py]
		for px: int in 9:
			if (row >> (8 - px)) & 1 == 0:
				continue
			var is_left: bool = px < 4
			var is_filled: bool = (filled_halves == 2) or (filled_halves == 1 and is_left)
			var col: Color
			if is_filled:
				col = HEART_RED if px > 0 and px < 8 and py > 0 and py < 8 else HEART_DARK_RED
			else:
				col = HEART_EMPTY
			draw_rect(Rect2(x + px, y + py, 1, 1), col)
	# Outline pixels (corners / outside)
	for py: int in [1, 2]:
		for px: int in [1, 2, 5, 6]:
			if (MASK[py] >> (8 - px)) & 1 == 1:
				draw_rect(Rect2(x + px - 1, y + py, 1, 1), HEART_OUTLINE)


func _draw_armor_bar(start_x: float, y: float, armor: int) -> void:
	# Draw shield icons representing armor points (each shield = 1 armor point)
	var visible_points: int = mini(armor, 20)
	for i: int in 10:
		var ax: float = start_x + float(i) * float(HEART_SIZE + HEART_GAP)
		var filled: int = clamp(visible_points - i * 2, 0, 2)
		_draw_armor_icon(ax, y, filled)


func _draw_armor_icon(x: float, y: float, filled: int) -> void:
	# Simple shield shape: 9x9
	# Shield outline
	var shield_col: Color = ARMOR_COL if filled > 0 else ARMOR_DARK
	# Top row of shield
	draw_rect(Rect2(x + 1, y + 0, 7, 2), shield_col)
	# Middle section
	draw_rect(Rect2(x + 0, y + 2, 9, 4), shield_col)
	# Lower taper
	draw_rect(Rect2(x + 1, y + 6, 7, 1), shield_col)
	draw_rect(Rect2(x + 2, y + 7, 5, 1), shield_col)
	draw_rect(Rect2(x + 3, y + 8, 3, 1), shield_col)
	# Empty tint
	if filled == 0:
		draw_rect(Rect2(x + 1, y + 0, 7, 9), Color(0.2, 0.2, 0.2, 0.5))
