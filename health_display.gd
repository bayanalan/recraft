extends Control

const HEART_PX: int = 2              # screen pixels per logical heart pixel
const HEART_SIZE: int = 9 * HEART_PX # 18 — matches logical 9×9 at 2× scale
const HEART_GAP: int = 2
const NUM_HEARTS: int = 10
const ROW_H: int = HEART_SIZE + 4

# Mirror hotbar geometry so hearts align exactly above slot 1
const _HOTBAR_SLOTS: int = 9
const _HOTBAR_SLOT_SIZE: float = 48.0
const _HOTBAR_BAR_PAD: float = 3.0

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

	# Align hearts to the left edge of the hotbar (slot 1), like Minecraft
	var hotbar_bar_w: float = _HOTBAR_SLOTS * _HOTBAR_SLOT_SIZE + _HOTBAR_BAR_PAD * 2.0
	var hotbar_bar_x: float = (vp.x - hotbar_bar_w) / 2.0
	var start_x: float = hotbar_bar_x + _HOTBAR_BAR_PAD
	# Bar height = SLOT_SIZE(48) + PAD*2(6) = 54; offset from bottom = 12
	var hotbar_h: float = 54.0 + 12.0
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
	var p: float = float(HEART_PX)
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
			draw_rect(Rect2(x + px * p, y + py * p, p, p), col)
	# Outline
	for py: int in [1, 2]:
		for px: int in [1, 2, 5, 6]:
			if (MASK[py] >> (8 - px)) & 1 == 1:
				draw_rect(Rect2(x + (px - 1) * p, y + py * p, p, p), HEART_OUTLINE)


func _draw_armor_bar(start_x: float, y: float, armor: int) -> void:
	# Draw shield icons representing armor points (each shield = 1 armor point)
	var visible_points: int = mini(armor, 20)
	for i: int in 10:
		var ax: float = start_x + float(i) * float(HEART_SIZE + HEART_GAP)
		var filled: int = clamp(visible_points - i * 2, 0, 2)
		_draw_armor_icon(ax, y, filled)


func _draw_armor_icon(x: float, y: float, filled: int) -> void:
	var shield_col: Color = ARMOR_COL if filled > 0 else ARMOR_DARK
	var p: float = float(HEART_PX)
	draw_rect(Rect2(x + 1*p, y,       7*p, 2*p), shield_col)
	draw_rect(Rect2(x,       y + 2*p, 9*p, 4*p), shield_col)
	draw_rect(Rect2(x + 1*p, y + 6*p, 7*p, p),   shield_col)
	draw_rect(Rect2(x + 2*p, y + 7*p, 5*p, p),   shield_col)
	draw_rect(Rect2(x + 3*p, y + 8*p, 3*p, p),   shield_col)
	if filled == 0:
		draw_rect(Rect2(x + 1*p, y, 7*p, 9*p), Color(0.2, 0.2, 0.2, 0.5))
