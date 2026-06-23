class_name VM
extends RefCounted

## The little office computer. Executes a Program one instruction at a time
## over a level's inbox / memory / outbox state, returning a StepAction that
## fully describes each step so the presentation layer can replay it.
##
## The VM is deliberately free of any node / scene dependencies so the whole
## execution model can be unit tested from a headless script.

var _level: Level
var _program: Program

## Remaining inbox values (front = next to be grabbed).
var inbox: Array[int] = []
## Values dropped onto the outbox so far, in order.
var outbox: Array[int] = []
## Memory tiles; uninitialised tiles hold NULL_VALUE.
var memory: Array[int] = []
## Value currently in the worker's hands, or NULL_VALUE when empty.
var held: int = StepAction.NULL_VALUE
## Program counter: index of the next instruction to execute.
var pc: int = 0
## Number of instructions executed; used as a runaway-loop guard.
var steps_taken: int = 0

const MAX_STEPS := 10000

func _init(level: Level, program: Program) -> void:
	_level = level
	_program = program
	reset()

## Restore the machine to the level's starting state.
func reset() -> void:
	inbox = _level.inbox.duplicate()
	outbox = []
	memory = []
	for i in _level.memory_size:
		memory.append(_level.initial_memory.get(i, StepAction.NULL_VALUE))
	held = StepAction.NULL_VALUE
	pc = 0
	steps_taken = 0

## True once the program counter has run off the end of the program.
func is_finished() -> bool:
	return pc >= _program.size()

## Execute the instruction at the program counter and return its StepAction.
## Returns a halted action when the program ends, errors, or loops forever.
func step() -> StepAction:
	var action := StepAction.new()

	if is_finished():
		return _finish(action, _is_win(), _win_or_progress_message())

	steps_taken += 1
	if steps_taken > MAX_STEPS:
		return _finish(action, false, "The worker got stuck in an endless loop!")

	var inst: Instruction = _program.instructions[pc]
	action.op = inst.op
	action.line_index = pc

	match inst.op:
		InstructionDef.Op.INBOX:
			_exec_inbox(action)
		InstructionDef.Op.OUTBOX:
			_exec_outbox(action)
		InstructionDef.Op.COPYFROM:
			_exec_copyfrom(action, inst)
		InstructionDef.Op.COPYTO:
			_exec_copyto(action, inst)
		InstructionDef.Op.ADD:
			_exec_arith(action, inst, true)
		InstructionDef.Op.SUB:
			_exec_arith(action, inst, false)
		InstructionDef.Op.BUMP_UP:
			_exec_bump(action, inst, 1)
		InstructionDef.Op.BUMP_DOWN:
			_exec_bump(action, inst, -1)
		InstructionDef.Op.JUMP, InstructionDef.Op.JUMP_IF_ZERO, InstructionDef.Op.JUMP_IF_NEG:
			_exec_jump(action, inst)

	if action.halted:
		return action

	# Non-jump instructions simply advance to the next line.
	if not inst.is_jump():
		pc += 1
	return action

# --- Individual opcode handlers -------------------------------------------------

func _exec_inbox(action: StepAction) -> void:
	if inbox.is_empty():
		# Running out of inbox is the normal way a correct program ends.
		_finish(action, _is_win(), _win_or_progress_message())
		return
	held = inbox.pop_front()
	action.source = StepAction.Source.INBOX
	action.held_value = held

func _exec_outbox(action: StepAction) -> void:
	if held == StepAction.NULL_VALUE:
		_finish(action, false, "Tried to OUTBOX with empty hands.")
		return
	outbox.append(held)
	action.sink = StepAction.Sink.OUTBOX
	action.held_value = held
	held = StepAction.NULL_VALUE
	# Outputting a wrong value is an immediate, informative failure.
	var idx := outbox.size() - 1
	if idx >= _level.expected_outbox.size() or outbox[idx] != _level.expected_outbox[idx]:
		_finish(action, false, "Wrong value sent to the OUTBOX!")

func _exec_copyfrom(action: StepAction, inst: Instruction) -> void:
	if not _valid_tile(action, inst.address):
		return
	if memory[inst.address] == StepAction.NULL_VALUE:
		_finish(action, false, "That memory tile is empty.")
		return
	held = memory[inst.address]
	action.source = StepAction.Source.MEMORY
	action.address = inst.address
	action.held_value = held

func _exec_copyto(action: StepAction, inst: Instruction) -> void:
	if not _valid_tile(action, inst.address):
		return
	if held == StepAction.NULL_VALUE:
		_finish(action, false, "Tried to COPYTO with empty hands.")
		return
	memory[inst.address] = held
	action.sink = StepAction.Sink.MEMORY
	action.address = inst.address
	action.memory_changed = true
	action.memory_value = held
	action.held_value = held

func _exec_arith(action: StepAction, inst: Instruction, is_add: bool) -> void:
	if not _valid_tile(action, inst.address):
		return
	if held == StepAction.NULL_VALUE or memory[inst.address] == StepAction.NULL_VALUE:
		_finish(action, false, "Arithmetic needs a value in hand and on the tile.")
		return
	held += memory[inst.address] if is_add else -memory[inst.address]
	action.source = StepAction.Source.MEMORY
	action.address = inst.address
	action.held_value = held

func _exec_bump(action: StepAction, inst: Instruction, delta: int) -> void:
	if not _valid_tile(action, inst.address):
		return
	if memory[inst.address] == StepAction.NULL_VALUE:
		_finish(action, false, "That memory tile is empty.")
		return
	memory[inst.address] += delta
	held = memory[inst.address]
	action.source = StepAction.Source.MEMORY
	action.address = inst.address
	action.held_value = held
	action.memory_changed = true
	action.memory_value = held

func _exec_jump(action: StepAction, inst: Instruction) -> void:
	var should_jump := false
	match inst.op:
		InstructionDef.Op.JUMP:
			should_jump = true
		InstructionDef.Op.JUMP_IF_ZERO:
			should_jump = (held == 0)
		InstructionDef.Op.JUMP_IF_NEG:
			should_jump = (held != StepAction.NULL_VALUE and held < 0)
	action.held_value = held

	if not should_jump:
		pc += 1
		return

	var target := _program.index_of_id(inst.jump_target_id)
	if target == -1:
		_finish(action, false, "A jump has no target set.")
		return
	pc = target

# --- Helpers -------------------------------------------------------------------

## Validate a memory tile index, failing the run with a message if invalid.
func _valid_tile(action: StepAction, addr: int) -> bool:
	if addr < 0 or addr >= memory.size():
		_finish(action, false, "Referenced a memory tile that doesn't exist.")
		return false
	return true

## Stamp an action as halted and record the win/lose outcome.
func _finish(action: StepAction, won: bool, message: String) -> StepAction:
	action.halted = true
	action.success = won
	action.message = message
	return action

## A level is solved only when the outbox exactly matches the expected sequence.
func _is_win() -> bool:
	return outbox == _level.expected_outbox

func _win_or_progress_message() -> String:
	if _is_win():
		return "Level complete! The boss is pleased."
	return "The program ended without producing the right output."
