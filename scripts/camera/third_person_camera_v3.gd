class_name ThirdPersonCameraV3
extends "res://scripts/camera/third_person_camera_v2.gd"

func _ready() -> void:
    sensitivity = 0.0095
    joystick_sensitivity = 0.024
    super._ready()

func recenter_behind_target() -> void:
    if _target == null or not is_instance_valid(_target):
        return
    yaw = _target.global_rotation.y
    pitch = deg_to_rad(-9.0)
    _apply_rotation()
