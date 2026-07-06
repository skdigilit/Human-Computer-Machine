class_name ControlBar
extends PanelContainer

## The transport controls along the bottom of the room: reset, step, play/pause
## and a speed slider — the debugger-style controls described in the brief.
## It only emits intent; the Game decides what running actually means.

signal reset_requested()
signal step_requested()
signal play_toggled(should_run: bool)
signal speed_changed(seconds_per_step: float)
signal settings_requested()

## Speed slider maps linearly onto this delay range (fast .. slow).
const FAST_DELAY := 0.06
const SLOW_DELAY := 0.9
const SFSymbolsScript := preload("res://src/ui/SFSymbols.gd")
const STATUS_TONE_DEFAULT := 0
const STATUS_TONE_SUCCESS := 1
const STATUS_TONE_ERROR := 2
const STATUS_DEFAULT_COLOR := "#F0E9DC"
const STATUS_SUCCESS_COLOR := "#FFE066"
const STATUS_SUCCESS_OUTLINE := "#5A4A10"
const STATUS_ERROR_COLOR := "#D94A3A"

var _play_button: Button
var _status: Label
var _status_tone: int = STATUS_TONE_DEFAULT
var _running: bool = false
var _margin: MarginContainer
var _row: HBoxContainer
var _speed_group: HBoxContainer
var _speed_label: Label
var _slider: HSlider
var _settings_button: Button
var _buttons: Array[Button] = []

func _init() -> void:
	_apply_panel_style()

func _ready() -> void:
	_margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(12, 4, 24))
	add_child(_margin)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", VisualTheme.scaled_int(12, 4, 24))
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_margin.add_child(_row)

	var reset := _make_button("RESET", VisualTheme.CORAL)
	reset.pressed.connect(func() -> void: reset_requested.emit())
	_row.add_child(reset)

	_play_button = _make_button("RUN", "#68A34E")
	_play_button.pressed.connect(_on_play_pressed)
	_row.add_child(_play_button)

	var step := _make_button("STEP", VisualTheme.SKY)
	step.pressed.connect(func() -> void: step_requested.emit())
	_row.add_child(step)

	_speed_group = HBoxContainer.new()
	_speed_group.add_theme_constant_override("separation", VisualTheme.scaled_int(10, 3, 20))
	_speed_group.alignment = BoxContainer.ALIGNMENT_CENTER
	_speed_group.custom_minimum_size = VisualTheme.scaled_size(Vector2(250, 44), Vector2(120, 20), Vector2(360, 120))
	_row.add_child(_speed_group)

	_speed_label = Label.new()
	_speed_label.text = "SPEED"
	_speed_label.add_theme_color_override("font_color", Color.html("#E8DEC8"))
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_label.custom_minimum_size = VisualTheme.scaled_size(Vector2(68, 44), Vector2(34, 20), Vector2(130, 96))
	VisualTheme.apply_font_size(_speed_label, 18)
	_speed_group.add_child(_speed_label)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.value = 0.6
	_slider.custom_minimum_size = VisualTheme.scaled_size(Vector2(170, 44), Vector2(80, 20), Vector2(230, 96))
	_slider.value_changed.connect(_on_speed_changed)
	_speed_group.add_child(_slider)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.clip_text = true
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(1, VisualTheme.scaled(44.0, 28.0, 96.0))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_status_style(STATUS_TONE_DEFAULT)
	_row.add_child(_status)

	_settings_button = _make_icon_button("gearshape")
	_settings_button.tooltip_text = "Settings"
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_row.add_child(_settings_button)

## Build a coloured pill button.
func _make_button(text: String, color_hex: String) -> Button:
	var b := Button.new()
	b.text = text
	var style := VisualTheme.make_box_style(color_hex, Color.html(color_hex).darkened(0.3).to_html(false))
	style.shadow_size = 0
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", VisualTheme.make_box_style(Color.html(color_hex).lightened(0.1).to_html(false), color_hex))
	b.add_theme_stylebox_override("pressed", style)
	b.add_theme_color_override("font_color", Color.html("#FBF7EE"))
	_apply_transport_button_size(b)
	_buttons.append(b)
	return b

