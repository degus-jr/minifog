extends Control

signal on_m1_pressed(pressed: bool)
signal on_m2_pressed(pressed: bool)
signal on_mouse_pos_changed(position: Vector2)
signal brush_size_changed(size: int)
signal tool_changed(index: int)
signal selector_finished(start: Vector2, end: Vector2)
signal pretend_to_draw

enum tool { SQUARE_BRUSH, ROUND_BRUSH, SELECTOR, TOKEN_PLACER, LENGTH }

const PerlinTexture = preload("res://resources/Fog.jpg")
const PlasmaTexture = preload("res://resources/Plasma.jpg")

const CircleIcon = preload("res://resources/CircleIcon.png")
const SquareIcon = preload("res://resources/SquareIcon.png")
const SelectorIcon = preload("res://resources/SelectorIcon.png")

const BRUSH_SIZE_MIN: int = 5
const BRUSH_SIZE_MAX: int = 500

const MAX_IMAGE_SIZE: float = 3000.0

const CORNER_BASE_SIZE: int = 16

const FOG_COLOR_LIST: Array = [
	Color.BURLYWOOD,  # not actually used, stand in for fog
	Color.DEEP_PINK,  # not actually used, stand in for colorful fog
	Color.BLACK,
	Color.WHITE,
	Color.DARK_GRAY,
	Color.FUCHSIA,
	Color.BLUE,
	Color.LIME,
]

const UNDO_LIST_MAX_SIZE: int = 15

var tool_index: int = 0
var fog_color_index: int = 0
var brush_size: int = 50
var fog_image_height: int
var fog_image_width: int

var ctrl_held := false
var m1_held := false
var m2_held := false
var selecting := false
var hovering_over_gui := false
var performance_mode := false
var in_sidebar := false

var undo_list: Array = []
var corner_list: Array = []

var selector_start_pos := Vector2.ZERO
var selector_end_pos := Vector2.ZERO

var current_file_path: String

var fog_scaling: float = 1.2

var mask_image_texture: Texture2D

var mask_texture: ImageTexture

var map_image: Image
var mask_image: Image
var light_brush: Image
var dark_brush: Image

@onready var menu_bar: MenuBar = $GUI/MenuBar
@onready var file_menu: PopupMenu = $GUI/MenuBar/File
@onready var help_menu: PopupMenu = $GUI/MenuBar/Help
@onready var saving_label: Label = $GUI/SavingLabel
@onready var colorscheme_menu: PopupMenu = $GUI/MenuBar/Colorscheme
@onready var tool_sidebar: PanelContainer = $GUI/ToolContainer
@onready var scroll_sidebar: PanelContainer = $GUI/ScrollBarContainer

@onready var scrollbar: VScrollBar = $GUI/ScrollBarContainer/VScrollBar
@onready var square_brush_button: Button = $GUI/ToolContainer/VBoxContainer/SquareBrushButton
@onready var circle_brush_button: Button = $GUI/ToolContainer/VBoxContainer/CircleBrushButton
@onready var selector_button: Button = $GUI/ToolContainer/VBoxContainer/SelectorButton
@onready var token_button: Button = $GUI/ToolContainer/VBoxContainer/TokenButton

# @onready var separator : HSeparator = $GUI/ToolContainer/VBoxContainer/Separator
@onready var tool_label: Label = $GUI/ToolContainer/VBoxContainer/ToolLabel
@onready var info_degus: TextureRect = $InfoDegus

@onready var text: TextEdit = $TextEdit
@onready var player_text: TextEdit = $PlayerWindow/TextEdit

@onready var load_dialog: FileDialog = $LoadDialog
@onready var save_dialog: FileDialog = $SaveDialog
@onready var warning: AcceptDialog = $Warning
@onready var cursor_node: Node2D = $CursorNode
@onready var cursor_panel: Panel = $CursorNode/Panel

@onready var drawing_viewport: SubViewport = $DrawingViewport
@onready var drawing_node: Node2D = $DrawingViewport/DrawingNode
@onready var drawing_texture: TextureRect = $DrawingViewport/DrawingTexture

@onready var dm_camera: Camera2D = $Camera
@onready var dm_fog: TextureRect = $DmFog
@onready var dm_root: Node2D = $DmRoot
@onready var dm_background: TextureRect = $DmRoot/Background

