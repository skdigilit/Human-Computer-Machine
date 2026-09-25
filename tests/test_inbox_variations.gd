extends SceneTree

## Verifies every puzzle has alternate data and swapping it resets only the
## machine state, without changing the program the player is testing.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://test_inbox_variations_%d.json" % Time.get_ticks_usec()
	game._settings_path = "user://test_inbox_variations_settings_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 4:
		await process_frame

	var all_levels_have_alternates := true
	for level in game._levels:
		all_levels_have_alternates = all_levels_have_alternates and level.test_case_count() >= 2

	var original_inbox := game._level.inbox.duplicate()
	var original_outbox := game._level.expected_outbox.duplicate()
	var instruction := Instruction.new(InstructionDef.Op.INBOX)
	game._program.add(instruction)
	game._program_list.rebuild()
	game._ensure_vm()
	game._vm.step()

	var swap_button: Button = (game._room as RoomView)._test_case_swap_button
	var button_below_inbox := swap_button.position.y >= (
		(game._room as RoomView)._chute_top
		+ RoomView.CELL * maxi(RoomView.MIN_CHUTE_SLOTS, original_inbox.size())
	)
	swap_button.pressed.emit()
	await process_frame

	var passed := (
		all_levels_have_alternates
		and button_below_inbox
		and game._level.active_test_case == 1
		and game._level.inbox != original_inbox
		and game._level.expected_outbox != original_outbox
		and game._program.size() == 1
		and game._program.instructions[0].id == instruction.id
		and game._vm == null
		and (game._room as RoomView)._inbox_boxes.size() == game._level.inbox.size()
		and (game._room as RoomView)._expected_outbox_values == game._level.expected_outbox
	)

	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
