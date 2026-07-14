class_name VisualTheme
extends RefCounted

## Named constants for every colour and dimension used by the presentation
## layer. Centralising them satisfies the "name your UI parameters" rule and
## means re-skinning the game is a one-file change.

# --- Room palette (high-contrast modular warehouse) ---------------------------
const ROOM_FLOOR := "#111513"
const ROOM_FLOOR_DARK := "#080A09"
const ROOM_WALL := "#171C19"
const STATION_FRAME := "#F5F0DA"
const INK := "#171915"
const PAPER := "#F7F2DE"
const SKY := "#43A9D5"
const SUN := "#F0BD36"
const CORAL := "#E56442"
const PLUM := "#6D405F"

# --- Number boxes (I/O green family, to match --fam-io command blocks) --------
# green-300 fill / green-700 border / green-900 numeral. --fam-io (#7DA33B) is
# the mid of this ramp (BOX_FILL_DARK); the lighter fill keeps boxes distinct
# from the green inbox/outbox command blocks sitting beside them.
const BOX_FILL := "#9FC65A"
const BOX_FILL_DARK := "#7DA33B"
const BOX_BORDER := "#5E7C29"
const BOX_TEXT := "#2C3A12"
const BOX_SUCCESS_FILL := "#B8D9A6"
const BOX_SUCCESS_BORDER := "#48683A"
const BOX_ERROR_FILL := "#E7A8A1"
const BOX_ERROR_BORDER := "#8B3C35"
# Memory boxes wear an orange coat once they come to rest on a floor tile — a
# required cue that the value now lives in memory, unlike a carried / inbox box
# (green) or an outbox box (success/error). Distinct in hue from the salmon
# memory-tile frame the orange box sits inside.
const BOX_MEMORY_FILL := "#F0A83C"
const BOX_MEMORY_BORDER := "#A0530F"
const BOX_MEMORY_TEXT := "#3A2306"

# --- Station outlines ---------------------------------------------------------
# Inbox / outbox chutes and memory tiles are one cell wide, exactly like the
# number boxes dropped into them, so an inside-drawn border would be hidden the
# moment a box lands. These widths are paired with an equal expand margin so the
# border is drawn OUTWARD, framing the box and staying visible when occupied.
const CHUTE_BORDER_WIDTH := 6
const CHUTE_BORDER_EXPAND := 6
const TILE_BORDER_WIDTH := 5
const TILE_BORDER_EXPAND := 5

# --- Worker (Wilmort-style blocky character) ----------------------------------
const WORKER_BODY := PAPER
const WORKER_BODY_SHADE := SKY
const WORKER_FACE := INK

# --- Sizes --------------------------------------------------------------------
const CELL_SIZE := 72.0
const BOX_SIZE := Vector2(CELL_SIZE, CELL_SIZE)
const TILE_SIZE := Vector2(CELL_SIZE, CELL_SIZE)
const WORKER_SIZE := Vector2(CELL_SIZE, CELL_SIZE)
const UI_PANEL_RADIUS := 18
const BASE_VIEWPORT_SIZE := Vector2(1900.0, 1400.0)
const USER_UI_SCALE_MIN := 0.50
const USER_UI_SCALE_MAX := 3.00
const VIEWPORT_UI_SCALE_MIN := 1.0
const VIEWPORT_UI_SCALE_MAX := 1.60
const EFFECTIVE_UI_SCALE_MIN := 0.45
const EFFECTIVE_UI_SCALE_MAX := 4.00
const UI_SCALE_STEP := 0.10

# --- Animation timing (seconds) ----------------------------------------------
const WALK_TIME := 0.42
const PICK_TIME := 0.22
const BUMP_TIME := 0.15
const UI_FONT := "res://Fonts/MonaspaceNeon-WideSemiBold.otf"
const UI_FONT_BOLD := "res://Fonts/MonaspaceRadon-SemiWideBold.otf"
const UI_FONT_HEAVY_ITALIC := "res://Fonts/MonaspaceNeon-BoldItalic.otf"

static var user_ui_scale := 1.0
static var viewport_ui_scale := 1.0

static func set_viewport_size(viewport_size: Vector2) -> bool:
	var previous := viewport_ui_scale
	var width_ratio := viewport_size.x / BASE_VIEWPORT_SIZE.x
	var height_ratio := viewport_size.y / BASE_VIEWPORT_SIZE.y
	viewport_ui_scale = clampf(
		minf(width_ratio, height_ratio),
		VIEWPORT_UI_SCALE_MIN,
		VIEWPORT_UI_SCALE_MAX
	)
	return not is_equal_approx(previous, viewport_ui_scale)

