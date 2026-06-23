extends SceneTree

## Drives Godot's real drag-and-drop pipeline with synthetic mouse events to
## prove that (a) dragging a palette command into the list inserts it, and
## (b) dragging an existing line onto another reorders the program.
##   Godot --headless --script tests/test_drag_drop.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://game_main.tscn").instantiate()
	game._save_path = "user://test_drag_drop_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 6:
		await process_frame

	var palette: InstructionPalette = game._palette
	var list: ProgramListView = game._program_list

	# --- Test 1: drag the first palette command into the program. ---
	var src_block := _first_block(palette)
	await _drag(src_block.get_global_rect().get_center(), list.get_global_rect().get_center())
	for i in 4: await process_frame
	var size_after_insert: int = game._program.size()
	print("after palette drag, program size = ", size_after_insert)

	# Add a second, different command so we have something to reorder.
	var second_palette := _nth_block(palette, 2)
	await _drag(second_palette.get_global_rect().get_center(), list.get_global_rect().get_center())
	for i in 4: await process_frame
	print("program now = ", _ops(game._program))

	# --- Test 2: reorder by dragging line 1 below line 2. ---
	var before := _ops(game._program)
	if game._program.size() >= 2:
		var row0_block := list._blocks[0]
		var row1_block := list._blocks[1]
		var target := row1_block.get_global_rect().get_center() + Vector2(0, 30)
		await _drag(row0_block.get_global_rect().get_center(), target)
		for i in 4: await process_frame
	var after := _ops(game._program)
	print("before reorder = ", before)
	print("after  reorder = ", after)

	var inserted_ok := size_after_insert >= 1
	var reordered_ok := before.size() >= 2 and after != before
	print("RESULT: ", "PASS" if (inserted_ok and reordered_ok) else "FAIL")
	quit()

func _first_block(node: Node) -> InstructionBlock:
	return _nth_block(node, 1)

## Return the n-th (1-based) InstructionBlock found in a subtree.
func _nth_block(node: Node, n: int) -> InstructionBlock:
	var count := 0
	for child in _all_descendants(node):
		if child is InstructionBlock:
			count += 1
			if count == n:
				return child
	return null

func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out

func _ops(p: Program) -> Array:
	var out: Array = []
	for inst in p.instructions:
		out.append(InstructionDef.label_for(inst.op))
	return out

## Simulate a press-drag-release from one screen point to another.
func _drag(from: Vector2, to: Vector2) -> void:
	# Establish hover on the source first; Godot needs a prior motion before a
	# press to begin tracking a potential drag.
	_motion(from, Vector2.ZERO)
	await process_frame
	_button(from, true)
	await process_frame
	var steps := 12
	for i in steps + 1:
		var t := float(i) / float(steps)
		var pos := from.lerp(to, t)
		_motion(pos, (to - from) / float(steps))
		await process_frame
	_button(to, false)
	await process_frame

func _button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e)

func _motion(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e)
