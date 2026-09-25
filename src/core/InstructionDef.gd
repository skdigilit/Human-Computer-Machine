class_name InstructionDef
extends RefCounted

## Central catalogue describing every instruction the machine understands.
## Keeping all per-opcode metadata (display name, colour, whether it needs an
## operand or a jump target) in one place means the UI and the VM never disagree
## about how an instruction behaves.

## The complete set of opcodes available in the game.
enum Op {
	INBOX,        ## Grab the next value from the inbox into the worker's hands.
	OUTBOX,       ## Drop the held value onto the outbox.
	COPYFROM,     ## Copy a value from a memory tile into the worker's hands.
	COPYTO,       ## Copy the held value onto a memory tile.
	ADD,          ## Add a memory tile's value to the held value.
	SUB,          ## Subtract a memory tile's value from the held value.
	BUMP_UP,      ## Increment a memory tile by one; the result ends up in hands.
	BUMP_DOWN,    ## Decrement a memory tile by one; the result ends up in hands.
	JUMP,         ## Unconditionally continue from another instruction.
	JUMP_IF_ZERO, ## Jump only when the held value equals zero.
	JUMP_IF_NEG,  ## Jump only when the held value is negative.
	# --- Snake mode (see src/snake). Appended so saved integer opcodes stay stable.
	TICK,         ## "wait": pause for the stepper's time, clearing the key latch (a game tick).
	JUMP_IF,      ## Jump when a chosen game condition holds (key pressed / head on tile).
	FACE,         ## Point the snake in a chosen direction.
	MOVE,         ## Read a direction key from Snake memory and move one cell.
	EAT,          ## Eat the food under the head: score, grow, spawn new food.
	GAME_OVER,    ## End the game and show the score.
	WRITE,        ## Snake: put a chosen number into a memory slot.
	FACE_FROM,    ## Snake: face the direction stored in a memory slot.
	KEY_PRESS,    ## Snake: copy the latest pressed key into a memory slot.
	IF,           ## Snake: execute the enclosed commands when the condition holds.
	END_IF,       ## Structural closing brace; created with IF.
}

## How an instruction consumes its operand, used by the UI to decide what kind
## of editing affordance to show next to the block.
enum OperandKind {
	NONE,    ## No operand (e.g. inbox / outbox).
	ADDRESS, ## A memory tile index, cycled by clicking the operand chip.
	JUMP,    ## A target instruction, chosen by the jump-target picker.
}

## A second, independent operand slot. A jump can carry one of these on top of
## its target (e.g. "jump if [key ←] -> 07"), which the address/jump
## OperandKind above cannot express. Stored in Instruction.param as an int.
enum ParamKind {
	NONE,    ## No extra parameter.
	CHOICE,  ## An index into choices_for(op); picked from an icon menu.
	STEPPER, ## A number nudged with -/+ buttons (see stepper_range_for).
}

## Snake "jump if" conditions, in menu order. Values are the Instruction.param
## the chip stores, so reordering this enum would silently change saved programs.
enum Condition {
	KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, ## The arrow key was pressed since the last tick.
	ON_FOOD,  ## The head sits on the food.
	ON_TAIL,  ## The head ran into the snake's own body.
	ON_WALL,  ## The head left the grid.
}

## Snake headings, in menu order (also the Instruction.param for FACE).
enum Direction { LEFT, UP, RIGHT, DOWN }

## Stepper values are stored as integer tenths of a second so save files stay
## all-int and repeated +/- presses never drift.
const TICK_STEPPER_MIN := 1
const TICK_STEPPER_MAX := 30
const TICK_STEPPER_STEP := 1
const TICK_STEPPER_DEFAULT := 5

## Palette colours echo the original game: green for inbox, teal for outbox,
## salmon for memory moves, orange for arithmetic, blue/lavender for control
## flow. Inbox and outbox split the I/O family by hue so an input and an output
## station never read the same at a glance.
const COLOR_IO := "#7DA33B"
const COLOR_OUTBOX := "#3E9E96"
const COLOR_MEMORY := "#C76B5A"
const COLOR_MATH := "#D98E3B"
const COLOR_JUMP := "#7B86C4"
## Snake families: violet for the clock, mint for snake actions, rose for the end.
const COLOR_TICK := "#9B6BC9"
const COLOR_SNAKE := "#3FA37A"
const COLOR_END := "#B9485C"

## The family glyph shown alongside a command so the action reads at a glance:
## arrows for I/O, vertical arrows for memory, +/- for math, the hook for jump.
## The UI renders this glyph in its own, larger label (see InstructionBlock),
## so it is kept separate from the command word here.
static func glyph_for(op: Op) -> String:
	match op:
		Op.INBOX: return "\u2192"        # ->
		Op.OUTBOX: return "\u2192"       # ->
		Op.COPYFROM: return "\u2193"     # down, onto the floor
		Op.COPYTO: return "\u2191"       # up, off the floor
		Op.ADD: return "+"
		Op.SUB: return "\u2212"          # minus
		Op.BUMP_UP: return "\u25B2"      # up triangle
		Op.BUMP_DOWN: return "\u25BC"    # down triangle
		Op.WRITE: return "\u2191"
		Op.FACE_FROM: return "\u2193"
		Op.JUMP, Op.JUMP_IF_ZERO, Op.JUMP_IF_NEG, Op.JUMP_IF: return "\u21B4"  # hook
	return ""

