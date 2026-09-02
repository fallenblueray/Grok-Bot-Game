extends Control
## Boot — E is the game. D is a corpse (KEY_D still opens it).

const INK := Color("1C1C1C")
const BG := Color("F4E8D0")
const CORAL := Color("E85D4C")
const TEAL := Color("2A9D8F")
const MUSTARD := Color("E9C46A")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "GROK BOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 280.0
	title.offset_bottom = 400.0
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", INK)
	add_child(title)

	_add_mode_button(
		"E",
		TEAL,
		Rect2(110, 820, 860, 320),
		_open_e
	)


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

	var letter_l := Label.new()
	letter_l.text = letter
	letter_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_l.position = Vector2.ZERO
	letter_l.size = rect.size
	letter_l.add_theme_font_size_override("font_size", 96)
	letter_l.add_theme_color_override("font_color", Color.WHITE)
	letter_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(letter_l)


func _open_d() -> void:
	get_tree().change_scene_to_file("res://ModeD.tscn")


func _open_e() -> void:
	Engine.set_meta("e_level", 0)
	Engine.set_meta("e_endless", false)
	get_tree().change_scene_to_file("res://ModeE.tscn")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
			return
		_tap_at(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_tap_at(st.position)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D or event.keycode == KEY_1:
			_open_d()
		elif event.keycode == KEY_E or event.keycode == KEY_2:
			_open_e()


func _tap_at(pos: Vector2) -> void:
	if Rect2(110, 820, 860, 320).has_point(pos):
		_open_e()
