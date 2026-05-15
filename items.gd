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
const OAK_SAPLING: int = 214
const RESTORE_ORB: int = 215

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

static var _tool_tex_cache: Dictionary = {}
static var _armor_tex_cache: Dictionary = {}


static func _get_armor_texture(id: int) -> Texture2D:
	if _armor_tex_cache.has(id):
		return _armor_tex_cache[id]
	const MATERIALS := ["leather", "iron", "gold", "diamond"]
	const TYPES := ["helmet", "chestplate", "leggings", "boots"]
	var mat: int = (id - 250) / 4
	var typ: int = (id - 250) % 4
	var path: String = "res://armor/%s_%s.png" % [TYPES[typ], MATERIALS[mat]]
	var tex: Texture2D = load(path) as Texture2D
	_armor_tex_cache[id] = tex
	return tex


static func _get_tool_texture(id: int) -> Texture2D:
	if _tool_tex_cache.has(id):
		return _tool_tex_cache[id]
	const MATERIALS := ["wood", "stone", "iron", "gold", "diamond"]
	const TYPES := ["sword", "pickaxe", "axe", "shovel", "hoe"]
	var mat: int = (id - 220) / 5
	var typ: int = (id - 220) % 5
	var path: String = "res://tools/%s_%s.png" % [TYPES[typ], MATERIALS[mat]]
	var tex: Texture2D = load(path) as Texture2D
	_tool_tex_cache[id] = tex
	return tex


static func is_item(id: int) -> bool:
	return id >= 200


static func is_tool(id: int) -> bool:
	return id >= 220 and id <= 244


static func is_armor(id: int) -> bool:
	return id >= 250 and id <= 265


static func is_block(id: int) -> bool:
	return id > 0 and id < 200


static func get_max_stack(id: int) -> int:
	if (id >= 220 and id <= 244) or (id >= 250 and id <= 265):
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
		OAK_SAPLING: return "Oak Sapling"
		RESTORE_ORB: return "Restore Orb"
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
	if id > 0 and id < 200:
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
		OAK_SAPLING: return Color(0.20, 0.65, 0.12)
		RESTORE_ORB: return Color(0.92, 0.78, 0.10)
		IRON_INGOT:  return Color(0.78, 0.78, 0.80)
		GOLD_INGOT:  return Color(0.95, 0.82, 0.10)
	if id >= 220 and id <= 244:
		var base: int = ((id - 220) / 5) * 5 + 220
		match base:
			220: return Color(0.60, 0.42, 0.20)  # wood
			225: return Color(0.60, 0.60, 0.60)  # stone
			230: return Color(0.75, 0.78, 0.82)  # iron
			235: return Color(0.95, 0.82, 0.10)  # gold
			240: return Color(0.25, 0.88, 0.95)  # diamond
	if id >= 250 and id <= 265:
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
	var ps: float = size / 8.0
	var ox: float = cx - 8.0 * ps
	var oy: float = cy - 8.0 * ps
	if id == COAL:
		_icon_coal(canvas, ox, oy, ps)
	elif id == RAW_IRON:
		_icon_raw_ore(canvas, ox, oy, ps, Color(0.72,0.55,0.38), Color(0.50,0.35,0.20), Color(0.88,0.72,0.52))
	elif id == RAW_GOLD:
		_icon_raw_ore(canvas, ox, oy, ps, Color(0.90,0.75,0.20), Color(0.68,0.54,0.06), Color(1.0,0.94,0.55))
	elif id == DIAMOND:
		_icon_gem(canvas, ox, oy, ps, Color(0.28,0.88,0.95), Color(0.10,0.60,0.78), Color(0.75,0.98,1.0))
	elif id == STICK:
		_icon_stick(canvas, ox, oy, ps)
	elif id == FLINT:
		_icon_gem(canvas, ox, oy, ps, Color(0.35,0.35,0.42), Color(0.20,0.20,0.26), Color(0.55,0.55,0.62))
	elif id == LEATHER:
		_icon_leather(canvas, ox, oy, ps)
	elif id == APPLE:
		_icon_apple(canvas, ox, oy, ps)
	elif id == BREAD:
		_icon_bread(canvas, ox, oy, ps)
	elif id == QUARTZ:
		_icon_gem(canvas, ox, oy, ps, Color(0.95,0.92,0.88), Color(0.76,0.73,0.70), Color(1.0,0.98,0.96))
	elif id == IRON_INGOT:
		_icon_ingot(canvas, ox, oy, ps, Color(0.78,0.78,0.80), Color(0.52,0.52,0.55), Color(0.95,0.95,0.98))
	elif id == GOLD_INGOT:
		_icon_ingot(canvas, ox, oy, ps, Color(0.95,0.82,0.10), Color(0.68,0.56,0.05), Color(1.0,0.96,0.55))
	elif id == OAK_SAPLING:
		_icon_sapling(canvas, ox, oy, ps)
	elif id == RESTORE_ORB:
		_icon_restore_orb(canvas, ox, oy, ps)
	elif id >= 220 and id <= 244:
		var tex: Texture2D = _get_tool_texture(id)
		if tex != null:
			canvas.draw_texture_rect(tex, Rect2(ox, oy, size * 2.0, size * 2.0), false)
		else:
			_icon_tool(canvas, ox, oy, ps, id)
	elif id >= 250 and id <= 265:
		var tex: Texture2D = _get_armor_texture(id)
		if tex != null:
			canvas.draw_texture_rect(tex, Rect2(ox, oy, size * 2.0, size * 2.0), false)
		else:
			_icon_armor(canvas, ox, oy, ps, id)
	else:
		canvas.draw_rect(Rect2(ox+2*ps, oy+2*ps, 12*ps, 12*ps), get_item_color(id))


