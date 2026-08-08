extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")

var _movement: Control
var _attack_button: Button
var _ability_1_button: Button
var _ability_2_button: Button
var _dodge_button: Button
var _interact_button: Button
var _hero_switch_button: Button
var _camera_reset_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30

    _movement = VirtualJoystickScript.new()
    _movement.name = "MovementJoystickInput"
    _movement.mode = "movement"
    _movement.deadzone = 0.10
    _movement.draw_visuals = true
    _movement.size = Vector2(320, 320)
    add_child(_movement)

    _attack_button = _create_action_button("ATTAQUE", "attack", Vector2(180, 180), 26)
    _ability_1_button = _create_action_button("POUVOIR 1", "ability_1", Vector2(150, 150), 21)
    _ability_2_button = _create_action_button("POUVOIR 2", "ability_2", Vector2(150, 150), 21)
    _dodge_button = _create_action_button("ESQUIVE", "dodge", Vector2(155, 112), 21)
    _create_interact_button()
    _create_switch_button()
    _create_camera_reset_button()

    GameState.hero_changed.connect(_on_hero_changed)
    _refresh_ability_labels()
    _refresh_hero_switch_label()
    get_viewport().size_changed.connect(_layout_controls)
    _layout_controls.call_deferred()

func _create_action_button(label: String, action: StringName, button_size: Vector2, font_size: int) -> Button:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size = button_size
    button.size = button_size
    button.add_theme_font_size_override("font_size", font_size)
    _apply_button_style(button, true)
    button.button_down.connect(func(): Input.action_press(action))
    button.button_up.connect(func(): Input.action_release(action))
    add_child(button)
    return button

func _create_interact_button() -> void:
    _interact_button = Button.new()
    _interact_button.text = "INTERAGIR / EMBARQUER"
    _interact_button.custom_minimum_size = Vector2(225, 96)
    _interact_button.size = Vector2(225, 96)
    _interact_button.add_theme_font_size_override("font_size", 19)
    _apply_button_style(_interact_button, false)
    _interact_button.pressed.connect(_interact)
    add_child(_interact_button)

func _create_switch_button() -> void:
    _hero_switch_button = Button.new()
    _hero_switch_button.custom_minimum_size = Vector2(250, 88)
    _hero_switch_button.size = Vector2(250, 88)
    _hero_switch_button.add_theme_font_size_override("font_size", 20)
    _apply_button_style(_hero_switch_button, false)
    _hero_switch_button.pressed.connect(func(): GameState.cycle_hero())
    add_child(_hero_switch_button)

func _create_camera_reset_button() -> void:
    _camera_reset_button = Button.new()
    _camera_reset_button.text = "RECENTRER\nCAMÉRA"
    _camera_reset_button.custom_minimum_size = Vector2(175, 82)
    _camera_reset_button.size = Vector2(175, 82)
    _camera_reset_button.add_theme_font_size_override("font_size", 18)
    _apply_button_style(_camera_reset_button, false)
    _camera_reset_button.pressed.connect(_recenter_camera)
    add_child(_camera_reset_button)

func _apply_button_style(button: Button, round_button: bool) -> void:
    button.add_theme_color_override("font_color", Color("f9e6a5"))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.02, 0.055, 0.075, 0.86)
    normal.border_color = Color(0.91, 0.68, 0.20, 0.96)
    normal.set_border_width_all(4)
    normal.set_corner_radius_all(80 if round_button else 18)
    button.add_theme_stylebox_override("normal", normal)

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.055, 0.12, 0.15, 0.94)
    button.add_theme_stylebox_override("hover", hover)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.23, 0.15, 0.025, 0.98)
    pressed.border_color = Color("ffe08a")
    button.add_theme_stylebox_override("pressed", pressed)

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
    if cleaned.length() <= 16:
        return cleaned
    var words := cleaned.split(" ")
    if words.size() >= 2:
        return "%s\n%s" % [words[0], words[1]]
    return cleaned.left(16)

func _interact() -> void:
    var world := get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("request_boat_interaction"):
        if bool(world.request_boat_interaction()):
            return
    Input.action_press("interact")
    await get_tree().process_frame
    Input.action_release("interact")

func _recenter_camera() -> void:
    var rig := get_tree().get_first_node_in_group("camera_rig")
    if rig != null and rig.has_method("recenter_behind_target"):
        rig.recenter_behind_target()

func _layout_controls() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y

    if _movement != null:
        _movement.position = Vector2(46.0, maxf(28.0, h - 366.0))

    if _attack_button != null:
        _attack_button.position = Vector2(w - 218.0, h - 218.0)
    if _ability_1_button != null:
        _ability_1_button.position = Vector2(w - 410.0, h - 338.0)
    if _ability_2_button != null:
        _ability_2_button.position = Vector2(w - 228.0, h - 410.0)
    if _dodge_button != null:
        _dodge_button.position = Vector2(w - 425.0, h - 158.0)
    if _interact_button != null:
        _interact_button.position = Vector2(w - 675.0, h - 150.0)
    if _hero_switch_button != null:
        _hero_switch_button.position = Vector2(w - 278.0, 96.0)
    if _camera_reset_button != null:
        _camera_reset_button.position = Vector2(w - 470.0, 98.0)
