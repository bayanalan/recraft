class_name BlockTextures

const TILE_SIZE: int = 16
const TILE_COUNT: int = 70
# Atlas layout (left to right):
# 0  stone            1  cobblestone       2  brick
# 3  dirt             4  planks            5  log_side
# 6  log_top          7  leaves            8  glass
# 9  sand             10 grass_top         11 grass_side
# 12 mossy_cobble     13 bedrock           14 obsidian
# 15 bookshelf_side   16 sponge            17 tnt_top
# 18 tnt_side         19 tnt_bottom        20 iron_block
# 21 gold_block       22 coal_ore          23 iron_ore
# 24 gold_ore         25 diamond_ore       26 wool_white
# 27 wool_red         28 wool_yellow       29 wool_green
# 30 wool_blue        31 world_bedrock     32 water
# 33 wool_orange      34 wool_magenta      35 wool_light_blue
# 36 wool_lime        37 wool_pink         38 wool_gray
# 39 wool_light_gray  40 wool_cyan         41 wool_purple
# 42 wool_brown       43 wool_black        44 fire
# 45 lava             46 smooth_stone      47 barrier
# 48 poppy            49 dandelion         50 torch
# 51 netherrack       52 nether_gold_ore   53 nether_quartz_ore
# 54 nether_portal    55 crimson_nylium_t  56 crimson_nylium_s
# 57 warped_nylium_t  58 warped_nylium_s   59 crimson_stem_s
# 60 crimson_stem_t   61 warped_stem_s     62 warped_stem_t
# 63 nether_wart      64 warped_wart       65 red_mushroom
# 66 brown_mushroom   67 crimson_fungus    68 warped_fungus
# 69 diamond_block

static var _cached: ImageTexture = null
static var _cached_icon: ImageTexture = null
# Whether the currently-cached atlas has mipmaps baked in.
static var _cached_mipmaps: bool = false
# The mipmap preference the caller wants. Set via `set_mipmaps()` from the
# settings handler; next atlas build honors this.
static var _want_mipmaps: bool = false

# +4% chroma lift on placed blocks. Gray/near-gray pixels (stone) are
# unaffected (their delta from luma is ~0); only saturated pixels (wool,
# flowers) get a visible boost. Applied once at atlas build time.
const WORLD_SATURATION: float = 1.04
const _LUMA_R: float = 0.2126
const _LUMA_G: float = 0.7152
const _LUMA_B: float = 0.0722


