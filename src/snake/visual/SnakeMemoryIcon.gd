class_name SnakeMemoryIcon
extends Control

## Small code-drawn symbols for Snake state and memory tiles. The four-point
## diamond is the direction symbol used by MOVE and the facing tile.

enum Kind { KEY, DIRECTION, VALUE }

var kind: Kind = Kind.KEY:
	set(value):
		kind = value
		queue_redraw()
var ink: Color = Color.html(VisualTheme.PAPER):
	set(value):
		ink = value
		queue_redraw()

func _init(p_kind: Kind = Kind.KEY) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(20, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.38
	var width := maxf(1.5, r * 0.18)
	match kind:
		Kind.KEY:
			draw_rect(Rect2(center - Vector2(r, r * 0.65), Vector2(r * 2.0, r * 1.3)), ink, false, width)
			for row in 2:
				for column in 3:
					draw_rect(Rect2(center + Vector2((column - 1) * r * 0.48 - r * 0.12, (row - 0.5) * r * 0.45 - r * 0.1), Vector2(r * 0.24, r * 0.2)), ink)
		Kind.DIRECTION:
			var points := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0), center + Vector2(0, -r)])
			draw_polyline(points, ink, width, true)
			draw_line(center + Vector2(0, -r * 0.55), center + Vector2(0, r * 0.55), ink, width)
			draw_line(center + Vector2(-r * 0.55, 0), center + Vector2(r * 0.55, 0), ink, width)
		Kind.VALUE:
			draw_rect(Rect2(center - Vector2(r, r * 0.75), Vector2(r * 2.0, r * 1.5)), ink, false, width)
			draw_line(center + Vector2(-r * 0.55, -r * 0.2), center + Vector2(r * 0.55, -r * 0.2), ink, width)
			draw_line(center + Vector2(-r * 0.55, r * 0.3), center + Vector2(r * 0.25, r * 0.3), ink, width)
