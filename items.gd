class_name Items

const COAL:        int = 200
const RAW_IRON:    int = 201
const RAW_GOLD:    int = 202
const DIAMOND:     int = 203
const STICK:       int = 204
const FLINT:       int = 205
const LEATHER:     int = 208
const APPLE:       int = 209
const BREAD:       int = 210
const QUARTZ:      int = 213

const WOOD_SWORD:      int = 220
const WOOD_PICKAXE:    int = 221
const WOOD_AXE:        int = 222
const WOOD_SHOVEL:     int = 223
const WOOD_HOE:        int = 224
const STONE_SWORD:     int = 225
const STONE_PICKAXE:   int = 226
const STONE_AXE:       int = 227
const STONE_SHOVEL:    int = 228
const STONE_HOE:       int = 229
const IRON_SWORD:      int = 230
const IRON_PICKAXE:    int = 231
const IRON_AXE:        int = 232
const IRON_SHOVEL:     int = 233
const IRON_HOE:        int = 234
const GOLD_SWORD:      int = 235
const GOLD_PICKAXE:    int = 236
const GOLD_AXE:        int = 237
const GOLD_SHOVEL:     int = 238
const GOLD_HOE:        int = 239
const DIAMOND_SWORD:   int = 240
const DIAMOND_PICKAXE: int = 241
const DIAMOND_AXE:     int = 242
const DIAMOND_SHOVEL:  int = 243
const DIAMOND_HOE:     int = 244

const IRON_INGOT:  int = 245
const GOLD_INGOT:  int = 246

const LEATHER_HELMET:     int = 250
const LEATHER_CHESTPLATE: int = 251
const LEATHER_LEGGINGS:   int = 252
const LEATHER_BOOTS:      int = 253
const IRON_HELMET:        int = 254
const IRON_CHESTPLATE:    int = 255
const IRON_LEGGINGS:      int = 256
const IRON_BOOTS:         int = 257
const GOLD_HELMET:        int = 258
const GOLD_CHESTPLATE:    int = 259
const GOLD_LEGGINGS:      int = 260
const GOLD_BOOTS:         int = 261
const DIAMOND_HELMET:     int = 262
const DIAMOND_CHESTPLATE: int = 263
const DIAMOND_LEGGINGS:   int = 264
const DIAMOND_BOOTS:      int = 265

const ARMOR_HELMET:     int = 0
const ARMOR_CHESTPLATE: int = 1
const ARMOR_LEGGINGS:   int = 2
const ARMOR_BOOTS:      int = 3

const MAX_STACK:  int = 64
const TOOL_STACK: int = 1


static func is_item(id: int) -> bool:
	return id >= 200


static func is_tool(id: int) -> bool:
	return id >= 220 and id <= 244


static func is_armor(id: int) -> bool:
	return id >= 250 and id <= 265


static func is_block(id: int) -> bool:
	return id > 0 and id < 200


static func get_max_stack(id: int) -> int:
	if is_tool(id) or is_armor(id):
		return 1
	return 64