@onready var player_window: Window = $PlayerWindow
@onready var player_camera: Camera2D = $PlayerWindow/Camera
@onready var player_fog: TextureRect = $PlayerWindow/PlayerFog
@onready var player_root: Node2D = $PlayerWindow/PlayerRoot
@onready var player_background: TextureRect = $PlayerWindow/PlayerRoot/Background

@onready var player_view: Panel = $PlayerViewRectangle
@onready var player_view_text: TextEdit = $PlayerViewRectangle/TextEdit


func _ready() -> void:
	get_window().title = "DM Window"

	load_dialog.connect("file_selected", func(path: String) -> void: load_map(path))
	save_dialog.connect("file_selected", func(path: String) -> void: write_map(path))
	scrollbar.connect("value_changed", on_scrollbar_value_changed)

	file_menu.connect("id_pressed", _on_file_id_pressed)
	help_menu.connect("id_pressed", _on_help_id_pressed)
	colorscheme_menu.connect("id_pressed", update_colorscheme)

	square_brush_button.connect("pressed", func() -> void: select_tool(tool.SQUARE_BRUSH))
	circle_brush_button.connect("pressed", func() -> void: select_tool(tool.ROUND_BRUSH))
	selector_button.connect("pressed", func() -> void: select_tool(tool.SELECTOR))
	token_button.connect("pressed", func() -> void: select_tool(tool.TOKEN_PLACER))

	square_brush_button.connect("mouse_exited", square_brush_button.release_focus)
	circle_brush_button.connect("mouse_exited", circle_brush_button.release_focus)
	selector_button.connect("mouse_exited", selector_button.release_focus)

	scrollbar.set_value_no_signal(brush_size)

	drawing_node.connect("on_finished_drawing", wait_one_frame_and_then_copy)

	update_tool_visuals()
	select_tool(0)

	var gui_list: Array = [
		menu_bar,
		file_menu,
		colorscheme_menu,
		tool_sidebar,
		scrollbar,
		square_brush_button,
		circle_brush_button,
		selector_button,
		token_button
	]
	for i in range(len(gui_list)):
		gui_list[i].connect("mouse_entered", func() -> void: hovering_over_gui = true)
		gui_list[i].connect("mouse_exited", func() -> void: hovering_over_gui = false)

	var sidebar_list: Array = [
		tool_sidebar,
		scroll_sidebar,
		scrollbar,
		square_brush_button,
		circle_brush_button,
		selector_button,
		token_button
	]

	for i in range(len(sidebar_list)):
		sidebar_list[i].connect("mouse_entered", are_we_inside_sidebar)
		sidebar_list[i].connect("mouse_exited", func() -> void: in_sidebar = false)

	load_dialog.add_filter("*.png, *.jpg, *.jpeg, *.map", "Images / .map files")
	save_dialog.add_filter("*.map", ".map files")
	update_brushes()

	cursor_panel.size = Vector2(brush_size, brush_size)

	var args: Array = OS.get_cmdline_args()

	if len(args) > 0:
		load_map(args[0])


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_L:
				load_dialog.popup()
	if current_file_path == "":
		return

	if event is InputEventKey:
		if event.keycode == KEY_CTRL:
			ctrl_held = event.pressed

		if event.pressed:
			if event.keycode == KEY_Z:
				if len(undo_list) > 1:
					undo_list.pop_back()

				var action: String = undo_list[-1][0]
				var payload: Texture2D = undo_list[-1][1]

				if action == "just_drew":
					drawing_texture.texture = payload
					drawing_texture.visible = true
					dm_fog.material.set_shader_parameter("mask_texture", payload)
					player_fog.material.set_shader_parameter("mask_texture", payload)

					pretend_to_draw.emit()

					drawing_texture.texture = payload
					drawing_texture.visible = true
					dm_fog.material.set_shader_parameter(
						"mask_texture", drawing_viewport.get_texture()
					)
					player_fog.material.set_shader_parameter(
						"mask_texture", drawing_viewport.get_texture()
					)

			if event.keycode == KEY_SPACE:
				select_tool((tool_index + 1) % tool.LENGTH)

			if event.keycode == KEY_T:
				var id: int = (fog_color_index + 1) % len(FOG_COLOR_LIST)
				update_colorscheme(id)

			if event.keycode == KEY_P:
				performance_mode = not performance_mode
				if performance_mode:
					Engine.max_fps = 30
				else:
					Engine.max_fps = 60

			if event.keycode == KEY_S:
				if ctrl_held:
					if current_file_path != "":
						if current_file_path.ends_with(".map"):
							set_cursor_shape(CursorShape.CURSOR_WAIT)
							saving_label.visible = true
							await get_tree().process_frame
							await get_tree().process_frame
							write_map(current_file_path)
							saving_label.visible = false
							set_cursor_shape()
						else:
							save_dialog.popup()

	if event is InputEventMouseButton:
		on_mouse_pos_changed.emit(get_global_mouse_position())

		if tool_index == tool.TOKEN_PLACER:
			pass

		else:
			if tool_index == tool.SELECTOR:
				if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
					if event.pressed:
						if hovering_over_gui:
							return
						selecting = true
						selector_start_pos = get_global_mouse_position()

					if event.pressed == false:
						if m1_held or m2_held:
							selecting = false
							selector_end_pos = get_global_mouse_position()
							selector_finished.emit(selector_start_pos, selector_end_pos)
					if event.button_index == MOUSE_BUTTON_LEFT:
						m1_held = event.pressed
						on_m1_pressed.emit(event.pressed)
					elif event.button_index == MOUSE_BUTTON_RIGHT:
						m2_held = event.pressed
						on_m2_pressed.emit(event.pressed)
				return

			if event.button_index == MOUSE_BUTTON_LEFT:
				if hovering_over_gui and event.pressed:
					return
				drawing_texture.visible = false

				if event.pressed == false and m1_held:
					copy_viewport_texture()
				m1_held = event.pressed
				on_m1_pressed.emit(event.pressed)

			if event.button_index == MOUSE_BUTTON_RIGHT:
				if hovering_over_gui and event.pressed:
					return
				drawing_texture.visible = false

				if event.pressed == false and m2_held:
					copy_viewport_texture()

				m2_held = event.pressed
				on_m2_pressed.emit(event.pressed)

			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if ctrl_held:
					update_brushes(-5)
					scrollbar.set_value_no_signal(brush_size)

			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if ctrl_held:
					update_brushes(5)
					scrollbar.set_value_no_signal(brush_size)

	elif event is InputEventMouseMotion:
		if m1_held or m2_held:
			drawing_texture.visible = false
		on_mouse_pos_changed.emit(get_global_mouse_position())


