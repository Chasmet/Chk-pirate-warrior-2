extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")
const TouchActionButtonScript = preload("res://scripts/ui/touch_action_button.gd")

# Marges par défaut pour éviter les gestes Retour/Accueil Android.
const SAFE_SIDE_MARGIN := 190.0
const SAFE_BOTTOM_MARGIN := 120.0
const JOYSTICK_LEFT_MARGIN := 56.0
const TOUCH_LAYOUT_PATH := "user://touch_layout.cfg"
const MIN_LAYOUT_SCALE := 0.55
const MAX_LAYOUT_SCALE := 1.45

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

# Éditeur tactile : MODIFIER permet de déplacer et redimensionner toutes les commandes.
var _layout_config := ConfigFile.new()
var _edit_mode := false
var _edit_toggle: Button
var _edit_minus: Button
var _edit_plus: Button
var _edit_reset: Button
var _edit_done: Button
var _edit_status: Label
var _selection_frame: Panel
var _selected_edit_control: Control
var _edit_touch_id := -1
var _mouse_edit_drag := false
var _drag_offset := Vector2.ZERO

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30
    set_process_input(true)
    _layout_config.load(TOUCH_LAYOUT_PATH)

    _movement = VirtualJoystickScript.new()
    _movement.name = "MovementJoystickInput"
    _movement.mode = "movement"
    _movement.deadzone = 0.075
    _movement.draw_visuals = true
    _movement.size = Vector2(282, 282)
    _movement.custom_minimum_size = Vector2(282, 282)
    _movement.set_meta("base_size", Vector2(282, 282))
    _movement.set_meta("layout_scale", 1.0)
    add_child(_movement)

    _attack_button = _create_action_button("ATTAQUE", &"attack", Vector2(174, 174), 24, true)
    _attack_button.name = "AttackButton"
    _ability_1_button = _create_action_button("POUVOIR 1", &"ability_1", Vector2(126, 126), 16, true)
    _ability_1_button.name = "Ability1Button"
    _ability_2_button = _create_action_button("POUVOIR 2", &"ability_2", Vector2(126, 126), 16, true)
    _ability_2_button.name = "Ability2Button"
    _dodge_button = _create_action_button("ESQUIVE", &"dodge", Vector2(116, 116), 17, true)
    _dodge_button.name = "DodgeButton"
    _jump_button = _create_action_button("SAUT", &"jump", Vector2(116, 116), 19, true)
    _jump_button.name = "JumpButton"
    _create_interact_button()
    _create_switch_button()
    _create_inventory_button()
    _create_enemy_recovery_button()
    _create_camera_reset_button()
    _create_layout_editor()

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
        _refresh_gameplay_enabled_state()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _cancel_all_touches()
        if _edit_mode:
            _save_full_layout()

func _create_action_button(label: String, action: StringName, button_size: Vector2, text_size: int, round_button: bool) -> TouchActionButton:
    var button := TouchActionButtonScript.new() as TouchActionButton
    button.configure(label, action, round_button, text_size)
    button.custom_minimum_size = button_size
    button.size = button_size
    button.set_meta("base_size", button_size)
    button.set_meta("base_font_size", text_size)
    button.set_meta("layout_scale", 1.0)
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
    _camera_reset_button = _create_action_button("RECENTRER\nCAMÉRA", &"", Vector2(150, 66), 14, false)
    _camera_reset_button.name = "CameraResetButton"
    _camera_reset_button.visible = false
    _camera_reset_button.activated.connect(_recenter_camera)

