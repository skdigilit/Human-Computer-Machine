class_name ChoiceChip
extends Button

## The picture-menu operand on a block ("jump if [🥕]", "face [→]"). Shows an
## icon for the current choice; clicking opens a popup menu listing every
## choice as icon + word so young players can pick by picture. The chosen index
## is written straight into Instruction.param.

signal choice_changed()

const ICON_TINT := "#3A3526"
const MENU_ICON_TINT := "#F7F2DE"

var instruction: Instruction
var _choices: Array[Dictionary] = []
var _menu: PopupMenu

func _init(p_instruction: Instruction) -> void:
	instruction = p_instruction
	_choices = InstructionDef.choices_for(instruction.op)
	focus_mode = Control.FOCUS_NONE
	expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var style := VisualTheme.make_box_style("#F3ECD8", "#B9AE8C")
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", VisualTheme.make_box_style("#FFF3CF", "#B9AE8C"))
	add_theme_stylebox_override("pressed", style)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu_pick)
	add_child(_menu)
	pressed.connect(_open_menu)
	apply_ui_scale()
	refresh()

## Size the chip like the other operand chips, scaled with the instruction font.
func apply_ui_scale() -> void:
	var edge := VisualTheme.scaled(30.0 * InstructionBlock.font_scale, 18.0, 140.0)
	custom_minimum_size = Vector2(edge * 1.3, edge)
	add_theme_constant_override("icon_max_width", int(edge * 0.75))
	_rebuild_menu()

## Show the icon and tooltip for the current param.
func refresh() -> void:
	var choice := _current_choice()
	if choice.is_empty():
		icon = null
		text = "?"
		return
	text = ""
	icon = SFSymbols.texture(String(choice["icon"]), Color.html(ICON_TINT))
	tooltip_text = String(choice["label"])

func _current_choice() -> Dictionary:
	if instruction.param >= 0 and instruction.param < _choices.size():
		return _choices[instruction.param]
	return {}

func _rebuild_menu() -> void:
	_menu.clear()
	var font_size := VisualTheme.scaled_int(18.0 * InstructionBlock.font_scale, 10, 72)
	_menu.add_theme_font_size_override("font_size", font_size)
	_menu.add_theme_constant_override("icon_max_width", int(font_size * 1.4))
	for i in _choices.size():
		var choice := _choices[i]
		_menu.add_icon_item(SFSymbols.texture(String(choice["icon"]), Color.html(MENU_ICON_TINT)), String(choice["label"]), i)

func _open_menu() -> void:
	_menu.position = Vector2i(get_screen_position() + Vector2(0.0, size.y))
	_menu.popup()

func _on_menu_pick(id: int) -> void:
	if id == instruction.param:
		return
	instruction.param = id
	refresh()
	choice_changed.emit()
