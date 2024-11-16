extends Camera2D

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 5.0
const ZOOM_RATE: float = 8.0
const ZOOM_INCREMENT: float = 0.1
const MOVE_SPEED : int = 300

var target_zoom: float = 1

var shift_held : bool = false
var ctrl_held : bool = false

var right_held : bool = false
var left_held : bool = false
var up_held : bool = false
var down_held : bool = false

signal mouse_pos_signal(pos : Vector2)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			shift_held = event.pressed

		if event.keycode == KEY_CTRL:
			ctrl_held = event.pressed

		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			left_held = event.pressed

		if event.keycode == KEY_UP or event.keycode == KEY_W:
			up_held = event.pressed

		if event.keycode == KEY_DOWN:
			down_held = event.pressed

		if event.keycode == KEY_S:
			if event.pressed:
				if not ctrl_held:
					down_held = true
			else:
				down_held = false

		if event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			right_held = event.pressed

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and not shift_held:
			target_zoom = min(target_zoom + ZOOM_INCREMENT, MAX_ZOOM)
			zoom = Vector2.ONE * target_zoom
			mouse_pos_signal.emit(get_global_mouse_position())

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not shift_held:
			target_zoom = max(target_zoom - ZOOM_INCREMENT, MIN_ZOOM)
			zoom = Vector2.ONE * target_zoom
			mouse_pos_signal.emit(get_global_mouse_position())

	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
			position -= event.relative / zoom

func _physics_process(delta : float) -> void:
	if left_held:
		position.x -= MOVE_SPEED * delta / zoom.x
		mouse_pos_signal.emit(get_global_mouse_position())
	if right_held:
		position.x += MOVE_SPEED * delta / zoom.x
		mouse_pos_signal.emit(get_global_mouse_position())
	if up_held:
		position.y -= MOVE_SPEED * delta / zoom.x
		mouse_pos_signal.emit(get_global_mouse_position())
	if down_held:
		position.y += MOVE_SPEED * delta / zoom.x
		mouse_pos_signal.emit(get_global_mouse_position())