func _create_layout_editor() -> void:
    _selection_frame = Panel.new()
    _selection_frame.name = "TouchLayoutSelection"
    _selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _selection_frame.visible = false
    _selection_frame.z_index = 190
    var select_style := StyleBoxFlat.new()
    select_style.bg_color = Color(0.95, 0.72, 0.15, 0.08)
    select_style.border_color = Color(1.0, 0.86, 0.36, 0.98)
    select_style.set_border_width_all(4)
    select_style.set_corner_radius_all(12)
    _selection_frame.add_theme_stylebox_override("panel", select_style)
    add_child(_selection_frame)

    _edit_toggle = _make_editor_button("MODIFIER", Vector2(116, 44))
    _edit_toggle.name = "TouchLayoutEditToggle"
    _edit_toggle.pressed.connect(_toggle_edit_mode)

    _edit_minus = _make_editor_button("−", Vector2(54, 44))
    _edit_minus.name = "TouchLayoutSmaller"
    _edit_minus.pressed.connect(func(): _resize_selected(-0.10))

    _edit_plus = _make_editor_button("+", Vector2(54, 44))
    _edit_plus.name = "TouchLayoutBigger"
    _edit_plus.pressed.connect(func(): _resize_selected(0.10))

    _edit_reset = _make_editor_button("RÉINIT.", Vector2(82, 44))
    _edit_reset.name = "TouchLayoutReset"
    _edit_reset.pressed.connect(_reset_custom_layout)

    _edit_done = _make_editor_button("OK", Vector2(60, 44))
    _edit_done.name = "TouchLayoutDone"
    _edit_done.pressed.connect(_toggle_edit_mode)

    _edit_status = Label.new()
    _edit_status.name = "TouchLayoutStatus"
    _edit_status.text = "GLISSE UNE COMMANDE • − / + POUR LA TAILLE"
    _edit_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _edit_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _edit_status.add_theme_font_size_override("font_size", 15)
    _edit_status.add_theme_color_override("font_color", Color("ffe9a6"))
    _edit_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    _edit_status.add_theme_constant_override("shadow_offset_x", 2)
    _edit_status.add_theme_constant_override("shadow_offset_y", 2)
    _edit_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _edit_status.z_index = 210
    add_child(_edit_status)

    for control in [_edit_minus, _edit_plus, _edit_reset, _edit_done, _edit_status]:
        control.visible = false

func _make_editor_button(text_value: String, button_size: Vector2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = button_size
    button.size = button_size
    button.focus_mode = Control.FOCUS_NONE
    button.z_index = 210
    button.add_theme_font_size_override("font_size", 15)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.02, 0.055, 0.075, 0.92)
    normal.border_color = Color(0.91, 0.68, 0.20, 0.96)
    normal.set_border_width_all(3)
    normal.set_corner_radius_all(10)
    button.add_theme_stylebox_override("normal", normal)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.27, 0.18, 0.03, 0.98)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover", pressed)
    button.add_theme_color_override("font_color", Color("f9e6a5"))
    add_child(button)
    return button

func _toggle_edit_mode() -> void:
    _edit_mode = not _edit_mode
    _edit_toggle.visible = not _edit_mode
    _edit_minus.visible = _edit_mode
    _edit_plus.visible = _edit_mode
    _edit_reset.visible = _edit_mode
    _edit_done.visible = _edit_mode
    _edit_status.visible = _edit_mode
    _selected_edit_control = null
    _edit_touch_id = -1
    _mouse_edit_drag = false
    _selection_frame.visible = false
    _cancel_all_touches()
    if _movement != null:
        _movement.mouse_filter = Control.MOUSE_FILTER_IGNORE if _edit_mode else Control.MOUSE_FILTER_STOP
    _refresh_gameplay_enabled_state()
    if not _edit_mode:
        _save_full_layout()
    _layout_editor_toolbar()

func _refresh_gameplay_enabled_state() -> void:
    var standard_enabled := not _edit_mode
    for button in [_attack_button, _ability_1_button, _ability_2_button, _dodge_button, _interact_button, _hero_switch_button, _inventory_button]:
        if button != null:
            button.set_enabled(standard_enabled)
    if _jump_button != null:
        _jump_button.set_enabled(standard_enabled and not _last_vehicle_mode)
    if _enemy_recovery_button != null:
        _enemy_recovery_button.set_enabled(standard_enabled and not _last_vehicle_mode)

