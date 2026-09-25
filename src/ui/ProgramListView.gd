class_name ProgramListView
extends Control

## The numbered program — the heart of the editor. It:
##  * renders one row per instruction,
##  * accepts palette drops (insert) and self drops (reorder),
##  * shows an empty "landing slot" where a dragged command will fall,
##  * deletes a line when it is dragged out of the list,
##  * lets a jump's arrow be dragged onto a line to set its target,
##  * gives every jump a dummy instruction box before its destination row,
##  * highlights the executing line.

signal program_changed()
signal page_requested(index: int)
signal add_page_requested()

const LINE_NUMBER_WIDTH := 34.0
const HEADER_HEIGHT := 50.0
const MAX_PAGES := 3
const TARGET_BOX_SIZE := Vector2(86, 34)
const ROW_DIM_ALPHA := 0.3 ## Opacity of a line while it is being dragged.
const CONNECTOR_LANE_GAP := 10.0
const CONNECTOR_WIDTH := 4.0
const CONNECTOR_HOVER_WIDTH := 6.0
const CONNECTOR_HALO_EXTRA := 4.0        ## Extra stroke width of the pale outline behind a connector.
const CONNECTOR_HOVER_DISTANCE := 8.0    ## Cursor distance (px) that counts as hovering the line.
const CONNECTOR_COLOR := "#5A66B0"
const CONNECTOR_HOVER_COLOR := "#3F7BFF"
const CONNECTOR_HALO_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const CONNECTOR_PROGRESS_COLOR := InstructionDef.COLOR_TICK  ## Countdown overlay on a waiting clock's connector.
const LIST_BOTTOM_PADDING := 96.0        ## Empty space after the last line so it can be scrolled clear.

var program: Program
var memory_size: int = 0
var _memory_values_snapshot: Array[int] = []
var _wait_scale_slot: int = -1
var _memory_key_snapshot: Array[bool] = []

var _scroll: ScrollContainer
var _list: VBoxContainer
var _blocks: Array[InstructionBlock] = []
var _hovered_block: InstructionBlock = null
var _active_index: int = -1
## Line currently showing a progress fill (snake wait), -1 when none.
var _progress_index: int = -1
## Instruction id and elapsed fraction of that wait, so the underlay can draw
## the same countdown travelling along the block's own connector.
var _progress_id: int = -1
var _progress_fraction: float = 0.0
var _jump_underlay: Control
var _page_header: HBoxContainer
var _target_boxes: Dictionary = {} ## Jump instruction id -> dummy target box.
var _page_buttons: Array[Button] = []
var _add_page_button: Button
var _active_page: int = 0
var _page_count: int = 1

# Drag-session state -----------------------------------------------------------
var _placeholder: PanelContainer            ## The empty landing slot.
var _row_centers: Array[float] = []         ## Global y-centres cached at drag start.
var _dragging_block: InstructionBlock = null  ## Line being reordered (for delete).
var _drop_handled: bool = false             ## True once a drop was consumed here.
var _jump_drag_source: InstructionBlock = null  ## Jump whose arrow is being dragged.
var _jump_drag_origin: Control = null       ## Handle or blank box drag started from.
var _candidate_block: InstructionBlock = null   ## Line a dragged arrow points at.
var _bottom_pad: Control = null             ## Spacer row after the last instruction.
var _hovered_jump_id: int = -1              ## Jump whose connector is drawn highlighted.

func _init() -> void:
	clip_contents = true

func _ready() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# Connectors live below the scroll/list, so they never intercept input or
	# paint over command blocks and target markers.
	_jump_underlay = Control.new()
	_jump_underlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_jump_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jump_underlay.draw.connect(_draw_jump_underlay)
	add_child(_jump_underlay)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_scroll_offsets()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", VisualTheme.scaled_int(5, 2, 28))
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)

	_build_page_header()
	_placeholder = _make_placeholder()
	set_process(true)

