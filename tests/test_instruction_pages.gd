extends SceneTree

## Verifies page creation, switching, the three-page cap, and serialization.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var save_path := "user://instruction_pages_test_%d.json" % Time.get_ticks_usec()
	var game: Control = load("res://game_main.tscn").instantiate()
	game._save_path = save_path
	root.add_child(game)
	for i in 4:
		await process_frame

	# Work on a distinct level and keep any existing saved pages intact.
	game._select_level(1)
	var initial_count: int = game._program_pages.size()
	while game._program_pages.size() < game.MAX_PROGRAM_PAGES:
		game._on_add_page_requested()
	var capped_count: int = game._program_pages.size()
	game._on_add_page_requested()

	var last_page: Program = game._program
	var inbox := Instruction.new(InstructionDef.Op.INBOX)
	last_page.add(inbox)
	var jump := Instruction.new(InstructionDef.Op.JUMP)
	jump.jump_target_id = inbox.id
	last_page.add(jump)
	game._on_program_changed()
	var serialized: Array = last_page.to_data()
	var restored := Program.from_data(serialized)

	var reloaded_game: Control = load("res://game_main.tscn").instantiate()
	reloaded_game._save_path = save_path
	root.add_child(reloaded_game)
	for i in 4:
		await process_frame
	reloaded_game._select_level(1)

	var passed: bool = (
		initial_count >= 1
		and capped_count == 3
		and game._program_pages.size() == 3
		and restored.size() == last_page.size()
		and restored.instructions[-1].jump_target_id == restored.instructions[0].id
		and game._program_list._add_page_button.disabled
		and reloaded_game._program_pages.size() == 3
		and reloaded_game._program.instructions[-1].jump_target_id == reloaded_game._program.instructions[0].id
	)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit()