static func get_item_name(id: int) -> String:
	match id:
		COAL:        return "Coal"
		RAW_IRON:    return "Raw Iron"
		RAW_GOLD:    return "Raw Gold"
		DIAMOND:     return "Diamond"
		STICK:       return "Stick"
		FLINT:       return "Flint"
		LEATHER:     return "Leather"
		APPLE:       return "Apple"
		BREAD:       return "Bread"
		QUARTZ:      return "Quartz"
		IRON_INGOT:  return "Iron Ingot"
		GOLD_INGOT:  return "Gold Ingot"
		WOOD_SWORD:      return "Wooden Sword"
		WOOD_PICKAXE:    return "Wooden Pickaxe"
		WOOD_AXE:        return "Wooden Axe"
		WOOD_SHOVEL:     return "Wooden Shovel"
		WOOD_HOE:        return "Wooden Hoe"
		STONE_SWORD:     return "Stone Sword"
		STONE_PICKAXE:   return "Stone Pickaxe"
		STONE_AXE:       return "Stone Axe"
		STONE_SHOVEL:    return "Stone Shovel"
		STONE_HOE:       return "Stone Hoe"
		IRON_SWORD:      return "Iron Sword"
		IRON_PICKAXE:    return "Iron Pickaxe"
		IRON_AXE:        return "Iron Axe"
		IRON_SHOVEL:     return "Iron Shovel"
		IRON_HOE:        return "Iron Hoe"
		GOLD_SWORD:      return "Golden Sword"
		GOLD_PICKAXE:    return "Golden Pickaxe"
		GOLD_AXE:        return "Golden Axe"
		GOLD_SHOVEL:     return "Golden Shovel"
		GOLD_HOE:        return "Golden Hoe"
		DIAMOND_SWORD:      return "Diamond Sword"
		DIAMOND_PICKAXE:    return "Diamond Pickaxe"
		DIAMOND_AXE:        return "Diamond Axe"
		DIAMOND_SHOVEL:     return "Diamond Shovel"
		DIAMOND_HOE:        return "Diamond Hoe"
		LEATHER_HELMET:     return "Leather Helmet"
		LEATHER_CHESTPLATE: return "Leather Chestplate"
		LEATHER_LEGGINGS:   return "Leather Leggings"
		LEATHER_BOOTS:      return "Leather Boots"
		IRON_HELMET:        return "Iron Helmet"
		IRON_CHESTPLATE:    return "Iron Chestplate"
		IRON_LEGGINGS:      return "Iron Leggings"
		IRON_BOOTS:         return "Iron Boots"
		GOLD_HELMET:        return "Golden Helmet"
		GOLD_CHESTPLATE:    return "Golden Chestplate"
		GOLD_LEGGINGS:      return "Golden Leggings"
		GOLD_BOOTS:         return "Golden Boots"
		DIAMOND_HELMET:     return "Diamond Helmet"
		DIAMOND_CHESTPLATE: return "Diamond Chestplate"
		DIAMOND_LEGGINGS:   return "Diamond Leggings"
		DIAMOND_BOOTS:      return "Diamond Boots"
	if is_block(id):
		return BlockIcon.get_block_name(id)
	return "Unknown"


static func get_armor_slot(id: int) -> int:
	match id:
		LEATHER_HELMET, IRON_HELMET, GOLD_HELMET, DIAMOND_HELMET:
			return ARMOR_HELMET
		LEATHER_CHESTPLATE, IRON_CHESTPLATE, GOLD_CHESTPLATE, DIAMOND_CHESTPLATE:
			return ARMOR_CHESTPLATE
		LEATHER_LEGGINGS, IRON_LEGGINGS, GOLD_LEGGINGS, DIAMOND_LEGGINGS:
			return ARMOR_LEGGINGS
		LEATHER_BOOTS, IRON_BOOTS, GOLD_BOOTS, DIAMOND_BOOTS:
			return ARMOR_BOOTS
	return -1


static func get_armor_value(id: int) -> int:
	match id:
		LEATHER_HELMET:     return 1
		LEATHER_CHESTPLATE: return 3
		LEATHER_LEGGINGS:   return 2
		LEATHER_BOOTS:      return 1
		IRON_HELMET:        return 2
		IRON_CHESTPLATE:    return 6
		IRON_LEGGINGS:      return 5
		IRON_BOOTS:         return 2
		GOLD_HELMET:        return 2
		GOLD_CHESTPLATE:    return 5
		GOLD_LEGGINGS:      return 3
		GOLD_BOOTS:         return 1
		DIAMOND_HELMET:     return 3
		DIAMOND_CHESTPLATE: return 8
		DIAMOND_LEGGINGS:   return 6
		DIAMOND_BOOTS:      return 3
	return 0


static func get_item_color(id: int) -> Color:
	match id:
		COAL:        return Color(0.15, 0.15, 0.15)
		RAW_IRON:    return Color(0.72, 0.55, 0.38)
		RAW_GOLD:    return Color(0.90, 0.75, 0.20)
		DIAMOND:     return Color(0.30, 0.90, 0.95)
		STICK:       return Color(0.55, 0.35, 0.15)
		FLINT:       return Color(0.35, 0.35, 0.40)
		LEATHER:     return Color(0.60, 0.38, 0.18)
		APPLE:       return Color(0.85, 0.15, 0.15)
		BREAD:       return Color(0.78, 0.60, 0.28)
		QUARTZ:      return Color(0.95, 0.92, 0.88)
		IRON_INGOT:  return Color(0.78, 0.78, 0.80)
		GOLD_INGOT:  return Color(0.95, 0.82, 0.10)
	if is_tool(id):
		var base: int = ((id - 220) / 5) * 5 + 220
		match base:
			220: return Color(0.60, 0.42, 0.20)  # wood
			225: return Color(0.60, 0.60, 0.60)  # stone
			230: return Color(0.75, 0.78, 0.82)  # iron
			235: return Color(0.95, 0.82, 0.10)  # gold
			240: return Color(0.25, 0.88, 0.95)  # diamond
	if is_armor(id):
		if id >= DIAMOND_HELMET: return Color(0.25, 0.88, 0.95)
		if id >= GOLD_HELMET:    return Color(0.95, 0.82, 0.10)
		if id >= IRON_HELMET:    return Color(0.75, 0.78, 0.82)
		return Color(0.60, 0.38, 0.18)
	return Color(0.7, 0.7, 0.7)


