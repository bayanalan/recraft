class_name SettingsConfig

# Persistence layer for general settings (everything except key bindings,
# which live in controls_config.gd). Written as a single [general] section
# in user://settings.cfg so all options are loaded at startup and any change
# reaches disk immediately.

const PATH: String = "user://settings.cfg"
const SECTION: String = "general"


static func save_all(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for key: String in data:
		cfg.set_value(SECTION, key, data[key])
	cfg.save(PATH)


static func load_all() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {}
	var result: Dictionary = {}
	if not cfg.has_section(SECTION):
		return result
	for key: String in cfg.get_section_keys(SECTION):
		result[key] = cfg.get_value(SECTION, key)
	return result