func _build_page_header() -> void:
	_page_header = HBoxContainer.new()
	_page_header.position = Vector2(10, 8)
	_page_header.size = Vector2(size.x - 20, 34)
	_page_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_apply_header_offsets()
	_page_header.add_theme_constant_override("separation", VisualTheme.scaled_int(6, 2, 28))
	add_child(_page_header)

	for i in MAX_PAGES:
		var page_button := Button.new()
		page_button.text = str(i + 1)
		VisualTheme.apply_button_size(page_button, Vector2(42, 34), 18, 24.0)
		page_button.pressed.connect(_on_page_button_pressed.bind(i))
		_page_header.add_child(page_button)
		_page_buttons.append(page_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_header.add_child(spacer)

	_add_page_button = Button.new()
	_add_page_button.text = "+"
	_add_page_button.tooltip_text = "Add instruction page"
	VisualTheme.apply_button_size(_add_page_button, Vector2(42, 34), 24, 20.0)
	_add_page_button.pressed.connect(func() -> void: add_page_requested.emit())
	_page_header.add_child(_add_page_button)
	_refresh_page_header()

func _on_page_button_pressed(index: int) -> void:
	page_requested.emit(index)

func _refresh_page_header() -> void:
	for i in _page_buttons.size():
		var button := _page_buttons[i]
		button.visible = i < _page_count
		_apply_page_button_style(button, i == _active_page)
		button.tooltip_text = "Instruction page %d" % (i + 1)
	if _add_page_button:
		_add_page_button.disabled = _page_count >= MAX_PAGES
		_add_page_button.tooltip_text = (
			"Maximum of three instruction pages"
			if _add_page_button.disabled
			else "Add instruction page"
		)

func _apply_page_button_style(button: Button, is_active: bool) -> void:
	var fill := VisualTheme.SUN if is_active else "#B8AE91"
	var border := "#8A6415" if is_active else "#8C8269"
	var text := Color.html(VisualTheme.INK) if is_active else Color(0.22, 0.21, 0.17, 0.55)
	var style := VisualTheme.make_box_style(fill, border, 4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style if is_active else VisualTheme.make_box_style("#CDC3A5", border, 4))
	button.add_theme_stylebox_override("pressed", style)
	VisualTheme.set_button_font_color(button, text)
	var base_font_size := 24 if button == _add_page_button else 18
	VisualTheme.apply_button_size(button, Vector2(42, 34), base_font_size, 24.0)

## The dashed empty slot shown at the drop position.
func _make_placeholder() -> PanelContainer:
	var slot := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.18)
	style.border_color = Color.html("#8C7E5C")
	style.set_border_width_all(VisualTheme.scaled_int(2, 1, 14))
	style.set_corner_radius_all(VisualTheme.scaled_int(7, 2, 36))
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size = VisualTheme.scaled_size(Vector2(0, 42), Vector2(0, 18), Vector2(0, 344))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := Label.new()
	hint.text = "DROP MOVE HERE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.3, 0.27, 0.18, 0.7))
	VisualTheme.apply_font_size(hint, 16, 6, 136)
	slot.add_child(hint)
	return slot

func apply_ui_scale() -> void:
	for child in get_children():
		if child is Panel:
			child.add_theme_stylebox_override("panel", _make_panel_style())
			break
	_apply_scroll_offsets()
	if _list:
		_list.add_theme_constant_override("separation", VisualTheme.scaled_int(5, 2, 28))
	if _page_header:
		_apply_header_offsets()
		_page_header.add_theme_constant_override("separation", VisualTheme.scaled_int(6, 2, 28))
	for button in _page_buttons:
		VisualTheme.apply_button_size(button, Vector2(42, 34), 18, 24.0)
	if _add_page_button:
		VisualTheme.apply_button_size(_add_page_button, Vector2(42, 34), 24, 20.0)
	_refresh_page_header()
	if _placeholder:
		_detach_placeholder()
		_placeholder.queue_free()
	_placeholder = _make_placeholder()
	var active_index := _active_index
	rebuild()
	set_active_line(active_index)

func _make_panel_style() -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.html("#E7DFC5")
	bg.border_color = Color.html(VisualTheme.INK)
	bg.set_border_width_all(VisualTheme.scaled_int(4, 1, 24))
	bg.set_corner_radius_all(VisualTheme.scaled_int(VisualTheme.UI_PANEL_RADIUS, 6, 72))
	return bg

func _apply_scroll_offsets() -> void:
	if _scroll == null:
		return
	var inset := VisualTheme.scaled(8.0, 3.0, 36.0)
	_scroll.offset_right = -inset
	_scroll.offset_left = inset
	_scroll.offset_top = _header_height()
	_scroll.offset_bottom = -inset

func _apply_header_offsets() -> void:
	if _page_header == null:
		return
	_page_header.offset_left = VisualTheme.scaled(10.0, 4.0, 44.0)
	_page_header.offset_right = -VisualTheme.scaled(10.0, 4.0, 44.0)
	_page_header.offset_top = VisualTheme.scaled(8.0, 3.0, 36.0)
	_page_header.offset_bottom = _header_height() - VisualTheme.scaled(8.0, 3.0, 36.0)

func _line_number_width() -> float:
	return VisualTheme.scaled(LINE_NUMBER_WIDTH, 15.0, 288.0)

func _header_height() -> float:
	return VisualTheme.scaled(HEADER_HEIGHT, 22.0, 376.0)

func _target_box_size() -> Vector2:
	return VisualTheme.scaled_size(TARGET_BOX_SIZE, Vector2(40, 16), Vector2(680, 280))

func _connector_lane_gap() -> float:
	return VisualTheme.scaled(CONNECTOR_LANE_GAP, 3.0, 36.0)

## Bind the program model and (re)draw all rows.
func setup(p_program: Program, p_memory_size: int, p_active_page: int = 0, p_page_count: int = 1) -> void:
	program = p_program
	memory_size = p_memory_size
	_active_page = p_active_page
	_page_count = clampi(p_page_count, 1, MAX_PAGES)
	_refresh_page_header()
	rebuild()

