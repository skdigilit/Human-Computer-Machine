class_name JumpTargetHandle
extends Button

## The little arrow on a jump instruction. Two ways to set where the jump lands:
##  * click it to cycle through the lines (quick), or
##  * drag it onto a program line to point the arrow there directly.
##
## Dragging emits a "jumptarget" drag whose drop is resolved by ProgramListView.

var owner_block: InstructionBlock

func _init(p_owner: InstructionBlock) -> void:
	owner_block = p_owner
	text = "→ ?"
	var style := VisualTheme.make_box_style("#F3ECD8", "#B9AE8C")
	style.shadow_size = 0
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", VisualTheme.make_box_style("#FFF3CF", "#B9AE8C"))
	add_theme_stylebox_override("pressed", style)
	VisualTheme.set_button_font_color(self, Color.html("#3A3526"))
	apply_ui_scale()
	tooltip_text = "Jump target\nClick to cycle, or drag this arrow onto a line."

func apply_ui_scale() -> void:
	VisualTheme.apply_button_size(self, Vector2(52, 28), 18, 24.0)

func _get_drag_data(_pos: Vector2) -> Variant:
	var list := _find_program_list()
	if list == null:
		return null
	list._begin_jump_drag(owner_block, self)
	set_drag_preview(_make_preview())
	return {
		InstructionBlock.DRAG_KIND: InstructionBlock.DRAG_JUMP_TARGET,
		InstructionBlock.DRAG_JUMP_BLOCK: owner_block,
	}

## Floating arrow shown under the cursor while wiring up a jump.
func _make_preview() -> Control:
	var lbl := Label.new()
	lbl.text = "→ target"
	VisualTheme.apply_font_size(lbl, 20, 8, 88)
	lbl.add_theme_color_override("font_color", Color.html("#3A3A6A"))
	return lbl

## Climb to the owning ProgramListView so we can announce the jump drag.
func _find_program_list() -> ProgramListView:
	var node: Node = get_parent()
	while node != null:
		if node is ProgramListView:
			return node
		node = node.get_parent()
	return null
