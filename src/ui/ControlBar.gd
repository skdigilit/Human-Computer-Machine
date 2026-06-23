class_name ControlBar
extends PanelContainer

## The transport controls along the bottom of the room: reset, step, play/pause
## and a speed slider — the debugger-style controls described in the brief.
## It only emits intent; the Game decides what running actually means.

signal reset_requested()
signal step_requested()
signal play_toggled(should_run: bool)
signal speed_changed(seconds_per_step: float)

## Speed slider maps linearly onto this delay range (fast .. slow).
const FAST_DELAY := 0.06
const SLOW_DELAY := 0.9

var _play_button: Button
var _status: Label
var _running: bool = false

func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(VisualTheme.ROOM_WALL)
	style.border_color = Color.html(VisualTheme.PAPER)
	style.set_border_width_all(3)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)

func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	var reset := _make_button("RESET", VisualTheme.CORAL)
	reset.pressed.connect(func() -> void: reset_requested.emit())
	row.add_child(reset)

	_play_button = _make_button("RUN", "#68A34E")
	_play_button.pressed.connect(_on_play_pressed)
	row.add_child(_play_button)

	var step := _make_button("STEP", VisualTheme.SKY)
	step.pressed.connect(func() -> void: step_requested.emit())
	row.add_child(step)

	var speed_group := HBoxContainer.new()
	speed_group.add_theme_constant_override("separation", 10)
	speed_group.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_group.custom_minimum_size = Vector2(250, 44)
	row.add_child(speed_group)

	var speed_label := Label.new()
	speed_label.text = "SPEED"
	speed_label.add_theme_color_override("font_color", Color.html("#E8DEC8"))
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_label.custom_minimum_size = Vector2(68, 44)
	speed_group.add_child(speed_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.6
	slider.custom_minimum_size = Vector2(170, 44)
	slider.value_changed.connect(_on_speed_changed)
	speed_group.add_child(slider)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color.html("#F0E9DC"))
	_status.add_theme_font_size_override("font_size", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(300, 0)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)

## Build a coloured pill button.
func _make_button(text: String, color_hex: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	var style := VisualTheme.make_box_style(color_hex, Color.html(color_hex).darkened(0.3).to_html(false))
	style.shadow_size = 0
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", VisualTheme.make_box_style(Color.html(color_hex).lightened(0.1).to_html(false), color_hex))
	b.add_theme_stylebox_override("pressed", style)
	b.add_theme_color_override("font_color", Color.html("#FBF7EE"))
	b.custom_minimum_size = Vector2(110, 44)
	return b

func _on_play_pressed() -> void:
	_running = not _running
	_refresh_play_button()
	play_toggled.emit(_running)

func _on_speed_changed(value: float) -> void:
	# Slider right = faster, so invert before mapping to a delay.
	speed_changed.emit(lerpf(SLOW_DELAY, FAST_DELAY, value))

## Current delay implied by the slider's starting position.
func initial_delay() -> float:
	return lerpf(SLOW_DELAY, FAST_DELAY, 0.6)

## Force the play button back to its idle state (e.g. when a run ends).
func set_running(running: bool) -> void:
	_running = running
	_refresh_play_button()

func _refresh_play_button() -> void:
	_play_button.text = "PAUSE" if _running else "RUN"

## Show a message (level complete, errors, hints).
func set_status(text: String) -> void:
	_status.text = text