static func _get_tool_material_color(id: int) -> Color:
	var tier: int = (id - 220) / 5
	match tier:
		0: return Color(0.60, 0.42, 0.20)
		1: return Color(0.60, 0.60, 0.60)
		2: return Color(0.75, 0.78, 0.82)
		3: return Color(0.95, 0.82, 0.10)
		4: return Color(0.25, 0.88, 0.95)
	return Color(0.7, 0.7, 0.7)


static func _get_tool_type(id: int) -> int:
	return (id - 220) % 5


static func draw_item_icon(canvas: CanvasItem, cx: float, cy: float, size: float, id: int) -> void:
	var s: float = size * 1.4
	var h: float = s

	if id == COAL:
		var r: Rect2 = Rect2(cx - s * 0.4, cy - s * 0.4, s * 0.8, s * 0.8)
		canvas.draw_rect(r, Color(0.10, 0.10, 0.10))
		canvas.draw_rect(Rect2(r.position.x + 2, r.position.y + 2, 4, 4), Color(0.25, 0.25, 0.28))
		return

	if id == RAW_IRON:
		_draw_rhombus(canvas, cx, cy, s * 0.45, Color(0.72, 0.55, 0.38), Color(0.50, 0.35, 0.20))
		return

	if id == RAW_GOLD:
		_draw_rhombus(canvas, cx, cy, s * 0.45, Color(0.90, 0.75, 0.20), Color(0.70, 0.55, 0.05))
		return

	if id == DIAMOND:
		_draw_rotated_square(canvas, cx, cy, s * 0.42, Color(0.30, 0.90, 0.95), Color(0.10, 0.65, 0.78))
		return

	if id == STICK:
		var sw: float = s * 0.18
		canvas.draw_rect(Rect2(cx - sw * 0.5, cy - h * 0.45, sw, h * 0.9), Color(0.55, 0.35, 0.15))
		canvas.draw_rect(Rect2(cx - sw * 0.5, cy - h * 0.45, sw, 3), Color(0.70, 0.50, 0.25))
		return

	if id == FLINT:
		_draw_rhombus(canvas, cx, cy, s * 0.38, Color(0.35, 0.35, 0.40), Color(0.20, 0.20, 0.25))
		return

	if id == LEATHER:
		canvas.draw_rect(Rect2(cx - s * 0.4, cy - s * 0.35, s * 0.8, s * 0.7), Color(0.60, 0.38, 0.18))
		canvas.draw_rect(Rect2(cx - s * 0.25, cy - s * 0.20, s * 0.5, s * 0.4), Color(0.75, 0.52, 0.28))
		return

	if id == APPLE:
		_draw_circle_icon(canvas, cx, cy + s * 0.05, s * 0.38, Color(0.85, 0.15, 0.15), Color(0.60, 0.05, 0.05))
		canvas.draw_rect(Rect2(cx - 2, cy - s * 0.42, 4, s * 0.18), Color(0.30, 0.60, 0.10))
		return

	if id == BREAD:
		canvas.draw_rect(Rect2(cx - s * 0.42, cy - s * 0.22, s * 0.84, s * 0.44), Color(0.78, 0.60, 0.28))
		canvas.draw_rect(Rect2(cx - s * 0.35, cy - s * 0.35, s * 0.70, s * 0.15), Color(0.88, 0.72, 0.40))
		return

	if id == QUARTZ:
		_draw_rotated_square(canvas, cx, cy, s * 0.40, Color(0.95, 0.92, 0.88), Color(0.78, 0.75, 0.70))
		return

	if id == IRON_INGOT:
		_draw_ingot(canvas, cx, cy, s, Color(0.78, 0.78, 0.80), Color(0.55, 0.55, 0.58))
		return

	if id == GOLD_INGOT:
		_draw_ingot(canvas, cx, cy, s, Color(0.95, 0.82, 0.10), Color(0.72, 0.60, 0.05))
		return

	if is_tool(id):
		_draw_tool(canvas, cx, cy, s, id)
		return

	if is_armor(id):
		_draw_armor(canvas, cx, cy, s, id)
		return

	canvas.draw_rect(Rect2(cx - s * 0.4, cy - s * 0.4, s * 0.8, s * 0.8), get_item_color(id))


