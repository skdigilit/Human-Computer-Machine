class_name SnakeGame
extends Game

## Snake mode orchestrator. Everything on screen is the office game's UI —
## palette, briefing, program list, control bar, settings — only the stage,
## the machine, the level list and a few bits of pacing/input differ, so this
## overrides just Game's mode hooks.
##
## Launched from snake_main.tscn as its own scene.

const SNAKE_SAVE_PATH := "user://snake_pages.json"
## Read-only compatibility for instruction pages saved with the former key rows.
## Game._save_current_level preserves their metadata without rewriting it.
var _key_handlers_by_page: Array[Array] = []

func _ready() -> void:
	super()
	_control_bar.set_speed_visible(false)
	# The wait block in the program shows the arena countdown progress.
	if _room is SnakeArena:
		(_room as SnakeArena).wait_progress.connect(_on_wait_progress)

# --- Game hooks ----------------------------------------------------------------

func _create_stage() -> StageView:
	return SnakeArena.new()

func _load_levels() -> Array[Level]:
	return SnakeLevelLibrary.all_levels()

func _create_vm() -> VM:
	var vm := SnakeVM.new(_level, _program)
	vm.key_handler_slots = _current_handler_slots()
	return vm

func _after_animation(action: StepAction) -> void:
	if action.op == InstructionDef.Op.TICK and _vm is SnakeVM:
		(_vm as SnakeVM).complete_wait()
	if _vm is SnakeVM:
		_program_list.set_memory_snapshot((_vm as SnakeVM).memory, (_vm as SnakeVM).memory_key_flags, (_level as SnakeLevel).wait_scale_slot)

func _level_index_setting_key() -> String:
	return HCMSettingsScript.SNAKE_LEVEL_INDEX

func _default_save_path() -> String:
	return SNAKE_SAVE_PATH

## No pause between steps: a wait is spent inside the arena's animate call
## (so the highlight stays on the wait block while it fills), and every other
## instruction runs on the next frame so a whole game frame of checks feels
## instant.
func _delay_after(_action: StepAction) -> float:
	return 0.0

func _idle_status() -> String:
	return "KEY PRESS [0] records keys. WAIT, then MOVE [0] reads the stored key."

## Capture printable keys while a run is active. Armed KEY PRESS slots update
## immediately; a key pressed before arming is buffered for that instruction.
func _handle_mode_key(key: InputEventKey) -> bool:
	var value := SnakeKey.from_event(key)
	if value == SnakeKey.NONE or not _vm is SnakeVM or _halted:
		return false
	(_vm as SnakeVM).press_key(value)
	(_room as SnakeArena).update_memory((_vm as SnakeVM).memory, (_vm as SnakeVM).memory_key_flags)
	_program_list.set_memory_snapshot((_vm as SnakeVM).memory, (_vm as SnakeVM).memory_key_flags, (_level as SnakeLevel).wait_scale_slot)
	return true

func _on_play_toggled(should_run: bool) -> void:
	if _room is SnakeArena:
		(_room as SnakeArena).set_manual_wait(false)
		(_room as SnakeArena).set_wait_paused(not should_run)
	super(should_run)

func _on_step() -> void:
	if _running:
		return
	if _room is SnakeArena:
		var arena := _room as SnakeArena
		arena.set_manual_wait(true)
		arena.set_wait_paused(false)
		# Finish this WAIT only; repeated clicks must not queue the next line.
		if arena.is_waiting():
			return
	super()

## The board size comes from Settings, so refresh the override before the
## arena and machine are rebuilt.
func _reset_run() -> void:
	SnakeLevel.grid_size_override = _settings.get_int(HCMSettingsScript.SNAKE_GRID_SIZE, SnakeState.DEFAULT_GRID_SIZE)
	super()
	(_room as SnakeArena).set_visible_memory_slots(_memory_slots_in_program())
	var initial_values: Array[int] = []
	var initial_flags: Array[bool] = []
	for i in _level.memory_size:
		initial_values.append(int(_level.initial_memory.get(i, StepAction.NULL_VALUE)))
		initial_flags.append(i == 0)
	_program_list.set_memory_snapshot(initial_values, initial_flags, (_level as SnakeLevel).wait_scale_slot)

func _memory_slots_in_program() -> Array[int]:
	var slots: Array[int] = []
	if _level.memory_size > 0:
		slots.append(0)
	var snake_level := _level as SnakeLevel
	if snake_level and snake_level.wait_scale_slot >= 0:
		slots.append(snake_level.wait_scale_slot)
	for instruction in _program.instructions:
		if InstructionDef.operand_kind_for(instruction.op) != InstructionDef.OperandKind.ADDRESS:
			continue
		if instruction.address >= 0 and instruction.address < _level.memory_size and not slots.has(instruction.address):
			slots.append(instruction.address)
	return slots

## A changed board size in Settings restarts the current run on the new board.
func _apply_settings() -> void:
	super()
	if _room == null or _level == null:
		return
	var wanted: int = _settings.get_int(HCMSettingsScript.SNAKE_GRID_SIZE, SnakeState.DEFAULT_GRID_SIZE)
	if wanted != SnakeLevel.grid_size_override:
		_reset_run()

# --- Legacy key-handler metadata --------------------------------------------

func _load_level_pages() -> void:
	super()
	_key_handlers_by_page.clear()
	var level_record: Variant = _saved_levels.get(_level_save_key(), {})
	var stored: Variant = level_record.get("key_handlers_by_page", []) if level_record is Dictionary else []
	for i in _program_pages.size():
		var page_slots: Variant = stored[i] if stored is Array and i < stored.size() else []
		_key_handlers_by_page.append(_validated_slots(page_slots))

func _current_handler_slots() -> Array[int]:
	if _active_page >= 0 and _active_page < _key_handlers_by_page.size():
		return _validated_slots(_key_handlers_by_page[_active_page])
	return _default_slots()

func _validated_slots(raw: Variant) -> Array[int]:
	var slots := _default_slots()
	if raw is Array:
		for i in mini(4, raw.size()):
			slots[i] = clampi(int(raw[i]), -1, maxi(0, _level.memory_size - 1))
	return slots

func _default_slots() -> Array[int]:
	return [-1, -1, -1, -1] as Array[int]

# --- Wait progress -------------------------------------------------------------

## Mirror the countdown onto the wait block; 1.0 (done) clears it.
func _on_wait_progress(line_index: int, elapsed_fraction: float) -> void:
	if elapsed_fraction >= 1.0:
		_program_list.set_line_progress(-1, 0.0)
	else:
		_program_list.set_line_progress(line_index, elapsed_fraction)
