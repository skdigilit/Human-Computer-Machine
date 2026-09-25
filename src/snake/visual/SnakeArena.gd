class_name SnakeArena
extends StageView

## The Snake board. Draws the grid, the white snake and the food straight from
## a SnakeState in _draw(), plus addressed student memory tiles above the
## board. It never mutates
## the state: SnakeVM owns it, and every SnakeStepAction hands over a reference
## to redraw from.

## Elapsed fraction of the wait the program line `line_index` is spending,
## so the block in the program list can show progress.
## Sent every frame of the wait and once more at 1.0 when done.
signal wait_progress(line_index: int, elapsed_fraction: float)

const BOARD_MARGIN := 24.0
const MANUAL_WAIT_MINIMUM_SECONDS := 1.0
const HUD_HEIGHT := 136.0
const GRID_LINE_ALPHA := 0.08
const FOOD_COLOR := VisualTheme.CORAL
const SNAKE_COLOR := VisualTheme.PAPER
const HEAD_COLOR := "#FFFFFF"
const BOARD_COLOR := VisualTheme.ROOM_FLOOR
const BOARD_FRAME := VisualTheme.STATION_FRAME

var _state: SnakeState = null
var _level: SnakeLevel = null
var _hud: HBoxContainer
var _memory_boxes: Array[NumberBox] = []
var _memory_values: Array[int] = []
var _memory_key_flags: Array[bool] = []
var _visible_memory_slots: Array[int] = [0]
var _food_icon: Texture2D
## Hidden countdown driving wait timing and instruction-block progress.
var _wait_bar: WaitBar
## Program line of the wait currently counting down (-1 when none).
var _wait_line: int = -1

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_food_icon = SFSymbols.texture("carrot.fill", Color.html(FOOD_COLOR))
	_wait_bar = WaitBar.new()
	_wait_bar.progress.connect(_on_wait_progress)
	add_child(_wait_bar)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_hud()
		queue_redraw()

# --- StageView ----------------------------------------------------------------

## Show the level's starting board before RUN is pressed. The preview state is
## built exactly like SnakeVM.reset() so the first frame matches.
func setup(level: Level) -> void:
	_level = level as SnakeLevel
	_state = SnakeState.new()
	if _level:
		_state.reset(_level.effective_grid_size(), _level.start_length, _level.food_seed)
	else:
		_state.reset(SnakeState.DEFAULT_GRID_SIZE, 3, 1)
	_memory_values.clear()
	_memory_key_flags.clear()
	if _level:
		for i in _level.memory_size:
			_memory_values.append(int(_level.initial_memory.get(i, StepAction.NULL_VALUE)))
			_memory_key_flags.append(i == 0)
	_build_hud()
	_refresh_hud()
	_wait_bar.clear()
	queue_redraw()

## A wait step is spent here: the coroutine holds until the countdown ends,
## so the program highlight stays on the wait block while it fills.
func animate(action: StepAction) -> void:
	var snake_action := action as SnakeStepAction
	if snake_action == null or snake_action.state == null:
		return
	_state = snake_action.state
	_memory_values = snake_action.memory_values.duplicate()
	_memory_key_flags = snake_action.memory_key_flags.duplicate()
	_refresh_hud()
	queue_redraw()
	if snake_action.wait_seconds > 0.0:
		_wait_line = snake_action.line_index
		_wait_bar.start(snake_action.wait_seconds)
		_wait_bar.hide()
		await _wait_bar.finished
		_wait_line = -1

## Repeated STEP presses must not shorten the countdown.
func speed_up_current_animation() -> void:
	pass

func set_manual_wait(enabled: bool) -> void:
	_wait_bar.minimum_animation_seconds = MANUAL_WAIT_MINIMUM_SECONDS if enabled else 0.0

func apply_ui_scale() -> void:
	_build_hud()
	_refresh_hud()
	_layout_hud()

## Reflect a key press in the visible boxes while the program may be waiting.
func update_memory(values: Array[int], key_flags: Array[bool]) -> void:
	_memory_values = values.duplicate()
	_memory_key_flags = key_flags.duplicate()
	_refresh_hud()

## Keep the key slot visible; show another slot only when a program uses it.
func set_visible_memory_slots(slots: Array[int]) -> void:
	_visible_memory_slots = slots.duplicate()
	_apply_memory_visibility()

func is_waiting() -> bool:
	return _wait_bar.is_waiting()

func set_wait_paused(paused: bool) -> void:
	_wait_bar.set_paused(paused)

# --- HUD ----------------------------------------------------------------------

func _build_hud() -> void:
	if _hud:
		_hud.queue_free()
	_hud = HBoxContainer.new()
	_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_constant_override("separation", VisualTheme.scaled_int(24, 10, 60))
	add_child(_hud)

	var memory_row := _make_hud_group("MEMORY")
	_memory_boxes.clear()
	for i in _memory_values.size():
		var box := _add_hud_slot(memory_row, i, true, "Writable memory slot %d" % i)
		_memory_boxes.append(box)
	_apply_memory_visibility()
	_layout_hud()

func _apply_memory_visibility() -> void:
	for i in _memory_boxes.size():
		var column := _memory_boxes[i].get_parent().get_parent() as Control
		column.visible = _visible_memory_slots.has(i) or (_level != null and i == _level.wait_scale_slot)

func _make_hud_group(caption: String) -> HBoxContainer:
	var group := VBoxContainer.new()
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", VisualTheme.scaled_int(4, 2, 14))
	_hud.add_child(group)
	var title := Label.new()
	title.text = caption
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.html("#B4AD99"))
	VisualTheme.apply_ui_font(title, true)
	VisualTheme.apply_font_size(title, 14, 8, 28)
	group.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTheme.scaled_int(12, 5, 28))
	group.add_child(row)
	return row

