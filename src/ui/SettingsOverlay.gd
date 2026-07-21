class_name SettingsOverlay
extends Control

signal close_requested()
## Emitted once when the overlay closes, carrying every setting the user
## may have changed while it was open (settings are not applied live).
signal settings_confirmed(settings: Dictionary)
## Requests that the active instruction workspace page be cleared.
signal clear_current_page_requested()

const TAB_ACCESSIBILITY := "accessibility"
const TAB_DATA := "data"
const TAB_PLAYER := "player"
## Granularity of the cursor-size slider (multiplier steps).
const CURSOR_SIZE_STEP := 0.25
## Instruction-font-size slider bounds and granularity (multiplier).
const INSTRUCTION_FONT_MIN := 1.0
const INSTRUCTION_FONT_MAX := 2.0
const INSTRUCTION_FONT_STEP := 0.1
const HCMSettingsScript := preload("res://src/ui/HCMSettings.gd")

var _settings: Dictionary = {}
var _active_tab := TAB_ACCESSIBILITY
var _panel: PanelContainer
var _tab_buttons: Dictionary = {}
var _content: VBoxContainer
var _toggles: Dictionary = {}
## key -> HSlider, so _sync_toggles can refresh numeric rows too.
var _sliders: Dictionary = {}

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	theme = VisualTheme.make_ui_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_build()

func setup(settings: Dictionary) -> void:
	_settings = settings.duplicate()
	_sync_toggles()

func open() -> void:
	visible = true
	_active_tab = TAB_ACCESSIBILITY
	_refresh_tabs()
	_refresh_content()

func close() -> void:
	visible = false
	settings_confirmed.emit(_settings.duplicate())

func apply_ui_scale() -> void:
	theme = VisualTheme.make_ui_theme()
	if get_child_count() > 0:
		for child in get_children():
			child.queue_free()
		_tab_buttons.clear()
		_toggles.clear()
		_sliders.clear()
		_build()
		_sync_toggles()

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color.html(VisualTheme.ROOM_FLOOR_DARK)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = _panel_size()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(18, 8, 48))
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", VisualTheme.scaled_int(14, 6, 36))
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", VisualTheme.scaled_int(10, 4, 28))
	root.add_child(header)

	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color.html(VisualTheme.PAPER))
	VisualTheme.apply_font_size(title, 30, 14, 72)
	header.add_child(title)

	var close_button := _make_button("X")
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", VisualTheme.scaled_int(14, 6, 36))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(VisualTheme.scaled(260.0, 170.0, 380.0), 0)
	tabs.add_theme_constant_override("separation", VisualTheme.scaled_int(8, 4, 24))
	body.add_child(tabs)

	_add_tab_button(tabs, TAB_ACCESSIBILITY, "Accessibility")
	_add_tab_button(tabs, TAB_DATA, "Data")
	_add_tab_button(tabs, TAB_PLAYER, "Player")

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", VisualTheme.scaled_int(12, 5, 32))
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content)

	_refresh_tabs()
	_refresh_content()

func _add_tab_button(parent: VBoxContainer, key: String, text: String) -> void:
	var button := _make_button(text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_select_tab.bind(key))
	parent.add_child(button)
	_tab_buttons[key] = button

func _select_tab(key: String) -> void:
	_active_tab = key
	_refresh_tabs()
	_refresh_content()

func _refresh_tabs() -> void:
	for key in _tab_buttons.keys():
		var button: Button = _tab_buttons[key]
		_apply_button_style(button, key == _active_tab)

func _refresh_content() -> void:
	for child in _content.get_children():
		child.queue_free()
	_toggles.clear()
	_sliders.clear()

	match _active_tab:
		TAB_ACCESSIBILITY:
			_add_accessibility_options()
		TAB_DATA:
			_add_data_options()
		TAB_PLAYER:
			_add_empty_section("Player")

func _add_accessibility_options() -> void:
	_add_toggle(HCMSettingsScript.SHOW_HINT_BUTTON, "Show hint button")
	_add_toggle(HCMSettingsScript.SHOW_OUTBOX_EXPECTED_BOXES, "Show expected outbox boxes")
	_add_toggle(HCMSettingsScript.CLICK_TO_PICKUP_INSTRUCTION_BOX, "Click to pickup instruction box")
	_add_toggle(HCMSettingsScript.CUSTOM_CURSOR, "Custom cursor")
	_add_slider(HCMSettingsScript.CURSOR_SIZE, "Cursor size",
			SoftwareCursor.MIN_SIZE_SCALE, SoftwareCursor.MAX_SIZE_SCALE, CURSOR_SIZE_STEP)
	_add_slider(HCMSettingsScript.INSTRUCTION_FONT_SCALE, "Instruction font size",
			INSTRUCTION_FONT_MIN, INSTRUCTION_FONT_MAX, INSTRUCTION_FONT_STEP)

