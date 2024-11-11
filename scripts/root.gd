extends Control

@onready var menu_bar: MenuBar = $GUI/MenuBar
@onready var file_menu: PopupMenu = $GUI/MenuBar/File
@onready var settings_menu: PopupMenu = $GUI/MenuBar/Settings
@onready var saving_label : Label = $GUI/SavingLabel
@onready var colorscheme_menu: PopupMenu = $GUI/MenuBar/Colorscheme
@onready var load_dialog: FileDialog = $LoadDialog
@onready var save_dialog: FileDialog = $SaveDialog
@onready var warning: AcceptDialog = $Warning
@onready var cursor_node : Node2D = $CursorNode
@onready var cursor_texture : TextureRect = $CursorNode/TextureRect
@onready var sidebar : PanelContainer = $GUI/PanelContainer

@onready var scrollbar : VScrollBar = $GUI/PanelContainer/VBoxContainer/VScrollBar
@onready var button : Button = $GUI/PanelContainer/VBoxContainer/Button

@onready var drawing_viewport : SubViewport = $DrawingViewport
@onready var drawing_node : Node2D = $DrawingViewport/DrawingNode
@onready var drawing_texture = $DrawingViewport/DrawingTexture

@onready var dm_camera: Camera2D = $Camera
@onready var dm_fog = $DmFog
@onready var dm_root = $DmRoot
@onready var dm_background = $DmRoot/Background

@onready var player_window: Window = $PlayerWindow
@onready var player_camera: Camera2D = $PlayerWindow/Camera
@onready var player_fog = $PlayerWindow/PlayerFog
@onready var player_root = $PlayerWindow/PlayerRoot
@onready var player_background = $PlayerWindow/PlayerRoot/Background

const PerlinTexture = preload('res://resources/Fog.jpg')
const PlasmaTexture = preload('res://resources/Plasma.jpg')

const BlackIndicatorTexture = preload('res://resources/BlackIndicator.png')
const WhiteIndicatorTexture = preload('res://resources/WhiteIndicator.png')
const BlackSquareIndicatorTexture = preload('res://resources/BlackSquareIndicator.png')
const WhiteSquareIndicatorTexture = preload('res://resources/WhiteSquareIndicator.png')

const CircleIcon = preload('res://resources/CircleIcon.png')
const SquareIcon = preload('res://resources/SquareIcon.png')


var should_draw_square : bool = false
var current_file_path : String

signal square_signal(boolean)

var fog_scaling : float = 1.2

var mask_image_texture

var hovering_over_gui : bool = false
var black_circle_bool : bool = false
var performance_mode : bool = false

var brush_size : int = 50

var map_image : Image

var fog_image_height : int
var fog_image_width : int

var mask_image : Image
var mask_texture : ImageTexture

var light_brush : Image
var dark_brush : Image

var shift_held : bool = false
var ctrl_held : bool = false
var m1_held : bool = false
var m2_held : bool = false

var undo_list : Array = []

signal m1(pressed)
signal m2(pressed)
signal mouse_pos_signal(position)
signal brush_size_changed(size)
signal pretend_to_draw

const FOG_COLOR_LIST : Array = [
    "fog",
    "colorful_fog",
    Color.BLACK,
    Color.WHITE,
    Color.DARK_GRAY,
    Color.FUCHSIA,
    Color.BLUE,
    Color.LIME,
]

var fog_color_index : int = 0

const UNDO_LIST_MAX_SIZE : int = 10


func _ready() -> void:
    get_window().title = "DM Window"

    load_dialog.connect("file_selected", func(path): load_map(path))
    save_dialog.connect("file_selected", func(path): write_map(path))
    scrollbar.connect('value_changed', on_scrollbar_value_changed)

    file_menu.connect('id_pressed', _on_file_id_pressed)
    settings_menu.connect('id_pressed', _on_settings_id_pressed)
    colorscheme_menu.connect('id_pressed', update_colorscheme)

    button.connect('pressed', on_button_pressed)


    var gui_list = [menu_bar, file_menu, settings_menu,  colorscheme_menu, sidebar, scrollbar, button]
    for i in range(len(gui_list)):
        gui_list[i].connect("mouse_entered", func(): hovering_over_gui = true)
        gui_list[i].connect("mouse_exited", func(): hovering_over_gui = false)

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

func on_button_pressed():
    should_draw_square = not should_draw_square
    square_signal.emit(should_draw_square)
    set_cursor_texture()
    if should_draw_square:
        button.icon = SquareIcon
    else:
        button.icon = CircleIcon