static func _r(canvas: CanvasItem, ox: float, oy: float, ps: float, x: int, y: int, w: int, h: int, col: Color) -> void:
	canvas.draw_rect(Rect2(ox + x*ps, oy + y*ps, w*ps, h*ps), col)


static func _icon_coal(canvas: CanvasItem, ox: float, oy: float, ps: float) -> void:
	var b := Color(0.08, 0.08, 0.09)
	var d := Color(0.04, 0.04, 0.04)
	var g := Color(0.26, 0.26, 0.30)
	var h := Color(0.48, 0.48, 0.54)
	# Rounded lump body
	_r(canvas, ox, oy, ps, 5, 1, 6, 1, b)
	_r(canvas, ox, oy, ps, 3, 2, 10, 1, b)
	_r(canvas, ox, oy, ps, 2, 3, 12, 7, b)
	_r(canvas, ox, oy, ps, 3, 10, 10, 2, b)
	_r(canvas, ox, oy, ps, 5, 12, 6, 1, b)
	# Lower-right shadow face
	_r(canvas, ox, oy, ps, 11, 3, 3, 7, d)
	_r(canvas, ox, oy, ps, 9, 10, 4, 2, d)
	_r(canvas, ox, oy, ps, 5, 12, 6, 1, d)
	# Upper-left gleam (two-tone)
	_r(canvas, ox, oy, ps, 2, 3, 4, 3, g)
	_r(canvas, ox, oy, ps, 2, 3, 2, 1, h)
	_r(canvas, ox, oy, ps, 3, 4, 1, 1, h)
	_r(canvas, ox, oy, ps, 6, 2, 2, 1, g)
	# Secondary gleam patch
	_r(canvas, ox, oy, ps, 7, 8, 2, 1, g)
	_r(canvas, ox, oy, ps, 8, 9, 2, 1, g)


