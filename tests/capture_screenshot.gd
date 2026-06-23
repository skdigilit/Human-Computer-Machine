extends SceneTree

## Dev utility: boots the game, drops in a few instructions so the program list,
## arrows and worker are all visible, then saves a screenshot for visual review.
##   Godot --path . --script tests/capture_screenshot.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://game_main.tscn").instantiate()
	game._save_path = "user://capture_screenshot_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 4:
		await process_frame

	# Seed a small program so the editor isn't empty in the shot.
	var p: Program = game._program
	p.add(Instruction.new(InstructionDef.Op.INBOX))
	var c := Instruction.new(InstructionDef.Op.COPYTO); c.address = 0
	p.add(c)
	p.add(Instruction.new(InstructionDef.Op.OUTBOX))
	var j := Instruction.new(InstructionDef.Op.JUMP)
	j.jump_target_id = p.instructions[0].id
	p.add(j)
	game._program_list.rebuild()

	# Run a couple of steps so the worker is mid-task holding a box.
	game._delay = 0.0
	await game._execute_one()
	await game._execute_one()

	for i in 6:
		await process_frame

	var img := get_root().get_texture().get_image()
	img.save_png("res://tests/shot.png")
	print("saved shot")
	quit()
