class_name InstructionBlock
extends PanelContainer

## A coloured instruction chip. Used in two modes:
##  * palette mode  — a source you drag into the program (no operands shown).
##  * program mode  — a line in the program; draggable to reorder, with an
##    editable operand (memory tile) or jump-target chip.
##
## Drag-and-drop uses Godot's built-in Control drag system. The drop target
## (ProgramListView) reads the dictionary returned by `_get_drag_data`.

signal request_target_pick(block: InstructionBlock)
signal instruction_changed()

## Payload keys used to describe a drag in flight.
const DRAG_KIND := "kind"
const DRAG_PALETTE := "palette"
const DRAG_REORDER := "reorder"
const DRAG_JUMP_TARGET := "jumptarget"
const DRAG_OP := "op"
const DRAG_BLOCK := "block"
const DRAG_JUMP_BLOCK := "jump_block"

## Distance (in a block's local pixels) the pointer may travel between press and
## release and still count as a "click" that starts a pickup. Keeps trackpad
## jitter during a physical click from being read as a drag attempt.
const CLICK_MOVE_TOLERANCE := 12.0
## A drop press arriving within this window of the pickup starting is ignored.
## Windows precision trackpads can emit a bouncy double-press on a single tap;
## without this, the second press would instantly drop what was just picked up,
## so a pickup silently cancels and appears never to have happened.
const DROP_DEBOUNCE_MS := 150

var op: InstructionDef.Op
var is_palette: bool
## The model object this block represents (null for palette blocks).
var instruction: Instruction = null
static var click_to_pickup_enabled: bool = false
static var custom_cursor_enabled: bool = false
## Accessibility multiplier on instruction text size. The block is a
## PanelContainer with fixed margins, so a larger font grows the block to fit
## while its padding stays constant. Set from HCMSettings before blocks build.
static var font_scale: float = 1.0
## The family glyph is drawn a little larger than the command word, sized as a
## multiple of the word's font size so the two always scale together.
const GLYPH_FONT_SCALE := 1.3
## Whether the mouse is currently over a spot that would accept the drop in
## flight, kept up to date every frame by both drag paths so the cursor can
## swap between the grab and grab-err art.
static var _drag_target_valid: bool = true
static var _click_drag_data: Dictionary = {}
static var _click_drag_preview: Control = null
static var _click_drag_source: InstructionBlock = null
## Set only for a jump-target pickup, so its rubber-band aim line can be
## cleared from the list it started on once the pickup ends.
static var _jump_pickup_list: ProgramListView = null
## Wall-clock time (ms) the current pickup began, used to debounce an
## immediate drop press (see DROP_DEBOUNCE_MS).
static var _click_pickup_started_ms: int = 0

var _memory_size: int = 0
var _operand_button: Button = null
var _target_button: JumpTargetHandle = null
var _label: Label = null
## Visual flags combined by _apply_style: execution highlight and drop-candidate.
var _active: bool = false
var _candidate: bool = false
## Left-press bookkeeping so a pickup starts on a clean click (press then
## release without travelling), not on the raw press. Starting on release keeps
## Godot's native drag-detection — armed on press because _get_drag_data is
## overridden — from stealing the gesture when a trackpad jitters mid-click.
var _pickup_press_active: bool = false
var _pickup_press_pos: Vector2 = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_target_valid = true
		_set_instruction_drag_cursor(false)

func _init(p_op: InstructionDef.Op, p_is_palette: bool, p_instruction: Instruction = null) -> void:
	op = p_op
	is_palette = p_is_palette
	instruction = p_instruction
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	_apply_style()
	custom_minimum_size = VisualTheme.scaled_size(Vector2(150, 0), Vector2(80, 0), Vector2(900, 0))
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Native hover tooltip explaining the command. The Viewport walks up from the
	# hovered child (label / chip) to this block for the text, so one assignment
	# covers the whole block.
	tooltip_text = InstructionDef.tooltip_for(op)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTheme.scaled_int(6, 2, 28))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(10, 4, 48))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, VisualTheme.scaled_int(6, 2, 32))
	margin.add_child(row)
	add_child(margin)

	_label = _add_command_label(row, 17, Color.html("#FBF7EE"))

	if not is_palette:
		_build_operand(row)

## Add the family glyph and command word to `row` as two labels — the glyph a
## little larger and sized relative to the word — respecting outbox's trailing
## glyph. Returns the word label, kept as _label for the block.
func _add_command_label(row: HBoxContainer, word_font_size: int, color: Color) -> Label:
	var glyph_size := int(roundf(float(word_font_size) * GLYPH_FONT_SCALE))
	var glyph := _make_command_part(InstructionDef.glyph_for(op), glyph_size, color)
	var word := _make_command_part(InstructionDef.word_for(op), word_font_size, color)
	if InstructionDef.glyph_leads(op):
		row.add_child(glyph)
		row.add_child(word)
	else:
		row.add_child(word)
		row.add_child(glyph)
	return word

