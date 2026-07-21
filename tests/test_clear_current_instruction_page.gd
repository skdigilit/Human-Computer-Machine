extends SceneTree

## Verifies Settings > Data clears only the active instruction workspace page
## and retains a lossless persisted snapshot of its previous contents.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var suffix := Time.get_ticks_usec()
	var save_path := "user://clear_instruction_page_%d.json" % suffix
	var settings_path := "user://clear_instruction_page_settings_%d.json" % suffix
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = save_path
	game._settings_path = settings_path
	root.add_child(game)
	for i in 4:
		await process_frame

	game._program.add(Instruction.new(InstructionDef.Op.INBOX))
	game._program.add(Instruction.new(InstructionDef.Op.OUTBOX))
	game._on_program_changed()
	game._on_add_page_requested()
	game._program.add(Instruction.new(InstructionDef.Op.COPYFROM))
	game._on_program_changed()

	var settings: SettingsOverlay = game._settings_overlay
	settings.clear_current_page_requested.emit()
	for i in 2:
		await process_frame

	var file := FileAccess.open(save_path, FileAccess.READ)
	var stored: Variant = JSON.parse_string(file.get_as_text()) if file != null else {}
	var levels: Dictionary = stored.get("levels", {}) if stored is Dictionary else {}
	var level_record: Dictionary = levels.get("0", {}) if levels.get("0", {}) is Dictionary else {}
	var archives: Array = level_record.get("cleared_pages", []) if level_record.get("cleared_pages", []) is Array else []
	var archive: Dictionary = archives[-1] if not archives.is_empty() and archives[-1] is Dictionary else {}

	var reloaded: Game = load("res://game_main.tscn").instantiate()
	reloaded._save_path = save_path
	reloaded._settings_path = settings_path
	root.add_child(reloaded)
	for i in 4:
		await process_frame
	reloaded._on_page_requested(0)

	var passed := (
		game._program_pages.size() == 2
		and game._active_page == 1
		and game._program.size() == 0
		and archive.get("page_index", -1) == 1
		and (archive.get("instructions", []) as Array).size() == 1
		and reloaded._program_pages.size() == 2
		and reloaded._program.size() == 2
	)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
