extends Control

@export_enum("movement", "camera") var mode := "movement"
@export var deadzone := 0.04
@export var camera_speed := 2.4
@export var draw_visuals := true
@export var response_curve := 0.88

var _touch_id: int = -1
var _mouse_active: bool = false
var _value: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_process_unhandled_input(false)
    _knob = _center()
    queue_redraw()

func _exit_tree() -> void:
    if mode == "movement":
        _send_move_to_controller(Vector2.ZERO)
        _release_movement_actions()

func cancel_input() -> void:
    _touch_id = -1
    _mouse_active = false
    _reset()

func get_input_value() -> Vector2:
    return _value

func _gui_input(event: InputEvent) -> void:
    # InputEventScreenTouch/ScreenDrag utilisent les coordonnées du viewport.
    # Le joystick dessine et calcule en coordonnées locales : on convertit donc
    # systématiquement le point avant de calculer le vecteur de déplacement.
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _touch_id == -1:
            _touch_id = touch.index
            _update_from_position(make_canvas_position_local(touch.position))
            accept_event()
        elif not touch.pressed and touch.index == _touch_id:
            _touch_id = -1
            _reset()
            accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_id:
            _update_from_position(make_canvas_position_local(drag.position))
            accept_event()
    elif event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index == MOUSE_BUTTON_LEFT:
            _mouse_active = mouse_button.pressed
            if _mouse_active:
                _update_from_position(make_canvas_position_local(mouse_button.position))
            else:
                _reset()
            accept_event()
    elif event is InputEventMouseMotion and _mouse_active:
        var motion := event as InputEventMouseMotion
        _update_from_position(make_canvas_position_local(motion.position))
        accept_event()

func _process(_delta: float) -> void:
    if mode == "camera" and _value.length() >= deadzone:
        var rig: Node = get_tree().get_first_node_in_group("camera_rig")
        if rig != null and rig.has_method("apply_joystick_look"):
            rig.apply_joystick_look(_value * camera_speed)
    elif mode == "movement":
        # Le contrôleur reçoit la valeur à chaque frame, y compris ZERO,
        # ce qui évite qu'un ancien vecteur reste bloqué après un contact interrompu.
        _send_move_to_controller(_value)

func _update_from_position(local_position: Vector2) -> void:
    var center: Vector2 = _center()
    var radius: float = _radius()
    var delta: Vector2 = local_position - center
    if delta.length() > radius:
        delta = delta.normalized() * radius
    _knob = center + delta

    var raw := delta / radius
    var magnitude := clampf(raw.length(), 0.0, 1.0)
    if magnitude <= deadzone:
        _value = Vector2.ZERO
    else:
        # V6 : zone morte plus petite et courbe presque linéaire. Les diagonales,
        # le recul et les changements de direction partent plus tôt, tout en gardant
        # une petite zone neutre pour éviter les déplacements involontaires.
        var normalized_strength := clampf((magnitude - deadzone) / maxf(0.001, 1.0 - deadzone), 0.0, 1.0)
        var curved_strength := pow(normalized_strength, maxf(0.5, response_curve))
        _value = raw.normalized() * curved_strength

    if mode == "movement":
        _send_move_to_controller(_value)
        _apply_movement_actions(_value)
    queue_redraw()

func _reset() -> void:
    _value = Vector2.ZERO
    _knob = _center()
    if mode == "movement":
        _send_move_to_controller(Vector2.ZERO)
        _release_movement_actions()
    queue_redraw()

func _send_move_to_controller(value: Vector2) -> void:
    var controller: Node = get_tree().get_first_node_in_group("active_controller")
    if controller == null:
        controller = get_tree().get_first_node_in_group("player")
    if controller != null and controller.has_method("set_virtual_move"):
        controller.set_virtual_move(value)

func _apply_movement_actions(value: Vector2) -> void:
    if value.x < -deadzone:
        Input.action_press("move_left", -value.x)
    else:
        Input.action_release("move_left")
    if value.x > deadzone:
        Input.action_press("move_right", value.x)
    else:
        Input.action_release("move_right")
    if value.y < -deadzone:
        Input.action_press("move_forward", -value.y)
    else:
        Input.action_release("move_forward")
    if value.y > deadzone:
        Input.action_press("move_back", value.y)
    else:
        Input.action_release("move_back")

func _release_movement_actions() -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    Input.action_release("move_forward")
    Input.action_release("move_back")

func _center() -> Vector2:
    var diameter: float = minf(size.x, size.y)
    return Vector2(diameter * 0.5, diameter * 0.5)

func _radius() -> float:
    # La force maximale est atteinte avant le bord physique. Le pouce n'a plus
    # besoin d'aller toucher la limite basse de l'écran pour obtenir le recul.
    return maxf(20.0, minf(size.x, size.y) * 0.39)

func _outer_radius() -> float:
    return maxf(24.0, minf(size.x, size.y) * 0.46)

func _draw() -> void:
    if not draw_visuals:
        return
    var center: Vector2 = _center()
    var outer_radius := _outer_radius()
    var radius := _radius()
    draw_circle(center, outer_radius, Color(0.015, 0.04, 0.06, 0.62))
    draw_arc(center, outer_radius, 0.0, TAU, 64, Color(0.88, 0.67, 0.25, 0.95), 5.0, true)
    # Repères visibles des quatre directions, notamment BAS / recul.
    var tick_color := Color(0.93, 0.76, 0.36, 0.78)
    for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
        draw_line(center + direction * (outer_radius - 16.0), center + direction * (outer_radius - 5.0), tick_color, 4.0, true)
    if _value.length_squared() > 0.001:
        draw_line(center, _knob, Color(0.25, 0.72, 0.95, 0.62), 8.0, true)
    var knob_radius: float = radius * 0.38
    draw_circle(_knob, knob_radius, Color(0.02, 0.08, 0.11, 0.90))
    draw_arc(_knob, knob_radius, 0.0, TAU, 48, Color(0.88, 0.67, 0.25, 0.90), 3.0, true)