## Recreate every row from the program model.
func rebuild() -> void:
	_detach_placeholder()
	for child in _list.get_children():
		child.queue_free()
	_blocks.clear()
	_hovered_block = null
	_target_boxes.clear()
	_candidate_block = null
	# Row indexes and blocks are about to be replaced, so any countdown still
	# pointing at the old ones has to go with them.
	_progress_index = -1
	_progress_id = -1
	_progress_fraction = 0.0

	var depth := 0
	var rows: Array[Control] = []
	for i in program.size():
		var inst := program.instructions[i]
		if inst.op == InstructionDef.Op.END_IF:
			depth = maxi(0, depth - 1)
		rows.append(_make_row(i, inst, depth))
		if inst.op == InstructionDef.Op.IF:
			depth += 1

	for target_index in program.size():
		for jump_index in program.size():
			var jump := program.instructions[jump_index]
			if not jump.is_jump():
				continue
			var resolved_target := program.index_of_id(jump.jump_target_id)
			if resolved_target == -1:
				resolved_target = jump_index
			if resolved_target != target_index:
				continue
			var box := _make_target_box(_blocks[jump_index])
			_target_boxes[jump.id] = box
			_list.add_child(_make_target_row(box))
		_list.add_child(rows[target_index])
	_bottom_pad = _make_bottom_pad()
	_list.add_child(_bottom_pad)
	for block in _blocks:
		if block.op == InstructionDef.Op.MOVE:
			_update_move_preview(block)
	_refresh_all_targets()
	_update_jump_underlay()
	queue_redraw()

## Empty spacer after the last row so the final instruction can be scrolled
## away from the panel edge, making it easier to hover, pick up and drop.
func _make_bottom_pad() -> Control:
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, VisualTheme.scaled(LIST_BOTTOM_PADDING, 36.0, 480.0))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_meta("bottom_pad", true)
	return pad

## Blank instruction-sized box showing where a jump lands. It takes the colour
## of the block that owns it, so the snake clock's landing box reads as violet
## like the clock rather than as one more blue jump. Every office jump shares
## the jump colour, so nothing changes there.
func _make_target_box(owner_block: InstructionBlock) -> JumpTargetBox:
	var box := JumpTargetBox.new(owner_block)
	var family := InstructionDef.color_for(owner_block.instruction.op)
	var style := StyleBoxFlat.new()
	style.bg_color = family
	style.border_color = family.darkened(0.25)
	style.set_border_width_all(VisualTheme.scaled_int(3, 1, 18))
	style.set_corner_radius_all(VisualTheme.scaled_int(2, 1, 18))
	box.add_theme_stylebox_override("normal", style)
	box.add_theme_stylebox_override("hover", VisualTheme.make_box_style(family.lightened(0.3).to_html(false), family.to_html(false), 2))
	box.add_theme_stylebox_override("pressed", style)
	box.custom_minimum_size = _target_box_size()
	return box

## Dummy targets occupy their own unnumbered row immediately before the
## instruction they point at, matching the original game's jump labels.
func _make_target_row(box: JumpTargetBox) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTheme.scaled_int(8, 3, 36))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.set_meta("jump_target_marker", true)

	var number_spacer := Control.new()
	number_spacer.custom_minimum_size = Vector2(_line_number_width(), 0)
	number_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(number_spacer)
	row.add_child(box)
	return row

## Build a single "NN  [block]" row.
func _make_row(index: int, inst: Instruction, depth: int = 0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTheme.scaled_int(8, 3, 36))
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var number := Label.new()
	number.text = "" if inst.op == InstructionDef.Op.END_IF else "%02d" % (index + 1)
	number.custom_minimum_size = Vector2(_line_number_width(), 0)
	number.add_theme_color_override("font_color", Color.html("#6B5E40"))
	VisualTheme.apply_font_size(number, 18, 6, 160)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(number)
	if depth > 0:
		var indent := Control.new()
		indent.custom_minimum_size.x = depth * VisualTheme.scaled(26, 14, 100)
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(indent)

	var block := InstructionBlock.new(inst.op, false, inst)
	block.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	block.set_memory_size(memory_size)
	if inst.op == InstructionDef.Op.MOVE:
		_update_move_preview(block)
	_update_wait_preview(block)
	block.request_target_pick.connect(_on_cycle_target)
	block.instruction_changed.connect(func() -> void: program_changed.emit())
	block.mouse_entered.connect(_on_block_mouse_entered.bind(block))
	block.mouse_exited.connect(_on_block_mouse_exited.bind(block))
	row.add_child(block)
	_blocks.append(block)
	return row

## Snake updates the value shown beside each MOVE's memory address.
func set_memory_snapshot(values: Array[int], key_flags: Array[bool], wait_scale_slot: int = -1) -> void:
	_wait_scale_slot = wait_scale_slot
	_memory_values_snapshot = values.duplicate()
	_memory_key_snapshot = key_flags.duplicate()
	for block in _blocks:
		if block.op == InstructionDef.Op.MOVE:
			_update_move_preview(block)
		_update_wait_preview(block)

