extends Control

const SLOT_SIZE: int = 48
const SLOT_GAP: int = 0
const BLOCK_S: float = 15.0
const BORDER: int = 2
const BAR_PAD: int = 3

# Pixel UI colors
const BAR_TINT := Color(0.45, 0.45, 0.45, 0.95)
const BAR_BORDER_DARK := Color(0.12, 0.12, 0.13, 1.0)
const BAR_BORDER_LIGHT := Color(0.68, 0.68, 0.66, 1.0)
const SLOT_BG := Color(0.0, 0.0, 0.0, 0.35)
const SLOT_DIVIDER := Color(0.05, 0.05, 0.06, 0.8)
const SELECT_OUTER := Color(1.0, 1.0, 1.0, 0.98)

var _atlas: Texture2D = null


func _ready() -> void:
	_atlas = BlockTextures.create_icon_atlas()
	# Force nearest sampling so iso-block faces don't bleed across tile
	# boundaries in the atlas (produces the thin seam users see otherwise).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var hud: Node = get_parent()
	var slots: Array[int] = hud.slots
	var selected: int = hud.selected_slot
	var slot_count: int = slots.size()

	var bar_inner_w: float = slot_count * SLOT_SIZE
	var bar_w: float = bar_inner_w + BAR_PAD * 2
	var bar_h: float = SLOT_SIZE + BAR_PAD * 2
	var vp: Vector2 = get_viewport_rect().size
	var bar_x: float = (vp.x - bar_w) / 2.0 - global_position.x
	var bar_y: float = vp.y - bar_h - 12.0 - global_position.y

	# Outer dark border
	draw_rect(Rect2(bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4), BAR_BORDER_DARK)

	# Stone-textured bar background
	_draw_stone_bg(Rect2(bar_x, bar_y, bar_w, bar_h), BAR_TINT)

	# Pixel-art bevel
	draw_rect(Rect2(bar_x, bar_y, bar_w, 2), BAR_BORDER_LIGHT)
	draw_rect(Rect2(bar_x, bar_y, 2, bar_h), BAR_BORDER_LIGHT)
	draw_rect(Rect2(bar_x, bar_y + bar_h - 2, bar_w, 2), BAR_BORDER_DARK)
	draw_rect(Rect2(bar_x + bar_w - 2, bar_y, 2, bar_h), BAR_BORDER_DARK)

	for i: int in slot_count:
		var sx: float = bar_x + BAR_PAD + i * SLOT_SIZE
		var sy: float = bar_y + BAR_PAD
		var slot_rect := Rect2(sx, sy, SLOT_SIZE, SLOT_SIZE)

		draw_rect(slot_rect, SLOT_BG)

		if i < slot_count - 1:
			draw_rect(Rect2(sx + SLOT_SIZE - 1, sy, 1, SLOT_SIZE), SLOT_DIVIDER)

		# 3D isometric textured block — shared helper.
		# Centering: block extends from (cy - s/2) to (cy + s/2 + s*CUBE_H).
		# Geometric center = cy + s*CUBE_H/2, so for slot-centered:
		#   cy = slot_center - s*CUBE_H/2
		var cx: float = sx + SLOT_SIZE * 0.5
		var cy: float = sy + SLOT_SIZE * 0.5 - BLOCK_S * BlockIcon.CUBE_H * 0.5
		BlockIcon.draw_iso(self, _atlas, cx, cy, BLOCK_S, slots[i])

		# Selection highlight
		if i == selected:
			var o := Rect2(sx - 2, sy - 2, SLOT_SIZE + 4, SLOT_SIZE + 4)
			draw_rect(Rect2(o.position.x, o.position.y, o.size.x, 2), SELECT_OUTER)
			draw_rect(Rect2(o.position.x, o.position.y + o.size.y - 2, o.size.x, 2), SELECT_OUTER)
			draw_rect(Rect2(o.position.x, o.position.y, 2, o.size.y), SELECT_OUTER)
			draw_rect(Rect2(o.position.x + o.size.x - 2, o.position.y, 2, o.size.y), SELECT_OUTER)

		# Slot number
		var num_str := str(i + 1)
		var font: Font = ThemeDB.fallback_font
		# draw_string's y is the baseline; offset so the number sits near the
		# top of the slot rather than the middle.
		draw_string(font, Vector2(sx + 5, sy + 18), num_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, PauseMenu._fs(22), Color(1, 1, 1, 0.9))


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
