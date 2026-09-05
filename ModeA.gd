extends Control
## Mode A — multiplier gate runner prototype.
## A portrait top-down runner: the track scrolls, while the swarm slides horizontally.

const VIEW_SIZE := Vector2(1080.0, 1920.0)
const TRACK_RECT := Rect2(72.0, 0.0, 936.0, 1920.0)
const PLAYER_Y := 1510.0
const EVENT_START_Y := -220.0
const EVENT_SPACING := 390.0
const SCROLL_SPEED := 430.0
const PLAYER_SLIDE_SPEED := 1500.0
const POP_CAP := 150

const INK := Color("1C1C1C")
const TRACK := Color("E8EEF5")
const BLUE := Color("3B82F6")
const GREEN := Color("22C55E")
const RED := Color("EF4444")
const YELLOW := Color("F59E0B")
const TIDE := Color("8B5CF6")

var levels: Dictionary = {
	1: {
		"start": 5,
		"wall": 20,
		"events": [
			{"kind": "gate", "op": "add", "value": 5},
			{"kind": "gate", "op": "mul", "value": 2},
			{"kind": "saw", "value": 3},
			{"kind": "gate", "op": "add", "value": 10}
		]
	},
	4: {
		"start": 8,
		"wall": 60,
		"events": [
			{"kind": "gate", "op": "mul", "value": 2},
			{"kind": "choice", "left": {"op": "sub", "value": 10}, "right": {"op": "add", "value": 15}},
			{"kind": "tide", "value": 12},
			{"kind": "gate", "op": "mul", "value": 3},
			{"kind": "saw", "value": 5}
		]
	},
	8: {
		"start": 10,
		"wall": 120,
		"events": [
			{"kind": "gate", "op": "add", "value": 20},
			{"kind": "choice", "left": {"op": "mul", "value": 3}, "right": {"op": "sub", "value": 20, "display": "x5", "fake": true}},
			{"kind": "saw", "value": 5},
			{"kind": "saw", "value": 5},
			{"kind": "tide", "value": 25},
			{"kind": "gate", "op": "mul", "value": 2},
			{"kind": "gate", "op": "add", "value": 30}
		]
	}
}

var level_order: Array[int] = [1, 4, 8]
var level_index := 0
var level_number := 1
var population := 5
var wall_count := 20
var events: Array = []
var resolved: Array[bool] = []
var scroll := 0.0
var swarm_x := 540.0
var target_x := 540.0
var dragging := false
var wall_resolved := false
enum RunState { RUNNING, FAILED, CLEARED }
var state: RunState = RunState.RUNNING
var hud: Label
var sub_hud: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	_start_level(level_number)
	queue_redraw()


func _build_hud() -> void:
	hud = Label.new()
	hud.position = Vector2(0.0, 48.0)
	hud.size = Vector2(VIEW_SIZE.x, 118.0)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_theme_font_size_override("font_size", 92)
	hud.add_theme_color_override("font_color", INK)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.z_index = 10
	add_child(hud)

	sub_hud = Label.new()
	sub_hud.position = Vector2(0.0, 160.0)
	sub_hud.size = Vector2(VIEW_SIZE.x, 52.0)
	sub_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_hud.add_theme_font_size_override("font_size", 27)
	sub_hud.add_theme_color_override("font_color", INK.darkened(0.2))
	sub_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_hud.z_index = 10
	add_child(sub_hud)


func _start_level(number: int) -> void:
	level_number = number
	var data: Dictionary = levels[level_number]
	population = int(data["start"])
	wall_count = int(data["wall"])
	events = data["events"]
	resolved.clear()
	for _event in events:
		resolved.append(false)
	scroll = 0.0
	swarm_x = VIEW_SIZE.x * 0.5
	target_x = swarm_x
	wall_resolved = false
	state = RunState.RUNNING
	_update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if state == RunState.RUNNING:
		scroll += SCROLL_SPEED * delta
		swarm_x = move_toward(swarm_x, target_x, PLAYER_SLIDE_SPEED * delta)
		_check_crossings()
	_update_hud()
	queue_redraw()


