extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")
const TouchActionButtonScript = preload("res://scripts/ui/touch_action_button.gd")

var _movement: Control
var _attack_button: TouchActionButton
var _ability_1_button: TouchActionButton
var _ability_2_button: TouchActionButton
var _dodge_button: TouchActionButton
var _jump_button: TouchActionButton
var _interact_button: TouchActionButton
var _hero_switch_button: TouchActionButton
var _camera_reset_button: TouchActionButton
var _last_boat_mode := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30

    _movement = VirtualJoystickScript.new()
    _movement.name = "MovementJoystickInput"
    _movement.mode = "movement"
    _movement.deadzone = 0.10
    _movement.draw_visuals = true
    _movement.size = Vector2(282, 282)
    add_child(_movement)

    _attack_button = _create_action_button("ATTAQUE", &"attack", Vector2(174, 174), 25, true)
    _ability_1_button = _create_action_button("POUVOIR 1", &"ability_1", Vector2(138, 138), 19, true)
    _ability_2_button = _create_action_button("POUVOIR 2", &"ability_2", Vector2(138, 138), 19, true)
    _dodge_button = _create_action_button("ESQUIVE", &"dodge", Vector2(150, 100), 20, false)
    _jump_button = _create_action_button("SAUT", &"jump", Vector2(146, 110), 23, false)
    _jump_button.name = "JumpButton"
    _create_interact_button()
    _create_switch_button()
    _create_camera_reset_button()

    GameState.hero_changed.connect(_on_hero_changed)
    _refresh_ability_labels()
    _refresh_hero_switch_label()
    get_viewport().size_changed.connect(_layout_controls)
    _layout_controls.call_deferred()

func _process(_delta: float) -> void:
    var active := get_tree().get_first_node_in_group("active_controller")
    var boat_mode := active is BoatController and (active as BoatController).is_boarded()
    if boat_mode != _last_boat_mode:
        _last_boat_mode = boat_mode
        if _jump_button != null:
            _jump_button.set_enabled(not boat_mode)

func _create_action_button(label: String, action: StringName, button_size: Vector2, font_size: int, round_button: bool) -> TouchActionButton:
    var button := TouchActionButtonScript.new() as TouchActionButton
    button.configure(label, action, round_button, font_size)
    button.custom_minimum_size = button_size
    button.size = button_size
    add_child(button)
    return button

func _create_interact_button() -> void:
    _interact_button = _create_action_button("INTERAGIR / EMBARQUER", &"", Vector2(218, 86), 18, false)
    _interact_button.activated.connect(_interact)

func _create_switch_button() -> void:
    _hero_switch_button = _create_action_button("CHANGER HÉROS", &"", Vector2(208, 76), 17, false)
    _hero_switch_button.activated.connect(func(): GameState.cycle_hero())

func _create_camera_reset_button() -> void:
    _camera_reset_button = _create_action_button("RECENTRER\nCAMÉRA", &"", Vector2(168, 76), 17, false)
    _camera_reset_button.activated.connect(_recenter_camera)

func _on_hero_changed(_hero_id: String) -> void:
    _refresh_ability_labels()
    _refresh_hero_switch_label()

func _refresh_hero_switch_label() -> void:
    if _hero_switch_button == null:
        return
    var current_name := str(GameState.get_hero_data().get("display_name", "Héros")).to_upper()
    _hero_switch_button.set_button_text("CHANGER HÉROS\n%s" % current_name)

func _refresh_ability_labels() -> void:
    var hero := GameState.get_hero_data()
    var abilities: Array = hero.get("abilities", [])
    if _ability_1_button != null:
        _ability_1_button.set_button_text(_short_ability_name(str(abilities[0].get("name", "POUVOIR 1"))) if abilities.size() > 0 else "POUVOIR 1")
    if _ability_2_button != null:
        _ability_2_button.set_button_text(_short_ability_name(str(abilities[1].get("name", "POUVOIR 2"))) if abilities.size() > 1 else "POUVOIR 2")

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
        _movement.position = Vector2(24.0, maxf(28.0, h - 306.0))

    if _attack_button != null:
        _attack_button.position = Vector2(w - 194.0, h - 194.0)
    if _ability_1_button != null:
        _ability_1_button.position = Vector2(w - 352.0, h - 304.0)
    if _ability_2_button != null:
        _ability_2_button.position = Vector2(w - 174.0, h - 364.0)
    if _dodge_button != null:
        _dodge_button.position = Vector2(w - 370.0, h - 116.0)
    if _jump_button != null:
        _jump_button.position = Vector2(w - 530.0, h - 122.0)
    if _interact_button != null:
        _interact_button.position = Vector2(w - 760.0, h - 98.0)
    if _hero_switch_button != null:
        _hero_switch_button.position = Vector2(w - 220.0, 86.0)
    if _camera_reset_button != null:
        _camera_reset_button.position = Vector2(w - 396.0, 86.0)