## One text part (glyph or word) of a command label, vertically centred so the
## larger glyph and the word line up on their middle.
func _make_command_part(text: String, base_font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_color_override("font_color", color)
	VisualTheme.apply_ui_font(lbl)
	VisualTheme.apply_font_size_mult(lbl, base_font_size, font_scale, 6, 320)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

## Build the operand affordance appropriate to this opcode.
func _build_operand(row: HBoxContainer) -> void:
	var kind := InstructionDef.operand_kind_for(op)
	if kind == InstructionDef.OperandKind.ADDRESS:
		_operand_button = _make_chip(str(instruction.address))
		_operand_button.pressed.connect(_on_cycle_address)
		row.add_child(_operand_button)
	elif kind == InstructionDef.OperandKind.JUMP:
		# A draggable arrow handle: click cycles the target, drag wires it
		# directly — except in click-to-pickup mode, where a click instead
		# starts a pickup (see JumpTargetHandle), so cycling is skipped there.
		_target_button = JumpTargetHandle.new(self)
		_target_button.pressed.connect(func() -> void:
			if not click_to_pickup_enabled:
				request_target_pick.emit(self))
		row.add_child(_target_button)

## A small light chip-button used for operands and jump targets.
func _make_chip(text: String) -> Button:
	var b := Button.new()
	b.text = text
	var style := VisualTheme.make_box_style("#F3ECD8", "#B9AE8C")
	style.shadow_size = 0
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)
	VisualTheme.apply_ui_font(b)
	VisualTheme.set_button_font_color(b, Color.html("#3A3526"))
	VisualTheme.apply_button_size_mult(b, Vector2(34, 28), 18, font_scale, 20.0)
	return b

## Cycle the memory tile this instruction refers to.
func _on_cycle_address() -> void:
	if _memory_size <= 0:
		return
	instruction.address = (instruction.address + 1) % _memory_size
	_operand_button.text = str(instruction.address)
	instruction_changed.emit()

## Tell address chips how many tiles exist so cycling stays in range.
func set_memory_size(count: int) -> void:
	_memory_size = count

## Set the jump target chip text; the list computes the human-readable target
## (e.g. "→ 17") since only it knows every line's current position.
func set_target_label(text: String) -> void:
	if _target_button:
		_target_button.text = text
		_target_button.apply_ui_scale()

## True when this block carries a jump-target chip.
func has_target_chip() -> bool:
	return _target_button != null

## Highlight this line while the VM is executing it.
func set_active(active: bool) -> void:
	_active = active
	_apply_style()

## Highlight this line as the line a dragged jump arrow would land on.
func set_candidate(candidate: bool) -> void:
	_candidate = candidate
	_apply_style()

## Repaint the block's frame from its current highlight flags.
func _apply_style() -> void:
	var base := InstructionDef.color_for(op)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(VisualTheme.scaled_int(2, 1, 18))
	if _candidate:
		style.bg_color = base.lightened(0.2)
		style.border_color = Color.html("#3FA0FF")
		style.set_border_width_all(VisualTheme.scaled_int(4, 1, 24))
	elif _active:
		style.bg_color = base.lightened(0.25)
		style.border_color = Color.html("#FFE680")
		style.set_border_width_all(VisualTheme.scaled_int(4, 1, 24))
	else:
		style.bg_color = base
		style.border_color = base.darkened(0.25)
		style.set_border_width_all(VisualTheme.scaled_int(3, 1, 18))
	add_theme_stylebox_override("panel", style)

# --- Drag and drop ------------------------------------------------------------

func _get_drag_data(_pos: Vector2) -> Variant:
	# When click-to-pickup is on, holding and moving the mouse must not also
	# start a native drag — that would race the click-to-pickup preview
	# (started from _gui_input below) and let a plain click-drag-release
	# reorder the line natively while the click-to-pickup preview is left
	# stuck on screen. Click-to-pickup is the only path in that mode.
	if click_to_pickup_enabled:
		return null
	var data := _make_drag_payload()
	set_drag_preview(_make_preview())
	_set_instruction_drag_cursor(true)
	return data

## Start a pickup on a clean click — press, then release without travelling —
## rather than on the raw press. This dodges Godot's native drag-detection,
## which arms on press (because _get_drag_data is overridden) and, on Windows
## precision trackpads, swallows the press whenever the physical click jitters
## past the drag threshold. Waiting for the release means the pickup keys off a
## gesture the drag system has already declined to claim.
func _gui_input(event: InputEvent) -> void:
	if not click_to_pickup_enabled:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_pickup_press_active = true
			_pickup_press_pos = button.position
			accept_event()
		elif _pickup_press_active:
			_pickup_press_active = false
			# Only a click that stayed put counts; a travelled press was the
			# user trying to drag (or trackpad jitter), not a pickup.
			if button.position.distance_to(_pickup_press_pos) <= CLICK_MOVE_TOLERANCE:
				_start_click_pickup()
			accept_event()

