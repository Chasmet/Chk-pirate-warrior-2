extends Node

var _failures := 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK FEEDBACK MOBILE  ", message)
    else:
        _failures += 1
        push_error("ÉCHEC FEEDBACK MOBILE  " + message)

func _run() -> void:
    GameState.new_game("cheikh", "aventure")
    var packed := load("res://scenes/main/main.tscn") as PackedScene
    _check(packed != null, "la scène principale est chargeable")
    if packed == null:
        get_tree().quit(_failures)
        return

    var main := packed.instantiate()
    get_tree().root.add_child(main)
    get_tree().paused = false
    var menu := get_tree().root.find_child("MainMenu", true, false)
    if menu != null:
        menu.queue_free()

    # Laisse finir les constructions différées du royaume, du HUD et du joueur.
    for _frame in range(120):
        await get_tree().physics_frame

    var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
    var movement := get_tree().root.find_child("MovementJoystickInput", true, false) as Control
    var hud := get_tree().get_first_node_in_group("hud")
    var grass := get_tree().root.find_child("ArriveeHerbeDenseMultiMesh", true, false) as MultiMeshInstance3D

    _check(player != null, "Cheikh est présent dans la partie")
    _check(movement != null, "le joystick de déplacement est présent")
    _check(hud != null, "le HUD mobile est présent")
    _check(grass != null, "les brindilles du port sont présentes")

    if hud != null:
        var mission_title = hud.get("mission_title")
        var mission_text = hud.get("mission_text")
        _check(mission_title is Label and (mission_title as Label).get_theme_font_size("font_size") == 15, "le titre de mission reste exactement à 15 px")
        _check(mission_text is Label and (mission_text as Label).get_theme_font_size("font_size") >= 19, "seule la consigne sous le titre passe à 19 px")
        if mission_title is Control and mission_text is Control:
            _check(not (mission_title as Control).get_rect().intersects((mission_text as Control).get_rect()), "le grand texte ne touche pas le titre")

    if grass != null and player != null:
        var multi := grass.multimesh
        _check(multi != null and multi.instance_count >= 1200, "1 200 brindilles sont rendues en un MultiMesh")
        var blade_mesh := multi.mesh as BoxMesh if multi != null else null
        _check(blade_mesh != null and blade_mesh.size.x >= 0.10 and blade_mesh.size.y >= 0.75, "les brindilles sont assez grandes pour un écran mobile")
        var nearby_blades := 0
        if multi != null:
            for blade_index in range(multi.instance_count):
                var blade_position := grass.to_global(multi.get_instance_transform(blade_index).origin)
                var flat_delta := blade_position - player.global_position
                flat_delta.y = 0.0
                if flat_delta.length() <= 72.0:
                    nearby_blades += 1
        print("INFO FEEDBACK MOBILE  brindilles à moins de 72 m = ", nearby_blades)
        _check(nearby_blades >= 256, "au moins 256 brindilles sont garanties autour du point de départ")

    if player == null or movement == null:
        await _finish(main)
        return

    var camera := get_viewport().get_camera_3d()
    var camera_forward := Vector3.FORWARD
    if camera != null:
        camera_forward = -camera.global_transform.basis.z
        camera_forward.y = 0.0
        camera_forward = camera_forward.normalized()

    var backpedal_start := player.global_position
    var touch := InputEventScreenTouch.new()
    touch.index = 40
    touch.pressed = true
    touch.position = movement.global_position + movement.size * 0.5
    movement.call("_input", touch)

    var drag := InputEventScreenDrag.new()
    drag.index = 40
    # Reproduit la vidéo : le doigt descend au-delà du rectangle du joystick.
    drag.position = movement.global_position + Vector2(movement.size.x * 0.5, movement.size.y * 1.22)
    movement.call("_input", drag)

    var captured: Vector2 = movement.call("get_input_value")
    var knob: Vector2 = movement.get("_knob")
    _check(captured.y >= 0.92, "le doigt reste capturé sous le cercle")
    _check(knob.y > movement.size.y * 0.75, "le bouton visuel descend réellement vers RECUL")

    for _frame in range(42):
        await get_tree().physics_frame

    touch.pressed = false
    touch.position = drag.position
    movement.call("_input", touch)
    var backpedal_delta := player.global_position - backpedal_start
    backpedal_delta.y = 0.0
    _check(backpedal_delta.length() > 1.25, "le joystick bas déplace réellement Cheikh")
    _check(backpedal_delta.dot(camera_forward) < -0.65, "Cheikh recule au lieu de repartir en avant")

    var facing := -player.global_transform.basis.z
    facing.y = 0.0
    facing = facing.normalized()
    _check(facing.dot(camera_forward) > 0.55, "Cheikh reste face à l'avant pendant le recul")
    var released_value: Vector2 = movement.call("get_input_value")
    _check(released_value.is_zero_approx(), "le joystick revient au centre au relâchement")

    await _finish(main)

func _finish(main: Node) -> void:
    if is_instance_valid(main):
        main.queue_free()
    await get_tree().process_frame
    if _failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V10_MOBILE_FEEDBACK_OK")
    get_tree().quit(_failures)