static func _icon_raw_ore(canvas: CanvasItem, ox: float, oy: float, ps: float, col: Color, dark: Color, light: Color) -> void:
	# Irregular chunk body
	_r(canvas, ox, oy, ps, 4, 1, 8, 1, col)
	_r(canvas, ox, oy, ps, 2, 2, 12, 1, col)
	_r(canvas, ox, oy, ps, 1, 3, 14, 8, col)
	_r(canvas, ox, oy, ps, 2, 11, 12, 1, col)
	_r(canvas, ox, oy, ps, 4, 12, 8, 1, col)
	# Upper-left highlight face (brightest corner → fade)
	_r(canvas, ox, oy, ps, 2, 3, 6, 4, light)
	_r(canvas, ox, oy, ps, 2, 3, 3, 2, light.lightened(0.18))
	_r(canvas, ox, oy, ps, 4, 2, 5, 2, light)
	# Lower-right shadow face
	_r(canvas, ox, oy, ps, 11, 4, 4, 7, dark)
	_r(canvas, ox, oy, ps, 2, 11, 12, 2, dark)
	_r(canvas, ox, oy, ps, 4, 12, 8, 1, dark.darkened(0.2))
	# Surface texture: crack + mineral speck
	_r(canvas, ox, oy, ps, 7, 6, 2, 2, dark)
	_r(canvas, ox, oy, ps, 4, 8, 2, 1, light)


static func _icon_gem(canvas: CanvasItem, ox: float, oy: float, ps: float, col: Color, dark: Color, light: Color) -> void:
	# Top cap — brightest facet
	_r(canvas, ox, oy, ps, 7, 2, 2, 1, light)
	_r(canvas, ox, oy, ps, 5, 3, 6, 1, light)
	_r(canvas, ox, oy, ps, 4, 4, 4, 1, light)
	# Upper-right facet (light, faces up-right)
	_r(canvas, ox, oy, ps, 8, 4, 4, 1, light)
	_r(canvas, ox, oy, ps, 4, 5, 4, 2, col)
	_r(canvas, ox, oy, ps, 8, 5, 5, 2, light)
	# Equator — full width
	_r(canvas, ox, oy, ps, 3, 7, 10, 1, col)
	# Lower-left facet (mid)
	_r(canvas, ox, oy, ps, 3, 8, 5, 2, col.darkened(0.15))
	# Lower-right facet (darkest)
	_r(canvas, ox, oy, ps, 8, 8, 5, 2, dark)
	# Bottom taper point
	_r(canvas, ox, oy, ps, 4, 10, 8, 1, dark)
	_r(canvas, ox, oy, ps, 5, 11, 6, 1, dark)
	_r(canvas, ox, oy, ps, 6, 12, 4, 1, dark)
	_r(canvas, ox, oy, ps, 7, 13, 2, 1, dark.darkened(0.25))


static func _icon_stick(canvas: CanvasItem, ox: float, oy: float, ps: float) -> void:
	var b := Color(0.55, 0.36, 0.14)
	var d := Color(0.32, 0.20, 0.06)
	var l := Color(0.76, 0.57, 0.26)
	# Diagonal from upper-right to lower-left; left pixel = light, right = dark
	_r(canvas, ox, oy, ps, 11, 1, 1, 2, l)
	_r(canvas, ox, oy, ps, 12, 1, 1, 2, d)
	_r(canvas, ox, oy, ps, 10, 3, 1, 2, b)
	_r(canvas, ox, oy, ps, 11, 3, 1, 2, d)
	_r(canvas, ox, oy, ps, 9, 5, 1, 2, l)
	_r(canvas, ox, oy, ps, 10, 5, 1, 2, d)
	_r(canvas, ox, oy, ps, 8, 7, 1, 2, b)
	_r(canvas, ox, oy, ps, 9, 7, 1, 2, d)
	_r(canvas, ox, oy, ps, 7, 9, 1, 2, l)
	_r(canvas, ox, oy, ps, 8, 9, 1, 2, d)
	_r(canvas, ox, oy, ps, 6, 11, 1, 2, b)
	_r(canvas, ox, oy, ps, 7, 11, 1, 2, d)
	_r(canvas, ox, oy, ps, 5, 13, 1, 1, b)
	_r(canvas, ox, oy, ps, 6, 13, 1, 1, d)
	_r(canvas, ox, oy, ps, 4, 14, 1, 1, d)