static func adjust_user_ui_scale(direction: int) -> bool:
	var previous := user_ui_scale
	user_ui_scale = clampf(
		user_ui_scale + float(direction) * UI_SCALE_STEP,
		USER_UI_SCALE_MIN,
		USER_UI_SCALE_MAX
	)
	return not is_equal_approx(previous, user_ui_scale)

static func effective_ui_scale() -> float:
	return clampf(
		user_ui_scale * viewport_ui_scale,
		EFFECTIVE_UI_SCALE_MIN,
		EFFECTIVE_UI_SCALE_MAX
	)

static func scaled(value: float, minimum: float = -INF, maximum: float = INF) -> float:
	return clampf(roundf(value * effective_ui_scale()), minimum, maximum)

static func scaled_int(value: float, minimum: int = 1, maximum: int = 4096) -> int:
	return clampi(int(roundf(value * effective_ui_scale())), minimum, maximum)

static func scaled_size(value: Vector2, minimum: Vector2 = Vector2.ZERO, maximum: Vector2 = Vector2(INF, INF)) -> Vector2:
	return Vector2(
		scaled(value.x, minimum.x, maximum.x),
		scaled(value.y, minimum.y, maximum.y)
	)

static func scaled_font_size(value: int, minimum: int = 6, maximum: int = 320) -> int:
	return scaled_int(value, minimum, maximum)

static func apply_font_size(control: Control, base_size: int, minimum: int = 6, maximum: int = 320) -> void:
	control.add_theme_font_size_override("font_size", scaled_font_size(base_size, minimum, maximum))

## Font size with an extra multiplier layered on top of the global UI scale.
## Used by the instruction-font accessibility option so only the instruction
## blocks grow while the rest of the UI keeps its size.
static func apply_font_size_mult(control: Control, base_size: int, mult: float, minimum: int = 6, maximum: int = 320) -> void:
	control.add_theme_font_size_override("font_size", scaled_int(float(base_size) * mult, minimum, maximum))

## Button variant of apply_font_size_mult: the font and the button's minimum box
## grow by `mult`, but the horizontal padding is left unscaled so the chip keeps
## the same padding around its larger text.
static func apply_button_size_mult(button: Button, base_size: Vector2, base_font_size: int, mult: float, horizontal_padding: float = 32.0) -> void:
	apply_font_size_mult(button, base_font_size, mult)
	button.custom_minimum_size = button_min_size(
		button.text, base_size * mult, int(roundf(float(base_font_size) * mult)), horizontal_padding
	)

static func apply_ui_font(control: Control, bold: bool = false, italic: bool = false) -> void:
	var font_path := UI_FONT
	if italic and bold:
		font_path = UI_FONT_HEAVY_ITALIC
	elif bold:
		font_path = UI_FONT_BOLD
	control.add_theme_font_override("font", load(font_path))

static func label_min_width(text: String, base_font_size: int, horizontal_padding: float) -> float:
	return float(text.length()) * float(scaled_font_size(base_font_size)) * 0.76 + scaled(horizontal_padding)

static func button_min_size(text: String, base_size: Vector2, base_font_size: int, horizontal_padding: float = 32.0) -> Vector2:
	var scaled_base := scaled_size(base_size)
	scaled_base.x = maxf(scaled_base.x, label_min_width(text, base_font_size, horizontal_padding))
	return scaled_base

static func apply_button_size(button: Button, base_size: Vector2, base_font_size: int, horizontal_padding: float = 32.0) -> void:
	apply_font_size(button, base_font_size)
	button.custom_minimum_size = button_min_size(button.text, base_size, base_font_size, horizontal_padding)

## Standard modular panel used by the warehouse UI.
static func make_box_style(fill_hex: String, border_hex: String, radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(fill_hex)
	style.border_color = Color.html(border_hex)
	style.set_border_width_all(scaled_int(3, 1, 18))
	style.set_corner_radius_all(0 if radius == 0 else scaled_int(radius, 1, 96))
	style.shadow_size = 0
	return style

static func make_ui_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = load(UI_FONT)
	ui_theme.default_font_size = scaled_font_size(18)
	return ui_theme

## Keep button text readable when Godot switches between interaction states.
static func set_button_font_color(button: Button, color: Color) -> void:
	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_focus_color",
		"font_disabled_color",
	]:
		button.add_theme_color_override(state, color)