func _input(event: InputEvent) -> void:
    if not _edit_mode:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if _editor_toolbar_has_point(touch.position):
            return
        if touch.pressed and _edit_touch_id == -1:
            var picked := _pick_editable_control(touch.position)
            if picked != null:
                _selected_edit_control = picked
                _edit_touch_id = touch.index
                _drag_offset = touch.position - picked.position
                _update_selection_frame()
                _edit_status.text = "%s • GLISSE POUR DÉPLACER • − / + TAILLE" % _control_display_name(picked)
                get_viewport().set_input_as_handled()
        elif not touch.pressed and touch.index == _edit_touch_id:
            _edit_touch_id = -1
            _save_selected_layout()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _edit_touch_id and _selected_edit_control != null:
            _move_selected_to(drag.position - _drag_offset)
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index != MOUSE_BUTTON_LEFT or _editor_toolbar_has_point(mouse.position):
            return
        if mouse.pressed:
            var picked := _pick_editable_control(mouse.position)
            if picked != null:
                _selected_edit_control = picked
                _mouse_edit_drag = true
                _drag_offset = mouse.position - picked.position
                _update_selection_frame()
                _edit_status.text = "%s • GLISSE POUR DÉPLACER • − / + TAILLE" % _control_display_name(picked)
                get_viewport().set_input_as_handled()
        elif _mouse_edit_drag:
            _mouse_edit_drag = false
            _save_selected_layout()
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _mouse_edit_drag and _selected_edit_control != null:
        var motion := event as InputEventMouseMotion
        _move_selected_to(motion.position - _drag_offset)
        get_viewport().set_input_as_handled()

func _editable_controls() -> Array[Control]:
    var controls: Array[Control] = []
    for control in [_movement, _attack_button, _ability_1_button, _ability_2_button, _dodge_button, _jump_button, _interact_button, _hero_switch_button, _inventory_button, _enemy_recovery_button]:
        if control != null and control.visible:
            controls.append(control)
    return controls

func _pick_editable_control(point: Vector2) -> Control:
    var controls := _editable_controls()
    controls.reverse()
    for control in controls:
        if control.get_global_rect().has_point(point):
            return control
    return null

func _move_selected_to(target_position: Vector2) -> void:
    if _selected_edit_control == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    _selected_edit_control.position = Vector2(
        clampf(target_position.x, 4.0, maxf(4.0, viewport_size.x - _selected_edit_control.size.x - 4.0)),
        clampf(target_position.y, 4.0, maxf(4.0, viewport_size.y - _selected_edit_control.size.y - 4.0))
    )
    _update_selection_frame()

func _resize_selected(delta_scale: float) -> void:
    if _selected_edit_control == null:
        _edit_status.text = "TOUCHE D'ABORD LA COMMANDE À MODIFIER"
        return
    var old_center := _selected_edit_control.position + _selected_edit_control.size * 0.5
    var current_scale := float(_selected_edit_control.get_meta("layout_scale", 1.0))
    var new_scale := clampf(current_scale + delta_scale, MIN_LAYOUT_SCALE, MAX_LAYOUT_SCALE)
    _selected_edit_control.set_meta("layout_scale", new_scale)
    var base_size: Vector2 = _selected_edit_control.get_meta("base_size", _selected_edit_control.size)
    var new_size := base_size * new_scale
    _selected_edit_control.custom_minimum_size = new_size
    _selected_edit_control.size = new_size
    _selected_edit_control.position = old_center - new_size * 0.5
    _apply_button_font_scale(_selected_edit_control, new_scale)
    _move_selected_to(_selected_edit_control.position)
    _save_selected_layout()

func _apply_button_font_scale(control: Control, scale_value: float) -> void:
    if control is TouchActionButton:
        var button := control as TouchActionButton
        var base_font := int(button.get_meta("base_font_size", button.font_size))
        button.font_size = maxi(10, int(round(float(base_font) * clampf(scale_value, 0.70, 1.25))))
        button.call("_refresh_label")

