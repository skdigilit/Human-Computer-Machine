class_name SnakeLevelLibrary
extends RefCounted

## Factory of the Snake mode levels. Each level unlocks a little more of the
## palette so the full game is built up one idea at a time: loop, steer, eat,
## then survive. Briefings follow the office convention — text before the
## first blank line is the task, the rest is the hint.

const CORE_PALETTE: Array[InstructionDef.Op] = [
	InstructionDef.Op.TICK,
	InstructionDef.Op.MOVE,
	InstructionDef.Op.JUMP,
]

static func _with_memory(level: SnakeLevel) -> SnakeLevel:
	level.memory_size = 3
	level.initial_memory = {0: KEY_RIGHT, 1: 0, 2: 0}
	return level

## The core loop commands plus `extra`, as a typed array (Array + Array drops
## the element type, which Level.palette rejects).
static func _palette(extra: Array[InstructionDef.Op]) -> Array[InstructionDef.Op]:
	var ops: Array[InstructionDef.Op] = CORE_PALETTE.duplicate()
	ops.append_array(extra)
	return ops

static func slither() -> SnakeLevel:
	var level := SnakeLevel.new()
	level.title = "Slither"
	level.briefing = (
		"Make the snake move by itself. Give each move a fixed WAIT.\n\n"
		+ "Slot 0 starts with the RIGHT arrow. Try MOVE [0], then WAIT 0.5s -> MOVE.\n"
		+ "WRITE and BUMP can change values in another memory slot; that slot appears when you use it.\n\n"
		+ "Hitting the wall is fine for this first lesson."
	)
	level.target_score = 0
	level.food_seed = 11
	level.palette = _palette([InstructionDef.Op.WRITE, InstructionDef.Op.BUMP_UP, InstructionDef.Op.BUMP_DOWN] as Array[InstructionDef.Op])
	return _with_memory(level)

static func steer() -> SnakeLevel:
	var level := SnakeLevel.new()
	level.title = "Steer"
	level.briefing = (
		"Turn the snake with the ARROW KEYS. Eat 1 food to finish.\n\n"
		+ "KEY PRESS [0] starts recording every key in the orange memory box, even during WAIT.\n"
		+ "Try KEY PRESS [0] -> WAIT -> MOVE [0] -> JUMP back to WAIT. MOVE shows the key it reads.\n"
		+ "A letter is stored too, but only an arrow key steers the snake. Put EAT inside IF [food] to eat only when the head reaches food."
	)
	level.target_score = 1
	level.food_seed = 23
	level.palette = _palette([
		InstructionDef.Op.IF,
		InstructionDef.Op.KEY_PRESS,
		InstructionDef.Op.WRITE,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.EAT,
	] as Array[InstructionDef.Op])
	return _with_memory(level)

static func snack_time() -> SnakeLevel:
	var level := SnakeLevel.new()
	level.title = "Snack Time"
	level.briefing = (
		"Eat 5 food. Each one makes the snake longer.\n\n"
		+ "Only EAT when the head is on food, or the machine stops.\n"
		+ "Shape: KEY PRESS [0], WAIT, MOVE [0], check for food, then loop back to WAIT.\n"
		+ "Put EAT inside an IF [food] brace. Commands inside run only when the condition is true."
	)
	level.target_score = 5
	level.food_seed = 37
	level.palette = _palette([
		InstructionDef.Op.IF,
		InstructionDef.Op.KEY_PRESS,
		InstructionDef.Op.WRITE,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.EAT,
	] as Array[InstructionDef.Op])
	return _with_memory(level)

static func walls_and_tail() -> SnakeLevel:
	var level := SnakeLevel.new()
	level.title = "Walls & Tail"
	level.briefing = (
		"Now the game must END properly. Hitting the wall or your own tail is GAME OVER. Eat 8 food.\n\n"
		+ "Right after MOVE, add IF [wall] and IF [tail], each with GAME OVER inside its brace.\n"
		+ "Check for food after those."
	)
	level.target_score = 8
	level.food_seed = 51
	level.palette = _palette([
		InstructionDef.Op.IF,
		InstructionDef.Op.KEY_PRESS,
		InstructionDef.Op.WRITE,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.EAT,
		InstructionDef.Op.GAME_OVER,
	] as Array[InstructionDef.Op])
	return _with_memory(level)

static func full_snake() -> SnakeLevel:
	var level := SnakeLevel.new()
	level.title = "Full Snake"
	level.briefing = (
		"Eat 15 food without crashing. Program the snake to get faster with every food it eats.\n\n"
		+ "The SPEED box (slot 1) starts at 1. Each WAIT lasts its chosen time divided by this box: 2 means twice as fast, 3 means three times as fast.\n"
		+ "Use BUMP+ [1] after EAT inside IF [food]. Keep the speed at 1 or more.\n"
		+ "(Programmers call one wait-and-move a \"tick\" of the game.)"
	)
	level.target_score = 15
	level.food_seed = 73
	level.palette = _palette([
		InstructionDef.Op.IF,
		InstructionDef.Op.KEY_PRESS,
		InstructionDef.Op.WRITE,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.EAT,
		InstructionDef.Op.GAME_OVER,
	] as Array[InstructionDef.Op])
	_with_memory(level)
	level.memory_size = 4
	level.wait_scale_slot = 1
	level.initial_memory[1] = 1
	level.initial_memory[3] = 0
	return level

static func all_levels() -> Array[Level]:
	return [
		slither(),
		steer(),
		snack_time(),
		walls_and_tail(),
		full_snake(),
	] as Array[Level]
