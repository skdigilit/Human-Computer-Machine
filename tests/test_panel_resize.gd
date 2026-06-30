extends SceneTree

## Verifies Ctrl/Command edge-dragging resizes the editor panels.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://panel_resize_test_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 4:
		await process_frame

	var initial_palette_width := game._palette.size.x
	var initial_program_width := game._program_list.size.x
	var initial_room_width := game._room.size.x
	var initial_briefing_height := game._briefing.size.y
	var initial_program_height := game._program_list.size.y

	var palette_left_edge := Vector2(
		game._palette.position.x,
		game._palette.position.y + game._palette.size.y * 0.5
	)
	_modifier_drag(game, palette_left_edge, palette_left_edge - Vector2(80, 0), false)
	for i in 2:
		await process_frame

	var palette_left_moved := game._palette.position.x < palette_left_edge.x - 10.0
	var room_shrank := game._room.size.x < initial_room_width - 10.0
	var palette_width_before_right_drag := game._palette.size.x
	var program_width_before_right_drag := game._program_list.size.x

	var palette_edge := Vector2(
		game._palette.position.x + game._palette.size.x,
		game._palette.position.y + game._palette.size.y * 0.5
	)
	_modifier_drag(game, palette_edge, palette_edge + Vector2(80, 0), true)
	for i in 2:
		await process_frame

	var palette_grew := game._palette.size.x > palette_width_before_right_drag + 10.0
	var editor_narrowed := game._program_list.size.x < program_width_before_right_drag - 10.0

	var editor_edge := Vector2(
		game._briefing.position.x + game._briefing.size.x * 0.5,
		game._briefing.position.y + game._briefing.size.y
	)
	_modifier_drag(game, editor_edge, editor_edge + Vector2(0, 90), false)
	for i in 2:
		await process_frame

	var briefing_grew := game._briefing.size.y > initial_briefing_height + 10.0
	var program_shrank := game._program_list.size.y < initial_program_height - 10.0
	var layout_clean := _regions_do_not_overlap(game) and _regions_inside_viewport(game, game.get_viewport_rect().size)
	var passed := palette_left_moved and room_shrank and palette_grew and editor_narrowed and briefing_grew and program_shrank and layout_clean

	if not passed:
		print("palette_left_moved=", palette_left_moved, " initial=", palette_left_edge.x, " actual=", game._palette.position.x)
		print("room_shrank=", room_shrank, " initial=", initial_room_width, " actual=", game._room.size.x)
		print("palette_grew=", palette_grew, " initial=", initial_palette_width, " actual=", game._palette.size.x)
		print("editor_narrowed=", editor_narrowed, " initial=", initial_program_width, " actual=", game._program_list.size.x)
		print("briefing_grew=", briefing_grew, " initial=", initial_briefing_height, " actual=", game._briefing.size.y)
		print("program_shrank=", program_shrank, " initial=", initial_program_height, " actual=", game._program_list.size.y)
		print("layout_clean=", layout_clean)

	print("RESULT: ", "PASS" if passed else "FAIL")
	quit()

func _modifier_drag(game: Game, start: Vector2, finish: Vector2, use_meta: bool) -> void:
	var down := InputEventMouseButton.new()
	down.position = start
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.ctrl_pressed = not use_meta
	down.meta_pressed = use_meta
	game._input(down)

	var move := InputEventMouseMotion.new()
	move.position = finish
	move.ctrl_pressed = not use_meta
	move.meta_pressed = use_meta
	game._input(move)

	var up := InputEventMouseButton.new()
	up.position = finish
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.ctrl_pressed = not use_meta
	up.meta_pressed = use_meta
	game._input(up)

func _regions_do_not_overlap(game: Game) -> bool:
	var regions := [
		game._room.get_global_rect(),
		game._palette.get_global_rect(),
		game._briefing.get_global_rect(),
		game._program_list.get_global_rect(),
		game._control_bar.get_global_rect(),
	]
	for i in regions.size():
		for j in range(i + 1, regions.size()):
			if regions[i].intersects(regions[j]):
				return false
	return true

func _regions_inside_viewport(game: Game, viewport_size: Vector2) -> bool:
	for rect in [
		game._room.get_global_rect(),
		game._palette.get_global_rect(),
		game._briefing.get_global_rect(),
		game._program_list.get_global_rect(),
		game._control_bar.get_global_rect(),
	]:
		if rect.position.x < -0.01 or rect.position.y < -0.01:
			return false
		if rect.end.x > viewport_size.x + 0.01 or rect.end.y > viewport_size.y + 0.01:
			return false
	return true