func _update_selection_frame() -> void:
    if not _edit_mode or _selected_edit_control == null:
        _selection_frame.visible = false
        return
    _selection_frame.visible = true
    _selection_frame.position = _selected_edit_control.position - Vector2(5, 5)
    _selection_frame.size = _selected_edit_control.size + Vector2(10, 10)

func _editor_toolbar_has_point(point: Vector2) -> bool:
    for control in [_edit_toggle, _edit_minus, _edit_plus, _edit_reset, _edit_done]:
        if control != null and control.visible and control.get_global_rect().has_point(point):
            return true
    return false

func _control_display_name(control: Control) -> String:
    match control.name:
        "MovementJoystickInput": return "JOYSTICK"
        "AttackButton": return "ATTAQUE"
        "Ability1Button": return "POUVOIR 1"
        "Ability2Button": return "POUVOIR 2"
        "DodgeButton": return "ESQUIVE"
        "JumpButton": return "SAUT"
        "InteractButton": return "INTERAGIR"
        "HeroSwitchButton": return "HÉROS"
        "InventoryButton": return "SAC"
        "EnemyRecoveryButton": return "ENNEMI BLOQUÉ"
        _: return str(control.name).to_upper()

func _save_selected_layout() -> void:
    if _selected_edit_control == null:
        return
    _save_control_layout(_selected_edit_control)
    _layout_config.save(TOUCH_LAYOUT_PATH)

func _save_full_layout() -> void:
    for control in _editable_controls():
        _save_control_layout(control)
    _layout_config.save(TOUCH_LAYOUT_PATH)

func _save_control_layout(control: Control) -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    var center := control.position + control.size * 0.5
    var normalized_center := Vector2(center.x / viewport_size.x, center.y / viewport_size.y)
    var section := str(control.name)
    _layout_config.set_value(section, "center", normalized_center)
    _layout_config.set_value(section, "scale", float(control.get_meta("layout_scale", 1.0)))

func _apply_saved_layout() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    for control in _editable_controls():
        var section := str(control.name)
        if not _layout_config.has_section(section):
            continue
        var scale_value := clampf(float(_layout_config.get_value(section, "scale", 1.0)), MIN_LAYOUT_SCALE, MAX_LAYOUT_SCALE)
        control.set_meta("layout_scale", scale_value)
        var base_size: Vector2 = control.get_meta("base_size", control.size)
        var resolved_size := base_size * scale_value
        control.custom_minimum_size = resolved_size
        control.size = resolved_size
        _apply_button_font_scale(control, scale_value)
        if _layout_config.has_section_key(section, "center"):
            var normalized_center: Vector2 = _layout_config.get_value(section, "center", Vector2(0.5, 0.5))
            var center := Vector2(normalized_center.x * viewport_size.x, normalized_center.y * viewport_size.y)
            control.position = center - control.size * 0.5
            control.position = Vector2(
                clampf(control.position.x, 4.0, maxf(4.0, viewport_size.x - control.size.x - 4.0)),
                clampf(control.position.y, 4.0, maxf(4.0, viewport_size.y - control.size.y - 4.0))
            )

func _reset_custom_layout() -> void:
    _layout_config.clear()
    _layout_config.save(TOUCH_LAYOUT_PATH)
    for control in _editable_controls():
        control.set_meta("layout_scale", 1.0)
        var base_size: Vector2 = control.get_meta("base_size", control.size)
        control.custom_minimum_size = base_size
        control.size = base_size
        _apply_button_font_scale(control, 1.0)
    _selected_edit_control = null
    _selection_frame.visible = false
    _edit_status.text = "POSITION PAR DÉFAUT RESTAURÉE"
    _layout_controls()

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
    var themed_life := get_tree().get_first_node_in_group("themed_life")
    if themed_life != null and themed_life.has_method("request_interaction"):
        if bool(themed_life.call("request_interaction")):
            return
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
    for button in [_attack_button, _ability_1_button, _ability_2_button, _dodge_button, _jump_button, _interact_button, _hero_switch_button, _inventory_button, _enemy_recovery_button]:
        if button != null:
            button.cancel_press()

