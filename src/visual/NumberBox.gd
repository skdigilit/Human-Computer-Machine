class_name NumberBox
extends Control

## A flat square number piece occupying one warehouse grid cell.

const BASE_FONT_SIZE := 32
const MIN_FONT_SIZE := 8
const MAX_FONT_SIZE := 184
const TEXT_HORIZONTAL_PADDING := 10.0

var value: int = 0

var _panel: Panel
var _label: Label
var _fill_hex: String = VisualTheme.BOX_FILL
var _border_hex: String = VisualTheme.BOX_BORDER
var _text_hex: String = VisualTheme.BOX_TEXT

func _init(p_value: int = 0) -> void:
	value = p_value
	custom_minimum_size = VisualTheme.BOX_SIZE
	size = VisualTheme.BOX_SIZE
	# Tween/scale around the box centre so "pop" animations look natural.
	pivot_offset = VisualTheme.BOX_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", VisualTheme.make_box_style(_fill_hex, _border_hex, 0))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.html(_text_hex))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()

func apply_ui_scale() -> void:
	if is_instance_valid(_label):
		_fit_label_font_size()

## Change the displayed value (e.g. after add/sub/bump).
func set_value(p_value: int) -> void:
	value = p_value
	if is_instance_valid(_label):
		_refresh()

func set_palette(fill_hex: String, border_hex: String, text_hex: String = VisualTheme.BOX_TEXT) -> void:
	_fill_hex = fill_hex
	_border_hex = border_hex
	_text_hex = text_hex
	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override("panel", VisualTheme.make_box_style(_fill_hex, _border_hex, 0))
	if is_instance_valid(_label):
		_label.add_theme_color_override("font_color", Color.html(_text_hex))

func _refresh() -> void:
	_label.text = str(value)
	_fit_label_font_size()

## Keep the box on the fixed warehouse grid while reducing only numerals that
## would otherwise extend through its border (for example, negative values
## with two or more digits).
func _fit_label_font_size() -> void:
	var font_size := VisualTheme.scaled_font_size(BASE_FONT_SIZE, MIN_FONT_SIZE, MAX_FONT_SIZE)
	var font := _label.get_theme_font("font")
	var available_width := maxf(1.0, size.x - TEXT_HORIZONTAL_PADDING * 2.0)
	var text_width := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	if text_width > available_width:
		font_size = maxi(MIN_FONT_SIZE, floori(float(font_size) * available_width / text_width))
	_label.add_theme_font_size_override("font_size", font_size)

## Centre this box on a target point in its parent's coordinate space.
func place_centered(center: Vector2) -> void:
	position = center - size * 0.5