static func _icon_leather(canvas: CanvasItem, ox: float, oy: float, ps: float) -> void:
	var b := Color(0.55, 0.33, 0.13)
	var l := Color(0.72, 0.50, 0.22)
	var d := Color(0.32, 0.17, 0.04)
	# Two shoulder lobes + body + two leg tabs (cowhide silhouette)
	_r(canvas, ox, oy, ps, 2, 1, 5, 5, b)
	_r(canvas, ox, oy, ps, 9, 1, 5, 5, b)
	_r(canvas, ox, oy, ps, 1, 5, 14, 6, b)
	_r(canvas, ox, oy, ps, 2, 11, 5, 4, b)
	_r(canvas, ox, oy, ps, 9, 11, 5, 4, b)
	# Highlights
	_r(canvas, ox, oy, ps, 3, 2, 3, 2, l)
	_r(canvas, ox, oy, ps, 10, 2, 3, 2, l)
	_r(canvas, ox, oy, ps, 2, 6, 12, 3, l)
	_r(canvas, ox, oy, ps, 3, 12, 3, 2, l)
	_r(canvas, ox, oy, ps, 10, 12, 3, 2, l)
	# Center seam + shadow edges
	_r(canvas, ox, oy, ps, 7, 1, 2, 14, d)
	_r(canvas, ox, oy, ps, 1, 10, 14, 1, d)
	_r(canvas, ox, oy, ps, 2, 14, 5, 1, d)
	_r(canvas, ox, oy, ps, 9, 14, 5, 1, d)


static func _icon_apple(canvas: CanvasItem, ox: float, oy: float, ps: float) -> void:
	var r := Color(0.78, 0.10, 0.10)
	var d := Color(0.44, 0.03, 0.03)
	var g := Color(0.20, 0.58, 0.08)
	var lg := Color(0.30, 0.72, 0.16)
	var h := Color(0.95, 0.50, 0.50)
	# Stem and leaf
	_r(canvas, ox, oy, ps, 8, 1, 1, 3, g)
	_r(canvas, ox, oy, ps, 9, 1, 3, 1, lg)
	_r(canvas, ox, oy, ps, 9, 2, 2, 1, g)
	# Apple body
	_r(canvas, ox, oy, ps, 5, 3, 6, 1, r)
	_r(canvas, ox, oy, ps, 4, 4, 8, 7, r)
	_r(canvas, ox, oy, ps, 5, 11, 6, 2, r)
	_r(canvas, ox, oy, ps, 6, 13, 4, 1, d)
	# Upper-left highlight
	_r(canvas, ox, oy, ps, 5, 4, 3, 3, h)
	_r(canvas, ox, oy, ps, 5, 4, 1, 1, h.lightened(0.30))
	# Lower-right shadow
	_r(canvas, ox, oy, ps, 9, 8, 3, 4, d)
	_r(canvas, ox, oy, ps, 5, 11, 7, 2, d)


