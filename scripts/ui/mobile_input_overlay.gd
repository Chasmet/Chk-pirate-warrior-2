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
var _inventory_button: TouchActionButton
var _enemy_recovery_button: TouchActionButton
var _camera_reset_button: TouchActionButton
var _last_vehicle_mode := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30

    _movement = VirtualJoystickScript.new()
    _movement.name = "MovementJoystickInput"
    _movement.mode = "movement"
    _movement.deadzone = 0.075
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

    # SAUT appartient au bloc d'actions de droite, comme demandé sur téléphone.
    _jump_button = _create_action_button("SAUT", &"jump", Vector2(116, 116), 19, true)
    _jump_button.name = "JumpButton"
    _create_interact_button()
    _create_switch_button()
    _create_inventory_button()
    _create_enemy_recovery_button()
    _create_camera_reset_button()

    GameState.hero_changed.connect(_on_hero_changed)
    _refresh_ability_labels()
    _refresh_hero_switch_label()
    get_viewport().size_changed.connect(_layout_controls)
    _layout_controls.call_deferred()

func _process(_delta: float) -> void:
    var active := get_tree().get_first_node_in_group("active_controller")
    var vehicle_mode := active != null
    if vehicle_mode != _last_vehicle_mode:
        _last_vehicle_mode = vehicle_mode
        if _jump_button != null:
            _jump_button.set_enabled(not vehicle_mode)
        if _enemy_recovery_button != null:
            _enemy_recovery_button.set_enabled(not vehicle_mode)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _cancel_all_touches()

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

func _create_inventory_button() -> void:
    _inventory_button = _create_action_button("SAC", &"open_inventory", Vector2(96, 96), 17, true)
    _inventory_button.name = "InventoryButton"

func _create_enemy_recovery_button() -> void:
    _enemy_recovery_button = _create_action_button("ENNEMI\nBLOQUÉ ?", &"", Vector2(170, 64), 14, false)
    _enemy_recovery_button.name = "EnemyRecoveryButton"
    _enemy_recovery_button.activated.connect(_recover_enemy)

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

func _recover_enemy() -> void:
    var recovery := get_tree().get_first_node_in_group("enemy_recovery")
    if recovery != null and recovery.has_method("request_recovery"):
        recovery.call("request_recovery")

func _recenter_camera() -> void:
    var rig := get_tree().get_first_node_in_group("camera_rig")
    if rig != null and rig.has_method("recenter_behind_target"):
        rig.recenter_behind_target()

func _cancel_all_touches() -> void:
    if _movement != null and _movement.has_method("cancel_input"):
        _movement.call("cancel_input")
    for button in [
        _attack_button,
        _ability_1_button,
        _ability_2_button,
        _dodge_button,
        _jump_button,
        _interact_button,
        _hero_switch_button,
        _inventory_button,
        _enemy_recovery_button
    ]:
        if button != null:
            button.cancel_press()

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
    if _jump_button != null:
        _jump_button.position = Vector2(
            _dodge_button.position.x - _jump_button.size.x - 18.0,
            h - SAFE_BOTTOM_MARGIN - _jump_button.size.y + 8.0
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

    # HÉROS et SAC ne doivent plus recouvrir le personnage au centre de l'écran.
    # Sur l'écran large du téléphone ils sont poussés nettement vers la droite.
    var utility_x := w * (0.585 if w >= 1350.0 else 0.50)
    var utility_y := maxf(278.0, h - 405.0)
    if _hero_switch_button != null:
        _hero_switch_button.position = Vector2(utility_x, utility_y)
    if _inventory_button != null:
        _inventory_button.position = Vector2(utility_x + 106.0, utility_y)

    # INTERAGIR est placé plus haut que SAUT/ESQUIVE : il peut donc être plus à droite
    # sans collision tactile avec le bloc combat du bas.
    if _interact_button != null:
        var interact_x := w * (0.56 if w >= 1350.0 else 0.48)
        _interact_button.position = Vector2(
            clampf(interact_x, 420.0, w - SAFE_SIDE_MARGIN - _interact_button.size.x),
            maxf(350.0, h - 326.0)
        )

    # Bouton de secours volontairement petit : visible si un ennemi disparaît, sans masquer le combat.
    if _enemy_recovery_button != null:
        _enemy_recovery_button.position = Vector2(
            clampf(w * 0.55, 610.0, w - SAFE_SIDE_MARGIN - _enemy_recovery_button.size.x),
            205.0
        )

    if _camera_reset_button != null:
        _camera_reset_button.position = Vector2(w - SAFE_SIDE_MARGIN - 150.0, 310.0)