func on_scrollbar_value_changed(value: float) -> void:
	brush_size = value
	brush_size_changed.emit(brush_size)

	if tool_index == tool.ROUND_BRUSH:
		var new_stylebox_normal: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
		new_stylebox_normal.corner_radius_top_left = brush_size / 2
		new_stylebox_normal.corner_radius_top_right = brush_size / 2
		new_stylebox_normal.corner_radius_bottom_left = brush_size / 2
		new_stylebox_normal.corner_radius_bottom_right = brush_size / 2
		cursor_panel.add_theme_stylebox_override("panel", new_stylebox_normal)


func update_brushes(value: int = 0) -> void:
	brush_size = min(max(BRUSH_SIZE_MIN, brush_size + value), BRUSH_SIZE_MAX)
	brush_size_changed.emit(brush_size)

	if tool_index == tool.ROUND_BRUSH:
		var new_stylebox_normal: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
		new_stylebox_normal.corner_radius_top_left = brush_size / 2
		new_stylebox_normal.corner_radius_top_right = brush_size / 2
		new_stylebox_normal.corner_radius_bottom_left = brush_size / 2
		new_stylebox_normal.corner_radius_bottom_right = brush_size / 2
		cursor_panel.add_theme_stylebox_override("panel", new_stylebox_normal)


func set_cursor_shape(shape: CursorShape = CursorShape.CURSOR_ARROW) -> void:
	mouse_default_cursor_shape = shape
	cursor_panel.mouse_default_cursor_shape = shape
	player_view.mouse_default_cursor_shape = shape
	player_view_text.mouse_default_cursor_shape = shape


func _process(_delta: float) -> void:
	if tool_index != tool.SELECTOR:
		if in_sidebar:
			cursor_node.position = dm_camera.position - Vector2.ONE * brush_size / 2
		else:
			cursor_node.position = get_global_mouse_position() - Vector2.ONE * brush_size / 2
		cursor_panel.size = Vector2(brush_size, brush_size)

	if current_file_path == "":
		return

	var view_size: Vector2 = player_window.get_visible_rect().size
	var view_transform: Transform2D = player_window.get_canvas_transform()

	player_view.position = view_transform.origin / -view_transform.x[0]
	player_view.size = view_size / view_transform.x[0]

	queue_redraw()
	if tool_index == tool.SELECTOR:
		draw_selector()