func _update_wait_preview(block: InstructionBlock) -> void:
	if block.op != InstructionDef.Op.TICK:
		return
	var slot := _wait_scale_slot
	var value := _memory_values_snapshot[slot] if slot >= 0 and slot < _memory_values_snapshot.size() else StepAction.NULL_VALUE
	var is_key := _memory_key_snapshot[slot] if slot >= 0 and slot < _memory_key_snapshot.size() else false
	block.set_wait_preview(slot, value, is_key)

func _update_move_preview(block: InstructionBlock) -> void:
	var address := block.instruction.address
	var value := _memory_values_snapshot[address] if address >= 0 and address < _memory_values_snapshot.size() else StepAction.NULL_VALUE
	var is_key := _memory_key_snapshot[address] if address >= 0 and address < _memory_key_snapshot.size() else false
	block.set_memory_preview(value, is_key)

func _on_block_mouse_entered(block: InstructionBlock) -> void:
	_hovered_block = block

func _on_block_mouse_exited(block: InstructionBlock) -> void:
	if _hovered_block == block:
		_hovered_block = null

# --- Jump targets -------------------------------------------------------------

## Advance a jump's target to the next program line (wrapping). Used by clicking
## the arrow chip; dragging the arrow onto a line is handled in _drop_data.
func _on_cycle_target(block: InstructionBlock) -> void:
	if program.size() == 0:
		return
	var current := program.index_of_id(block.instruction.jump_target_id)
	var next := (current + 1) % program.size()
	block.instruction.jump_target_id = program.instructions[next].id
	_refresh_all_targets()
	queue_redraw()
	program_changed.emit()

## Update every jump chip to show its target's 1-based line number.
func _refresh_all_targets() -> void:
	for block in _blocks:
		if not block.has_target_chip():
			continue
		var idx := program.index_of_id(block.instruction.jump_target_id)
		block.set_target_label("→ ?" if idx == -1 else "→ %02d" % (idx + 1))

# --- Execution highlight ------------------------------------------------------

## Highlight the line the VM is about to run; pass -1 to clear.
## Fill the background of line `index` to `fraction` (0..1) while it waits.
## Pass -1 to clear. Only one line shows progress at a time.
func set_line_progress(index: int, fraction: float) -> void:
	if _progress_index != index and _progress_index >= 0 and _progress_index < _blocks.size():
		_blocks[_progress_index].set_progress(0.0)
	_progress_index = index
	var live := index >= 0 and index < _blocks.size()
	if live:
		_blocks[index].set_progress(fraction)
	# Mirror the same countdown onto this block's connector, so a wait reads as
	# "travelling back to line N" instead of as a program sitting still. Redraw
	# only when something actually moved: this runs once per frame per wait.
	var next_id: int = _blocks[index].instruction.id if live else -1
	var next_fraction := clampf(fraction, 0.0, 1.0) if live else 0.0
	if next_id != _progress_id or not is_equal_approx(next_fraction, _progress_fraction):
		_progress_id = next_id
		_progress_fraction = next_fraction
		_update_jump_underlay()

func set_active_line(index: int) -> void:
	if _active_index >= 0 and _active_index < _blocks.size():
		_blocks[_active_index].set_active(false)
	_active_index = index
	if index >= 0 and index < _blocks.size():
		_blocks[index].set_active(true)
		_ensure_visible(_blocks[index])

## Delete the instruction block currently under the pointer. Returns true only
## when a program line was removed, allowing the caller to consume the shortcut.
func delete_hovered_instruction() -> bool:
	if program == null or InstructionBlock.has_active_click_pickup() or get_viewport().gui_is_dragging():
		return false
	var block := _hovered_program_block()
	if block == null or block.op == InstructionDef.Op.END_IF:
		return false
	var index := program.index_of_id(block.instruction.id)
	if index == -1:
		return false
	set_active_line(-1)
	program.remove_at(index)
	rebuild()
	program_changed.emit()
	return true

## Resolve child controls such as address and jump-target buttons back to the
## program block they belong to, then fall back to the block hover signals.
func _hovered_program_block() -> InstructionBlock:
	var hovered: Node = get_viewport().gui_get_hovered_control()
	while hovered != null and not hovered is InstructionBlock:
		hovered = hovered.get_parent()
	if hovered is InstructionBlock and _blocks.has(hovered):
		return hovered as InstructionBlock
	if _hovered_block != null and is_instance_valid(_hovered_block):
		return _hovered_block
	return null

## Scroll so a block is within the viewport (follows execution).
func _ensure_visible(block: InstructionBlock) -> void:
	var top := block.global_position.y - _list.global_position.y
	var bottom := top + block.size.y
	if top < _scroll.scroll_vertical:
		_scroll.scroll_vertical = int(top)
	elif bottom > _scroll.scroll_vertical + _scroll.size.y:
		_scroll.scroll_vertical = int(bottom - _scroll.size.y)

