extends Control
## Mode A: portrait multiplier-gate runner.

const VIEW_SIZE := Vector2(1080.0, 1920.0)
const TRACK_LEFT := 70.0
const TRACK_RIGHT := 1010.0
const PLAYER_Y := 1480.0
const SCROLL_SPEED := 360.0
const KEYBOARD_SPEED := 820.0
const FIRST_EVENT_Y := -280.0
const EVENT_SPACING := 480.0
const TRACK_MID := 540.0
const TRACK_WIDTH := TRACK_RIGHT - TRACK_LEFT
## Art ref: track visual width 280 → scale into 1080 scene.
const SKIN_REF_TRACK := 280.0
const SKIN_SCALE := TRACK_WIDTH / SKIN_REF_TRACK
const BEAN_DIAMETER := 14.0 * SKIN_SCALE
const GATE_BOX := Vector2(120.0, 56.0) * SKIN_SCALE
const GATE_STROKE := 8.0 * SKIN_SCALE
const GATE_STROKE_RED_EXTRA := 4.0 * SKIN_SCALE
const GATE_FAKE_NOTCH := 16.0 * SKIN_SCALE
const SAW_DIAMETER := 72.0 * SKIN_SCALE
const WALL_BOX := Vector2(280.0, 40.0) * SKIN_SCALE
const SKIN_DEPTH := {"bean": 8.0, "gate": 12.0, "saw": 8.0, "wall": 20.0}
## Reserved mesh slots (null = color-block fallback). Same AABB as draw boxes.
var skin_meshes := {
	"bean_blue": null,
	"bean_red": null,
	"gate_green": null,
	"gate_red": null,
	"gate_fake": null,
	"saw": null,
	"wall": null,
}

const TRACK := Color("E8EEF5")
const INK := Color("1C1C1C")
const BLUE := Color("3B82F6")
const GREEN := Color("22C55E")
const RED := Color("EF4444")
const YELLOW := Color("F59E0B")
const PALE_GREEN := Color("DCFCE7")
const PALE_RED := Color("FEE2E7")
const WHITE := Color("FFFFFF")

const LEVEL_NUMBERS := [1, 4, 8]

var level_index := 0
var level_number := 1
var count: int = 5
var player_x := 540.0
var obstacles: Array[Dictionary] = []
var dragging := false
var left_held := false
var right_held := false
var ended := false
var won := false
var fail_reason := ""
var end_overlay: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	level_index = clampi(int(Engine.get_meta("a_level", 0)), 0, LEVEL_NUMBERS.size() - 1)
	level_number = LEVEL_NUMBERS[level_index]
	_build_level(level_number)
	queue_redraw()


func _process(delta: float) -> void:
	if ended:
		return
	var keyboard_axis := float(int(right_held) - int(left_held))
	if keyboard_axis != 0.0:
		player_x += keyboard_axis * KEYBOARD_SPEED * delta
	player_x = clampf(player_x, TRACK_LEFT + 70.0, TRACK_RIGHT - 70.0)
	for obstacle in obstacles:
		if bool(obstacle["triggered"]):
			continue
		obstacle["y"] = float(obstacle["y"]) + SCROLL_SPEED * delta
		if float(obstacle["y"]) >= PLAYER_Y:
			obstacle["triggered"] = true
			_trigger_obstacle(obstacle)
			if ended:
				break
	queue_redraw()


func _build_level(number: int) -> void:
	var start_count := 5
	var sequence: Array[Dictionary] = []
	match number:
		1:
			start_count = 5
			sequence = [_gate("+", 5), _gate("*", 2), _saw(3), _gate("+", 10), _wall(20)]
		4:
			start_count = 8
			sequence = [
				_gate("*", 2),
				_fork(_gate("-", 10, RED), _gate("+", 15, GREEN)),
				_tide(12),
				_gate("*", 3),
				_saw(5),
				_wall(50),
			]
		8:
			start_count = 10
			sequence = [
				_gate("+", 20),
				_fork(_gate("*", 3, GREEN), _fake()),
				_saw(5),
				_saw(5),
				_tide(25),
				_gate("*", 2),
				_gate("+", 30),
				_wall(120),
			]
	count = start_count
	_reset_end_state()
	obstacles.clear()
	for i in sequence.size():
		var obstacle: Dictionary = sequence[i].duplicate(true)
		obstacle["y"] = FIRST_EVENT_Y - float(i) * EVENT_SPACING
		obstacle["triggered"] = false
		obstacles.append(obstacle)