func _make_drag_payload() -> Dictionary:
	var data := {}
	if is_palette:
		data[DRAG_KIND] = DRAG_PALETTE
		data[DRAG_OP] = op
	else:
		data[DRAG_KIND] = DRAG_REORDER
		data[DRAG_BLOCK] = self
		# Let the list dim this line and watch for a drop-outside-to-delete.
		var list := _find_program_list()
		if list:
			list._begin_reorder_drag(self)
	return data

## Godot only offers a drop to the top-most control under the cursor and does
## not bubble up. Since program blocks sit on top of the list, they must forward
## drops to the ProgramListView so that dropping *onto a block* still reorders.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var list := _find_program_list()
	return list != null and list.can_accept_at(global_position + at_position, data)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var list := _find_program_list()
	if list:
		list.drop_at(global_position + at_position, data)

## Climb the tree to the owning ProgramListView (null for palette blocks).
func _find_program_list() -> ProgramListView:
	var node: Node = get_parent()
	while node != null:
		if node is ProgramListView:
			return node
		node = node.get_parent()
	return null

## A lightweight floating copy shown under the cursor while dragging.
func _make_preview() -> Control:
	var preview := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = InstructionDef.color_for(op)
	style.set_corner_radius_all(7)
	preview.add_theme_stylebox_override("panel", style)
	preview.modulate.a = 0.85
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", VisualTheme.scaled_int(6, 2, 28))
	_add_command_label(row, 20, Color.html("#FBF7EE"))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", VisualTheme.scaled_int(10, 4, 48))
	m.add_theme_constant_override("margin_right", VisualTheme.scaled_int(10, 4, 48))
	m.add_theme_constant_override("margin_top", VisualTheme.scaled_int(6, 2, 32))
	m.add_theme_constant_override("margin_bottom", VisualTheme.scaled_int(6, 2, 32))
	m.add_child(row)
	preview.add_child(m)
	return preview

func _start_click_pickup() -> void:
	InstructionBlock.start_generic_click_pickup(_make_drag_payload(), _make_preview(), self, self)

## Starts a click-to-pickup session for any draggable payload recognised by
## ProgramListView.can_accept_at/drop_at — used by InstructionBlock itself
## (palette/reorder) and by JumpTargetBox (wiring a jump target), so every
## draggable in the program editor behaves the same way once click-to-pickup
## is enabled instead of only some of them falling back to a held drag.
## `reorder_source` is only needed for DRAG_REORDER payloads, so a dropped
## reorder can be deleted if it lands outside every list; `jump_pickup_list`
## is only needed for DRAG_JUMP_TARGET payloads, so the list's rubber-band
## aim line gets cleared once the pickup ends.
static func start_generic_click_pickup(data: Dictionary, preview: Control, tree_node: Node, reorder_source: InstructionBlock = null, jump_pickup_list: ProgramListView = null) -> void:
	if _click_drag_preview != null:
		return
	var root := tree_node.get_tree().current_scene if tree_node.get_tree().current_scene != null else tree_node.get_tree().root
	_click_drag_source = reorder_source
	_jump_pickup_list = jump_pickup_list
	_click_drag_data = data
	_click_pickup_started_ms = Time.get_ticks_msec()
	_prepare_click_pickup_lists(root)
	_click_drag_preview = preview
	_click_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_click_drag_preview.modulate.a = 0.92
	tree_node.get_tree().root.add_child(_click_drag_preview)
	update_click_pickup(tree_node.get_viewport().get_mouse_position(), root)
	_set_instruction_drag_cursor(true)

static func configure_custom_cursor(enabled: bool) -> void:
	custom_cursor_enabled = enabled
	if _click_drag_preview == null:
		_set_instruction_drag_cursor(false)

static func has_active_click_pickup() -> bool:
	return _click_drag_preview != null

static func update_click_pickup(mouse_position: Vector2, root: Node) -> void:
	if _click_drag_preview == null or not is_instance_valid(_click_drag_preview):
		return
	_click_drag_preview.global_position = mouse_position + Vector2(10, 10)
	_preview_click_drop_at(mouse_position, root)

