class_name JumpTargetBox
extends Button

## Draggable dummy instruction showing where a jump lands.

var owner_block: InstructionBlock

func _init(p_owner: InstructionBlock) -> void:
	owner_block = p_owner
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Jump target\nDrag this box onto a command to change the target."

func _get_drag_data(_pos: Vector2) -> Variant:
	var list := _find_program_list()
	if list == null:
		return null
	list._begin_jump_drag(owner_block, self)
	set_drag_preview(_make_preview())
	return drag_payload()

func drag_payload() -> Dictionary:
	return {
		InstructionBlock.DRAG_KIND: InstructionBlock.DRAG_JUMP_TARGET,
		InstructionBlock.DRAG_JUMP_BLOCK: owner_block,
	}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var list := _find_program_list()
	return list != null and list.can_accept_at(global_position + at_position, data)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var list := _find_program_list()
	if list:
		list.drop_at(global_position + at_position, data)

func _make_preview() -> Control:
	var preview := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(InstructionDef.COLOR_JUMP)
	style.border_color = Color.html(InstructionDef.COLOR_JUMP).darkened(0.25)
	style.set_border_width_all(3)
	style.set_corner_radius_all(2)
	preview.add_theme_stylebox_override("panel", style)
	preview.custom_minimum_size = size
	return preview

func _find_program_list() -> ProgramListView:
	var node: Node = get_parent()
	while node != null:
		if node is ProgramListView:
			return node
		node = node.get_parent()
	return null
