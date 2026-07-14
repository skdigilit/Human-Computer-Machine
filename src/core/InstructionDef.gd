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
}

## How an instruction consumes its operand, used by the UI to decide what kind
## of editing affordance to show next to the block.
enum OperandKind {
	NONE,    ## No operand (e.g. inbox / outbox).
	ADDRESS, ## A memory tile index, cycled by clicking the operand chip.
	JUMP,    ## A target instruction, chosen by the jump-target picker.
}

## Palette colours echo the original game: green for inbox, teal for outbox,
## salmon for memory moves, orange for arithmetic, blue/lavender for control
## flow. Inbox and outbox split the I/O family by hue so an input and an output
## station never read the same at a glance.
const COLOR_IO := "#7DA33B"
const COLOR_OUTBOX := "#3E9E96"
const COLOR_MEMORY := "#C76B5A"
const COLOR_MATH := "#D98E3B"
const COLOR_JUMP := "#7B86C4"

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
		Op.JUMP, Op.JUMP_IF_ZERO, Op.JUMP_IF_NEG: return "\u21B4"  # hook
	return "?"

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
		Op.COPYFROM, Op.COPYTO:
			return Color.html(COLOR_MEMORY)
		Op.ADD, Op.SUB, Op.BUMP_UP, Op.BUMP_DOWN:
			return Color.html(COLOR_MATH)
		Op.JUMP, Op.JUMP_IF_ZERO, Op.JUMP_IF_NEG:
			return Color.html(COLOR_JUMP)
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
			return "bump+ [tile]\nAdd 1 to the tile, then hold the result."
		Op.BUMP_DOWN:
			return "bump- [tile]\nSubtract 1 from the tile, then hold the result."
		Op.JUMP:
			return "jump\nAlways continue from the target line.\nClick the arrow to choose the target."
		Op.JUMP_IF_ZERO:
			return "jump =0\nJump to the target line only if the held value is zero."
		Op.JUMP_IF_NEG:
			return "jump <0\nJump to the target line only if the held value is negative."
	return ""

## What kind of operand (if any) this opcode carries.
static func operand_kind_for(op: Op) -> OperandKind:
	match op:
		Op.COPYFROM, Op.COPYTO, Op.ADD, Op.SUB, Op.BUMP_UP, Op.BUMP_DOWN:
			return OperandKind.ADDRESS
		Op.JUMP, Op.JUMP_IF_ZERO, Op.JUMP_IF_NEG:
			return OperandKind.JUMP
	return OperandKind.NONE
