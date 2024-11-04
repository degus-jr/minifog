extends Control

@onready var file_menu: PopupMenu = $GUI/MenuBar/File
@onready var settings_menu: PopupMenu = $GUI/MenuBar/Settings
@onready var file_dialog: FileDialog = $FileDialog
@onready var save_dialog: FileDialog = $FileDialog2
@onready var camera: Camera2D = $Camera2D
@onready var player_window: Window = $PlayerWindow
@onready var dm_fog = $Fog
@onready var player_fog = $PlayerWindow/Fog
@onready var background_node = $BackgroundNode
@onready var background = $BackgroundNode/Background

const LightTexture = preload('res://Light.png')
const DarkTexture = preload('res://Dark.png')
const GrayTexture = preload('res://Gray.png')


var hovering_over_gui : bool = false
var mod_held : bool = false
var black_circle_bool : bool = false

var undo_list : Array = []

var blend_rect_size : int = 50


var fog_scaling : float = 1.0

var map_image : Image

var map_image_height : int
var map_image_width : int

var dm_fog_image : Image
var dm_fog_texture : ImageTexture

var player_fog_image : Image
var player_fog_texture : ImageTexture

var light_brush : Image
var dark_brush : Image
var gray_brush : Image

var m1_pressed: bool = false
var m2_pressed: bool = false
var current_line: Line2D = null


var WIDTH: int = 10
var COLOR = Color.BLUE


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
	blend_rect_size = max(5, blend_rect_size + value)

	light_brush = LightTexture.get_image()
	dark_brush = DarkTexture.get_image()
	gray_brush = GrayTexture.get_image()

	var imglist = [light_brush, dark_brush, gray_brush]
	for i in range(3):
		imglist[i].resize(blend_rect_size, blend_rect_size)
		imglist[i].convert(Image.FORMAT_RGBAH)



func update_fog(pos, erase: bool = false):
	var offset = Vector2(blend_rect_size / 2, blend_rect_size / 2) - Vector2(map_image_width * fog_scaling * 0.5, map_image_height * fog_scaling * 0.5)
	var blend_rect = Rect2(Vector2.ZERO, Vector2.ONE * blend_rect_size)
	if not erase:
		dm_fog_image.blend_rect(light_brush, blend_rect, pos - offset)
		dm_fog_texture.update(dm_fog_image)

		player_fog_image.blend_rect(light_brush, blend_rect, pos - offset)
		player_fog_texture.update(dm_fog_image)

		dm_fog.material.set_shader_parameter('mask_texture', player_fog_texture)

	if erase:
		dm_fog_image.blend_rect(gray_brush, blend_rect, pos - offset)
		dm_fog_texture.update(dm_fog_image)

		player_fog_image.blend_rect(dark_brush, blend_rect, pos - offset)
		player_fog_texture.update(player_fog_image)


func _process(_delta):
	if Input.is_action_pressed("quit"):
		get_tree().quit()

	queue_redraw()

func _input(event: InputEvent) -> void:

	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_C:
			black_circle_bool = not black_circle_bool
			settings_menu.set_item_checked(0, black_circle_bool)

	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_Z:
			for i in range(len(undo_list)):
				update_fog(undo_list[i][0], not undo_list[i][1])
			# undo_list.pop_back()
			print(undo_list)

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
				# undo_list.append([get_global_mouse_position(), false])
				update_fog(get_global_mouse_position())

		if event.button_index == MOUSE_BUTTON_RIGHT:
			m2_pressed = event.pressed

			if m2_pressed:
				# undo_list.append([get_global_mouse_position(), true])
				update_fog(get_global_mouse_position(), true)

	elif event is InputEventMouseMotion:
		if m1_pressed:
			# undo_list.append([get_global_mouse_position(), false])
			update_fog(get_global_mouse_position())
		elif m2_pressed:
			# undo_list.append([get_global_mouse_position(), true])
			update_fog(get_global_mouse_position(), true)

func _draw() -> void:
	var circle_color : Color
	if black_circle_bool:
		circle_color = Color.BLACK
	else:
		circle_color = Color.WHITE

	# draw_arc(get_global_mouse_position(), blend_rect_size * 0.5, 0.0, 2 * 3.141592, 100, circle_color, 1)
	draw_circle(get_global_mouse_position(), blend_rect_size * 0.5, circle_color, false, 1)

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


func load_map(path: String) -> void:
	if path.ends_with(".map"):
		var reader = ZIPReader.new()
		reader.open(path)
		dm_fog_image = Image.new()
		dm_fog_image.load_png_from_buffer(reader.read_file("dm_fog.png"))
		dm_fog_image.convert(Image.FORMAT_RGBAH)

		player_fog_image = Image.new()
		player_fog_image.load_png_from_buffer(reader.read_file("player_fog.png"))
		player_fog_image.convert(Image.FORMAT_RGBAH)

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


		# dm_fog_image = Image.new()
		dm_fog_image = Image.create(map_image_width * fog_scaling, map_image_height * fog_scaling, false, Image.FORMAT_RGBAH)
		dm_fog_image.fill(Color.RED)
		dm_fog_image.resize(map_image_width, map_image_height)


		player_fog_image = Image.create(map_image_width * fog_scaling, map_image_height * fog_scaling, false, Image.FORMAT_RGBAH)
		player_fog_image.fill(Color(0, 0, 0, 1))

	dm_fog_texture = ImageTexture.create_from_image(dm_fog_image)
	dm_fog.scale = Vector2.ONE * 2

	player_fog_texture = ImageTexture.create_from_image(player_fog_image)
	player_fog.texture = player_fog_texture
	dm_fog.material.set_shader_parameter('mask_texture', dm_fog_texture)


	var image_texture = ImageTexture.new()
	image_texture.set_image(map_image)

	background.texture = image_texture
	background_node.position = -Vector2(map_image_width * fog_scaling * 0.5, map_image_height * fog_scaling * 0.5)

	player_window.add_child(background_node.duplicate())


func _on_file_dialog_2_file_selected(path:String) -> void:
	var writer = ZIPPacker.new()
	writer.open(path)
	writer.start_file("dm_fog.png")
	writer.write_file(dm_fog_image.save_png_to_buffer())
	writer.start_file("player_fog.png")
	writer.write_file(player_fog_image.save_png_to_buffer())
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
