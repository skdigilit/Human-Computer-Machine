class_name SnakeVM
extends VM

## The Snake machine. Runs the same Program / jump model as the office VM but
## over a SnakeState and a small writable memory. Every step returns a
## SnakeStepAction; a WAIT step carries its exact duration and completes its
## jump only after the visible countdown finishes.
##
## Subclassing VM keeps Game.gd's typed `_vm: VM` and its run loop untouched.

var state: SnakeState
var memory_key_flags: Array[bool] = []
## Retained only for programs saved with the former four-row key-handler UI.
var key_handler_slots: Array[int] = [-1, -1, -1, -1]
var _pending_key: int = SnakeKey.NONE
var _recording_slots: Array[int] = []
var _waiting_target: int = -1
## Instructions run since the last tick; guards a frame that never ticks.
var _steps_since_tick: int = 0

func _init(level: Level, program: Program) -> void:
	super(level, program)

## Fresh board and student-owned memory from the level.
func reset() -> void:
	super.reset()
	var snake_level := _level as SnakeLevel
	state = SnakeState.new()
	state.reset(
		snake_level.effective_grid_size() if snake_level else SnakeState.DEFAULT_GRID_SIZE,
		snake_level.start_length if snake_level else 3,
		snake_level.food_seed if snake_level else 1
	)
	_steps_since_tick = 0
	_waiting_target = -1
	_pending_key = SnakeKey.NONE
	_recording_slots.clear()
	memory_key_flags.clear()
	for i in memory.size():
		memory_key_flags.append(i == 0)

## Capture the latest printable or arrow key. KEY PRESS arms a memory slot, so
## later presses update it immediately, including during WAIT.
func press_key(value: int) -> bool:
	if state == null:
		return false
	if value == SnakeKey.NONE:
		return false
	_pending_key = value
	for slot in _recording_slots:
		memory[slot] = value
		memory_key_flags[slot] = true
	var direction := SnakeKey.direction_for(value)
	if direction >= 0:
		state.press_key(direction as InstructionDef.Direction)
		if not _has_key_press_instruction() and direction < key_handler_slots.size():
			var legacy_slot := key_handler_slots[direction]
			if legacy_slot >= 0 and legacy_slot < memory.size():
				memory[legacy_slot] = direction
				memory_key_flags[legacy_slot] = true
	return true

func is_waiting() -> bool:
	return _waiting_target >= 0

## Called only after the visible countdown reaches its end.
func complete_wait() -> void:
	if _waiting_target >= 0:
		pc = _waiting_target
		_waiting_target = -1

func step() -> StepAction:
	var action := SnakeStepAction.new()
	action.state = state
	action.memory_values = memory.duplicate()
	action.memory_key_flags = memory_key_flags.duplicate()
	if is_waiting():
		return _finish(action, false, "WAIT is still counting down.")

	if is_finished():
		return _finish(action, false, "The program ended. Point the WAIT block's arrow back at the top so the snake keeps going.")

	steps_taken += 1
	_steps_since_tick += 1
	if _steps_since_tick > MAX_STEPS:
		return _finish(action, false, "Your loop never WAITs, so the snake never gets a turn. Add a WAIT inside the loop.")

	var inst: Instruction = _program.instructions[pc]
	action.op = inst.op
	action.line_index = pc

	match inst.op:
		InstructionDef.Op.TICK:
			_exec_tick(action, inst)
		InstructionDef.Op.JUMP, InstructionDef.Op.JUMP_IF:
			_exec_snake_jump(action, inst)
		InstructionDef.Op.IF:
			var closing := _program.matching_end_if(pc)
			if closing < 0:
				return _finish(action, false, "This IF is missing its closing brace.")
			if not _condition_holds(inst.param):
				pc = closing
		InstructionDef.Op.END_IF:
			pass
		InstructionDef.Op.FACE:
			_exec_face(action, inst)
		InstructionDef.Op.FACE_FROM:
			_exec_face_from(action, inst)
		InstructionDef.Op.KEY_PRESS:
			_exec_key_press(action, inst)
		InstructionDef.Op.WRITE:
			_exec_write(action, inst)
		InstructionDef.Op.BUMP_UP, InstructionDef.Op.BUMP_DOWN:
			_exec_bump_memory(action, inst)
		InstructionDef.Op.MOVE:
			_exec_move(action, inst)
		InstructionDef.Op.EAT:
			_exec_eat(action)
		InstructionDef.Op.GAME_OVER:
			_finish(action, false, "Game over! Score: %d" % state.score)
		_:
			_finish(action, false, "That command doesn't work in Snake.")

	if action.halted:
		return action
	if not inst.is_jump():
		pc += 1
	action.memory_values = memory.duplicate()
	action.memory_key_flags = memory_key_flags.duplicate()
	return action

func _has_key_press_instruction() -> bool:
	for instruction in _program.instructions:
		if instruction.op == InstructionDef.Op.KEY_PRESS:
			return true
	return false

func _uses_legacy_face_program() -> bool:
	if _has_key_press_instruction():
		return false
	for instruction in _program.instructions:
		if instruction.op == InstructionDef.Op.FACE or instruction.op == InstructionDef.Op.FACE_FROM:
			return true
	return false

# --- Opcode handlers ----------------------------------------------------------

