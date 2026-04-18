class_name BlockIcon

# Shared helper for drawing a block as an isometric 3D icon.
# Used by both the hotbar and the block select (inventory) screen.

const ATLAS_TILES: float = 70.0
const CUBE_H: float = 1.2

# Face tints approximate the ratio between top/side faces under the world's
# directional sun. No color manipulation beyond that — icons use the same
# atlas as placed blocks, so whatever saturation the textures have is the
# saturation they ship with.
const TOP_TINT := Color(1.0, 1.0, 1.0)
const RIGHT_TINT := Color(0.82, 0.82, 0.82)
const LEFT_TINT := Color(0.66, 0.66, 0.66)


# Returns (top_tile, side_tile) for a block.
# Bottom uses side unless a block needs a distinct bottom (TNT).
static func get_tiles(block_type: int) -> Vector2i:
	match block_type:
		Chunk.Block.STONE: return Vector2i(0, 0)
		Chunk.Block.COBBLESTONE: return Vector2i(1, 1)
		Chunk.Block.BRICK: return Vector2i(2, 2)
		Chunk.Block.DIRT: return Vector2i(3, 3)
		Chunk.Block.PLANKS: return Vector2i(4, 4)
		Chunk.Block.LOG: return Vector2i(6, 5)
		Chunk.Block.LEAVES: return Vector2i(7, 7)
		Chunk.Block.GLASS: return Vector2i(8, 8)
		Chunk.Block.SAND: return Vector2i(9, 9)
		Chunk.Block.GRASS: return Vector2i(10, 11)
		Chunk.Block.MOSSY_COBBLESTONE: return Vector2i(12, 12)
		Chunk.Block.BEDROCK: return Vector2i(13, 13)
		Chunk.Block.OBSIDIAN: return Vector2i(14, 14)
		Chunk.Block.BOOKSHELF: return Vector2i(4, 15)
		Chunk.Block.SPONGE: return Vector2i(16, 16)
		Chunk.Block.TNT: return Vector2i(17, 18)
		Chunk.Block.IRON_BLOCK: return Vector2i(20, 20)
		Chunk.Block.GOLD_BLOCK: return Vector2i(21, 21)
		Chunk.Block.COAL_ORE: return Vector2i(22, 22)
		Chunk.Block.IRON_ORE: return Vector2i(23, 23)
		Chunk.Block.GOLD_ORE: return Vector2i(24, 24)
		Chunk.Block.DIAMOND_ORE: return Vector2i(25, 25)
		Chunk.Block.WOOL_WHITE: return Vector2i(26, 26)
		Chunk.Block.WOOL_RED: return Vector2i(27, 27)
		Chunk.Block.WOOL_YELLOW: return Vector2i(28, 28)
		Chunk.Block.WOOL_GREEN: return Vector2i(29, 29)
		Chunk.Block.WOOL_BLUE: return Vector2i(30, 30)
		Chunk.Block.WOOL_ORANGE: return Vector2i(33, 33)
		Chunk.Block.WOOL_MAGENTA: return Vector2i(34, 34)
		Chunk.Block.WOOL_LIGHT_BLUE: return Vector2i(35, 35)
		Chunk.Block.WOOL_LIME: return Vector2i(36, 36)
		Chunk.Block.WOOL_PINK: return Vector2i(37, 37)
		Chunk.Block.WOOL_GRAY: return Vector2i(38, 38)
		Chunk.Block.WOOL_LIGHT_GRAY: return Vector2i(39, 39)
		Chunk.Block.WOOL_CYAN: return Vector2i(40, 40)
		Chunk.Block.WOOL_PURPLE: return Vector2i(41, 41)
		Chunk.Block.WOOL_BROWN: return Vector2i(42, 42)
		Chunk.Block.WOOL_BLACK: return Vector2i(43, 43)
		Chunk.Block.FIRE: return Vector2i(44, 44)
		Chunk.Block.LAVA: return Vector2i(45, 45)
		Chunk.Block.SMOOTH_STONE: return Vector2i(46, 46)
		Chunk.Block.SMOOTH_STONE_SLAB: return Vector2i(46, 46)
		Chunk.Block.BARRIER: return Vector2i(47, 47)
		Chunk.Block.POPPY: return Vector2i(48, 48)
		Chunk.Block.DANDELION: return Vector2i(49, 49)
		Chunk.Block.WATER: return Vector2i(32, 32)
		Chunk.Block.TORCH: return Vector2i(50, 50)
		Chunk.Block.NETHERRACK: return Vector2i(51, 51)
		Chunk.Block.NETHER_GOLD_ORE: return Vector2i(52, 52)
		Chunk.Block.NETHER_QUARTZ_ORE: return Vector2i(53, 53)
		Chunk.Block.NETHER_PORTAL: return Vector2i(54, 54)
		Chunk.Block.CRIMSON_NYLIUM: return Vector2i(55, 56)
		Chunk.Block.WARPED_NYLIUM: return Vector2i(57, 58)
		Chunk.Block.CRIMSON_STEM: return Vector2i(60, 59)
		Chunk.Block.WARPED_STEM: return Vector2i(62, 61)
		Chunk.Block.NETHER_WART_BLOCK: return Vector2i(63, 63)
		Chunk.Block.WARPED_WART_BLOCK: return Vector2i(64, 64)
		Chunk.Block.RED_MUSHROOM: return Vector2i(65, 65)
		Chunk.Block.BROWN_MUSHROOM: return Vector2i(66, 66)
		Chunk.Block.CRIMSON_FUNGUS: return Vector2i(67, 67)
		Chunk.Block.WARPED_FUNGUS: return Vector2i(68, 68)
		Chunk.Block.DIAMOND_BLOCK: return Vector2i(69, 69)
	return Vector2i(0, 0)


