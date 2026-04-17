extends Control

const GRAPH_WIDTH: int = 200
const GRAPH_HEIGHT: int = 40
const GRAPH_MAX_MS: float = 33.3  # cap at ~30fps for graph scale
const HISTORY_SIZE: int = 200

# Only redraw the graph / update the label periodically.
# At 1500 fps, updating every frame would push ~300k draw_rect calls per second
# and force string formatting for the label — both significant on the main thread.
const REDRAW_INTERVAL: float = 0.1  # ~10 Hz is plenty for a readable FPS display

var frame_times: PackedFloat32Array
var write_idx: int = 0
var filled: bool = false

var _accum_time: float = 0.0
var _last_fps_shown: int = -1
var _last_low_shown: int = -1

@onready var fps_label: Label = $FPSLabel
@onready var graph: Control = $Graph


func _ready() -> void:
	frame_times.resize(HISTORY_SIZE)
	frame_times.fill(0.0)
	visible = false  # hidden until F3
	var font: Font = load("res://fonts/font.ttf")
	if font != null:
		fps_label.add_theme_font_override("font", font)
	fps_label.add_theme_font_size_override("font_size", PauseMenu._fs(22))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Always sample the frame time (cheap: one array write)
	frame_times[write_idx] = delta * 1000.0
	write_idx = (write_idx + 1) % HISTORY_SIZE
	if write_idx == 0:
		filled = true

	_accum_time += delta
	if _accum_time < REDRAW_INTERVAL:
		return
	_accum_time = 0.0

	# Relabel only when FPS or 1% low changes — avoids per-tick string
	# formatting when nothing meaningful moved.
	var fps: int = int(Engine.get_frames_per_second())
	var low_1pct: int = _compute_1pct_low_fps()
	if fps != _last_fps_shown or low_1pct != _last_low_shown:
		_last_fps_shown = fps
		_last_low_shown = low_1pct
		fps_label.text = "%d FPS  %d 1%% low  %.1f ms" % [fps, low_1pct, delta * 1000.0]
	graph.queue_redraw()


## Return the 1% low FPS derived from the frame-time history. Takes the
## slowest 1% of samples (average of their frame times) and converts to FPS.
## Falls back gracefully while the ring buffer is still filling.
func _compute_1pct_low_fps() -> int:
	var n: int = HISTORY_SIZE if filled else write_idx
	if n == 0:
		return 0
	var samples: PackedFloat32Array = frame_times.slice(0, n)
	samples.sort()  # ascending — slowest frames at the end
	var low_count: int = maxi(1, n / 100)
	var sum_ms: float = 0.0
	for i: int in range(n - low_count, n):
		sum_ms += samples[i]
	var avg_ms: float = sum_ms / float(low_count)
	if avg_ms <= 0.0:
		return 0
	return int(1000.0 / avg_ms)
