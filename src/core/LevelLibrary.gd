class_name LevelLibrary
extends RefCounted

## Factory of the game's built-in puzzles. Each builder returns a freshly
## configured Level, keeping puzzle definitions in one discoverable place.

static func mail_room() -> Level:
	var level := Level.new()
	level.title = "Mail Room"
	level.briefing = (
		"Send every number from PICK to SEND, in the same order.\n\n"
		+ "Start with INBOX and OUTBOX. Repeat those moves for every box."
	)
	level.inbox = [4, 2, 7] as Array[int]
	level.expected_outbox = [4, 2, 7] as Array[int]
	level.memory_size = 0
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
	] as Array[InstructionDef.Op]
	return level

static func busy_mail_room() -> Level:
	var level := Level.new()
	level.title = "Busy Mail Room"
	level.briefing = (
		"Send every number from PICK to SEND again.\n\n"
		+ "This time, use GO TO so the same small set of moves repeats until "
		+ "the PICK lane is empty."
	)
	level.inbox = [6, 1, 8, 3] as Array[int]
	level.expected_outbox = [6, 1, 8, 3] as Array[int]
	level.memory_size = 0
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.JUMP,
	] as Array[InstructionDef.Op]
	return level

static func swap_floor() -> Level:
	var level := Level.new()
	level.title = "Swap Floor"
	level.briefing = (
		"Two boxes arrive. Send the SECOND box first, then the FIRST box.\n\n"
		+ "Place both boxes on memory tiles, then pick them up in the new order."
	)
	level.inbox = [8, 3] as Array[int]
	level.expected_outbox = [3, 8] as Array[int]
	level.memory_size = 2
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
	] as Array[InstructionDef.Op]
	return level

static func add_one_room() -> Level:
	var level := Level.new()
	level.title = "Add One Room"
	level.briefing = (
		"Send every number after adding ONE.\n\n"
		+ "Tile 0 already holds a 1. Use ADD, then loop back for the next box."
	)
	level.inbox = [2, 5, 8] as Array[int]
	level.expected_outbox = [3, 6, 9] as Array[int]
	level.memory_size = 1
	level.initial_memory = {0: 1}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.ADD,
		InstructionDef.Op.JUMP,
	] as Array[InstructionDef.Op]
	return level

static func rainy_summer() -> Level:
	var level := Level.new()
	level.title = "Rainy Summer"
	level.briefing = (
		"Numbers arrive in PAIRS. Add each pair together and send the total.\n\n"
		+ "Place the first number on tile 0. Pick up the second number, ADD tile 0, "
		+ "then OUTBOX the result."
	)
	level.inbox = [2, 3, 5, 1, -2, 4] as Array[int]
	level.expected_outbox = [5, 6, 2] as Array[int]
	level.memory_size = 1
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.JUMP,
	] as Array[InstructionDef.Op]
	return level

static func zero_exterminator() -> Level:
	var level := Level.new()
	level.title = "Zero Exterminator"
	level.briefing = (
		"Send every number except ZERO.\n\n"
		+ "Use IF ZERO to skip zero boxes and loop back for the next number."
	)
	level.inbox = [4, 0, -2, 0, 7, 3] as Array[int]
	level.expected_outbox = [4, -2, 7, 3] as Array[int]
	level.memory_size = 0
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
	] as Array[InstructionDef.Op]
	return level

static func zero_preservation() -> Level:
	var level := Level.new()
	level.title = "Zero Preservation Initiative"
	level.briefing = (
		"Send only the ZERO boxes. Ignore every other number.\n\n"
		+ "IF ZERO follows its connected target when the box is zero. "
		+ "For any other number, it continues to the next command.\n\n"
		+ "Hint: use this shape:\n"
		+ "1. INBOX\n2. IF ZERO -> 4\n3. GO TO -> 1\n4. OUTBOX\n5. GO TO -> 1"
	)
	level.inbox = [0, 5, 0, -2, 3, 0] as Array[int]
	level.expected_outbox = [0, 0, 0] as Array[int]
	level.memory_size = 0
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
	] as Array[InstructionDef.Op]
	return level

static func countdown() -> Level:
	var level := Level.new()
	level.title = "Countdown"
	level.briefing = (
		"For each number, count down to ZERO and send every smaller number.\n\n"
		+ "Example: a 3 should send 2, 1, 0. Place the number on tile 0, then use "
		+ "TAKE 1 and IF ZERO."
	)
	level.inbox = [3, 2] as Array[int]
	level.expected_outbox = [2, 1, 0, 1, 0] as Array[int]
	level.memory_size = 1
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
	] as Array[InstructionDef.Op]
	return level

static func tripler_room() -> Level:
	var level := Level.new()
	level.title = "Tripler Room"
	level.briefing = (
		"Send each number multiplied by THREE.\n\n"
		+ "Place the number on tile 0. TAKE 1 and ADD 1 on that tile to hold a copy "
		+ "while leaving the same number on the tile. Then ADD tile 0 twice."
	)
	level.inbox = [2, -3, 4] as Array[int]
	level.expected_outbox = [6, -9, 12] as Array[int]
	level.memory_size = 1
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
	] as Array[InstructionDef.Op]
	return level

