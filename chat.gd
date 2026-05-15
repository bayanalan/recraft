extends Control

## Simple local chat overlay. Press Enter to open the input bar, type a
## message, press Enter again to send (or Escape to cancel). Sent messages
## appear in a scrolling log above the input and fade out after a few seconds.
## Works with captured mouse — no cursor release needed.

const MAX_VISIBLE_MESSAGES: int = 10
const MESSAGE_LIFETIME: float = 8.0     # seconds before a message starts fading
const MESSAGE_FADE_TIME: float = 2.0    # fade-out duration after lifetime expires
const INPUT_HEIGHT: float = 36.0
var MSG_FONT_SIZE: int = PauseMenu._fs(22)
var INPUT_FONT_SIZE: int = PauseMenu._fs(24)
const BOTTOM_MARGIN: float = 60.0       # above the hotbar

var _open: bool = false
var _input_line: LineEdit = null
var _msg_container: VBoxContainer = null
var _messages: Array = []
var _font: Font = null

# Command history — up/down arrows cycle through previous commands.
var _history: Array[String] = []
var _history_idx: int = -1  # -1 = not browsing history
var _saved_input: String = ""  # what user typed before browsing

# Tab completion data.
const COMMANDS: Array[String] = ["/time", "/tick", "/gamerule", "/noclip", "/durability", "/give"]
const COMPLETIONS: Dictionary = {
	"/time": ["set"],
	"/time set": ["day", "night", "noon", "midnight"],
	"/tick": ["rate"],
	"/gamerule": ["dodaylightcycle"],
	"/gamerule dodaylightcycle": ["true", "false"],
	"/noclip": ["true", "false"],
	"/durability": ["max"],
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://fonts/font.ttf")

	# Message log — bottom-aligned VBox that grows upward.
	_msg_container = VBoxContainer.new()
	_msg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_msg_container.anchor_top = 0.0
	_msg_container.anchor_bottom = 1.0
	_msg_container.anchor_left = 0.0
	_msg_container.anchor_right = 0.5
	_msg_container.offset_bottom = -(BOTTOM_MARGIN + INPUT_HEIGHT + 4)
	_msg_container.offset_left = 8.0
	_msg_container.grow_vertical = Control.GROW_DIRECTION_END
	_msg_container.alignment = BoxContainer.ALIGNMENT_END
	_msg_container.add_theme_constant_override("separation", 2)
	add_child(_msg_container)

	# Input bar — hidden until Enter is pressed.
	_input_line = LineEdit.new()
	_input_line.visible = false
	_input_line.placeholder_text = "Type a message..."
	_input_line.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_input_line.anchor_top = 1.0
	_input_line.anchor_bottom = 1.0
	_input_line.anchor_left = 0.0
	_input_line.anchor_right = 0.5
	_input_line.offset_top = -(BOTTOM_MARGIN + INPUT_HEIGHT)
	_input_line.offset_bottom = -BOTTOM_MARGIN
	_input_line.offset_left = 8.0
	if _font != null:
		_input_line.add_theme_font_override("font", _font)
	_input_line.add_theme_font_size_override("font_size", INPUT_FONT_SIZE)
	_input_line.add_theme_color_override("font_color", Color(1, 1, 1))
	_input_line.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	# Semi-transparent dark background so text is readable over the game.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(0)
	bg.content_margin_left = 6
	bg.content_margin_right = 6
	_input_line.add_theme_stylebox_override("normal", bg)
	_input_line.add_theme_stylebox_override("focus", bg)
	add_child(_input_line)


func _process(delta: float) -> void:
	# Tick message lifetimes and fade them out.
	var i: int = 0
	while i < _messages.size():
		var entry: Dictionary = _messages[i]
		entry["time"] -= delta
		var lbl: Label = entry["label"]
		if entry["time"] < -MESSAGE_FADE_TIME:
			# Fully faded — remove.
			lbl.queue_free()
			_messages.remove_at(i)
			continue
		elif entry["time"] < 0.0:
			# Fading out.
			lbl.modulate.a = 1.0 + entry["time"] / MESSAGE_FADE_TIME
		else:
			# Chat open → keep messages fully visible regardless of timer
			# so you can read context while typing.
			if _open:
				lbl.modulate.a = 1.0
		i += 1


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if not _open:
		if event.keycode == KEY_ENTER:
			_open_chat()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SLASH:
			_open_chat("/")
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ENTER:
		_send_and_close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		_close_chat()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_UP:
		_history_prev()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DOWN:
		_history_next()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB:
		_tab_complete()
		get_viewport().set_input_as_handled()


func _open_chat(prefill: String = "") -> void:
	_open = true
	_input_line.visible = true
	_input_line.text = prefill
	_input_line.caret_column = prefill.length()
	_input_line.grab_focus()
	# Make all existing messages fully visible while chat is open.
	for entry: Dictionary in _messages:
		(entry["label"] as Label).modulate.a = 1.0


func _close_chat() -> void:
	_open = false
	_input_line.visible = false
	_input_line.release_focus()


func _send_and_close() -> void:
	var text: String = _input_line.text.strip_edges()
	if text.is_empty():
		_close_chat()
		return
	# Push to history (avoid duplicating the last entry).
	if _history.is_empty() or _history[_history.size() - 1] != text:
		_history.append(text)
	_history_idx = -1
	if text.begins_with("/"):
		_execute_command(text)
	else:
		add_message("<You> " + text)
	_close_chat()


func _history_prev() -> void:
	if _history.is_empty():
		return
	if _history_idx == -1:
		_saved_input = _input_line.text
		_history_idx = _history.size() - 1
	elif _history_idx > 0:
		_history_idx -= 1
	_input_line.text = _history[_history_idx]
	_input_line.caret_column = _input_line.text.length()


func _history_next() -> void:
	if _history_idx == -1:
		return
	_history_idx += 1
	if _history_idx >= _history.size():
		_history_idx = -1
		_input_line.text = _saved_input
	else:
		_input_line.text = _history[_history_idx]
	_input_line.caret_column = _input_line.text.length()


func _tab_complete() -> void:
	var text: String = _input_line.text
	if not text.begins_with("/"):
		return
	var parts: PackedStringArray = text.split(" ", false)
	# Build the prefix key for lookup (all parts except the last incomplete one).
	# If text ends with a space, the user wants completions for the NEXT argument.
	var ends_with_space: bool = text.ends_with(" ")
	var prefix_parts: PackedStringArray
	var partial: String
	if ends_with_space:
		prefix_parts = parts
		partial = ""
	else:
		prefix_parts = parts.slice(0, parts.size() - 1)
		partial = parts[parts.size() - 1].to_lower() if parts.size() > 0 else ""
	# If we're completing the command itself (first word).
	if prefix_parts.is_empty():
		var matches: Array[String] = []
		for cmd: String in COMMANDS:
			if cmd.begins_with(partial):
				matches.append(cmd)
		if matches.size() == 1:
			_input_line.text = matches[0] + " "
			_input_line.caret_column = _input_line.text.length()
		elif matches.size() > 1:
			add_message("Options: " + " ".join(matches))
		return
	# Completing an argument — build the lookup key from prefix parts.
	var key: String = " ".join(prefix_parts).to_lower()
	if not COMPLETIONS.has(key):
		return
	var options: Array = COMPLETIONS[key]
	var matches: Array[String] = []
	for opt: String in options:
		if partial.is_empty() or opt.begins_with(partial):
			matches.append(opt)
	if matches.size() == 1:
		var completed: String = " ".join(prefix_parts) + " " + matches[0] + " "
		_input_line.text = completed
		_input_line.caret_column = _input_line.text.length()
	elif matches.size() > 1:
		add_message("Options: " + " ".join(matches))


## Find the main node (game scene root) to access game rules + day/night.
func _get_main() -> Node:
	# Chat is HUD → Main. Walk up to find the node with the game rule vars.
	var n: Node = self
	while n != null:
		if n.has_method("_update_day_night"):
			return n
		n = n.get_parent()
	# Fallback: try the tree root's first child (main scene root).
	return get_tree().current_scene


func _execute_command(text: String) -> void:
	if GameConfig.game_mode == GameConfig.GameMode.SURVIVAL and not GameConfig.cheats_enabled:
		add_message("Commands disabled. Enable cheats at world creation.")
		return
	var parts: PackedStringArray = text.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0].to_lower()

	match cmd:
		"/time":
			_cmd_time(parts)
		"/tick":
			_cmd_tick(parts)
		"/gamerule":
			_cmd_gamerule(parts)
		"/noclip":
			_cmd_noclip(parts)
		"/durability":
			_cmd_durability(parts)
		"/give":
			_cmd_give(parts)
		_:
			add_message("Unknown command: " + cmd)


