class_name Game
extends Control

## Top-level orchestrator. Owns the level, the program model and the VM, lays
## out every panel, and drives execution by feeding VM StepActions to the
## RoomView animation while keeping the program highlight and status in sync.
##
## Logic lives here; presentation lives in the panels. The VM never touches a
## node and the panels never execute instructions.

# The initial viewport determines the room's grid layout. UI panels may resize
# freely; room width and child coordinates stay stable so the grid-based puzzle
# and character visuals do not shift during window resizes.
const PANEL_GAP := 8.0
const ROOM_WIDTH_RATIO := 0.64
const PALETTE_WIDTH_RATIO := 0.12
const CONTROL_HEIGHT_RATIO := 0.10
const BRIEFING_HEIGHT_RATIO := 0.30
const MIN_ROOM_WIDTH := 720.0
const MIN_PALETTE_WIDTH := 180.0
const MIN_EDITOR_WIDTH := 330.0
const MIN_CONTROL_HEIGHT := 112.0
const MIN_BRIEFING_HEIGHT := 220.0
const MIN_PROGRAM_HEIGHT := 260.0
const MAX_PROGRAM_PAGES := 3
const DEFAULT_SAVE_PATH := "user://instruction_pages.json"

var _level: Level
var _levels: Array[Level] = []
var _level_index: int = 0
var _program: Program
var _program_pages: Array[Program] = []
var _active_page: int = 0
var _saved_levels: Dictionary = {}
var _save_path: String = DEFAULT_SAVE_PATH
var _vm: VM = null

var _room: RoomView
var _palette: InstructionPalette
var _briefing: BriefingNote
var _program_list: ProgramListView
var _control_bar: ControlBar
var _win_banner: Label
var _room_visual_size: Vector2 = Vector2.ZERO
var _palette_sidebar_ratio: float = 0.0

var _running: bool = false
var _busy: bool = false
var _halted: bool = false
var _step_buffered: bool = false
var _manual_step_loop_active: bool = false
var _delay: float = 0.4

func _ready() -> void:
	theme = VisualTheme.make_ui_theme()
	_levels = LevelLibrary.all_levels()
	_level = _levels[_level_index]
	_load_saved_levels()
	_load_level_pages()
	_build_background()
	_build_panels()
	_room_visual_size = _compute_initial_room_size(get_viewport_rect().size)
	_palette_sidebar_ratio = _compute_initial_palette_sidebar_ratio(get_viewport_rect().size, _room_visual_size.x)
	_layout_panels(get_viewport_rect().size)
	_wire_signals()
	_delay = _control_bar.initial_delay()
	_start_fresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _room != null:
		_layout_panels(get_viewport_rect().size)

# --- Construction -------------------------------------------------------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.html(VisualTheme.ROOM_FLOOR_DARK)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_panels() -> void:
	_room = RoomView.new()
	add_child(_room)

	_control_bar = ControlBar.new()
	add_child(_control_bar)

	_palette = InstructionPalette.new()
	add_child(_palette)

	_briefing = BriefingNote.new()
	add_child(_briefing)

	_program_list = ProgramListView.new()
	add_child(_program_list)

	_win_banner = Label.new()
	_win_banner.text = "GREAT JOB!"
	_win_banner.add_theme_font_size_override("font_size", 64)
	_win_banner.add_theme_color_override("font_color", Color.html("#FFE066"))
	_win_banner.add_theme_color_override("font_outline_color", Color.html("#5A4A10"))
	_win_banner.add_theme_constant_override("outline_size", 8)
	_win_banner.position = Vector2(120, 1200)
	_win_banner.visible = false
	add_child(_win_banner)

func _compute_initial_room_size(viewport_size: Vector2) -> Vector2:
	var available_width := viewport_size.x - PANEL_GAP * 4.0
	var palette_width := maxf(MIN_PALETTE_WIDTH, viewport_size.x * PALETTE_WIDTH_RATIO)
	var editor_width := maxf(MIN_EDITOR_WIDTH, viewport_size.x - viewport_size.x * ROOM_WIDTH_RATIO - palette_width - PANEL_GAP * 4.0)
	var room_width := available_width - palette_width - editor_width
	if room_width < MIN_ROOM_WIDTH:
		room_width = MIN_ROOM_WIDTH
		editor_width = maxf(MIN_EDITOR_WIDTH, available_width - room_width - palette_width)

	var control_height := maxf(MIN_CONTROL_HEIGHT, viewport_size.y * CONTROL_HEIGHT_RATIO)
	var room_height := viewport_size.y - control_height - PANEL_GAP * 3.0
	return Vector2(room_width, room_height)

