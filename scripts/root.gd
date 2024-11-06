extends Control

@onready var file_menu: PopupMenu = $GUI/MenuBar/File
@onready var settings_menu: PopupMenu = $GUI/MenuBar/Settings
@onready var colorscheme_menu: PopupMenu = $GUI/MenuBar/Colorscheme
@onready var load_dialog: FileDialog = $LoadDialog
@onready var save_dialog: FileDialog = $SaveDialog
@onready var warning: AcceptDialog = $Warning
@onready var cursor_node : Node2D = $CursorNode
@onready var cursor_texture : TextureRect = $CursorNode/TextureRect

@onready var dm_camera: Camera2D = $Camera
@onready var dm_fog = $DmRoot/Fog
@onready var dm_root = $DmRoot
@onready var dm_background = $DmRoot/Background

@onready var player_window: Window = $PlayerWindow
@onready var player_camera: Camera2D = $PlayerWindow/Camera
@onready var player_fog = $PlayerWindow/PlayerRoot/Fog
@onready var player_root = $PlayerWindow/PlayerRoot
@onready var player_background = $PlayerWindow/PlayerRoot/Background

const LightTexture = preload('res://resources/Light.png')
const DarkTexture = preload('res://resources/Dark.png')
const PerlinTexture = preload('res://resources/fog.jpg')
const PlasmaTexture = preload('res://resources/Plasma.jpg')

const BlackIndicatorTexture = preload('res://resources/BlackIndicator.png')
const WhiteIndicatorTexture = preload('res://resources/WhiteIndicator.png')

var current_file_path : String


var hovering_over_gui : bool = false
var mod_held : bool = false
var black_circle_bool : bool = false
var performance_mode : bool = false

var brush_size : int = 50

var map_image : Image

var map_image_height : int
var map_image_width : int

var mask_image : Image
var mask_texture : ImageTexture

var light_brush : Image
var dark_brush : Image

var m1_pressed: bool = false
var m2_pressed: bool = false

var prev_mouse_pos

const FOG_COLOR_LIST : Array = [
	"fog",
	"colorful_fog",
	Color.BLACK,
	Color.WHITE,
	Color.DARK_GRAY,
	Color.FUCHSIA,
	Color.MIDNIGHT_BLUE,
	Color.LIME,
]

var fog_color_index : int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_window().title = "DM Window"
	file_menu.connect('id_pressed', _on_file_id_pressed)
	settings_menu.connect('id_pressed', _on_settings_id_pressed)
	colorscheme_menu.connect('id_pressed', update_colorscheme)
	load_dialog.add_filter("*.png, *.jpg, *.jpeg, *.map", "Images / .map files")
	save_dialog.add_filter("*.map", ".map files")
	update_brushes()

	cursor_texture.texture = WhiteIndicatorTexture
	cursor_texture.size = Vector2(brush_size, brush_size)

	var args = OS.get_cmdline_args()

	if len(args) > 0:
		load_map(args[0])

	else:
		load_dialog.popup()


func update_brushes(value: int = 0) -> void:
	brush_size = max(5, brush_size + value)
	cursor_texture.size = Vector2(brush_size, brush_size)

	light_brush = LightTexture.get_image()
	dark_brush = DarkTexture.get_image()

	var imglist = [light_brush, dark_brush]
	for i in range(2):
		imglist[i].resize(brush_size, brush_size)
		imglist[i].convert(Image.FORMAT_RGBAH)


func update_mask_wrapper(pos, erase: bool = false):
	if prev_mouse_pos == null:
		update_mask(pos, erase)
		return

	var distance = pos.distance_to(prev_mouse_pos)
	var step_size = brush_size / 2

	if distance > step_size:
		var sub_steps = floor(distance / (step_size / 2))
		var x_diff = pos.x - prev_mouse_pos.x
		var y_diff = pos.y - prev_mouse_pos.y


		for i in range(1, sub_steps + 1):
			var sub_pos = pos
			sub_pos.x -= (x_diff / sub_steps) * i
			sub_pos.y -= (y_diff / sub_steps) * i
			update_mask(sub_pos, erase)

	update_mask(pos, erase)



func update_mask(pos, erase: bool = false):
	var offset = Vector2.ONE * brush_size / 2

	if not erase:
		mask_image.blend_rect(light_brush, light_brush.get_used_rect(), pos - offset)

	if erase:
		mask_image.blend_rect(dark_brush, dark_brush.get_used_rect(), pos - offset)

	mask_texture = ImageTexture.create_from_image(mask_image)
	dm_fog.material.set_shader_parameter('mask_texture', mask_texture)
	player_fog.material.set_shader_parameter('mask_texture', mask_texture)