func _cmd_time(parts: PackedStringArray) -> void:
	# /time set day|night|noon|midnight
	if parts.size() < 3 or parts[1].to_lower() != "set":
		add_message("Usage: /time set <day|night|noon|midnight>")
		return
	var main: Node = _get_main()
	if main == null:
		add_message("Cannot access game state")
		return
	var value: String = parts[2].to_lower()
	match value:
		"day":
			main.set("_day_time", 0.0)     # dawn
			add_message("Time set to day")
		"noon":
			main.set("_day_time", 0.25)    # noon
			add_message("Time set to noon")
		"night":
			main.set("_day_time", 0.5)     # dusk → night
			add_message("Time set to night")
		"midnight":
			main.set("_day_time", 0.75)    # midnight
			add_message("Time set to midnight")
		_:
			add_message("Unknown time: " + value + ". Use day/night/noon/midnight")


func _cmd_tick(parts: PackedStringArray) -> void:
	# /tick rate <number>
	if parts.size() < 3 or parts[1].to_lower() != "rate":
		add_message("Usage: /tick rate <number> (base: 20)")
		return
	var main: Node = _get_main()
	if main == null:
		add_message("Cannot access game state")
		return
	if not parts[2].is_valid_float():
		add_message("Invalid number: " + parts[2])
		return
	var rate: float = clampf(float(parts[2]), 0.1, 10000.0)
	main.set("tick_rate", rate)
	add_message("Tick rate set to " + str(rate))


