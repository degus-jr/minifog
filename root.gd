extends Control

@onready var file_menu: PopupMenu = $GUI/MenuBar/File
@onready var settings_menu: PopupMenu = $GUI/MenuBar/Settings
@onready var file_dialog: FileDialog = $FileDialog
@onready var save_dialog: FileDialog = $FileDialog2

@onready var dm_camera: Camera2D = $Camera
@onready var dm_fog = $DmRoot/Fog
@onready var dm_root = $DmRoot
@onready var dm_background = $DmRoot/Background

@onready var player_window: Window = $PlayerWindow
@onready var player_camera: Camera2D = $PlayerWindow/Camera
@onready var player_fog = $PlayerWindow/PlayerRoot/Fog
@onready var player_root = $PlayerWindow/PlayerRoot
@onready var player_background = $PlayerWindow/PlayerRoot/Background

const LightTexture = preload('res://Light.png')
const DarkTexture = preload('res://Dark.png')


var hovering_over_gui : bool = false
var mod_held : bool = false
var black_circle_bool : bool = false

var brush_size : int = 50

var fog_scaling : float = 1.3

var map_image : Image

var map_image_height : int
var map_image_width : int

var mask_image : Image
var mask_texture : ImageTexture

var light_brush : Image
var dark_brush : Image

var m1_pressed: bool = false
var m2_pressed: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_window().title = "DM Window"
	file_menu.connect('id_pressed', _on_file_id_pressed)
	settings_menu.connect('id_pressed', _on_settings_id_pressed)
	file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.map", "Images / .map files")
	save_dialog.add_filter("*.map", ".map files")
	update_brushes()

	var args = OS.get_cmdline_args()

	if len(args) > 0:
		load_map(args[0])

	else:
		file_dialog.popup()


func update_brushes(value: int = 0) -> void:
	brush_size = max(5, brush_size + value)

	light_brush = LightTexture.get_image()
	dark_brush = DarkTexture.get_image()

	var imglist = [light_brush, dark_brush]
	for i in range(2):
		imglist[i].resize(brush_size, brush_size)
		imglist[i].convert(Image.FORMAT_RGBAH)



func update_mask(pos, erase: bool = false):
	var offset = Vector2.ONE * brush_size / 2
	if not erase:
		mask_image.blend_rect(light_brush, light_brush.get_used_rect(), pos - offset)
		mask_texture = ImageTexture.create_from_image(mask_image)
		dm_fog.material.set_shader_parameter('mask_texture', mask_texture)
		player_fog.material.set_shader_parameter('mask_texture', mask_texture)

	if erase:
		mask_image.blend_rect(dark_brush, dark_brush.get_used_rect(), pos - offset)
		mask_texture = ImageTexture.create_from_image(mask_image)
		dm_fog.material.set_shader_parameter('mask_texture', mask_texture)
		player_fog.material.set_shader_parameter('mask_texture', mask_texture)

func _process(_delta):
	if Input.is_action_pressed("quit"):
		get_tree().quit()

	queue_redraw()

func _input(event: InputEvent) -> void:

	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_C:
			black_circle_bool = not black_circle_bool
			settings_menu.set_item_checked(0, black_circle_bool)

		if event.pressed and event.keycode == KEY_T:
			update_fog_texture(Color.BLACK)

	if event.is_action_pressed('mod'):
		mod_held = true

	if event.is_action_released('mod'):
		mod_held = false

	if event.is_action_pressed('zoom_in') and mod_held:
		update_brushes(-5)

	if event.is_action_pressed('zoom_out') and mod_held:
		update_brushes(5)

	if event is InputEventMouseButton:
		if hovering_over_gui:
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			m1_pressed = event.pressed

			if m1_pressed:
				update_mask(get_global_mouse_position())

		if event.button_index == MOUSE_BUTTON_RIGHT:
			m2_pressed = event.pressed

			if m2_pressed:
				update_mask(get_global_mouse_position(), true)

	elif event is InputEventMouseMotion:
		if m1_pressed:
			update_mask(get_global_mouse_position())
		elif m2_pressed:
			update_mask(get_global_mouse_position(), true)

