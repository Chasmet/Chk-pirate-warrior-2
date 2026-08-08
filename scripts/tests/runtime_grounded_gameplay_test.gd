extends Node

var _failures := 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK RUNTIME  ", message)
    else:
        _failures += 1
        push_error("ÉCHEC RUNTIME  " + message)

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

    for _frame in range(120):
        await get_tree().physics_frame

    var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
    _check(player != null, "le héros existe dans le jeu lancé")
    if player == null:
        await _finish(main)
        return

    _check(player.is_on_floor(), "Cheikh repose réellement sur une collision de sol")
    _check(player.global_position.y > -1.15, "Cheikh n'est ni sous l'île ni dans l'eau profonde")
    var island := get_tree().root.find_child("Royaume_01_*", true, false) as Node3D
    _check(island != null, "le Royaume musical est instancié")
    _check(get_tree().root.find_child("PlaceArrivee", true, false) != null, "la place d'arrivée collisionnée existe")
    _check(get_tree().root.find_child("Accordia", true, false) != null, "Accordia est visible à l'exécution")
    _check(get_tree().root.find_child("ArcheHarpe_Gauche", true, false) != null, "les arches-harpes du port sont instanciées")
    _check(get_tree().root.find_child("PontPiano_Collision", true, false) != null, "la promenade-piano est instanciée")
    var active_horizon := get_tree().root.find_child("HorizonRoyaume_01", true, false) as Node3D
    var next_horizon := get_tree().root.find_child("HorizonRoyaume_02", true, false) as Node3D
    _check(active_horizon != null and not active_horizon.visible, "la silhouette LOD ne double pas l'île active")
    _check(next_horizon != null and next_horizon.visible, "le royaume suivant reste visible à l'horizon")

    var route_clear := island != null
    var route_max_step := 0.0
    var previous_route_y := NAN
    if island != null:
        for route_index in range(30):
            var route_z := 340.0 + float(route_index) * 5.0
            var ray_from: Vector3 = island.to_global(Vector3(0.0, 5.0, route_z))
            var ray_to: Vector3 = island.to_global(Vector3(0.0, -8.0, route_z))
            var route_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
            route_query.exclude = [player.get_rid()]
            var route_hit := player.get_world_3d().direct_space_state.intersect_ray(route_query)
            if route_hit.is_empty():
                route_clear = false
                break
            var route_point: Vector3 = route_hit.get("position", Vector3.ZERO)
            if not is_nan(previous_route_y):
                route_max_step = maxf(route_max_step, absf(route_point.y - previous_route_y))
            previous_route_y = route_point.y
    _check(route_clear, "une collision continue relie la place d'arrivée au quai")
    _check(route_max_step <= 1.25, "la promenade vers le bateau ne contient pas de marche infranchissable")

    var movement := get_tree().root.find_child("MovementJoystickInput", true, false) as Control
    var jump_button := get_tree().root.find_child("JumpButton", true, false) as Control
    _check(InputMap.has_action("jump"), "l'action de saut est enregistrée")
    _check(movement != null, "le joystick tactile est visible dans la scène jouée")
    _check(jump_button != null, "le bouton SAUT est visible dans la scène jouée")

    var start_position := player.global_position
    var jump_start_y := player.global_position.y
    var max_jump_y := jump_start_y
    if movement != null:
        var move_touch := InputEventScreenTouch.new()
        move_touch.index = 3
        move_touch.pressed = true
        move_touch.position = movement.global_position + movement.size * 0.5 + Vector2(0.0, -movement.size.y * 0.38)
        movement.call("_gui_input", move_touch)
    for _frame in range(8):
        await get_tree().physics_frame

    if jump_button != null:
        var jump_touch := InputEventScreenTouch.new()
        jump_touch.index = 7
        jump_touch.pressed = true
        jump_touch.position = jump_button.global_position + jump_button.size * 0.5
        jump_button.call("_gui_input", jump_touch)
        await get_tree().physics_frame
        jump_touch.pressed = false
        jump_button.call("_gui_input", jump_touch)

    for _frame in range(47):
        await get_tree().physics_frame
        max_jump_y = maxf(max_jump_y, player.global_position.y)
    if movement != null:
        var move_release := InputEventScreenTouch.new()
        move_release.index = 3
        move_release.pressed = false
        move_release.position = movement.global_position + movement.size * 0.5
        movement.call("_gui_input", move_release)

    var horizontal_delta := player.global_position - start_position
    horizontal_delta.y = 0.0
    _check(horizontal_delta.length() > 1.5, "le joystick tactile déplace réellement Cheikh")
    _check(max_jump_y > jump_start_y + 0.65, "SAUT fonctionne pendant qu'un autre doigt maintient le joystick")

    for _frame in range(120):
        if player.is_on_floor():
            break
        await get_tree().physics_frame
    _check(player.is_on_floor(), "Cheikh retombe sur l'île après le saut")

    var boat := get_tree().root.find_child("Bateau_01", true, false) as BoatController
    var dock := get_tree().root.find_child("PortPrincipal", true, false) as Node3D
    _check(boat != null, "le bateau du premier port existe")
    _check(dock != null, "le quai du premier port existe")
    if boat != null:
        _check(boat.boarding_radius >= 9.0, "la portée d'embarquement correspond au quai")
    if boat != null and dock != null:
        var dock_tip := dock.to_global(Vector3(0.0, 1.4, 35.0))
        _check(dock_tip.distance_to(boat.global_position) <= boat.boarding_radius, "le bateau est réellement accessible depuis le bout du quai")
        player.global_position = dock_tip
        player.velocity = Vector3.ZERO
        for _frame in range(8):
            await get_tree().physics_frame
        var world := get_tree().get_first_node_in_group("world_director")
        var boarded := world != null and bool(world.call("request_boat_interaction"))
        _check(boarded and boat.is_boarded(), "Cheikh peut embarquer depuis le quai")
        if boat.is_boarded():
            world.call("request_boat_interaction")
            for _frame in range(90):
                await get_tree().physics_frame
                if player.is_on_floor():
                    break
            _check(not boat.is_boarded(), "Cheikh peut débarquer")
            _check(player.is_on_floor() and player.global_position.y > boat.water_height + 0.35, "le débarquement replace Cheikh sur le quai, pas dans l'eau")

        # Régression V3 : une mort en pleine mer appelait le débarquement normal,
        # qui refusait sans rive. Le bateau conservait alors le héros désactivé
        # et annulait chaque tentative de retour au port.
        player.global_position = dock_tip
        player.velocity = Vector3.ZERO
        for _frame in range(8):
            await get_tree().physics_frame
        var reboarded := world != null and bool(world.call("request_boat_interaction"))
        _check(reboarded and boat.is_boarded(), "Cheikh peut remonter à bord pour tester le respawn maritime")
        if boat.is_boarded():
            var deep_water := island.to_global(Vector3(260.0, boat.water_height, 680.0))
            boat.force_reposition(deep_water, 0.0)
            world.call("respawn_player")
            for _frame in range(90):
                if player.is_on_floor():
                    break
                await get_tree().physics_frame
            var active_after_respawn := get_tree().get_first_node_in_group("active_controller")
            _check(not boat.is_boarded(), "un respawn en pleine mer libère le héros du bateau")
            _check(active_after_respawn == null, "le bateau ne reste pas contrôleur actif après le respawn")
            _check(player.is_physics_processing(), "la physique du héros est réactivée après le respawn maritime")
            _check(player.is_on_floor(), "le héros respawn réellement sur le port après une mort en mer")

    if _failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V4_RUNTIME_GROUNDED_JUMP_OK")
    await _finish(main)

func _finish(main: Node) -> void:
    Input.action_release("jump")
    Input.action_release("move_forward")
    if main != null and is_instance_valid(main):
        main.queue_free()
    await get_tree().process_frame
    get_tree().quit(_failures)
