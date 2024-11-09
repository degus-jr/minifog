extends Node2D

var mouse_pos = Vector2.ZERO
var prev_mouse_pos = Vector2.ZERO
var prev_prev_mouse_pos = Vector2.ZERO
var root
var m1_held: bool = false
var m2_held: bool = false
var brush_size: int = 50
var pretend_to_draw: bool = false

var should_draw_square: bool = false

func _ready() -> void:
	root = get_tree().root.get_child(0)
	root.connect('m1', func(pressed): m1_held = pressed)
	root.connect('m2', func(pressed): m2_held = pressed)
	root.connect('brush_size_changed', func(size): brush_size = size)
	root.connect('mouse_pos_signal', func(mouse_pos_signal): mouse_pos = mouse_pos_signal)
	root.connect('pretend_to_draw', fake_drawing)
	root.connect('square_signal', func(boolean): should_draw_square = boolean)

func _draw() -> void:
	if pretend_to_draw:
		draw_circle(Vector2.ZERO, 1, Color(1, 1, 1, 1))
		pretend_to_draw = false
	prev_prev_mouse_pos = prev_mouse_pos
	if mouse_pos == prev_mouse_pos:
		return
	var radius = brush_size / 2
	var width = brush_size
	if (mouse_pos.x < 0 or
		mouse_pos.y < 0 or
		prev_mouse_pos.x < 0 or
		prev_mouse_pos.y < 0
	):
		return

	if prev_mouse_pos == Vector2.ZERO:
		if m1_held:
			if not should_draw_square:
				draw_circle(mouse_pos, radius, Color(0, 1, 1, 1), true, -1.0, false)
			else:
				draw_rect(Rect2(mouse_pos - Vector2.ONE * radius, Vector2(width, width)), Color(0, 1, 1, 1), true, -1.0, true)
		elif m2_held:
			if not should_draw_square:
				draw_circle(mouse_pos, radius, Color(1, 1, 1, 1), true, -1.0, true)
			else:
				draw_rect(Rect2(mouse_pos, Vector2(width, width)), Color(1, 1, 1, 1), true, -1.0, true)
	else:
		if m1_held:
			if not should_draw_square:
				draw_circle(mouse_pos, radius, Color(0, 1, 1, 1), true, -1.0, true)
				draw_line(mouse_pos, prev_mouse_pos, Color(0, 1, 1, 1), width, true)
			else:
				var points
				draw_rect(Rect2(mouse_pos - Vector2.ONE * radius, Vector2(width, width)), Color(0, 1, 1, 1), true, -1.0, true)
				var angle = mouse_pos.angle_to_point(prev_mouse_pos)
				if (angle < 3.141592 and angle > 1.570796) or (angle < 0 and angle > -1.570796):
					points = PackedVector2Array([
						mouse_pos - Vector2.ONE * radius,
						mouse_pos + Vector2.ONE * radius,
						prev_mouse_pos + Vector2.ONE * radius,
						prev_mouse_pos - Vector2.ONE * radius,
					])

				else:
					points = [
						[mouse_pos.x - radius, mouse_pos.y + radius],
						[mouse_pos.x + radius, mouse_pos.y - radius],
						[prev_mouse_pos.x + radius, prev_mouse_pos.y - radius],
						[prev_mouse_pos.x - radius, prev_mouse_pos.y + radius],
					]
					points = PackedVector2Array([
						mouse_pos + Vector2(-radius, radius),
						mouse_pos + Vector2(radius, -radius),
						prev_mouse_pos + Vector2(radius, -radius),
						prev_mouse_pos + Vector2(-radius, radius)
					])
				draw_colored_polygon(points, Color(0, 1, 1, 1))
		elif m2_held:
			if not should_draw_square:
				draw_circle(mouse_pos, radius, Color(1, 1, 1, 1), true, -1.0, true)
				draw_line(mouse_pos, prev_mouse_pos, Color(1, 1, 1, 1), width, true)
			else:
				draw_rect(Rect2(mouse_pos - Vector2.ONE * radius, Vector2(width, width)), Color(1, 1, 1, 1), true, -1.0, true)
				draw_line(mouse_pos, prev_mouse_pos, Color(1, 1, 1, 1), width, true)

	prev_mouse_pos = mouse_pos


func fake_drawing() -> void:
	pretend_to_draw = true
	queue_redraw()


func _process(_delta: float) -> void:
	if m1_held or m2_held:
		queue_redraw()
	else:
		prev_mouse_pos = Vector2.ZERO
