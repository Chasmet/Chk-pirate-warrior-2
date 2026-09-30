extends "res://scripts/camera/third_person_camera_v3.gd"

var _vehicle_manual_hold := 0.0
var _last_vehicle_controller_id := 0

func _ready() -> void:
    super._ready()
    var arm := get_node_or_null("SpringArm3D") as SpringArm3D
    if arm != null and _target is CollisionObject3D:
        arm.add_excluded_object((_target as CollisionObject3D).get_rid())
        arm.margin = 0.18
    GameSettings.changed.connect(_on_setting_changed)
    _on_setting_changed("", null)

func _process(delta: float) -> void:
    _vehicle_manual_hold = maxf(0.0, _vehicle_manual_hold - delta)
    super._process(delta)
    _update_vehicle_auto_follow(delta)

func _unhandled_input(event: InputEvent) -> void:
    super._unhandled_input(event)
    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _look_touch_id:
            _mark_vehicle_manual_look()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _mark_vehicle_manual_look()

func _on_setting_changed(_key: String, _value: Variant) -> void:
    sensitivity = 0.0048 * float(GameSettings.get_value("sensitivity"))
    joystick_sensitivity = 0.017 * float(GameSettings.get_value("sensitivity"))
    var camera := get_node_or_null("SpringArm3D/Camera3D") as Camera3D
    if camera != null:
        camera.fov = float(GameSettings.get_value("fov"))

func _apply_dynamic_camera(immediate: bool, delta: float = 0.016) -> void:
    # Preserve vehicle camera settings; only land distance is customized.
    super._apply_dynamic_camera(immediate, delta)
    if get_tree().get_first_node_in_group("active_controller") == null:
        var arm := get_node_or_null("SpringArm3D") as SpringArm3D
        if arm != null:
            arm.spring_length = LAND_ARM * float(GameSettings.get_value("camera_distance"))

func apply_joystick_look(value: Vector2) -> void:
    # The overlay sends one sample per rendered frame. Keep speed constant at 30/60 FPS.
    if value.length_squared() > 0.0004:
        _mark_vehicle_manual_look()
    super.apply_joystick_look(value * clampf(get_process_delta_time() * 60.0, 0.1, 3.0))

func _mark_vehicle_manual_look() -> void:
    var controller := get_tree().get_first_node_in_group("active_controller")
    if controller == null:
        return
    var hold := 1.15
    if controller.has_method("camera_manual_hold_time"):
        hold = float(controller.call("camera_manual_hold_time"))
    _vehicle_manual_hold = maxf(_vehicle_manual_hold, hold)

func _update_vehicle_auto_follow(delta: float) -> void:
    var controller := get_tree().get_first_node_in_group("active_controller")
    if controller == null or not controller is Node3D:
        _last_vehicle_controller_id = 0
        return

    var controller_3d := controller as Node3D
    var controller_id := controller_3d.get_instance_id()
    var desired_yaw := controller_3d.global_rotation.y
    if controller.has_method("camera_heading_yaw"):
        desired_yaw = float(controller.call("camera_heading_yaw"))

    var desired_pitch := deg_to_rad(-12.0)
    if controller.has_method("camera_pitch_degrees"):
        desired_pitch = deg_to_rad(float(controller.call("camera_pitch_degrees")))

    if controller_id != _last_vehicle_controller_id:
        _last_vehicle_controller_id = controller_id
        _vehicle_manual_hold = 0.0
        yaw = desired_yaw
        pitch = desired_pitch
        _apply_rotation()
        return

    if _vehicle_manual_hold > 0.0:
        return

    var speed := 0.0
    var steering := 0.0
    var speed_value = controller.get("_current_speed")
    if speed_value != null:
        speed = absf(float(speed_value))
    var steering_value = controller.get("_smoothed_steering")
    if steering_value != null:
        steering = absf(float(steering_value))
    if speed < 0.35 and steering < 0.08:
        return

    var follow_strength := 5.0
    if controller.has_method("camera_auto_follow_strength"):
        follow_strength = float(controller.call("camera_auto_follow_strength"))
    var yaw_weight := 1.0 - exp(-maxf(0.1, follow_strength) * delta)
    var pitch_weight := 1.0 - exp(-3.0 * delta)
    yaw = lerp_angle(yaw, desired_yaw, yaw_weight)
    pitch = lerp_angle(pitch, desired_pitch, pitch_weight)
    _apply_rotation()
