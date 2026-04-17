class_name SaveSystem

const SAVE_DIR: String = "user://saves/"
const MAGIC: String = "RCFT"
# v2 adds world seed after player_pos.
# v3 adds terrain_type (int32) after seed so the loader can take the
# flatgrass shared-mesh fast path without guessing from voxels.
const VERSION: int = 3

# Default terrain type when loading pre-v3 saves (before this field existed).
const LEGACY_TERRAIN_TYPE: int = 1  # World.TerrainType.VANILLA_DEFAULT


static func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# Returns array of save info dictionaries, sorted newest-first
static func list_saves() -> Array:
	ensure_dir()
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var fname: String = dir.get_next()
		if fname == "":
			break
		if dir.current_is_dir():
			continue
		if fname.ends_with(".save"):
			var info: Dictionary = read_header(fname.get_basename())
			if not info.is_empty():
				result.append(info)
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["timestamp"]) > int(b["timestamp"]))
	return result


static func read_header(save_name: String) -> Dictionary:
	var path: String = SAVE_DIR + save_name + ".save"
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var magic: String = f.get_buffer(4).get_string_from_ascii()
	if magic != MAGIC:
		f.close()
		return {}
	var version: int = f.get_32()
	var size: int = f.get_32()
	var timestamp: int = f.get_64()
	f.close()
	return {
		"name": save_name,
		"version": version,
		"size": size,
		"timestamp": timestamp,
	}


static func save_world(save_name: String, world_size: int, voxels: PackedByteArray, player_pos: Vector3, world_seed: int = 0, terrain_type: int = LEGACY_TERRAIN_TYPE) -> bool:
	ensure_dir()
	var path: String = SAVE_DIR + save_name + ".save"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_32(VERSION)
	f.store_32(world_size)
	f.store_64(Time.get_unix_time_from_system())
	f.store_float(player_pos.x)
	f.store_float(player_pos.y)
	f.store_float(player_pos.z)
	f.store_64(world_seed)
	f.store_32(terrain_type)
	f.store_buffer(voxels)
	f.close()
	return true


static func load_world(save_name: String) -> Dictionary:
	var path: String = SAVE_DIR + save_name + ".save"
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var magic: String = f.get_buffer(4).get_string_from_ascii()
	if magic != MAGIC:
		f.close()
		return {}
	var version: int = f.get_32()
	var size: int = f.get_32()
	var timestamp: int = f.get_64()
	var px: float = f.get_float()
	var py: float = f.get_float()
	var pz: float = f.get_float()
	var seed: int = 0
	if version >= 2:
		seed = f.get_64()
	var terrain_type: int = LEGACY_TERRAIN_TYPE
	if version >= 3:
		terrain_type = f.get_32()
	var expected: int = size * size * size
	var voxels: PackedByteArray = f.get_buffer(expected)
	f.close()
	return {
		"name": save_name,
		"version": version,
		"size": size,
		"timestamp": timestamp,
		"player_pos": Vector3(px, py, pz),
		"seed": seed,
		"terrain_type": terrain_type,
		"voxels": voxels,
	}


static func delete_save(save_name: String) -> bool:
	var path: String = SAVE_DIR + save_name + ".save"
	if FileAccess.file_exists(path):
		var err: int = DirAccess.remove_absolute(path)
		return err == OK
	return false


# Sanitize a user-entered save name: keep alphanumerics, underscores, spaces, hyphens
static func sanitize_name(input: String) -> String:
	var result: String = ""
	for i: int in input.length():
		var c: String = input[i]
		var code: int = c.unicode_at(0)
		var is_alnum: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if is_alnum or c == "_" or c == "-" or c == " ":
			result += c
	return result.strip_edges()


static func format_timestamp(ts: int) -> String:
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]
