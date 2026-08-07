extends Node3D

@export var sensitivity := 0.006
@export var joystick_sensitivity := 0.018
@export var min_pitch := deg_to_rad(-38.0)
@export var max_pitch := deg_to_rad(42.0)
@export var spring_length := 3.8
@export var vertical_offset := 1.35

var yaw := 0.0
var pitch := deg_to_rad(-7.0)
var _target: Node3D

func _ready() -> void:
    add_to_group("camera_rig")
    _target = get_parent() as Node3D
    top_level = true
    var arm := get_node_or_null("SpringArm3D") as SpringArm3D
    if arm:
        arm.spring_length = spring_length
    _follow_target()
    _apply_rotation()

func _process(_delta: float) -> void:
    _follow_target()

func _follow_target() -> void:
    if _target != null and is_instance_valid(_target):
        global_position = _target.global_position + Vector3(0.0, vertical_offset, 0.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        var viewport_size := get_viewport().get_visible_rect().size
        if event.position.x > viewport_size.x * 0.42:
            _add_look(Vector2(event.relative.x, event.relative.y), sensitivity)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _add_look(Vector2(event.relative.x, event.relative.y), sensitivity)

func apply_joystick_look(value: Vector2) -> void:
    yaw -= value.x * joystick_sensitivity
    pitch = clampf(pitch + value.y * joystick_sensitivity, min_pitch, max_pitch)
    _apply_rotation()

func _add_look(delta: Vector2, factor: float) -> void:
    yaw -= delta.x * factor
    pitch = clampf(pitch - delta.y * factor, min_pitch, max_pitch)
    _apply_rotation()

func _apply_rotation() -> void:
    global_rotation = Vector3(pitch, yaw, 0.0)
