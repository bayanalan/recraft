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
# Each entry: { "label": Label, "time": float (time remaining before fade starts) }
var _messages: Array = []
var _font: Font = null


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
	# Enter opens the chat when closed.
	if event.keycode == KEY_ENTER and not _open:
		_open_chat()
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


func _open_chat() -> void:
	_open = true
	_input_line.visible = true
	_input_line.text = ""
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
	if not text.is_empty():
		add_message("<You> " + text)
	_close_chat()


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
