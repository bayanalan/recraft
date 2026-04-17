class_name ControlsConfig

# Rebindable action list. Each entry is [action_name: StringName, display: String].
# Order here is the order the Controls tab renders them in.
const ACTIONS: Array = [
	[&"move_forward",  "Forward"],
	[&"move_backward", "Backward"],
	[&"move_left",     "Left"],
	[&"move_right",    "Right"],
	[&"jump",          "Jump / Fly Up"],
	[&"descend",       "Fly Down"],
	[&"sprint",        "Sprint"],
]

const PATH: String = "user://controls.cfg"


## Load persisted key bindings (if any) and apply them to the live InputMap.
## Safe to call multiple times — later calls just re-apply.
static func load_into_inputmap() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		var key := str(action)
		if not cfg.has_section_key("keys", key):
			continue
		var code: int = int(cfg.get_value("keys", key, 0))
		if code == 0:
			# Explicitly saved as unbound.
			InputMap.action_erase_events(action)
		else:
			_set_raw(action, code)


## Write every rebindable action's current binding to disk.
static func save() -> void:
	var cfg := ConfigFile.new()
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		cfg.set_value("keys", str(action), get_action_physical_keycode(action))
	cfg.save(PATH)


## Bind `physical_keycode` to `action`. If another rebindable action was using
## the same key, that other action becomes unbound (no duplicate bindings).
static func set_action_key(action: StringName, physical_keycode: int) -> void:
	for entry: Array in ACTIONS:
		var other: StringName = entry[0]
		if other == action:
			continue
		if get_action_physical_keycode(other) == physical_keycode:
			InputMap.action_erase_events(other)
	_set_raw(action, physical_keycode)


## Return the first physical keycode bound to `action`, or 0 if unbound.
static func get_action_physical_keycode(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	var events: Array = InputMap.action_get_events(action)
	for ev: InputEvent in events:
		if ev is InputEventKey:
			var ek: InputEventKey = ev
			if ek.physical_keycode != 0:
				return ek.physical_keycode
			return ek.keycode
	return 0


## Human-readable label for a key ("W", "Shift", "Space", "Unbound", ...).
static func keycode_to_string(code: int) -> String:
	if code == 0:
		return "Unbound"
	return OS.get_keycode_string(code)


static func _set_raw(action: StringName, physical_keycode: int) -> void:
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, ev)
