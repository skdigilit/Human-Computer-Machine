extends SceneTree

## Verifies window resizing is absorbed by the surrounding UI, not the room.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://responsive_layout_test_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 4:
		await process_frame

	var initial_room_size := game._room.size
	var initial_palette_width := game._palette.size.x
	var initial_briefing_width := game._briefing.size.x
	var initial_sidebar_ratio := initial_palette_width / (initial_palette_width + initial_briefing_width)
	var initial_control_height := game._control_bar.size.y
	var initial_worker_position := game._room.worker.position
	var initial_viewport := Vector2(
		game._briefing.position.x + game._briefing.size.x + Game.PANEL_GAP,
		game._control_bar.position.y + game._control_bar.size.y + Game.PANEL_GAP
	)
	var room_has_outer_padding := game._room.position == Vector2(Game.PANEL_GAP, Game.PANEL_GAP)

	var grown_viewport := initial_viewport + Vector2(240, 160)
	game._layout_panels(grown_viewport)
	for i in 2:
		await process_frame

	var room_fixed := game._room.size == initial_room_size
	var resized_sidebar_ratio := game._palette.size.x / (game._palette.size.x + game._briefing.size.x)
	var palette_resized := not is_equal_approx(game._palette.size.x, initial_palette_width)
	var palette_ratio_kept := is_equal_approx(resized_sidebar_ratio, initial_sidebar_ratio)
	var briefing_resized := not is_equal_approx(game._briefing.size.x, initial_briefing_width)
	var controls_resized := not is_equal_approx(game._control_bar.size.y, initial_control_height)
	var controls_reach_grown_bottom := is_equal_approx(
		game._control_bar.position.y + game._control_bar.size.y,
		grown_viewport.y - Game.PANEL_GAP
	)
	var worker_position_kept := game._room.worker.position == initial_worker_position

	var shrunk_viewport := initial_viewport - Vector2(0, 280)
	game._layout_panels(shrunk_viewport)
	for i in 2:
		await process_frame

	var room_width_fixed_after_shrink := is_equal_approx(game._room.size.x, initial_room_size.x)
	var room_height_can_shrink := game._room.size.y < initial_room_size.y
	var controls_reach_shrunk_bottom := is_equal_approx(
		game._control_bar.position.y + game._control_bar.size.y,
		shrunk_viewport.y - Game.PANEL_GAP
	)
	var worker_position_kept_after_shrink := game._room.worker.position == initial_worker_position
	var passed := (
		room_fixed
		and room_has_outer_padding
		and palette_resized
		and palette_ratio_kept
		and briefing_resized
		and controls_resized
		and controls_reach_grown_bottom
		and worker_position_kept
		and room_width_fixed_after_shrink
		and room_height_can_shrink
		and controls_reach_shrunk_bottom
		and worker_position_kept_after_shrink
	)
	if not passed:
		print("room_fixed=", room_fixed)
		print("room_has_outer_padding=", room_has_outer_padding)
		print("palette_resized=", palette_resized)
		print("palette_ratio_kept=", palette_ratio_kept, " initial=", initial_sidebar_ratio, " resized=", resized_sidebar_ratio)
		print("briefing_resized=", briefing_resized)
		print("controls_resized=", controls_resized)
		print("controls_reach_grown_bottom=", controls_reach_grown_bottom)
		print("worker_position_kept=", worker_position_kept)
		print("room_width_fixed_after_shrink=", room_width_fixed_after_shrink)
		print("room_height_can_shrink=", room_height_can_shrink)
		print("controls_reach_shrunk_bottom=", controls_reach_shrunk_bottom)
		print("worker_position_kept_after_shrink=", worker_position_kept_after_shrink)

	print("RESULT: ", "PASS" if passed else "FAIL")
	quit()
