extends SceneTree

## Exercises the editor's advanced drag behaviours:
##  1. dragging a line out of the list deletes it (via real synthetic drag),
##  2. dragging a jump's arrow onto a line targets it, and the candidate
##     highlight engages (via the public drop API with true canvas coordinates,
##     since precise synthetic landings fight the window stretch transform —
##     the native drag pipeline itself is covered by test_drag_drop.gd).
##  3. dragging the dummy jump target instruction retargets the jump.
##   Godot --headless --script tests/test_dnd_features.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://game_main.tscn").instantiate()
	game._save_path = "user://test_dnd_features_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 8: await process_frame

	var list: ProgramListView = game._program_list
	var p: Program = game._program

	p.add(Instruction.new(InstructionDef.Op.INBOX))
	p.add(Instruction.new(InstructionDef.Op.OUTBOX))
	p.add(Instruction.new(InstructionDef.Op.JUMP))
	list.rebuild()
	for i in 3: await process_frame
	print("seeded   = ", _ops(p))

	# --- Test 1: drag the middle line out of the list to delete it. ---
	var victim := list._blocks[1]  # outbox
	var outside: Vector2 = game._room.get_global_rect().get_center()
	await _drag(victim.get_global_rect().get_center(), outside)
	for i in 4: await process_frame
	print("after delete = ", _ops(p))
	var delete_ok := p.size() == 2 and not _ops(p).has("outbox")

	# --- Test 2: jump-arrow drop sets the target + lights the candidate. ---
	var jump_block := _find_jump_block(list)
	var target_block := list._blocks[0]
	var jump_inst: Instruction = jump_block.instruction
	var target_inst: Instruction = target_block.instruction
	var data := {
		InstructionBlock.DRAG_KIND: InstructionBlock.DRAG_JUMP_TARGET,
		InstructionBlock.DRAG_JUMP_BLOCK: jump_block,
	}
	var point: Vector2 = target_block.get_global_rect().get_center()
	var accepted := list.can_accept_at(point, data)
	var candidate_ok := list._candidate_block == target_block
	list.drop_at(point, data)
	for i in 3: await process_frame
	var target_set := jump_inst.jump_target_id == target_inst.id
	print("accepted=", accepted, " candidate_ok=", candidate_ok, " target_set=", target_set)

	# --- Test 3: the dummy target instruction emits and routes the same drag. ---
	jump_inst.jump_target_id = jump_inst.id
	list.rebuild()
	for i in 3: await process_frame
	jump_block = _find_jump_block(list)
	target_block = list._blocks[0]
	var target_box: JumpTargetBox = list._target_boxes[jump_inst.id]
	var box_data: Variant = target_box.drag_payload()
	var box_payload_ok: bool = (
		box_data is Dictionary
		and box_data[InstructionBlock.DRAG_KIND] == InstructionBlock.DRAG_JUMP_TARGET
		and box_data[InstructionBlock.DRAG_JUMP_BLOCK] == jump_block
	)
	var box_is_dummy_instruction: bool = (
		target_box.custom_minimum_size.x >= 80.0
		and target_box.get_parent().has_meta("jump_target_marker")
		and target_box.get_parent().get_index() + 1 == jump_block.get_parent().get_index()
	)
	list.drop_at(target_block.get_global_rect().get_center(), box_data)
	for i in 4: await process_frame
	var box_drag_ok: bool = box_payload_ok and box_is_dummy_instruction and jump_inst.jump_target_id == target_inst.id

	var jump_ok: bool = accepted and candidate_ok and target_set and box_drag_ok
	print("delete_ok = ", delete_ok, "  jump_ok = ", jump_ok, "  box_drag_ok = ", box_drag_ok)
	print("RESULT: ", "PASS" if jump_ok else "FAIL")
	quit()

func _find_jump_block(list: ProgramListView) -> InstructionBlock:
	for b in list._blocks:
		if b.instruction.is_jump():
			return b
	return null

func _ops(p: Program) -> Array:
	var out: Array = []
	for inst in p.instructions:
		out.append(InstructionDef.label_for(inst.op))
	return out

func _drag(from: Vector2, to: Vector2) -> void:
	_motion(from, Vector2.ZERO)
	await process_frame
	_button(from, true)
	await process_frame
	var steps := 14
	for i in steps + 1:
		var t := float(i) / float(steps)
		_motion(from.lerp(to, t), (to - from) / float(steps))
		await process_frame
	_button(to, false)
	await process_frame

func _button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e)

func _motion(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e)