# func _draw() -> void:
# 	if current_file_path == "":
# 		return
#
# 	var view_size : Vector2 = player_window.get_visible_rect().size
# 	var view_position : Vector2 = player_window.get_canvas_transform().origin
# 	var view_rect : Rect2 = Rect2(view_position * -1, view_size)
#
# 	draw_rect(view_rect, Color(0, 0, 0, 1))


func draw_selector() -> void:
	if selecting:
		cursor_panel.visible = true
	else:
		cursor_panel.visible = false

	var mouse_pos: Vector2 = get_global_mouse_position()

	cursor_panel.size = (selector_start_pos - mouse_pos).abs()

	if mouse_pos.x >= selector_start_pos.x:
		cursor_node.position.x = selector_start_pos.x
	else:
		cursor_node.position.x = mouse_pos.x
	if mouse_pos.y >= selector_start_pos.y:
		cursor_node.position.y = selector_start_pos.y
	else:
		cursor_node.position.y = mouse_pos.y


func update_tool_visuals() -> void:
	var button_list: Array = [square_brush_button, circle_brush_button, selector_button, token_button]

	for i in range(len(button_list)):
		var new_stylebox_pressed: StyleBox = button_list[i].get_theme_stylebox("normal").duplicate()
		new_stylebox_pressed.border_width_left = 0
		new_stylebox_pressed.border_width_right = 0
		new_stylebox_pressed.border_width_top = 0
		new_stylebox_pressed.border_width_bottom = 0
		button_list[i].add_theme_stylebox_override("normal", new_stylebox_pressed)

	if tool_index == tool.SQUARE_BRUSH:
		set_cursor_shape(CursorShape.CURSOR_CROSS)
		cursor_panel.visible = true
		var new_stylebox_normal: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
		new_stylebox_normal.corner_radius_top_left = 3
		new_stylebox_normal.corner_radius_top_right = 3
		new_stylebox_normal.corner_radius_bottom_left = 3
		new_stylebox_normal.corner_radius_bottom_right = 3
		cursor_panel.add_theme_stylebox_override("panel", new_stylebox_normal)

		scroll_sidebar.visible = true

		var new_stylebox_pressed: StyleBox = (
			square_brush_button.get_theme_stylebox("normal").duplicate()
		)
		new_stylebox_pressed.border_width_left = 2
		new_stylebox_pressed.border_width_right = 2
		new_stylebox_pressed.border_width_top = 2
		new_stylebox_pressed.border_width_bottom = 2
		square_brush_button.add_theme_stylebox_override("normal", new_stylebox_pressed)

	elif tool_index == tool.ROUND_BRUSH:
		set_cursor_shape(CursorShape.CURSOR_CROSS)
		cursor_panel.visible = true
		var new_stylebox_normal: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
		new_stylebox_normal.corner_radius_top_left = brush_size / 2
		new_stylebox_normal.corner_radius_top_right = brush_size / 2
		new_stylebox_normal.corner_radius_bottom_left = brush_size / 2
		new_stylebox_normal.corner_radius_bottom_right = brush_size / 2
		cursor_panel.add_theme_stylebox_override("panel", new_stylebox_normal)

		scroll_sidebar.visible = true

		var new_stylebox_pressed: StyleBox = (
			circle_brush_button.get_theme_stylebox("normal").duplicate()
		)
		new_stylebox_pressed.border_width_left = 2
		new_stylebox_pressed.border_width_right = 2
		new_stylebox_pressed.border_width_top = 2
		new_stylebox_pressed.border_width_bottom = 2
		circle_brush_button.add_theme_stylebox_override("normal", new_stylebox_pressed)

	elif tool_index == tool.SELECTOR:
		set_cursor_shape()
		var new_stylebox_normal: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
		new_stylebox_normal.corner_radius_top_left = 3
		new_stylebox_normal.corner_radius_top_right = 3
		new_stylebox_normal.corner_radius_bottom_left = 3
		new_stylebox_normal.corner_radius_bottom_right = 3
		cursor_panel.add_theme_stylebox_override("panel", new_stylebox_normal)

		scroll_sidebar.visible = false

		var new_stylebox_pressed: StyleBox = (
			selector_button.get_theme_stylebox("normal").duplicate()
		)
		new_stylebox_pressed.border_width_left = 2
		new_stylebox_pressed.border_width_right = 2
		new_stylebox_pressed.border_width_top = 2
		new_stylebox_pressed.border_width_bottom = 2
		selector_button.add_theme_stylebox_override("normal", new_stylebox_pressed)

	elif tool_index == tool.TOKEN_PLACER:
		set_cursor_shape(CursorShape.CURSOR_CAN_DROP)

		var new_stylebox_normal: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
		new_stylebox_normal.corner_radius_top_left = 3
		new_stylebox_normal.corner_radius_top_right = 3
		new_stylebox_normal.corner_radius_bottom_left = 3
		new_stylebox_normal.corner_radius_bottom_right = 3
		cursor_panel.add_theme_stylebox_override("panel", new_stylebox_normal)

		scroll_sidebar.visible = false

		var new_stylebox_pressed: StyleBox = (
			token_button.get_theme_stylebox("normal").duplicate()
		)
		new_stylebox_pressed.border_width_left = 2
		new_stylebox_pressed.border_width_right = 2
		new_stylebox_pressed.border_width_top = 2
		new_stylebox_pressed.border_width_bottom = 2
		token_button.add_theme_stylebox_override("normal", new_stylebox_pressed)


