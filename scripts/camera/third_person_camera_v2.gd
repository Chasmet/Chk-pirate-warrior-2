extends "res://scripts/camera/third_person_camera.gd"

const LAND_ARM := 4.6
const BOAT_ARM := 11.5
const LAND_HEIGHT := 1.45
const BOAT_HEIGHT := 3.1

var _camera_mode_boat := false

func _ready() -> void:
    super._ready()
    spring_length = LAND_ARM
    vertical_offset = LAND_HEIGHT
    _apply_dynamic_camera(true)

func _process(delta: float) -> void:
    _apply_dynamic_camera(false, delta)
    super._process(delta)

func _apply_dynamic_camera(immediate: bool, delta: float = 0.016) -> void:
    if _target == null or not is_instance_valid(_target):
        return
    var parent := _target.get_parent()
    var boat_mode := parent is BoatController
    var target_arm := BOAT_ARM if boat_mode else LAND_ARM
    var target_height := BOAT_HEIGHT if boat_mode else LAND_HEIGHT
    var arm := get_node_or_null("SpringArm3D") as SpringArm3D
    if arm != null:
        arm.spring_length = target_arm if immediate else lerpf(arm.spring_length, target_arm, 1.0 - exp(-4.2 * delta))
    vertical_offset = target_height if immediate else lerpf(vertical_offset, target_height, 1.0 - exp(-4.2 * delta))
    if boat_mode != _camera_mode_boat:
        _camera_mode_boat = boat_mode
        if boat_mode:
            pitch = deg_to_rad(-13.0)
        else:
            pitch = deg_to_rad(-7.0)
        _apply_rotation()