func _process(_delta):
	cursor_node.position = get_global_mouse_position() - Vector2.ONE * brush_size / 2
	if Input.is_action_pressed("quit"):
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if current_file_path == "":
		return

	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_C:
				black_circle_bool = not black_circle_bool
				settings_menu.set_item_checked(0, black_circle_bool)
				if black_circle_bool:
					cursor_texture.texture = BlackIndicatorTexture
				else:
					cursor_texture.texture = WhiteIndicatorTexture


			if event.keycode == KEY_T:
				var id = (fog_color_index + 1) % len(FOG_COLOR_LIST)
				update_colorscheme(id)

			if event.keycode == KEY_P:
				performance_mode = not performance_mode
				if performance_mode:
					Engine.max_fps = 30
				else:
					Engine.max_fps = 60
				settings_menu.set_item_checked(1, performance_mode)

	if event.is_action_pressed('mod'):
		mod_held = true

	if event.is_action_released('mod'):
		mod_held = false

	if event.is_action_pressed('zoom_in') and mod_held:
		update_brushes(-5)

	if event.is_action_pressed('zoom_out') and mod_held:
		update_brushes(5)

	if event.is_action_pressed('save'):
		if current_file_path != "":
			if current_file_path.ends_with('.map'):
				write_map(current_file_path)
			else:
				save_dialog.popup()


	if event is InputEventMouseButton:
		var pos = get_global_mouse_position()
		if hovering_over_gui:
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			m1_pressed = event.pressed

			if m1_pressed:
				update_mask(pos)

		if event.button_index == MOUSE_BUTTON_RIGHT:
			m2_pressed = event.pressed

			if m2_pressed:
				update_mask(pos, true)
		prev_mouse_pos = pos

	elif event is InputEventMouseMotion:
		var pos = get_global_mouse_position()
		if m1_pressed:
			update_mask_wrapper(pos)
		elif m2_pressed:
			update_mask_wrapper(pos, true)
		prev_mouse_pos = pos


func update_fog_texture(color):
	var fog_image_texture
	if color is String:
		if color == "fog":
			fog_image_texture = PerlinTexture
		elif color == "colorful_fog":
			fog_image_texture = PlasmaTexture
		RenderingServer.set_default_clear_color(Color.WHITE)

	else:
		var fog_image = Image.create(map_image_width, map_image_height, false, Image.FORMAT_RGBAH)
		fog_image.fill(color)
		fog_image_texture = ImageTexture.create_from_image(fog_image)
		RenderingServer.set_default_clear_color(color)

	player_fog.texture = fog_image_texture
	dm_fog.texture = fog_image_texture



func load_map(path: String) -> void:
	if not (
		path.ends_with('.jpg') or
		path.ends_with('.jpeg') or
		path.ends_with('.png') or
		path.ends_with('.map')
	):
		warning.title = "Invalid file format"
		warning.dialog_text = "File must be .jpg, .jpeg, .png or .map"
		warning.popup_centered()
		return


	current_file_path = path

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


		mask_image = Image.create(map_image_width, map_image_height, false, Image.FORMAT_RGBAH)
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

func write_map(path: String) -> void:
	var writer = ZIPPacker.new()
	writer.open(path)
	writer.start_file("mask.png")
	writer.write_file(mask_image.save_png_to_buffer())
	writer.start_file("map.png")
	writer.write_file(map_image.save_png_to_buffer())
	writer.close_file()

	writer.close()

func _on_file_id_pressed(id: int) -> void:
	if id == 0:
		load_dialog.popup()

	if id == 1:
		if current_file_path == "":
			warning.title = "Cannot save an empty map"
			warning.dialog_text = "Cannot save an empty map"
			warning.popup_centered()
		else:
			save_dialog.popup()

	if id == 2:
		warning.title = "Keybindings"
		warning.dialog_text = "General\n    Left click: Reveal areas\n    Right click: Hide areas\n    Middle mouse: Pan/Move view\n    Mouse wheel: Zoom\n    Shift+Mouse wheel: Resize brush\n    Ctrl+S: Save\nKeybinds\n    T: Toggle between fog themes\n    C: Change color of circle\n    P: Toggle performance mode"
		warning.popup_centered()

	if id == 3:
		get_tree().quit()

func _on_settings_id_pressed(id: int) -> void:
	if id == 0:
		black_circle_bool = not black_circle_bool
		settings_menu.set_item_checked(id, black_circle_bool)
		if black_circle_bool:
			cursor_texture.texture = BlackIndicatorTexture
		else:
			cursor_texture.texture = WhiteIndicatorTexture

	if id == 1:
		performance_mode = not performance_mode
		if performance_mode:
			Engine.max_fps = 30
		else:
			Engine.max_fps = 60
		settings_menu.set_item_checked(id, performance_mode)

func update_colorscheme(id: int) -> void:
	fog_color_index = id
	update_fog_texture(FOG_COLOR_LIST[fog_color_index])
	colorscheme_menu.set_item_checked(id, true)

	for i in range(len(FOG_COLOR_LIST)):
		colorscheme_menu.set_item_checked(i, i == id)


func _on_file_dialog_file_selected(path: String) -> void:
	load_map(path)

func _on_file_dialog_2_file_selected(path:String) -> void:
	write_map(path)


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