func _reset_end_state() -> void:
	ended = false
	won = false
	fail_reason = ""
	if end_overlay != null and is_instance_valid(end_overlay):
		end_overlay.queue_free()
	end_overlay = null


func _gate(op: String, value: int, tint: Color = GREEN) -> Dictionary:
	return {"kind": "gate", "op": op, "value": value, "gate_color": tint}


func _fake() -> Dictionary:
	return {"kind": "fake", "label": "x5", "effect": -20, "gate_color": RED}


func _fork(left: Dictionary, right: Dictionary) -> Dictionary:
	return {"kind": "fork", "left": left, "right": right}


func _saw(value: int) -> Dictionary:
	return {"kind": "saw", "value": value}


func _tide(value: int) -> Dictionary:
	return {"kind": "tide", "value": value}


func _wall(required: int) -> Dictionary:
	return {"kind": "wall", "required": required}


func _trigger_obstacle(obstacle: Dictionary) -> void:
	var kind := str(obstacle["kind"])
	if kind == "fork":
		var left: Dictionary = obstacle["left"]
		var right: Dictionary = obstacle["right"]
		# Split the track: left half = left gate, right half = right gate (always pick one).
		if player_x < TRACK_MID:
			_apply_effect(left)
		else:
			_apply_effect(right)
		_check_wiped("WIPED")
		return
	if kind == "wall":
		var need := int(obstacle["required"])
		if count > need:
			_finish(true, "")
		else:
			_finish(false, "WALL %d  HAVE %d" % [need, count])
		return
	_apply_effect(obstacle)
	_check_wiped("WIPED")


func _apply_effect(effect: Dictionary) -> void:
	var kind := str(effect["kind"])
	if kind == "fake":
		count += int(effect["effect"])
	elif kind == "saw" or kind == "tide":
		count -= int(effect["value"])
	elif kind == "gate":
		var value := maxi(1, int(effect["value"]))
		var op := str(effect["op"])
		match op:
			"+":
				count += value
			"-":
				count -= value
			"*":
				count *= value
			"/":
				count = int(floor(float(count) / float(value)))
	count = clampi(count, 0, 150)


func _check_wiped(reason: String) -> void:
	if count <= 0:
		count = 0
		_finish(false, reason)


func _finish(success: bool, reason: String) -> void:
	if ended:
		return
	ended = true
	won = success
	fail_reason = reason
	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.05, 0.07, 0.11, 0.88)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.gui_input.connect(_on_overlay_gui_input)
	add_child(end_overlay)

	var result := Label.new()
	var body := "WIN" if success else "FAIL"
	if not success and reason != "":
		body += "\n" + reason
	if not success:
		body += "\n\nTAP"
	result.text = body
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if success:
		result.offset_bottom = -280.0
	result.add_theme_font_size_override("font_size", 72)
	result.add_theme_color_override("font_color", GREEN if success else RED)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_overlay.add_child(result)

	if success:
		_add_end_button("NEXT", GREEN, Rect2(110, 1180, 860, 180), _goto_next)
		_add_end_button("MENU", Color("3B82F6"), Rect2(110, 1400, 860, 160), _goto_menu)
	queue_redraw()


func _add_end_button(letter: String, color: Color, rect: Rect2, cb: Callable) -> void:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.pressed.connect(cb)
	end_overlay.add_child(btn)
	var letter_l := Label.new()
	letter_l.text = letter
	letter_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_l.position = Vector2.ZERO
	letter_l.size = rect.size
	letter_l.add_theme_font_size_override("font_size", 56)
	letter_l.add_theme_color_override("font_color", Color.WHITE)
	letter_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(letter_l)


