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
const InfoDegus = preload("res://resources/Info.png")
const PlayerInfoDegus = preload("res://resources/PlayerInfo.png")

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

const TOKEN_COLOR_LIST: Array = [
	[Color.RED, Color.DARK_RED],
	[Color.BLUE, Color.DARK_BLUE],
	[Color.GREEN, Color.DARK_GREEN],
	[Color.YELLOW, Color.DARK_ORANGE],
]


const DRAWING_LIST_MAX_SIZE: int = 15

var current_tool: int = 0
var fog_color_index: int = 0
var token_color_index: int = 0
var brush_size: int = 50
var fog_image_height: int
var fog_image_width: int

var last_brush_size: int = 50
var last_token_size: int = 50

var ctrl_held := false
var m1_held := false
var m2_held := false
var selecting := false
var hovering_over_gui := false
var performance_mode := false
var in_sidebar := false

var drawing_list: Array = []
var undo_list: Array = []
var corner_list: Array = []

var selector_start_pos := Vector2.ZERO
var selector_end_pos := Vector2.ZERO

var all_placed_tokens: Array[Dictionary] = []

var current_file_path: String

var fog_scaling: float = 1.2

var mask_image_texture: Texture2D

var mask_texture: ImageTexture

var map_image: Image
var mask_image: Image
var light_brush: Image
var dark_brush: Image

var hovered_tokens: Dictionary[String, Panel] = {}
var held_tokens: Dictionary[String, Panel] = {}

var stylebox_button_pressed: StyleBox
var stylebox_button_not_pressed: StyleBox
var stylebox_cursor_normal: StyleBox


@onready var menu_bar: MenuBar = $GUI/MenuBar
@onready var file_menu: PopupMenu = $GUI/MenuBar/File
@onready var help_menu: PopupMenu = $GUI/MenuBar/Help
@onready var saving_label: Label = $GUI/SavingLabel
@onready var colorscheme_menu: PopupMenu = $GUI/MenuBar/Colorscheme
@onready var tool_sidebar: PanelContainer = $GUI/ToolContainer
@onready var scroll_sidebar: PanelContainer = $GUI/ScrollBarContainer

@onready var scrollbar: VScrollBar = $GUI/ScrollBarContainer/VBoxContainer/VScrollBar
@onready var scrollbar_label: Label = $GUI/ScrollBarContainer/VBoxContainer/Label
@onready var square_brush_button: Button = $GUI/ToolContainer/VBoxContainer/SquareBrushButton
@onready var circle_brush_button: Button = $GUI/ToolContainer/VBoxContainer/CircleBrushButton
@onready var selector_button: Button = $GUI/ToolContainer/VBoxContainer/SelectorButton
@onready var token_button: Button = $GUI/ToolContainer/VBoxContainer/TokenButton

# @onready var separator : HSeparator = $GUI/ToolContainer/VBoxContainer/Separator
@onready var tool_label: Label = $GUI/ToolContainer/VBoxContainer/ToolLabel

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
	scrollbar.connect("value_changed", update_brush_size)


	# player_camera.connect("on_mouse_pos_changed", func(_pos: Vector2) -> void: move_player_view())
	# dm_camera.connect("on_mouse_pos_changed", func(pos: Vector2) -> void: update_cursor_position())

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
	token_button.connect("mouse_exited", token_button.release_focus)

	stylebox_button_pressed = selector_button.get_theme_stylebox("normal").duplicate()
	stylebox_button_pressed.border_width_left = 2
	stylebox_button_pressed.border_width_right = 2
	stylebox_button_pressed.border_width_top = 2
	stylebox_button_pressed.border_width_bottom = 2

	stylebox_button_not_pressed = selector_button.get_theme_stylebox("normal").duplicate()
	stylebox_button_not_pressed.border_width_left = 0
	stylebox_button_not_pressed.border_width_right = 0
	stylebox_button_not_pressed.border_width_top = 0
	stylebox_button_not_pressed.border_width_bottom = 0

	stylebox_cursor_normal = cursor_panel.get_theme_stylebox("panel").duplicate()
	stylebox_cursor_normal.corner_radius_top_left = 3
	stylebox_cursor_normal.corner_radius_top_right = 3
	stylebox_cursor_normal.corner_radius_bottom_left = 3
	stylebox_cursor_normal.corner_radius_bottom_right = 3
	stylebox_cursor_normal.bg_color = Color.TRANSPARENT
	stylebox_cursor_normal.border_color = Color.BLACK

	scrollbar.set_value_no_signal(brush_size)

	drawing_node.connect("on_finished_drawing", wait_one_frame_and_then_copy)

	update_tool_visuals()
	select_tool(tool.SQUARE_BRUSH)

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
	update_brush_size(brush_size)

	cursor_panel.size = Vector2(brush_size, brush_size)

	var args: Array = OS.get_cmdline_args()

	if len(args) > 0:
		load_map(args[0])
	else:
		load_map("noargs")