func on_scrollbar_value_changed(value: float):
    brush_size = value
    cursor_texture.size = Vector2(brush_size, brush_size)
    brush_size_changed.emit(brush_size)


func update_brushes(value: int = 0) -> void:
    brush_size = max(5, brush_size + value)
    cursor_texture.size = Vector2(brush_size, brush_size)
    brush_size_changed.emit(brush_size)

func _process(_delta):
    cursor_node.position = get_global_mouse_position() - Vector2.ONE * brush_size / 2

func _input(event: InputEvent) -> void:
    if current_file_path == "":
        return

    if event is InputEventKey:
        if event.keycode == KEY_SHIFT:
            shift_held = event.pressed
        if event.keycode == KEY_CTRL:
            ctrl_held = event.pressed

        # schmoovement

        # if event.keycode == KEY_J:
        # 	m1_held = event.pressed
        # 	m1.emit(event.pressed)
        # 	drawing_texture.visible = false
        #
        # 	if event.pressed == false:
        # 		copy_viewport_texture()
        #
        # if event.keycode == KEY_L:
        # 	m2_held = event.pressed
        # 	m2.emit(event.pressed)
        # 	drawing_texture.visible = false
        #
        # 	if event.pressed == false:
        # 		copy_viewport_texture()

        if event.pressed:
            if event.keycode == KEY_Q:
                get_tree().quit()


            if event.keycode == KEY_Z:
                if len(undo_list) > 1:
                    undo_list.pop_back()

                drawing_texture.texture = undo_list[-1]
                drawing_texture.visible = true
                dm_fog.material.set_shader_parameter('mask_texture', undo_list[-1])
                player_fog.material.set_shader_parameter('mask_texture', undo_list[-1])

                pretend_to_draw.emit()

                drawing_texture.texture = undo_list[-1]
                drawing_texture.visible = true
                dm_fog.material.set_shader_parameter('mask_texture', drawing_viewport.get_texture())
                player_fog.material.set_shader_parameter('mask_texture', drawing_viewport.get_texture())

            if event.keycode == KEY_C:
                black_circle_bool = not black_circle_bool
                settings_menu.set_item_checked(0, black_circle_bool)
                set_cursor_texture()

            if event.keycode == KEY_SPACE:
                should_draw_square = not should_draw_square
                settings_menu.set_item_checked(1, should_draw_square)
                square_signal.emit(should_draw_square)
                set_cursor_texture()



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

            if event.keycode == KEY_S:
                if ctrl_held:
                    if current_file_path != "":
                        if current_file_path.ends_with('.map'):
                            saving_label.visible = true
                            await get_tree().process_frame
                            await get_tree().process_frame
                            write_map(current_file_path)
                            saving_label.visible = false
                        else:
                            save_dialog.popup()


            # if event.keycode == KEY_K:
            # 	update_brushes(-5)
            # if event.keycode == KEY_I:
            # 	update_brushes(5)

    if event is InputEventMouseButton:
        if hovering_over_gui:
            return

        if event.button_index == MOUSE_BUTTON_LEFT:
            m1_held = event.pressed
            m1.emit(event.pressed)
            drawing_texture.visible = false

            if event.pressed == false:
                copy_viewport_texture()

        if event.button_index == MOUSE_BUTTON_RIGHT:
            m2_held = event.pressed
            m2.emit(event.pressed)
            drawing_texture.visible = false

            if event.pressed == false:
                copy_viewport_texture()


        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            if shift_held:
                update_brushes(-5)

        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if shift_held:
                update_brushes(5)

    elif event is InputEventMouseMotion:
        if m1_held or m2_held:
            drawing_texture.visible = false
        mouse_pos_signal.emit(get_global_mouse_position())

func set_cursor_texture() -> void:
    if should_draw_square:
        if black_circle_bool:
            cursor_texture.texture = BlackSquareIndicatorTexture
        else:
            cursor_texture.texture = WhiteSquareIndicatorTexture
    else:
        if black_circle_bool:
            cursor_texture.texture = BlackIndicatorTexture
        else:
            cursor_texture.texture = WhiteIndicatorTexture


func copy_viewport_texture() -> void:
    var image = drawing_viewport.get_texture().get_image()
    image.convert(Image.FORMAT_R8)
    var image_texture = ImageTexture.new()
    image_texture = ImageTexture.create_from_image(image)
    undo_list.append(image_texture)

    if len(undo_list) > UNDO_LIST_MAX_SIZE:
        undo_list.pop_front()

