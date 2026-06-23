extends SceneTree

## Headless regression test for manual stepping while an instruction animation
## is still in flight.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://test_manual_step_buffer_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await process_frame
	await process_frame

	game._program.add(Instruction.new(InstructionDef.Op.INBOX))
	game._program.add(Instruction.new(InstructionDef.Op.OUTBOX))
	game._program.add(Instruction.new(InstructionDef.Op.INBOX))
	game._program_list.rebuild()

	game._on_step()
	await process_frame
	var first_step_started := game._busy and game._vm.steps_taken == 1

	game._on_step()
	game._on_step()
	var buffered_without_advancing := (
		game._step_buffered
		and game._vm.steps_taken == 1
		and game._room._animation_speed_scale == RoomView.MANUAL_STEP_SPEED_SCALE
	)

	var start := Time.get_ticks_msec()
	while game._busy or game._manual_step_loop_active:
		await process_frame
		if Time.get_ticks_msec() - start > 5000:
			print("RESULT: FAIL (timed out)")
			quit(1)
			return

	var one_step_was_buffered := (
		game._vm.steps_taken == 2
		and not game._step_buffered
		and game._room._animation_speed_scale == 1.0
	)
	var passed := first_step_started and buffered_without_advancing and one_step_was_buffered
	print("steps   = ", game._vm.steps_taken)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
