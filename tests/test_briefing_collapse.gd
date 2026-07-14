extends SceneTree

## Verifies collapsing the problem statement hides its body and gives the
## released height to the instruction list.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://briefing_collapse_test_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 4:
		await process_frame

	var initial_briefing_height := game._briefing.size.y
	var initial_program_height := game._program_list.size.y
	var initial_program_bottom := game._program_list.position.y + game._program_list.size.y

	game._briefing._collapse_button.pressed.emit()
	for i in 2:
		await process_frame

	var collapsed := (
		game._briefing.is_collapsed()
		and not game._briefing._body_scroll.visible
		and game._briefing.size.y < initial_briefing_height
		and game._program_list.size.y > initial_program_height
		and is_equal_approx(
			game._program_list.position.y + game._program_list.size.y,
			initial_program_bottom
		)
	)

	game._briefing._collapse_button.pressed.emit()
	for i in 2:
		await process_frame

	var expanded := (
		not game._briefing.is_collapsed()
		and game._briefing._body_scroll.visible
		and is_equal_approx(game._briefing.size.y, initial_briefing_height)
		and is_equal_approx(game._program_list.size.y, initial_program_height)
	)

	print("RESULT: ", "PASS" if collapsed and expanded else "FAIL")
	quit()
