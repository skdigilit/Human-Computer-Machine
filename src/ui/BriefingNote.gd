class_name BriefingNote
extends PanelContainer

## The "sticky note" above the program that states the level's title and the
## boss's instructions, echoing the briefing card in the original game.

signal previous_requested()
signal next_requested()

var _body: Label
var _hint_button: Button
var _problem_text: String = ""
var _hint_text: String = ""

func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(VisualTheme.PAPER)
	style.border_color = Color.html(VisualTheme.INK)
	style.set_border_width_all(4)
	style.set_corner_radius_all(VisualTheme.UI_PANEL_RADIUS)
	add_theme_stylebox_override("panel", style)

## Fill the note from a level definition and show progression controls.
func set_level(level: Level, index: int = 0, total: int = 1) -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)

	var previous := _make_nav_button("<")
	previous.disabled = index <= 0
	previous.pressed.connect(func() -> void: previous_requested.emit())
	header.add_child(previous)

	var counter := Label.new()
	counter.text = "%d / %d" % [index + 1, total]
	counter.add_theme_color_override("font_color", Color.html("#6B5E40"))
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(counter)

	var next := _make_nav_button(">")
	next.disabled = index >= total - 1
	next.pressed.connect(func() -> void: next_requested.emit())
	header.add_child(next)

	var title := Label.new()
	title.text = level.title
	title.add_theme_color_override("font_color", Color.html("#3A3526"))
	title.add_theme_font_size_override("font_size", 26)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(title)

	var briefing_parts := level.briefing.split("\n\n", false, 1)
	_problem_text = briefing_parts[0]
	_hint_text = briefing_parts[1] if briefing_parts.size() > 1 else ""

	_body = Label.new()
	_body.text = _problem_text
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", Color.html("#4A4534"))
	_body.add_theme_font_size_override("font_size", 16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body_width := Control.new()
	body_width.custom_minimum_size.x = 1
	body_width.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_width.add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(body_width)
	column.add_child(scroll)

	_hint_button = _make_hint_button()
	_hint_button.visible = not _hint_text.is_empty()
	_hint_button.toggled.connect(_on_hint_toggled)
	column.add_child(_hint_button)

func _on_hint_toggled(show_hint: bool) -> void:
	_body.text = _problem_text + ("\n\n" + _hint_text if show_hint else "")
	_hint_button.text = "HIDE HINT" if show_hint else "SHOW HINT"

func _make_hint_button() -> Button:
	var button := _make_nav_button("SHOW HINT")
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 42)
	return button

func _make_nav_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(42, 42)
	var normal := VisualTheme.make_box_style(VisualTheme.PAPER, VisualTheme.INK, 0)
	var hover := VisualTheme.make_box_style(VisualTheme.SUN, VisualTheme.INK, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	VisualTheme.set_button_font_color(button, Color.html(VisualTheme.INK))
	return button