func update_cursor_position() -> void:
	if current_tool != tool.SELECTOR:
		if in_sidebar:
			cursor_node.position = dm_camera.position - Vector2.ONE * brush_size / 2
		else:
			cursor_node.position = get_global_mouse_position() - Vector2.ONE * brush_size / 2
	else:
		reshape_selector_cursor_panel()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_L:
				load_dialog.popup()

	update_cursor_position()

	if event is InputEventKey:
		process_keypresses(event)

	if event is InputEventMouseButton:
		on_mouse_pos_changed.emit(get_global_mouse_position())

		# dont process clicks when over gui, but process releases
		if hovering_over_gui and event.pressed:
			return

		match current_tool:
			tool.TOKEN_PLACER:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.pressed:
						if hovered_tokens.is_empty():
							var tokens: Dictionary[String, Panel] = make_token()
							undo_list.append(["place_token", {'tokens': tokens}])
						else:
							undo_list.append(["move_token", {'tokens': hovered_tokens, 'position': hovered_tokens['dm'].position}])
							held_tokens = hovered_tokens
					else:
						held_tokens = {}

				if event.button_index == MOUSE_BUTTON_RIGHT:
					if not hovered_tokens.is_empty():
						var dm_token : Panel = hovered_tokens['dm']
						var player_token : Panel = hovered_tokens['player']
						dm_token.visible = false
						player_token.visible = false
						undo_list.append(["remove_token", {'tokens': {'dm': dm_token, 'player': player_token}}])

						hovered_tokens = {}

			tool.SELECTOR:
				if (
					event.button_index == MOUSE_BUTTON_LEFT
					or event.button_index == MOUSE_BUTTON_RIGHT
				):
					if event.pressed:
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
					reshape_selector_cursor_panel()

			_:
				if event.button_index == MOUSE_BUTTON_LEFT:
					drawing_texture.visible = false

					if event.pressed == false and m1_held:
						copy_viewport_texture()
					m1_held = event.pressed
					on_m1_pressed.emit(event.pressed)

				if event.button_index == MOUSE_BUTTON_RIGHT:
					drawing_texture.visible = false

					if event.pressed == false and m2_held:
						copy_viewport_texture()

					m2_held = event.pressed
					on_m2_pressed.emit(event.pressed)

		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					set_cursor_shape(CursorShape.CURSOR_DRAG)
				else:
					update_tool_visuals()

			MOUSE_BUTTON_WHEEL_UP:
				if ctrl_held:
					update_brush_size(min(max(BRUSH_SIZE_MIN, brush_size - 5), BRUSH_SIZE_MAX))
					scrollbar.set_value_no_signal(brush_size)

			MOUSE_BUTTON_WHEEL_DOWN:
				if ctrl_held:
					update_brush_size(min(max(BRUSH_SIZE_MIN, brush_size + 5), BRUSH_SIZE_MAX))
					scrollbar.set_value_no_signal(brush_size)

	elif event is InputEventMouseMotion:
		on_mouse_pos_changed.emit(get_global_mouse_position())

		if m1_held or m2_held:
			drawing_texture.visible = false

		if not held_tokens.is_empty():
			held_tokens['dm'].position = get_global_mouse_position() - Vector2.ONE * held_tokens['dm'].size / 2
			held_tokens['player'].position = get_global_mouse_position() - Vector2.ONE * held_tokens['player'].size / 2

		if current_tool == tool.TOKEN_PLACER:
			if hovered_tokens.is_empty():
				cursor_node.visible = true
				set_cursor_shape(CursorShape.CURSOR_POINTING_HAND)
			else:
				cursor_node.visible = false
				set_cursor_shape(CursorShape.CURSOR_MOVE)


