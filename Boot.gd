extends Control
## Boot — title, then Mode A level select (1 / 4 / 8). E remains warehouse.

const INK := Color("1C1C1C")
const BG := Color("F4E8D0")
const BLUE := Color("3B82F6")
const TEAL := Color("2A9D8F")
const GREEN := Color("22C55E")
const AMBER := Color("F59E0B")

const A_RECT := Rect2(110, 820, 860, 280)
const E_RECT := Rect2(260, 1180, 560, 140)
const BACK_RECT := Rect2(110, 1600, 860, 120)

const LV1_RECT := Rect2(110, 700, 860, 200)
const LV4_RECT := Rect2(110, 940, 860, 200)
const LV8_RECT := Rect2(110, 1180, 860, 200)

enum Screen { TITLE, SELECT }
var screen: Screen = Screen.TITLE
var _buttons: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bool(Engine.get_meta("a_open_select", false)):
		Engine.set_meta("a_open_select", false)
		screen = Screen.SELECT
	_rebuild()


func _clear_dynamic() -> void:
	for node in _buttons:
		if is_instance_valid(node):
			node.queue_free()
	_buttons.clear()


func _rebuild() -> void:
	_clear_dynamic()
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	if screen == Screen.TITLE:
		_build_title()
	else:
		_build_select()


func _build_title() -> void:
	_add_label("GROK BOT", 280.0, 400.0, 72, INK)
	_add_label("MULTIPLIER GATE RUNNER", 420.0, 470.0, 26, INK.darkened(0.2))
	_add_mode_button("A", BLUE, A_RECT, _open_select)
	_add_mode_button("E", TEAL, E_RECT, _open_e)


func _build_select() -> void:
	_add_label("SELECT LEVEL", 280.0, 400.0, 56, INK)
	_add_label("MODE A", 420.0, 480.0, 28, INK.darkened(0.2))
	_add_mode_button("1", BLUE, LV1_RECT, func() -> void: _open_a(0))
	_add_mode_button("4", GREEN, LV4_RECT, func() -> void: _open_a(1))
	_add_mode_button("8", AMBER, LV8_RECT, func() -> void: _open_a(2))
	_add_mode_button("BACK", INK.lightened(0.25), BACK_RECT, _back_to_title)


func _add_label(text: String, top: float, bottom: float, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = bottom
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _add_mode_button(letter: String, color: Color, rect: Rect2, cb: Callable) -> void:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.pressed.connect(cb)
	add_child(btn)
	_buttons.append(btn)

	var letter_l := Label.new()
	letter_l.text = letter
	letter_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_l.position = Vector2.ZERO
	letter_l.size = rect.size
	var font_size := 96
	if letter == "E" or letter == "BACK":
		font_size = 48
	elif letter.length() == 1 and letter.is_valid_int():
		font_size = 84
	letter_l.add_theme_font_size_override("font_size", font_size)
	letter_l.add_theme_color_override("font_color", Color.WHITE)
	letter_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(letter_l)


func _open_select() -> void:
	screen = Screen.SELECT
	_rebuild()


func _back_to_title() -> void:
	screen = Screen.TITLE
	_rebuild()


func _open_a(level_index: int) -> void:
	Engine.set_meta("a_level", level_index)
	get_tree().change_scene_to_file("res://ModeA.tscn")


func _open_e() -> void:
	Engine.set_meta("e_level", 0)
	Engine.set_meta("e_endless", false)
	get_tree().change_scene_to_file("res://ModeE.tscn")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_tap_at(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_tap_at(st.position)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if screen == Screen.TITLE:
			if event.keycode == KEY_A or event.keycode == KEY_1:
				_open_select()
			elif event.keycode == KEY_E or event.keycode == KEY_2:
				_open_e()
		elif screen == Screen.SELECT:
			if event.keycode == KEY_1:
				_open_a(0)
			elif event.keycode == KEY_4:
				_open_a(1)
			elif event.keycode == KEY_8:
				_open_a(2)
			elif event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
				_back_to_title()


func _tap_at(pos: Vector2) -> void:
	if screen == Screen.TITLE:
		if A_RECT.has_point(pos):
			_open_select()
		elif E_RECT.has_point(pos):
			_open_e()
	elif screen == Screen.SELECT:
		if LV1_RECT.has_point(pos):
			_open_a(0)
		elif LV4_RECT.has_point(pos):
			_open_a(1)
		elif LV8_RECT.has_point(pos):
			_open_a(2)
		elif BACK_RECT.has_point(pos):
			_back_to_title()
