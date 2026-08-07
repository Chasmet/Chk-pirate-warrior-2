extends Node3D

@export var sensitivity := 0.008
@export var min_pitch := deg_to_rad(-55.0)
@export var max_pitch := deg_to_rad(55.0)
@export var spring_length := 5.2
@export var vertical_offset := 1.7

var yaw := 0.0
var pitch := deg_to_rad(-10.0)

func _ready() -> void:
    position.y = vertical_offset
    var arm := get_node_or_null("SpringArm3D") as SpringArm3D
    if arm:
        arm.spring_length = spring_length
    _apply_rotation()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        yaw -= event.relative.x * sensitivity
        pitch = clampf(pitch - event.relative.y * sensitivity, min_pitch, max_pitch)
        _apply_rotation()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        yaw -= event.relative.x * sensitivity
        pitch = clampf(pitch - event.relative.y * sensitivity, min_pitch, max_pitch)
        _apply_rotation()

func _apply_rotation() -> void:
    rotation = Vector3(pitch, yaw, 0.0)