func _check_crossings() -> void:
	for index in range(events.size()):
		if not resolved[index] and _event_y(index) >= PLAYER_Y - 4.0:
			_resolve_event(index)
	if not wall_resolved and _wall_y() >= PLAYER_Y:
		_resolve_wall()


func _event_y(index: int) -> float:
	return EVENT_START_Y + float(index + 1) * EVENT_SPACING - scroll


func _wall_y() -> float:
	return EVENT_START_Y + float(events.size() + 1) * EVENT_SPACING - scroll


func _resolve_event(index: int) -> void:
	resolved[index] = true
	var event: Dictionary = events[index]
	var kind := String(event.get("kind", "gate"))
	if kind == "gate":
		_apply_gate(event)
	elif kind == "choice":
		var option: Dictionary = event["left"] if swarm_x < VIEW_SIZE.x * 0.5 else event["right"]
		_apply_gate(option)
	elif kind == "saw":
		population = _capped_population(population - int(event["value"]))
	elif kind == "tide":
		population = _capped_population(population - int(event["value"]))
	if population <= 0:
		state = RunState.FAILED


func _apply_gate(gate: Dictionary) -> void:
	var op := String(gate.get("op", "add"))
	var value := int(gate.get("value", 0))
	match op:
		"add":
			population += value
		"sub":
			population -= value
		"mul":
			population *= value
		"div":
			population = int(floor(float(population) / float(maxi(value, 1))))
	population = _capped_population(population)


func _capped_population(value: int) -> int:
	return clampi(value, 0, POP_CAP)


func _resolve_wall() -> void:
	wall_resolved = true
	if population > wall_count:
		state = RunState.CLEARED
	else:
		state = RunState.FAILED


func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	hud.text = str(population)
	var progress := "LEVEL %d   /   WALL %d" % [level_number, wall_count]
	if state == RunState.RUNNING:
		sub_hud.text = progress + "   •   DRAG TO SLIDE"
	elif state == RunState.CLEARED:
		sub_hud.text = progress + "   •   CLEAR"
	else:
		sub_hud.text = progress + "   •   FAILED"


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				dragging = true
				if state == RunState.RUNNING:
					_set_target_x(mouse.position.x)
			else:
				dragging = false
				if state != RunState.RUNNING:
					_overlay_tap()
	elif event is InputEventMouseMotion and dragging and state == RunState.RUNNING:
		_set_target_x((event as InputEventMouseMotion).position.x)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			dragging = true
			if state == RunState.RUNNING:
				_set_target_x(touch.position.x)
		else:
			dragging = false
			if state != RunState.RUNNING:
				_overlay_tap()
	elif event is InputEventScreenDrag and dragging and state == RunState.RUNNING:
		_set_target_x((event as InputEventScreenDrag).position.x)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER):
			if state != RunState.RUNNING:
				_overlay_tap()


func _set_target_x(value: float) -> void:
	target_x = clampf(value, TRACK_RECT.position.x + 56.0, TRACK_RECT.end.x - 56.0)


func _overlay_tap() -> void:
	if state == RunState.FAILED:
		_start_level(level_number)
	elif state == RunState.CLEARED:
		if level_index + 1 < level_order.size():
			level_index += 1
			_start_level(level_order[level_index])
		else:
			_start_level(level_number)


