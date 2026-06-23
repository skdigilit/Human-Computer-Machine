class_name Worker
extends Control

## A hatless, square warehouse helper inspired by Wilmot's modular objects.
##
## Movement itself is driven by the RoomView via tweens on `position`; this node
## only owns how the worker looks and where a carried box should sit.

## Box currently snapped to the worker's hands, or null when empty-handed.
var held_box: NumberBox = null

func _init() -> void:
	custom_minimum_size = VisualTheme.WORKER_SIZE
	size = VisualTheme.WORKER_SIZE
	pivot_offset = VisualTheme.WORKER_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	var body_rect := Rect2(2, 2, w - 4, h - 4)
	draw_rect(body_rect, Color.html(VisualTheme.WORKER_BODY), true)
	draw_rect(body_rect, Color.html(VisualTheme.WORKER_FACE), false, 3.0)

	# --- Face: two dot eyes and a friendly smile. ---
	var face_col := Color.html(VisualTheme.WORKER_FACE)
	var eye_y := h * 0.36
	draw_circle(Vector2(w * 0.34, eye_y), 3.2, face_col)
	draw_circle(Vector2(w * 0.66, eye_y), 3.2, face_col)
	_draw_smile(Vector2(w * 0.5, eye_y + 8), w * 0.19, face_col)

## Draw a simple upward smile arc centred at `center`.
func _draw_smile(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments := 12
	for i in segments + 1:
		var t := float(i) / float(segments)
		var angle := lerpf(0.15 * PI, 0.85 * PI, t)
		# Arc opening upward, so y uses +sin.
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, 2.5, true)

## The carried piece occupies the cell directly below the worker. At memory,
## this keeps it away from the horizontal row of tile cells.
func carry_local_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y + VisualTheme.BOX_SIZE.y * 0.5)