func process_keypresses(event: InputEventKey) -> void:
	if event.keycode == KEY_CTRL:
		ctrl_held = event.pressed

	if event.pressed:
		if not hovered_tokens.is_empty() and event.keycode in range(KEY_0, KEY_9 + 1):
			var previous_number: String = hovered_tokens['dm'].get_child(0).text
			undo_list.append(['change_number', {'tokens': hovered_tokens, 'number': previous_number}])
			var number := str(event.keycode - KEY_0)
			hovered_tokens['dm'].get_child(0).text = number
			hovered_tokens['player'].get_child(0).text = number
			return

		match event.keycode:
			KEY_1:
				select_tool(tool.SQUARE_BRUSH)

			KEY_2:
				select_tool(tool.ROUND_BRUSH)

			KEY_3:
				select_tool(tool.SELECTOR)

			KEY_4:
				select_tool(tool.TOKEN_PLACER)

			KEY_C:
				token_color_index = (token_color_index + 1) % len(TOKEN_COLOR_LIST)
				print(TOKEN_COLOR_LIST[token_color_index])
				update_tool_visuals()

			KEY_Z:
				undo()

			KEY_SPACE:
				select_tool((current_tool + 1) % tool.LENGTH)

			KEY_T:
				var id: int = (fog_color_index + 1) % len(FOG_COLOR_LIST)
				update_colorscheme(id)

			KEY_P:
				performance_mode = not performance_mode
				if performance_mode:
					Engine.max_fps = 30
				else:
					Engine.max_fps = 60

			KEY_S:
				if ctrl_held:
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

			KEY_K:
				for tokens in all_placed_tokens:
					if is_instance_valid(tokens['tokens']['dm']):
						tokens[0]['dm'].visible = true
						tokens[0]['player'].visible = true


func undo() -> void:
	print(undo_list)
	if undo_list.is_empty():
		return

	var last: Array = undo_list.pop_back()

	var action: String = last[0]
	var payload: Variant = last[1]

	match action:
		"draw":
			if len(drawing_list) > 1:
				drawing_list.pop_back()

			drawing_texture.texture = drawing_list[-1]
			drawing_texture.visible = true
			dm_fog.material.set_shader_parameter("mask_texture", payload)
			player_fog.material.set_shader_parameter("mask_texture", payload)

			pretend_to_draw.emit()

			drawing_texture.texture = drawing_list[-1]
			drawing_texture.visible = true
			dm_fog.material.set_shader_parameter("mask_texture", drawing_viewport.get_texture())
			player_fog.material.set_shader_parameter("mask_texture", drawing_viewport.get_texture())

		"place_token":
			if not is_instance_valid(payload['tokens']['dm']):
				undo()
			else:
				payload['tokens']['dm'].queue_free()
				payload['tokens']['player'].queue_free()

		"remove_token":
			payload['tokens']['dm'].visible = true
			payload['tokens']['player'].visible = true

		"move_token":
			payload['tokens']['dm'].position = payload['position']
			payload['tokens']['player'].position = payload['position']

		"change_number":
			payload['tokens']['dm'].get_child(0).text = payload['number']
			payload['tokens']['player'].get_child(0).text = payload['number']


