class_name BlockTextures

const TILE_SIZE: int = 16
const TILE_COUNT: int = 55
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
# 48 poppy            49 dandelion

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
	_draw_ore(img, rng, 22, Color(0.05, 0.05, 0.05))   # coal
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
			img.set_pixel(x, y, Color(
				luma + (c.r - luma) * ICON_DESATURATION,
				luma + (c.g - luma) * ICON_DESATURATION,
				luma + (c.b - luma) * ICON_DESATURATION,
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
	# Match the in-world water shader: horizontal streaks (quantized to 3
	# shades) blended with a mottle pattern (quantized to 4), so the inventory
	# icon reads as the same block the shader renders in the world.
	var deep := Color(0.10, 0.24, 0.58)
	var light := Color(0.36, 0.58, 0.95)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var fx: float = float(x) / float(TILE_SIZE)
			var fy: float = float(y) / float(TILE_SIZE)
			var streak: float = sin(fy * 18.0) * 0.5 + 0.5
			streak = floor(streak * 3.0) / 3.0
			var mottle: float = sin(fx * 6.0 + fy * 2.0) * 0.5 + 0.5
			mottle = floor(mottle * 4.0) / 4.0
			var shimmer: float = streak * 0.6 + mottle * 0.4
			_px(img, t, x, y, deep.lerp(light, shimmer))


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
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.2:
				c = Color(0.26, 0.26, 0.27)
			elif r < 0.5:
				c = Color(0.34, 0.34, 0.34)
			elif r < 0.8:
				c = Color(0.42, 0.42, 0.41)
			else:
				c = Color(0.46, 0.46, 0.45)
			_px(img, t, x, y, c)
	# Dark mortar grid
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			if (x % 5 == 0 or y % 5 == 0) and rng.randf() < 0.6:
				_px(img, t, x, y, Color(0.22, 0.22, 0.23))


static func _draw_brick(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var brick_row: int = y / 4
			var offset: int = 8 if brick_row % 2 == 1 else 0
			var bx: int = (x + offset) % 16
			var is_mortar: bool = (y % 4 == 0) or (bx % 8 == 0)
			if is_mortar:
				_px(img, t, x, y, Color(0.55, 0.53, 0.48))
			else:
				var r: float = rng.randf()
				var c: Color
				if r < 0.3:
					c = Color(0.60, 0.25, 0.18)
				elif r < 0.7:
					c = Color(0.68, 0.30, 0.20)
				else:
					c = Color(0.72, 0.35, 0.24)
				_px(img, t, x, y, c)


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
	# Minecraft-style oak log side: warm brown with clean vertical wood grain.
	# Darker than the inner-ring top face so the bark reads as "bark, not wood"
	# in-world. Each column gets one of three shade classes (dark/mid/light)
	# with subtle per-pixel noise.
	var col_shade := PackedFloat32Array()
	col_shade.resize(TILE_SIZE)
	# Default: mid-bark.
	for x: int in TILE_SIZE:
		col_shade[x] = 0.32
	# Darker grain columns — the "bark grooves".
	for col: int in [2, 7, 12]:
		col_shade[col] = 0.20
	# Subtle lighter highlights between grain.
	for col: int in [5, 10, 14]:
		col_shade[col] = 0.38

	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var s: float = col_shade[x] + (rng.randf() - 0.5) * 0.03
			_px(img, t, x, y, Color(s, s * 0.64, s * 0.32))


static func _draw_log_top(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	var center := Vector2(7.5, 7.5)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var dist: float = Vector2(x, y).distance_to(center)
			var ring: int = int(dist) % 3
			var c: Color
			if dist > 7:
				c = Color(0.40, 0.28, 0.14)  # bark edge
			elif ring == 0:
				c = Color(0.62, 0.48, 0.28)
			elif ring == 1:
				c = Color(0.55, 0.42, 0.24)
			else:
				c = Color(0.58, 0.45, 0.26)
			c += Color(rng.randf() * 0.03, rng.randf() * 0.03, rng.randf() * 0.02, 0)
			_px(img, t, x, y, c)


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
	# Deep-purple polished volcanic glass. A base of dark eggplant tones with
	# scattered brighter violet specks for crystalline shine, plus a few
	# bright pinpoint highlights so the surface reads as glossy instead of
	# matte-black.
	var base := Color(0.09, 0.05, 0.15)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var c: Color
			if r < 0.25:
				c = Color(0.06, 0.03, 0.10)
			elif r < 0.65:
				c = base
			elif r < 0.90:
				c = Color(0.13, 0.07, 0.21)
			else:
				c = Color(0.18, 0.10, 0.28)
			_px(img, t, x, y, c)
	# Crystalline specks — deep violet mid-brightness flecks.
	for _i: int in 14:
		var cx: int = rng.randi() % TILE_SIZE
		var cy: int = rng.randi() % TILE_SIZE
		_px(img, t, cx, cy, Color(0.26, 0.15, 0.40))
	# A few bright glossy pinpoints for the "shiny rock" read.
	for _i: int in 5:
		var sx: int = rng.randi() % TILE_SIZE
		var sy: int = rng.randi() % TILE_SIZE
		_px(img, t, sx, sy, Color(0.52, 0.32, 0.72))


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
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = 0.76 + rng.randf() * 0.04
			var g: float = 0.64 + rng.randf() * 0.06
			_px(img, t, x, y, Color(r, g, 0.16))
	# Darker border
	for i: int in TILE_SIZE:
		if i == 0 or i == TILE_SIZE - 1:
			for j: int in TILE_SIZE:
				_px(img, t, i, j, Color(0.58, 0.46, 0.10))
				_px(img, t, j, i, Color(0.58, 0.46, 0.10))


static func _draw_ore(img: Image, rng: RandomNumberGenerator, t: int, ore_color: Color) -> void:
	# Stone base
	_draw_stone(img, rng, t)
	# Ore clusters — 5-7 small irregular blobs
	var cluster_count: int = rng.randi_range(5, 7)
	for _i: int in cluster_count:
		var cx: int = rng.randi_range(1, TILE_SIZE - 2)
		var cy: int = rng.randi_range(1, TILE_SIZE - 2)
		var size: int = rng.randi_range(1, 2)
		for dy: int in range(-size, size + 1):
			for dx: int in range(-size, size + 1):
				if absi(dx) + absi(dy) > size:
					continue
				var px: int = cx + dx
				var py: int = cy + dy
				if px >= 0 and px < TILE_SIZE and py >= 0 and py < TILE_SIZE:
					var shade: float = 1.0 + (rng.randf() - 0.5) * 0.15
					var c: Color = Color(ore_color.r * shade, ore_color.g * shade, ore_color.b * shade)
					_px(img, t, px, py, c)


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
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var r: float = rng.randf()
			var shade: float
			if r < 0.20:
				shade = 0.90
			elif r < 0.45:
				shade = 0.96
			elif r < 0.80:
				shade = 1.00
			else:
				shade = 1.06
			var c := Color(base_col.r * shade, base_col.g * shade, base_col.b * shade)
			_px(img, t, x, y, c)


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
	# Transparent tile with a stem + a four-petal red flower head on top,
	# drawn for the X-quad plant mesh. Shape inspired by Minecraft's poppy.
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))
	# Stem — thin green vertical line in the center.
	var stem := Color(0.18, 0.42, 0.14, 1.0)
	for y: int in range(6, 15):
		_px(img, t, 7, y, stem)
		if y < 12:
			_px(img, t, 8, y, stem)
	# Two leaves hanging off the stem.
	var leaf := Color(0.24, 0.54, 0.16, 1.0)
	_px(img, t, 5, 10, leaf); _px(img, t, 6, 10, leaf)
	_px(img, t, 9, 8, leaf); _px(img, t, 10, 8, leaf)
	# Red petals — four-leaf clover shape centered near (7, 4).
	var petal := Color(0.82, 0.14, 0.12, 1.0)
	var petal_hl := Color(0.95, 0.30, 0.22, 1.0)
	var petals: Array = [
		# (x, y, highlight?)
		[6, 2], [7, 2], [8, 2],
		[5, 3], [6, 3], [8, 3], [9, 3],
		[5, 4], [6, 4], [8, 4], [9, 4],
		[6, 5], [7, 5], [8, 5],
	]
	for p: Array in petals:
		_px(img, t, p[0], p[1], petal)
	# Slight highlights on upper row.
	_px(img, t, 6, 2, petal_hl)
	_px(img, t, 8, 2, petal_hl)
	# Dark center pip.
	_px(img, t, 7, 4, Color(0.20, 0.05, 0.05, 1.0))


static func _draw_dandelion(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Transparent tile with a stem + a yellow flower head, Minecraft-style
	# dandelion. Simpler rounded head (no petal separation).
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			_px(img, t, x, y, Color(0, 0, 0, 0))
	var stem := Color(0.22, 0.50, 0.18, 1.0)
	for y: int in range(6, 15):
		_px(img, t, 7, y, stem)
		if y < 13:
			_px(img, t, 8, y, stem)
	var leaf := Color(0.26, 0.58, 0.20, 1.0)
	_px(img, t, 5, 10, leaf); _px(img, t, 6, 10, leaf)
	_px(img, t, 9, 9, leaf); _px(img, t, 10, 9, leaf)
	# Yellow flower head.
	var flower := Color(0.95, 0.82, 0.14, 1.0)
	var flower_hl := Color(1.0, 0.95, 0.30, 1.0)
	var flower_sh := Color(0.75, 0.58, 0.08, 1.0)
	for dy: int in range(1, 6):
		for dx: int in range(5, 11):
			# Rough circular mask.
			var d2: int = (dx - 7) * (dx - 7) + (dy - 3) * (dy - 3)
			if d2 > 6:
				continue
			_px(img, t, dx, dy, flower)
	# Highlights + shadow.
	_px(img, t, 6, 2, flower_hl)
	_px(img, t, 7, 2, flower_hl)
	_px(img, t, 8, 5, flower_sh)
	_px(img, t, 9, 4, flower_sh)


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


## Nether gold ore — netherrack base with scattered gold specks. The gold
## is brighter and more orange than overworld gold ore to stand out against
## the red netherrack.
static func _draw_nether_gold_ore(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_netherrack(img, rng, t)
	var gold := Color(0.95, 0.75, 0.20)
	var gold_dk := Color(0.72, 0.52, 0.12)
	var count: int = rng.randi_range(8, 14)
	for _i: int in count:
		var cx: int = rng.randi_range(1, TILE_SIZE - 2)
		var cy: int = rng.randi_range(1, TILE_SIZE - 2)
		_px(img, t, cx, cy, gold)
		# Adjacent pixel for a 1-2 pixel cluster
		if rng.randf() < 0.5:
			var dx: int = rng.randi_range(-1, 1)
			var dy: int = rng.randi_range(-1, 1)
			var nx: int = clampi(cx + dx, 0, TILE_SIZE - 1)
			var ny: int = clampi(cy + dy, 0, TILE_SIZE - 1)
			_px(img, t, nx, ny, gold_dk)


## Nether quartz ore — netherrack base with white/cream quartz veins.
## Distinctive from gold by being pale against the dark red background.
static func _draw_nether_quartz_ore(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	_draw_netherrack(img, rng, t)
	var quartz := Color(0.92, 0.88, 0.82)
	var quartz_dk := Color(0.75, 0.70, 0.65)
	# Quartz forms in small veins/lines rather than scattered dots.
	var veins: int = rng.randi_range(3, 5)
	for _v: int in veins:
		var sx: int = rng.randi_range(1, TILE_SIZE - 2)
		var sy: int = rng.randi_range(1, TILE_SIZE - 2)
		var length: int = rng.randi_range(2, 4)
		var dx: int = rng.randi_range(-1, 1)
		var dy: int = rng.randi_range(-1, 1)
		if dx == 0 and dy == 0:
			dx = 1
		for _s: int in length:
			if sx >= 0 and sx < TILE_SIZE and sy >= 0 and sy < TILE_SIZE:
				_px(img, t, sx, sy, quartz if rng.randf() < 0.6 else quartz_dk)
			sx += dx
			sy += dy


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


static func _draw_lava(img: Image, rng: RandomNumberGenerator, t: int) -> void:
	# Pattern mirrors the water inventory tile (streaks + mottle) but in
	# molten oranges and reds so the dropdown preview reads as lava.
	var deep := Color(0.45, 0.08, 0.02)
	var light := Color(0.98, 0.62, 0.12)
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			var fx: float = float(x) / float(TILE_SIZE)
			var fy: float = float(y) / float(TILE_SIZE)
			var streak: float = sin(fy * 14.0) * 0.5 + 0.5
			streak = floor(streak * 3.0) / 3.0
			var mottle: float = sin(fx * 4.5 + fy * 2.0) * 0.5 + 0.5
			mottle = floor(mottle * 4.0) / 4.0
			var shimmer: float = streak * 0.55 + mottle * 0.45
			_px(img, t, x, y, deep.lerp(light, shimmer))


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
