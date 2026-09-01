extends Control
## Mode E — 相位咬合 Phase Snap
## Whole-screen tap samples the circle's current rotation vs nearest window.
## Placeholder = circle + arcs (drawn). Tweens only.

const INK := Color("1C1C1C")
const BG := Color("F4E8D0")
const CORAL := Color("E85D4C")
const TEAL := Color("2A9D8F")
const MUSTARD := Color("E9C46A")
const FLASH_WHITE := Color("FFFFFF")
const FAIL_RED := Color("E85D4C")

@export var view_width: float = 1080.0
@export var view_height: float = 1920.0
@export var circle_diameter_frac: float = 0.72
@export var arc_thickness_frac: float = 0.12
@export var window_outer_deg: float = 28.0
@export var window_inner_deg: float = 12.0
@export var window_count: int = 3
@export var rotation_period: float = 1.8
@export var period_min: float = 0.75
@export var period_scale: float = 0.92
@export var docks_per_speedup: int = 8
@export var snap_duration: float = 0.12
@export var bounce_duration: float = 0.16
@export var bounce_deg: float = 14.0
@export var run_seconds: float = 90.0

var _period: float = 1.8
var _score: int = 0
var _combo: int = 0
var _time_left: float = 90.0
var _success_docks: int = 0
var _busy: bool = false
var _ended: bool = false
var _restarting: bool = false
var _blocked: Array[bool] = [false, false, false]

var _score_label: Label
var _combo_label: Label
var _time_label: Label
var _block_label: Label
var _overlay: ColorRect
var _overlay_label: Label
var _flash: ColorRect
var _rotor: Rotor
var _tick: SnapTick
var _radius: float = 388.8


class Rotor extends Node2D:
	var radius: float = 388.8
	var thick_frac: float = 0.12
	var outer_deg: float = 28.0
	var inner_deg: float = 12.0
	var blocked: Array[bool] = [false, false, false]
	var window_count: int = 3

	func _draw() -> void:
		var ink := Color("1C1C1C")
		var coral := Color("E85D4C")
		var teal := Color("2A9D8F")
		var white := Color("FFFFFF")
		var r := radius
		var thick := r * thick_frac
		var arc_r := r - thick * 0.55
		draw_circle(Vector2.ZERO, r, Color(ink.r, ink.g, ink.b, 0.10))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, ink, 5.0, true)
		for i in window_count:
			# Local 0° = up. Godot 0 rad = right, so offset -90°.
			var mid := deg_to_rad(float(i) * (360.0 / float(window_count)) - 90.0)
			var ho := deg_to_rad(outer_deg)
			var hi := deg_to_rad(inner_deg)
			if blocked[i]:
				var c := coral
				c.a = 0.40
				draw_arc(Vector2.ZERO, arc_r, mid - ho, mid + ho, 36, c, thick, true)
			else:
				var tcol := teal
				tcol.a = 0.50
				draw_arc(Vector2.ZERO, arc_r, mid - ho, mid + ho, 36, tcol, thick, true)
				draw_arc(Vector2.ZERO, arc_r, mid - hi, mid + hi, 28, white, thick * 0.72, true)


class SnapTick extends Node2D:
	var radius: float = 388.8

	func _draw() -> void:
		var ink := Color("1C1C1C")
		var y0 := -radius - 8.0
		var y1 := -radius - 44.0
		draw_line(Vector2(0, y0), Vector2(0, y1), ink, 8.0, true)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-14, y1),
				Vector2(14, y1),
				Vector2(0, y1 - 22),
			]),
			ink
		)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_period = rotation_period
	_time_left = run_seconds
	var short_side := minf(view_width, view_height)
	_radius = short_side * circle_diameter_frac * 0.5
	_build_ui()


func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_end_run()
		_refresh_hud()
		return
	if not _busy:
		# Clockwise in Godot 2D (Y-down). One revolution per _period seconds.
		_rotor.rotation_degrees += (360.0 / _period) * delta
	_refresh_hud()


func _input(event: InputEvent) -> void:
	if not _is_press(event):
		return
	get_viewport().set_input_as_handled()
	if _ended:
		_restart()
		return
	if _busy:
		return
	_on_tap()