func _on_overlay_gui_input(event: InputEvent) -> void:
	# FAIL: whole overlay TAP restarts. WIN: only NEXT / MENU buttons.
	if ended and not won and _pressed_event(event):
		_restart_same()


func _restart_same() -> void:
	Engine.set_meta("a_level", level_index)
	get_tree().reload_current_scene()


func _goto_next() -> void:
	if level_index >= LEVEL_NUMBERS.size() - 1:
		_goto_menu()
		return
	Engine.set_meta("a_level", level_index + 1)
	get_tree().reload_current_scene()


func _goto_menu() -> void:
	Engine.set_meta("a_open_select", true)
	get_tree().change_scene_to_file("res://Boot.tscn")


func _input(event: InputEvent) -> void:
	if ended:
		if not won and _pressed_event(event):
			get_viewport().set_input_as_handled()
			_restart_same()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_LEFT or key.keycode == KEY_A:
			left_held = key.pressed
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			right_held = key.pressed
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse_button.pressed
		return
	if event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		player_x = clampf(player_x + motion.relative.x, TRACK_LEFT + 70.0, TRACK_RIGHT - 70.0)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		dragging = touch.pressed
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if dragging:
			player_x = clampf(player_x + drag.relative.x, TRACK_LEFT + 70.0, TRACK_RIGHT - 70.0)


func _pressed_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_SPACE]
	return false


