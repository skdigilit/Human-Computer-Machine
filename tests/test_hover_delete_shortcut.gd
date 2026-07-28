extends SceneTree

## Verifies X deletes only the program instruction directly under the pointer.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://hover_delete_shortcut_test_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 6:
		await process_frame

	var program: Program = game._program
	program.add(Instruction.new(InstructionDef.Op.INBOX))
	program.add(Instruction.new(InstructionDef.Op.OUTBOX))
	program.add(Instruction.new(InstructionDef.Op.COPYFROM))
	game._program_list.rebuild()
	for i in 3:
		await process_frame

	var victim: InstructionBlock = game._program_list._blocks[1]
	victim.mouse_entered.emit()
	game._input(_x_event())
	await process_frame
	var hovered_instruction_deleted := (
		program.size() == 2
		and program.instructions[0].op == InstructionDef.Op.INBOX
		and program.instructions[1].op == InstructionDef.Op.COPYFROM
	)

	game._input(_x_event())
	await process_frame
	var no_hover_press_ignored := program.size() == 2

	var passed := hovered_instruction_deleted and no_hover_press_ignored
	if not passed:
		print("hovered_instruction_deleted=", hovered_instruction_deleted)
		print("no_hover_press_ignored=", no_hover_press_ignored)
		print("remaining_instruction_count=", program.size())

	game.queue_free()
	for i in 2:
		await process_frame
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

func _x_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_X
	event.physical_keycode = KEY_X
	event.key_label = KEY_X
	return event