func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return false
		return k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER
	return false


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var world := Node2D.new()
	world.name = "World"
	world.position = Vector2(view_width * 0.5, view_height * 0.5)
	add_child(world)

	_rotor = Rotor.new()
	_rotor.name = "Rotor"
	_rotor.radius = _radius
	_rotor.thick_frac = arc_thickness_frac
	_rotor.outer_deg = window_outer_deg
	_rotor.inner_deg = window_inner_deg
	_rotor.window_count = window_count
	_rotor.blocked = _blocked
	world.add_child(_rotor)

	_tick = SnapTick.new()
	_tick.name = "SnapTick"
	_tick.radius = _radius
	world.add_child(_tick)

	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var hud_bg := ColorRect.new()
	hud_bg.color = Color(BG, 0.92)
	hud_bg.position = Vector2.ZERO
	hud_bg.size = Vector2(view_width, view_height * 0.10)
	hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_bg)

	_score_label = _make_hud_label(hud, Vector2(40, 40), Vector2(240, 110), HORIZONTAL_ALIGNMENT_LEFT)
	_combo_label = _make_hud_label(hud, Vector2(300, 40), Vector2(240, 110), HORIZONTAL_ALIGNMENT_CENTER)
	_block_label = _make_hud_label(hud, Vector2(540, 40), Vector2(240, 110), HORIZONTAL_ALIGNMENT_CENTER)
	_time_label = _make_hud_label(hud, Vector2(800, 40), Vector2(240, 110), HORIZONTAL_ALIGNMENT_RIGHT)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 20
	add_child(flash_layer)
	_flash = ColorRect.new()
	_flash.color = Color(FLASH_WHITE, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_flash)

	var ov_layer := CanvasLayer.new()
	ov_layer.layer = 30
	add_child(ov_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(FAIL_RED, 0.88)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	ov_layer.add_child(_overlay)

	_overlay_label = Label.new()
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_label.add_theme_font_size_override("font_size", 64)
	_overlay_label.add_theme_color_override("font_color", FLASH_WHITE)
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_overlay_label)


func _make_hud_label(host: Node, pos: Vector2, size: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 42)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(l)
	return l


func _blocked_count() -> int:
	var n := 0
	for b in _blocked:
		if b:
			n += 1
	return n


func _refresh_hud() -> void:
	_score_label.text = str(_score)
	_combo_label.text = str(_combo)
	_block_label.text = "%d/3" % _blocked_count()
	_time_label.text = str(ceili(_time_left))


func _angle_diff_deg(a: float, b: float) -> float:
	return wrapf(a - b, -180.0, 180.0)


func _on_tap() -> void:
	# Sample current rotation. Window i local game-angle = i * 120, 0 = up.
	# World game-angle = rotor.rotation_degrees + i * 120. Snap target = 0 (tick).
	var nearest_i := 0
	var nearest_d := 999.0
	for i in window_count:
		var world_game := _rotor.rotation_degrees + float(i) * (360.0 / float(window_count))
		var d := _angle_diff_deg(world_game, 0.0)
		if absf(d) < absf(nearest_d):
			nearest_d = d
			nearest_i = i

	var ad := absf(nearest_d)
	if ad <= window_inner_deg and not _blocked[nearest_i]:
		await _do_perfect(nearest_i, nearest_d)
	elif ad <= window_outer_deg and not _blocked[nearest_i]:
		await _do_dock(nearest_d)
	else:
		await _do_miss(nearest_i, nearest_d)


func _register_success() -> void:
	_score += 1
	_success_docks += 1
	if _success_docks % docks_per_speedup == 0:
		_period = maxf(period_min, _period * period_scale)
	_refresh_hud()


func _do_perfect(_window_i: int, delta_deg: float) -> void:
	_busy = true
	_combo += 1
	_register_success()
	_flash.color = Color(FLASH_WHITE, 0.78)
	var flash_tw := create_tween()
	flash_tw.tween_property(_flash, "color:a", 0.0, 0.14)

	var target := _rotor.rotation_degrees - delta_deg
	var tw := create_tween()
	tw.tween_property(_rotor, "rotation_degrees", target, snap_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not _ended:
		_busy = false


func _do_dock(delta_deg: float) -> void:
	_busy = true
	_combo = 0
	_register_success()
	# Soft ease toward the window, no flash, combo reset.
	var target := _rotor.rotation_degrees - delta_deg * 0.35
	var tw := create_tween()
	tw.tween_property(_rotor, "rotation_degrees", target, snap_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not _ended:
		_busy = false


func _do_miss(window_i: int, delta_deg: float) -> void:
	_busy = true
	_combo = 0
	if not _blocked[window_i]:
		_blocked[window_i] = true
		_rotor.blocked = _blocked
		_rotor.queue_redraw()
	_refresh_hud()

	var kick := bounce_deg
	if delta_deg >= 0.0:
		kick = bounce_deg
	else:
		kick = -bounce_deg
	var target := _rotor.rotation_degrees + kick
	var tw := create_tween()
	tw.tween_property(_rotor, "rotation_degrees", target, bounce_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	if _blocked_count() >= window_count:
		_end_run()
		return
	if not _ended:
		_busy = false


func _end_run() -> void:
	if _ended:
		return
	_ended = true
	_busy = true
	_overlay_label.text = str(_score)
	_overlay.visible = true


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	get_tree().reload_current_scene()


func _on_overlay_input(event: InputEvent) -> void:
	if _ended and _is_press(event):
		_restart()
