extends SceneTree

## Verifies Settings exposes a scrollable Help tab containing the gameplay
## keyboard and mouse shortcut reference.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://settings_help_tab_%d.json" % Time.get_ticks_usec()
	game._settings_path = "user://settings_help_tab_settings_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 4:
		await process_frame

	var settings: SettingsOverlay = game._settings_overlay
	settings._select_tab(SettingsOverlay.TAB_HELP)
	await process_frame

	var labels: Array[String] = []
	_collect_label_text(settings._content, labels)
	var passed := (
		settings._tab_buttons.has(SettingsOverlay.TAB_HELP)
		and settings._content.get_parent() is ScrollContainer
		and "Keyboard" in labels
		and "Mouse" in labels
		and "Space" in labels
		and "Shift + H" in labels
		and "Ctrl/Cmd + left-drag" in labels
		and "Click, then click" in labels
	)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

func _collect_label_text(node: Node, labels: Array[String]) -> void:
	if node is Label:
		labels.append((node as Label).text)
	for child in node.get_children():
		_collect_label_text(child, labels)
