extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")
const TouchActionButtonScript = preload("res://scripts/ui/touch_action_button.gd")

# Marges conservées pour éviter les gestes Retour/Accueil Android.
const SAFE_SIDE_MARGIN := 190.0
const SAFE_BOTTOM_MARGIN := 120.0
const JOYSTICK_LEFT_MARGIN := 56.0

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

    # Bloc combat : ATTAQUE dominant, pouvoirs au-dessus et esquive à côté.
    _attack_button = _create_action_button("ATTAQUE", &"attack", Vector2(174, 174), 24, true)
    _attack_button.name = "AttackButton"
    _ability_1_button = _create_action_button("POUVOIR 1", &"ability_1", Vector2(126, 126), 16, true)
    _ability_1_button.name = "Ability1Button"
    _ability_2_button = _create_action_button("POUVOIR 2", &"ability_2", Vector2(126, 126), 16, true)
    _ability_2_button.name = "Ability2Button"
    _dodge_button = _create_action_button("ESQUIVE", &"dodge", Vector2(116, 116), 17, true)
    _dodge_button.name = "DodgeButton"

    # Actions de déplacement au centre, comme sur la maquette.
    _jump_button = _create_action_button("SAUT", &"jump", Vector2(150, 84), 21, false)
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
    _interact_button = _create_action_button("INTERAGIR /\nEMBARQUER", &"", Vector2(210, 84), 16, false)
    _interact_button.name = "InteractButton"
    _interact_button.activated.connect(_interact)

func _create_switch_button() -> void:
    _hero_switch_button = _create_action_button("HÉROS", &"", Vector2(96, 96), 16, true)
    _hero_switch_button.name = "HeroSwitchButton"
    _hero_switch_button.activated.connect(func(): GameState.cycle_hero())

func _create_camera_reset_button() -> void:
    # Fonction conservée mais masquée : un bouton technique ne doit plus encombrer le HUD.
    _camera_reset_button = _create_action_button("RECENTRER\nCAMÉRA", &"", Vector2(150, 66), 14, false)
    _camera_reset_button.name = "CameraResetButton"
    _camera_reset_button.visible = false
    _camera_reset_button.activated.connect(_recenter_camera)

func _on_hero_changed(_hero_id: String) -> void:
    _refresh_ability_labels()
    _refresh_hero_switch_label()

func _refresh_hero_switch_label() -> void:
    if _hero_switch_button != null:
        _hero_switch_button.set_button_text("HÉROS")

func _refresh_ability_labels() -> void:
    var hero := GameState.get_hero_data()
    var abilities: Array = hero.get("abilities", [])
    if _ability_1_button != null:
        _ability_1_button.set_button_text(_short_ability_name(str(abilities[0].get("name", "POUVOIR 1"))) if abilities.size() > 0 else "POUVOIR 1")
    if _ability_2_button != null:
        _ability_2_button.set_button_text(_short_ability_name(str(abilities[1].get("name", "POUVOIR 2"))) if abilities.size() > 1 else "POUVOIR 2")

func _short_ability_name(value: String) -> String:
    var cleaned := value.to_upper()
    if cleaned.length() <= 15:
        return cleaned
    var words := cleaned.split(" ")
    if words.size() >= 2:
        return "%s\n%s" % [words[0], words[1]]
    return cleaned.left(15)

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

    # Joystick seul en bas à gauche.
    if _movement != null:
        _movement.position = Vector2(
            JOYSTICK_LEFT_MARGIN,
            maxf(72.0, h - _movement.size.y - SAFE_BOTTOM_MARGIN)
        )

    # Actions centrales : interaction et saut, bien séparés du joystick.
    if _interact_button != null:
        _interact_button.position = Vector2(360.0, h - SAFE_BOTTOM_MARGIN - _interact_button.size.y)
    if _jump_button != null:
        _jump_button.position = Vector2(585.0, h - SAFE_BOTTOM_MARGIN - _jump_button.size.y)
    if _hero_switch_button != null:
        _hero_switch_button.position = Vector2(515.0, maxf(300.0, h - 338.0))

    # Bloc combat à droite. Tous les boutons restent hors de la bande système Android.
    if _attack_button != null:
        _attack_button.position = Vector2(
            w - SAFE_SIDE_MARGIN - _attack_button.size.x,
            h - SAFE_BOTTOM_MARGIN - _attack_button.size.y
        )
    if _dodge_button != null:
        _dodge_button.position = Vector2(
            w - SAFE_SIDE_MARGIN - _attack_button.size.x - _dodge_button.size.x - 18.0,
            h - SAFE_BOTTOM_MARGIN - _dodge_button.size.y + 8.0
        )
    if _ability_1_button != null:
        _ability_1_button.position = Vector2(
            w - SAFE_SIDE_MARGIN - _attack_button.size.x - _ability_1_button.size.x - 12.0,
            maxf(302.0, h - 430.0)
        )
    if _ability_2_button != null:
        _ability_2_button.position = Vector2(
            w - SAFE_SIDE_MARGIN - _ability_2_button.size.x,
            maxf(296.0, h - 454.0)
        )

    if _camera_reset_button != null:
        _camera_reset_button.position = Vector2(w - SAFE_SIDE_MARGIN - 150.0, 310.0)