func _add_data_options() -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(14, 6, 32))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(10, 5, 28))
	row.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", VisualTheme.scaled_int(10, 5, 24))
	margin.add_child(content)

	var title := Label.new()
	title.text = "Instruction workspace"
	title.add_theme_color_override("font_color", Color.html(VisualTheme.PAPER))
	VisualTheme.apply_font_size(title, 22, 12, 60)
	content.add_child(title)

	var description := Label.new()
	description.text = "Remove all placed instructions from the current page."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color.html(VisualTheme.PAPER))
	VisualTheme.apply_font_size(description, 16, 9, 42)
	content.add_child(description)

	var clear_button := _make_button("Clear current page")
	clear_button.tooltip_text = "Remove every instruction from the current page"
	clear_button.pressed.connect(func() -> void: clear_current_page_requested.emit())
	content.add_child(clear_button)

func _add_empty_section(title_text: String) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(14, 6, 32))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(10, 5, 28))
	row.add_child(margin)

	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", Color.html(VisualTheme.PAPER))
	VisualTheme.apply_font_size(title, 24, 12, 64)
	margin.add_child(title)

func _add_toggle(key: String, text: String) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(14, 6, 32))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(10, 5, 28))
	row.add_child(margin)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", VisualTheme.scaled_int(12, 6, 28))
	margin.add_child(line)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.html(VisualTheme.PAPER))
	VisualTheme.apply_font_size(label, 18, 10, 48)
	line.add_child(label)

	var toggle := CheckButton.new()
	toggle.button_pressed = bool(_settings.get(key, false))
	toggle.toggled.connect(_on_toggle_changed.bind(key))
	line.add_child(toggle)
	_toggles[key] = toggle

## Adds a labelled HSlider row (same visual row style as the toggles) whose
## value is shown as a percentage; applied only once the overlay closes.
func _add_slider(key: String, text: String, min_value: float, max_value: float, step: float) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(14, 6, 32))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(10, 5, 28))
	row.add_child(margin)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", VisualTheme.scaled_int(12, 6, 28))
	margin.add_child(line)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.html(VisualTheme.PAPER))
	VisualTheme.apply_font_size(label, 18, 10, 48)
	line.add_child(label)

	var value_label := Label.new()
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color.html(VisualTheme.PAPER))
	VisualTheme.apply_font_size(value_label, 18, 10, 48)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(_settings.get(key, min_value))
	slider.custom_minimum_size = Vector2(VisualTheme.scaled(240.0, 150.0, 420.0), 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label))
	line.add_child(slider)

	value_label.text = _percent_text(slider.value)
	line.add_child(value_label)
	_sliders[key] = slider

func _on_toggle_changed(enabled: bool, key: String) -> void:
	_settings[key] = enabled

func _on_slider_changed(value: float, key: String, value_label: Label) -> void:
	_settings[key] = value
	value_label.text = _percent_text(value)

static func _percent_text(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

func _sync_toggles() -> void:
	for key in _toggles.keys():
		var toggle: CheckButton = _toggles[key]
		toggle.set_pressed_no_signal(bool(_settings.get(key, false)))
	for key in _sliders.keys():
		var slider: HSlider = _sliders[key]
		slider.set_value_no_signal(float(_settings.get(key, slider.min_value)))

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	VisualTheme.apply_button_size(button, Vector2(60, 48), 20, 36.0)
	_apply_button_style(button, false)
	return button

func _panel_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		clampf(viewport_size.x * 0.74, VisualTheme.scaled(860.0, 560.0, 1200.0), VisualTheme.scaled(1480.0, 920.0, 1800.0)),
		clampf(viewport_size.y * 0.76, VisualTheme.scaled(660.0, 440.0, 920.0), VisualTheme.scaled(1060.0, 700.0, 1280.0))
	)

func _apply_button_style(button: Button, active: bool) -> void:
	var fill := VisualTheme.SUN if active else "#2A312D"
	var border := "#A06D11" if active else "#59655B"
	var text := Color.html(VisualTheme.INK) if active else Color.html(VisualTheme.PAPER)
	var normal := VisualTheme.make_box_style(fill, border, 4)
	var hover := VisualTheme.make_box_style("#E7B840" if active else "#3C463F", border, 4)
	for style in [normal, hover]:
		style.content_margin_left = VisualTheme.scaled(16.0, 8.0, 40.0)
		style.content_margin_right = VisualTheme.scaled(16.0, 8.0, 40.0)
		style.content_margin_top = VisualTheme.scaled(8.0, 4.0, 24.0)
		style.content_margin_bottom = VisualTheme.scaled(8.0, 4.0, 24.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	VisualTheme.set_button_font_color(button, text)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(VisualTheme.ROOM_WALL)
	style.border_color = Color.html(VisualTheme.PAPER)
	style.set_border_width_all(VisualTheme.scaled_int(4, 2, 18))
	style.set_corner_radius_all(VisualTheme.scaled_int(8, 4, 24))
	return style

func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html("#222922")
	style.border_color = Color.html("#59655B")
	style.set_border_width_all(VisualTheme.scaled_int(2, 1, 10))
	style.set_corner_radius_all(VisualTheme.scaled_int(6, 3, 18))
	return style
