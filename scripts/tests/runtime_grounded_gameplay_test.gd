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

func _tap_button(button: Control, touch_index: int) -> void:
    if button == null:
        return
    var touch := InputEventScreenTouch.new()
    touch.index = touch_index
    touch.pressed = true
    touch.position = button.global_position + button.size * 0.5
    button.call("_gui_input", touch)
    await get_tree().physics_frame
    touch.pressed = false
    button.call("_gui_input", touch)
    await get_tree().physics_frame

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
    var attack_button := get_tree().root.find_child("AttackButton", true, false) as Control
    var ability_1_button := get_tree().root.find_child("Ability1Button", true, false) as Control
    var ability_2_button := get_tree().root.find_child("Ability2Button", true, false) as Control
    var dodge_button := get_tree().root.find_child("DodgeButton", true, false) as Control
    var interact_button := get_tree().root.find_child("InteractButton", true, false) as Control
    var hero_switch_button := get_tree().root.find_child("HeroSwitchButton", true, false) as Control
    var camera_reset_button := get_tree().root.find_child("CameraResetButton", true, false) as Control

    _check(InputMap.has_action("jump"), "l'action de saut est enregistrée")
    _check(movement != null, "le joystick tactile est visible dans la scène jouée")
    _check(jump_button != null, "le bouton SAUT est visible dans la scène jouée")
    _check(attack_button != null, "le bouton ATTAQUE est instancié")
    _check(ability_1_button != null, "le bouton POUVOIR 1 est instancié")
    _check(ability_2_button != null, "le bouton POUVOIR 2 est instancié")
    _check(dodge_button != null, "le bouton ESQUIVE est instancié")
    _check(interact_button != null, "le bouton INTERAGIR est instancié")
    _check(hero_switch_button != null, "le bouton CHANGER HÉROS est instancié")
    _check(camera_reset_button != null, "le bouton RECENTRER CAMÉRA est instancié")

    var viewport_width := get_viewport().get_visible_rect().size.x
    for button in [attack_button, ability_1_button, ability_2_button, dodge_button, jump_button, interact_button, hero_switch_button, camera_reset_button]:
        if button != null:
            _check(button.position.x + button.size.x <= viewport_width - 180.0, "%s reste hors de la bande système Android" % button.name)

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
        await _tap_button(jump_button, 7)

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

    # Régression téléphone : chaque commande d'action doit accepter un vrai appui
    # tactile et rendre la main au jeu sans erreur ni action bloquée.
    if attack_button != null:
        await _tap_button(attack_button, 20)
        _check(not Input.is_action_pressed("attack"), "ATTAQUE se presse et se relâche sans rester bloquée")
    if ability_1_button != null:
        await _tap_button(ability_1_button, 21)
        _check(not Input.is_action_pressed("ability_1"), "POUVOIR 1 se presse et se relâche")
    if ability_2_button != null:
        await _tap_button(ability_2_button, 22)
        _check(not Input.is_action_pressed("ability_2"), "POUVOIR 2 se presse et se relâche")
    if dodge_button != null:
        await _tap_button(dodge_button, 23)
        _check(not Input.is_action_pressed("dodge"), "ESQUIVE se presse et se relâche")
    if interact_button != null:
        await _tap_button(interact_button, 24)
        _check(not Input.is_action_pressed("interact"), "INTERAGIR ne laisse aucune action bloquée")
    if camera_reset_button != null:
        await _tap_button(camera_reset_button, 25)
        _check(is_instance_valid(player), "RECENTRER CAMÉRA garde le jeu actif")
    if hero_switch_button != null:
        await _tap_button(hero_switch_button, 26)
        _check(GameState.selected_hero == "yvane", "CHANGER HÉROS fonctionne par appui tactile")
        await _tap_button(hero_switch_button, 27)
        await _tap_button(hero_switch_button, 28)
        _check(GameState.selected_hero == "cheikh", "cycle héros revient correctement à Cheikh")

    # Régression téléphone signalée : le contact d'un ennemi ne doit jamais
    # fermer l'application. On injecte plusieurs impacts consécutifs comme le ferait l'IA.
    var health_before_hit := float(player.get("health"))
    for _hit in range(3):
        player.call("receive_damage", 5.0)
        await get_tree().physics_frame
    var health_after_hit := float(player.get("health"))
    _check(is_instance_valid(player), "les impacts ennemis gardent le héros et le jeu actifs")
    _check(health_after_hit < health_before_hit, "les dégâts ennemis retirent bien des PV sans fermer le jeu")

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
        print("CHK_PIRATE_WARRIOR_2_V4_RUNTIME_ALL_TOUCH_AND_DAMAGE_OK")
    await _finish(main)

func _finish(main: Node) -> void:
    for action in ["jump", "attack", "ability_1", "ability_2", "dodge", "interact", "move_forward"]:
        Input.action_release(action)
    if main != null and is_instance_valid(main):
        main.queue_free()
    await get_tree().process_frame
    get_tree().quit(_failures)
