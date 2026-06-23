extends SceneTree

## Headless sanity check: builds a hand-written compare-and-swap solution for
## the sorting level and asserts the VM reports a win. Run with:
##   Godot --headless --script tests/test_sorting_solvable.gd

func _init() -> void:
	var level := LevelLibrary.sorting_floor()
	var program := _build_solution()
	var vm := VM.new(level, program)

	var last: StepAction = null
	while true:
		last = vm.step()
		if last.halted:
			break

	print("outbox      = ", vm.outbox)
	print("expected    = ", level.expected_outbox)
	print("steps taken = ", vm.steps_taken)
	print("message     = ", last.message)
	if last.success:
		print("RESULT: PASS")
	else:
		print("RESULT: FAIL")
	quit()

## Helper that appends an opcode and returns the created Instruction so callers
## can set operands / jump targets fluently.
func _add(program: Program, op: InstructionDef.Op) -> Instruction:
	var inst := Instruction.new(op)
	program.add(inst)
	return inst

func _addr(program: Program, op: InstructionDef.Op, address: int) -> Instruction:
	var inst := _add(program, op)
	inst.address = address
	return inst

## Selection of 3 numbers via three compare-and-swaps using tile 3 as scratch.
func _build_solution() -> Program:
	var p := Program.new()
	# Load inbox -> tiles 0,1,2.
	_add(p, InstructionDef.Op.INBOX); _addr(p, InstructionDef.Op.COPYTO, 0)
	_add(p, InstructionDef.Op.INBOX); _addr(p, InstructionDef.Op.COPYTO, 1)
	_add(p, InstructionDef.Op.INBOX); _addr(p, InstructionDef.Op.COPYTO, 2)

	var l1 := _compare_swap(p, 0, 1)
	var l2 := _compare_swap(p, 1, 2)
	var l3 := _compare_swap(p, 0, 1)

	# Output 0,1,2 in order.
	var out0 := _addr(p, InstructionDef.Op.COPYFROM, 0)
	_add(p, InstructionDef.Op.OUTBOX)
	_addr(p, InstructionDef.Op.COPYFROM, 1); _add(p, InstructionDef.Op.OUTBOX)
	_addr(p, InstructionDef.Op.COPYFROM, 2); _add(p, InstructionDef.Op.OUTBOX)
	l1.done.jump_target_id = l2.start.id
	l2.done.jump_target_id = l3.start.id
	l3.done.jump_target_id = out0.id
	return p

## Compare-and-swap under move semantics.
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