func copy_viewport_texture() -> void:
	var image: Image = drawing_viewport.get_texture().get_image()
	image.convert(Image.FORMAT_R8)
	var image_texture: Texture2D = ImageTexture.new()
	image_texture = ImageTexture.create_from_image(image)
	undo_list.append(["just_drew", image_texture])

	if len(undo_list) > UNDO_LIST_MAX_SIZE:
		undo_list.pop_front()


func update_fog_texture(color: Color) -> void:
	var fog_image_texture: Texture2D
	if color == Color.BURLYWOOD:
		fog_image_texture = PerlinTexture
		RenderingServer.set_default_clear_color(Color.WHITE)
	elif color == Color.DEEP_PINK:
		fog_image_texture = PlasmaTexture
		RenderingServer.set_default_clear_color(Color.WHITE)
	else:
		var fog_image: Image = Image.create(
			fog_image_width, fog_image_height, false, Image.FORMAT_RGBA8
		)
		fog_image.fill(color)
		fog_image_texture = ImageTexture.create_from_image(fog_image)
		RenderingServer.set_default_clear_color(color)

	player_fog.texture = fog_image_texture
	dm_fog.texture = fog_image_texture


func get_fog_size(image_size: Vector2i) -> void:
	if image_size[0] > image_size[1]:
		fog_image_width = image_size[0] * fog_scaling
		fog_image_height = image_size[0] * fog_scaling
	else:
		fog_image_width = image_size[1] * fog_scaling
		fog_image_height = image_size[1] * fog_scaling


func load_map(path: String) -> void:
	if not (
		path.ends_with(".jpg")
		or path.ends_with(".jpeg")
		or path.ends_with(".png")
		or path.ends_with(".map")
	):
		warning.title = "Invalid file format"
		warning.dialog_text = "File must be .jpg, .jpeg, .png or .map"
		warning.popup_centered()
		return

	if path.ends_with(".map"):
		var reader: ZIPReader = ZIPReader.new()
		var error := reader.open(path)

		if error != OK:
			warning.title = "Error"
			warning.dialog_text = "Error loading map"
			warning.popup_centered()
			return

		mask_image = Image.new()
		mask_image.load_png_from_buffer(reader.read_file("mask.png"))
		mask_image.convert(Image.FORMAT_R8)

		mask_image_texture = ImageTexture.new()
		mask_image_texture.set_image(mask_image)
		drawing_texture.texture = mask_image_texture

		map_image = Image.new()
		map_image.load_png_from_buffer(reader.read_file("map.png"))
		map_image.convert(Image.FORMAT_RGB8)

		reader.close()

	else:
		map_image = Image.new()
		map_image.load(path)
		map_image.convert(Image.FORMAT_RGB8)

		var map_image_width: int = map_image.get_size()[0]
		var map_image_height: int = map_image.get_size()[1]

		if map_image_width > MAX_IMAGE_SIZE or map_image_height > MAX_IMAGE_SIZE:
			var ratio: float
			if map_image_width > map_image_height:
				ratio = MAX_IMAGE_SIZE / map_image_width
			else:
				ratio = MAX_IMAGE_SIZE / map_image_height

			map_image.resize(
				map_image_width * ratio,
				map_image_height * ratio,
				Image.Interpolation.INTERPOLATE_CUBIC
			)

		get_fog_size(map_image.get_size())

		mask_image = Image.create(fog_image_width, fog_image_width, false, Image.FORMAT_R8)
		mask_image.fill(Color.RED)

		mask_image_texture = ImageTexture.create_from_image(mask_image)
		drawing_texture.texture = mask_image_texture

	current_file_path = path

	get_fog_size(map_image.get_size())

	undo_list.append(["just_drew", mask_image_texture])

	drawing_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE

	dm_fog.visible = true
	player_fog.visible = true
	dm_fog.size = Vector2(fog_image_width, fog_image_height)
	player_fog.size = Vector2(fog_image_width, fog_image_height)
	drawing_viewport.size = Vector2(fog_image_width, fog_image_height)

	dm_fog.material.set_shader_parameter("mask_texture", drawing_viewport.get_texture())
	player_fog.material.set_shader_parameter("mask_texture", drawing_viewport.get_texture())

	dm_camera.position = Vector2(fog_image_width * 0.5, fog_image_height * 0.5)
	player_camera.position = Vector2(fog_image_width * 0.5, fog_image_height * 0.5)

	player_view.visible = true
	player_view_text.visible = true

	move_background(player_root)
	move_background(dm_root)

	var image_texture: Texture2D = ImageTexture.new()
	image_texture.set_image(map_image)
	dm_background.texture = image_texture
	player_background.texture = image_texture

	if is_instance_valid(text):
		text.queue_free()
	if is_instance_valid(info_degus):
		info_degus.queue_free()
	if is_instance_valid(player_text):
		player_text.queue_free()