# --- Drag session bookkeeping -------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			# Cache row centres from the clean layout so the landing slot index is
			# stable (inserting the slot must not move the thresholds = no jitter).
			_cache_row_centers()
			_drop_handled = false
		NOTIFICATION_DRAG_END:
			_end_drag_session()

## Called by a program block when it starts being dragged, so we can dim it and
## know which line to remove if it is dropped outside the list.
func _begin_reorder_drag(block: InstructionBlock) -> void:
	_dragging_block = block
	_drop_handled = false
	var row := block.get_parent() as Control
	if row:
		row.modulate.a = ROW_DIM_ALPHA

func begin_manual_drop_preview() -> void:
	_cache_row_centers()
	_drop_handled = false

## Called by a jump handle or blank target box when it starts being dragged.
func _begin_jump_drag(block: InstructionBlock, origin: Control = null) -> void:
	_jump_drag_source = block
	_jump_drag_origin = origin

## Ends a jump-target click-to-pickup session (see InstructionBlock's generic
## click-pickup path), clearing the rubber-band aim line _draw() renders
## while _jump_drag_source is set.
func cancel_jump_drag() -> void:
	_jump_drag_source = null
	_jump_drag_origin = null
	_clear_candidate()
	queue_redraw()

## Clean up after any drag: delete a line dropped outside, clear visuals.
func _end_drag_session() -> void:
	_hide_placeholder()
	_clear_candidate()
	var was_reorder := _dragging_block != null
	# A reorder that wasn't consumed by a drop on the list, and ended outside the
	# list, means the player flicked it away to delete it.
	if was_reorder and not _drop_handled and not _is_mouse_over_list():
		var idx := program.index_of_id(_dragging_block.instruction.id)
		if idx != -1:
			program.remove_at(idx)
			program_changed.emit()
	_dragging_block = null
	_jump_drag_source = null
	_jump_drag_origin = null
	if was_reorder:
		rebuild()  # restore dimming / reflect any deletion

# --- Drag and drop ------------------------------------------------------------

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return can_accept_at(global_position + at_position, data)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	drop_at(global_position + at_position, data)

## Public entry points so program blocks can forward drops with a global point.
## (Godot reports drop positions local to whichever control was hit, and the
## live mouse position is unreliable mid-drag, so we resolve everything from the
## event's own position.)
func can_accept_at(global_point: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has(InstructionBlock.DRAG_KIND)):
		return false
	match data[InstructionBlock.DRAG_KIND]:
		InstructionBlock.DRAG_PALETTE, InstructionBlock.DRAG_REORDER:
			_clear_candidate()
			_show_placeholder_at(_insert_index(global_point.y))
			return true
		InstructionBlock.DRAG_JUMP_TARGET:
			_hide_placeholder()
			_set_candidate(_block_at(global_point))
			return true
	return false

func drop_at(global_point: Vector2, data: Variant) -> void:
	match data[InstructionBlock.DRAG_KIND]:
		InstructionBlock.DRAG_PALETTE:
			var index := _insert_index(global_point.y)
			var inst := Instruction.new(data[InstructionBlock.DRAG_OP])
			program.insert_at(index, inst)
			if inst.op == InstructionDef.Op.IF:
				program.insert_at(index + 1, Instruction.new(InstructionDef.Op.END_IF))
		InstructionBlock.DRAG_REORDER:
			_apply_reorder(data[InstructionBlock.DRAG_BLOCK], global_point)
		InstructionBlock.DRAG_JUMP_TARGET:
			_apply_jump_target(data[InstructionBlock.DRAG_JUMP_BLOCK], global_point)
	_drop_handled = true
	_hide_placeholder()
	_clear_candidate()
	set_active_line(-1)
	rebuild()
	program_changed.emit()

func clear_drop_preview() -> void:
	_hide_placeholder()
	_clear_candidate()

## Move an existing line to the landing slot at the drop point.
func _apply_reorder(moved: InstructionBlock, global_point: Vector2) -> void:
	var from := program.index_of_id(moved.instruction.id)
	if from == -1:
		return
	var index := _insert_index(global_point.y)
	program.move_group(from, index)

## Point a jump's arrow at whatever line the drop landed on.
func _apply_jump_target(source: InstructionBlock, global_point: Vector2) -> void:
	var target := _block_at(global_point)
	if target == null or source == null:
		return
	source.instruction.jump_target_id = target.instruction.id

# --- Landing slot -------------------------------------------------------------

## Insert index implied by a global y, using the cached (pre-slot) row centres.
func _insert_index(global_y: float) -> int:
	for i in _row_centers.size():
		if global_y < _row_centers[i]:
			return i
	return _row_centers.size()

func _cache_row_centers() -> void:
	_row_centers.clear()
	for block in _blocks:
		_row_centers.append(block.get_global_rect().get_center().y)