func temp():
    var writer = ZIPPacker.new()
    writer.open('/home/jona/masks/masks.zip')

    for i in range(len(undo_list)):
        writer.start_file("%s.png" % i)
        writer.write_file(undo_list[i].get_image().save_png_to_buffer())
    writer.close_file()

    writer.close()



func update_fog_texture(color):
    var fog_image_texture
    if color is String:
        if color == "fog":
            fog_image_texture = PerlinTexture
        elif color == "colorful_fog":
            fog_image_texture = PlasmaTexture
        RenderingServer.set_default_clear_color(Color.WHITE)

    else:
        var fog_image = Image.create(fog_image_width, fog_image_height, false, Image.FORMAT_RGBA8)
        fog_image.fill(color)
        fog_image_texture = ImageTexture.create_from_image(fog_image)
        RenderingServer.set_default_clear_color(color)

    player_fog.texture = fog_image_texture
    dm_fog.texture = fog_image_texture

func get_fog_size(image_size):
    if image_size[0] > image_size[1]:
        fog_image_width = image_size[0] * fog_scaling
        fog_image_height = image_size[0] * fog_scaling
    else:
        fog_image_width = image_size[1] * fog_scaling
        fog_image_height = image_size[1] * fog_scaling


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
        get_fog_size(map_image.get_size())

        mask_image = Image.create(fog_image_width, fog_image_width, false, Image.FORMAT_R8)
        mask_image.fill(Color.RED)

        mask_image_texture = ImageTexture.create_from_image(mask_image)
        drawing_texture.texture = mask_image_texture

    get_fog_size(map_image.get_size())

    undo_list.append(mask_image_texture)

    drawing_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE

    dm_fog.visible = true
    player_fog.visible = true
    dm_fog.size = Vector2(fog_image_width, fog_image_height)
    player_fog.size = Vector2(fog_image_width, fog_image_height)
    drawing_viewport.size = Vector2(fog_image_width, fog_image_height)

    dm_fog.material.set_shader_parameter('mask_texture', drawing_viewport.get_texture())
    player_fog.material.set_shader_parameter('mask_texture', drawing_viewport.get_texture())

    dm_camera.position = Vector2(fog_image_width * 0.5, fog_image_height * 0.5)
    player_camera.position = Vector2(fog_image_width * 0.5, fog_image_height * 0.5)

    move_background(player_root)
    move_background(dm_root)

    var image_texture = ImageTexture.new()
    image_texture.set_image(map_image)
    dm_background.texture = image_texture
    player_background.texture = image_texture

func move_background(background_node: Node2D):
    var map_image_width = map_image.get_size()[0]
    var map_image_height = map_image.get_size()[1]

    var x_diff = fog_image_width - map_image_width
    var y_diff = fog_image_height - map_image_height

    background_node.position.x += x_diff / 2
    background_node.position.y += y_diff / 2


func write_map(path: String) -> void:
    var writer = ZIPPacker.new()
    writer.open(path)
    writer.start_file("mask.png")
    writer.write_file(drawing_viewport.get_texture().get_image().save_png_to_buffer())
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
        warning.dialog_text = "General\n    Left click: Reveal areas\n    Right click: Hide areas\n    Middle mouse: Pan view\n    WASD/Arrow keys: Move view\n    Mouse wheel: Zoom\n    Shift+Mouse wheel: Resize brush\n    Ctrl+S: Save\n    Ctrl+Z: Undo\nExtra keybinds\n    Space: Change brush type\n    C: Change color of size indicator\n    T: Toggle between fog themes\n    P: Limit FPS"
        warning.popup_centered()

    if id == 3:
        get_tree().quit()

func _on_settings_id_pressed(id: int) -> void:
    if id == 0:
        black_circle_bool = not black_circle_bool
        settings_menu.set_item_checked(id, black_circle_bool)
        set_cursor_texture()

    if id == 1:
        should_draw_square = not should_draw_square
        square_signal.emit(should_draw_square)
        settings_menu.set_item_checked(id, should_draw_square)
        set_cursor_texture()

    if id == 2:
        performance_mode = not performance_mode
        if performance_mode:
            Engine.max_fps = 30
        else:
            Engine.max_fps = 60
        settings_menu.set_item_checked(id, performance_mode)

func update_colorscheme(id: int) -> void:
    if current_file_path == "":
        return
    fog_color_index = id
    update_fog_texture(FOG_COLOR_LIST[fog_color_index])
    colorscheme_menu.set_item_checked(id, true)

    for i in range(len(FOG_COLOR_LIST)):
        colorscheme_menu.set_item_checked(i, i == id)