## Hold the program counter on WAIT until the countdown finishes, then continue
## from its target line. Key presses during this interval can update memory.
##
## The clock carries its own jump target so one block is a whole game turn:
## pause, then loop back to the top. A target that is unset (or was deleted)
## falls through to the next line instead of erroring, which keeps every
## program written before the target existed running exactly as it did.
func _exec_tick(action: SnakeStepAction, inst: Instruction) -> void:
	state.clear_keys()
	_steps_since_tick = 0
	var speed := 1
	var snake_level := _level as SnakeLevel
	if snake_level and snake_level.wait_scale_slot >= 0:
		var slot := snake_level.wait_scale_slot
		if not _valid_tile(action, slot):
			return
		if memory_key_flags[slot] or memory[slot] == StepAction.NULL_VALUE or memory[slot] < 1:
			_finish(action, false, "The SPEED box needs a number of 1 or more. WRITE a number into slot %d." % slot)
			return
		speed = memory[slot]
	action.wait_seconds = maxf(0.0, inst.param / 10.0) / float(speed)
	var target := _program.index_of_id(inst.jump_target_id)
	_waiting_target = target if target != -1 else pc + 1

func _exec_snake_jump(action: SnakeStepAction, inst: Instruction) -> void:
	var should_jump := inst.op == InstructionDef.Op.JUMP or _condition_holds(inst.param)
	if not should_jump:
		pc += 1
		return
	var target := _program.index_of_id(inst.jump_target_id)
	if target == -1:
		_finish(action, false, "A jump has no target set.")
		return
	pc = target

## Evaluate a "jump if" condition (InstructionDef.Condition).
func _condition_holds(condition: int) -> bool:
	match condition:
		InstructionDef.Condition.KEY_LEFT: return state.key_pressed(InstructionDef.Direction.LEFT)
		InstructionDef.Condition.KEY_UP: return state.key_pressed(InstructionDef.Direction.UP)
		InstructionDef.Condition.KEY_RIGHT: return state.key_pressed(InstructionDef.Direction.RIGHT)
		InstructionDef.Condition.KEY_DOWN: return state.key_pressed(InstructionDef.Direction.DOWN)
		InstructionDef.Condition.ON_FOOD: return state.head_on_food()
		InstructionDef.Condition.ON_TAIL: return state.head_on_tail()
		InstructionDef.Condition.ON_WALL: return state.head_on_wall()
	return false

func _exec_face(action: SnakeStepAction, inst: Instruction) -> void:
	action.board_changed = state.face(inst.param as InstructionDef.Direction)

func _exec_face_from(action: SnakeStepAction, inst: Instruction) -> void:
	if not _valid_tile(action, inst.address):
		return
	var value := SnakeKey.direction_for(memory[inst.address])
	if value < 0:
		_finish(action, false, "FACE FROM needs a direction (0=left, 1=up, 2=right, 3=down).")
		return
	action.board_changed = state.face(value as InstructionDef.Direction)

func _exec_key_press(action: SnakeStepAction, inst: Instruction) -> void:
	if not _valid_tile(action, inst.address):
		return
	if not _recording_slots.has(inst.address):
		_recording_slots.append(inst.address)
	if _pending_key == SnakeKey.NONE:
		return
	memory[inst.address] = _pending_key
	memory_key_flags[inst.address] = true
	action.address = inst.address
	action.memory_changed = true
	action.memory_value = _pending_key
	_pending_key = SnakeKey.NONE

func _exec_write(action: SnakeStepAction, inst: Instruction) -> void:
	if not _valid_tile(action, inst.address):
		return
	memory[inst.address] = inst.param
	memory_key_flags[inst.address] = false
	action.address = inst.address
	action.memory_changed = true
	action.memory_value = inst.param

func _exec_bump_memory(action: SnakeStepAction, inst: Instruction) -> void:
	if not _valid_tile(action, inst.address):
		return
	if memory[inst.address] == StepAction.NULL_VALUE:
		_finish(action, false, "That memory slot is empty. WRITE a number first.")
		return
	var delta := 1 if inst.op == InstructionDef.Op.BUMP_UP else -1
	memory[inst.address] += delta
	memory_key_flags[inst.address] = false
	action.address = inst.address
	action.memory_changed = true
	action.memory_value = memory[inst.address]

## Moving while already off the board is the one move that fails: the player
## forgot to check for the wall, and the arena has nothing sensible to draw.
func _exec_move(action: SnakeStepAction, inst: Instruction) -> void:
	if not _uses_legacy_face_program():
		if not _valid_tile(action, inst.address):
			return
		var direction := SnakeKey.direction_for(memory[inst.address]) if memory_key_flags[inst.address] else -1
		if direction < 0:
			return
		action.board_changed = state.face(direction as InstructionDef.Direction)
	if state.head_on_wall():
		_finish(action, false, "The snake left the board! Use if [wall] to catch it.")
		return
	state.move()
	action.board_changed = true

func _exec_eat(action: SnakeStepAction) -> void:
	if not state.eat():
		_finish(action, false, "There's no food under the head. Check if [food] first.")
		return
	action.board_changed = true
	action.ate = true
	var snake_level := _level as SnakeLevel
	if snake_level and snake_level.target_score > 0 and state.score >= snake_level.target_score:
		_finish(action, true, "Level complete! Score: %d" % state.score)
