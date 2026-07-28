extends SceneTree

## Verifies Space picks up a hovered instruction and drops one already held.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://space_pickup_shortcut_test_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 6:
		await process_frame

	var palette_block := _find_instruction_block(game._palette)
	_move_pointer(game, palette_block.get_global_rect().get_center())
	palette_block.mouse_entered.emit()
	game._input(_space_event())
	var palette_instruction_picked_up := InstructionBlock.has_active_click_pickup()

	palette_block.mouse_exited.emit()
	var drop_point := game._program_list.get_global_rect().get_center()
	_move_pointer(game, drop_point)
	game._input(_space_event())
	await process_frame
	var palette_instruction_dropped := (
		not InstructionBlock.has_active_click_pickup()
		and game._program.size() == 1
	)

	var program_block: InstructionBlock = game._program_list._blocks[0]
	_move_pointer(game, program_block.get_global_rect().get_center())
	program_block.mouse_entered.emit()
	game._input(_space_event())
	var program_instruction_picked_up := InstructionBlock.has_active_click_pickup()
	game._input(_space_event())
	await process_frame
	var program_instruction_dropped := (
		not InstructionBlock.has_active_click_pickup()
		and game._program.size() == 1
	)

	game._input(_space_event())
	var no_hover_press_ignored := not InstructionBlock.has_active_click_pickup()
	var passed := (
		palette_instruction_picked_up
		and palette_instruction_dropped
		and program_instruction_picked_up
		and program_instruction_dropped
		and no_hover_press_ignored
	)
	if not passed:
		print("palette_instruction_picked_up=", palette_instruction_picked_up)
		print("palette_instruction_dropped=", palette_instruction_dropped)
		print("program_instruction_picked_up=", program_instruction_picked_up)
		print("program_instruction_dropped=", program_instruction_dropped)
		print("no_hover_press_ignored=", no_hover_press_ignored)

	game.queue_free()
	for i in 2:
		await process_frame
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

func _space_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.key_label = KEY_SPACE
	return event

func _move_pointer(game: Game, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	game._input(event)

func _find_instruction_block(node: Node) -> InstructionBlock:
	if node is InstructionBlock:
		return node as InstructionBlock
	for child in node.get_children():
		var found := _find_instruction_block(child)
		if found:
			return found
	return null