func _add_hud_slot(row: HBoxContainer, index: int, memory_style: bool, description: String) -> NumberBox:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", VisualTheme.scaled_int(4, 2, 12))
	row.add_child(column)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", VisualTheme.scaled_int(3, 1, 10))
	column.add_child(header)
	if index >= 0:
		var address := Label.new()
		address.text = "%d · SPEED" % index if _level != null and index == _level.wait_scale_slot else str(index)
		address.add_theme_color_override("font_color", Color.html(InstructionDef.COLOR_MEMORY))
		VisualTheme.apply_ui_font(address, true)
		VisualTheme.apply_font_size(address, 17, 10, 32)
		header.add_child(address)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_color = Color.html(InstructionDef.COLOR_MEMORY if memory_style else "#8F8A79")
	frame_style.set_border_width_all(VisualTheme.scaled_int(3, 2, 10))
	frame_style.set_expand_margin_all(VisualTheme.scaled_int(3, 2, 10))
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.tooltip_text = description
	column.add_child(frame)
	var box := NumberBox.new()
	var edge := VisualTheme.scaled(48.0, 38.0, 80.0)
	box.custom_minimum_size = Vector2(edge, edge)
	box.size = Vector2(edge, edge)
	box.pivot_offset = Vector2.ONE * edge * 0.5
	box.set_palette(VisualTheme.BOX_MEMORY_FILL if memory_style else "#D9D4C4", VisualTheme.BOX_MEMORY_BORDER if memory_style else "#777E70", VisualTheme.BOX_MEMORY_TEXT if memory_style else VisualTheme.INK)
	frame.add_child(box)
	return box

func _layout_hud() -> void:
	if _hud == null:
		return
	_hud.position = Vector2(0.0, 0.0)
	_hud.size = Vector2(size.x, _hud_height())

func _refresh_hud() -> void:
	for i in mini(_memory_boxes.size(), _memory_values.size()):
		var value := _memory_values[i]
		var is_key := i < _memory_key_flags.size() and _memory_key_flags[i]
		_memory_boxes[i].set_display_text(SnakeKey.display(value) if is_key else ("—" if value == StepAction.NULL_VALUE else str(value)))

func _hud_height() -> float:
	return VisualTheme.scaled(HUD_HEIGHT, 36.0, 160.0)

# --- Wait bar -----------------------------------------------------------------

func _on_wait_progress(elapsed_fraction: float) -> void:
	if _wait_line >= 0:
		wait_progress.emit(_wait_line, elapsed_fraction)

# --- Board --------------------------------------------------------------------

## The largest square that fits below the HUD,
## centred horizontally.
func board_rect() -> Rect2:
	var margin := VisualTheme.scaled(BOARD_MARGIN, 8.0, 80.0)
	var top := _hud_height()
	var bottom := margin
	var available := Vector2(size.x - margin * 2.0, size.y - top - bottom)
	var edge := maxf(1.0, minf(available.x, available.y))
	return Rect2(Vector2((size.x - edge) * 0.5, top + (available.y - edge) * 0.5), Vector2(edge, edge))

## Cell size in pixels for the current board.
func cell_size() -> float:
	if _state == null:
		return 1.0
	return board_rect().size.x / float(_state.grid_size)

func _cell_rect(cell: Vector2i) -> Rect2:
	var board := board_rect()
	var edge := cell_size()
	return Rect2(board.position + Vector2(cell) * edge, Vector2(edge, edge))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.html(VisualTheme.ROOM_FLOOR_DARK))
	if _state == null:
		return
	var board := board_rect()
	draw_rect(board, Color.html(BOARD_COLOR))

	# Faint grid so players can count cells; skipped when cells get tiny.
	var edge := cell_size()
	if edge >= 6.0:
		var line := Color(Color.html(VisualTheme.PAPER), GRID_LINE_ALPHA)
		for i in range(1, _state.grid_size):
			var x := board.position.x + i * edge
			var y := board.position.y + i * edge
			draw_line(Vector2(x, board.position.y), Vector2(x, board.end.y), line, 1.0)
			draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), line, 1.0)

	if _state.is_inside(_state.food):
		var food_rect := _cell_rect(_state.food).grow(-edge * 0.08)
		if _food_icon and edge >= 10.0:
			draw_texture_rect(_food_icon, food_rect, false)
		else:
			draw_rect(food_rect, Color.html(FOOD_COLOR))

	var inset := -maxf(1.0, edge * 0.06)
	for i in range(_state.body.size() - 1, -1, -1):
		var cell := _state.body[i]
		if not _state.is_inside(cell):
			continue
		var color := Color.html(HEAD_COLOR if i == 0 else SNAKE_COLOR)
		draw_rect(_cell_rect(cell).grow(inset), color)

	if _state.is_inside(_state.head()) and edge >= 10.0:
		_draw_heading_arrow(_state.head(), edge)

	draw_rect(board, Color.html(BOARD_FRAME), false, VisualTheme.scaled(4.0, 2.0, 12.0))

## A filled arrow on the head cell, using the active theme font.
func _draw_heading_arrow(cell: Vector2i, edge: float) -> void:
	var step := SnakeState.DIRECTION_STEPS[_state.heading]
	var angle := atan2(float(step.y), float(step.x))
	var centre := _cell_rect(cell).get_center()
	var font := get_theme_default_font()
	var font_size := int(edge * 0.85)
	var glyph := "▲"
	var glyph_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_set_transform(centre, angle + PI * 0.5, Vector2.ONE)
	font.draw_string(get_canvas_item(), Vector2(-glyph_size.x * 0.5, glyph_size.y * 0.35), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
