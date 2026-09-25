class_name SnakeKey
extends RefCounted

## Key values live in the same integer memory as counters. Arrow keys use
## Godot's keycodes; printable keys use their Unicode code point.

const NONE := StepAction.NULL_VALUE

static func from_event(event: InputEventKey) -> int:
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
		return NONE
	match event.keycode:
		KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN:
			return event.keycode
	if event.unicode >= 32 and event.unicode != 127:
		return event.unicode
	if event.keycode >= 32 and event.keycode <= 126:
		return event.keycode
	return NONE

static func direction_for(value: int) -> int:
	match value:
		KEY_LEFT, InstructionDef.Direction.LEFT:
			return InstructionDef.Direction.LEFT
		KEY_UP, InstructionDef.Direction.UP:
			return InstructionDef.Direction.UP
		KEY_RIGHT, InstructionDef.Direction.RIGHT:
			return InstructionDef.Direction.RIGHT
		KEY_DOWN, InstructionDef.Direction.DOWN:
			return InstructionDef.Direction.DOWN
	return -1

static func display(value: int) -> String:
	match direction_for(value):
		InstructionDef.Direction.LEFT: return "←"
		InstructionDef.Direction.UP: return "↑"
		InstructionDef.Direction.RIGHT: return "→"
		InstructionDef.Direction.DOWN: return "↓"
	if value == NONE:
		return "—"
	if value == 32:
		return "␣"
	if value >= 32 and value <= 0x10FFFF and value != 127:
		return char(value)
	return str(value)
