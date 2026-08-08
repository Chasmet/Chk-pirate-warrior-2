extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")

var _movement: Control
var _camera: Control
var _buttons: Array[Button] = []
var _ability_1_button: Button
var _ability_2_button: Button
var _hero_switch_button: Button

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
    _ability_1_button = _create_action_button("POUVOIR 1", "ability_1", Vector2(100, 100))
    _ability_2_button = _create_action_button("POUVOIR 2", "ability_2", Vector2(100, 100))
    _create_action_button("ESQUIVE", "dodge", Vector2(92, 92))
    _create_interact_button()
    _create_switch_button()

    GameState.hero_changed.connect(_on_hero_changed)
    _refresh_ability_labels()
    _refresh_hero_switch_label()
    get_viewport().size_changed.connect(_layout_controls)
    _layout_controls.call_deferred()

func _create_action_button(label: String, action: StringName, button_size: Vector2) -> Button:
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
    return button

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
    _hero_switch_button = Button.new()
    _hero_switch_button.text = "CHANGER\nHÉROS"
    _hero_switch_button.custom_minimum_size = Vector2(210, 88)
    _hero_switch_button.size = Vector2(210, 88)
    _hero_switch_button.add_theme_font_size_override("font_size", 18)
    _hero_switch_button.add_theme_color_override("font_color", Color("f6dc82"))
    _hero_switch_button.add_theme_color_override("font_hover_color", Color.WHITE)

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.025, 0.055, 0.075, 0.94)
    normal.border_color = Color(0.90, 0.67, 0.20, 1.0)
    normal.set_border_width_all(3)
    normal.set_corner_radius_all(14)
    _hero_switch_button.add_theme_stylebox_override("normal", normal)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.14, 0.10, 0.03, 0.98)
    _hero_switch_button.add_theme_stylebox_override("pressed", pressed)

    _hero_switch_button.pressed.connect(func(): GameState.cycle_hero())
    add_child(_hero_switch_button)
    _buttons.append(_hero_switch_button)

func _on_hero_changed(_hero_id: String) -> void:
    _refresh_ability_labels()
    _refresh_hero_switch_label()

func _refresh_hero_switch_label() -> void:
    if _hero_switch_button == null:
        return
    var current_name := str(GameState.get_hero_data().get("display_name", "Héros")).to_upper()
    _hero_switch_button.text = "CHANGER HÉROS\n%s" % current_name

func _refresh_ability_labels() -> void:
    var hero := GameState.get_hero_data()
    var abilities: Array = hero.get("abilities", [])
    if _ability_1_button != null:
        _ability_1_button.text = _short_ability_name(str(abilities[0].get("name", "POUVOIR 1"))) if abilities.size() > 0 else "POUVOIR 1"
    if _ability_2_button != null:
        _ability_2_button.text = _short_ability_name(str(abilities[1].get("name", "POUVOIR 2"))) if abilities.size() > 1 else "POUVOIR 2"

func _short_ability_name(value: String) -> String:
    var cleaned := value.to_upper()
    if cleaned.length() <= 14:
        return cleaned
    var words := cleaned.split(" ")
    if words.size() >= 2:
        return "%s\n%s" % [words[0], words[1]]
    return cleaned.left(14)

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
        _camera.position = Vector2(maxf(520.0, viewport_size.x - 610.0), maxf(20.0, viewport_size.y - 210.0))
    if _buttons.size() < 6:
        return
    _buttons[0].position = Vector2(viewport_size.x - 145.0, viewport_size.y - 150.0)
    _buttons[1].position = Vector2(viewport_size.x - 270.0, viewport_size.y - 245.0)
    _buttons[2].position = Vector2(viewport_size.x - 150.0, viewport_size.y - 285.0)
    _buttons[3].position = Vector2(viewport_size.x - 385.0, viewport_size.y - 150.0)
    _buttons[4].position = Vector2(viewport_size.x - 410.0, viewport_size.y - 270.0)
    _buttons[5].position = Vector2(viewport_size.x - 238.0, 92.0)
