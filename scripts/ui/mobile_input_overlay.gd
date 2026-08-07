extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")

var _movement: Control
var _camera: Control
var _buttons: Array[Button] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30

    _movement = VirtualJoystickScript.new()
    _movement.name = "MovementJoystickInput"
    _movement.mode = "movement"
    _movement.draw_visuals = true
    _movement.size = Vector2(190, 190)
    add_child(_movement)

    _camera = VirtualJoystickScript.new()
    _camera.name = "CameraJoystickInput"
    _camera.mode = "camera"
    _camera.draw_visuals = true
    _camera.size = Vector2(145, 145)
    add_child(_camera)

    _create_action_button("ATTAQUE", "attack", Vector2(112, 112))
    _create_action_button("POUVOIR 1", "ability_1", Vector2(100, 100))
    _create_action_button("POUVOIR 2", "ability_2", Vector2(100, 100))
    _create_action_button("ESQUIVE", "dodge", Vector2(92, 92))
    _create_interact_button()
    _create_switch_button()

    get_viewport().size_changed.connect(_layout_controls)
    _layout_controls.call_deferred()

func _create_action_button(label: String, action: StringName, button_size: Vector2) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size = button_size
    button.size = button_size
    button.add_theme_font_size_override("font_size", 14)
    button.modulate = Color(1.0, 1.0, 1.0, 0.86)
    button.button_down.connect(func(): Input.action_press(action))
    button.button_up.connect(func(): Input.action_release(action))
    add_child(button)
    _buttons.append(button)

func _create_interact_button() -> void:
    var button := Button.new()
    button.text = "EMBARQUER\nINTERAGIR"
    button.custom_minimum_size = Vector2(118, 70)
    button.size = Vector2(118, 70)
    button.add_theme_font_size_override("font_size", 13)
    button.pressed.connect(_interact)
    add_child(button)
    _buttons.append(button)

func _create_switch_button() -> void:
    var button := Button.new()
    button.text = "HÉROS"
    button.custom_minimum_size = Vector2(86, 54)
    button.size = Vector2(86, 54)
    button.add_theme_font_size_override("font_size", 13)
    button.pressed.connect(func(): GameState.cycle_hero())
    add_child(button)
    _buttons.append(button)

func _interact() -> void:
    var world := get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("request_boat_interaction"):
        if bool(world.request_boat_interaction()):
            return
    Input.action_press("interact")
    await get_tree().process_frame
    Input.action_release("interact")

func _layout_controls() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    if _movement != null:
        _movement.position = Vector2(42.0, maxf(20.0, viewport_size.y - 232.0))
    if _camera != null:
        _camera.position = Vector2(282.0, maxf(20.0, viewport_size.y - 190.0))
    if _buttons.size() < 6:
        return
    _buttons[0].position = Vector2(viewport_size.x - 145.0, viewport_size.y - 150.0)
    _buttons[1].position = Vector2(viewport_size.x - 270.0, viewport_size.y - 245.0)
    _buttons[2].position = Vector2(viewport_size.x - 150.0, viewport_size.y - 285.0)
    _buttons[3].position = Vector2(viewport_size.x - 385.0, viewport_size.y - 150.0)
    _buttons[4].position = Vector2(viewport_size.x - 410.0, viewport_size.y - 270.0)
    _buttons[5].position = Vector2(viewport_size.x - 100.0, 22.0)
