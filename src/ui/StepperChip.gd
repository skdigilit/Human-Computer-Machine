class_name StepperChip
extends HBoxContainer

## The "[-] 0.5s [+]" operand on a block. Nudges Instruction.param within the
## opcode's stepper range (InstructionDef.stepper_range_for) and shows the
## value through InstructionDef.param_text_for, so the chip never needs to know
## what unit the number is in.

signal value_changed()

const CHIP_FILL := "#F3ECD8"
const CHIP_BORDER := "#B9AE8C"
const CHIP_TEXT := "#3A3526"

var instruction: Instruction
var _range: Vector3i
var _minus: Button
var _plus: Button
var _value: Label

func _init(p_instruction: Instruction) -> void:
	instruction = p_instruction
	_range = InstructionDef.stepper_range_for(instruction.op)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_minus = _make_step_button("-", -1)
	add_child(_minus)
	_value = Label.new()
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value.add_theme_color_override("font_color", Color.html("#FBF7EE"))
	VisualTheme.apply_ui_font(_value)
	add_child(_value)
	_plus = _make_step_button("+", 1)
	add_child(_plus)
	apply_ui_scale()
	refresh()

func _make_step_button(label: String, direction: int) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	var style := VisualTheme.make_box_style(CHIP_FILL, CHIP_BORDER)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", VisualTheme.make_box_style("#FFF3CF", CHIP_BORDER))
	button.add_theme_stylebox_override("pressed", style)
	VisualTheme.apply_ui_font(button)
	VisualTheme.set_button_font_color(button, Color.html(CHIP_TEXT))
	button.pressed.connect(_nudge.bind(direction))
	return button

## Scale the buttons and value text with the instruction font setting.
func apply_ui_scale() -> void:
	add_theme_constant_override("separation", VisualTheme.scaled_int(4, 1, 20))
	for button in [_minus, _plus]:
		VisualTheme.apply_button_size_mult(button, Vector2(28, 28), 18, InstructionBlock.font_scale, 10.0)
	VisualTheme.apply_font_size_mult(_value, 17, InstructionBlock.font_scale, 6, 320)
	_value.custom_minimum_size = Vector2(VisualTheme.scaled(52.0 * InstructionBlock.font_scale, 30.0, 260.0), 0.0)

## Show the current value in the opcode's own units.
func refresh() -> void:
	_value.text = InstructionDef.param_text_for(instruction.op, instruction.param)
	_minus.disabled = instruction.param <= _range.x
	_plus.disabled = instruction.param >= _range.y

func _nudge(direction: int) -> void:
	var next := clampi(instruction.param + direction * _range.z, _range.x, _range.y)
	if next == instruction.param:
		return
	instruction.param = next
	refresh()
	value_changed.emit()
