class_name HCMSettings
extends RefCounted

const SETTINGS_PATH := "user://settings.json"

const SHOW_HINT_BUTTON := "show_hint_button"
const SHOW_OUTBOX_EXPECTED_BOXES := "show_outbox_expected_boxes"
const CLICK_TO_PICKUP_INSTRUCTION_BOX := "click_to_pickup_instruction_box"
const CUSTOM_CURSOR := "custom_cursor"
## Multiplier on the custom cursor's base size (1.0 = default art size).
const CURSOR_SIZE := "cursor_size"
## User-controlled UI scale, same value the +/- keys adjust.
const UI_SCALE := "ui_scale"
## Room panel width in pixels, set by dragging the room/sidebar split.
const ROOM_WIDTH := "room_width"
## Palette-vs-editor width split within the right-hand sidebar (0..1).
const PALETTE_SIDEBAR_RATIO := "palette_sidebar_ratio"
## Briefing-vs-program-list height split in the editor stack (0..1).
const EDITOR_QUESTION_RATIO := "editor_question_ratio"
## The currently selected built-in level index.
const CURRENT_LEVEL_INDEX := "current_level_index"

## Defaults double as each setting's type: loaded values are cast to the type
## of the default here, so bools and numbers can share the one store.
var values: Dictionary = {
	SHOW_HINT_BUTTON: true,
	SHOW_OUTBOX_EXPECTED_BOXES: false,
	CLICK_TO_PICKUP_INSTRUCTION_BOX: false,
	CUSTOM_CURSOR: false,
	CURSOR_SIZE: 1.5,
	UI_SCALE: 1.0,
	ROOM_WIDTH: 0.0,
	PALETTE_SIDEBAR_RATIO: 0.0,
	EDITOR_QUESTION_RATIO: 0.0,
	CURRENT_LEVEL_INDEX: 0,
}

var _raw: Dictionary = {}
var settings_path: String = SETTINGS_PATH

func load_from_disk() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open settings file.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	_raw = parsed
	var loaded: Variant = _raw.get("settings", {})
	if not (loaded is Dictionary):
		return
	for key in values.keys():
		if not loaded.has(key):
			continue
		# Cast to the default's type so loaded values keep the same shape.
		if values[key] is bool:
			values[key] = bool(loaded[key])
		elif values[key] is int:
			values[key] = int(loaded[key])
		else:
			values[key] = float(loaded[key])

func save_to_disk() -> void:
	var stored_settings: Variant = _raw.get("settings", {})
	var settings: Dictionary = stored_settings if stored_settings is Dictionary else {}
	for key in values.keys():
		settings[key] = values[key]
	_raw["version"] = int(_raw.get("version", 1))
	_raw["settings"] = settings

	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save settings.")
		return
	file.store_string(JSON.stringify(_raw, "\t"))

func set_value(key: String, value: Variant) -> void:
	if not values.has(key):
		return
	values[key] = value
	save_to_disk()

func is_enabled(key: String) -> bool:
	return bool(values.get(key, false))

## Reads a numeric setting (e.g. CURSOR_SIZE), falling back to `default`.
func get_number(key: String, default: float = 1.0) -> float:
	return float(values.get(key, default))

func get_int(key: String, default: int = 0) -> int:
	return int(values.get(key, default))