func _cmd_gamerule(parts: PackedStringArray) -> void:
	# /gamerule dodaylightcycle true|false
	if parts.size() < 3:
		add_message("Usage: /gamerule <rule> <true|false>")
		return
	var main: Node = _get_main()
	if main == null:
		add_message("Cannot access game state")
		return
	var rule: String = parts[1].to_lower()
	var val: String = parts[2].to_lower()
	var bool_val: bool = val == "true"
	match rule:
		"dodaylightcycle":
			main.set("do_daylight_cycle", bool_val)
			add_message("dodaylightcycle set to " + str(bool_val))
		_:
			add_message("Unknown gamerule: " + rule)


func _cmd_noclip(parts: PackedStringArray) -> void:
	# /noclip true|false
	var main: Node = _get_main()
	if main == null:
		add_message("Cannot access game state")
		return
	if parts.size() < 2:
		# Toggle if no argument
		var current: bool = main.get("noclip")
		main.set("noclip", not current)
		add_message("Noclip " + ("enabled" if not current else "disabled"))
		return
	var val: String = parts[1].to_lower()
	var enabled: bool = val == "true"
	main.set("noclip", enabled)
	add_message("Noclip " + ("enabled" if enabled else "disabled"))


func _cmd_durability(parts: PackedStringArray) -> void:
	var hud: Node = get_parent()
	if hud == null or not "inventory" in hud or not "selected_slot" in hud:
		add_message("Cannot access inventory")
		return
	var inv: Inventory = hud.inventory
	var slot: int = hud.selected_slot
	var item_id: int = inv.ids[slot]
	if item_id == 0:
		add_message("No item held")
		return
	var max_dur: int = Items.get_max_durability(item_id)
	if max_dur <= 0:
		add_message("Held item has no durability")
		return
	if parts.size() < 2:
		var cur: int = inv.durabilities[slot]
		var display: int = max_dur if cur == 0 else cur
		add_message("Durability: %d / %d  (use /durability <value|max>)" % [display, max_dur])
		return
	var arg: String = parts[1].to_lower()
	var new_dur: int
	if arg == "max":
		new_dur = max_dur
	elif arg.is_valid_int():
		new_dur = clampi(arg.to_int(), 1, max_dur)
	else:
		add_message("Usage: /durability <1-%d | max>" % max_dur)
		return
	inv.durabilities[slot] = new_dur if new_dur < max_dur else 0
	if hud.has_method("_sync_slots_from_inventory"):
		hud._sync_slots_from_inventory()
	var shown: int = max_dur if new_dur >= max_dur else new_dur
	add_message("Set durability to %d / %d" % [shown, max_dur])