static func _icon_bread(canvas: CanvasItem, ox: float, oy: float, ps: float) -> void:
	var b := Color(0.68, 0.48, 0.18)
	var l := Color(0.88, 0.70, 0.34)
	var d := Color(0.44, 0.28, 0.07)
	var i := Color(0.91, 0.78, 0.52)
	# Dome top (crust)
	_r(canvas, ox, oy, ps, 5, 2, 6, 1, l)
	_r(canvas, ox, oy, ps, 3, 3, 10, 1, l)
	_r(canvas, ox, oy, ps, 2, 4, 12, 1, l)
	# Body
	_r(canvas, ox, oy, ps, 2, 5, 12, 5, b)
	# Inner crumb face (lighter, shows cross-section)
	_r(canvas, ox, oy, ps, 4, 5, 8, 3, i)
	# Score line
	_r(canvas, ox, oy, ps, 2, 7, 12, 1, d)
	# Left end lighter, right end darker
	_r(canvas, ox, oy, ps, 2, 5, 2, 4, l)
	_r(canvas, ox, oy, ps, 12, 5, 2, 4, d)
	# Bottom shadow
	_r(canvas, ox, oy, ps, 2, 9, 12, 1, d)
	_r(canvas, ox, oy, ps, 3, 10, 11, 1, d)
	_r(canvas, ox, oy, ps, 4, 11, 9, 1, d.darkened(0.2))


static func _icon_ingot(canvas: CanvasItem, ox: float, oy: float, ps: float, col: Color, dark: Color, light: Color) -> void:
	# Narrow neck at top (ingot mold pour area)
	_r(canvas, ox, oy, ps, 4, 2, 8, 1, light)         # top rim highlight
	_r(canvas, ox, oy, ps, 4, 3, 8, 2, col)            # neck
	# Notch shadow corners where neck widens to body
	_r(canvas, ox, oy, ps, 2, 3, 2, 2, dark)
	_r(canvas, ox, oy, ps, 12, 3, 2, 2, dark)
	# Wide body
	_r(canvas, ox, oy, ps, 2, 5, 12, 6, col)
	# Left highlight face
	_r(canvas, ox, oy, ps, 2, 5, 2, 5, light)
	_r(canvas, ox, oy, ps, 4, 3, 1, 2, light)
	# Top face strip
	_r(canvas, ox, oy, ps, 5, 3, 6, 1, light.lerp(col, 0.5))
	# Right shadow face
	_r(canvas, ox, oy, ps, 12, 5, 2, 6, dark)
	_r(canvas, ox, oy, ps, 11, 3, 1, 2, dark)
	# Bottom shadow
	_r(canvas, ox, oy, ps, 2, 11, 12, 1, dark)
	_r(canvas, ox, oy, ps, 3, 12, 11, 1, dark.darkened(0.28))


static func _icon_tool(canvas: CanvasItem, ox: float, oy: float, ps: float, id: int) -> void:
	var mat: Color = _get_tool_material_color(id)
	var dark: Color = mat.darkened(0.4)
	var light: Color = mat.lightened(0.25)
	var tool_type: int = _get_tool_type(id)
	var hb := Color(0.58, 0.38, 0.16)
	var hd := Color(0.38, 0.22, 0.08)
	_r(canvas, ox, oy, ps, 7, 9, 2, 2, hb)
	_r(canvas, ox, oy, ps, 8, 11, 2, 2, hb)
	_r(canvas, ox, oy, ps, 9, 13, 2, 2, hd)
	match tool_type:
		0:  # sword
			_r(canvas, ox, oy, ps, 5, 1, 2, 8, mat)
			_r(canvas, ox, oy, ps, 6, 1, 1, 1, light)
			_r(canvas, ox, oy, ps, 4, 8, 1, 1, dark)
			_r(canvas, ox, oy, ps, 3, 7, 6, 2, dark)
			_r(canvas, ox, oy, ps, 4, 7, 4, 1, mat)
		1:  # pickaxe
			_r(canvas, ox, oy, ps, 1, 4, 10, 3, mat)
			_r(canvas, ox, oy, ps, 1, 3, 2, 2, mat)
			_r(canvas, ox, oy, ps, 1, 6, 2, 2, dark)
			_r(canvas, ox, oy, ps, 9, 2, 4, 3, mat)
			_r(canvas, ox, oy, ps, 11, 1, 2, 1, mat)
			_r(canvas, ox, oy, ps, 1, 4, 2, 1, light)
			_r(canvas, ox, oy, ps, 5, 3, 4, 1, light)
		2:  # axe
			_r(canvas, ox, oy, ps, 1, 1, 8, 6, mat)
			_r(canvas, ox, oy, ps, 1, 1, 3, 1, light)
			_r(canvas, ox, oy, ps, 1, 6, 4, 2, dark)
			_r(canvas, ox, oy, ps, 5, 5, 4, 3, dark)
			_r(canvas, ox, oy, ps, 4, 7, 4, 1, mat)
		3:  # shovel
			_r(canvas, ox, oy, ps, 5, 1, 4, 5, mat)
			_r(canvas, ox, oy, ps, 5, 1, 2, 1, light)
			_r(canvas, ox, oy, ps, 7, 5, 2, 4, mat)
			_r(canvas, ox, oy, ps, 8, 4, 1, 5, dark)
			_r(canvas, ox, oy, ps, 5, 5, 2, 1, dark)
		4:  # hoe
			_r(canvas, ox, oy, ps, 1, 2, 9, 3, mat)
			_r(canvas, ox, oy, ps, 1, 2, 4, 1, light)
			_r(canvas, ox, oy, ps, 7, 4, 3, 3, mat)
			_r(canvas, ox, oy, ps, 8, 4, 2, 4, dark)
			_r(canvas, ox, oy, ps, 1, 4, 3, 1, dark)


