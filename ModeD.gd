extends Control
## Mode D — 抽層 Pull Layer
## Six fixed Y-bands. Hit-test by tap Y → band index (never raycast).
## Tweens only — no RigidBody, no physics, no CSG.

const INK := Color("1C1C1C")
const BG := Color("F4E8D0")
const CORAL := Color("E85D4C")
const TEAL := Color("2A9D8F")
const MUSTARD := Color("E9C46A")
const FLASH_WHITE := Color("FFFFFF")
const FAIL_RED := Color("E85D4C")
const COLLAPSE_RED := Color("FF3A2A")

const LAYER_COLORS: Array[Color] = [CORAL, TEAL, MUSTARD, CORAL, TEAL, MUSTARD]

@export var view_width: float = 1080.0
@export var view_height: float = 1920.0
@export var hud_frac: float = 0.10
@export var bottom_frac: float = 0.05
@export var band_count: int = 6
@export var band_height: float = 272.0
@export var band_gap_px: float = 8.0
@export var block_width_frac: float = 0.92
@export var crack_cut_px: float = 72.0
@export var pull_duration: float = 0.28
@export var drop_duration: float = 0.22
@export var collapse_duration: float = 0.65
@export var next_group_delay: float = 0.40
@export var group_drop_duration: float = 0.35
@export var run_seconds: float = 90.0

var _hud_h: float = 192.0
var _score: int = 0
var _combo: int = 0
var _time_left: float = 90.0
var _group_index: int = 1
var _busy: bool = false
var _ended: bool = false
var _restarting: bool = false
var _layers: Array = [] # LayerBlock

var _score_label: Label
var _combo_label: Label
var _time_label: Label
var _overlay: ColorRect
var _overlay_label: Label
var _flash: ColorRect
var _layer_host: Node2D


class LayerBlock extends Node2D:
	var band: int = 0
	var is_crack: bool = false
	var block_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_h = view_height * hud_frac
	_time_left = run_seconds
	_build_ui()
	randomize()
	_spawn_group(true)


func _process(delta: float) -> void:
	if _ended:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_end_timeout()
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
	_on_tap(_event_pos(event))


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


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return get_viewport().get_mouse_position()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_layer_host = Node2D.new()
	_layer_host.name = "Layers"
	add_child(_layer_host)

	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var hud_bg := ColorRect.new()
	hud_bg.color = Color(BG, 0.92)
	hud_bg.position = Vector2.ZERO
	hud_bg.size = Vector2(view_width, _hud_h)
	hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_bg)

	_score_label = _make_hud_label(hud, Vector2(40, 40), Vector2(320, 110), HORIZONTAL_ALIGNMENT_LEFT)
	_combo_label = _make_hud_label(hud, Vector2(380, 40), Vector2(320, 110), HORIZONTAL_ALIGNMENT_CENTER)
	_time_label = _make_hud_label(hud, Vector2(720, 40), Vector2(320, 110), HORIZONTAL_ALIGNMENT_RIGHT)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 20
	add_child(flash_layer)
	_flash = ColorRect.new()
	_flash.color = Color(COLLAPSE_RED, 0.0)
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


func _refresh_hud() -> void:
	_score_label.text = str(_score)
	_combo_label.text = str(_combo)
	_time_label.text = str(ceili(_time_left))


func _band_y(band: int) -> float:
	return _hud_h + float(band) * band_height + band_gap_px * 0.5


func _band_from_y(y: float) -> int:
	if y < _hud_h:
		return -1
	var play_h := float(band_count) * band_height
	if y >= _hud_h + play_h:
		return -1
	if y >= view_height - view_height * bottom_frac:
		return -1
	return clampi(int((y - _hud_h) / band_height), 0, band_count - 1)


func _crack_count_for_group(group: int) -> int:
	# group 1 = 1 crack / 5 loose; 2–3 = 2/4; 4+ = 3/3
	if group <= 1:
		return 1
	if group <= 3:
		return 2
	return 3


