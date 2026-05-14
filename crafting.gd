class_name Crafting

# Each recipe: [grid_size, pattern Array[int], output_id, output_count]
# grid_size=2 → pattern has 4 elements (2x2)
# grid_size=3 → pattern has 9 elements (3x3)
# 0 in pattern means empty slot

static var _recipes: Array = []
static var _initialized: bool = false

static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true

	var L: int = Chunk.Block.LOG
	var P: int = Chunk.Block.PLANKS
	var S: int = Items.STICK
	var Co: int = Chunk.Block.COBBLESTONE
	var Ir: int = Items.IRON_INGOT
	var Go: int = Items.GOLD_INGOT
	var Di: int = Items.DIAMOND
	var Le: int = Items.LEATHER

	# --- 2x2 shapeless / shaped recipes ---

	# Log -> 4 Planks (shapeless: any single log)
	_recipes.append([2, [L, 0, 0, 0], Chunk.Block.PLANKS, 4])

	# 2 Planks vertical -> 4 Sticks
	_recipes.append([2, [P, 0, P, 0], Items.STICK, 4])

	# 4 Planks -> Crafting Table
	_recipes.append([2, [P, P, P, P], Chunk.Block.CRAFTING_TABLE, 1])

	# --- 3x3 Wood tools ---
	# Sword: 2 planks + 1 stick
	_recipes.append([3, [0, P, 0, 0, P, 0, 0, S, 0], Items.WOOD_SWORD, 1])
	# Pickaxe: 3 planks top + 2 sticks
	_recipes.append([3, [P, P, P, 0, S, 0, 0, S, 0], Items.WOOD_PICKAXE, 1])
	# Axe
	_recipes.append([3, [P, P, 0, P, S, 0, 0, S, 0], Items.WOOD_AXE, 1])
	# Shovel
	_recipes.append([3, [0, P, 0, 0, S, 0, 0, S, 0], Items.WOOD_SHOVEL, 1])
	# Hoe
	_recipes.append([3, [P, P, 0, 0, S, 0, 0, S, 0], Items.WOOD_HOE, 1])

	# --- 3x3 Stone tools ---
	_recipes.append([3, [0, Co, 0, 0, Co, 0, 0, S, 0], Items.STONE_SWORD, 1])
	_recipes.append([3, [Co, Co, Co, 0, S, 0, 0, S, 0], Items.STONE_PICKAXE, 1])
	_recipes.append([3, [Co, Co, 0, Co, S, 0, 0, S, 0], Items.STONE_AXE, 1])
	_recipes.append([3, [0, Co, 0, 0, S, 0, 0, S, 0], Items.STONE_SHOVEL, 1])
	_recipes.append([3, [Co, Co, 0, 0, S, 0, 0, S, 0], Items.STONE_HOE, 1])

	# --- 3x3 Iron tools ---
	_recipes.append([3, [0, Ir, 0, 0, Ir, 0, 0, S, 0], Items.IRON_SWORD, 1])
	_recipes.append([3, [Ir, Ir, Ir, 0, S, 0, 0, S, 0], Items.IRON_PICKAXE, 1])
	_recipes.append([3, [Ir, Ir, 0, Ir, S, 0, 0, S, 0], Items.IRON_AXE, 1])
	_recipes.append([3, [0, Ir, 0, 0, S, 0, 0, S, 0], Items.IRON_SHOVEL, 1])
	_recipes.append([3, [Ir, Ir, 0, 0, S, 0, 0, S, 0], Items.IRON_HOE, 1])

	# --- 3x3 Gold tools ---
	_recipes.append([3, [0, Go, 0, 0, Go, 0, 0, S, 0], Items.GOLD_SWORD, 1])
	_recipes.append([3, [Go, Go, Go, 0, S, 0, 0, S, 0], Items.GOLD_PICKAXE, 1])
	_recipes.append([3, [Go, Go, 0, Go, S, 0, 0, S, 0], Items.GOLD_AXE, 1])
	_recipes.append([3, [0, Go, 0, 0, S, 0, 0, S, 0], Items.GOLD_SHOVEL, 1])
	_recipes.append([3, [Go, Go, 0, 0, S, 0, 0, S, 0], Items.GOLD_HOE, 1])

	# --- 3x3 Diamond tools ---
	_recipes.append([3, [0, Di, 0, 0, Di, 0, 0, S, 0], Items.DIAMOND_SWORD, 1])
	_recipes.append([3, [Di, Di, Di, 0, S, 0, 0, S, 0], Items.DIAMOND_PICKAXE, 1])
	_recipes.append([3, [Di, Di, 0, Di, S, 0, 0, S, 0], Items.DIAMOND_AXE, 1])
	_recipes.append([3, [0, Di, 0, 0, S, 0, 0, S, 0], Items.DIAMOND_SHOVEL, 1])
	_recipes.append([3, [Di, Di, 0, 0, S, 0, 0, S, 0], Items.DIAMOND_HOE, 1])

	# --- Armor: Leather ---
	_recipes.append([3, [Le, Le, Le, Le, 0, Le, 0, 0, 0], Items.LEATHER_HELMET, 1])
	_recipes.append([3, [Le, 0, Le, Le, Le, Le, Le, Le, Le], Items.LEATHER_CHESTPLATE, 1])
	_recipes.append([3, [Le, Le, Le, Le, 0, Le, Le, 0, Le], Items.LEATHER_LEGGINGS, 1])
	_recipes.append([3, [0, 0, 0, Le, 0, Le, Le, 0, Le], Items.LEATHER_BOOTS, 1])

	# --- Armor: Iron ---
	_recipes.append([3, [Ir, Ir, Ir, Ir, 0, Ir, 0, 0, 0], Items.IRON_HELMET, 1])
	_recipes.append([3, [Ir, 0, Ir, Ir, Ir, Ir, Ir, Ir, Ir], Items.IRON_CHESTPLATE, 1])
	_recipes.append([3, [Ir, Ir, Ir, Ir, 0, Ir, Ir, 0, Ir], Items.IRON_LEGGINGS, 1])
	_recipes.append([3, [0, 0, 0, Ir, 0, Ir, Ir, 0, Ir], Items.IRON_BOOTS, 1])

	# --- Armor: Gold ---
	_recipes.append([3, [Go, Go, Go, Go, 0, Go, 0, 0, 0], Items.GOLD_HELMET, 1])
	_recipes.append([3, [Go, 0, Go, Go, Go, Go, Go, Go, Go], Items.GOLD_CHESTPLATE, 1])
	_recipes.append([3, [Go, Go, Go, Go, 0, Go, Go, 0, Go], Items.GOLD_LEGGINGS, 1])
	_recipes.append([3, [0, 0, 0, Go, 0, Go, Go, 0, Go], Items.GOLD_BOOTS, 1])

	# --- Armor: Diamond ---
	_recipes.append([3, [Di, Di, Di, Di, 0, Di, 0, 0, 0], Items.DIAMOND_HELMET, 1])
	_recipes.append([3, [Di, 0, Di, Di, Di, Di, Di, Di, Di], Items.DIAMOND_CHESTPLATE, 1])
	_recipes.append([3, [Di, Di, Di, Di, 0, Di, Di, 0, Di], Items.DIAMOND_LEGGINGS, 1])
	_recipes.append([3, [0, 0, 0, Di, 0, Di, Di, 0, Di], Items.DIAMOND_BOOTS, 1])

	# --- Blocks ---
	# 8 cobblestone -> furnace
	_recipes.append([3, [Co, Co, Co, Co, 0, Co, Co, Co, Co], Chunk.Block.FURNACE, 1])
	# 9 iron ingot -> iron block (4 ingots in a 2x2 pattern in a 3x3)
	_recipes.append([3, [Ir, Ir, 0, Ir, Ir, 0, 0, 0, 0], Chunk.Block.IRON_BLOCK, 1])
	# 9 gold ingot -> gold block
	_recipes.append([3, [Go, Go, 0, Go, Go, 0, 0, 0, 0], Chunk.Block.GOLD_BLOCK, 1])