static func _draw_rhombus(canvas: CanvasItem, cx: float, cy: float, r: float, col: Color, shadow: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx, cy - r),
		Vector2(cx + r * 0.7, cy),
		Vector2(cx, cy + r),
		Vector2(cx - r * 0.7, cy),
	])
	var cols := PackedColorArray([col, col, shadow, shadow])
	canvas.draw_polygon(pts, cols)


static func _draw_rotated_square(canvas: CanvasItem, cx: float, cy: float, r: float, col: Color, shadow: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx, cy - r),
		Vector2(cx + r, cy),
		Vector2(cx, cy + r),
		Vector2(cx - r, cy),
	])
	var cols := PackedColorArray([col, col, shadow, shadow])
	canvas.draw_polygon(pts, cols)


static func _draw_circle_icon(canvas: CanvasItem, cx: float, cy: float, r: float, col: Color, _shadow: Color) -> void:
	canvas.draw_circle(Vector2(cx, cy), r, col)
	canvas.draw_circle(Vector2(cx - r * 0.25, cy - r * 0.25), r * 0.35, col.lightened(0.3))


static func _draw_ingot(canvas: CanvasItem, cx: float, cy: float, s: float, col: Color, shadow: Color) -> void:
	var w: float = s * 0.72
	var h: float = s * 0.48
	var pts := PackedVector2Array([
		Vector2(cx - w * 0.4, cy - h * 0.5),
		Vector2(cx + w * 0.4, cy - h * 0.5),
		Vector2(cx + w * 0.5, cy + h * 0.5),
		Vector2(cx - w * 0.5, cy + h * 0.5),
	])
	var cols := PackedColorArray([col, col, shadow, shadow])
	canvas.draw_polygon(pts, cols)
	canvas.draw_rect(Rect2(cx - w * 0.35, cy - h * 0.5, w * 0.70, h * 0.22), col.lightened(0.25))


static func _draw_tool(canvas: CanvasItem, cx: float, cy: float, s: float, id: int) -> void:
	var mat_col: Color = _get_tool_material_color(id)
	var dark: Color = mat_col.darkened(0.4)
	var tool_type: int = _get_tool_type(id)
	var handle_col: Color = Color(0.55, 0.35, 0.15)

	# Handle (stick) — drawn bottom-right diagonal
	var hx: float = cx + s * 0.10
	var hy: float = cy + s * 0.10
	var hw: float = s * 0.14
	var hlen: float = s * 0.65
	var handle_pts := PackedVector2Array([
		Vector2(hx - hw * 0.5, hy - hlen * 0.5),
		Vector2(hx + hw * 0.5, hy - hlen * 0.5),
		Vector2(hx + hw * 0.5 + hlen * 0.4, hy + hlen * 0.5),
		Vector2(hx - hw * 0.5 + hlen * 0.4, hy + hlen * 0.5),
	])
	canvas.draw_polygon(handle_pts, PackedColorArray([handle_col, handle_col, handle_col, handle_col]))

	match tool_type:
		0:  # sword
			var blade_pts := PackedVector2Array([
				Vector2(cx - s * 0.12, cy - s * 0.45),
				Vector2(cx + s * 0.12, cy - s * 0.45),
				Vector2(cx + s * 0.08, cy + s * 0.10),
				Vector2(cx - s * 0.08, cy + s * 0.10),
			])
			canvas.draw_polygon(blade_pts, PackedColorArray([mat_col, mat_col, dark, dark]))
			canvas.draw_rect(Rect2(cx - s * 0.28, cy + s * 0.06, s * 0.56, s * 0.10), dark)
		1:  # pickaxe
			var head_pts := PackedVector2Array([
				Vector2(cx - s * 0.42, cy - s * 0.20),
				Vector2(cx + s * 0.42, cy - s * 0.28),
				Vector2(cx + s * 0.42, cy - s * 0.10),
				Vector2(cx - s * 0.42, cy - s * 0.02),
			])
			canvas.draw_polygon(head_pts, PackedColorArray([mat_col, mat_col, dark, dark]))
			var tip_pts := PackedVector2Array([
				Vector2(cx - s * 0.42, cy - s * 0.20),
				Vector2(cx - s * 0.30, cy - s * 0.36),
				Vector2(cx - s * 0.20, cy - s * 0.10),
			])
			canvas.draw_polygon(tip_pts, PackedColorArray([mat_col, mat_col, dark]))
			var tip2_pts := PackedVector2Array([
				Vector2(cx + s * 0.42, cy - s * 0.28),
				Vector2(cx + s * 0.55, cy - s * 0.42),
				Vector2(cx + s * 0.42, cy - s * 0.10),
			])
			canvas.draw_polygon(tip2_pts, PackedColorArray([mat_col, mat_col, dark]))
		2:  # axe
			var head_pts := PackedVector2Array([
				Vector2(cx - s * 0.18, cy - s * 0.45),
				Vector2(cx + s * 0.35, cy - s * 0.35),
				Vector2(cx + s * 0.35, cy + s * 0.05),
				Vector2(cx - s * 0.18, cy + s * 0.05),
			])
			canvas.draw_polygon(head_pts, PackedColorArray([mat_col, mat_col, dark, dark]))
		3:  # shovel
			var blade_pts := PackedVector2Array([
				Vector2(cx - s * 0.20, cy - s * 0.42),
				Vector2(cx + s * 0.20, cy - s * 0.42),
				Vector2(cx + s * 0.16, cy + s * 0.02),
				Vector2(cx - s * 0.16, cy + s * 0.02),
			])
			canvas.draw_polygon(blade_pts, PackedColorArray([mat_col, mat_col, dark, dark]))
		4:  # hoe
			var blade_pts := PackedVector2Array([
				Vector2(cx - s * 0.35, cy - s * 0.42),
				Vector2(cx + s * 0.12, cy - s * 0.42),
				Vector2(cx + s * 0.12, cy - s * 0.20),
				Vector2(cx - s * 0.35, cy - s * 0.20),
			])
			canvas.draw_polygon(blade_pts, PackedColorArray([mat_col, mat_col, dark, dark]))


