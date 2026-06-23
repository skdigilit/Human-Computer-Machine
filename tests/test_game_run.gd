extends SceneTree

## Headless integration test: boots the real game scene, injects a known-good
## sorting solution into the live program model, runs the play loop, and checks
## the game reaches its win state. Exercises VM + RoomView animation + Game
## orchestration end to end (everything except manual mouse drag).
##   Godot --headless --script tests/test_game_run.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://game_main.tscn").instantiate()
	game._save_path = "user://test_game_run_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await process_frame
	await process_frame

	# This integration test exercises the final sorting puzzle.
	game._select_level(game._levels.size() - 1)
	await process_frame

	# Inject the solution into the game's program model, then refresh the view.
	_build_solution(game._program)
	game._program_list.rebuild()
	game._delay = 0.0
	game._on_play_toggled(true)

	var start := Time.get_ticks_msec()
	while not game._halted:
		await process_frame
		if Time.get_ticks_msec() - start > 90000:
			print("RESULT: FAIL (timed out)")
			quit()
			return

	print("outbox  = ", game._vm.outbox)
	print("status  = ", game._control_bar._status.text)
	print("win     = ", game._win_banner.visible)
	print("RESULT: ", "PASS" if game._win_banner.visible else "FAIL")
	quit()

func _add(p: Program, op: InstructionDef.Op) -> Instruction:
	var inst := Instruction.new(op)
	p.add(inst)
	return inst

func _addr(p: Program, op: InstructionDef.Op, address: int) -> Instruction:
	var inst := _add(p, op)
	inst.address = address
	return inst

func _build_solution(p: Program) -> void:
	_add(p, InstructionDef.Op.INBOX); _addr(p, InstructionDef.Op.COPYTO, 0)
	_add(p, InstructionDef.Op.INBOX); _addr(p, InstructionDef.Op.COPYTO, 1)
	_add(p, InstructionDef.Op.INBOX); _addr(p, InstructionDef.Op.COPYTO, 2)
	var l1 := _compare_swap(p, 0, 1)
	var l2 := _compare_swap(p, 1, 2)
	var l3 := _compare_swap(p, 0, 1)
	var out0 := _addr(p, InstructionDef.Op.COPYFROM, 0)
	_add(p, InstructionDef.Op.OUTBOX)
	_addr(p, InstructionDef.Op.COPYFROM, 1); _add(p, InstructionDef.Op.OUTBOX)
	_addr(p, InstructionDef.Op.COPYFROM, 2); _add(p, InstructionDef.Op.OUTBOX)
	l1.done.jump_target_id = l2.start.id
	l2.done.jump_target_id = l3.start.id
	l3.done.jump_target_id = out0.id

func _compare_swap(p: Program, a: int, b: int) -> Dictionary:
	var start := _addr(p, InstructionDef.Op.COPYFROM, a)
	_addr(p, InstructionDef.Op.SUB, b)
	var jneg := _add(p, InstructionDef.Op.JUMP_IF_NEG)
	var jzero := _add(p, InstructionDef.Op.JUMP_IF_ZERO)
	_addr(p, InstructionDef.Op.ADD, b)
	_addr(p, InstructionDef.Op.COPYTO, 3)
	_addr(p, InstructionDef.Op.COPYFROM, b); _addr(p, InstructionDef.Op.COPYTO, a)
	_addr(p, InstructionDef.Op.COPYFROM, 3); _addr(p, InstructionDef.Op.COPYTO, b)
	var done := _add(p, InstructionDef.Op.JUMP)
	var restore := _addr(p, InstructionDef.Op.ADD, b)
	_addr(p, InstructionDef.Op.COPYTO, a)
	jneg.jump_target_id = restore.id
	jzero.jump_target_id = restore.id
	return {"start": start, "done": done}