func _draw() -> void:
	# Track and a quiet top margin for the HUD.
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("F7FAFC"))
	draw_rect(TRACK_RECT, TRACK)
	draw_line(Vector2(TRACK_RECT.position.x, 0.0), Vector2(TRACK_RECT.position.x, VIEW_SIZE.y), INK.lightened(0.45), 5.0)
	draw_line(Vector2(TRACK_RECT.end.x, 0.0), Vector2(TRACK_RECT.end.x, VIEW_SIZE.y), INK.lightened(0.45), 5.0)

	for index in range(events.size()):
		var y := _event_y(index)
		if y > -180.0 and y < VIEW_SIZE.y + 180.0:
			_draw_event(events[index], y, resolved[index])
	var wall_y := _wall_y()
	if wall_y > -120.0 and wall_y < VIEW_SIZE.y + 180.0:
		_draw_wall(wall_y)

	_draw_swarm()
	if state != RunState.RUNNING:
		_draw_overlay()


func _draw_event(event: Dictionary, y: float, already_hit: bool) -> void:
	var kind := String(event.get("kind", "gate"))
	if kind == "saw":
		_draw_saw(y, int(event["value"]), already_hit)
	elif kind == "tide":
		_draw_tide(y, int(event["value"]), already_hit)
	elif kind == "choice":
		_draw_choice(event, y, already_hit)
	else:
		_draw_gate(event, y, already_hit)


func _draw_gate(gate: Dictionary, y: float, already_hit: bool) -> void:
	var rect := Rect2(TRACK_RECT.position.x + 18.0, y - 48.0, TRACK_RECT.size.x - 36.0, 96.0)
	var color := _gate_color(gate)
	var fill := color.darkened(0.08) if not already_hit else color.darkened(0.45)
	draw_rect(rect, fill)
	draw_rect(rect, color, false, 10.0)
	_draw_centered(_gate_text(gate), y + 20.0, 52, Color.WHITE)


func _draw_choice(event: Dictionary, y: float, already_hit: bool) -> void:
	var left := Rect2(TRACK_RECT.position.x + 18.0, y - 48.0, TRACK_RECT.size.x * 0.5 - 24.0, 96.0)
	var right := Rect2(TRACK_RECT.position.x + TRACK_RECT.size.x * 0.5 + 6.0, y - 48.0, TRACK_RECT.size.x * 0.5 - 24.0, 96.0)
	var left_gate: Dictionary = event["left"]
	var right_gate: Dictionary = event["right"]
	var left_color := _gate_color(left_gate)
	var right_color := _gate_color(right_gate)
	if already_hit:
		left_color = left_color.darkened(0.45)
		right_color = right_color.darkened(0.45)
	draw_rect(left, left_color)
	draw_rect(right, right_color)
	draw_rect(left, left_color, false, 9.0)
	draw_rect(right, right_color, false, 9.0)
	_draw_centered_in_rect(_gate_text(left_gate), left, 42, Color.WHITE)
	_draw_centered_in_rect(_gate_text(right_gate), right, 42, Color.WHITE)
	if bool(right_gate.get("fake", false)):
		# The fake gate keeps its bright red frame and a triangular notch.
		draw_rect(right.grow(5.0), RED, false, 10.0)
		var notch := PackedVector2Array([Vector2(right.end.x - 30.0, right.position.y - 5.0), Vector2(right.end.x + 5.0, right.position.y - 5.0), Vector2(right.end.x + 5.0, right.position.y + 30.0)])
		draw_colored_polygon(notch, RED)
	_draw_centered("CHOOSE", y - 61.0, 24, INK)


func _draw_saw(y: float, damage: int, already_hit: bool) -> void:
	var rect := Rect2(TRACK_RECT.position.x + 10.0, y - 30.0, TRACK_RECT.size.x - 20.0, 60.0)
	var color := YELLOW.darkened(0.32) if not already_hit else YELLOW.darkened(0.6)
	draw_rect(rect, color)
	var teeth := 15
	for i in range(teeth):
		var x := rect.position.x + float(i) * rect.size.x / float(teeth)
		var points := PackedVector2Array([Vector2(x, rect.position.y), Vector2(x + rect.size.x / float(teeth) * 0.5, rect.end.y), Vector2(x + rect.size.x / float(teeth), rect.position.y)])
		draw_colored_polygon(points, INK)
	_draw_centered("SAW  −%d" % damage, y + 11.0, 28, Color.WHITE)