static func get_block_name(block_type: int) -> String:
	match block_type:
		Chunk.Block.STONE: return "Stone"
		Chunk.Block.COBBLESTONE: return "Cobblestone"
		Chunk.Block.BRICK: return "Brick"
		Chunk.Block.DIRT: return "Dirt"
		Chunk.Block.PLANKS: return "Wood Planks"
		Chunk.Block.LOG: return "Log"
		Chunk.Block.LEAVES: return "Leaves"
		Chunk.Block.GLASS: return "Glass"
		Chunk.Block.SAND: return "Sand"
		Chunk.Block.GRASS: return "Grass"
		Chunk.Block.MOSSY_COBBLESTONE: return "Mossy Cobblestone"
		Chunk.Block.BEDROCK: return "Bedrock"
		Chunk.Block.OBSIDIAN: return "Obsidian"
		Chunk.Block.BOOKSHELF: return "Bookshelf"
		Chunk.Block.SPONGE: return "Sponge"
		Chunk.Block.TNT: return "TNT"
		Chunk.Block.IRON_BLOCK: return "Iron Block"
		Chunk.Block.GOLD_BLOCK: return "Gold Block"
		Chunk.Block.COAL_ORE: return "Coal Ore"
		Chunk.Block.IRON_ORE: return "Iron Ore"
		Chunk.Block.GOLD_ORE: return "Gold Ore"
		Chunk.Block.DIAMOND_ORE: return "Diamond Ore"
		Chunk.Block.WOOL_WHITE: return "White Wool"
		Chunk.Block.WOOL_RED: return "Red Wool"
		Chunk.Block.WOOL_YELLOW: return "Yellow Wool"
		Chunk.Block.WOOL_GREEN: return "Green Wool"
		Chunk.Block.WOOL_BLUE: return "Blue Wool"
		Chunk.Block.WOOL_ORANGE: return "Orange Wool"
		Chunk.Block.WOOL_MAGENTA: return "Magenta Wool"
		Chunk.Block.WOOL_LIGHT_BLUE: return "Light Blue Wool"
		Chunk.Block.WOOL_LIME: return "Lime Wool"
		Chunk.Block.WOOL_PINK: return "Pink Wool"
		Chunk.Block.WOOL_GRAY: return "Gray Wool"
		Chunk.Block.WOOL_LIGHT_GRAY: return "Light Gray Wool"
		Chunk.Block.WOOL_CYAN: return "Cyan Wool"
		Chunk.Block.WOOL_PURPLE: return "Purple Wool"
		Chunk.Block.WOOL_BROWN: return "Brown Wool"
		Chunk.Block.WOOL_BLACK: return "Black Wool"
		Chunk.Block.FIRE: return "Fire"
		Chunk.Block.LAVA: return "Lava"
		Chunk.Block.SMOOTH_STONE: return "Smooth Stone"
		Chunk.Block.SMOOTH_STONE_SLAB: return "Smooth Stone Slab"
		Chunk.Block.BARRIER: return "Barrier"
		Chunk.Block.POPPY: return "Poppy"
		Chunk.Block.DANDELION: return "Dandelion"
		Chunk.Block.WATER: return "Water"
		Chunk.Block.TORCH: return "Torch"
		Chunk.Block.NETHERRACK: return "Netherrack"
		Chunk.Block.NETHER_GOLD_ORE: return "Nether Gold Ore"
		Chunk.Block.NETHER_QUARTZ_ORE: return "Nether Quartz Ore"
		Chunk.Block.NETHER_PORTAL: return "Nether Portal"
		Chunk.Block.CRIMSON_NYLIUM: return "Crimson Nylium"
		Chunk.Block.WARPED_NYLIUM: return "Warped Nylium"
		Chunk.Block.CRIMSON_STEM: return "Crimson Stem"
		Chunk.Block.WARPED_STEM: return "Warped Stem"
		Chunk.Block.NETHER_WART_BLOCK: return "Nether Wart Block"
		Chunk.Block.WARPED_WART_BLOCK: return "Warped Wart Block"
		Chunk.Block.RED_MUSHROOM: return "Red Mushroom"
		Chunk.Block.BROWN_MUSHROOM: return "Brown Mushroom"
		Chunk.Block.CRIMSON_FUNGUS: return "Crimson Fungus"
		Chunk.Block.WARPED_FUNGUS: return "Warped Fungus"
		Chunk.Block.DIAMOND_BLOCK: return "Diamond Block"
	return "Unknown"