## Show the empty landing slot before the row at `index`.
func _show_placeholder_at(index: int) -> void:
	# Re-attach at the end before resolving the child index so its previous
	# position cannot split a target marker from the instruction it labels.
	_detach_placeholder()
	_list.add_child(_placeholder)
	_list.move_child(_placeholder, _list_child_index_for_insert(index))
	_placeholder.visible = true

## Translate a program index to a VBox child index. Target-marker rows are
## attached to the instruction after them, so an insertion lands before both.
func _list_child_index_for_insert(index: int) -> int:
	if index >= _blocks.size():
		# The placeholder was just appended after the pad, so moving it to the
		# pad's index lands it between the last row and the padding.
		if _bottom_pad and _bottom_pad.get_parent() == _list:
			return _bottom_pad.get_index()
		return _list.get_child_count() - (1 if _placeholder.get_parent() == _list else 0)
	var child_index := _blocks[index].get_parent().get_index()
	while child_index > 0 and _list.get_child(child_index - 1).has_meta("jump_target_marker"):
		child_index -= 1
	return child_index

func _hide_placeholder() -> void:
	_placeholder.visible = false
	_detach_placeholder()

func _detach_placeholder() -> void:
	if _placeholder.get_parent() != null:
		_placeholder.get_parent().remove_child(_placeholder)

# --- Jump-target candidate highlight -----------------------------------------

func _set_candidate(block: InstructionBlock) -> void:
	if block == _candidate_block:
		return
	_clear_candidate()
	_candidate_block = block
	if block:
		block.set_candidate(true)

func _clear_candidate() -> void:
	if _candidate_block and is_instance_valid(_candidate_block):
		_candidate_block.set_candidate(false)
	_candidate_block = null

## The program block whose row contains a global point, or null. Matches on the
## full row height (not just the block) so the whole line is an easy target.
func _block_at(global_point: Vector2) -> InstructionBlock:
	for block in _blocks:
		var rect := block.get_global_rect()
		if global_point.y >= rect.position.y and global_point.y <= rect.position.y + rect.size.y:
			return block
	return null

func _is_mouse_over_list() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())

# --- Jump arrows --------------------------------------------------------------

func _process(_delta: float) -> void:
	# Block positions shift with layout/scroll; keep connectors in sync cheaply.
	# Also retract drag visuals when the cursor leaves the list mid-drag.
	if get_viewport().gui_is_dragging() and not _is_mouse_over_list():
		_hide_placeholder()
		_clear_candidate()
	_update_hovered_jump()
	_update_jump_underlay()
	if _jump_drag_source:
		queue_redraw()

func _draw() -> void:
	# While dragging a jump's arrow, rubber-band a line from it to the cursor.
	if _jump_drag_source and is_instance_valid(_jump_drag_source):
		var r := _local_control_rect(_jump_drag_origin) if is_instance_valid(_jump_drag_origin) else _local_rect(_jump_drag_source)
		var start := r.get_center()
		var end := get_local_mouse_position()
		draw_line(start, end, Color.html("#3FA0FF"), 3.0, true)
		_draw_arrowhead(end, (end - start).normalized(), Color.html("#3FA0FF"))

func _update_jump_underlay() -> void:
	if program == null or _jump_underlay == null:
		return
	_jump_underlay.queue_redraw()

## Draw straight orthogonal connectors as a secondary cue between each jump and
## its dummy target box. The target box itself remains the primary destination.
## Vertical runs are packed into lanes so no two connectors share a line, and
## the hovered jump's connector is drawn last, brighter and thicker.
func _draw_jump_underlay() -> void:
	if program == null:
		return
	_draw_if_braces()
	var connectors := _build_connectors()
	var hovered: Dictionary = {}
	for connector: Dictionary in connectors:
		if connector["id"] == _hovered_jump_id:
			hovered = connector
			continue
		_draw_connector(connector, false)
	if not hovered.is_empty():
		_draw_connector(hovered, true)
	_draw_wait_progress(connectors)

## Paint the counting-down clock's connector over the top of the plain one, up
## to however much of the wait has elapsed. The moving tip keeps the arrowhead,
## so the loop back to the target line is something the player watches happen.
func _draw_wait_progress(connectors: Array[Dictionary]) -> void:
	if _progress_id == -1 or _progress_fraction <= 0.0:
		return
	for connector: Dictionary in connectors:
		if connector["id"] != _progress_id:
			continue
		var points := _polyline_prefix(connector["points"], _progress_fraction)
		if points.size() < 2:
			return
		var width := VisualTheme.scaled(CONNECTOR_HOVER_WIDTH, 2.0, 24.0)
		var color := Color.html(CONNECTOR_PROGRESS_COLOR)
		_jump_underlay.draw_polyline(points, color, width, true)
		_draw_underlay_arrowhead(points[-1], (points[-1] - points[-2]).normalized(), color)
		return

