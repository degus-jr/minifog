extends Camera2D

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 5.0
const ZOOM_RATE: float = 8.0
const ZOOM_INCREMENT: float = 0.1

var _target_zoom: float = 1

var mod_held : bool = false



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:

	if event.is_action_pressed('mod'):
		mod_held = true

	if event.is_action_released('mod'):
		mod_held = false

	if event is InputEventMouseMotion:

		if event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
			position -= event.relative / zoom
	if event.is_action_pressed('zoom_in') and not mod_held:
		_target_zoom = min(_target_zoom + ZOOM_INCREMENT, MAX_ZOOM)
		zoom = Vector2.ONE * _target_zoom

	elif event.is_action_pressed('zoom_out') and not mod_held:
		_target_zoom = max(_target_zoom - ZOOM_INCREMENT, MIN_ZOOM)
		zoom = Vector2.ONE * _target_zoom
