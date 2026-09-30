extends SceneTree

const VehicleScript = preload("res://scripts/player/island_vehicle.gd")
const CameraScript = preload("res://scripts/camera/third_person_camera_v12.gd")

var failures: Array[String] = []

func _initialize() -> void:
    _run.call_deferred()

func _check(value: bool, label: String) -> void:
    if value:
        print("RIDE OK • ", label)
    else:
        failures.append(label)
        push_error("RIDE ÉCHEC • " + label)

func _angle_distance(a: float, b: float) -> float:
    return absf(wrapf(a - b, -PI, PI))

func _run() -> void:
    var horse = VehicleScript.new()
    horse.style_key = "horse"
    horse.maximum_speed = 13.2
    root.add_child(horse)
    horse.set_physics_process(false)

    var quarter_input := float(horse.call("_steering_curve", 0.25))
    _check(quarter_input > 0.25 and quarter_input < 0.55, "petit mouvement du joystick amplifié sans devenir brutal")
    var low_grip := float(horse.call("_steering_grip", 0.0))
    var high_grip := float(horse.call("_steering_grip", 1.0))
    _check(low_grip > 1.0, "cheval très maniable à basse vitesse")
    _check(high_grip < low_grip and high_grip > 0.65, "galop stabilisé sans supprimer la direction")
    _check(float(horse.call("camera_auto_follow_strength")) >= 8.0, "suivi caméra renforcé pour le cheval")
    _check(float(horse.call("camera_manual_hold_time")) >= 0.7, "regard manuel temporairement respecté")

    var hero := Node3D.new()
    hero.name = "RideCameraTestHero"
    var rig = CameraScript.new()
    rig.name = "CameraRig"
    var arm := SpringArm3D.new()
    arm.name = "SpringArm3D"
    var camera := Camera3D.new()
    camera.name = "Camera3D"
    arm.add_child(camera)
    rig.add_child(arm)
    hero.add_child(rig)
    root.add_child(hero)
    await process_frame
    rig.set_process(false)

    horse.add_to_group("active_controller")
    horse.set("_current_speed", 6.0)
    horse.set("_smoothed_steering", 0.0)
    horse.global_rotation.y = 1.05
    rig.call("_update_vehicle_auto_follow", 0.016)
    var initial_target := float(horse.call("camera_heading_yaw"))
    _check(_angle_distance(float(rig.get("yaw")), initial_target) < 0.01, "caméra recentrée derrière la monture dès la prise de contrôle")

    rig.call("_mark_vehicle_manual_look")
    var manual_yaw := float(rig.get("yaw"))
    horse.global_rotation.y = 1.70
    rig.call("_update_vehicle_auto_follow", 0.25)
    _check(_angle_distance(float(rig.get("yaw")), manual_yaw) < 0.001, "rotation manuelle de caméra non combattue immédiatement")

    rig.set("_vehicle_manual_hold", 0.0)
    var before_resume := _angle_distance(float(rig.get("yaw")), float(horse.call("camera_heading_yaw")))
    for _i in range(8):
        rig.call("_update_vehicle_auto_follow", 0.10)
    var after_resume := _angle_distance(float(rig.get("yaw")), float(horse.call("camera_heading_yaw")))
    _check(after_resume < before_resume * 0.25, "caméra reprend automatiquement le suivi après le regard manuel")

    horse.remove_from_group("active_controller")
    hero.queue_free()
    horse.queue_free()
    await process_frame

    if failures.is_empty():
        print("CHK_V12_RIDE_GAMEPLAY_OK")
    quit(0 if failures.is_empty() else 1)
