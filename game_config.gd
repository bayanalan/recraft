class_name GameConfig

## Lightweight static-var bridge between the main menu scene and the game
## scene. The main menu sets these before calling change_scene_to_file;
## main.gd reads them on _ready to decide whether to generate or load.

enum StartMode { NEW_WORLD, LOAD_WORLD }

static var start_mode: int = StartMode.NEW_WORLD
static var world_size: int = 256
static var terrain_type: int = 1   # World.TerrainType.VANILLA_DEFAULT
static var world_seed: int = 0     # 0 = random
static var save_name: String = ""
static var world_name: String = "" # user-chosen name, used as default save name