func _layout_controls() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y

    # Position par défaut. Dès qu'un joueur utilise MODIFIER, sa disposition sauvegardée remplace ces valeurs.
    if _movement != null:
        _movement.position = Vector2(JOYSTICK_LEFT_MARGIN, maxf(72.0, h - _movement.size.y - SAFE_BOTTOM_MARGIN))

    if _attack_button != null:
        _attack_button.position = Vector2(w - SAFE_SIDE_MARGIN - _attack_button.size.x, h - SAFE_BOTTOM_MARGIN - _attack_button.size.y)
    if _dodge_button != null:
        _dodge_button.position = Vector2(w - SAFE_SIDE_MARGIN - _attack_button.size.x - _dodge_button.size.x - 18.0, h - SAFE_BOTTOM_MARGIN - _dodge_button.size.y + 8.0)
    if _jump_button != null:
        _jump_button.position = Vector2(_dodge_button.position.x - _jump_button.size.x - 18.0, h - SAFE_BOTTOM_MARGIN - _jump_button.size.y + 8.0)
    if _ability_1_button != null:
        _ability_1_button.position = Vector2(w - SAFE_SIDE_MARGIN - _attack_button.size.x - _ability_1_button.size.x - 12.0, maxf(302.0, h - 430.0))
    if _ability_2_button != null:
        _ability_2_button.position = Vector2(w - SAFE_SIDE_MARGIN - _ability_2_button.size.x, maxf(296.0, h - 454.0))

    var utility_x := w * (0.585 if w >= 1350.0 else 0.50)
    var utility_y := maxf(278.0, h - 405.0)
    if _hero_switch_button != null:
        _hero_switch_button.position = Vector2(utility_x, utility_y)
    if _inventory_button != null:
        _inventory_button.position = Vector2(utility_x + 106.0, utility_y)

    if _interact_button != null:
        var interact_x := w * (0.56 if w >= 1350.0 else 0.48)
        _interact_button.position = Vector2(clampf(interact_x, 420.0, w - SAFE_SIDE_MARGIN - _interact_button.size.x), maxf(350.0, h - 326.0))

    if _enemy_recovery_button != null:
        _enemy_recovery_button.position = Vector2(clampf(w * 0.55, 610.0, w - SAFE_SIDE_MARGIN - _enemy_recovery_button.size.x), 205.0)

    if _camera_reset_button != null:
        _camera_reset_button.position = Vector2(w - SAFE_SIDE_MARGIN - 150.0, 310.0)

    _apply_saved_layout()
    _layout_editor_toolbar()
    _update_selection_frame()

func _layout_editor_toolbar() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y
    if _edit_toggle != null:
        _edit_toggle.position = Vector2(18.0, clampf(h * 0.30, 180.0, 246.0))
    if not _edit_mode:
        return
    var toolbar_y := 16.0
    var total_width := 54.0 + 8.0 + 54.0 + 8.0 + 82.0 + 8.0 + 60.0
    var start_x := maxf(12.0, w * 0.5 - total_width * 0.5)
    _edit_minus.position = Vector2(start_x, toolbar_y)
    _edit_plus.position = Vector2(start_x + 62.0, toolbar_y)
    _edit_reset.position = Vector2(start_x + 124.0, toolbar_y)
    _edit_done.position = Vector2(start_x + 214.0, toolbar_y)
    _edit_status.position = Vector2(maxf(8.0, w * 0.5 - 240.0), toolbar_y + 49.0)
    _edit_status.size = Vector2(minf(480.0, w - 16.0), 34.0)