## Called every frame a native (Control _get_drag_data) drag is in flight, so
## the grab/grab-err cursor swap tracks the mouse the same way it does for
## click-to-pickup. Godot's built-in CURSOR_DRAG/CURSOR_CAN_DROP auto-switch
## isn't reliable enough here (it doesn't consistently reflect `can_accept_at`
## once a block is dragged over its own source list), so validity is instead
## computed explicitly, exactly like the click-pickup path.
static func update_native_drag_cursor(mouse_position: Vector2, root: Node) -> void:
	if not custom_cursor_enabled:
		return
	var drag_data: Variant = root.get_viewport().gui_get_drag_data()
	_update_drag_validity(_drag_target_at(mouse_position, root, drag_data))

## True if dropping `drag_data` at `global_point` would land inside a
## ProgramListView that accepts it — i.e. inside the instruction-code-area.
static func _drag_target_at(global_point: Vector2, root: Node, drag_data: Variant) -> bool:
	var lists: Array[ProgramListView] = []
	_collect_program_lists(root, lists)
	for list in lists:
		if list.get_global_rect().has_point(global_point):
			return list.can_accept_at(global_point, drag_data)
	return false

static func _update_drag_validity(valid: bool) -> void:
	if valid != _drag_target_valid:
		_drag_target_valid = valid
		_set_instruction_drag_cursor(true)

static func finish_click_pickup(global_point: Vector2, root: Node) -> bool:
	if _click_drag_preview == null:
		return false
	# Swallow a drop press that lands right on the heels of the pickup. A single
	# trackpad tap can register as two quick presses on Windows; without this the
	# second one would drop the item instantly, so it looks like the pickup never
	# took. The press is still consumed (true) so nothing else acts on it.
	if Time.get_ticks_msec() - _click_pickup_started_ms < DROP_DEBOUNCE_MS:
		return true

	var dropped := _drop_click_pickup(global_point, root)
	if not dropped:
		_delete_click_pickup_if_reorder()
	_end_click_pickup()
	return true

static func _drop_click_pickup(global_point: Vector2, root: Node) -> bool:
	var lists: Array[ProgramListView] = []
	_collect_program_lists(root, lists)
	for list in lists:
		if not list.get_global_rect().has_point(global_point):
			continue
		if list.can_accept_at(global_point, _click_drag_data):
			list.drop_at(global_point, _click_drag_data)
			return true
	return false

static func _preview_click_drop_at(global_point: Vector2, root: Node) -> void:
	var lists: Array[ProgramListView] = []
	_collect_program_lists(root, lists)
	var active_list: ProgramListView = null
	for list in lists:
		if active_list == null and list.get_global_rect().has_point(global_point):
			active_list = list
		else:
			list.clear_drop_preview()
	var valid := active_list != null and active_list.can_accept_at(global_point, _click_drag_data)
	_update_drag_validity(valid)

static func _prepare_click_pickup_lists(root: Node) -> void:
	var lists: Array[ProgramListView] = []
	_collect_program_lists(root, lists)
	for list in lists:
		list.begin_manual_drop_preview()

static func _collect_program_lists(node: Node, out: Array[ProgramListView]) -> void:
	if node is ProgramListView:
		out.append(node)
	for child in node.get_children():
		_collect_program_lists(child, out)

static func _delete_click_pickup_if_reorder() -> void:
	if _click_drag_data.get(DRAG_KIND, "") != DRAG_REORDER:
		return
	if _click_drag_source == null or not is_instance_valid(_click_drag_source):
		return
	var list := _click_drag_source._find_program_list()
	if list == null:
		return
	var idx := list.program.index_of_id(_click_drag_source.instruction.id)
	if idx != -1:
		list.program.remove_at(idx)
		list.program_changed.emit()
		list.rebuild()

static func _end_click_pickup() -> void:
	if _click_drag_preview != null and is_instance_valid(_click_drag_preview):
		_click_drag_preview.queue_free()
	_click_drag_preview = null
	_click_drag_data = {}
	_click_drag_source = null
	if _jump_pickup_list != null and is_instance_valid(_jump_pickup_list):
		_jump_pickup_list.cancel_jump_drag()
	_jump_pickup_list = null
	_drag_target_valid = true
	_set_instruction_drag_cursor(false)

## Swaps in the grab (or grab-err, once over an invalid drop spot) art while
## a block is being dragged, and the plain pointer otherwise. The grab/grab-err
## split is driven entirely by `_drag_target_valid` (kept up to date by
## `update_native_drag_cursor` and `_preview_click_drop_at`) rather than by
## which cursor shape Godot happens to pick during the drag.
static func _set_instruction_drag_cursor(active: bool) -> void:
	if not custom_cursor_enabled:
		return
	if active:
		var state := SoftwareCursor.State.GRAB if _drag_target_valid else SoftwareCursor.State.GRAB_ERR
		SoftwareCursor.set_state(state)
	else:
		SoftwareCursor.set_state(SoftwareCursor.State.POINTER)
