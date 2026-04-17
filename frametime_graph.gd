extends Control

const GRAPH_MAX_MS: float = 33.3
const BAR_COLOR_GOOD := Color(0.2, 0.9, 0.2, 0.8)
const BAR_COLOR_WARN := Color(0.9, 0.9, 0.2, 0.8)
const BAR_COLOR_BAD := Color(0.9, 0.2, 0.2, 0.8)
const BG_COLOR := Color(0.0, 0.0, 0.0, 0.4)
const LINE_16MS := Color(1, 1, 1, 0.2)


func _draw() -> void:
	var overlay: Control = get_parent()
	var frame_times: PackedFloat32Array = overlay.frame_times
	var count: int = overlay.HISTORY_SIZE if overlay.filled else overlay.write_idx
	if count == 0:
		return

	var w: float = size.x
	var h: float = size.y

	# Background
	draw_rect(Rect2(0, 0, w, h), BG_COLOR)

	# 16.6ms line (60fps target)
	var y_16: float = h - (16.6 / GRAPH_MAX_MS) * h
	draw_line(Vector2(0, y_16), Vector2(w, y_16), LINE_16MS)

	# Bars
	var bar_w: float = w / float(overlay.HISTORY_SIZE)
	var start_idx: int = (overlay.write_idx - count + overlay.HISTORY_SIZE) % overlay.HISTORY_SIZE

	for i: int in count:
		var idx: int = (start_idx + i) % overlay.HISTORY_SIZE
		var ms: float = frame_times[idx]
		var bar_h: float = clampf(ms / GRAPH_MAX_MS, 0.0, 1.0) * h

		var color: Color
		if ms < 16.7:
			color = BAR_COLOR_GOOD
		elif ms < 25.0:
			color = BAR_COLOR_WARN
		else:
			color = BAR_COLOR_BAD

		var x: float = float(i) * bar_w
		draw_rect(Rect2(x, h - bar_h, maxf(bar_w - 0.5, 1.0), bar_h), color)