static func octoplier_suite() -> Level:
	var level := Level.new()
	level.title = "Octoplier Suite"
	level.briefing = (
		"Send each number multiplied by EIGHT.\n\n"
		+ "Use the same tile-copy trick from Tripler Room, then keep adding tile 0 "
		+ "until the held number is eight times larger."
	)
	level.inbox = [1, -2, 3] as Array[int]
	level.expected_outbox = [8, -16, 24] as Array[int]
	level.memory_size = 1
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
	] as Array[InstructionDef.Op]
	return level

static func sub_hallway() -> Level:
	var level := Level.new()
	level.title = "Sub Hallway"
	level.briefing = (
		"Numbers arrive in PAIRS. Subtract the SECOND number from the FIRST and "
		+ "send the result.\n\nPlace both numbers on tiles, then pick the first one "
		+ "and TAKE AWAY the second."
	)
	level.inbox = [8, 3, 2, 5, -1, -4] as Array[int]
	level.expected_outbox = [5, -3, 3] as Array[int]
	level.memory_size = 2
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.SUB,
		InstructionDef.Op.JUMP,
	] as Array[InstructionDef.Op]
	return level

static func equalization_room() -> Level:
	var level := Level.new()
	level.title = "Equalization Room"
	level.briefing = (
		"Numbers arrive in PAIRS. Send a ZERO only when both numbers are equal.\n\n"
		+ "Subtract the second number from the first. IF ZERO can send equal pairs "
		+ "to SEND while unequal pairs loop back to PICK."
	)
	level.inbox = [4, 4, 7, 2, -3, -3, 1, 5] as Array[int]
	level.expected_outbox = [0, 0] as Array[int]
	level.memory_size = 2
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.SUB,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
	] as Array[InstructionDef.Op]
	return level

static func tetracontiplier() -> Level:
	var level := Level.new()
	level.title = "Tetracontiplier"
	level.briefing = (
		"Multiply every number by FORTY and send the result.\n\n"
		+ "Build powers of two by storing a result and ADDing it to itself. "
		+ "Forty is thirty-two plus eight."
	)
	level.inbox = [1, -2, 3] as Array[int]
	level.expected_outbox = [40, -80, 120] as Array[int]
	level.memory_size = 5
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.JUMP,
	] as Array[InstructionDef.Op]
	return level

static func maximization_room() -> Level:
	var level := Level.new()
	level.title = "Maximization Room"
	level.briefing = (
		"Numbers arrive in PAIRS. Send only the BIGGER number from each pair. "
		+ "If they are equal, send either one.\n\n"
		+ "Subtract the first number from the second, then use IF MINUS to choose."
	)
	level.inbox = [3, 8, -2, -7, 5, 5] as Array[int]
	level.expected_outbox = [8, -2, 5] as Array[int]
	level.memory_size = 2
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func absolute_positivity() -> Level:
	var level := Level.new()
	level.title = "Absolute Positivity"
	level.briefing = (
		"Send the absolute value of every number. Positive numbers and zero stay "
		+ "the same; negative numbers must become positive.\n\n"
		+ "Tile 1 holds zero. For a negative number, store it and subtract it "
		+ "from zero."
	)
	level.inbox = [4, -7, 0, 3] as Array[int]
	level.expected_outbox = [4, 7, 0, 3] as Array[int]
	level.memory_size = 2
	level.initial_memory = {1: 0}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func exclusive_lounge() -> Level:
	var level := Level.new()
	level.title = "Exclusive Lounge"
	level.briefing = (
		"Numbers arrive in PAIRS. Send ZERO when both numbers have the same sign, "
		+ "or ONE when their signs differ.\n\n"
		+ "Use IF MINUS to follow a separate path for each sign. Tiles 4-7 hold "
		+ "the answers for the four pairs."
	)
	level.inbox = [3, 8, -2, -7, 4, -1, -5, 6] as Array[int]
	level.expected_outbox = [0, 0, 1, 1] as Array[int]
	level.memory_size = 8
	level.initial_memory = {4: 0, 5: 0, 6: 1, 7: 1}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func multiplication_workshop() -> Level:
	var level := Level.new()
	level.title = "Multiplication Workshop"
	level.briefing = (
		"Numbers arrive in PAIRS. Multiply each pair and send the result. "
		+ "You will only receive non-negative numbers.\n\n"
		+ "Multiplication is repeated addition. Keep a running total on a tile."
	)
	level.inbox = [3, 4, 2, 5, 0, 7] as Array[int]
	level.expected_outbox = [12, 10, 0] as Array[int]
	level.memory_size = 4
	level.initial_memory = {3: 0}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func zero_terminated_sum() -> Level:
	var level := Level.new()
	level.title = "Zero Terminated Sum"
	level.briefing = (
		"The PICK lane contains groups separated by ZERO. Add every number in a "
		+ "group, then send its sum when you reach the terminating zero.\n\n"
		+ "Reset the running total and repeat for each group."
	)
	level.inbox = [3, -1, 4, 0, 5, 2, 0, 0] as Array[int]
	level.expected_outbox = [6, 7, 0] as Array[int]
	level.memory_size = 4
	level.initial_memory = {1: 0, 2: 0, 3: 0}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func fibonacci_visitor() -> Level:
	var level := Level.new()
	level.title = "Fibonacci Visitor"
	level.briefing = (
		"For each number, send the Fibonacci sequence up to that number without "
		+ "exceeding it.\n\nExample: 10 sends 1, 1, 2, 3, 5, 8."
	)
	level.inbox = [10, 6] as Array[int]
	level.expected_outbox = [1, 1, 2, 3, 5, 8, 1, 1, 2, 3, 5] as Array[int]
	level.memory_size = 6
	level.initial_memory = {5: 0}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func littlest_number() -> Level:
	var level := Level.new()
	level.title = "The Littlest Number"
	level.briefing = (
		"The PICK lane contains non-empty groups separated by ZERO. Send only "
		+ "the SMALLEST number from each group.\n\n"
		+ "Keep the smallest value seen so far on a tile."
	)
	level.inbox = [7, 2, 5, 0, -1, -6, 3, 0, 4, 4, 0] as Array[int]
	level.expected_outbox = [2, -6, 4] as Array[int]
	level.memory_size = 2
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func cumulative_countdown() -> Level:
	var level := Level.new()
	level.title = "Cumulative Countdown"
	level.briefing = (
		"For every number, send the sum of that number and every positive number "
		+ "below it.\n\nExample: 3 sends 6 because 3 + 2 + 1 = 6."
	)
	level.inbox = [3, 5, 0, 1] as Array[int]
	level.expected_outbox = [6, 15, 0, 1] as Array[int]
	level.memory_size = 2
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func small_divide() -> Level:
	var level := Level.new()
	level.title = "Small Divide"
	level.briefing = (
		"Numbers arrive in PAIRS. Send how many times the SECOND number fully "
		+ "fits into the FIRST.\n\n"
		+ "There are no negative numbers, zero divisors, or remainders."
	)
	level.inbox = [8, 2, 15, 3, 12, 4] as Array[int]
	level.expected_outbox = [4, 5, 3] as Array[int]
	level.memory_size = 4
	level.initial_memory = {3: 0}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