## SF Symbol drawn in place of the text glyph when non-empty. Snake commands
## lean on icons so young players can read a block without the word.
static func icon_for(op: Op) -> String:
	match op:
		Op.TICK: return "timer"
		Op.JUMP_IF: return "arrow.turn.down.right"
		Op.FACE: return "location.north.fill"
		Op.MOVE: return ""
		Op.EAT: return "fork.knife"
		Op.GAME_OVER: return "flag.checkered"
	return ""

## The command word, lowercase one-words matching the design system's style.
static func word_for(op: Op) -> String:
	match op:
		Op.INBOX: return "inbox"
		Op.OUTBOX: return "outbox"
		Op.COPYFROM: return "copyfrom"
		Op.COPYTO: return "copyto"
		Op.ADD: return "add"
		Op.SUB: return "sub"
		Op.BUMP_UP: return "bump+"
		Op.BUMP_DOWN: return "bump-"
		Op.JUMP: return "jump"
		Op.JUMP_IF_ZERO: return "jump =0"
		Op.JUMP_IF_NEG: return "jump <0"
		Op.TICK: return "wait"
		Op.JUMP_IF: return "jump if"
		Op.IF: return "if"
		Op.END_IF: return ""
		Op.FACE: return "face"
		Op.MOVE: return "move"
		Op.EAT: return "eat"
		Op.GAME_OVER: return "game over"
		Op.WRITE: return "write"
		Op.FACE_FROM: return "face from"
		Op.KEY_PRESS: return "key press"
	return "?"

## Whether the glyph precedes the word. Outbox trails its arrow ("outbox ->")
## to suggest a value leaving; every other command leads with its glyph.
static func glyph_leads(op: Op) -> bool:
	return op != Op.OUTBOX

## Combined single-string label (glyph + word). Used for debug / headless text;
## the interactive UI builds the two parts separately so it can size the glyph.
static func label_for(op: Op) -> String:
	if glyph_leads(op):
		return glyph_for(op) + " " + word_for(op)
	return word_for(op) + " " + glyph_for(op)

## Block fill colour for an opcode, grouped by behaviour family.
static func color_for(op: Op) -> Color:
	match op:
		Op.INBOX:
			return Color.html(COLOR_IO)
		Op.OUTBOX:
			return Color.html(COLOR_OUTBOX)
		Op.COPYFROM, Op.COPYTO, Op.WRITE, Op.FACE_FROM, Op.KEY_PRESS:
			return Color.html(COLOR_MEMORY)
		Op.ADD, Op.SUB, Op.BUMP_UP, Op.BUMP_DOWN:
			return Color.html(COLOR_MATH)
		Op.JUMP, Op.JUMP_IF_ZERO, Op.JUMP_IF_NEG, Op.JUMP_IF, Op.IF, Op.END_IF:
			return Color.html(COLOR_JUMP)
		Op.TICK:
			return Color.html(COLOR_TICK)
		Op.FACE, Op.MOVE, Op.EAT:
			return Color.html(COLOR_SNAKE)
		Op.GAME_OVER:
			return Color.html(COLOR_END)
	return Color.WHITE