func _compute_initial_palette_sidebar_ratio(viewport_size: Vector2, room_width: float) -> float:
	var right_width := maxf(1.0, viewport_size.x - room_width - PANEL_GAP * 4.0)
	var palette_width := minf(right_width, maxf(MIN_PALETTE_WIDTH, viewport_size.x * PALETTE_WIDTH_RATIO))
	return clampf(palette_width / right_width, 0.0, 1.0)

## Size every panel from the current window while preserving room coordinates.
func _layout_panels(viewport_size: Vector2) -> void:
	if _room_visual_size == Vector2.ZERO:
		_room_visual_size = _compute_initial_room_size(viewport_size)
	if _palette_sidebar_ratio <= 0.0:
		_palette_sidebar_ratio = _compute_initial_palette_sidebar_ratio(viewport_size, _room_visual_size.x)

	var room_width := _room_visual_size.x
	var available_room_and_controls_height := maxf(0.0, viewport_size.y - PANEL_GAP * 3.0)
	var desired_control_height := maxf(
		MIN_CONTROL_HEIGHT,
		viewport_size.y - _room_visual_size.y - PANEL_GAP * 3.0
	)
	var control_height := minf(available_room_and_controls_height, desired_control_height)
	var room_height := available_room_and_controls_height - control_height
	var right_width := maxf(1.0, viewport_size.x - room_width - PANEL_GAP * 4.0)
	var palette_width := clampf(
		right_width * _palette_sidebar_ratio,
		minf(MIN_PALETTE_WIDTH, right_width),
		right_width
	)
	var editor_width := maxf(1.0, right_width - palette_width)
	var editor_x := room_width + palette_width + PANEL_GAP * 3.0
	var max_briefing_height := maxf(
		80.0,
		viewport_size.y - MIN_PROGRAM_HEIGHT - PANEL_GAP * 3.0
	)
	var min_briefing_height := minf(MIN_BRIEFING_HEIGHT, max_briefing_height)
	var briefing_height := clampf(
		viewport_size.y * BRIEFING_HEIGHT_RATIO,
		min_briefing_height,
		max_briefing_height
	)

	_room.position = Vector2(PANEL_GAP, PANEL_GAP)
	_room.size = Vector2(room_width, room_height)

	_control_bar.position = Vector2(PANEL_GAP, PANEL_GAP * 2.0 + room_height)
	_control_bar.size = Vector2(room_width, control_height)

	_palette.position = Vector2(room_width + PANEL_GAP * 2.0, PANEL_GAP)
	_palette.size = Vector2(palette_width, viewport_size.y - PANEL_GAP * 2.0)

	_briefing.position = Vector2(editor_x, PANEL_GAP)
	_briefing.size = Vector2(editor_width, briefing_height)

	_program_list.position = Vector2(editor_x, briefing_height + PANEL_GAP * 2.0)
	_program_list.size = Vector2(
		editor_width,
		viewport_size.y - briefing_height - PANEL_GAP * 3.0
	)

func _wire_signals() -> void:
	_control_bar.reset_requested.connect(_on_reset)
	_control_bar.step_requested.connect(_on_step)
	_control_bar.play_toggled.connect(_on_play_toggled)
	_control_bar.speed_changed.connect(func(d: float) -> void: _delay = d)
	_program_list.program_changed.connect(_on_program_changed)
	_program_list.page_requested.connect(_on_page_requested)
	_program_list.add_page_requested.connect(_on_add_page_requested)
	_briefing.previous_requested.connect(func() -> void: _select_level(_level_index - 1))
	_briefing.next_requested.connect(func() -> void: _select_level(_level_index + 1))

# --- Level / run lifecycle ----------------------------------------------------

## Build (or rebuild) all level-dependent views from scratch.
func _start_fresh() -> void:
	_briefing.set_level(_level, _level_index, _levels.size())
	_palette.build(_level)
	_program_list.setup(_program, _level.memory_size, _active_page, _program_pages.size())
	_reset_run()

func _select_level(index: int) -> void:
	if index < 0 or index >= _levels.size() or index == _level_index:
		return
	_save_current_level()
	_level_index = index
	_level = _levels[_level_index]
	_load_level_pages()
	_start_fresh()

