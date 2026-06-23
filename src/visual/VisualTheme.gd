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

# --- Number boxes -------------------------------------------------------------
const BOX_FILL := PAPER
const BOX_FILL_DARK := "#E4DDBE"
const BOX_BORDER := INK
const BOX_TEXT := INK

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

# --- Animation timing (seconds) ----------------------------------------------
const WALK_TIME := 0.42
const PICK_TIME := 0.22
const BUMP_TIME := 0.15
const UI_FONT := "res://Fonts/MonaspaceNeon-WideSemiBold.otf"
const UI_FONT_BOLD := "res://Fonts/MonaspaceRadon-SemiWideBold.otf"

## Standard modular panel used by the warehouse UI.
static func make_box_style(fill_hex: String, border_hex: String, radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(fill_hex)
	style.border_color = Color.html(border_hex)
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.shadow_size = 0
	return style

static func make_ui_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = load(UI_FONT)
	ui_theme.default_font_size = 18
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