## Normalize a grid to its bounding box — removes leading/trailing empty rows and
## columns so the pattern can match regardless of where it's placed in the grid.
static func _normalize(grid: Array[int], grid_size: int) -> Array:
	var min_r: int = grid_size
	var max_r: int = -1
	var min_c: int = grid_size
	var max_c: int = -1
	for r: int in grid_size:
		for c: int in grid_size:
			if grid[r * grid_size + c] != 0:
				if r < min_r: min_r = r
				if r > max_r: max_r = r
				if c < min_c: min_c = c
				if c > max_c: max_c = c
	if max_r < 0:
		return [[], 0, 0]  # empty grid
	var rows: int = max_r - min_r + 1
	var cols: int = max_c - min_c + 1
	var out: Array[int] = []
	for r: int in rows:
		for c: int in cols:
			out.append(grid[(min_r + r) * grid_size + (min_c + c)])
	return [out, rows, cols]


## Try to match the player's crafting grid against all recipes.
## Returns {id, count} or empty dict.
static func match_recipe(grid: Array[int], grid_size: int) -> Dictionary:
	_ensure_init()
	var norm_result: Array = _normalize(grid, grid_size)
	var norm_grid: Array = norm_result[0]
	var g_rows: int = norm_result[1]
	var g_cols: int = norm_result[2]
	if norm_grid.is_empty():
		return {}

	for recipe: Array in _recipes:
		var r_size: int = recipe[0]
		var r_pattern: Array = recipe[1]
		var r_out: int = recipe[2]
		var r_count: int = recipe[3]

		# Normalize the recipe pattern
		var r_norm_result: Array = _normalize(r_pattern, r_size)
		var r_norm: Array = r_norm_result[0]
		var r_rows: int = r_norm_result[1]
		var r_cols: int = r_norm_result[2]

		if r_norm.is_empty():
			continue

		# The normalized grids must match in size and content
		if g_rows != r_rows or g_cols != r_cols:
			continue
		if norm_grid.size() != r_norm.size():
			continue

		# Check shapeless: same ingredients regardless of position
		# Detect shapeless by checking if the recipe is a single-ingredient pattern
		# For logs: shapeless — any arrangement of 1 log works
		var is_shapeless: bool = (r_rows == 1 and r_cols == 1 and g_rows == 1 and g_cols == 1)

		if is_shapeless:
			if _shapeless_match(norm_grid, r_norm):
				return {"id": r_out, "count": r_count}
		else:
			if _exact_match(norm_grid, r_norm):
				return {"id": r_out, "count": r_count}

	return {}


static func _exact_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if a[i] != b[i]:
			return false
	return true


static func _shapeless_match(grid_norm: Array, recipe_norm: Array) -> bool:
	# Build ingredient counts for each
	var grid_counts: Dictionary = {}
	var recipe_counts: Dictionary = {}
	for v: int in grid_norm:
		if v != 0:
			grid_counts[v] = grid_counts.get(v, 0) + 1
	for v: int in recipe_norm:
		if v != 0:
			recipe_counts[v] = recipe_counts.get(v, 0) + 1
	return grid_counts == recipe_counts


## Return the list of ingredients consumed (as [[id, count]] pairs) for the
## given grid, or empty if no recipe matches. Used by UIs to verify crafting.
static func get_ingredients(grid: Array[int], grid_size: int) -> Array:
	var result: Dictionary = match_recipe(grid, grid_size)
	if result.is_empty():
		return []
	var ingredients: Dictionary = {}
	for v: int in grid:
		if v != 0:
			ingredients[v] = ingredients.get(v, 0) + 1
	var out: Array = []
	for id: int in ingredients:
		out.append([id, ingredients[id]])
	return out
