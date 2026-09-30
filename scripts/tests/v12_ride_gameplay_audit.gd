extends SceneTree

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
    var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    current_scene = main

    # Laisser les directeurs créer les véhicules et le rig caméra réel.
    for _i in range(12):
        await process_frame
        await physics_frame

    var horse: Node = null
    for candidate in get_nodes_in_group("island_vehicle"):
        if str(candidate.get("style_key")) == "horse":
            horse = candidate
            break

    _check(horse != null, "cheval du royaume présent dans le monde")
    if horse == null:
        main.queue_free()
        await process_frame
        quit(1)
        return

    horse.set_physics_process(false)
    var quarter_input := float(horse.call("_steering_curve", 0.25))
    _check(quarter_input > 0.25 and quarter_input < 0.55, "petit mouvement du joystick amplifié sans devenir brutal")
    var low_grip := float(horse.call("_steering_grip", 0.0))
    var high_grip := float(horse.call("_steering_grip", 1.0))
    _check(low_grip > 1.0, "cheval très maniable à basse vitesse")
    _check(high_grip < low_grip and high_grip > 0.65, "galop stabilisé sans supprimer la direction")
    _check(float(horse.call("camera_auto_follow_strength")) >= 8.0, "suivi caméra renforcé pour le cheval")
    _check(float(horse.call("camera_manual_hold_time")) >= 0.7, "regard manuel temporairement respecté")

    var rig := main.get_node("Hero/CameraRig")
    _check(rig != null, "rig caméra réel disponible")
    if rig != null:
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
        _check(_angle_distance(float(rig.get("yaw")), manual_yaw) < 0.001, "rotation manuelle de caméra respectée")

        rig.set("_vehicle_manual_hold", 0.0)
        var before_resume := _angle_distance(float(rig.get("yaw")), float(horse.call("camera_heading_yaw")))
        for _i in range(8):
            rig.call("_update_vehicle_auto_follow", 0.10)
        var after_resume := _angle_distance(float(rig.get("yaw")), float(horse.call("camera_heading_yaw")))
        _check(after_resume < before_resume * 0.25, "caméra reprend automatiquement le suivi après le regard manuel")

        horse.remove_from_group("active_controller")

    main.queue_free()
    await process_frame

    if failures.is_empty():
        print("CHK_V12_RIDE_GAMEPLAY_OK")
    quit(0 if failures.is_empty() else 1)