func _draw_tide(y: float, amount: int, already_hit: bool) -> void:
	var rect := Rect2(TRACK_RECT.position.x + 10.0, y - 37.0, TRACK_RECT.size.x - 20.0, 74.0)
	var color := TIDE.darkened(0.12) if not already_hit else TIDE.darkened(0.5)
	draw_rect(rect, color)
	for wave in range(5):
		var wx := rect.position.x + 80.0 + float(wave) * 190.0
		draw_arc(Vector2(wx, y + 3.0), 48.0, 0.0, PI, 16, Color.WHITE.lightened(0.15), 5.0)
	_draw_centered("RED TIDE  −%d" % amount, y + 11.0, 30, Color.WHITE)


func _draw_wall(y: float) -> void:
	var rect := Rect2(TRACK_RECT.position.x + 4.0, y - 42.0, TRACK_RECT.size.x - 8.0, 84.0)
	draw_rect(rect, INK)
	for stripe in range(12):
		var sx := rect.position.x + float(stripe) * rect.size.x / 12.0
		var stripe_points := PackedVector2Array([Vector2(sx, rect.position.y), Vector2(sx + 30.0, rect.position.y), Vector2(sx - 15.0, rect.end.y), Vector2(sx - 45.0, rect.end.y)])
		draw_colored_polygon(stripe_points, BLUE if stripe % 2 == 0 else YELLOW)
	_draw_centered("WALL  >  %d" % wall_count, y + 13.0, 34, Color.WHITE)


func _draw_swarm() -> void:
	var center := Vector2(swarm_x, PLAYER_Y)
	draw_circle(center + Vector2(0.0, 18.0), 76.0, Color(INK, 0.12))
	var visible := mini(population, 48)
	for index in range(visible):
		var angle := float(index) * 2.399963
		var ring := 26.0 + float(index % 5) * 13.0
		var bean := center + Vector2(cos(angle), sin(angle)) * ring
		draw_circle(bean, 16.0 if index < 20 else 13.0, BLUE if index % 4 != 0 else GREEN)
	draw_circle(center, 26.0, INK)
	draw_circle(center, 18.0, Color.WHITE)
	_draw_centered("SWARM", PLAYER_Y + 112.0, 22, INK.darkened(0.15))


func _draw_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(INK, 0.78))
	var clear := state == RunState.CLEARED
	var headline := "CLEAR!" if clear else "FAILED"
	var detail := "WALL BROKEN" if clear else "THE SWARM IS GONE"
	var action := "TAP TO NEXT" if clear and level_index + 1 < level_order.size() else "TAP TO RETRY"
	_draw_centered(headline, 790.0, 92, Color.WHITE)
	_draw_centered(detail, 885.0, 32, Color.WHITE.lightened(0.2))
	var button := Rect2(190.0, 1060.0, 700.0, 150.0)
	draw_rect(button, BLUE if clear else RED)
	draw_rect(button, Color.WHITE, false, 6.0)
	_draw_centered_in_rect(action, button, 42, Color.WHITE)


func _gate_color(gate: Dictionary) -> Color:
	match String(gate.get("op", "add")):
		"add":
			return GREEN
		"sub":
			return RED
		"mul":
			return BLUE
		"div":
			return YELLOW
	return INK


func _gate_text(gate: Dictionary) -> String:
	if gate.has("display"):
		return String(gate["display"])
	var op := String(gate.get("op", "add"))
	var value := int(gate.get("value", 0))
	match op:
		"add":
			return "+%d" % value
		"sub":
			return "−%d" % value
		"mul":
			return "×%d" % value
		"div":
			return "÷%d" % value
	return "?"


func _draw_centered(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW_SIZE.x, font_size, color)


func _draw_centered_in_rect(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var baseline := rect.position.y + rect.size.y * 0.5 + float(font_size) * 0.35
	draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)