func wait_one_frame_and_then_copy() -> void:
	await RenderingServer.frame_post_draw
	copy_viewport_texture()


func are_we_inside_sidebar() -> void:
	if m1_held or m2_held:
		return
	else:
		in_sidebar = true


func select_tool(index: int) -> void:
	tool_index = index
	tool_changed.emit(index)
	update_tool_visuals()

	if tool_index == tool.SQUARE_BRUSH:
		tool_label.text = "Square brush"
	elif tool_index == tool.ROUND_BRUSH:
		tool_label.text = "Round brush"
	elif tool_index == tool.SELECTOR:
		tool_label.text = "Selector"
	elif tool_index == tool.TOKEN_PLACER:
		tool_label.text = "Token"


func move_background(background_node: Node2D) -> void:
	var map_image_width: int = map_image.get_size()[0]
	var map_image_height: int = map_image.get_size()[1]

	var x_diff: float = fog_image_width - map_image_width
	var y_diff: float = fog_image_height - map_image_height

	background_node.position.x = x_diff / 2
	background_node.position.y = y_diff / 2


func write_map(path: String) -> void:
	if not path.ends_with(".map"):
		warning.title = "Invalid file format"
		warning.dialog_text = "File must be .map"
		warning.popup_centered()
		return

	var writer: ZIPPacker = ZIPPacker.new()
	var error := writer.open(path)

	if error != OK:
		warning.title = "Error"
		warning.dialog_text = "Error writing map"
		warning.popup_centered()
		return

	current_file_path = path

	writer.start_file("mask.png")
	writer.write_file(drawing_viewport.get_texture().get_image().save_png_to_buffer())
	writer.start_file("map.png")
	writer.write_file(map_image.save_png_to_buffer())
	writer.close_file()

	writer.close()


func _on_help_id_pressed(id: int) -> void:
	if id == 0:
		warning.title = "Keybindings"
		warning.dialog_text = "General\n    Left click: Reveal areas\n    Right click: Hide areas\n    Middle mouse: Pan view\n    WASD/Arrow keys: Move view\n    Mouse wheel: Zoom\n    Ctrl+S: Save\n    Ctrl+Z: Undo\nExtra keybinds\n    Ctrl+Mouse wheel: Resize brush\n    Space: Change brush type\n    T: Toggle between fog themes\n    L: Load a map"
		warning.popup_centered()


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
		get_tree().quit()


func update_colorscheme(id: int) -> void:
	if current_file_path == "":
		return
	fog_color_index = id
	update_fog_texture(FOG_COLOR_LIST[fog_color_index])
	colorscheme_menu.set_item_checked(id, true)

	for i in range(len(FOG_COLOR_LIST)):
		colorscheme_menu.set_item_checked(i, i == id)
