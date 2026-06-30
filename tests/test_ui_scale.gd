extends SceneTree

## Verifies classroom UI scaling changes text and control dimensions together.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	VisualTheme.user_ui_scale = 1.0
	VisualTheme.set_viewport_size(Vector2(1900, 1400))

	var game: Game = load("res://game_main.tscn").instantiate()
	game._save_path = "user://ui_scale_test_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	for i in 4:
		await process_frame
	game._program.add(Instruction.new(game._level.palette[0]))
	game._program_list.rebuild()
	for i in 2:
		await process_frame

	var initial_title_font := _find_label(game._briefing, game._level.title).get_theme_font_size("font_size")
	var initial_body_font := game._briefing._body.get_theme_font_size("font_size")
	var initial_block := _find_instruction_block(game._palette)
	var initial_block_height := initial_block.get_combined_minimum_size().y
	var initial_palette_width := game._palette.size.x
	var initial_palette_block_width := initial_block.get_global_rect().size.x
	var initial_program_width := game._program_list.size.x
	var initial_program_block_width := game._program_list._blocks[0].get_global_rect().size.x
	var initial_briefing_width := game._briefing.size.x
	var initial_run_button := _find_button(game._control_bar, "RUN")
	var initial_run_width := initial_run_button.custom_minimum_size.x

	var plus_event := InputEventKey.new()
	plus_event.pressed = true
	plus_event.keycode = KEY_EQUAL
	plus_event.physical_keycode = KEY_EQUAL
	plus_event.shift_pressed = true
	plus_event.unicode = 43
	game._input(plus_event)
	var plus_key_works := VisualTheme.user_ui_scale > 1.0

	VisualTheme.user_ui_scale = 1.0
	game._apply_ui_scale()
	for i in 6:
		var minus_event := InputEventKey.new()
		minus_event.pressed = true
		minus_event.keycode = KEY_MINUS
		minus_event.physical_keycode = KEY_MINUS
		minus_event.unicode = 45
		game._input(minus_event)
	var minus_range_is_lenient := VisualTheme.user_ui_scale < 0.85

	VisualTheme.user_ui_scale = 1.0
	game._apply_ui_scale()
	for i in 4:
		VisualTheme.adjust_user_ui_scale(1)
	game._apply_ui_scale()
	for i in 4:
		await process_frame

	var scaled_title_font := _find_label(game._briefing, game._level.title).get_theme_font_size("font_size")
	var scaled_body_font := game._briefing._body.get_theme_font_size("font_size")
	var scaled_block := _find_instruction_block(game._palette)
	var scaled_block_height := scaled_block.get_combined_minimum_size().y
	var scaled_palette_width := game._palette.size.x
	var scaled_palette_block_width := scaled_block.get_global_rect().size.x
	var scaled_program_width := game._program_list.size.x
	var scaled_program_block_width := game._program_list._blocks[0].get_global_rect().size.x
	var scaled_briefing_width := game._briefing.size.x
	var scaled_run_button := _find_button(game._control_bar, "RUN")
	var scaled_run_width := scaled_run_button.custom_minimum_size.x
	var controls_clear_side_panels := (
		not game._control_bar.get_global_rect().intersects(game._palette.get_global_rect())
		and not game._control_bar.get_global_rect().intersects(game._briefing.get_global_rect())
		and not game._control_bar.get_global_rect().intersects(game._program_list.get_global_rect())
	)
	var status_label_on_right := game._control_bar._status.get_global_rect().position.x > game._control_bar._slider.get_global_rect().end.x
	var editor_split_is_quarter := _question_split_is_quarter(game)

	for i in 40:
		VisualTheme.adjust_user_ui_scale(1)
	var capped_high := is_equal_approx(VisualTheme.user_ui_scale, VisualTheme.USER_UI_SCALE_MAX)
	game._apply_ui_scale()
	for i in 2:
		await process_frame
	var max_scale_no_overlap := _regions_do_not_overlap(game)
	var max_scale_inside_viewport := _regions_inside_viewport(game, game.get_viewport_rect().size)
	var max_scale_split_is_quarter := _question_split_is_quarter(game)
	var max_scale_layout_clean := max_scale_no_overlap and max_scale_inside_viewport
	for i in 40:
		VisualTheme.adjust_user_ui_scale(-1)
	var capped_low := is_equal_approx(VisualTheme.user_ui_scale, VisualTheme.USER_UI_SCALE_MIN)

	var passed := (
		scaled_title_font > initial_title_font
		and scaled_body_font > initial_body_font
		and scaled_block_height > initial_block_height
		and scaled_palette_width > initial_palette_width
		and scaled_palette_block_width > initial_palette_block_width
		and scaled_program_width > initial_program_width
		and scaled_program_block_width > initial_program_block_width
		and scaled_briefing_width > initial_briefing_width
		and scaled_run_width >= initial_run_width
		and controls_clear_side_panels
		and status_label_on_right
		and editor_split_is_quarter
		and plus_key_works
		and minus_range_is_lenient
		and capped_high
		and max_scale_layout_clean
		and max_scale_split_is_quarter
		and capped_low
	)
	if not passed:
		print("scaled_title_font=", scaled_title_font, " initial=", initial_title_font)
		print("scaled_body_font=", scaled_body_font, " initial=", initial_body_font)
		print("scaled_block_height=", scaled_block_height, " initial=", initial_block_height)
		print("scaled_palette_width=", scaled_palette_width, " initial=", initial_palette_width)
		print("scaled_palette_block_width=", scaled_palette_block_width, " initial=", initial_palette_block_width)
		print("scaled_program_width=", scaled_program_width, " initial=", initial_program_width)
		print("scaled_program_block_width=", scaled_program_block_width, " initial=", initial_program_block_width)
		print("scaled_briefing_width=", scaled_briefing_width, " initial=", initial_briefing_width)
		print("scaled_run_width=", scaled_run_width, " initial=", initial_run_width)
		print("controls_clear_side_panels=", controls_clear_side_panels)
		print("status_label_on_right=", status_label_on_right)
		print("editor_split_is_quarter=", editor_split_is_quarter)
		print("plus_key_works=", plus_key_works)
		print("minus_range_is_lenient=", minus_range_is_lenient)
		print("capped_high=", capped_high, " max_scale_no_overlap=", max_scale_no_overlap, " max_scale_inside_viewport=", max_scale_inside_viewport, " max_scale_split_is_quarter=", max_scale_split_is_quarter, " capped_low=", capped_low)
		print("viewport=", game.get_viewport_rect().size)
		_print_regions(game)

	VisualTheme.user_ui_scale = 1.0
	VisualTheme.set_viewport_size(Vector2(1900, 1400))
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit()

func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, text)
		if found:
			return found
	return null

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found:
			return found
	return null

func _find_instruction_block(node: Node) -> InstructionBlock:
	if node is InstructionBlock:
		return node as InstructionBlock
	for child in node.get_children():
		var found := _find_instruction_block(child)
		if found:
			return found
	return null

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

func _print_regions(game: Game) -> void:
	print("room=", game._room.get_global_rect())
	print("palette=", game._palette.get_global_rect())
	print("briefing=", game._briefing.get_global_rect())
	print("program=", game._program_list.get_global_rect())
	print("controls=", game._control_bar.get_global_rect())

func _question_split_is_quarter(game: Game) -> bool:
	var total := game._briefing.size.y + game._program_list.size.y
	if total <= 0.0:
		return false
	return absf(game._briefing.size.y / total - 0.25) < 0.01
