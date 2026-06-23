class_name NumberBox
extends Control

## A flat square number piece occupying one warehouse grid cell.

var value: int = 0

var _panel: Panel
var _label: Label

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
	_panel.add_theme_stylebox_override(
		"panel", VisualTheme.make_box_style(VisualTheme.BOX_FILL, VisualTheme.BOX_BORDER, 0)
	)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.html(VisualTheme.BOX_TEXT))
	_label.add_theme_font_size_override("font_size", 32)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()

## Change the displayed value (e.g. after add/sub/bump).
func set_value(p_value: int) -> void:
	value = p_value
	if is_instance_valid(_label):
		_refresh()

func _refresh() -> void:
	_label.text = str(value)

## Centre this box on a target point in its parent's coordinate space.
func place_centered(center: Vector2) -> void:
	position = center - size * 0.5