## One-line explanation shown as a hover tooltip on a command block, so players
## can learn what each instruction does without leaving the editor.
static func tooltip_for(op: Op) -> String:
	match op:
		Op.INBOX:
			return "inbox\nGrab the next value from the IN tray into your hands."
		Op.OUTBOX:
			return "outbox\nDrop the value in your hands onto the OUT tray."
		Op.COPYFROM:
			return "copyfrom [tile]\nCopy the tile's value into your hands. The tile keeps its value.\nClick the number to choose the tile."
		Op.COPYTO:
			return "copyto [tile]\nCopy the value in your hands onto a tile. You keep holding it.\nClick the number to choose the tile."
		Op.ADD:
			return "add [tile]\nAdd the tile's value to the value in your hands."
		Op.SUB:
			return "sub [tile]\nSubtract the tile's value from the value in your hands."
		Op.BUMP_UP:
			return "bump+ [tile]\nAdd 1 to this memory tile. In Snake, using another slot makes it visible."
		Op.BUMP_DOWN:
			return "bump- [tile]\nSubtract 1 from this memory tile."
		Op.JUMP:
			return "jump\nAlways continue from the target line.\nClick the arrow to choose the target."
		Op.JUMP_IF_ZERO:
			return "jump =0\nJump to the target line only if the held value is zero."
		Op.JUMP_IF_NEG:
			return "jump <0\nJump to the target line only if the held value is negative."
		Op.TICK:
			return "wait [time] ->\nStay on this line for the full shown time, then go to the arrow's target.\nKeys pressed during WAIT are available to KEY PRESS.\nUse - and + to change the time. With no target, continue to the next line."
		Op.IF:
			return "if [condition]\nRun the commands inside the brace only when this condition is true.\nDrop commands above the closing brace to put them inside. Drag the header to move the whole block."
		Op.END_IF:
			return "End of IF. Drop above this bar to add a command inside; drop below it to continue outside."
		Op.JUMP_IF:
			return "jump if [condition]\nJump to the target line only if the condition is true right now.\nClick the picture to choose: an arrow key, or what the head is on."
		Op.FACE:
			return "face [direction]\nTurn the snake to face that way. It cannot turn straight back on itself."
		Op.MOVE:
			return "move [slot] [key]\nRead the key shown in this memory slot. An arrow key turns and moves the snake; another character stays visible but does not move it."
		Op.EAT:
			return "eat\nEat the food under the head: +1 score, grow longer, new food appears."
		Op.GAME_OVER:
			return "game over\nStop the game and show the final score."
		Op.WRITE:
			return "write [number] [slot]\nPut a number into a memory slot. In Snake, only a recorded arrow key steers MOVE."
		Op.FACE_FROM:
			return "face from [slot]\nTurn using the direction stored in this memory slot."
		Op.KEY_PRESS:
			return "key press [slot]\nStart recording every printable or arrow key in this memory slot, even during WAIT. A key pressed earlier is copied here when this line runs."
	return ""

## What kind of operand (if any) this opcode carries.
static func operand_kind_for(op: Op) -> OperandKind:
	match op:
		Op.COPYFROM, Op.COPYTO, Op.ADD, Op.SUB, Op.BUMP_UP, Op.BUMP_DOWN, Op.WRITE, Op.FACE_FROM, Op.KEY_PRESS, Op.MOVE:
			return OperandKind.ADDRESS
		Op.JUMP, Op.JUMP_IF_ZERO, Op.JUMP_IF_NEG, Op.JUMP_IF:
			return OperandKind.JUMP
		Op.TICK:
			# The clock closes its own loop: it pauses, then continues from its
			# target line, so one block is the whole game tick. An unset target
			# falls through to the next line (see SnakeVM._exec_tick), which is
			# what every program saved before the target existed does.
			return OperandKind.JUMP
	return OperandKind.NONE

## What kind of extra parameter (if any) this opcode carries.
static func param_kind_for(op: Op) -> ParamKind:
	match op:
		Op.TICK, Op.WRITE:
			return ParamKind.STEPPER
		Op.JUMP_IF, Op.IF, Op.FACE:
			return ParamKind.CHOICE
	return ParamKind.NONE

## Menu entries for a CHOICE parameter: [{"icon": sf_symbol, "label": text}, ...].
## The array index is the value stored in Instruction.param.
static func choices_for(op: Op) -> Array[Dictionary]:
	match op:
		Op.JUMP_IF, Op.IF:
			return [
				{"icon": "arrow.left.square.fill", "label": "key left"},
				{"icon": "arrow.up.square.fill", "label": "key up"},
				{"icon": "arrow.right.square.fill", "label": "key right"},
				{"icon": "arrow.down.square.fill", "label": "key down"},
				{"icon": "carrot.fill", "label": "on food"},
				{"icon": "ellipsis", "label": "on tail"},
				{"icon": "rectangle.split.3x3", "label": "on wall"},
			]
		Op.FACE:
			return [
				{"icon": "arrow.left", "label": "left"},
				{"icon": "arrow.up", "label": "up"},
				{"icon": "arrow.right", "label": "right"},
				{"icon": "arrow.down", "label": "down"},
			]
	return []

## Inclusive [min, max, step] for a STEPPER parameter, in the op's own units
## (tenths of a second for tick).
static func stepper_range_for(op: Op) -> Vector3i:
	match op:
		Op.TICK:
			return Vector3i(TICK_STEPPER_MIN, TICK_STEPPER_MAX, TICK_STEPPER_STEP)
		Op.WRITE:
			return Vector3i(-9, 99, 1)
	return Vector3i(0, 0, 1)

## Starting parameter for a freshly placed block.
static func default_param_for(op: Op) -> int:
	match op:
		Op.TICK:
			return TICK_STEPPER_DEFAULT
		Op.WRITE:
			return 0
		Op.IF:
			return Condition.ON_FOOD
		Op.FACE:
			return Direction.RIGHT
	return 0

## Human-readable form of a parameter, used for stepper chips and debug text.
static func param_text_for(op: Op, param: int) -> String:
	match param_kind_for(op):
		ParamKind.STEPPER:
			return "%.1fs" % (param / 10.0) if op == Op.TICK else str(param)
		ParamKind.CHOICE:
			var choices := choices_for(op)
			if param >= 0 and param < choices.size():
				return String(choices[param]["label"])
			return "?"
	return ""