## The leading `fraction` of a polyline, measured along its real length so the
## tip travels at a constant speed through the corners.
static func _polyline_prefix(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	if points.size() < 2:
		return PackedVector2Array()
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	if total <= 0.0:
		return PackedVector2Array()
	var wanted := total * clampf(fraction, 0.0, 1.0)
	var walked := 0.0
	var prefix := PackedVector2Array([points[0]])
	for i in points.size() - 1:
		var segment := points[i].distance_to(points[i + 1])
		if walked + segment >= wanted:
			var along := 0.0 if segment <= 0.0 else (wanted - walked) / segment
			prefix.append(points[i].lerp(points[i + 1], along))
			return prefix
		walked += segment
		prefix.append(points[i + 1])
	return prefix

## Geometry for every visible jump connector: {id, points}. Lanes are assigned
## shortest-span-first so nested jumps sit inside, outer jumps sit outside.
func _build_connectors() -> Array[Dictionary]:
	var connectors: Array[Dictionary] = []
	var max_right := 0.0
	for block in _blocks:
		max_right = maxf(max_right, _local_rect(block).end.x)
	for block in _blocks:
		var inst := block.instruction
		if not inst.is_jump() or not _target_boxes.has(inst.id):
			continue
		var source_rect := _local_rect(block)
		var target_box: JumpTargetBox = _target_boxes[inst.id]
		var target_rect := _local_control_rect(target_box)
		max_right = maxf(max_right, target_rect.end.x)
		var start := Vector2(source_rect.end.x, source_rect.get_center().y)
		var end := Vector2(target_rect.end.x, target_rect.get_center().y)
		connectors.append({"id": inst.id, "start": start, "end": end})
	# Shortest vertical spans first so they claim the inner lanes.
	connectors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absf(a["end"].y - a["start"].y) < absf(b["end"].y - b["start"].y))
	var lane_spans: Array[Array] = []  ## lane -> list of [min_y, max_y]
	var margin := _connector_lane_gap() * 0.5
	for connector in connectors:
		var lo := minf(connector["start"].y, connector["end"].y) - margin
		var hi := maxf(connector["start"].y, connector["end"].y) + margin
		var lane := 0
		while lane < lane_spans.size() and _lane_overlaps(lane_spans[lane], lo, hi):
			lane += 1
		if lane == lane_spans.size():
			lane_spans.append([])
		lane_spans[lane].append([lo, hi])
		connector["lane"] = lane
	# Pack lanes to the right of the widest row; fall back inward if the panel
	# is too narrow to fit them all outside the blocks.
	var lane_gap := _connector_lane_gap()
	var right_limit := size.x - VisualTheme.scaled(14.0, 5.0, 56.0)
	var base_x := minf(
		max_right + VisualTheme.scaled(24.0, 10.0, 96.0),
		right_limit - maxf(0.0, float(lane_spans.size() - 1)) * lane_gap
	)
	for connector in connectors:
		var lane_x: float = base_x + connector["lane"] * lane_gap
		connector["points"] = PackedVector2Array([
			connector["start"],
			Vector2(lane_x, connector["start"].y),
			Vector2(lane_x, connector["end"].y),
			connector["end"],
		])
	return connectors

func _lane_overlaps(spans: Array, lo: float, hi: float) -> bool:
	for span: Array in spans:
		if lo <= span[1] and hi >= span[0]:
			return true
	return false

## Stroke one connector: a pale halo underneath for contrast, then the line.
func _draw_connector(connector: Dictionary, highlighted: bool) -> void:
	var points: PackedVector2Array = connector["points"]
	var width := VisualTheme.scaled(CONNECTOR_HOVER_WIDTH if highlighted else CONNECTOR_WIDTH, 2.0, 24.0)
	var color := Color.html(CONNECTOR_HOVER_COLOR if highlighted else CONNECTOR_COLOR)
	var halo_width := width + VisualTheme.scaled(CONNECTOR_HALO_EXTRA, 2.0, 16.0)
	_jump_underlay.draw_polyline(points, CONNECTOR_HALO_COLOR, halo_width, true)
	_jump_underlay.draw_polyline(points, color, width, true)
	var dir := (points[-1] - points[-2]).normalized()
	_draw_underlay_arrowhead(points[-1], dir, color, halo_width * 0.5)

## Decide which jump's connector should be highlighted: the cursor is over the
## jump block, over its target box, or close to the connector line itself.
func _update_hovered_jump() -> void:
	var next_id := -1
	if not get_viewport().gui_is_dragging():
		next_id = _jump_id_under_cursor()
	if next_id != _hovered_jump_id:
		_hovered_jump_id = next_id
		_update_jump_underlay()