func make_token(pos: Vector2 = Vector2.INF) -> Dictionary[String, Panel]:
	var token_dict: Dictionary[String, Panel] = {}

	var token_pos : Vector2
	if pos == Vector2.INF:
		token_pos = get_global_mouse_position() - Vector2.ONE * brush_size / 2
	else:
		token_pos = pos
		

	for i in range(2):
		var token := Panel.new()

		var label := Label.new()


		label.text = "1"
		label.set("theme_override_font_sizes/font_size", brush_size / 2)
		label.size = Vector2(brush_size, brush_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		token.add_child(label)

		token.size = Vector2(brush_size, brush_size)
		token.position = token_pos
		token.z_index = -1

		var stylebox_cursor: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
		stylebox_cursor.corner_radius_top_left = brush_size / 2 - 1
		stylebox_cursor.corner_radius_top_right = brush_size / 2 - 1
		stylebox_cursor.corner_radius_bottom_left = brush_size / 2 - 1
		stylebox_cursor.corner_radius_bottom_right = brush_size / 2 - 1
		stylebox_cursor.corner_detail = 32
		stylebox_cursor.bg_color = TOKEN_COLOR_LIST[token_color_index][0]
		stylebox_cursor.border_color = TOKEN_COLOR_LIST[token_color_index][1]
		token.add_theme_stylebox_override("panel", stylebox_cursor)

		token.mouse_default_cursor_shape = CursorShape.CURSOR_MOVE

		if i == 0:
			add_child(token)
			token_dict['dm'] = token
		else:
			player_window.add_child(token)
			token_dict['player'] = token


	token_dict['dm'].tooltip_text = "Hold left mouse to drag this token, press left mouse to delete"
	token_dict['dm'].connect("mouse_entered", func() -> void: hovered_tokens = token_dict)
	token_dict['dm'].connect("mouse_exited", func() -> void: hovered_tokens = {})

	all_placed_tokens.append({'tokens': token_dict, 'color_id': token_color_index})
	print(all_placed_tokens)
	print(len(all_placed_tokens))

	return token_dict


func update_brush_size(value: float) -> void:
	brush_size = int(value)
	brush_size_changed.emit(brush_size)

	scrollbar_label.text = str(int(value))

	if current_tool == tool.TOKEN_PLACER:
		last_token_size = brush_size
	else:
		last_brush_size = brush_size

	cursor_panel.size = Vector2(brush_size, brush_size)
	update_tool_visuals()

func set_cursor_shape(shape: CursorShape = CursorShape.CURSOR_ARROW) -> void:
	mouse_default_cursor_shape = shape
	cursor_panel.mouse_default_cursor_shape = shape
	player_view.mouse_default_cursor_shape = shape
	player_view_text.mouse_default_cursor_shape = shape


func move_player_view() -> void:
	var view_size: Vector2 = player_window.get_visible_rect().size
	var view_transform: Transform2D = player_window.get_canvas_transform()

	player_view.position = view_transform.origin / -view_transform.x[0]
	player_view.size = view_size / view_transform.x[0]


func reshape_selector_cursor_panel() -> void:
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
	var button_list: Array = [
		square_brush_button, circle_brush_button, selector_button, token_button
	]

	# make all buttons unpressed
	for i in range(len(button_list)):
		button_list[i].add_theme_stylebox_override("normal", stylebox_button_not_pressed)

	scroll_sidebar.visible = true
	cursor_panel.visible = true

	scrollbar.set_value_no_signal(last_brush_size)
	brush_size = last_brush_size
	brush_size_changed.emit(brush_size)
	scrollbar_label.text = str(int(brush_size))

	match current_tool:
		tool.SQUARE_BRUSH:
			set_cursor_shape(CursorShape.CURSOR_CROSS)
			cursor_panel.add_theme_stylebox_override("panel", stylebox_cursor_normal)


			square_brush_button.add_theme_stylebox_override("normal", stylebox_button_pressed)
			tool_label.text = "Square brush"

		tool.ROUND_BRUSH:
			var stylebox_cursor: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
			set_cursor_shape(CursorShape.CURSOR_CROSS)
			stylebox_cursor = update_circular_stylebox(stylebox_cursor)
			stylebox_cursor.bg_color = Color.TRANSPARENT
			stylebox_cursor.border_color = Color.BLACK
			cursor_panel.add_theme_stylebox_override("panel", stylebox_cursor)

			circle_brush_button.add_theme_stylebox_override("normal", stylebox_button_pressed)
			tool_label.text = "Round Brush"

		tool.SELECTOR:
			set_cursor_shape()
			cursor_panel.add_theme_stylebox_override("panel", stylebox_cursor_normal)
			scroll_sidebar.visible = false

			selector_button.add_theme_stylebox_override("normal", stylebox_button_pressed)
			reshape_selector_cursor_panel()
			tool_label.text = "Selector"

		tool.TOKEN_PLACER:
			var stylebox_cursor: StyleBox = cursor_panel.get_theme_stylebox("panel").duplicate()
			set_cursor_shape(CursorShape.CURSOR_POINTING_HAND)

			scrollbar.set_value_no_signal(last_token_size)
			brush_size = last_token_size
			scrollbar_label.text = str(int(brush_size))

			stylebox_cursor = update_circular_stylebox(stylebox_cursor)
			stylebox_cursor.bg_color = TOKEN_COLOR_LIST[token_color_index][0]
			stylebox_cursor.border_color = TOKEN_COLOR_LIST[token_color_index][1]
			cursor_panel.add_theme_stylebox_override("panel", stylebox_cursor)

			token_button.add_theme_stylebox_override("normal", stylebox_button_pressed)

			tool_label.text = "Token"

	cursor_panel.size = Vector2(brush_size, brush_size)

	if current_tool != tool.SELECTOR:
		if in_sidebar:
			cursor_node.position = dm_camera.position - Vector2.ONE * brush_size / 2
		else:
			cursor_node.position = get_global_mouse_position() - Vector2.ONE * brush_size / 2

func update_circular_stylebox(stylebox: StyleBox) -> StyleBox:
	stylebox.corner_detail = 32
	stylebox.corner_radius_top_left = brush_size / 2 - 1
	stylebox.corner_radius_top_right = brush_size / 2 - 1
	stylebox.corner_radius_bottom_left = brush_size / 2 - 1
	stylebox.corner_radius_bottom_right = brush_size / 2 - 1

	return stylebox

func copy_viewport_texture() -> void:
	var image: Image = drawing_viewport.get_texture().get_image()
	image.convert(Image.FORMAT_R8)
	var image_texture: Texture2D = ImageTexture.new()
	image_texture = ImageTexture.create_from_image(image)
	drawing_list.append(image_texture)
	undo_list.append(["draw", null])

	if len(drawing_list) > DRAWING_LIST_MAX_SIZE:
		drawing_list.pop_front()


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
	drawing_list = []

	for dictionary in all_placed_tokens:
		if is_instance_valid(dictionary['tokens']['dm']):
			dictionary['tokens']['dm'].queue_free()
			dictionary['tokens']['player'].queue_free()

	all_placed_tokens = []
	print(undo_list)

	if path == "noargs":
		get_fog_size(InfoDegus.get_size())
		mask_image = Image.create(fog_image_width, fog_image_width, false, Image.FORMAT_R8)
		mask_image.fill(Color.RED)

		mask_image_texture = ImageTexture.create_from_image(mask_image)
		drawing_texture.texture = mask_image_texture

		
		dm_background.texture = InfoDegus
		player_background.texture = PlayerInfoDegus

		dm_fog.material.set_shader_parameter("alpha_ceil", 0.2)
		player_fog.material.set_shader_parameter("alpha_ceil", 0.3)

	else:
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
				warning.dialog_text = "Error loading .map file. Error code: %s" % error
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
			var error := map_image.load(path)

			if error != OK:
				warning.title = "Error"
				if error == ERR_FILE_NOT_FOUND:
					warning.dialog_text = "File not found"
				else:
					warning.dialog_text = "Error loading image. Error code: %s" % error
				warning.popup_centered()
				return

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


			mask_image = Image.create(fog_image_width, fog_image_width, false, Image.FORMAT_R8)
			mask_image.fill(Color.RED)

			mask_image_texture = ImageTexture.create_from_image(mask_image)
			drawing_texture.texture = mask_image_texture

		get_fog_size(map_image.get_size())
		var image_texture: Texture2D = ImageTexture.new()
		image_texture.set_image(map_image)
		dm_background.texture = image_texture
		player_background.texture = image_texture

		player_view.visible = true
		player_view_text.visible = true
		current_file_path = path

		dm_fog.material.set_shader_parameter("alpha_ceil", 0.5)
		player_fog.material.set_shader_parameter("alpha_ceil", 1)


	print(drawing_list)
	drawing_list.append(mask_image_texture)

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


	move_background(player_root)
	move_background(dm_root)
	move_player_view()

	# reuse undo function to just force a redraw from the mask we just loaded
	undo_list = [['draw', null]]
	undo()


func wait_one_frame_and_then_copy() -> void:
	await RenderingServer.frame_post_draw
	copy_viewport_texture()


func are_we_inside_sidebar() -> void:
	if m1_held or m2_held:
		return
	else:
		in_sidebar = true


func select_tool(index: int) -> void:
	current_tool = index
	tool_changed.emit(index)
	update_tool_visuals()


func _process(_delta: float) -> void:
	move_player_view()
	update_cursor_position()



func move_background(background_node: Node2D) -> void:
	var map_image_width: int
	var map_image_height: int
	if map_image != null:
		map_image_width = map_image.get_size()[0]
		map_image_height = map_image.get_size()[1]
	else:
		map_image_width = int(InfoDegus.get_size()[0])
		map_image_height = int(InfoDegus.get_size()[1])

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
	fog_color_index = id
	update_fog_texture(FOG_COLOR_LIST[fog_color_index])
	colorscheme_menu.set_item_checked(id, true)

	for i in range(len(FOG_COLOR_LIST)):
		colorscheme_menu.set_item_checked(i, i == id)
