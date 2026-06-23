class_name Instruction
extends RefCounted

## A single instruction line inside the player's program.
## Each instruction carries a stable unique id so that jump instructions can
## point at a *specific* line even after the program is reordered (the original
## game anchors its label arrows the same way).

static var _next_id: int = 1

var id: int
var op: InstructionDef.Op
## Memory tile index for ADDRESS instructions (ignored otherwise).
var address: int = 0
## Id of the instruction this jump targets, or -1 when unset (JUMP ops only).
var jump_target_id: int = -1

func _init(p_op: InstructionDef.Op) -> void:
	id = _next_id
	_next_id += 1
	op = p_op

## True when this opcode needs a memory tile operand.
func uses_address() -> bool:
	return InstructionDef.operand_kind_for(op) == InstructionDef.OperandKind.ADDRESS

## True when this opcode is a (conditional or unconditional) jump.
func is_jump() -> bool:
	return InstructionDef.operand_kind_for(op) == InstructionDef.OperandKind.JUMP

## Human readable form, handy for debugging and headless tests.
func to_text() -> String:
	var text := InstructionDef.label_for(op)
	if uses_address():
		text += " " + str(address)
	elif is_jump():
		text += " ->#" + str(jump_target_id)
	return text