func _draw_outlined_string(font: Font, pos: Vector2, text: String, width: float, size: int, fill: Color, outline: Color = INK, outline_px: float = 4.0) -> void:
	for ox in [-1.0, 0.0, 1.0]:
		for oy in [-1.0, 0.0, 1.0]:
			if ox == 0.0 and oy == 0.0:
				continue
			draw_string(font, pos + Vector2(ox, oy) * outline_px, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, outline)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, fill)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), TRACK)
	draw_rect(Rect2(TRACK_LEFT, 0.0, 8.0, VIEW_SIZE.y), INK)
	draw_rect(Rect2(TRACK_RIGHT - 8.0, 0.0, 8.0, VIEW_SIZE.y), INK)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(90.0, 105.0), "MODE A   LV" + str(level_number), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 38, INK)
	draw_string(font, Vector2(90.0, 155.0), "DRAG LEFT / RIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, INK.darkened(0.15))
	for obstacle in obstacles:
		_draw_obstacle(obstacle)
	_draw_swarm(font)


func _draw_swarm(font: Font) -> void:
	var draw_count := mini(count, 150)
	if draw_count > 0:
		var cols := mini(10, draw_count)
		var rows := int(ceil(float(draw_count) / float(cols)))
		var spacing := BEAN_DIAMETER * 1.2
		for i in draw_count:
			var row := i / cols
			var col := i % cols
			var px := player_x + (float(col) - float(cols - 1) * 0.5) * spacing
			var py := PLAYER_Y + (float(row) - float(rows - 1) * 0.5) * spacing
			var bean_r := BEAN_DIAMETER * 0.5
			draw_circle(Vector2(px, py), bean_r, BLUE)
	_draw_outlined_string(font, Vector2(player_x - 150.0, PLAYER_Y - 130.0), str(count), 300.0, 82, WHITE)


func _draw_obstacle(obstacle: Dictionary) -> void:
	var y := float(obstacle["y"])
	var kind := str(obstacle["kind"])
	if kind == "fork":
		var left_x := TRACK_LEFT + GATE_BOX.x * 0.5 + 24.0
		var right_x := TRACK_RIGHT - GATE_BOX.x * 0.5 - 24.0
		_draw_gate(obstacle["left"], left_x, y)
		_draw_gate(obstacle["right"], right_x, y)
		# Midline hint for which side counts.
		var mid_h := GATE_BOX.y * 0.5 + 24.0
		draw_line(Vector2(TRACK_MID, y - mid_h), Vector2(TRACK_MID, y + mid_h), Color(INK, 0.35), 4.0)
	elif kind == "gate" or kind == "fake":
		_draw_gate(obstacle, TRACK_MID, y)
	elif kind == "saw":
		_draw_saw(Vector2(TRACK_MID, y), int(obstacle["value"]))
	elif kind == "tide":
		_draw_tide(y, int(obstacle["value"]))
	elif kind == "wall":
		_draw_wall(y, int(obstacle["required"]))


## Color-block fallback until skin_meshes[id] is filled with a Mesh/Texture.
func _skin_ready(slot: String) -> bool:
	return skin_meshes.has(slot) and skin_meshes[slot] != null


func _draw_gate(gate: Dictionary, center_x: float, y: float) -> void:
	var rect := Rect2(center_x - GATE_BOX.x * 0.5, y - GATE_BOX.y * 0.5, GATE_BOX.x, GATE_BOX.y)
	var tint: Color = gate["gate_color"]
	var is_fake := str(gate["kind"]) == "fake"
	var is_red := tint == RED or is_fake
	var label := str(gate["label"]) if is_fake else (str(gate["op"]) + str(gate["value"]))
	var stroke := GATE_STROKE + (GATE_STROKE_RED_EXTRA if is_red else 0.0)
	# Slot: gate_fake / gate_red / gate_green — mesh reserved, color-block for now.
	draw_rect(rect, PALE_RED if is_red else PALE_GREEN, true)
	draw_rect(rect, tint, false, stroke)
	if is_fake:
		var n := GATE_FAKE_NOTCH
		var notch := PackedVector2Array([
			rect.position + Vector2(rect.size.x - n, 0.0),
			rect.position + Vector2(rect.size.x, 0.0),
			rect.position + Vector2(rect.size.x, n),
		])
		draw_colored_polygon(notch, TRACK)
		draw_line(rect.position + Vector2(rect.size.x - n, 0.0), rect.position + Vector2(rect.size.x, n), tint, stroke)
	var font := ThemeDB.fallback_font
	_draw_outlined_string(font, Vector2(rect.position.x, y + GATE_BOX.y * 0.18), label, rect.size.x, 64, WHITE, INK, 5.0)


func _draw_saw(center: Vector2, value: int) -> void:
	var outer := SAW_DIAMETER * 0.5
	var inner := outer * 0.62
	var tooth := outer * 0.18
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		var side := Vector2(-direction.y, direction.x)
		var points := PackedVector2Array([
			center + direction * outer,
			center + side * tooth + direction * inner,
			center - side * tooth + direction * inner,
		])
		draw_colored_polygon(points, INK)
	draw_circle(center, inner, RED)
	draw_arc(center, inner, 0.0, TAU, 40, INK, 8.0)
	_draw_outlined_string(ThemeDB.fallback_font, Vector2(center.x - 100.0, center.y + 18.0), "-" + str(value), 200.0, 44, WHITE, INK, 4.0)


func _draw_tide(y: float, value: int) -> void:
	var h := maxf(BEAN_DIAMETER * 2.2, 84.0)
	draw_rect(Rect2(TRACK_LEFT, y - h * 0.5, TRACK_WIDTH, h), RED)
	draw_rect(Rect2(TRACK_LEFT, y - h * 0.5, TRACK_WIDTH, h), INK, false, 8.0)
	# bean_red slot reserved for tide dots later; band is the trigger stand-in.
	_draw_outlined_string(ThemeDB.fallback_font, Vector2(TRACK_LEFT, y + 16.0), "RED TIDE -" + str(value), TRACK_WIDTH, 36, WHITE, INK, 4.0)


func _draw_wall(y: float, required: int) -> void:
	var wall_h := WALL_BOX.y
	var wall_w := TRACK_WIDTH  # table 280 maps to full track via SKIN_SCALE
	draw_rect(Rect2(TRACK_LEFT, y - wall_h * 0.5, wall_w, wall_h), INK)
	draw_rect(Rect2(TRACK_LEFT + 12.0, y - wall_h * 0.5 + 8.0, wall_w - 24.0, wall_h - 16.0), Color("374151"))
	_draw_outlined_string(ThemeDB.fallback_font, Vector2(TRACK_LEFT, y + wall_h * 0.15), "WALL  " + str(required), wall_w, 80, YELLOW, INK, 6.0)