func _jump_id_under_cursor() -> int:
	var hovered: Node = get_viewport().gui_get_hovered_control()
	while hovered != null and not (hovered is InstructionBlock or hovered is JumpTargetBox):
		hovered = hovered.get_parent()
	if hovered is JumpTargetBox:
		return (hovered as JumpTargetBox).owner_block.instruction.id
	if hovered is InstructionBlock and _blocks.has(hovered):
		var inst := (hovered as InstructionBlock).instruction
		if inst.is_jump():
			return inst.id
	if not _is_mouse_over_list():
		return -1
	var mouse := get_local_mouse_position()
	var threshold := VisualTheme.scaled(CONNECTOR_HOVER_DISTANCE, 4.0, 32.0)
	var best_id := -1
	var best_distance := threshold
	for connector in _build_connectors():
		var points: PackedVector2Array = connector["points"]
		for i in points.size() - 1:
			var d := mouse.distance_to(Geometry2D.get_closest_point_to_segment(mouse, points[i], points[i + 1]))
			if d < best_distance:
				best_distance = d
				best_id = connector["id"]
	return best_id

## Small triangle pointing in `dir` at the arrow's landing point.
func _draw_arrowhead(tip: Vector2, dir: Vector2, color: Color) -> void:
	if dir == Vector2.ZERO:
		return
	var perp := Vector2(-dir.y, dir.x)
	var a := tip
	var b := tip - dir * 10 + perp * 6
	var c := tip - dir * 10 - perp * 6
	draw_colored_polygon(PackedVector2Array([a, b, c]), color)

func _draw_underlay_arrowhead(tip: Vector2, dir: Vector2, color: Color, halo: float = 0.0) -> void:
	if dir == Vector2.ZERO:
		return
	var perp := Vector2(-dir.y, dir.x)
	var length := VisualTheme.scaled(12.0, 6.0, 48.0)
	var half := VisualTheme.scaled(7.0, 3.0, 28.0)
	if halo > 0.0:
		var ha := tip + dir * halo
		var hb := tip - dir * (length + halo) + perp * (half + halo)
		var hc := tip - dir * (length + halo) - perp * (half + halo)
		_jump_underlay.draw_colored_polygon(PackedVector2Array([ha, hb, hc]), CONNECTOR_HALO_COLOR)
	var a := tip
	var b := tip - dir * length + perp * half
	var c := tip - dir * length - perp * half
	_jump_underlay.draw_colored_polygon(PackedVector2Array([a, b, c]), color)

## A block's rectangle expressed in this control's local coordinates.
func _local_rect(block: InstructionBlock) -> Rect2:
	var r := block.get_global_rect()
	r.position -= global_position
	return r

func _local_control_rect(control: Control) -> Rect2:
	var r := control.get_global_rect()
	r.position -= global_position
	return r

## One closed C-shaped contour: header, spine and bottom lip share a fill
## and a single outline, with no overlapping panel borders at their joins.
## Its bounds are measured from the laid-out rows, including the drop preview.
func _if_outline(index: int) -> PackedVector2Array:
	var closing := program.matching_end_if(index)
	if closing < 0 or closing >= _blocks.size():
		return PackedVector2Array()
	var header := _local_rect(_blocks[index])
	var footer := _local_rect(_blocks[closing])
	var left := header.position.x
	var right := header.end.x
	var padding := VisualTheme.scaled(12, 6, 48)
	for i in range(index + 1, closing):
		right = maxf(right, _local_rect(_blocks[i]).end.x + padding)
	var inner := left + VisualTheme.scaled(16, 8, 64)
	return PackedVector2Array([
		Vector2(left, header.position.y),
		Vector2(right, header.position.y),
		Vector2(right, header.end.y),
		Vector2(inner, header.end.y),
		Vector2(inner, footer.position.y),
		Vector2(right, footer.position.y),
		Vector2(right, footer.end.y),
		Vector2(left, footer.end.y),
	])

func _draw_if_braces() -> void:
	var clip_rect := _scroll.get_global_rect()
	clip_rect.position -= global_position
	var clip_polygon := PackedVector2Array([
		clip_rect.position, Vector2(clip_rect.end.x, clip_rect.position.y),
		clip_rect.end, Vector2(clip_rect.position.x, clip_rect.end.y),
	])
	for i in _blocks.size():
		var block := _blocks[i]
		if block.op != InstructionDef.Op.IF:
			continue
		var points := _if_outline(i)
		if points.is_empty():
			continue
		var base := InstructionDef.color_for(InstructionDef.Op.IF)
		var fill := base
		var border := base.darkened(0.25)
		var width := VisualTheme.scaled(3, 1, 18)
		if block._candidate:
			fill = base.lightened(0.2)
			border = Color.html("#3FA0FF")
			width = VisualTheme.scaled(4, 1, 24)
		elif block._active:
			fill = base.lightened(0.25)
			border = Color.html("#FFE680")
			width = VisualTheme.scaled(4, 1, 24)
		var alpha := (block.get_parent() as Control).modulate.a
		fill.a *= alpha
		border.a *= alpha
		for visible_shape in Geometry2D.intersect_polygons(points, clip_polygon):
			_jump_underlay.draw_colored_polygon(visible_shape, fill)
			var outline := visible_shape.duplicate()
			outline.append(outline[0])
			_jump_underlay.draw_polyline(outline, border, width, true)
