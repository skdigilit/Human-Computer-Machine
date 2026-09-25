class_name StageView
extends Control

## Base class for the big play-area panel (top-left of the screen). Game.gd
## talks to the stage only through this surface, so a mode can swap in its own
## stage (the office RoomView, the SnakeArena) without touching the
## orchestrator, palette, program list or control bar.
##
## Every method here is a safe no-op default; subclasses override what they use.

## Emitted when the player asks for the next inbox/outbox test case.
signal test_case_swap_requested()

## Build (or rebuild) the stage for a level. Called on every reset.
func setup(_level: Level) -> void:
	pass

## Play back one VM step. May be a coroutine (the caller always awaits it).
func animate(_action: StepAction) -> void:
	pass

## Finish the current animation quickly because another manual step is queued.
func speed_up_current_animation() -> void:
	pass

## The design-space size the stage draws in; the stage scales it to fit itself.
func set_virtual_size(_size: Vector2) -> void:
	pass

## Re-apply font / control sizes after the UI scale changed.
func apply_ui_scale() -> void:
	pass

## Office-only: show ghost boxes for the expected outbox. Other stages ignore it.
func set_show_expected_outbox_boxes(_show: bool, _level: Level = null) -> void:
	pass

## Screen-space rect of the decorative floor strip, used by layout tests.
func bottom_decoration_rect() -> Rect2:
	return Rect2()
