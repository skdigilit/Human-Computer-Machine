class_name BriefingNote
extends Panel

## The "sticky note" above the program that states the level's title and the
## boss's instructions, echoing the briefing card in the original game.

signal previous_requested()
signal next_requested()
signal collapsed_changed(collapsed: bool)

var _body: Label
var _body_scroll: ScrollContainer
var _problem_text: String = ""
var _hint_text: String = ""
var _hint_button: Button
var _collapse_button: Button
var _show_hint_button: bool = true
var _hint_visible: bool = false
var _collapsed: bool = false

func _init() -> void:
	clip_contents = true
	_apply_panel_style()

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(VisualTheme.PAPER)
	style.border_color = Color.html(VisualTheme.INK)
	style.set_border_width_all(VisualTheme.scaled_int(4, 1, 24))
	style.set_corner_radius_all(VisualTheme.scaled_int(VisualTheme.UI_PANEL_RADIUS, 6, 72))
	add_theme_stylebox_override("panel", style)

## Fill the note from a level definition and show progression controls.
func set_level(level: Level, index: int = 0, total: int = 1) -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(14, 5, 60))
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", VisualTheme.scaled_int(8, 3, 40))
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", VisualTheme.scaled_int(8, 3, 36))
	column.add_child(header)

	var previous := _make_nav_button("<")
	previous.disabled = index <= 0
	previous.pressed.connect(func() -> void: previous_requested.emit())
	header.add_child(previous)

	var counter := Label.new()
	counter.text = "%d / %d" % [index + 1, total]
	counter.add_theme_color_override("font_color", Color.html("#6B5E40"))
	VisualTheme.apply_font_size(counter, 18)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(counter)

	_hint_button = _make_nav_button("?")
	_hint_button.tooltip_text = "Show hint"
	_hint_button.pressed.connect(show_hint)
	header.add_child(_hint_button)

	var next := _make_nav_button(">")
	next.disabled = index >= total - 1
	next.pressed.connect(func() -> void: next_requested.emit())
	header.add_child(next)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", VisualTheme.scaled_int(8, 3, 36))
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(title_row)

	var title := Label.new()
	title.text = level.title
	title.add_theme_color_override("font_color", Color.html("#3A3526"))
	VisualTheme.apply_font_size(title, 26, 8, 208)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	_collapse_button = _make_nav_button("+")
	_collapse_button.pressed.connect(func() -> void: set_collapsed(not _collapsed))
	title_row.add_child(_collapse_button)

	var briefing_parts := level.briefing.split("\n\n", false, 1)
	_problem_text = briefing_parts[0]
	_hint_text = briefing_parts[1] if briefing_parts.size() > 1 else ""
	_hint_visible = false
	_refresh_hint_button()

	_body = Label.new()
	_body.text = _problem_text
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", Color.html("#4A4534"))
	VisualTheme.apply_font_size(_body, 22, 8, 160)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body_width := Control.new()
	body_width.custom_minimum_size.x = 1
	body_width.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_width.add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_body_scroll.add_child(body_width)
	column.add_child(_body_scroll)
	_refresh_collapsed_state()

## Shows only the title when collapsed; the game resizes the instruction list
## in response to collapsed_changed.
func set_collapsed(collapsed: bool) -> void:
	if _collapsed == collapsed:
		return
	_collapsed = collapsed
	_refresh_collapsed_state()
	collapsed_changed.emit(_collapsed)

func is_collapsed() -> bool:
	return _collapsed

## Enough room for the navigation and title rows at the active UI scale.
func collapsed_height() -> float:
	return VisualTheme.scaled(150.0, 75.0, 1200.0)

func _refresh_collapsed_state() -> void:
	if _body_scroll != null:
		_body_scroll.visible = not _collapsed
	if _collapse_button != null:
		_collapse_button.text = "+" if _collapsed else "-"
		_collapse_button.tooltip_text = "Expand problem statement" if _collapsed else "Collapse problem statement"

## Toggles the hint text on/off in the briefing body.
func show_hint() -> void:
	if _body == null or _hint_text.is_empty():
		return
	_hint_visible = not _hint_visible
	_body.text = _problem_text + "\n\n" + _hint_text if _hint_visible else _problem_text

func set_hint_button_visible(show: bool) -> void:
	_show_hint_button = show
	_refresh_hint_button()

func _refresh_hint_button() -> void:
	if _hint_button == null:
		return
	_hint_button.visible = _show_hint_button and not _hint_text.is_empty()

func _make_nav_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = VisualTheme.button_min_size(text, Vector2(42, 42), 18, 28.0)
	var normal := VisualTheme.make_box_style(VisualTheme.PAPER, VisualTheme.INK, 0)
	var hover := VisualTheme.make_box_style(VisualTheme.SUN, VisualTheme.INK, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	VisualTheme.set_button_font_color(button, Color.html(VisualTheme.INK))
	VisualTheme.apply_font_size(button, 18)
	return button