static func _draw_armor(canvas: CanvasItem, cx: float, cy: float, s: float, id: int) -> void:
	var col: Color = get_item_color(id)
	var dark: Color = col.darkened(0.4)
	var slot: int = get_armor_slot(id)

	match slot:
		ARMOR_HELMET:
			var pts := PackedVector2Array([
				Vector2(cx - s * 0.42, cy + s * 0.10),
				Vector2(cx + s * 0.42, cy + s * 0.10),
				Vector2(cx + s * 0.38, cy - s * 0.15),
				Vector2(cx + s * 0.18, cy - s * 0.42),
				Vector2(cx - s * 0.18, cy - s * 0.42),
				Vector2(cx - s * 0.38, cy - s * 0.15),
			])
			canvas.draw_polygon(pts, PackedColorArray([dark, dark, col, col, col, col]))
			canvas.draw_rect(Rect2(cx - s * 0.30, cy + s * 0.10, s * 0.60, s * 0.18), dark)
		ARMOR_CHESTPLATE:
			var pts := PackedVector2Array([
				Vector2(cx - s * 0.42, cy - s * 0.35),
				Vector2(cx + s * 0.42, cy - s * 0.35),
				Vector2(cx + s * 0.42, cy + s * 0.38),
				Vector2(cx - s * 0.42, cy + s * 0.38),
			])
			canvas.draw_polygon(pts, PackedColorArray([col, col, dark, dark]))
			canvas.draw_rect(Rect2(cx - s * 0.12, cy - s * 0.35, s * 0.24, s * 0.20), dark)
		ARMOR_LEGGINGS:
			var pts := PackedVector2Array([
				Vector2(cx - s * 0.42, cy - s * 0.38),
				Vector2(cx + s * 0.42, cy - s * 0.38),
				Vector2(cx + s * 0.38, cy + s * 0.38),
				Vector2(cx + s * 0.08, cy + s * 0.38),
				Vector2(cx + s * 0.08, cy),
				Vector2(cx - s * 0.08, cy),
				Vector2(cx - s * 0.08, cy + s * 0.38),
				Vector2(cx - s * 0.38, cy + s * 0.38),
			])
			canvas.draw_polygon(pts, PackedColorArray([col, col, dark, dark, dark, dark, dark, col]))
		ARMOR_BOOTS:
			canvas.draw_rect(Rect2(cx - s * 0.42, cy - s * 0.20, s * 0.38, s * 0.55), col)
			canvas.draw_rect(Rect2(cx - s * 0.42, cy + s * 0.28, s * 0.44, s * 0.12), dark)
			canvas.draw_rect(Rect2(cx + s * 0.04, cy - s * 0.20, s * 0.38, s * 0.55), col)
			canvas.draw_rect(Rect2(cx + s * 0.04, cy + s * 0.28, s * 0.44, s * 0.12), dark)
