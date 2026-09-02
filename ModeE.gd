extends Control
## Mode E — 相位咬合. 8-level chapter then 90s endless. Tweens only.

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

# period, inner°, outer°, docks to clear. 共7/8 sized so perfect window ≥ 90ms.
const LEVELS: Array[Dictionary] = [
	{"period": 2.2, "inner": 16.0, "outer": 36.0, "goal": 12},
	{"period": 2.0, "inner": 14.0, "outer": 32.0, "goal": 16},
	{"period": 1.8, "inner": 12.0, "outer": 28.0, "goal": 20},
	{"period": 1.65, "inner": 12.0, "outer": 26.0, "goal": 24},
	{"period": 1.5, "inner": 12.0, "outer": 24.0, "goal": 28},
	{"period": 1.42, "inner": 12.0, "outer": 23.0, "goal": 32},
	{"period": 1.35, "inner": 12.0, "outer": 22.0, "goal": 36},
	{"period": 1.3, "inner": 14.0, "outer": 24.0, "goal": 40},
]

var _period: float = 1.8
var _score: int = 0
var _combo: int = 0
var _time_left: float = 90.0
var _success_docks: int = 0
var _level_docks: int = 0
var _goal: int = 12
var _level: int = 0
var _endless: bool = false
var _cleared: bool = false
var _busy: bool = false
var _ended: bool = false
var _restarting: bool = false
var _blocked: Array[bool] = [false, false, false]
var _font: Font

var _score_label: Label
var _combo_label: Label
var _block_label: Label
var _level_label: Label
var _docks_label: Label
var _overlay: ColorRect
var _overlay_label: Label
var _overlay_hint: Label
var _flash: ColorRect
var _rotor: Rotor
var _tick: SnapTick
var _radius: float = 388.8


func _cjk_font() -> Font:
	if _font != null:
		return _font
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Noto Sans CJK TC", "Noto Sans CJK", "Noto Sans TC",
		"PingFang TC", "Microsoft JhengHei", "Source Han Sans TC", "sans-serif",
	])
	_font = f
	return _font


class Rotor extends Node2D:
	var radius: float = 388.8
	var thick_frac: float = 0.12
	var outer_deg: float = 28.0
	var inner_deg: float = 12.0
	var blocked: Array[bool] = [false, false, false]
	var window_count: int = 3

	func _band(r_in: float, r_out: float, a0: float, a1: float, color: Color, steps: int = 20) -> void:
		for s in steps:
			var t0 := float(s) / float(steps)
			var t1 := float(s + 1) / float(steps)
			var A := lerpf(a0, a1, t0)
			var B := lerpf(a0, a1, t1)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(cos(A), sin(A)) * r_out,
					Vector2(cos(B), sin(B)) * r_out,
					Vector2(cos(B), sin(B)) * r_in,
					Vector2(cos(A), sin(A)) * r_in,
				]),
				color
			)

	func _draw() -> void:
		var ink := Color("1C1C1C")
		var coral := Color("E85D4C")
		var teal := Color("2A9D8F")
		var white := Color("FFFFFF")
		var r := radius
		var thick := r * thick_frac
		var r_out := r - 3.0
		var r_in := r_out - thick
		draw_circle(Vector2.ZERO, r, Color(ink.r, ink.g, ink.b, 0.22))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, ink, 6.0, true)
		for i in window_count:
			var mid := deg_to_rad(float(i) * (360.0 / float(window_count)) - 90.0)
			var ho := deg_to_rad(outer_deg)
			var hi := deg_to_rad(inner_deg)
			if blocked[i]:
				coral.a = 0.88
				_band(r_in, r_out, mid - ho, mid + ho, coral)
			else:
				teal.a = 1.0
				_band(r_in, r_out, mid - ho, mid + ho, teal)
				var ink_edge := Color(ink, 1.0)
				var r_white_in := r_out - thick * 0.62
				_band(r_white_in - 6.0, r_out, mid - hi, mid + hi, ink_edge)
				_band(r_white_in, r_out - 3.0, mid - hi, mid + hi, white)


class SnapTick extends Node2D:
	var radius: float = 388.8

	func _draw() -> void:
		var ink := Color("1C1C1C")
		var y0 := -radius - 22.0
		var y1 := -radius - 78.0
		draw_line(Vector2(0, y0), Vector2(0, y1), ink, 8.0, true)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-16, y1),
				Vector2(16, y1),
				Vector2(0, y1 - 24),
			]),
			ink
		)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_level = int(Engine.get_meta("e_level", 0))
	_endless = bool(Engine.get_meta("e_endless", false))
	_apply_level()
	var short_side := minf(view_width, view_height)
	_radius = short_side * circle_diameter_frac * 0.5
	_build_ui()
	_apply_rotor_windows()