func _spawn_group(first: bool) -> void:
	_busy = true
	_clear_layers()

	var n_crack := _crack_count_for_group(_group_index)
	var flags: Array[bool] = [false, false, false, false, false, false]
	var slots: Array[int] = [0, 1, 2, 3, 4, 5]
	slots.shuffle()
	for i in n_crack:
		flags[slots[i]] = true

	var block_w := view_width * block_width_frac
	var block_h := band_height - band_gap_px
	var origin_x := (view_width - block_w) * 0.5
	var start_offset := 0.0 if first else -900.0

	for i in band_count:
		var L := _make_layer(i, flags[i], LAYER_COLORS[i], Vector2(block_w, block_h))
		L.position = Vector2(origin_x, _band_y(i) + start_offset)
		_layer_host.add_child(L)
		_layers.append(L)

	if first:
		_busy = false
		return

	var tw := create_tween()
	tw.set_parallel(true)
	for L in _layers:
		var lb: LayerBlock = L
		tw.tween_property(lb, "position:y", _band_y(lb.band), group_drop_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not _ended:
		_busy = false


func _clear_layers() -> void:
	for L in _layers:
		if is_instance_valid(L):
			(L as Node).queue_free()
	_layers.clear()


func _make_layer(band: int, is_crack: bool, color: Color, sz: Vector2) -> LayerBlock:
	var L := LayerBlock.new()
	L.band = band
	L.is_crack = is_crack
	L.block_size = sz
	L.name = "Layer_%d" % band

	var w := sz.x
	var h := sz.y
	var cut := crack_cut_px
	var pts: PackedVector2Array
	if is_crack:
		# Missing top-right corner + ink notch (not a crack texture).
		pts = PackedVector2Array([
			Vector2(0, 0),
			Vector2(w - cut, 0),
			Vector2(w - cut, cut * 0.32),
			Vector2(w - cut * 0.22, cut),
			Vector2(w, cut),
			Vector2(w, h),
			Vector2(0, h),
		])
	else:
		pts = PackedVector2Array([
			Vector2(0, 0),
			Vector2(w, 0),
			Vector2(w, h),
			Vector2(0, h),
		])

	var body := Polygon2D.new()
	body.polygon = pts
	body.color = color
	L.add_child(body)

	if is_crack:
		var notch := Polygon2D.new()
		notch.color = INK
		notch.polygon = PackedVector2Array([
			Vector2(w - cut, 0),
			Vector2(w - cut + 28, 0),
			Vector2(w - cut + 12, 24),
			Vector2(w - cut, 20),
		])
		L.add_child(notch)

	return L


func _on_tap(pos: Vector2) -> void:
	var band := _band_from_y(pos.y)
	if band < 0:
		return
	var target: LayerBlock = null
	for L in _layers:
		var lb: LayerBlock = L
		if lb.band == band:
			target = lb
			break
	if target == null:
		return
	if target.is_crack:
		_on_crack_hit()
	else:
		_on_loose_hit(target)


func _on_loose_hit(layer: LayerBlock) -> void:
	_busy = true
	_score += 1
	_combo += 1
	_refresh_hud()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(layer, "position:x", layer.position.x + view_width, pull_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(layer, "modulate:a", 0.0, pull_duration)
	await tw.finished
	if _ended:
		return

	var vacated := layer.band
	_layers.erase(layer)
	if is_instance_valid(layer):
		layer.queue_free()

	# Layers above (smaller band index) tween down one slot.
	var movers: Array = []
	for L in _layers:
		var lb: LayerBlock = L
		if lb.band < vacated:
			movers.append(lb)
	if not movers.is_empty():
		var drop := create_tween()
		drop.set_parallel(true)
		for L in movers:
			var lb: LayerBlock = L
			lb.band += 1
			drop.tween_property(lb, "position:y", _band_y(lb.band), drop_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await drop.finished
		if _ended:
			return

	if _count_loose() == 0:
		await get_tree().create_timer(next_group_delay).timeout
		if _ended:
			return
		await _retire_and_next_group()
		return

	_busy = false


func _count_loose() -> int:
	var n := 0
	for L in _layers:
		if not (L as LayerBlock).is_crack:
			n += 1
	return n


func _retire_and_next_group() -> void:
	# Remaining cracks tween off, then a new 6-layer group drops in.
	if not _layers.is_empty():
		var tw := create_tween()
		tw.set_parallel(true)
		for L in _layers:
			var lb: LayerBlock = L
			tw.tween_property(lb, "position:y", lb.position.y + 1400.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_property(lb, "modulate:a", 0.0, 0.28)
		await tw.finished
		if _ended:
			return
	_group_index += 1
	await _spawn_group(false)


func _on_crack_hit() -> void:
	if _ended:
		return
	_ended = true
	_busy = true
	# Brighter red collapse flash, then layers fall/rotate with tweens (not physics).
	_flash.color = Color(COLLAPSE_RED, 0.72)
	var flash_tw := create_tween()
	flash_tw.tween_property(_flash, "color:a", 0.0, 0.35)
	await _play_collapse()
	_show_overlay()


func _play_collapse() -> void:
	if _layers.is_empty():
		return
	var tw := create_tween()
	tw.set_parallel(true)
	var i := 0
	for L in _layers:
		var lb: LayerBlock = L
		var delay := 0.04 * float(i)
		var fall_y := lb.position.y + 1100.0 + float(i) * 40.0
		var rot := randf_range(-0.9, 0.9)
		var drift := lb.position.x + randf_range(-80.0, 80.0)
		tw.tween_property(lb, "position:y", fall_y, collapse_duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(lb, "position:x", drift, collapse_duration).set_delay(delay)
		tw.tween_property(lb, "rotation", rot, collapse_duration).set_delay(delay)
		tw.tween_property(lb, "modulate:a", 0.25, collapse_duration).set_delay(delay)
		i += 1
	await tw.finished


func _end_timeout() -> void:
	if _ended:
		return
	_ended = true
	_busy = true
	_show_overlay()


func _show_overlay() -> void:
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
