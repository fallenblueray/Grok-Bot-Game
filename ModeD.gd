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
	oov_layer := CanvasLayer.new()