func _cmd_give(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		add_message("Usage: /give <item> [count]")
		return
	var hud: Node = get_parent()
	if hud == null or not "inventory" in hud:
		add_message("Cannot access inventory")
		return
	var inv: Inventory = hud.inventory
	var query: String = parts[1].to_lower()
	var count: int = 1
	if parts.size() >= 3 and parts[2].is_valid_int():
		count = maxi(1, parts[2].to_int())

	var name_map: Dictionary = _give_name_map()

	# Exact match first, then prefix search
	var matched_key: String = ""
	if name_map.has(query):
		matched_key = query
	else:
		var hits: Array[String] = []
		for k: String in name_map:
			if k.begins_with(query):
				hits.append(k)
		hits.sort()
		if hits.size() == 1:
			matched_key = hits[0]
		elif hits.size() > 1:
			add_message("Did you mean: " + ", ".join(hits.slice(0, 8)))
			return
		else:
			add_message("Unknown item: " + query)
			return

	var id: int = name_map[matched_key]
	var leftover: int = inv.give_item(id, count)
	if hud.has_method("_sync_slots_from_inventory"):
		hud._sync_slots_from_inventory()
	var given: int = count - leftover
	if given > 0:
		add_message("Gave %dx %s" % [given, Items.get_item_name(id)])
	else:
		add_message("Inventory full")


static func _give_name_map() -> Dictionary:
	var B: Dictionary = {
		"stone": Chunk.Block.STONE, "cobblestone": Chunk.Block.COBBLESTONE,
		"brick": Chunk.Block.BRICK, "dirt": Chunk.Block.DIRT,
		"planks": Chunk.Block.PLANKS, "log": Chunk.Block.LOG,
		"leaves": Chunk.Block.LEAVES, "glass": Chunk.Block.GLASS,
		"sand": Chunk.Block.SAND, "grass": Chunk.Block.GRASS,
		"mossy_cobblestone": Chunk.Block.MOSSY_COBBLESTONE,
		"bedrock": Chunk.Block.BEDROCK, "obsidian": Chunk.Block.OBSIDIAN,
		"bookshelf": Chunk.Block.BOOKSHELF, "sponge": Chunk.Block.SPONGE,
		"tnt": Chunk.Block.TNT,
		"iron_block": Chunk.Block.IRON_BLOCK, "gold_block": Chunk.Block.GOLD_BLOCK,
		"diamond_block": Chunk.Block.DIAMOND_BLOCK, "coal_block": Chunk.Block.COAL_BLOCK,
		"coal_ore": Chunk.Block.COAL_ORE, "iron_ore": Chunk.Block.IRON_ORE,
		"gold_ore": Chunk.Block.GOLD_ORE, "diamond_ore": Chunk.Block.DIAMOND_ORE,
		"wool_white": Chunk.Block.WOOL_WHITE, "wool_red": Chunk.Block.WOOL_RED,
		"wool_yellow": Chunk.Block.WOOL_YELLOW, "wool_green": Chunk.Block.WOOL_GREEN,
		"wool_blue": Chunk.Block.WOOL_BLUE, "wool_orange": Chunk.Block.WOOL_ORANGE,
		"wool_magenta": Chunk.Block.WOOL_MAGENTA, "wool_light_blue": Chunk.Block.WOOL_LIGHT_BLUE,
		"wool_lime": Chunk.Block.WOOL_LIME, "wool_pink": Chunk.Block.WOOL_PINK,
		"wool_gray": Chunk.Block.WOOL_GRAY, "wool_light_gray": Chunk.Block.WOOL_LIGHT_GRAY,
		"wool_cyan": Chunk.Block.WOOL_CYAN, "wool_purple": Chunk.Block.WOOL_PURPLE,
		"wool_brown": Chunk.Block.WOOL_BROWN, "wool_black": Chunk.Block.WOOL_BLACK,
		"smooth_stone": Chunk.Block.SMOOTH_STONE,
		"smooth_stone_slab": Chunk.Block.SMOOTH_STONE_SLAB,
		"barrier": Chunk.Block.BARRIER,
		"poppy": Chunk.Block.POPPY, "dandelion": Chunk.Block.DANDELION,
		"torch": Chunk.Block.TORCH,
		"netherrack": Chunk.Block.NETHERRACK,
		"nether_gold_ore": Chunk.Block.NETHER_GOLD_ORE,
		"nether_quartz_ore": Chunk.Block.NETHER_QUARTZ_ORE,
		"crimson_nylium": Chunk.Block.CRIMSON_NYLIUM,
		"warped_nylium": Chunk.Block.WARPED_NYLIUM,
		"crimson_stem": Chunk.Block.CRIMSON_STEM,
		"warped_stem": Chunk.Block.WARPED_STEM,
		"nether_wart_block": Chunk.Block.NETHER_WART_BLOCK,
		"warped_wart_block": Chunk.Block.WARPED_WART_BLOCK,
		"red_mushroom": Chunk.Block.RED_MUSHROOM,
		"brown_mushroom": Chunk.Block.BROWN_MUSHROOM,
		"crimson_fungus": Chunk.Block.CRIMSON_FUNGUS,
		"warped_fungus": Chunk.Block.WARPED_FUNGUS,
		"furnace": Chunk.Block.FURNACE,
		"crafting_table": Chunk.Block.CRAFTING_TABLE,
		"sapling": Chunk.Block.SAPLING,
		# Items
		"coal": Items.COAL, "raw_iron": Items.RAW_IRON, "raw_gold": Items.RAW_GOLD,
		"diamond": Items.DIAMOND, "stick": Items.STICK, "flint": Items.FLINT,
		"leather": Items.LEATHER, "apple": Items.APPLE, "bread": Items.BREAD,
		"quartz": Items.QUARTZ, "oak_sapling": Items.OAK_SAPLING,
		"restore_orb": Items.RESTORE_ORB,
		"iron_ingot": Items.IRON_INGOT, "gold_ingot": Items.GOLD_INGOT,
		# Tools
		"wood_sword": Items.WOOD_SWORD, "wood_pickaxe": Items.WOOD_PICKAXE,
		"wood_axe": Items.WOOD_AXE, "wood_shovel": Items.WOOD_SHOVEL,
		"wood_hoe": Items.WOOD_HOE,
		"stone_sword": Items.STONE_SWORD, "stone_pickaxe": Items.STONE_PICKAXE,
		"stone_axe": Items.STONE_AXE, "stone_shovel": Items.STONE_SHOVEL,
		"stone_hoe": Items.STONE_HOE,
		"iron_sword": Items.IRON_SWORD, "iron_pickaxe": Items.IRON_PICKAXE,
		"iron_axe": Items.IRON_AXE, "iron_shovel": Items.IRON_SHOVEL,
		"iron_hoe": Items.IRON_HOE,
		"gold_sword": Items.GOLD_SWORD, "gold_pickaxe": Items.GOLD_PICKAXE,
		"gold_axe": Items.GOLD_AXE, "gold_shovel": Items.GOLD_SHOVEL,
		"gold_hoe": Items.GOLD_HOE,
		"diamond_sword": Items.DIAMOND_SWORD, "diamond_pickaxe": Items.DIAMOND_PICKAXE,
		"diamond_axe": Items.DIAMOND_AXE, "diamond_shovel": Items.DIAMOND_SHOVEL,
		"diamond_hoe": Items.DIAMOND_HOE,
		# Armor
		"leather_helmet": Items.LEATHER_HELMET,
		"leather_chestplate": Items.LEATHER_CHESTPLATE,
		"leather_leggings": Items.LEATHER_LEGGINGS,
		"leather_boots": Items.LEATHER_BOOTS,
		"iron_helmet": Items.IRON_HELMET,
		"iron_chestplate": Items.IRON_CHESTPLATE,
		"iron_leggings": Items.IRON_LEGGINGS,
		"iron_boots": Items.IRON_BOOTS,
		"gold_helmet": Items.GOLD_HELMET,
		"gold_chestplate": Items.GOLD_CHESTPLATE,
		"gold_leggings": Items.GOLD_LEGGINGS,
		"gold_boots": Items.GOLD_BOOTS,
		"diamond_helmet": Items.DIAMOND_HELMET,
		"diamond_chestplate": Items.DIAMOND_CHESTPLATE,
		"diamond_leggings": Items.DIAMOND_LEGGINGS,
		"diamond_boots": Items.DIAMOND_BOOTS,
	}
	return B


func add_message(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", MSG_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_container.add_child(lbl)
	_messages.append({"label": lbl, "time": MESSAGE_LIFETIME})
	# Cap visible messages.
	while _messages.size() > MAX_VISIBLE_MESSAGES:
		var old: Dictionary = _messages[0]
		(old["label"] as Label).queue_free()
		_messages.remove_at(0)


func is_chat_open() -> bool:
	return _open
