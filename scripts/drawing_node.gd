extends Node2D

signal on_finished_drawing

enum tool { SQUARE_BRUSH, ROUND_BRUSH, SELECTOR, TOKEN_PLACER, LENGTH }

var m1_held := false
var m2_held := false
var selector := false
var pretend_to_draw := false
var should_draw_square:= false
var selector_erase : bool

var brush_size: int = 50
var tool_index : int = 0

var mouse_pos := Vector2.ZERO
var prev_mouse_pos  := Vector2.ZERO
var prev_prev_mouse_pos := Vector2.ZERO
var selector_end_pos : Vector2
var selector_start_pos : Vector2

var color := Color(1, 0, 0, 1)


@onready var root : Control = get_node('/root/Root')
@onready var panned_camera : Camera2D = get_node('/root/Root/Camera')



func _ready() -> void:
	# root = get_tree().root.get_child(0)
	root.connect('on_m1_pressed', func(pressed : bool) -> void: m1_held = pressed)
	root.connect('on_m2_pressed', func(pressed : bool) -> void: m2_held = pressed)
	root.connect('brush_size_changed', func(size : int) -> void: brush_size = size)
	root.connect('on_mouse_pos_changed', func(mouse_pos_signal : Vector2) -> void: mouse_pos = mouse_pos_signal)

	root.connect('pretend_to_draw', fake_drawing)
	root.connect('tool_changed', func(index : int) -> void: tool_index = index)

	root.connect('selector_finished', on_selector_finished)

	panned_camera.connect('on_mouse_pos_changed', func(mouse_pos_signal : Vector2) -> void: mouse_pos = mouse_pos_signal)


func _draw() -> void:
	if pretend_to_draw:
		draw_circle(Vector2.ZERO, 1, Color(1, 0, 0, 1))
		pretend_to_draw = false
	prev_prev_mouse_pos = prev_mouse_pos

	if selector:
		draw_rect(Rect2(selector_start_pos, selector_end_pos - selector_start_pos), color, true, -1.0, true)
		selector = false
		on_finished_drawing.emit()

	if mouse_pos == prev_mouse_pos:
		return
	var radius : float = float(brush_size) / 2
	var width : int = brush_size
	if (mouse_pos.x < 0 or
		mouse_pos.y < 0 or
		prev_mouse_pos.x < 0 or
		prev_mouse_pos.y < 0
	):
		return

	if prev_mouse_pos == Vector2.ZERO:
		if m1_held or m2_held:
			if tool_index == tool.ROUND_BRUSH:
				draw_circle(mouse_pos, radius, color, true, -1.0, false)
			elif tool_index == tool.SQUARE_BRUSH:
				draw_rect(Rect2(mouse_pos - Vector2.ONE * radius, Vector2(width, width)), color, true, -1.0, true)
	else:
		if m1_held or m2_held:
			if tool_index == tool.ROUND_BRUSH:
				draw_circle(mouse_pos, radius, color, true, -1.0, true)
				draw_line(mouse_pos, prev_mouse_pos, color, width, true)
			elif tool_index == tool.SQUARE_BRUSH:
				var points : PackedVector2Array
				var angle : float = mouse_pos.angle_to_point(prev_mouse_pos)

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

				draw_rect(Rect2(mouse_pos - Vector2.ONE * radius, Vector2(width, width)), color, true, -1.0, true)
				draw_colored_polygon(points, color)

	prev_mouse_pos = mouse_pos

func on_selector_finished(start : Vector2, end : Vector2) -> void:
	selector_end_pos = end
	selector_start_pos = start
	selector = true
	queue_redraw()


func fake_drawing() -> void:
	pretend_to_draw = true
	queue_redraw()


func _process(_delta: float) -> void:
	if m1_held or m2_held:
		if m1_held:
			color = Color(0, 0, 0, 1)
		elif m2_held:
			color = Color(1, 0, 0, 1)
		queue_redraw()
	else:
		prev_mouse_pos = Vector2.ZERO
