extends SceneTree

## Verifies the published 14-line Tetracontiplier solution works unchanged.
## Source: https://atesgoral.github.io/hrm-solutions/

func _init() -> void:
	var level := LevelLibrary.tetracontiplier()
	var program := _build_solution()
	var vm := VM.new(level, program)
	var last: StepAction

	while true:
		last = vm.step()
		if last.halted:
			break

	var passed := last.success and vm.outbox == level.expected_outbox
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

func _build_solution() -> Program:
	var program := Program.new()
	var start := _add(program, InstructionDef.Op.INBOX)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	_addr(program, InstructionDef.Op.ADD, 0)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	_addr(program, InstructionDef.Op.ADD, 0)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	_addr(program, InstructionDef.Op.ADD, 0)
	_addr(program, InstructionDef.Op.COPYTO, 0)
	for i in 4:
		_addr(program, InstructionDef.Op.ADD, 0)
	_add(program, InstructionDef.Op.OUTBOX)
	var repeat := _add(program, InstructionDef.Op.JUMP)
	repeat.jump_target_id = start.id
	return program

func _add(program: Program, op: InstructionDef.Op) -> Instruction:
	var instruction := Instruction.new(op)
	program.add(instruction)
	return instruction

func _addr(program: Program, op: InstructionDef.Op, address: int) -> Instruction:
	var instruction := _add(program, op)
	instruction.address = address
	return instruction
