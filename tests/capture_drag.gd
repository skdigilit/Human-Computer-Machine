extends SceneTree

## Dev utility: shows the editor with a landing-slot placeholder displayed
## between two lines (as it appears while dragging) and saves a screenshot.
##   Godot --path . --script tests/capture_drag.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://game_main.tscn").instantiate()
	game._save_path = "user://capture_drag_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 6: await process_frame

	var list: ProgramListView = game._program_list
	var p: Program = game._program
	for op in [InstructionDef.Op.INBOX, InstructionDef.Op.COPYTO,
			InstructionDef.Op.OUTBOX, InstructionDef.Op.JUMP]:
		p.add(Instruction.new(op))
	list.rebuild()
	for i in 3: await process_frame

	# Simulate the state mid-drag: cache row centres, then ask the list to show
	# the landing slot between line 2 and line 3.
	list._cache_row_centers()
	var b1 := list._blocks[1].get_global_rect()
	var b2 := list._blocks[2].get_global_rect()
	var between := Vector2(b1.get_center().x, (b1.position.y + b1.size.y + b2.position.y) * 0.5)
	list.can_accept_at(between, {
		InstructionBlock.DRAG_KIND: InstructionBlock.DRAG_PALETTE,
		InstructionBlock.DRAG_OP: InstructionDef.Op.ADD,
	})
	for i in 4: await process_frame

	get_root().get_texture().get_image().save_png("res://tests/shot.png")
	print("saved")
	quit()
