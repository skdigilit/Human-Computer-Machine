class_name WaitBar
extends Control

## Countdown strip shown under the Snake board while a `wait` block is
## pausing the program. It fills from empty to full on its own clock, then
## hides. This makes the pause visible — without it the program just looks
## stuck between moves. The icon on the left is the same timer glyph as the
## wait block so the two read as one thing.
##
## It is also the clock the arena awaits: `finished` fires when the wait is
## spent or a reset clears it, and `progress` every frame so the wait block in the
## program list can fill in step with this strip.

## Elapsed fraction of the wait, 0.0 → 1.0, once per frame while waiting.
signal progress(elapsed_fraction: float)
## The wait ran out or was cleared by a reset.
signal finished()

const BAR_HEIGHT := 10.0
const ICON_SIZE := 22.0
const ICON_GAP := 8.0
const TRACK_ALPHA := 0.18
const CORNER_RADIUS := 4.0

var _total_seconds: float = 0.0
var _elapsed_seconds: float = 0.0
var _paused: bool = false
## Slow short waits for manual stepping without changing their stored duration.
var minimum_animation_seconds: float = 0.0
var _icon: Texture2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = SFSymbols.texture("timer", Color.html(InstructionDef.COLOR_TICK))
	set_process(false)
	visible = false

## Begin filling from empty over `seconds`. A zero wait finishes immediately.
func start(seconds: float) -> void:
	if seconds <= 0.0:
		finish_now()
		return
	_total_seconds = seconds
	_elapsed_seconds = 0.0
	_paused = false
	visible = true
	set_process(true)
	progress.emit(0.0)
	queue_redraw()

## True while a wait is being counted down.
func is_waiting() -> bool:
	return _total_seconds > 0.0

func set_paused(paused: bool) -> void:
	_paused = paused

## Complete the countdown or cancel it for a reset. Fires `finished` so
## whoever is awaiting the wait carries on.
func finish_now() -> void:
	var was_waiting := is_waiting()
	_total_seconds = 0.0
	_elapsed_seconds = 0.0
	_paused = false
	visible = false
	set_process(false)
	if was_waiting:
		progress.emit(1.0)
	finished.emit()

## Hide the bar without waking an awaiting caller (level setup, no wait running).
func clear() -> void:
	if is_waiting():
		finish_now()
		return
	visible = false
	set_process(false)

## Fraction of the wait already spent, 0.0 = just started.
func elapsed_fraction() -> float:
	if _total_seconds <= 0.0:
		return 0.0
	return clampf(_elapsed_seconds / _total_seconds, 0.0, 1.0)

## Height the arena should reserve for the bar row, in scaled pixels.
static func row_height() -> float:
	return VisualTheme.scaled(ICON_SIZE, 12.0, 64.0)

func _process(delta: float) -> void:
	if _paused:
		return
	var playback_scale := _total_seconds / maxf(_total_seconds, minimum_animation_seconds)
	_elapsed_seconds += delta * playback_scale
	if _elapsed_seconds >= _total_seconds:
		finish_now()
		return
	progress.emit(elapsed_fraction())
	queue_redraw()

func _draw() -> void:
	var icon_edge := row_height()
	var gap := VisualTheme.scaled(ICON_GAP, 3.0, 24.0)
	var bar_height := VisualTheme.scaled(BAR_HEIGHT, 4.0, 32.0)
	var radius := VisualTheme.scaled(CORNER_RADIUS, 1.0, 12.0)
	var color := Color.html(InstructionDef.COLOR_TICK)

	if _icon:
		draw_texture_rect(_icon, Rect2(Vector2(0.0, (size.y - icon_edge) * 0.5), Vector2(icon_edge, icon_edge)), false)

	var track_x := icon_edge + gap
	var track := Rect2(Vector2(track_x, (size.y - bar_height) * 0.5), Vector2(maxf(1.0, size.x - track_x), bar_height))
	_draw_rounded(track, Color(color, TRACK_ALPHA), radius)
	var fill := Rect2(track.position, Vector2(track.size.x * elapsed_fraction(), track.size.y))
	if fill.size.x > 0.0:
		_draw_rounded(fill, color, radius)

func _draw_rounded(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)
