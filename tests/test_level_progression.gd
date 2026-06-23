extends SceneTree

## Verifies every introductory puzzle has a working solution.

func _init() -> void:
	var levels := LevelLibrary.all_levels()
	var programs := [
		_mail_room_solution(3),
		_busy_mail_room_solution(),
		_swap_floor_solution(),
		_add_one_solution(),
		_rainy_summer_solution(),
		_zero_exterminator_solution(),
		_zero_preservation_solution(),
		_countdown_solution(),
		_multiplier_solution(2),
		_multiplier_solution(7),
		_sub_hallway_solution(),
		_equalization_solution(),
		_mod_module_solution(),
	]

	var passed := true
	for i in programs.size():
		var vm := VM.new(levels[i], programs[i])
		var last: StepAction
		for step in 100:
			last = vm.step()
			if last.halted:
				break
		var solved := last != null and last.success
		passed = passed and solved
		print(levels[i].title, ": ", "PASS" if solved else "FAIL")
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit()

func _mail_room_solution(count: int) -> Program:
	var program := Program.new()
	for i in count:
		_add(program, InstructionDef.Op.INBOX)
		_add(program, InstructionDef.Op.OUTBOX)
	return program

func _busy_mail_room_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_add(program, InstructionDef.Op.OUTBOX)
	var jump := _add(program, InstructionDef.Op.JUMP)
	jump.jump_target_id = start.id
	return program

func _swap_floor_solution() -> Program:
	var program := Program.new()
	_add(program, InstructionDef.Op.INBOX); _addr(program, InstructionDef.Op.COPYTO, 0)
	_add(program, InstructionDef.Op.INBOX); _addr(program, InstructionDef.Op.COPYTO, 1)
	_addr(program, InstructionDef.Op.COPYFROM, 1); _add(program, InstructionDef.Op.OUTBOX)
	_addr(program, InstructionDef.Op.COPYFROM, 0); _add(program, InstructionDef.Op.OUTBOX)
	return program

func _add_one_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.ADD, 0)
	_add(program, InstructionDef.Op.OUTBOX)
	var jump := _add(program, InstructionDef.Op.JUMP)
	jump.jump_target_id = start.id
	return program

func _rainy_summer_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	_add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.ADD, 0)
	_add(program, InstructionDef.Op.OUTBOX)
	var jump := _add(program, InstructionDef.Op.JUMP)
	jump.jump_target_id = start.id
	return program

func _zero_exterminator_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	var zero := _add(program, InstructionDef.Op.JUMP_IF_ZERO)
	_add(program, InstructionDef.Op.OUTBOX)
	var jump := _add(program, InstructionDef.Op.JUMP)
	zero.jump_target_id = start.id
	jump.jump_target_id = start.id
	return program

func _zero_preservation_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	var zero := _add(program, InstructionDef.Op.JUMP_IF_ZERO)
	var skip := _add(program, InstructionDef.Op.JUMP)
	var output := _add(program, InstructionDef.Op.OUTBOX)
	var repeat := _add(program, InstructionDef.Op.JUMP)
	zero.jump_target_id = output.id
	skip.jump_target_id = start.id
	repeat.jump_target_id = start.id
	return program

func _countdown_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	var decrement := _addr(program, InstructionDef.Op.BUMP_DOWN, 0)
	var zero := _add(program, InstructionDef.Op.JUMP_IF_ZERO)
	_add(program, InstructionDef.Op.OUTBOX)
	var repeat_count := _add(program, InstructionDef.Op.JUMP)
	var output_zero := _add(program, InstructionDef.Op.OUTBOX)
	var repeat_input := _add(program, InstructionDef.Op.JUMP)
	zero.jump_target_id = output_zero.id
	repeat_count.jump_target_id = decrement.id
	repeat_input.jump_target_id = start.id
	return program

func _multiplier_solution(add_count: int) -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	_addr(program, InstructionDef.Op.BUMP_DOWN, 0)
	_addr(program, InstructionDef.Op.BUMP_UP, 0)
	for i in add_count:
		_addr(program, InstructionDef.Op.ADD, 0)
	_add(program, InstructionDef.Op.OUTBOX)
	var repeat := _add(program, InstructionDef.Op.JUMP)
	repeat.jump_target_id = start.id
	return program

func _sub_hallway_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	_add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 1)
	_addr(program, InstructionDef.Op.COPYFROM, 0)
	_addr(program, InstructionDef.Op.SUB, 1)
	_add(program, InstructionDef.Op.OUTBOX)
	var repeat := _add(program, InstructionDef.Op.JUMP)
	repeat.jump_target_id = start.id
	return program

func _equalization_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	_add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 1)
	_addr(program, InstructionDef.Op.COPYFROM, 0)
	_addr(program, InstructionDef.Op.SUB, 1)
	var equal := _add(program, InstructionDef.Op.JUMP_IF_ZERO)
	var skip := _add(program, InstructionDef.Op.JUMP)
	var output := _add(program, InstructionDef.Op.OUTBOX)
	var repeat := _add(program, InstructionDef.Op.JUMP)
	equal.jump_target_id = output.id
	skip.jump_target_id = start.id
	repeat.jump_target_id = start.id
	return program

func _mod_module_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	var subtract := _addr(program, InstructionDef.Op.SUB, 0)
	var negative := _add(program, InstructionDef.Op.JUMP_IF_NEG)
	var repeat_subtract := _add(program, InstructionDef.Op.JUMP)
	var recover := _addr(program, InstructionDef.Op.ADD, 0)
	_add(program, InstructionDef.Op.OUTBOX)
	var repeat_input := _add(program, InstructionDef.Op.JUMP)
	negative.jump_target_id = recover.id
	repeat_subtract.jump_target_id = subtract.id
	repeat_input.jump_target_id = start.id
	return program

func _add(program: Program, op: InstructionDef.Op) -> Instruction:
	var instruction := Instruction.new(op)
	program.add(instruction)
	return instruction

func _addr(program: Program, op: InstructionDef.Op, address: int) -> Instruction:
	var instruction := _add(program, op)
	instruction.address = address
	return instruction