## Plant-style blocks (fire, flowers) render as a single flat sprite in the
## inventory — the crossed-quad mesh is for world rendering only.
static func _is_sprite_block(block_type: int) -> bool:
	return block_type == Chunk.Block.FIRE \
		or block_type == Chunk.Block.POPPY \
		or block_type == Chunk.Block.DANDELION \
		or block_type == Chunk.Block.TORCH \
		or block_type == Chunk.Block.RED_MUSHROOM \
		or block_type == Chunk.Block.BROWN_MUSHROOM \
		or block_type == Chunk.Block.CRIMSON_FUNGUS \
		or block_type == Chunk.Block.WARPED_FUNGUS


# Draw an isometric 3D block at center (cx, cy) with size s (half-width of top diamond).
static func draw_iso(canvas: CanvasItem, atlas: Texture2D, cx: float, cy: float, s: float, block_type: int) -> void:
	if atlas == null:
		return

	# Sprite blocks: single flat quad using the block's atlas tile. Sized so
	# it visually matches the footprint of a full iso block in the same slot.
	if _is_sprite_block(block_type):
		var tiles_s: Vector2i = get_tiles(block_type)
		var tw_s: float = 1.0 / ATLAS_TILES
		var uv_inset_s: float = 0.5 / (ATLAS_TILES * 16.0)
		var v_inset_s: float = 0.5 / 16.0
		var u0: float = float(tiles_s.x) * tw_s + uv_inset_s
		var u1: float = float(tiles_s.x + 1) * tw_s - uv_inset_s
		# Square, roughly block-sized. Centered on (cx, cy) with a little
		# vertical offset so it sits where an iso block would.
		var half: float = s * 1.2
		var sprite_y_off: float = s * CUBE_H * 0.5
		var pts := PackedVector2Array([
			Vector2(cx - half, cy - half + sprite_y_off),
			Vector2(cx + half, cy - half + sprite_y_off),
			Vector2(cx + half, cy + half + sprite_y_off),
			Vector2(cx - half, cy + half + sprite_y_off),
		])
		var uvs := PackedVector2Array([
			Vector2(u0, v_inset_s),
			Vector2(u1, v_inset_s),
			Vector2(u1, 1.0 - v_inset_s),
			Vector2(u0, 1.0 - v_inset_s),
		])
		var cols := PackedColorArray([Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1)])
		canvas.draw_polygon(pts, cols, uvs, atlas)
		return

	var tiles: Vector2i = get_tiles(block_type)
	var tw: float = 1.0 / ATLAS_TILES
	# Inset UVs by half a texel inside each tile so linear filtering at the
	# tile boundary can't bleed in pixels from the neighboring tile. This is
	# what produced the faint seam between the three iso faces and at the
	# top/bottom edges of each face.
	var uv_inset: float = 0.5 / (ATLAS_TILES * 16.0)
	var v_inset: float = 0.5 / 16.0
	var top_u0: float = float(tiles.x) * tw + uv_inset
	var top_u1: float = float(tiles.x + 1) * tw - uv_inset
	var side_u0: float = float(tiles.y) * tw + uv_inset
	var side_u1: float = float(tiles.y + 1) * tw - uv_inset
	var v0: float = v_inset
	var v1: float = 1.0 - v_inset
	var h: float = s * CUBE_H
	# Slabs are half-height. Shrink the iso side-face height and shift the
	# top diamond downward so the slab visually rests on the bottom of the
	# slot instead of floating mid-cube.
	if block_type == Chunk.Block.SMOOTH_STONE_SLAB:
		var full_h: float = h
		h = full_h * 0.5
		cy += full_h * 0.5
		# Slab sides are clipped — only show the top half of the side texture
		# (bottom half would be hidden by neighboring slab in the world).
		v0 = 0.5 + v_inset
		v1 = 1.0 - v_inset

	# Top face (diamond)
	var top_pts := PackedVector2Array([
		Vector2(cx, cy - s * 0.5),
		Vector2(cx + s, cy),
		Vector2(cx, cy + s * 0.5),
		Vector2(cx - s, cy),
	])
	var top_uvs := PackedVector2Array([
		Vector2(top_u0, v0),
		Vector2(top_u1, v0),
		Vector2(top_u1, v1),
		Vector2(top_u0, v1),
	])
	var top_colors := PackedColorArray([TOP_TINT, TOP_TINT, TOP_TINT, TOP_TINT])
	canvas.draw_polygon(top_pts, top_colors, top_uvs, atlas)

	# Left face
	var left_pts := PackedVector2Array([
		Vector2(cx - s, cy),
		Vector2(cx, cy + s * 0.5),
		Vector2(cx, cy + s * 0.5 + h),
		Vector2(cx - s, cy + h),
	])
	var left_uvs := PackedVector2Array([
		Vector2(side_u0, v0),
		Vector2(side_u1, v0),
		Vector2(side_u1, v1),
		Vector2(side_u0, v1),
	])
	var left_colors := PackedColorArray([LEFT_TINT, LEFT_TINT, LEFT_TINT, LEFT_TINT])
	canvas.draw_polygon(left_pts, left_colors, left_uvs, atlas)

	# Right face
	var right_pts := PackedVector2Array([
		Vector2(cx, cy + s * 0.5),
		Vector2(cx + s, cy),
		Vector2(cx + s, cy + h),
		Vector2(cx, cy + s * 0.5 + h),
	])
	var right_uvs := PackedVector2Array([
		Vector2(side_u0, v0),
		Vector2(side_u1, v0),
		Vector2(side_u1, v1),
		Vector2(side_u0, v1),
	])
	var right_colors := PackedColorArray([RIGHT_TINT, RIGHT_TINT, RIGHT_TINT, RIGHT_TINT])
	canvas.draw_polygon(right_pts, right_colors, right_uvs, atlas)