## Discard the running machine and return the floor to the level's start.
func _reset_run() -> void:
	_running = false
	_halted = false
	_busy = false
	_step_buffered = false
	_vm = null
	_room.setup(_level)
	_program_list.set_active_line(-1)
	_win_banner.visible = false
	_control_bar.set_running(false)
	_control_bar.set_status("Drag a move into the list. Press RUN to watch it!")

## Create the VM lazily so edits before the first run are always honoured.
func _ensure_vm() -> void:
	if _vm == null:
		_vm = VM.new(_level, _program)
		_halted = false

# --- Control bar handlers -----------------------------------------------------

func _on_reset() -> void:
	_reset_run()

func _on_program_changed() -> void:
	# Any edit invalidates a half-run machine; rewind to a clean state.
	_save_current_level()
	_reset_run()

func _on_page_requested(index: int) -> void:
	if index < 0 or index >= _program_pages.size() or index == _active_page:
		return
	_active_page = index
	_program = _program_pages[_active_page]
	_save_current_level()
	_program_list.setup(_program, _level.memory_size, _active_page, _program_pages.size())
	_reset_run()

func _on_add_page_requested() -> void:
	if _program_pages.size() >= MAX_PROGRAM_PAGES:
		return
	_program_pages.append(Program.new())
	_active_page = _program_pages.size() - 1
	_program = _program_pages[_active_page]
	_save_current_level()
	_program_list.setup(_program, _level.memory_size, _active_page, _program_pages.size())
	_reset_run()

# --- Instruction page persistence --------------------------------------------

func _level_save_key() -> String:
	return str(_level_index)

func _load_saved_levels() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open instruction page save file.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("levels", {}) is Dictionary:
		_saved_levels = parsed.get("levels", {})

func _load_level_pages() -> void:
	_program_pages.clear()
	_active_page = 0
	var saved: Variant = _saved_levels.get(_level_save_key(), {})
	if saved is Dictionary:
		var pages: Variant = saved.get("pages", [])
		if pages is Array:
			for page_data in pages.slice(0, MAX_PROGRAM_PAGES):
				if page_data is Array:
					_program_pages.append(Program.from_data(page_data))
		_active_page = clampi(int(saved.get("active_page", 0)), 0, maxi(0, _program_pages.size() - 1))
	if _program_pages.is_empty():
		_program_pages.append(Program.new())
	_program = _program_pages[_active_page]

func _save_current_level() -> void:
	var pages: Array = []
	for page in _program_pages:
		pages.append(page.to_data())
	_saved_levels[_level_save_key()] = {
		"active_page": _active_page,
		"pages": pages,
	}
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save instruction pages.")
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"levels": _saved_levels,
	}, "\t"))

func _on_play_toggled(should_run: bool) -> void:
	if should_run:
		_running = true
		_run_loop()
	else:
		_running = false

func _on_step() -> void:
	if _running:
		return
	_step_buffered = true
	if _busy:
		_room.speed_up_current_animation()
		return
	_run_manual_steps()

## Consume manual step requests one at a time. Multiple clicks during the same
## instruction collapse into one buffered request for the following instruction.
func _run_manual_steps() -> void:
	if _manual_step_loop_active:
		return
	_manual_step_loop_active = true
	while _step_buffered and not _running and not _halted:
		_step_buffered = false
		await _execute_one()
	_manual_step_loop_active = false

## Auto-advance through the program at the chosen speed until paused or halted.
func _run_loop() -> void:
	while _running:
		await _execute_one()
		if _halted or not _running:
			break
		await get_tree().create_timer(_delay).timeout
	_running = false
	_control_bar.set_running(false)
	if _step_buffered and not _halted:
		_run_manual_steps()

## Execute exactly one instruction and play back its animation. Guarded so
## overlapping triggers (fast clicks, run loop) never interleave.
func _execute_one() -> void:
	if _busy or _halted:
		return
	_busy = true
	_ensure_vm()

	if _program.size() == 0:
		_control_bar.set_status("Your program is empty — drag in some commands!")
		_busy = false
		return

	var action := _vm.step()
	if not action.halted:
		_program_list.set_active_line(action.line_index)
	await _room.animate(action)

	if action.halted:
		_finish(action)
	else:
		_program_list.set_active_line(_vm.pc)
	_busy = false

## React to the program ending (win, wrong output, or error).
func _finish(action: StepAction) -> void:
	_halted = true
	_running = false
	_control_bar.set_running(false)
	_program_list.set_active_line(-1)
	_control_bar.set_status(action.message)
	_win_banner.visible = action.success