static func mod_module() -> Level:
	var level := Level.new()
	level.title = "Mod Module"
	level.briefing = (
		"Send the REMAINDER left after dividing each number by THREE.\n\n"
		+ "Tile 0 holds a 3. Repeatedly TAKE AWAY tile 0. When the result is minus, "
		+ "ADD tile 0 once to recover the remainder."
	)
	level.inbox = [8, 4, 12, 2] as Array[int]
	level.expected_outbox = [2, 1, 0, 2] as Array[int]
	level.memory_size = 1
	level.initial_memory = {0: 3}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

## "The Sorting Floor" — grab three numbers from the inbox and send them to the
## outbox from smallest to largest. Tile 3 is free to use as swap scratch space.
##
## Solvable with compare-and-swap: subtract two stored values and use
## jump-if-negative to decide whether they are already in order.
static func sorting_floor() -> Level:
	var level := Level.new()
	level.title = "The Sorting Floor"
	level.briefing = (
		"Your job: send the THREE number boxes from smallest to biggest.\n\n"
		+ "1. Drag moves into the list below.\n"
		+ "2. Tap a small tile number to change it.\n"
		+ "3. Press RUN and watch your helper!\n\n"
		+ "Hint: place numbers on tiles 0-2. Picking a tile copies its value. "
		+ "Tile 3 is a spare."
	)
	level.inbox = [5, 1, 3] as Array[int]
	level.expected_outbox = [1, 3, 5] as Array[int]
	level.memory_size = 4
	level.initial_memory = {}
	level.palette = [
		InstructionDef.Op.INBOX,
		InstructionDef.Op.OUTBOX,
		InstructionDef.Op.COPYFROM,
		InstructionDef.Op.COPYTO,
		InstructionDef.Op.ADD,
		InstructionDef.Op.SUB,
		InstructionDef.Op.BUMP_UP,
		InstructionDef.Op.BUMP_DOWN,
		InstructionDef.Op.JUMP,
		InstructionDef.Op.JUMP_IF_ZERO,
		InstructionDef.Op.JUMP_IF_NEG,
	] as Array[InstructionDef.Op]
	return level

## The default level the game boots into.
static func default_level() -> Level:
	return mail_room()

## Built-in progression, inspired by Human Resource Machine's early levels.
static func all_levels() -> Array[Level]:
	return [
		mail_room(),
		busy_mail_room(),
		swap_floor(),
		add_one_room(),
		rainy_summer(),
		zero_exterminator(),
		zero_preservation(),
		countdown(),
		tripler_room(),
		octoplier_suite(),
		sub_hallway(),
		equalization_room(),
		mod_module(),
		sorting_floor(),
		tetracontiplier(),
		maximization_room(),
		absolute_positivity(),
		exclusive_lounge(),
		multiplication_workshop(),
		zero_terminated_sum(),
		fibonacci_visitor(),
		littlest_number(),
		cumulative_countdown(),
		small_divide(),
	] as Array[Level]