func _draw() -> void:
	var circle_color : Color
	if black_circle_bool:
		circle_color = Color.BLACK
	else:
		circle_color = Color.WHITE

	draw_arc(get_global_mouse_position(), brush_size * 0.5, 0.0, 2 * 3.141592, 100, circle_color, 1)
	draw_circle(get_global_mouse_position(), brush_size * 0.5, circle_color, false, 1)

func update_fog_texture(color : Color):
	var fog_image = Image.create(map_image_width * fog_scaling, map_image_height * fog_scaling, false, Image.FORMAT_RGBAH)
	mask_image.fill(color)
	var fog_image_texture = ImageTexture.create_from_image(fog_image)
	player_fog.texture = fog_image_texture
	dm_fog.texture = fog_image_texture



func load_map(path: String) -> void:
	if path.ends_with(".map"):
		var reader = ZIPReader.new()
		reader.open(path)
		mask_image = Image.new()
		mask_image.load_png_from_buffer(reader.read_file("mask.png"))
		mask_image.convert(Image.FORMAT_RGBAH)

		map_image = Image.new()
		map_image.load_png_from_buffer(reader.read_file("map.png"))
		map_image.convert(Image.FORMAT_RGBAH)

		map_image_width = map_image.get_size()[0]
		map_image_height = map_image.get_size()[1]

		reader.close()

	else:
		map_image = Image.new()
		map_image.load(path)
		map_image.convert(Image.FORMAT_RGBAH)

		map_image_width = map_image.get_size()[0]
		map_image_height = map_image.get_size()[1]


		mask_image = Image.create(map_image_width * fog_scaling, map_image_height * fog_scaling, false, Image.FORMAT_RGBAH)
		mask_image.fill(Color(0, 0, 0, 1))

	mask_texture = ImageTexture.create_from_image(mask_image)
	dm_fog.size = Vector2(map_image.get_size())
	player_fog.size = Vector2(map_image.get_size())

	dm_fog.material.set_shader_parameter('mask_texture', mask_texture)
	player_fog.material.set_shader_parameter('mask_texture', mask_texture)

	dm_camera.position = Vector2(map_image_width * 0.5, map_image_height * 0.5)

	player_camera.position = Vector2(map_image_width * 0.5, map_image_height * 0.5)

	var image_texture = ImageTexture.new()
	image_texture.set_image(map_image)
	dm_background.texture = image_texture
	player_background.texture = image_texture

func _on_file_id_pressed(id: int) -> void:
	if id == 0:
		file_dialog.popup()

	if id == 1:
		save_dialog.popup()

	if id == 2:
		get_tree().quit()

func _on_settings_id_pressed(id: int) -> void:
	if id == 0:
		black_circle_bool = not black_circle_bool
		settings_menu.set_item_checked(id, black_circle_bool)

func _on_file_dialog_file_selected(path: String) -> void:
	load_map(path)

func _on_file_dialog_2_file_selected(path:String) -> void:
	var writer = ZIPPacker.new()
	writer.open(path)
	writer.start_file("mask.png")
	writer.write_file(mask_image.save_png_to_buffer())
	writer.start_file("map.png")
	writer.write_file(map_image.save_png_to_buffer())
	writer.close_file()

	writer.close()

func _on_menu_bar_mouse_entered() -> void:
	hovering_over_gui = true

func _on_menu_bar_mouse_exited() -> void:
	hovering_over_gui = false

func _on_file_mouse_entered() -> void:
	hovering_over_gui = true

func _on_file_mouse_exited() -> void:
	hovering_over_gui = false

func _on_settings_mouse_entered() -> void:
	hovering_over_gui = true

func _on_settings_mouse_exited() -> void:
	hovering_over_gui = false