static func _icon_armor(canvas: CanvasItem, ox: float, oy: float, ps: float, id: int) -> void:
	var col: Color = get_item_color(id)
	var dark: Color = col.darkened(0.4)
	var light: Color = col.lightened(0.25)
	var slot: int = get_armor_slot(id)
	match slot:
		ARMOR_HELMET:
			_r(canvas, ox, oy, ps, 4, 1, 8, 1, col)
			_r(canvas, ox, oy, ps, 2, 2, 12, 4, col)
			_r(canvas, ox, oy, ps, 1, 3, 1, 3, col)
			_r(canvas, ox, oy, ps, 14, 3, 1, 3, col)
			_r(canvas, ox, oy, ps, 2, 6, 12, 2, col)
			_r(canvas, ox, oy, ps, 3, 8, 4, 2, dark)
			_r(canvas, ox, oy, ps, 9, 8, 4, 2, dark)
			_r(canvas, ox, oy, ps, 4, 1, 4, 3, light)
			_r(canvas, ox, oy, ps, 2, 3, 2, 2, light)
		ARMOR_CHESTPLATE:
			_r(canvas, ox, oy, ps, 3, 1, 3, 3, col)
			_r(canvas, ox, oy, ps, 10, 1, 3, 3, col)
			_r(canvas, ox, oy, ps, 1, 4, 14, 9, col)
			_r(canvas, ox, oy, ps, 1, 4, 3, 3, light)
			_r(canvas, ox, oy, ps, 1, 10, 14, 3, dark)
			_r(canvas, ox, oy, ps, 12, 4, 3, 6, dark)
		ARMOR_LEGGINGS:
			_r(canvas, ox, oy, ps, 1, 1, 14, 3, col)
			_r(canvas, ox, oy, ps, 1, 1, 5, 1, light)
			_r(canvas, ox, oy, ps, 1, 4, 6, 10, col)
			_r(canvas, ox, oy, ps, 1, 12, 6, 2, dark)
			_r(canvas, ox, oy, ps, 9, 4, 6, 10, col)
			_r(canvas, ox, oy, ps, 9, 12, 6, 2, dark)
		ARMOR_BOOTS:
			_r(canvas, ox, oy, ps, 1, 3, 5, 8, col)
			_r(canvas, ox, oy, ps, 1, 10, 7, 3, col)
			_r(canvas, ox, oy, ps, 1, 3, 2, 2, light)
			_r(canvas, ox, oy, ps, 1, 12, 7, 1, dark)
			_r(canvas, ox, oy, ps, 9, 3, 5, 8, col)
			_r(canvas, ox, oy, ps, 8, 10, 7, 3, col)
			_r(canvas, ox, oy, ps, 9, 3, 2, 2, light)
			_r(canvas, ox, oy, ps, 8, 12, 7, 1, dark)