func _process(delta: float) -> void:
	if _ended:
		return
	if _endless:
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = 0.0
			_fail_run()
			_refresh_hud()
			return
	if not _busy:
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

	var hud_h := view_height * 0.10
	var hud_bg := ColorRect.new()
	hud_bg.color = Color(BG, 0.92)
	hud_bg.position = Vector2.ZERO
	hud_bg.size = Vector2(view_width, hud_h)
	hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_bg)

	var col_w := view_width / 5.0
	_score_label = _make_hud_cell(hud, 0.0, col_w, "分")
	_combo_label = _make_hud_cell(hud, col_w, col_w, "連")
	_block_label = _make_hud_cell(hud, col_w * 2.0, col_w, "堵")
	_level_label = _make_hud_cell(hud, col_w * 3.0, col_w, "關")
	_docks_label = _make_hud_cell(hud, col_w * 4.0, col_w, "扣")

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
	_overlay_label.offset_bottom = -80.0
	_overlay_label.add_theme_font_override("font", _cjk_font())
	_overlay_label.add_theme_font_size_override("font_size", 64)
	_overlay_label.add_theme_color_override("font_color", FLASH_WHITE)
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_overlay_label)

	_overlay_hint = Label.new()
	_overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_hint.offset_top = 80.0
	_overlay_hint.add_theme_font_override("font", _cjk_font())
	_overlay_hint.add_theme_font_size_override("font_size", 36)
	_overlay_hint.add_theme_color_override("font_color", FLASH_WHITE)
	_overlay_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_hint.text = "點一下"
	_overlay.add_child(_overlay_hint)


func _make_hud_cell(host: Node, x: float, w: float, caption: String) -> Label:
	var cap := Label.new()
	cap.text = caption
	cap.position = Vector2(x, 18)
	cap.size = Vector2(w, 44)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_theme_font_override("font", _cjk_font())
	cap.add_theme_font_size_override("font_size", 28)
	cap.add_theme_color_override("font_color", INK)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(cap)

	var l := Label.new()
	l.position = Vector2(x, 58)
	l.size = Vector2(w, 72)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _cjk_font())
	l.add_theme_font_size_override("font_size", 40)
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
	if _endless:
		_level_label.text = "無盡"
		_docks_label.text = str(ceili(_time_left))
	else:
		_level_label.text = "%d/8" % (_level + 1)
		_docks_label.text = "%d/%d" % [_level_docks, _goal]


func _angle_diff_deg(a: float, b: float) -> float:
	return wrapf(a - b, -180.0, 180.0)


func _on_tap() -> void:
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
	_level_docks += 1
	_refresh_hud()
	if not _endless and _level_docks >= _goal:
		_clear_level()


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
	var kick := bounce_deg if delta_deg >= 0.0 else -bounce_deg
	var target := _rotor.rotation_degrees + kick
	var tw := create_tween()
	tw.tween_property(_rotor, "rotation_degrees", target, bounce_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	if _blocked_count() >= window_count:
		_fail_run()
		return
	if not _ended:
		_busy = false


func _apply_level() -> void:
	var idx := mini(_level, LEVELS.size() - 1)
	var L: Dictionary = LEVELS[idx]
	_period = float(L["period"])
	window_inner_deg = float(L["inner"])
	window_outer_deg = float(L["outer"])
	_goal = int(L["goal"])
	if _endless:
		_time_left = run_seconds
	else:
		_time_left = 0.0


func _apply_rotor_windows() -> void:
	if _rotor == null:
		return
	_rotor.outer_deg = window_outer_deg
	_rotor.inner_deg = window_inner_deg
	_rotor.blocked = _blocked
	_rotor.queue_redraw()


func _clear_level() -> void:
	if _ended:
		return
	_ended = true
	_cleared = true
	_busy = true
	_overlay.color = Color(TEAL, 0.88)
	if _level >= LEVELS.size() - 1:
		_overlay_label.text = "無盡"
	else:
		_overlay_label.text = "%d/8" % (_level + 2)
	_overlay.visible = true


func _fail_run() -> void:
	if _ended:
		return
	_ended = true
	_cleared = false
	_busy = true
	_overlay.color = Color(FAIL_RED, 0.88)
	_overlay_label.text = str(_score)
	_overlay.visible = true


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	if _cleared:
		if _level >= LEVELS.size() - 1:
			Engine.set_meta("e_endless", true)
		else:
			Engine.set_meta("e_level", _level + 1)
			Engine.set_meta("e_endless", false)
	get_tree().reload_current_scene()


func _on_overlay_input(event: InputEvent) -> void:
	if _ended and _is_press(event):
		_restart()
