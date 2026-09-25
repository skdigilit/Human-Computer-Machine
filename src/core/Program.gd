class_name Program
extends RefCounted

## Ordered list of instructions that make up the player's solution.
## This is a thin, UI-agnostic container; the ProgramListView mirrors it
## visually and the VM reads from it during execution.

var instructions: Array[Instruction] = []

## Append a new instruction to the end of the program.
func add(instruction: Instruction) -> void:
	instructions.append(instruction)

## Insert an instruction at a specific index (used by drag-and-drop drops).
func insert_at(index: int, instruction: Instruction) -> void:
	index = clampi(index, 0, instructions.size())
	instructions.insert(index, instruction)

## Remove and return the instruction at index, or null when out of range.
func remove_at(index: int) -> Instruction:
	if index < 0 or index >= instructions.size():
		return null
	var closing := matching_end_if(index)
	if closing > index:
		instructions.remove_at(closing)
	return instructions.pop_at(index)

## Current line count.
func size() -> int:
	return instructions.size()

## Find the array index of an instruction by its stable id, or -1.
func index_of_id(target_id: int) -> int:
	for i in instructions.size():
		if instructions[i].id == target_id:
			return i
	return -1

## Remove every line; used when the player resets the level.
func clear() -> void:
	instructions.clear()

## Convert the program to JSON-safe data. Jump targets are stored as line
## indexes so they remain valid when fresh instruction ids are assigned later.
func to_data() -> Array:
	var data: Array = []
	for instruction in instructions:
		data.append({
			"op": int(instruction.op),
			"address": instruction.address,
			"jump_target": index_of_id(instruction.jump_target_id),
			"param": instruction.param,
		})
	return data

## Recreate a program previously produced by to_data().
static func from_data(data: Array) -> Program:
	var loaded := Program.new()
	var jump_targets: Array[int] = []
	for value in data:
		if not value is Dictionary:
			continue
		var instruction := Instruction.new(clampi(int(value.get("op", 0)), 0, InstructionDef.Op.size() - 1))
		instruction.address = int(value.get("address", 0))
		# Older saves have no param; keep the opcode's default in that case.
		instruction.param = int(value.get("param", instruction.param))
		loaded.add(instruction)
		jump_targets.append(int(value.get("jump_target", -1)))

	for i in mini(loaded.size(), jump_targets.size()):
		var target_index := jump_targets[i]
		if target_index >= 0 and target_index < loaded.size():
			loaded.instructions[i].jump_target_id = loaded.instructions[target_index].id
	return loaded

## The flat save format keeps old opcode values and jump targets intact.
## Matching braces are structural, so nested blocks need no saved length.
func matching_end_if(index: int) -> int:
	if index < 0 or index >= size() or instructions[index].op != InstructionDef.Op.IF:
		return -1
	var depth := 0
	for i in range(index, size()):
		if instructions[i].op == InstructionDef.Op.IF:
			depth += 1
		elif instructions[i].op == InstructionDef.Op.END_IF:
			depth -= 1
			if depth == 0:
				return i
	return -1

## Move a complete IF group together; ordinary instructions move individually.
func move_group(from: int, destination: int) -> void:
	var end := matching_end_if(from)
	if end < 0:
		end = from
	if destination >= from and destination <= end + 1:
		return
	var group := instructions.slice(from, end + 1)
	for i in group.size():
		instructions.remove_at(from)
	if destination > end:
		destination -= group.size()
	for i in group.size():
		instructions.insert(clampi(destination + i, 0, size()), group[i])