static func _icon_sapling(canvas: CanvasItem, ox: float, oy: float, ps: float) -> void:
	var g := Color(0.18, 0.62, 0.10)
	var dg := Color(0.10, 0.40, 0.06)
	var lg := Color(0.35, 0.80, 0.18)
	var br := Color(0.45, 0.28, 0.08)
	# Trunk
	_r(canvas, ox, oy, ps, 7, 8, 2, 6, br)
	# Lower leaf cluster
	_r(canvas, ox, oy, ps, 4, 9, 8, 3, g)
	_r(canvas, ox, oy, ps, 4, 9, 3, 1, lg)
	_r(canvas, ox, oy, ps, 10, 11, 2, 1, dg)
	# Upper leaf cluster
	_r(canvas, ox, oy, ps, 5, 4, 6, 4, g)
	_r(canvas, ox, oy, ps, 5, 4, 2, 1, lg)
	_r(canvas, ox, oy, ps, 9, 6, 1, 1, dg)
	# Tip
	_r(canvas, ox, oy, ps, 7, 2, 2, 2, g)
	_r(canvas, ox, oy, ps, 7, 2, 1, 1, lg)


static func _icon_restore_orb(canvas: CanvasItem, ox: float, oy: float, ps: float) -> void:
	var g := Color(0.92, 0.78, 0.10)
	var dg := Color(0.62, 0.50, 0.04)
	var lg := Color(1.0, 0.96, 0.55)
	var di := Color(0.30, 0.90, 0.95)
	var dl := Color(0.75, 0.98, 1.0)
	# Gold orb body
	_r(canvas, ox, oy, ps, 5, 2, 6, 1, g)
	_r(canvas, ox, oy, ps, 3, 3, 10, 8, g)
	_r(canvas, ox, oy, ps, 5, 11, 6, 1, g)
	# Highlight
	_r(canvas, ox, oy, ps, 3, 3, 4, 3, lg)
	_r(canvas, ox, oy, ps, 3, 3, 2, 1, lg.lightened(0.2))
	# Shadow
	_r(canvas, ox, oy, ps, 10, 6, 3, 4, dg)
	_r(canvas, ox, oy, ps, 5, 11, 6, 1, dg)
	# Diamond core
	_r(canvas, ox, oy, ps, 7, 6, 2, 1, dl)
	_r(canvas, ox, oy, ps, 6, 7, 4, 1, di)
	_r(canvas, ox, oy, ps, 7, 8, 2, 1, dl)


static func get_max_durability(id: int) -> int:
	if id >= 220 and id <= 244:
		var tier: int = (id - 220) / 5
		match tier:
			0: return 89      # wood
			1: return 197     # stone
			2: return 375     # iron
			3: return 48      # gold
			4: return 2342    # diamond
	if id >= 250 and id <= 265:
		match id:
			LEATHER_HELMET:      return 83
			LEATHER_CHESTPLATE:  return 120
			LEATHER_LEGGINGS:    return 113
			LEATHER_BOOTS:       return 98
			IRON_HELMET:         return 248
			IRON_CHESTPLATE:     return 360
			IRON_LEGGINGS:       return 338
			IRON_BOOTS:          return 293
			GOLD_HELMET:         return 116
			GOLD_CHESTPLATE:     return 168
			GOLD_LEGGINGS:       return 158
			GOLD_BOOTS:          return 137
			DIAMOND_HELMET:      return 545
			DIAMOND_CHESTPLATE:  return 792
			DIAMOND_LEGGINGS:    return 743
			DIAMOND_BOOTS:       return 644
	return 0
