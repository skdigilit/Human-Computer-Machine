extends SceneTree

## Verifies the selected level survives a restart through the settings store.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var suffix := Time.get_ticks_usec()
	var save_path := "user://restore_selected_level_%d.json" % suffix
	var settings_path := "user://restore_selected_level_settings_%d.json" % suffix

	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = save_path
	game._settings_path = settings_path
	root.add_child(game)
	for i in 4:
		await process_frame

	var target_index := mini(7, game._levels.size() - 1)
	game._select_level(target_index)
	await process_frame

	var reloaded_game: Game = load("res://game_main.tscn").instantiate()
	reloaded_game._save_path = save_path
	reloaded_game._settings_path = settings_path
	root.add_child(reloaded_game)
	for i in 4:
		await process_frame

	var passed := (
		game._level_index == target_index
		and reloaded_game._level_index == target_index
		and reloaded_game._level.title == game._levels[target_index].title
	)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