func apply_ui_scale() -> void:
	_apply_panel_style()
	if _margin:
		for side in ["left", "right", "top", "bottom"]:
			_margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(12, 4, 24))
	if _row:
		_row.add_theme_constant_override("separation", VisualTheme.scaled_int(12, 4, 24))
	for button in _buttons:
		_apply_transport_button_size(button)
	if _speed_group:
		_speed_group.add_theme_constant_override("separation", VisualTheme.scaled_int(10, 3, 20))
		_speed_group.custom_minimum_size = VisualTheme.scaled_size(Vector2(250, 44), Vector2(120, 20), Vector2(360, 120))
	if _speed_label:
		VisualTheme.apply_font_size(_speed_label, 18)
		_speed_label.custom_minimum_size = VisualTheme.scaled_size(Vector2(68, 44), Vector2(34, 20), Vector2(130, 96))
	if _slider:
		_slider.custom_minimum_size = VisualTheme.scaled_size(Vector2(170, 44), Vector2(80, 20), Vector2(230, 96))
	if _status:
		_apply_status_style(_status_tone)
		_status.custom_minimum_size = Vector2(1, VisualTheme.scaled(44.0, 28.0, 96.0))
	if _settings_button:
		_apply_icon_button_size(_settings_button)

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(VisualTheme.ROOM_WALL)
	style.border_color = Color.html(VisualTheme.PAPER)
	style.set_border_width_all(VisualTheme.scaled_int(3, 1, 18))
	style.set_corner_radius_all(VisualTheme.scaled_int(VisualTheme.UI_PANEL_RADIUS, 6, 72))
	add_theme_stylebox_override("panel", style)

func _apply_transport_button_size(button: Button) -> void:
	VisualTheme.apply_font_size(button, 20, 10, 34)
	var font_size := float(button.get_theme_font_size("font_size"))
	var width := maxf(
		VisualTheme.scaled(110.0, 70.0, 180.0),
		float(button.text.length()) * font_size * 0.76 + VisualTheme.scaled(36.0, 20.0, 56.0)
	)
	button.custom_minimum_size = Vector2(width, VisualTheme.scaled(44.0, 28.0, 96.0))

func _make_icon_button(symbol: String) -> Button:
	var button := Button.new()
	button.icon = SFSymbolsScript.texture(symbol, Color.html(VisualTheme.PAPER))
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var normal := VisualTheme.make_box_style("#2A312D", "#59655B", 4)
	var hover := VisualTheme.make_box_style("#3C463F", "#F7F2DE", 4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	_apply_icon_button_size(button)
	return button

func _apply_icon_button_size(button: Button) -> void:
	var edge := VisualTheme.scaled(44.0, 28.0, 96.0)
	button.custom_minimum_size = Vector2(edge, edge)
	button.add_theme_constant_override("icon_max_width", VisualTheme.scaled_int(24, 14, 56))

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
	_apply_transport_button_size(_play_button)

## Show a message (level complete, errors, hints).
func set_status(text: String, tone: int = STATUS_TONE_DEFAULT) -> void:
	_apply_status_style(tone)
	_status.text = text

func _apply_status_style(tone: int) -> void:
	_status_tone = tone
	if _status == null:
		return
	match tone:
		STATUS_TONE_SUCCESS:
			VisualTheme.apply_ui_font(_status, true, true)
			VisualTheme.apply_font_size(_status, 24, 12, 64)
			_status.add_theme_color_override("font_color", Color.html(STATUS_SUCCESS_COLOR))
			_status.add_theme_color_override("font_outline_color", Color.html(STATUS_SUCCESS_OUTLINE))
			_status.add_theme_constant_override("outline_size", VisualTheme.scaled_int(3, 1, 12))
		STATUS_TONE_ERROR:
			VisualTheme.apply_ui_font(_status, true)
			VisualTheme.apply_font_size(_status, 24, 12, 64)
			_status.add_theme_color_override("font_color", Color.html(STATUS_ERROR_COLOR))
			_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			_status.add_theme_constant_override("outline_size", 0)
		_:
			VisualTheme.apply_ui_font(_status)
			VisualTheme.apply_font_size(_status, 18)
			_status.add_theme_color_override("font_color", Color.html(STATUS_DEFAULT_COLOR))
			_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			_status.add_theme_constant_override("outline_size", 0)