## Returns (and caches) the block atlas. `_want_mipmaps` controls whether the
## returned texture has mipmap levels baked in — Godot's shader sampler falls
## back to base-level-only sampling for a texture with no mipmaps, so the
## shader hint can safely request `_mipmap_anisotropic` regardless and the
## actual LOD behavior is gated by the texture itself.
static func create_atlas() -> ImageTexture:
	# Invalidate if the mipmap preference changed since last build.
	if _cached != null and _cached_mipmaps != _want_mipmaps:
		_cached = null
	if _cached != null:
		return _cached
	# Base image needs `use_mipmaps = true` for generate_mipmaps() to work —
	# that flag is the 3rd arg of Image.create().
	var img := Image.create(TILE_SIZE * TILE_COUNT, TILE_SIZE, _want_mipmaps, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Originals
	_draw_stone(img, rng, 0)
	_draw_cobblestone(img, rng, 1)
	_draw_brick(img, rng, 2)
	_draw_dirt(img, rng, 3)
	_draw_planks(img, rng, 4)
	_draw_log_side(img, rng, 5)
	_draw_log_top(img, rng, 6)
	_draw_leaves(img, rng, 7)
	_draw_glass(img, rng, 8)
	_draw_sand(img, rng, 9)
	_draw_grass_top(img, rng, 10)
	_draw_grass_side(img, rng, 11)

	# New additions
	_draw_mossy_cobble(img, rng, 12)
	_draw_bedrock(img, rng, 13)
	_draw_obsidian(img, rng, 14)
	_draw_bookshelf_side(img, rng, 15)
	_draw_sponge(img, rng, 16)
	_draw_tnt_top(img, rng, 17)
	_draw_tnt_side(img, rng, 18)
	_draw_tnt_bottom(img, rng, 19)
	_draw_iron_block(img, rng, 20)
	_draw_gold_block(img, rng, 21)
	# Coal gets bigger deposits than iron/gold — coal seams are chunkier
	# lumps in classic Minecraft art, so 4-10 px per cluster vs 2-7 for the
	# smaller metallic ores.
	_draw_ore(img, rng, 22, Color(0.05, 0.05, 0.05), 4, 10)   # coal
	_draw_ore(img, rng, 23, Color(0.62, 0.46, 0.33))   # iron
	_draw_ore(img, rng, 24, Color(0.78, 0.66, 0.18))   # gold
	_draw_diamond_ore(img, rng, 25)                    # diamond (scattered splotches)
	_draw_wool(img, rng, 26, Color(0.70, 0.70, 0.71))  # white
	_draw_wool(img, rng, 27, Color(0.58, 0.14, 0.14))  # red
	_draw_wool(img, rng, 28, Color(0.70, 0.63, 0.18))  # yellow
	_draw_wool(img, rng, 29, Color(0.18, 0.44, 0.18))  # green
	_draw_wool(img, rng, 30, Color(0.16, 0.22, 0.58))  # blue
	_draw_world_bedrock(img, rng, 31)
	_draw_water(img, rng, 32)
	# Remaining classic-Minecraft wool palette (tiles 33-43).
	_draw_wool(img, rng, 33, Color(0.72, 0.44, 0.13))  # orange
	_draw_wool(img, rng, 34, Color(0.62, 0.26, 0.62))  # magenta
	_draw_wool(img, rng, 35, Color(0.34, 0.52, 0.70))  # light blue
	_draw_wool(img, rng, 36, Color(0.35, 0.62, 0.14))  # lime
	_draw_wool(img, rng, 37, Color(0.78, 0.52, 0.62))  # pink
	_draw_wool(img, rng, 38, Color(0.26, 0.26, 0.27))  # gray
	_draw_wool(img, rng, 39, Color(0.50, 0.50, 0.51))  # light gray
	_draw_wool(img, rng, 40, Color(0.18, 0.54, 0.62))  # cyan
	_draw_wool(img, rng, 41, Color(0.42, 0.18, 0.58))  # purple
	_draw_wool(img, rng, 42, Color(0.42, 0.28, 0.16))  # brown
	_draw_wool(img, rng, 43, Color(0.09, 0.09, 0.10))  # black
	_draw_fire(img, rng, 44)
	_draw_lava(img, rng, 45)
	_draw_smooth_stone(img, rng, 46)
	_draw_barrier(img, rng, 47)
	_draw_poppy(img, rng, 48)
	_draw_dandelion(img, rng, 49)
	_draw_torch(img, rng, 50)
	_draw_netherrack(img, rng, 51)
	_draw_nether_gold_ore(img, rng, 52)
	_draw_nether_quartz_ore(img, rng, 53)
	_draw_nether_portal(img, rng, 54)
	_draw_crimson_nylium_top(img, rng, 55)
	_draw_nylium_side(img, rng, 56, Color(0.55, 0.10, 0.10))  # crimson side
	_draw_warped_nylium_top(img, rng, 57)
	_draw_nylium_side(img, rng, 58, Color(0.15, 0.45, 0.45))  # warped side
	_draw_stem_side(img, rng, 59, Color(0.45, 0.08, 0.25), Color(0.30, 0.05, 0.18))
	_draw_stem_top(img, rng, 60, Color(0.60, 0.20, 0.28), Color(0.45, 0.10, 0.20))
	_draw_stem_side(img, rng, 61, Color(0.18, 0.48, 0.55), Color(0.10, 0.32, 0.38))
	_draw_stem_top(img, rng, 62, Color(0.30, 0.62, 0.68), Color(0.18, 0.48, 0.55))
	_draw_wart_block(img, rng, 63, Color(0.60, 0.08, 0.08), Color(0.45, 0.05, 0.05), Color(0.80, 0.20, 0.10))
	_draw_wart_block(img, rng, 64, Color(0.10, 0.55, 0.50), Color(0.05, 0.35, 0.35), Color(0.30, 0.75, 0.70))
	# Nether mushrooms (X-cross plants)
	_draw_red_mushroom(img, rng, 65)
	_draw_brown_mushroom(img, rng, 66)
	_draw_crimson_fungus(img, rng, 67)
	_draw_warped_fungus(img, rng, 68)
	# Gem block — polished diamond, matches the iron/gold family style.
	_draw_diamond_block(img, rng, 69)

	# World saturation lift — applied before mipmaps so downsampled levels
	# inherit the boosted palette. Adaptive, so stone-gray pixels don't
	# accidentally grow chroma.
	_apply_saturation(img, WORLD_SATURATION)
	# If mipmaps are requested, generate them now — after all the per-tile
	# pixel pokes are done. Atlases of 800×16 are small so this is fast.
	if _want_mipmaps:
		img.generate_mipmaps()
	_cached = ImageTexture.create_from_image(img)
	_cached_mipmaps = _want_mipmaps
	return _cached


## UI-only atlas: a desaturated COPY of the base atlas, baked pixel-by-pixel.
## Icon atlas — used by the hotbar and block-select inventory screen.
## A SEPARATE texture from the world atlas, with 50% of each pixel's chroma
## removed (uniform, not adaptive). This is the most direct way to desaturate
## icons: the pixel data itself is muted, no shader or tint overlay involved.
## Cached independently from the world atlas.
const ICON_DESATURATION: float = 0.68
# Pure brightness lift applied to the icon atlas AFTER desaturation. Uniform
# per-channel multiply preserves HSV saturation (so "not more saturated,
# just brighter"); any channel that would exceed 1.0 is clamped.
const ICON_BRIGHTNESS: float = 1.15

static func create_icon_atlas() -> ImageTexture:
	if _cached_icon != null:
		return _cached_icon
	# Start from the raw (pre-WORLD_SATURATION) image. Rebuild the base
	# atlas image from scratch so we don't inherit the world's +4% boost.
	# This means icon atlas is desaturated relative to RAW textures, which
	# gives the biggest perceived muting.
	var base: ImageTexture = create_atlas()
	var src: Image = base.get_image()
	var img: Image = src.duplicate(true) as Image
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var luma: float = c.r * _LUMA_R + c.g * _LUMA_G + c.b * _LUMA_B
			var r: float = luma + (c.r - luma) * ICON_DESATURATION
			var g: float = luma + (c.g - luma) * ICON_DESATURATION
			var b: float = luma + (c.b - luma) * ICON_DESATURATION
			img.set_pixel(x, y, Color(
				clampf(r * ICON_BRIGHTNESS, 0.0, 1.0),
				clampf(g * ICON_BRIGHTNESS, 0.0, 1.0),
				clampf(b * ICON_BRIGHTNESS, 0.0, 1.0),
				c.a,
			))
	_cached_icon = ImageTexture.create_from_image(img)
	return _cached_icon


## Adaptive saturation pass used by the world atlas's +4% chroma lift.
## The effective strength scales by pixel chroma so gray stone is unaffected
## while saturated blocks (wool, flowers) get the full boost.
static func _apply_saturation(img: Image, sat: float) -> void:
	if is_equal_approx(sat, 1.0):
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.001:
				continue
			var luma: float = c.r * _LUMA_R + c.g * _LUMA_G + c.b * _LUMA_B
			var chroma: float = maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			var eff: float = lerpf(1.0, sat, chroma)
			img.set_pixel(x, y, Color(
				luma + (c.r - luma) * eff,
				luma + (c.g - luma) * eff,
				luma + (c.b - luma) * eff,
				c.a,
			))


## Settings-driven toggle. Call before (or anytime — the next `create_atlas()`
## will rebuild). Triggering a rebuild on a live world is the responsibility
## of the caller; this class just stores the preference.
static func set_mipmaps(enabled: bool) -> void:
	_want_mipmaps = enabled


## Invalidate all cached atlases. Called when settings that affect atlas
## construction change (mipmaps), so the next build rebuilds from scratch.
static func invalidate_cache() -> void:
	_cached = null
	_cached_icon = null


static func _draw_water(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Pixel-art water tile — not a smooth gradient. Four discrete blues
	# arranged as wavy horizontal bands with per-pixel jitter, plus a
	# handful of bright "glint" pixels for surface sparkle. Each pixel is a
	# flat color pick (no interpolation) so the result reads as chunky pixel
	# art at any zoom level.
	var shades: Array = [
		Color(0.08, 0.22, 0.54),   # deep
		Color(0.14, 0.32, 0.68),
		Color(0.22, 0.46, 0.84),
		Color(0.38, 0.62, 0.96),   # crest
	]
	for y: int in TILE_SIZE:
		# Two overlapping sine-like row selectors give each row a stable
		# "base shade index" that shifts as you move up/down the tile, so
		# you see distinct wave bands rather than a smooth gradient.
		var wave: float = sin(float(y) * 1.1) * 0.5 + 0.5
		var wave2: float = sin(float(y) * 0.37 + 1.2) * 0.5 + 0.5
		var base_idx: int = clampi(int((wave * 0.65 + wave2 * 0.35) * 4.0), 0, 3)
		for x: int in TILE_SIZE:
			# Per-pixel jitter picks an adjacent shade ±1 with low probability
			# so bands aren't razor-straight — matches hand-drawn water.
			var jitter: float = rng.randf()
			var idx: int = base_idx
			if jitter < 0.18 and idx > 0:
				idx -= 1
			elif jitter > 0.82 and idx < 3:
				idx += 1
			_px(img, t, x, y, shades[idx])
	# Horizontal ripple highlights — a few one-pixel-tall rows of the
	# brightest shade form "crests" that read as surface waves.
	for ry: int in [3, 9, 13]:
		if ry >= TILE_SIZE:
			continue
		var start: int = rng.randi_range(0, 4)
		for x: int in range(start, TILE_SIZE, 2):
			_px(img, t, x, ry, shades[3])
	# Bright glint pinpoints — super-light cyan pixels that look like light
	# catching the surface.
	var glint := Color(0.80, 0.94, 1.00)
	for _i: int in 6:
		var gx: int = rng.randi_range(1, TILE_SIZE - 2)
		var gy: int = rng.randi_range(1, TILE_SIZE - 2)
		_px(img, t, gx, gy, glint)


static func _px(img: Image, t: int, x: int, y: int, c: Color) -> void:
	img.set_pixel(t * TILE_SIZE + x, y, c)


static func _stone(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_stone(img, rng, t)


static func _draw_stone(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Improved stone: gray base with subtle variation and darker crack lines
	var base := Color(0.40, 0.40, 0.40)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.15:
				c = Color(0.30, 0.30, 0.31)
			elif r < 0.55:
				c = Color(0.37, 0.37, 0.37)
			elif r < 0.85:
				c = base
			else:
				c = Color(0.44, 0.44, 0.43)
			_px(img, t, x, y, c)

	# Crack lines
	for i: int in 4:
		var cy: int = rng.randi_range(1, 14)
		var cx0: int = rng.randi_range(0, 8)
		var cx1: int = rng.randi_range(cx0 + 2, 15)
		for x: int in range(cx0, cx1 + 1):
			_px(img, t, x, cy, Color(0.26, 0.26, 0.27))
			if rng.randf() < 0.4:
				cy += rng.randi_range(-1, 1)
				cy = clampi(cy, 0, 15)


static func _draw_cobblestone(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Cobbled stones laid out as clearly separated rounded chunks with a
	# dark mortar channel between them. Arranged as a 3×3 grid of stones
	# where every other row is offset so the stones interlock (classic
	# cobblestone masonry). Each stone is given a base shade + top-left
	# highlight + bottom-right shadow so it reads as a rounded rock, not a
	# flat color patch.
	var mortar_dk := Color(0.16, 0.16, 0.17)
	var mortar := Color(0.22, 0.22, 0.23)
	var stone_shades: Array = [
		Color(0.40, 0.40, 0.41),
		Color(0.46, 0.46, 0.46),
		Color(0.34, 0.34, 0.35),
		Color(0.42, 0.43, 0.42),
		Color(0.38, 0.39, 0.38),
	]

	# Start by filling the whole tile with mortar. Stones are overlaid
	# afterward — any pixel left uncovered is visible mortar.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, mortar)

	# 3 rows × 3 stones per row. Stones are ~5×5 with the dark mortar
	# filling the ~1-pixel channels between.
	# Row y ranges (with mortar between): 0..4, 6..10, 12..15 (short last row).
	var row_definitions: Array = [
		{"y0": 0, "y1": 4, "offset": 0},
		{"y0": 6, "y1": 10, "offset": 3},    # interlocked offset
		{"y0": 12, "y1": 15, "offset": 0},
	]

	for row_def: Dictionary in row_definitions:
		var y0: int = row_def["y0"]
		var y1: int = row_def["y1"]
		var offset: int = row_def["offset"]
		# Stone slots across. Width 5, gap 1 between.
		var x: int = offset - 6  # start negative so partial stones appear on left edge
		while x < TILE_SIZE:
			var bx0: int = x
			var bx1: int = x + 4
			# Draw this stone.
			var shade: Color = stone_shades[rng.randi() % stone_shades.size()]
			for py: int in range(y0, y1 + 1):
				for px: int in range(bx0, bx1 + 1):
					if px < 0 or px >= TILE_SIZE or py < 0 or py >= TILE_SIZE:
						continue
					var n: float = (rng.randf() - 0.5) * 0.05
					_px(img, t, px, py, Color(
						clampf(shade.r + n, 0.0, 1.0),
						clampf(shade.g + n, 0.0, 1.0),
						clampf(shade.b + n, 0.0, 1.0),
					))
			# Top-left highlight along the rock's "lit" edge — gives the
			# stone a rounded, 3D look.
			var hi: Color = shade.lightened(0.20)
			for px: int in range(bx0, bx1 + 1):
				if px >= 0 and px < TILE_SIZE and y0 >= 0 and y0 < TILE_SIZE:
					_px(img, t, px, y0, hi)
			if bx0 >= 0 and bx0 < TILE_SIZE:
				for py: int in range(y0, y1 + 1):
					if py < TILE_SIZE:
						_px(img, t, bx0, py, hi)
			# Bottom-right shadow.
			var sh: Color = shade.darkened(0.35)
			if y1 >= 0 and y1 < TILE_SIZE:
				for px: int in range(bx0 + 1, bx1 + 1):
					if px >= 0 and px < TILE_SIZE:
						_px(img, t, px, y1, sh)
			if bx1 >= 0 and bx1 < TILE_SIZE:
				for py: int in range(y0 + 1, y1 + 1):
					if py < TILE_SIZE:
						_px(img, t, bx1, py, sh)
			# Round the corners — convert the four corners from stone to
			# mortar to give each rock a subtly curved silhouette.
			if bx0 >= 0 and bx0 < TILE_SIZE and y0 >= 0 and y0 < TILE_SIZE:
				_px(img, t, bx0, y0, mortar_dk)
			if bx1 >= 0 and bx1 < TILE_SIZE and y0 >= 0 and y0 < TILE_SIZE:
				_px(img, t, bx1, y0, mortar)
			if bx0 >= 0 and bx0 < TILE_SIZE and y1 >= 0 and y1 < TILE_SIZE:
				_px(img, t, bx0, y1, mortar)
			if bx1 >= 0 and bx1 < TILE_SIZE and y1 >= 0 and y1 < TILE_SIZE:
				_px(img, t, bx1, y1, mortar_dk)
			x += 6

	# Deeper mortar flecks scattered through the lines for a weathered look.
	for _i: int in 8:
		var fx: int = rng.randi_range(0, TILE_SIZE - 1)
		var fy: int = rng.randi_range(0, TILE_SIZE - 1)
		# Only darken already-mortar pixels.
		var existing: Color = img.get_pixel(t * TILE_SIZE + fx, fy)
		if existing.r < 0.28:
			_px(img, t, fx, fy, mortar_dk)


static func _draw_brick(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Classic running-bond brickwork. Bricks are 8 wide × 4 tall, offset by
	# 4 pixels every other row so the vertical mortar joints alternate. Each
	# brick gets its own base shade (so adjacent bricks aren't identical)
	# plus a 1-pixel highlight along its top-left edge and a 1-pixel shadow
	# along its bottom-right, giving each brick a tiny pressed-tile bevel
	# that reads clearly at 16px.
	var mortar := Color(0.40, 0.38, 0.34)         # darker mortar than before
	var mortar_dk := Color(0.30, 0.28, 0.25)
	var brick_shades: Array = [
		Color(0.58, 0.24, 0.16),
		Color(0.64, 0.28, 0.18),
		Color(0.68, 0.32, 0.22),
		Color(0.54, 0.22, 0.14),
		Color(0.62, 0.26, 0.17),
	]

	# Fill whole tile with mortar first — bricks are then drawn on top so
	# any gaps read as mortar, not as whatever noise happened to land there.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, mortar)

	# Draw each brick. Brick rows are 4 pixels tall (y=0..3, 4..7, 8..11, 12..15).
	# Odd rows offset by 4 px to produce the running bond.
	for brick_row: int in 4:
		var y0: int = brick_row * 4
		var y1: int = y0 + 3            # inclusive bottom row of bricks, row 3 is mortar of next
		var row_offset: int = 4 if brick_row % 2 == 1 else 0
		# Six brick slots across (16 + offset), spaced every 8 px.
		var x_starts: Array[int] = []
		var start: int = -row_offset
		while start < TILE_SIZE:
			x_starts.append(start)
			start += 8
		for xs: int in x_starts:
			var brick_w: int = 7           # 7 visible cols, 1 col for mortar between
			var bx0: int = xs
			var bx1: int = xs + brick_w - 1
			# Pick a base shade per brick.
			var base: Color = brick_shades[rng.randi() % brick_shades.size()]
			# Fill the brick body.
			for y: int in range(y0, y1):
				for x: int in range(bx0, bx1 + 1):
					if x < 0 or x >= TILE_SIZE or y >= TILE_SIZE:
						continue
					# Slight per-pixel variation for texture without speckle.
					var n: float = (rng.randf() - 0.5) * 0.06
					var c := Color(
						clampf(base.r + n, 0.0, 1.0),
						clampf(base.g + n * 0.8, 0.0, 1.0),
						clampf(base.b + n * 0.6, 0.0, 1.0),
					)
					_px(img, t, x, y, c)
			# Top-left highlight line (1 px across the top of the brick + 1 px down the left).
			var hi: Color = base.lightened(0.18)
			for x: int in range(bx0, bx1 + 1):
				if x >= 0 and x < TILE_SIZE and y0 >= 0 and y0 < TILE_SIZE:
					_px(img, t, x, y0, hi)
			if bx0 >= 0 and bx0 < TILE_SIZE:
				for y: int in range(y0, y1):
					if y < TILE_SIZE:
						_px(img, t, bx0, y, hi)
			# Bottom-right shadow — single row/column of the darker mortar
			# tone, inset one pixel into the brick so the bevel reads.
			var sh: Color = base.darkened(0.28)
			if y1 - 1 >= 0 and y1 - 1 < TILE_SIZE:
				for x: int in range(bx0 + 1, bx1 + 1):
					if x >= 0 and x < TILE_SIZE:
						_px(img, t, x, y1 - 1, sh)
			if bx1 >= 0 and bx1 < TILE_SIZE:
				for y: int in range(y0 + 1, y1):
					if y < TILE_SIZE:
						_px(img, t, bx1, y, sh)

	# Emphasize horizontal mortar rows with the darker mortar tone so the
	# courses stand out crisply.
	for y: int in [3, 7, 11, 15]:
		if y >= TILE_SIZE:
			continue
		for x: int in TILE_SIZE:
			_px(img, t, x, y, mortar_dk)


static func _draw_dirt(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.20:
				c = Color(0.38, 0.22, 0.08)
			elif r < 0.60:
				c = Color(0.50, 0.32, 0.13)
			elif r < 0.90:
				c = Color(0.56, 0.36, 0.16)
			else:
				c = Color(0.35, 0.28, 0.18)
			_px(img, t, x, y, c)


static func _draw_planks(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var plank: int = x / 4
			var base: float = 0.58 + float(plank % 2) * 0.06
			var r: float = rng.randf() * 0.06
			var c := Color(base + r, (base - 0.12) + r, (base - 0.28) + r)
			if x % 4 == 0:
				c = c.darkened(0.15)
			_px(img, t, x, y, c)


static func _draw_log_side(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Bark side. Intentionally MUCH darker than the inner-ring top face so
	# the bark/heartwood contrast reads clearly in-world — the top of a cut
	# log should look distinctly brighter than its sides. Vertical grain is
	# drawn as three darker groove columns + two lighter ridge columns over
	# a deep-brown base, with gentle per-pixel noise so the bark doesn't
	# band visibly at larger view scales.
	var bark_base := Color(0.18, 0.10, 0.05)   # very dark brown
	var bark_mid := Color(0.22, 0.13, 0.06)
	var groove := Color(0.10, 0.06, 0.03)      # near-black bark cracks
	var ridge := Color(0.28, 0.18, 0.09)       # slight highlight between grooves
	var col_class := PackedInt32Array()
	col_class.resize(TILE_SIZE)
	# 0 = mid, 1 = groove (darker), 2 = ridge (lighter).
	for x: int in TILE_SIZE:
		col_class[x] = 0
	for col: int in [1, 6, 11, 14]:
		col_class[col] = 1
	for col: int in [4, 9]:
		col_class[col] = 2

	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var base: Color
			match col_class[x]:
				1: base = groove
				2: base = ridge
				_: base = bark_mid if ((x + y) & 1) == 0 else bark_base
			# Per-pixel jitter, small so the bark doesn't get speckly.
			var n: float = (rng.randf() - 0.5) * 0.04
			_px(img, t, x, y, Color(
				clampf(base.r + n, 0.0, 1.0),
				clampf(base.g + n * 0.6, 0.0, 1.0),
				clampf(base.b + n * 0.4, 0.0, 1.0),
			))
	# Occasional horizontal bark "knots" — short dark flecks breaking up the
	# vertical grain pattern so the bark isn't a perfect rain of lines.
	for _i: int in 4:
		var kx: int = rng.randi_range(1, TILE_SIZE - 3)
		var ky: int = rng.randi_range(2, TILE_SIZE - 3)
		_px(img, t, kx, ky, groove)
		_px(img, t, kx + 1, ky, groove)


static func _draw_log_top(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Cut-log end grain. Warm, light heartwood with concentric growth rings
	# and a narrow dark bark ring at the very edge. Significantly brighter
	# than the bark side so a chopped log visibly shows "this side was cut,
	# that side was covered in bark".
	var center := Vector2(7.5, 7.5)
	# Palette — pale warm wood with three ring tones + dark bark edge.
	var wood_lt := Color(0.82, 0.66, 0.38)
	var wood_md := Color(0.74, 0.58, 0.32)
	var wood_dk := Color(0.66, 0.50, 0.26)
	var ring := Color(0.50, 0.34, 0.16)         # dark growth ring
	var bark_edge := Color(0.18, 0.10, 0.05)    # matches log_side base
	var heart := Color(0.60, 0.40, 0.20)        # heartwood pip at center

	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var dist: float = Vector2(x, y).distance_to(center)
			var c: Color
			if dist >= 7.2:
				c = bark_edge
			elif dist >= 6.3:
				# Thin inner bark layer — transition between dark bark and
				# bright heartwood so the two regions don't smash into each
				# other.
				c = Color(0.34, 0.22, 0.10)
			elif dist >= 5.2 and dist < 5.8:
				c = ring
			elif dist >= 3.3 and dist < 3.7:
				c = ring
			elif dist >= 1.4 and dist < 1.8:
				c = ring
			else:
				# Three tones of heartwood chosen by a cheap radial pattern
				# to give the rings subtle alternation without computing
				# noise per pixel.
				var band: int = int(dist * 2.0) % 3
				c = wood_lt if band == 0 else (wood_md if band == 1 else wood_dk)
			# Subtle warm jitter so the wood isn't dead-flat.
			var n: float = rng.randf() * 0.04
			c = Color(
				clampf(c.r + n, 0.0, 1.0),
				clampf(c.g + n * 0.8, 0.0, 1.0),
				clampf(c.b + n * 0.4, 0.0, 1.0),
			)
			_px(img, t, x, y, c)
	# Bright center heartwood pip (2×2) — a small visual anchor marking the
	# core of the log.
	_px(img, t, 7, 7, heart); _px(img, t, 8, 7, heart)
	_px(img, t, 7, 8, heart); _px(img, t, 8, 8, heart)


static func _draw_leaves(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.15:
				c = Color(0.10, 0.30, 0.05)
			elif r < 0.4:
				c = Color(0.15, 0.40, 0.08)
			elif r < 0.7:
				c = Color(0.20, 0.50, 0.10)
			elif r < 0.9:
				c = Color(0.25, 0.55, 0.12)
			else:
				c = Color(0.12, 0.35, 0.06)
			_px(img, t, x, y, c)


static func _draw_glass(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var is_frame: bool = (x == 0 or x == 15 or y == 0 or y == 15)
			if is_frame:
				_px(img, t, x, y, Color(0.60, 0.65, 0.70))
			else:
				_px(img, t, x, y, Color(0.72, 0.82, 0.90, 0.3))


static func _draw_sand(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.3:
				c = Color(0.76, 0.70, 0.50)
			elif r < 0.7:
				c = Color(0.82, 0.76, 0.56)
			else:
				c = Color(0.86, 0.80, 0.60)
			_px(img, t, x, y, c)


static func _draw_grass_top(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.30:
				c = Color(0.22, 0.42, 0.08)
			elif r < 0.55:
				c = Color(0.30, 0.55, 0.12)
			elif r < 0.85:
				c = Color(0.38, 0.65, 0.18)
			else:
				c = Color(0.42, 0.72, 0.22)
			_px(img, t, x, y, c)


static func _draw_grass_side(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	var grass_depth: Array[int] = []
	for x: int in TILE_SIZE:
		grass_depth.append(rng.randi_range(2, 4))
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var c: Color
			if y < grass_depth[x]:
				c = Color(0.30, 0.55, 0.12) if rng.randf() > 0.35 else Color(0.22, 0.42, 0.08)
			else:
				var r: float = rng.randf()
				if r < 0.25:
					c = Color(0.40, 0.24, 0.09)
				elif r < 0.70:
					c = Color(0.50, 0.32, 0.13)
				else:
					c = Color(0.56, 0.36, 0.16)
			_px(img, t, x, y, c)


static func _draw_mossy_cobble(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Start with a cobblestone base then overlay moss
	_draw_cobblestone(img, rng, t)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			if r < 0.42:
				var g: float = 0.32 + rng.randf() * 0.18
				var moss := Color(0.14 + rng.randf() * 0.08, g, 0.08 + rng.randf() * 0.06)
				_px(img, t, x, y, moss)


static func _draw_bedrock(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Dark grey base so bedrock still reads as "nearly black" after the voxel
	# shader lifts midtones on lit faces.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var v: float = 0.07 + rng.randf() * 0.05
			_px(img, t, x, y, Color(v, v, v + 0.005))
	# Darker patches.
	for _i: int in 8:
		var cx: int = rng.randi() % TILE_SIZE
		var cy: int = rng.randi() % TILE_SIZE
		var size: int = rng.randi_range(1, 2)
		for dy: int in range(-size, size + 1):
			for dx: int in range(-size, size + 1):
				if absi(dx) + absi(dy) > size:
					continue
				var px: int = cx + dx
				var py: int = cy + dy
				if px >= 0 and px < TILE_SIZE and py >= 0 and py < TILE_SIZE:
					_px(img, t, px, py, Color(0.035, 0.035, 0.04))


static func _draw_world_bedrock(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Distinct from regular bedrock: pure-black base with subtle red-tinged
	# fissures so the player can recognize the unbreakable variant.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var v: float = 0.04 + rng.randf() * 0.05
			_px(img, t, x, y, Color(v, v * 0.92, v * 0.92))
	for _i: int in 12:
		var cx: int = rng.randi() % TILE_SIZE
		var cy: int = rng.randi() % TILE_SIZE
		var size: int = rng.randi_range(1, 2)
		for dy: int in range(-size, size + 1):
			for dx: int in range(-size, size + 1):
				if absi(dx) + absi(dy) > size:
					continue
				var px: int = cx + dx
				var py: int = cy + dy
				if px >= 0 and px < TILE_SIZE and py >= 0 and py < TILE_SIZE:
					_px(img, t, px, py, Color(0.16, 0.06, 0.06))


static func _draw_obsidian(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Polished volcanic glass — chunky rocky shards with razor-bright
	# specular highlights, not the old uniform noise. The surface is
	# built in three layers:
	#  1. A near-black base with very subtle per-pixel variation.
	#  2. A handful of sharp-edged polygon shards drawn as filled irregular
	#     regions, each with its own base tone — this creates the "rocky"
	#     faceted look instead of smooth powder.
	#  3. Specular highlights: sharp 1-2 pixel strokes of bright violet/white
	#     along the top-left edge of each shard, like light glancing off
	#     polished glass. Makes the surface unmistakably shiny.
	var very_dark := Color(0.04, 0.02, 0.07)
	var dark := Color(0.07, 0.04, 0.11)
	var mid := Color(0.11, 0.06, 0.17)
	var light := Color(0.16, 0.09, 0.24)
	var glint := Color(0.42, 0.26, 0.62)       # violet specular
	var hot := Color(0.72, 0.58, 0.88)         # near-white highlight

	# Layer 1 — near-black background with tiny jitter.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.45:
				c = very_dark
			elif r < 0.85:
				c = dark
			else:
				c = mid
			_px(img, t, x, y, c)

	# Layer 2 — 4 shard regions. Each shard is a small polygon defined by
	# an origin + a walk of adjacent pixels, yielding an irregular rocky
	# chunk. Shards use `light` so they read as raised facets catching
	# ambient light, vs the darker background acting as cracks between.
	for s: int in 4:
		var ox: int = rng.randi_range(2, TILE_SIZE - 3)
		var oy: int = rng.randi_range(2, TILE_SIZE - 3)
		var shard_size: int = rng.randi_range(5, 9)
		var cx: int = ox; var cy: int = oy
		var shard_cells: Array[Vector2i] = []
		for _i: int in shard_size:
			if cx >= 0 and cx < TILE_SIZE and cy >= 0 and cy < TILE_SIZE:
				_px(img, t, cx, cy, light)
				shard_cells.append(Vector2i(cx, cy))
			# Random walk biased toward diagonals for rocky edges.
			cx += rng.randi_range(-1, 1)
			cy += rng.randi_range(-1, 1)
		# Shadow line along the bottom-right edge of each shard for depth.
		for cell: Vector2i in shard_cells:
			var bx: int = cell.x + 1
			var by: int = cell.y + 1
			if bx < TILE_SIZE and by < TILE_SIZE and not shard_cells.has(Vector2i(bx, by)):
				_px(img, t, bx, by, very_dark)

	# Layer 3 — sharp specular glints. Scatter 6-8 one-pixel violet specks
	# as subtle shine, then 3-4 two-pixel bright strokes as "catch the
	# light" highlights along shard edges.
	for _i: int in rng.randi_range(8, 12):
		var gx: int = rng.randi_range(1, TILE_SIZE - 2)
		var gy: int = rng.randi_range(1, TILE_SIZE - 2)
		_px(img, t, gx, gy, glint)
	for _i: int in 4:
		var sx: int = rng.randi_range(2, TILE_SIZE - 3)
		var sy: int = rng.randi_range(2, TILE_SIZE - 3)
		_px(img, t, sx, sy, hot)
		# Short 2-pixel highlight stroke (horizontal or vertical).
		if rng.randf() < 0.5:
			if sx + 1 < TILE_SIZE:
				_px(img, t, sx + 1, sy, glint)
		else:
			if sy + 1 < TILE_SIZE:
				_px(img, t, sx, sy + 1, glint)


static func _draw_bookshelf_side(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	var plank_colors: Array = [
		Color(0.58, 0.42, 0.22),
		Color(0.52, 0.38, 0.20),
		Color(0.62, 0.46, 0.24),
	]
	var book_colors: Array = [
		Color(0.62, 0.20, 0.20),  # red
		Color(0.22, 0.42, 0.70),  # blue
		Color(0.58, 0.48, 0.16),  # ochre
		Color(0.28, 0.50, 0.22),  # green
		Color(0.48, 0.26, 0.10),  # brown
		Color(0.70, 0.58, 0.24),  # tan
	]
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			if y < 2 or y >= TILE_SIZE - 2:
				# Plank border (top/bottom)
				var pc: Color = plank_colors[rng.randi() % plank_colors.size()]
				_px(img, t, x, y, pc)
			else:
				# Books in the middle 12 rows
				# Each book is ~3px wide including a 1px dark gap
				var book_slot: int = x / 3
				var is_gap: bool = (x % 3) == 2
				if is_gap:
					_px(img, t, x, y, Color(0.08, 0.05, 0.02))
				else:
					var bc: Color = book_colors[(book_slot + (y % 2)) % book_colors.size()]
					var shade: float = 1.0 + (rng.randf() - 0.5) * 0.08
					_px(img, t, x, y, bc * shade)


static func _draw_sponge(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.18:
				c = Color(0.42, 0.32, 0.08)  # pore
			elif r < 0.42:
				c = Color(0.78, 0.70, 0.22)
			elif r < 0.80:
				c = Color(0.86, 0.78, 0.26)
			else:
				c = Color(0.92, 0.84, 0.30)
			_px(img, t, x, y, c)


static func _draw_tnt_top(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var v: float = 0.72 + rng.randf() * 0.06
			_px(img, t, x, y, Color(v, v, v * 0.96))
	# Red fuse center
	for dy: int in range(6, 10):
		for dx: int in range(6, 10):
			_px(img, t, dx, dy, Color(0.62, 0.14, 0.09))
	# Yellow fuse spark (center pixel)
	_px(img, t, 7, 7, Color(0.78, 0.64, 0.14))
	_px(img, t, 8, 8, Color(0.78, 0.64, 0.14))


static func _draw_tnt_side(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var c: Color
			if y < 2:
				# Top fuse strip: yellow/white with slight variation
				var v: float = 0.70 + rng.randf() * 0.06
				c = Color(v, v * 0.92, v * 0.30)
			elif y >= 6 and y <= 9:
				# Label band — off-white background for the "TNT" letters area
				if y == 7 or y == 8:
					c = Color(0.76, 0.76, 0.74)
				else:
					c = Color(0.62, 0.14, 0.10)
			else:
				# Body: red with slight horizontal striping
				var r: float = rng.randf()
				if r < 0.3:
					c = Color(0.52, 0.11, 0.08)
				elif r < 0.7:
					c = Color(0.58, 0.14, 0.09)
				else:
					c = Color(0.64, 0.16, 0.11)
			_px(img, t, x, y, c)

	# Draw a crude "TNT" in the label band by darkening letter-like pixels
	var letter_px: Array = [
		# T (x 2-4)
		Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(3, 8),
		# N (x 6-8)
		Vector2i(6, 7), Vector2i(6, 8), Vector2i(7, 7), Vector2i(8, 7), Vector2i(8, 8),
		# T (x 10-12)
		Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(11, 8),
	]
	for p: Vector2i in letter_px:
		_px(img, t, p.x, p.y, Color(0.10, 0.10, 0.10))


static func _draw_tnt_bottom(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.30:
				c = Color(0.50, 0.11, 0.08)
			elif r < 0.70:
				c = Color(0.56, 0.14, 0.09)
			else:
				c = Color(0.62, 0.16, 0.11)
			_px(img, t, x, y, c)


static func _draw_iron_block(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Bright polished-silver base so iron reads clearly as metal, clearly
	# distinct from smooth stone. Anisotropic brushed-metal look: horizontal
	# bands of slightly different brightness with sparse sharp highlights.
	for y: int in TILE_SIZE:
		var band: float = 0.86 + sin(float(y) * 0.9) * 0.04
		for x: int in TILE_SIZE:
			var v: float = clampf(band + (rng.randf() - 0.5) * 0.04, 0.0, 1.0)
			_px(img, t, x, y, Color(v, v, v * 0.995))
	# Sharp bright specular flecks (shine).
	for _i: int in 6:
		var sx: int = rng.randi_range(2, TILE_SIZE - 3)
		var sy: int = rng.randi_range(1, TILE_SIZE - 2)
		_px(img, t, sx, sy, Color(1.0, 1.0, 1.0))
		_px(img, t, sx + 1, sy, Color(0.96, 0.96, 0.97))
	# Dark bevel border for a pressed-metal edge.
	for i: int in TILE_SIZE:
		if i == 0 or i == TILE_SIZE - 1:
			for j: int in TILE_SIZE:
				_px(img, t, i, j, Color(0.48, 0.48, 0.50))
				_px(img, t, j, i, Color(0.48, 0.48, 0.50))
	# Inner-top highlight line (1px below top border) for a 3D bevel look.
	for x: int in range(1, TILE_SIZE - 1):
		_px(img, t, x, 1, Color(0.98, 0.98, 0.99))


static func _draw_gold_block(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Polished gold-ingot style: matches iron_block's bevel language so the
	# two read as a family. Horizontal bands for brushed-metal grain, a dark
	# chamfer border, a single-pixel highlight line along the top-inner edge,
	# and a few mirror-bright specular flecks to sell "shiny".
	for y: int in TILE_SIZE:
		# Horizontal brightness banding gives the impression of a polished
		# ingot's anisotropic reflection — each row averages slightly
		# different so light appears to sweep across the block.
		var band: float = 0.86 + sin(float(y) * 0.8) * 0.05
		for x: int in TILE_SIZE:
			var v: float = clampf(band + (rng.randf() - 0.5) * 0.035, 0.0, 1.0)
			# Warm yellow tone. Green channel is deliberately kept ~0.78× of
			# red so the metal reads as yellow-gold, not lemon.
			_px(img, t, x, y, Color(v, v * 0.80, v * 0.16))
	# Sharp bright specular flecks — two-pixel glints scattered sparsely so
	# the surface reads as reflective without getting busy.
	for _i: int in 5:
		var sx: int = rng.randi_range(2, TILE_SIZE - 3)
		var sy: int = rng.randi_range(2, TILE_SIZE - 3)
		_px(img, t, sx, sy, Color(1.00, 0.94, 0.52))
		_px(img, t, sx + 1, sy, Color(0.96, 0.88, 0.42))
	# Dark chamfer border — the "cast ingot" edge.
	var edge := Color(0.44, 0.32, 0.06)
	for i: int in TILE_SIZE:
		_px(img, t, i, 0, edge); _px(img, t, i, TILE_SIZE - 1, edge)
		_px(img, t, 0, i, edge); _px(img, t, TILE_SIZE - 1, i, edge)
	# Inner-top highlight line (1px below top border) for a 3D bevel, so the
	# gold visibly catches light on one edge instead of reading as flat.
	for x: int in range(1, TILE_SIZE - 1):
		_px(img, t, x, 1, Color(1.00, 0.92, 0.48))
	# Inner-left highlight, slightly dimmer (side lighting).
	for y: int in range(2, TILE_SIZE - 1):
		_px(img, t, 1, y, Color(0.95, 0.80, 0.30))


## Diamond block — polished cyan gem block, same bevel language as iron
## and gold so the three read as a family. Faceted look: base is pale cyan
## with blue-shadowed diagonal hatching (simulating cut facets), bright
## white specular pinpoints, and a dark navy chamfer border.
static func _draw_diamond_block(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		# Subtle horizontal banding similar to iron/gold so the surface
		# doesn't read as a flat color.
		var band: float = 0.82 + sin(float(y) * 0.75) * 0.05
		for x: int in TILE_SIZE:
			# Diagonal facet hatching: every few steps along (x+y) gets a
			# slightly darker shade, mimicking the way a cut gemstone
			# produces alternating bright/dark bands as light hits facets.
			var facet_phase: float = float((x + y) % 4)
			var facet_mod: float = -0.06 if facet_phase < 1.0 else (0.04 if facet_phase < 2.0 else 0.0)
			var v: float = clampf(band + facet_mod + (rng.randf() - 0.5) * 0.025, 0.0, 1.0)
			# Cyan-leaning palette — high green/blue, low red so the block
			# reads as diamond rather than ice (which would be pure white).
			_px(img, t, x, y, Color(v * 0.42, v * 0.92, v * 0.98))
	# Bright white specular pinpoints — the "star sparkle" on the gem.
	for _i: int in 6:
		var sx: int = rng.randi_range(2, TILE_SIZE - 3)
		var sy: int = rng.randi_range(2, TILE_SIZE - 3)
		_px(img, t, sx, sy, Color(1.00, 1.00, 1.00))
		if rng.randf() < 0.5:
			_px(img, t, sx + 1, sy, Color(0.88, 0.98, 1.00))
		else:
			_px(img, t, sx, sy + 1, Color(0.88, 0.98, 1.00))
	# Dark chamfer border — matches iron/gold for family consistency but
	# uses a navy cast instead of brown.
	var edge := Color(0.10, 0.34, 0.44)
	for i: int in TILE_SIZE:
		_px(img, t, i, 0, edge); _px(img, t, i, TILE_SIZE - 1, edge)
		_px(img, t, 0, i, edge); _px(img, t, TILE_SIZE - 1, i, edge)
	# Inner bevel highlights (top + left) for the 3D pressed-gem look.
	for x: int in range(1, TILE_SIZE - 1):
		_px(img, t, x, 1, Color(0.80, 0.98, 1.00))
	for y: int in range(2, TILE_SIZE - 1):
		_px(img, t, 1, y, Color(0.62, 0.94, 1.00))


static func _draw_ore(
	img: Image, rng: RandomNumberGenerator, t: int, ore_color: Color,
	min_size: int = 2, max_size: int = 7,
) -> void:
	# Multiple ore deposits per tile with size variation — 3-5 separate
	# clusters distributed across the tile with a minimum separation so
	# they don't merge into one blob. Each cluster has its own highlight +
	# body + shadow so it reads as a rounded nugget rather than a flat
	# color stamp. Size range is tunable per ore: coal uses bigger chunks
	# than iron/gold because coal deposits are typically larger lumps.
	_draw_stone(img, rng, t)
	var ore_dk: Color = Color(ore_color.r * 0.60, ore_color.g * 0.60, ore_color.b * 0.60)
	var ore_hi: Color = Color(
		clampf(ore_color.r * 1.25 + 0.08, 0.0, 1.0),
		clampf(ore_color.g * 1.25 + 0.08, 0.0, 1.0),
		clampf(ore_color.b * 1.25 + 0.08, 0.0, 1.0),
	)
	_stamp_ore_deposits(img, rng, t, ore_color, ore_hi, ore_dk, min_size, max_size)


## Shared helper: place 3-5 ore deposits across the current tile with
## varying sizes. Each deposit grows via a random walk from its seed cell,
## staying compact (4-connected neighbor picks) so clusters don't string
## out into lines. Deposits are required to start at least `MIN_SEP`
## pixels apart so the tile reads as "a few nuggets" rather than one blob.
static func _stamp_ore_deposits(
	img: Image, rng: RandomNumberGenerator, t: int,
	body: Color, hi: Color, shadow: Color,
	min_size: int = 2, max_size: int = 7,
) -> void:
	const MIN_SEP: int = 4                # min Chebyshev distance between deposit centers
	const MAX_ATTEMPTS: int = 40
	var deposit_count: int = rng.randi_range(3, 5)
	var centers: Array[Vector2i] = []
	var attempts: int = 0
	while centers.size() < deposit_count and attempts < MAX_ATTEMPTS:
		attempts += 1
		var cx: int = rng.randi_range(2, TILE_SIZE - 3)
		var cy: int = rng.randi_range(2, TILE_SIZE - 3)
		var too_close: bool = false
		for e: Vector2i in centers:
			if absi(e.x - cx) < MIN_SEP and absi(e.y - cy) < MIN_SEP:
				too_close = true
				break
		if not too_close:
			centers.append(Vector2i(cx, cy))

	var occupied: Dictionary = {}
	for center: Vector2i in centers:
		var target_size: int = rng.randi_range(min_size, max_size)
		# Grow the cluster cell-by-cell via 4-neighbor random walk seeded
		# from the center, preferring compact growth by picking a random
		# existing cell and extending outward.
		var cells: Array[Vector2i] = [center]
		occupied[center] = true
		var grow_attempts: int = 0
		while cells.size() < target_size and grow_attempts < target_size * 4:
			grow_attempts += 1
			var seed_cell: Vector2i = cells[rng.randi() % cells.size()]
			var offsets: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var off: Vector2i = offsets[rng.randi() % 4]
			var nc: Vector2i = seed_cell + off
			if nc.x < 0 or nc.x >= TILE_SIZE or nc.y < 0 or nc.y >= TILE_SIZE:
				continue
			if occupied.has(nc):
				continue
			cells.append(nc)
			occupied[nc] = true
		# Identify highlight (top-left-most) and shadow (bottom-right-most)
		# cells by their x+y sum — gives each nugget a consistent lit side.
		var hi_idx: int = 0
		var sh_idx: int = 0
		var hi_score: int = 999
		var sh_score: int = -1
		for i: int in cells.size():
			var s: int = cells[i].x + cells[i].y
			if s < hi_score:
				hi_score = s
				hi_idx = i
			if s > sh_score:
				sh_score = s
				sh_idx = i
		# Draw.
		for i: int in cells.size():
			var c: Vector2i = cells[i]
			var color: Color
			# Only apply hi/shadow on deposits of 3+ cells so 2-pixel nuggets
			# stay solid-colored (too small to have a lit side).
			if cells.size() >= 3 and i == hi_idx:
				color = hi
			elif cells.size() >= 3 and i == sh_idx:
				color = shadow
			else:
				var n: float = (rng.randf() - 0.5) * 0.14
				color = Color(
					clampf(body.r + n, 0.0, 1.0),
					clampf(body.g + n, 0.0, 1.0),
					clampf(body.b + n, 0.0, 1.0),
				)
			_px(img, t, c.x, c.y, color)


## Diamond ore — scattered splotches rather than the clumped blobs _draw_ore
## produces. Each splotch is a 1–2 pixel gem with an optional bright highlight
## pixel, so the overall tile reads like Minecraft's diamond ore: many small
## sparkles rather than a few big patches.
static func _draw_diamond_ore(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_stone(img, rng, t)
	const BODY := Color(0.38, 0.88, 0.92)   # main diamond cyan
	const DARK := Color(0.22, 0.62, 0.68)   # shadowed facet
	const HILITE := Color(0.78, 0.98, 1.00) # bright sparkle highlight
	# Track occupied pixels to keep splotches spread out — Minecraft diamond
	# ore reads as many independent gems, not overlapping blobs.
	var occupied: Dictionary = {}
	# Space probing: 12-16 sparkles scattered across the tile.
	var target: int = rng.randi_range(12, 16)
	var placed: int = 0
	var attempts: int = 0
	while placed < target and attempts < 200:
		attempts += 1
		var cx: int = rng.randi_range(0, TILE_SIZE - 1)
		var cy: int = rng.randi_range(0, TILE_SIZE - 1)
		# Reject if too close to an existing splotch (Chebyshev distance < 2).
		var too_close: bool = false
		for key: Vector2i in occupied.keys():
			if absi(key.x - cx) < 2 and absi(key.y - cy) < 2:
				too_close = true
				break
		if too_close:
			continue
		# Core gem pixel.
		_px(img, t, cx, cy, BODY)
		occupied[Vector2i(cx, cy)] = true
		# Most splotches get a second body pixel so they read as a small gem,
		# oriented randomly (horizontal / vertical / diagonal nub).
		var shape: int = rng.randi_range(0, 3)
		var nub: Vector2i
		match shape:
			0: nub = Vector2i(1, 0)
			1: nub = Vector2i(0, 1)
			2: nub = Vector2i(-1, 0)
			_: nub = Vector2i(0, -1)
		if rng.randf() < 0.7:
			var nx: int = cx + nub.x
			var ny: int = cy + nub.y
			if nx >= 0 and nx < TILE_SIZE and ny >= 0 and ny < TILE_SIZE:
				# Use the darker facet here so the gem reads as a tiny rounded
				# cluster rather than a flat blob.
				_px(img, t, nx, ny, DARK)
				occupied[Vector2i(nx, ny)] = true
		# ~35% of gems get a single bright highlight pixel diagonally offset —
		# the "sparkle" that sells the gemstone look.
		if rng.randf() < 0.35:
			var hx: int = cx + (1 if rng.randf() < 0.5 else -1)
			var hy: int = cy + (1 if rng.randf() < 0.5 else -1)
			if hx >= 0 and hx < TILE_SIZE and hy >= 0 and hy < TILE_SIZE \
					and not occupied.has(Vector2i(hx, hy)):
				_px(img, t, hx, hy, HILITE)
				occupied[Vector2i(hx, hy)] = true
		placed += 1


static func _draw_wool(img: Image, rng: RandomNumberGenerator, t: int, base_col: Color) -> void:
	# Soft felted-wool look — flat blocks of color with subtle horizontal
	# fiber streaks. Much less jittery than per-pixel noise, so adjacent
	# wool blocks tile without looking like TV static. Approach:
	#   1. Fill the tile with the base color + a tiny uniform jitter range.
	#   2. Overlay occasional 2-3 pixel horizontal "fiber" streaks at
	#      slightly lighter and darker shades, creating the impression of
	#      spun threads running across the tile.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			# Tight range: ±3% lightness. Keeps each color block uniform
			# instead of powdery.
			var n: float = (rng.randf() - 0.5) * 0.06
			_px(img, t, x, y, Color(
				clampf(base_col.r + n, 0.0, 1.0),
				clampf(base_col.g + n, 0.0, 1.0),
				clampf(base_col.b + n, 0.0, 1.0),
			))
	# Horizontal fiber streaks — short 2-3 pixel runs at 2-4 distinct rows.
	# They represent the weave direction and give the wool shape without
	# making it look like sand.
	var streak_rows: Array[int] = []
	var rows_needed: int = 3 + (rng.randi() % 2)
	for _i: int in rows_needed:
		streak_rows.append(rng.randi_range(1, TILE_SIZE - 2))
	for ry: int in streak_rows:
		# Run 2-3 pixel streaks every few columns across this row.
		var x: int = rng.randi_range(0, 3)
		while x < TILE_SIZE:
			var run_len: int = rng.randi_range(2, 3)
			# Pick lighter or darker for this streak.
			var direction: float = 1.08 if rng.randf() < 0.5 else 0.92
			for dx: int in run_len:
				var xi: int = x + dx
				if xi >= 0 and xi < TILE_SIZE:
					_px(img, t, xi, ry, Color(
						clampf(base_col.r * direction, 0.0, 1.0),
						clampf(base_col.g * direction, 0.0, 1.0),
						clampf(base_col.b * direction, 0.0, 1.0),
					))
			x += run_len + rng.randi_range(1, 3)
	# A couple of scattered "thread knot" pixels — a single lighter or
	# darker pixel here and there — break up any remaining flatness without
	# introducing speckle.
	for _i: int in 4:
		var kx: int = rng.randi_range(0, TILE_SIZE - 1)
		var ky: int = rng.randi_range(0, TILE_SIZE - 1)
		var dir: float = 1.12 if rng.randf() < 0.5 else 0.86
		_px(img, t, kx, ky, Color(
			clampf(base_col.r * dir, 0.0, 1.0),
			clampf(base_col.g * dir, 0.0, 1.0),
			clampf(base_col.b * dir, 0.0, 1.0),
		))


static func _draw_fire(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Flame sprite drawn on two crossed quads inside the voxel cell. Tile is
	# filled with a rising flame silhouette — transparent outside, alpha-cut
	# handles the edges. Shape: a wide base that narrows upward, with a
	# brighter inner column, slight jitter for organic feel.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))
	# Flame body. y=TILE_SIZE-1 is the bottom (wide), y=0 is the top (narrow).
	var cx: float = float(TILE_SIZE) / 2.0
	for y: int in TILE_SIZE:
		var frac_up: float = 1.0 - float(y) / float(TILE_SIZE - 1)  # 0 bottom → 1 top
		# Width of the flame at this row — wider at the bottom, narrows up.
		var half_w: float = lerpf(6.0, 0.8, frac_up) + (rng.randf() - 0.5) * 1.2
		var x_lo: int = int(floor(cx - half_w))
		var x_hi: int = int(ceil(cx + half_w))
		for x: int in range(maxi(0, x_lo), mini(TILE_SIZE, x_hi + 1)):
			var dist: float = abs(float(x) - cx) / max(half_w, 0.01)
			# Colour: hottest (white-ish) near top + center, deep red at edges / base.
			var r: float = 0.95
			var g: float = lerpf(0.20, 0.90, 1.0 - dist * 0.7) * lerpf(0.55, 1.0, frac_up)
			var b: float = lerpf(0.06, 0.40, 1.0 - dist * 0.9) * frac_up
			_px(img, t, x, y, Color(r, clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), 1.0))
	# Bright inner core.
	for y: int in range(2, TILE_SIZE - 1):
		var frac_up: float = 1.0 - float(y) / float(TILE_SIZE - 1)
		if rng.randf() > 0.65 * frac_up + 0.15:
			continue
		var xi: int = int(cx + (rng.randf() - 0.5) * 2.0)
		if xi >= 0 and xi < TILE_SIZE:
			_px(img, t, xi, y, Color(1.0, 0.92, lerpf(0.2, 0.7, frac_up), 1.0))


static func _draw_poppy(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Minecraft-style poppy: a centered stem with two leaves, topped with a
	# four-petal bloom that has clearly separated red petals arranged around
	# a dark center. The separations are drawn as transparent gaps so each
	# petal reads as an individual lobe instead of a single red blob.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))

	# Stem — tight 1-pixel-wide line with a darker outline on the right so
	# the stem has form (not a flat block of green).
	var stem := Color(0.22, 0.52, 0.16, 1.0)
	var stem_sh := Color(0.12, 0.34, 0.10, 1.0)
	for y: int in range(6, 14):
		_px(img, t, 7, y, stem)
		_px(img, t, 8, y, stem_sh)

	# Leaves — angled tear-drop shapes on each side of the stem.
	var leaf := Color(0.26, 0.58, 0.18, 1.0)
	var leaf_sh := Color(0.14, 0.38, 0.10, 1.0)
	# Left leaf
	_px(img, t, 5, 10, leaf); _px(img, t, 6, 10, leaf)
	_px(img, t, 5, 11, leaf_sh)
	# Right leaf
	_px(img, t, 9, 8, leaf); _px(img, t, 10, 8, leaf)
	_px(img, t, 10, 9, leaf_sh)

	# Petal palette — four distinct reds for a painterly, multi-tone bloom.
	var petal_dk := Color(0.48, 0.05, 0.05, 1.0)   # shadow edge
	var petal := Color(0.78, 0.12, 0.12, 1.0)      # main red
	var petal_hi := Color(0.95, 0.30, 0.22, 1.0)   # highlight
	var petal_hot := Color(1.00, 0.52, 0.38, 1.0)  # specular hot-spot
	var center := Color(0.20, 0.06, 0.04, 1.0)     # dark center pip
	var center_hi := Color(0.58, 0.32, 0.06, 1.0)  # pollen fleck

	# Bloom — a 6×5 cluster centered around (7-8, 3). Lay it out as explicit
	# pixel rows so the petal separations (tiny transparent gaps between
	# lobes) read clearly at 16px.
	#  y=1 .##.##.        top petals
	#  y=2 #H##H##        upper row, highlights
	#  y=3 ###C###        mid row, dark center
	#  y=4 #H###H#        lower row, highlights
	#  y=5 .##.##.        bottom petals

	# Top petals (y=1)
	_px(img, t, 6, 1, petal); _px(img, t, 7, 1, petal_hi)
	_px(img, t, 8, 1, petal_hi); _px(img, t, 9, 1, petal)
	# Upper row (y=2) — widest
	_px(img, t, 5, 2, petal_dk); _px(img, t, 6, 2, petal_hot); _px(img, t, 7, 2, petal_hi)
	_px(img, t, 8, 2, petal_hi); _px(img, t, 9, 2, petal_hot); _px(img, t, 10, 2, petal_dk)
	# Middle row with center pip (y=3)
	_px(img, t, 5, 3, petal); _px(img, t, 6, 3, petal); _px(img, t, 7, 3, center)
	_px(img, t, 8, 3, center_hi); _px(img, t, 9, 3, petal); _px(img, t, 10, 3, petal)
	# Lower row (y=4)
	_px(img, t, 5, 4, petal_dk); _px(img, t, 6, 4, petal_hi); _px(img, t, 7, 4, petal)
	_px(img, t, 8, 4, petal); _px(img, t, 9, 4, petal_hi); _px(img, t, 10, 4, petal_dk)
	# Bottom petals (y=5) — narrowest, meets stem
	_px(img, t, 6, 5, petal); _px(img, t, 7, 5, petal_dk)
	_px(img, t, 8, 5, petal_dk); _px(img, t, 9, 5, petal)


static func _draw_dandelion(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Minecraft-style dandelion: same stem/leaf footprint as the poppy for
	# visual consistency, topped with a puffy yellow bloom drawn as a
	# rounded cluster of small pixel-petals rather than a flat disc. The
	# cluster shows three distinct yellows (shadow / body / highlight) plus
	# an amber pistil pip so the flower reads as an individual bloom rather
	# than a yellow blur.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))

	# Stem + leaves (match poppy, slightly brighter stem for species variety).
	var stem := Color(0.24, 0.56, 0.18, 1.0)
	var stem_sh := Color(0.14, 0.38, 0.12, 1.0)
	for y: int in range(6, 14):
		_px(img, t, 7, y, stem)
		_px(img, t, 8, y, stem_sh)
	var leaf := Color(0.28, 0.60, 0.20, 1.0)
	var leaf_sh := Color(0.16, 0.42, 0.12, 1.0)
	_px(img, t, 5, 10, leaf); _px(img, t, 6, 10, leaf)
	_px(img, t, 5, 11, leaf_sh)
	_px(img, t, 9, 8, leaf); _px(img, t, 10, 8, leaf)
	_px(img, t, 10, 9, leaf_sh)

	# Bloom palette.
	var y_sh := Color(0.62, 0.45, 0.06, 1.0)     # shadowed petal
	var y_body := Color(0.95, 0.78, 0.12, 1.0)   # main body
	var y_hi := Color(1.00, 0.92, 0.34, 1.0)     # highlight
	var pip := Color(0.80, 0.46, 0.08, 1.0)      # amber center

	# Hand-placed petal cluster — a 6×5 rounded shape with ragged edges
	# that suggests individual petals poking out.
	#  y=1    .HH.HH
	#  y=2   .BBBBBB.
	#  y=3   BBBPBBB.       (P = pip)
	#  y=4    BBSBSB
	#  y=5    .SS.S.
	_px(img, t, 6, 1, y_hi); _px(img, t, 7, 1, y_hi)
	_px(img, t, 9, 1, y_hi); _px(img, t, 10, 1, y_hi)

	_px(img, t, 5, 2, y_body); _px(img, t, 6, 2, y_hi); _px(img, t, 7, 2, y_hi)
	_px(img, t, 8, 2, y_body); _px(img, t, 9, 2, y_hi); _px(img, t, 10, 2, y_body)

	_px(img, t, 4, 3, y_body); _px(img, t, 5, 3, y_body); _px(img, t, 6, 3, y_body)
	_px(img, t, 7, 3, pip); _px(img, t, 8, 3, y_body); _px(img, t, 9, 3, y_body)
	_px(img, t, 10, 3, y_body); _px(img, t, 11, 3, y_body)

	_px(img, t, 5, 4, y_body); _px(img, t, 6, 4, y_body); _px(img, t, 7, 4, y_sh)
	_px(img, t, 8, 4, y_body); _px(img, t, 9, 4, y_sh); _px(img, t, 10, 4, y_body)

	_px(img, t, 6, 5, y_sh); _px(img, t, 7, 5, y_sh)
	_px(img, t, 9, 5, y_sh)


## Torch — brown stick on the bottom half with an orange flame on top.
## Rendered as a crossed-quad plant in-world (like fire/flowers).
static func _draw_torch(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))
	# Stick (2px wide, brown)
	var stick := Color(0.45, 0.30, 0.15, 1.0)
	var stick_dk := Color(0.35, 0.22, 0.10, 1.0)
	for y: int in range(6, 15):
		_px(img, t, 7, y, stick)
		_px(img, t, 8, y, stick_dk)
	# Base nub
	_px(img, t, 6, 14, stick_dk)
	_px(img, t, 9, 14, stick_dk)
	# Flame — bright orange/yellow, 4px wide, top portion
	var flame_core := Color(1.0, 0.90, 0.30, 1.0)
	var flame_mid := Color(1.0, 0.60, 0.10, 1.0)
	var flame_outer := Color(0.90, 0.35, 0.05, 1.0)
	# Core
	_px(img, t, 7, 4, flame_core); _px(img, t, 8, 4, flame_core)
	_px(img, t, 7, 5, flame_core); _px(img, t, 8, 5, flame_core)
	# Mid
	_px(img, t, 6, 4, flame_mid); _px(img, t, 9, 4, flame_mid)
	_px(img, t, 6, 5, flame_mid); _px(img, t, 9, 5, flame_mid)
	_px(img, t, 7, 3, flame_mid); _px(img, t, 8, 3, flame_mid)
	_px(img, t, 7, 6, flame_mid); _px(img, t, 8, 6, flame_mid)
	# Outer glow
	_px(img, t, 7, 2, flame_outer); _px(img, t, 8, 2, flame_outer)
	_px(img, t, 6, 3, flame_outer); _px(img, t, 9, 3, flame_outer)
	_px(img, t, 5, 5, flame_outer); _px(img, t, 10, 5, flame_outer)
	# Tip
	_px(img, t, 7, 1, Color(1.0, 0.75, 0.20, 0.8))


## Shared helper: draw a small mushroom shape (cap + stem) with a given
## cap/spot/stem palette. Shape is a classic 16×16 pixel-art mushroom that
## matches the density of the flower sprites — cap is wider than the stem
## with a rounded dome, white spots on the cap for red/brown, none for fungi.
static func _draw_mushroom_shape(img: Image, t: int, cap: Color, cap_hl: Color, cap_sh: Color, stem: Color, stem_sh: Color, spots: Color) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))
	# Stem — short & stubby, 2px wide, center.
	for y: int in range(8, 14):
		_px(img, t, 7, y, stem)
		_px(img, t, 8, y, stem_sh)
	# Stem base shadow
	_px(img, t, 6, 13, stem_sh)
	_px(img, t, 9, 13, stem_sh)
	# Cap — dome from y=3..7, widest at y=6.
	var cap_rows: Array = [
		[Vector2i(7, 3), Vector2i(8, 3)],
		[Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4)],
		[Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5)],
		[Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6)],
		[Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7)],
	]
	for row: Array in cap_rows:
		for p: Vector2i in row:
			_px(img, t, p.x, p.y, cap)
	# Cap underside shadow (rim)
	_px(img, t, 5, 7, cap_sh); _px(img, t, 10, 7, cap_sh)
	_px(img, t, 6, 7, cap_sh); _px(img, t, 9, 7, cap_sh)
	# Cap highlight — a 2×2 block top-left of center
	_px(img, t, 6, 4, cap_hl)
	_px(img, t, 5, 5, cap_hl)
	_px(img, t, 6, 5, cap_hl)
	# Spots — only drawn if the spot color has non-zero alpha
	if spots.a > 0.0:
		_px(img, t, 8, 4, spots)
		_px(img, t, 4, 6, spots)
		_px(img, t, 9, 6, spots)
		_px(img, t, 7, 6, spots)


## Red mushroom — classic Minecraft mushroom: bright red cap with white
## spots, pale stem. Spawns rarely on netherrack outside the forest biomes.
static func _draw_red_mushroom(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_mushroom_shape(
		img, t,
		Color(0.82, 0.12, 0.12, 1.0),   # cap base
		Color(0.98, 0.38, 0.30, 1.0),   # cap highlight
		Color(0.55, 0.06, 0.06, 1.0),   # cap rim shadow
		Color(0.94, 0.88, 0.78, 1.0),   # stem
		Color(0.72, 0.62, 0.48, 1.0),   # stem shadow
		Color(1.00, 0.98, 0.92, 1.0),   # white spots
	)


## Brown mushroom — earthy brown cap, no spots (matches Minecraft).
static func _draw_brown_mushroom(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_mushroom_shape(
		img, t,
		Color(0.50, 0.32, 0.18, 1.0),   # cap base
		Color(0.72, 0.52, 0.32, 1.0),   # cap highlight
		Color(0.32, 0.20, 0.10, 1.0),   # cap rim shadow
		Color(0.90, 0.82, 0.70, 1.0),   # stem
		Color(0.65, 0.56, 0.42, 1.0),   # stem shadow
		Color(0, 0, 0, 0),              # no spots
	)


## Crimson fungus — red-magenta fungus with a warm dark stem, matches the
## crimson forest palette. Small pinkish highlights stand in for the spots.
static func _draw_crimson_fungus(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_mushroom_shape(
		img, t,
		Color(0.72, 0.10, 0.18, 1.0),   # cap base — deep crimson
		Color(0.95, 0.28, 0.32, 1.0),   # cap highlight
		Color(0.40, 0.04, 0.10, 1.0),   # cap rim shadow
		Color(0.56, 0.22, 0.28, 1.0),   # stem — crimson-brown
		Color(0.35, 0.10, 0.16, 1.0),   # stem shadow
		Color(0, 0, 0, 0),              # no white spots — fungus, not mushroom
	)


## Warped fungus — teal/cyan fungus matching the warped forest palette.
static func _draw_warped_fungus(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_mushroom_shape(
		img, t,
		Color(0.22, 0.58, 0.55, 1.0),   # cap base — warped teal
		Color(0.48, 0.82, 0.75, 1.0),   # cap highlight
		Color(0.08, 0.32, 0.32, 1.0),   # cap rim shadow
		Color(0.20, 0.45, 0.45, 1.0),   # stem — darker teal
		Color(0.08, 0.28, 0.30, 1.0),   # stem shadow
		Color(0, 0, 0, 0),              # no white spots
	)


## Netherrack — dark red-brown rocky texture with cracks and variation,
## resembling the hell-stone from Minecraft. Noisy with darker veins.
static func _draw_netherrack(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var shade: float
			if r < 0.12:
				shade = 0.70  # dark crack
			elif r < 0.35:
				shade = 0.82
			elif r < 0.70:
				shade = 0.90
			else:
				shade = 1.0
			# Base color: dark maroon-red
			var c := Color(0.52 * shade, 0.20 * shade, 0.18 * shade)
			_px(img, t, x, y, c)
	# Dark vein streaks running horizontally
	for y: int in [3, 7, 11]:
		for x: int in TILE_SIZE:
			if rng.randf() < 0.6:
				_px(img, t, x, y, Color(0.30, 0.10, 0.09))


## Nether gold ore — netherrack base with 3-5 variable-sized gold deposits
## using the same multi-deposit stamp as overworld ores, so the two read
## as one family differing only in base rock + palette. Brighter / more
## orange gold than the overworld variant so it punches through the red
## netherrack base.
static func _draw_nether_gold_ore(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_netherrack(img, rng, t)
	var gold := Color(0.98, 0.78, 0.22)
	var gold_hi := Color(1.00, 0.95, 0.48)
	var gold_dk := Color(0.65, 0.45, 0.08)
	_stamp_ore_deposits(img, rng, t, gold, gold_hi, gold_dk)


## Nether quartz ore — netherrack base with multiple discrete long chunks
## of pale quartz crystal scattered across the tile. Each chunk is a
## thick rectangular shard with a highlight line, oriented randomly
## (horizontal / vertical / diagonal) and well-separated from neighbors.
static func _draw_nether_quartz_ore(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_netherrack(img, rng, t)
	var quartz := Color(0.92, 0.88, 0.82)
	var quartz_hi := Color(1.00, 0.97, 0.90)
	var quartz_dk := Color(0.70, 0.65, 0.58)
	# Track occupied pixels so shards don't overlap — keeps them as discrete
	# chunks rather than one blob.
	var occupied: Dictionary = {}
	var target: int = rng.randi_range(4, 6)
	var placed: int = 0
	var attempts: int = 0
	while placed < target and attempts < 40:
		attempts += 1
		# Choose orientation: 0 = horizontal, 1 = vertical, 2 = diag ↘, 3 = diag ↙
		var orient: int = rng.randi_range(0, 3)
		var length: int = rng.randi_range(4, 6)
		var thickness: int = rng.randi_range(1, 2)
		# Random start that fits the shape.
		var sx: int = rng.randi_range(1, TILE_SIZE - 2)
		var sy: int = rng.randi_range(1, TILE_SIZE - 2)
		# Collect target pixels for this shard.
		var pixels: Array[Vector2i] = []
		for i: int in length:
			for th: int in thickness:
				var px: int; var py: int
				match orient:
					0:
						px = sx + i; py = sy + th
					1:
						px = sx + th; py = sy + i
					2:
						px = sx + i; py = sy + i + th
					_:
						px = sx + i; py = sy - i + th
				if px < 0 or px >= TILE_SIZE or py < 0 or py >= TILE_SIZE:
					pixels.clear()
					break
				pixels.append(Vector2i(px, py))
			if pixels.is_empty():
				break
		if pixels.is_empty():
			continue
		# Reject if any target pixel is within 1 of an existing shard —
		# guarantees visual separation between chunks.
		var conflict: bool = false
		for p: Vector2i in pixels:
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					if occupied.has(Vector2i(p.x + dx, p.y + dy)):
						conflict = true
						break
				if conflict: break
			if conflict: break
		if conflict:
			continue
		# Paint the shard with a bright highlight pixel on the first block.
		for i: int in pixels.size():
			var p: Vector2i = pixels[i]
			occupied[p] = true
			var c: Color
			if i == 0:
				c = quartz_hi  # tip highlight
			elif i == pixels.size() - 1:
				c = quartz_dk  # darker tail
			else:
				c = quartz
			_px(img, t, p.x, p.y, c)
		placed += 1


## Nether portal — translucent purple swirl texture. Alpha < 1 so it reads
## as a glowing membrane you can walk through.
static func _draw_nether_portal(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var purple: Color
			if r < 0.25:
				purple = Color(0.35, 0.10, 0.65, 0.75)
			elif r < 0.55:
				purple = Color(0.50, 0.15, 0.80, 0.80)
			elif r < 0.80:
				purple = Color(0.60, 0.25, 0.90, 0.85)
			else:
				purple = Color(0.75, 0.40, 1.00, 0.90)  # bright sparkle
			_px(img, t, x, y, purple)


## Crimson nylium top — deep red fungus crust over dark netherrack. Bright
## red fungal spots scattered on a dark red-brown base.
static func _draw_crimson_nylium_top(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.15:
				c = Color(0.25, 0.06, 0.06)  # dark crack
			elif r < 0.55:
				c = Color(0.52, 0.10, 0.10)  # base crimson
			elif r < 0.85:
				c = Color(0.65, 0.14, 0.14)  # mid
			else:
				c = Color(0.80, 0.22, 0.15)  # bright spore
			_px(img, t, x, y, c)


## Warped nylium top — blue/cyan fungus crust over dark netherrack.
static func _draw_warped_nylium_top(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.15:
				c = Color(0.05, 0.18, 0.20)  # dark crack
			elif r < 0.55:
				c = Color(0.12, 0.40, 0.40)  # base warped teal
			elif r < 0.85:
				c = Color(0.18, 0.55, 0.52)  # mid
			else:
				c = Color(0.30, 0.72, 0.62)  # bright spore
			_px(img, t, x, y, c)


## Nylium side — top half is the colored fungus fade, bottom half is
## netherrack so the transition reads naturally at the grass-like edge.
static func _draw_nylium_side(img: Image, rng: RandomNumberGenerator, t: int, fungus: Color) -> void:
	_draw_netherrack(img, rng, t)
	# Top 5 pixels get the fungus color overlay with a jagged bottom edge.
	for x: int in TILE_SIZE:
		var edge: int = rng.randi_range(2, 5)  # how far down the fungus bleeds
		for y: int in edge:
			var r: float = rng.randf()
			var shade: float = 0.85 + r * 0.3
			var c := Color(fungus.r * shade, fungus.g * shade, fungus.b * shade)
			if r < 0.2:
				c = c.darkened(0.3)
			_px(img, t, x, y, c)


## Generic stem side bark — vertical ridges + noise for organic fungal feel.
## `base` is the main color, `dark` the crevice color.
static func _draw_stem_side(img: Image, rng: RandomNumberGenerator, t: int, base: Color, dark: Color) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			# Vertical ridges every 3-4 pixels.
			var ridge: bool = (x % 4) == 0 or (x % 4) == 3
			var c: Color
			if ridge:
				c = dark if rng.randf() < 0.6 else base
			else:
				var r: float = rng.randf()
				if r < 0.25:
					c = dark
				elif r < 0.85:
					c = base
				else:
					c = Color(base.r * 1.2, base.g * 1.2, base.b * 1.2)
			_px(img, t, x, y, c)


## Stem top cross-section — concentric rings of the stem colors.
static func _draw_stem_top(img: Image, rng: RandomNumberGenerator, t: int, base: Color, dark: Color) -> void:
	var cx: float = 7.5
	var cy: float = 7.5
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var d: float = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
			var ring: int = int(d) % 3
			var c: Color
			if ring == 0:
				c = base
			elif ring == 1:
				c = Color(base.r * 0.85, base.g * 0.85, base.b * 0.85)
			else:
				c = dark
			# Sprinkle noise
			if rng.randf() < 0.15:
				c = c.darkened(0.15)
			_px(img, t, x, y, c)


## Wart block — large organic fungal blocks. Mottled pattern with a bright
## spore layer on top and darker depths, plus occasional bright sparkles.
static func _draw_wart_block(img: Image, rng: RandomNumberGenerator, t: int, base: Color, dark: Color, bright: Color) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.10:
				c = bright  # sparkle
			elif r < 0.35:
				c = Color(base.r * 1.1, base.g * 1.1, base.b * 1.1).clamp(Color(0,0,0), Color(1,1,1))
			elif r < 0.75:
				c = base
			else:
				c = dark
			_px(img, t, x, y, c)


static func _draw_lava(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Pixel-art lava tile — chunky oranges and dark reds arranged as molten
	# blobs with a bright "hot crack" pattern snaking across the surface.
	# Same palette language as water (4 quantized shades + glints) so the
	# two fluids read as a matched pair.
	var shades: Array = [
		Color(0.30, 0.04, 0.02),   # dark crust
		Color(0.60, 0.12, 0.04),
		Color(0.88, 0.36, 0.08),
		Color(1.00, 0.78, 0.18),   # hot core
	]
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			# Two overlapping noise-ish bases produce cellular blobs at a
			# low spatial frequency — this is lava, so the patches should
			# feel larger than water's tight bands.
			var n1: float = sin(float(x) * 0.9 + float(y) * 0.4) * 0.5 + 0.5
			var n2: float = sin(float(x) * 0.31 + float(y) * 0.87 + 2.3) * 0.5 + 0.5
			var combined: float = n1 * 0.6 + n2 * 0.4
			# Quantize to 4 shade indices.
			var idx: int = clampi(int(combined * 4.0), 0, 3)
			# Per-pixel jitter nudges ±1 shade for irregular blob edges.
			var j: float = rng.randf()
			if j < 0.15 and idx > 0:
				idx -= 1
			elif j > 0.85 and idx < 3:
				idx += 1
			_px(img, t, x, y, shades[idx])
	# Hot cracks — a few zig-zag trails of the hottest shade running across
	# the tile, like glowing seams in a cooled crust.
	for _i: int in 3:
		var crack_y: int = rng.randi_range(2, TILE_SIZE - 3)
		var x: int = 0
		while x < TILE_SIZE:
			if crack_y >= 0 and crack_y < TILE_SIZE:
				_px(img, t, x, crack_y, shades[3])
			# Occasional 2-pixel-wide crack for heft.
			if crack_y + 1 < TILE_SIZE and rng.randf() < 0.35:
				_px(img, t, x, crack_y + 1, shades[2])
			x += 1
			# Drift the crack ±1 along Y so it snakes rather than flowing
			# in a straight line.
			if rng.randf() < 0.30:
				crack_y += rng.randi_range(-1, 1)
				crack_y = clampi(crack_y, 0, TILE_SIZE - 1)
	# Extra-bright specular flecks — the "hottest spots" in the pool.
	var hot := Color(1.00, 0.92, 0.40)
	for _i: int in 5:
		var hx: int = rng.randi_range(1, TILE_SIZE - 2)
		var hy: int = rng.randi_range(1, TILE_SIZE - 2)
		_px(img, t, hx, hy, hot)


static func _draw_smooth_stone(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Brighter uniform grey with light per-pixel jitter, wrapped in a 1-pixel
	# darker outline so block boundaries (and slab edges) read clearly.
	var base := Color(0.70, 0.70, 0.72)
	var border := Color(0.46, 0.46, 0.48)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var on_border: bool = (x == 0 or x == TILE_SIZE - 1 or y == 0 or y == TILE_SIZE - 1)
			if on_border:
				_px(img, t, x, y, border)
			else:
				var jitter: float = (rng.randf() - 0.5) * 0.03
				_px(img, t, x, y, Color(
					clampf(base.r + jitter, 0.0, 1.0),
					clampf(base.g + jitter, 0.0, 1.0),
					clampf(base.b + jitter, 0.0, 1.0)))


static func _draw_barrier(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Classic red-on-white X so barriers are unmistakably "dev tool" when
	# revealed. Transparent background → alpha-cut fills the cell with
	# nothing when the player isn't holding one.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))
	# White border frame so the block's silhouette is clear when held.
	for i: int in TILE_SIZE:
		_px(img, t, i, 0, Color(0.96, 0.96, 0.98, 1.0))
		_px(img, t, i, TILE_SIZE - 1, Color(0.96, 0.96, 0.98, 1.0))
		_px(img, t, 0, i, Color(0.96, 0.96, 0.98, 1.0))
		_px(img, t, TILE_SIZE - 1, i, Color(0.96, 0.96, 0.98, 1.0))
	# Red X across the center.
	var red := Color(0.88, 0.18, 0.18, 1.0)
	for i: int in TILE_SIZE:
		_px(img, t, i, i, red)
		_px(img, t, i, TILE_SIZE - 1 - i, red)
		# Thicken diagonals a touch.
		if i + 1 < TILE_SIZE:
			_px(img, t, i + 1, i, red)
			_px(img, t, i + 1, TILE_SIZE - 1 - i, red)
