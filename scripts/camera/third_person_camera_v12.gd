extends "res://scripts/camera/third_person_camera_v3.gd"

func _ready() -> void:
    super._ready()
    var arm := get_node_or_null("SpringArm3D") as SpringArm3D
    if arm != null and _target is CollisionObject3D:
        arm.add_excluded_object((_target as CollisionObject3D).get_rid())
        arm.margin = 0.18
    GameSettings.changed.connect(_on_setting_changed)
    _on_setting_changed("", null)

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
    super.apply_joystick_look(value * clampf(get_process_delta_time() * 60.0, 0.1, 3.0))
