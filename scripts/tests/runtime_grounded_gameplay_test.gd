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
    AudioDirector.start_gameplay_audio()

    for _frame in range(120):
        await get_tree().physics_frame

    var audio_directors := get_tree().get_nodes_in_group("audio_director")
    _check(audio_directors.size() == 1, "un seul directeur audio joue la musique")
    var audio_director := audio_directors[0] if audio_directors.size() == 1 else null
    if audio_director != null:
        _check(str(audio_director.get("_current_music_path")) == "res://assets/audio/bandes_son/ile_01/theme_principal.mp3", "la vraie bande-son du Royaume musical démarre en jeu")

    var voice_director := get_tree().get_first_node_in_group("hero_voice_director")
    _check(voice_director != null, "le directeur des voix des héros est actif")
    if voice_director != null:
        GameState.set_hero("nelvyn")
        await get_tree().physics_frame
        var nelvyn_voice_started: bool = bool(voice_director.call("play_event", "bonjour", true))
        var nelvyn_voice_player := voice_director.get_node_or_null("PlayableHeroVoice") as AudioStreamPlayer
        _check(nelvyn_voice_started, "une vraie voix de Nelvyn peut être déclenchée")
        _check(nelvyn_voice_player != null and nelvyn_voice_player.stream != null and nelvyn_voice_player.stream.resource_path.contains("/nelvyn/"), "Nelvyn utilise uniquement sa propre banque vocale")
        _check(nelvyn_voice_player != null and nelvyn_voice_player.bus == &"Voice", "Nelvyn utilise le bus Voice séparé de la musique")
        _check(nelvyn_voice_player != null and nelvyn_voice_player.volume_db >= 2.0, "le gain de la voix jouable est renforcé sur téléphone")
        for _audio_frame in range(3):
            await get_tree().process_frame
        var music_bus_index := AudioServer.get_bus_index(&"Music")
        var voice_bus_index := AudioServer.get_bus_index(&"Voice")
        _check(music_bus_index >= 0 and voice_bus_index >= 0, "les bus Music et Voice sont réellement chargés")
        if music_bus_index >= 0:
            _check(AudioServer.get_bus_volume_db(music_bus_index) <= -18.0, "la musique baisse immédiatement pendant la voix de Nelvyn")
        GameState.set_hero("cheikh")
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

    var enemy_models := {}
    var enemy_archetypes := {}
    for enemy in get_tree().get_nodes_in_group("enemy"):
        enemy_models[str(enemy.get("model_path"))] = true
        enemy_archetypes[str(enemy.get("archetype"))] = true
    _check(enemy_models.size() >= 4, "l'île 1 utilise au moins quatre modèles de forces locales différents")
    _check(enemy_archetypes.size() >= 4, "l'île 1 mélange gardes, tireurs, chargeurs et duellistes")
    _check(get_tree().root.find_children("Maison_01_*", "StaticBody3D", true, false).size() >= 10, "le village musical contient au moins dix maisons")
    _check(get_tree().root.find_child("PanneauVillage", true, false) != null, "le village possède une entrée clairement nommée")
    _check(get_tree().get_nodes_in_group("island_vehicle").size() == 2, "deux véhicules thématiques sont présents sur l'île")
    _check(get_tree().root.find_child("RolePNJ", true, false) != null, "les habitants du quai ont des rôles visibles")
    var arrival_grass := get_tree().root.find_child("ArriveeHerbeDenseMultiMesh", true, false) as MultiMeshInstance3D
    _check(arrival_grass != null, "des brindilles sont visibles autour de la zone d'arrivée")
    if arrival_grass != null:
        _check(arrival_grass.multimesh != null and arrival_grass.multimesh.instance_count >= 1000, "la zone jouée possède une vraie densité d'herbe optimisée")
        var grass_mesh := arrival_grass.multimesh.mesh as BoxMesh
        _check(grass_mesh != null and grass_mesh.size.x >= 0.10 and grass_mesh.size.y >= 0.75, "les brindilles sont assez grandes pour rester visibles sur téléphone")
        var guaranteed_grass := get_tree().root.find_child("BrindillesVisiblesAuDepart", true, false) as MeshInstance3D
        _check(guaranteed_grass != null and int(guaranteed_grass.get_meta("blade_count", 0)) >= 160, "au moins 160 brindilles directes se trouvent dans le champ de vision du départ")

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
    var inventory_button := get_tree().root.find_child("InventoryButton", true, false) as Control
    var camera_reset_button := get_tree().root.find_child("CameraResetButton", true, false) as Control
    var edit_toggle := get_tree().root.find_child("TouchLayoutEditToggle", true, false) as Control
    var coin_panel := get_tree().root.find_child("CoinCounterPanel", true, false) as Control

    _check(InputMap.has_action("jump"), "l'action de saut est enregistrée")
    _check(movement != null, "le joystick tactile est visible dans la scène jouée")
    _check(jump_button != null, "le bouton SAUT est visible dans la scène jouée")
    _check(attack_button != null, "le bouton ATTAQUE est instancié")
    _check(ability_1_button != null, "le bouton POUVOIR 1 est instancié")
    _check(ability_2_button != null, "le bouton POUVOIR 2 est instancié")
    _check(dodge_button != null, "le bouton ESQUIVE est instancié")
    _check(interact_button != null, "le bouton INTERAGIR est instancié")
    _check(hero_switch_button != null, "le bouton CHANGER HÉROS est instancié")
    _check(inventory_button != null, "le bouton SAC tactile est instancié")
    _check(camera_reset_button != null, "le bouton RECENTRER CAMÉRA est instancié")
    var runtime_hud := get_tree().get_first_node_in_group("hud")
    if runtime_hud != null:
        var runtime_stats = runtime_hud.get("stats_panel")
        var runtime_mission_title = runtime_hud.get("mission_title")
        var runtime_mission_text = runtime_hud.get("mission_text")
        var runtime_hero_label = runtime_hud.get("hero_label")
        var runtime_health_bar = runtime_hud.get("health_bar")
        _check(runtime_stats is Panel, "la carte de vie utilise un panneau libre sans empilement automatique")
        if runtime_stats is Control and coin_panel != null:
            _check(not (runtime_stats as Control).get_global_rect().intersects(coin_panel.get_global_rect()), "le compteur de pièces reste sous la carte joueur")
        if runtime_hero_label is Control and runtime_health_bar is Control:
            _check(not (runtime_hero_label as Control).get_rect().intersects((runtime_health_bar as Control).get_rect()), "le nom du héros reste séparé de la barre de vie")
        if runtime_mission_title is Control and runtime_mission_text is Control:
            _check(not (runtime_mission_title as Control).get_rect().intersects((runtime_mission_text as Control).get_rect()), "le titre et le texte de mission ne se chevauchent pas")
            _check((runtime_mission_text as Label).get_theme_font_size("font_size") >= 19, "la consigne sous le titre est lisible sur téléphone")
    if coin_panel != null and edit_toggle != null:
        _check(not coin_panel.get_global_rect().intersects(edit_toggle.get_global_rect()), "MODIFIER reste à côté du compteur de pièces")
    if edit_toggle != null and movement != null:
        _check(not edit_toggle.get_global_rect().intersects(movement.get_global_rect()), "MODIFIER ne recouvre pas le joystick")
    var combat_hud := get_tree().get_first_node_in_group("combat_hud_v1_30")
    _check(combat_hud != null, "le HUD V1 30/100 des PV ennemis est actif")
    _check(get_tree().root.find_child("EnemyHealthPanel", true, false) != null, "la barre de vie ennemie est instanciée")
    _check(get_tree().root.find_child("AuraEnergieV130", true, false) != null, "l'aura de pouvoir du héros est visible")
    if combat_hud != null:
        var full_life_color: Color = combat_hud.call("_life_color", 1.0)
        var half_life_color: Color = combat_hud.call("_life_color", 0.50)
        var critical_life_color: Color = combat_hud.call("_life_color", 0.10)
        _check(full_life_color.is_equal_approx(Color("39c66b")), "PV complets : barre verte")
        _check(half_life_color.is_equal_approx(Color("f0c53d")), "PV à moitié : barre jaune")
        _check(critical_life_color.is_equal_approx(Color("e34842")), "PV critiques : barre rouge")

    var viewport_width := get_viewport().get_visible_rect().size.x
    for button in [attack_button, ability_1_button, ability_2_button, dodge_button, jump_button, interact_button, hero_switch_button, inventory_button, camera_reset_button]:
        if button != null:
            _check(button.position.x + button.size.x <= viewport_width - 180.0, "%s reste hors de la bande système Android" % button.name)
    if jump_button != null:
        _check(jump_button.position.x >= viewport_width * 0.5, "SAUT est regroupé à droite avec les actions")

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

    # Régression V1 30/100 : joystick vers le bas doit produire une vraie marche
    # arrière, pas un vecteur nul ni une seconde marche avant.
    var camera := get_viewport().get_camera_3d()
    var camera_forward := Vector3.FORWARD
    if camera != null:
        camera_forward = -camera.global_transform.basis.z
        camera_forward.y = 0.0
        camera_forward = camera_forward.normalized()
    var backpedal_start := player.global_position
    var backpedal_touch := InputEventScreenTouch.new()
    backpedal_touch.index = 40
    backpedal_touch.pressed = true
    backpedal_touch.position = movement.global_position + movement.size * 0.5
    movement.call("_input", backpedal_touch)
    var backpedal_drag := InputEventScreenDrag.new()
    backpedal_drag.index = 40
    # Le pouce sort volontairement du rectangle, comme dans la vidéo Honor 200.
    backpedal_drag.position = movement.global_position + Vector2(movement.size.x * 0.5, movement.size.y * 1.22)
    movement.call("_input", backpedal_drag)
    var captured_backpedal: Vector2 = movement.call("get_input_value")
    _check(captured_backpedal.y >= 0.92, "le joystick suit le pouce vers le bas même hors de son cercle")
    for _frame in range(42):
        await get_tree().physics_frame
    backpedal_touch.pressed = false
    backpedal_touch.position = backpedal_drag.position
    movement.call("_input", backpedal_touch)
    var backpedal_delta := player.global_position - backpedal_start
    backpedal_delta.y = 0.0
    _check(backpedal_delta.length() > 1.25, "le joystick vers le bas déplace réellement le héros")
    _check(backpedal_delta.dot(camera_forward) < -0.65, "le héros recule au lieu d'avancer une seconde fois")
    var facing_after_backpedal := -player.global_transform.basis.z
    facing_after_backpedal.y = 0.0
    facing_after_backpedal = facing_after_backpedal.normalized()
    _check(facing_after_backpedal.dot(camera_forward) > 0.55, "le héros reste tourné vers l'avant pendant le recul maximal")

    if attack_button != null:
        await _tap_button(attack_button, 20)
        _check(not Input.is_action_pressed("attack"), "ATTAQUE se presse et se relâche sans rester bloquée")
    if ability_1_button != null:
        await _tap_button(ability_1_button, 21)
        _check(not Input.is_action_pressed("ability_1"), "POUVOIR 1 se presse et se relâche")
        _check(get_tree().root.find_child("ImpactPouvoir_*", true, false) != null, "POUVOIR 1 déclenche une onde d'énergie visible")
    if ability_2_button != null:
        await _tap_button(ability_2_button, 22)
        _check(not Input.is_action_pressed("ability_2"), "POUVOIR 2 se presse et se relâche")
    if dodge_button != null:
        await _tap_button(dodge_button, 23)
        _check(not Input.is_action_pressed("dodge"), "ESQUIVE se presse et se relâche")
    if interact_button != null:
        await _tap_button(interact_button, 24)
        _check(not Input.is_action_pressed("interact"), "INTERAGIR ne laisse aucune action bloquée")
    if inventory_button != null:
        var hud := get_tree().get_first_node_in_group("hud")
        var inventory_panel = hud.get("inventory_panel") if hud != null else null
        await _tap_button(inventory_button, 29)
        _check(inventory_panel is Control and (inventory_panel as Control).visible, "SAC ouvre réellement l'inventaire au toucher")
        await _tap_button(inventory_button, 30)
        _check(inventory_panel is Control and not (inventory_panel as Control).visible, "SAC referme réellement l'inventaire")
    if camera_reset_button != null:
        await _tap_button(camera_reset_button, 25)
        _check(is_instance_valid(player), "RECENTRER CAMÉRA garde le jeu actif")
    if hero_switch_button != null:
        await _tap_button(hero_switch_button, 26)
        _check(GameState.selected_hero == "yvane", "CHANGER HÉROS fonctionne par appui tactile")
        await _tap_button(hero_switch_button, 27)
        await _tap_button(hero_switch_button, 28)
        _check(GameState.selected_hero == "cheikh", "cycle héros revient correctement à Cheikh")

    if attack_button != null:
        var interrupted_touch := InputEventScreenTouch.new()
        interrupted_touch.index = 31
        interrupted_touch.pressed = true
        interrupted_touch.position = attack_button.global_position + attack_button.size * 0.5
        attack_button.call("_gui_input", interrupted_touch)
        var touch_overlay := get_tree().root.find_child("MobileInputOverlay", true, false)
        if touch_overlay != null:
            touch_overlay.call("_cancel_all_touches")
        _check(not Input.is_action_pressed("attack"), "une interruption Android libère les actions tactiles")

    # L'esquive active volontairement 0,30 s d'invulnérabilité et une impulsion.
    # On laisse l'état revenir au repos avant dégâts et embarquement.
    for _frame in range(30):
        await get_tree().physics_frame
    player.velocity = Vector3.ZERO

    var health_before_hit := float(player.get("health"))
    for _hit in range(3):
        player.call("receive_damage", 5.0)
        for _frame in range(2):
            await get_tree().physics_frame
    var health_after_hit := float(player.get("health"))
    _check(is_instance_valid(player), "les impacts ennemis gardent le héros et le jeu actifs")
    _check(health_after_hit < health_before_hit, "les dégâts ennemis retirent bien des PV sans fermer le jeu")

    var world := get_tree().get_first_node_in_group("world_director")
    var vehicle := get_tree().get_first_node_in_group("island_vehicle") as IslandVehicle
    _check(vehicle != null, "un véhicule terrestre conduisible est instancié")
    if vehicle != null and world != null:
        player.global_position = vehicle.global_position + Vector3(0.0, 1.1, 3.4)
        player.velocity = Vector3.ZERO
        for _frame in range(8):
            await get_tree().physics_frame
        var vehicle_boarded := bool(world.call("request_boat_interaction"))
        _check(vehicle_boarded and vehicle.is_boarded(), "Cheikh peut monter dans un véhicule d'île")
        if vehicle.is_boarded():
            var vehicle_start := vehicle.global_position
            var vehicle_touch := InputEventScreenTouch.new()
            vehicle_touch.index = 32
            vehicle_touch.pressed = true
            vehicle_touch.position = movement.global_position + movement.size * 0.5 + Vector2(0.0, -movement.size.y * 0.38)
            movement.call("_gui_input", vehicle_touch)
            await get_tree().physics_frame
            var forwarded_vehicle_input: Vector2 = vehicle.get("_virtual_move")
            _check(forwarded_vehicle_input.length() > 0.5, "le joystick transmet son vecteur au véhicule actif")
            for _frame in range(70):
                await get_tree().physics_frame
            vehicle_touch.pressed = false
            vehicle_touch.position = movement.global_position + movement.size * 0.5
            movement.call("_gui_input", vehicle_touch)
            var driven_distance := Vector2(vehicle.global_position.x - vehicle_start.x, vehicle.global_position.z - vehicle_start.z).length()
            _check(absf(float(vehicle.get("_current_speed"))) > 0.5, "le moteur du véhicule reçoit une vitesse")
            _check(driven_distance > 2.0, "le joystick déplace réellement le véhicule")
            _check(not GameState.exact_boat_mode, "conduire à terre n'enregistre pas une fausse sauvegarde en bateau")

            # Régression critique : une attaque létale pendant la conduite ne
            # doit ni fermer/minimiser Android, ni laisser un contrôleur fantôme.
            player.call("receive_damage", 99999.0)
            for _frame in range(100):
                await get_tree().physics_frame
                if not vehicle.is_boarded() and player.is_on_floor():
                    break
            _check(not vehicle.is_boarded(), "la mort libère le héros du véhicule")
            _check(get_tree().get_first_node_in_group("active_controller") == null, "aucun contrôleur fantôme ne subsiste après une mort létale")
            _check(player.is_physics_processing(), "la physique du héros reprend après une mort létale")
            _check(is_equal_approx(float(player.get("health")), float(player.get("max_health"))), "les PV sont restaurés une seule fois au respawn")
            _check(player.is_on_floor() and player.global_position.y > -1.15, "le respawn létal replace le héros sur le port")

    var boat := get_tree().root.find_child("Bateau_01", true, false) as BoatController
    var dock := get_tree().root.find_child("PortPrincipal", true, false) as Node3D
    _check(boat != null, "le bateau du premier port existe")
    _check(dock != null, "le quai du premier port existe")
    if boat != null:
        _check(boat.boarding_radius >= 9.0, "la portée d'embarquement correspond au quai")
        var deck_crew := boat.get_node_or_null("MatelotsDuBord")
        _check(deck_crew != null and deck_crew.get_child_count() >= 2, "des matelots sont visibles sur le bateau du joueur")
    if boat != null and dock != null:
        var dock_tip := dock.to_global(Vector3(0.0, 1.4, 35.0))
        _check(boat.boarding_distance_to(dock_tip) <= boat.boarding_radius, "le bateau est réellement accessible depuis le bout du quai")
        var away_from_dock := boat.global_position - dock.global_position
        away_from_dock.y = 0.0
        var boat_forward := -boat.global_transform.basis.z
        boat_forward.y = 0.0
        _check(away_from_dock.normalized().dot(boat_forward.normalized()) > 0.72, "le bateau amarré pointe vers le large, pas dans le quai")
        player.global_position = dock_tip
        player.velocity = Vector3.ZERO
        for _frame in range(8):
            await get_tree().physics_frame
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
        _check(reboarded and boat.is_boarded(), "Cheikh peut remonter à bord pour quitter le quai")
        if boat.is_boarded():
            var dock_distance_before := Vector2(boat.global_position.x - dock.global_position.x, boat.global_position.z - dock.global_position.z).length()
            var boat_touch := InputEventScreenTouch.new()
            boat_touch.index = 41
            boat_touch.pressed = true
            boat_touch.position = movement.global_position + movement.size * 0.5 + Vector2(0.0, -movement.size.y * 0.38)
            movement.call("_gui_input", boat_touch)
            for _frame in range(80):
                await get_tree().physics_frame
            boat_touch.pressed = false
            boat_touch.position = movement.global_position + movement.size * 0.5
            movement.call("_gui_input", boat_touch)
            var dock_distance_after := Vector2(boat.global_position.x - dock.global_position.x, boat.global_position.z - dock.global_position.z).length()
            _check(dock_distance_after > dock_distance_before + 3.0, "JOYSTICK HAUT fait sortir le bateau du quai sans collision")
            if audio_director != null:
                _check(str(audio_director.get("_current_music_path")) == "res://assets/audio/bandes_son/mer/traversee_mer.mp3", "embarquer déclenche la vraie bande-son de traversée en mer")

            # Reproduit le passage Royaume de feu -> royaume suivant : le bateau
            # piloté arrive au nouveau port avant que l'île soit reconstruite.
            var island_two_info := WorldCatalog.island(1)
            var island_two_center := WorldCatalog.world_positions()[1]
            var island_two_size: Vector2 = island_two_info["size"]
            var island_two_boat_spawn := island_two_center + Vector3(3.4, boat.water_height, island_two_size.y * 0.45 + 41.8)
            boat.force_reposition(island_two_boat_spawn, PI)
            world.call("_load_island", 1, false)
            for _frame in range(16):
                await get_tree().physics_frame
            var boats_after_transition := get_tree().get_nodes_in_group("boat")
            _check(boats_after_transition.size() == 1, "un changement de royaume ne crée plus un second bateau sur celui du joueur")
            _check(boats_after_transition.size() == 1 and boats_after_transition[0] == boat, "le bateau conservé est bien celui que Cheikh pilotait")

            var deep_water := island_two_center + Vector3(260.0, boat.water_height, island_two_size.y * 0.5 + 360.0)
            boat.force_reposition(deep_water, PI)
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
            var repaired_boat_spawn: Vector3 = world.call("_safe_boat_spawn", 1, boat.water_height)
            _check(boat.global_position.distance_to(repaired_boat_spawn) < 1.5, "le bateau revient aussi au quai après le respawn maritime")
            for _frame in range(70):
                await get_tree().physics_frame
            if audio_director != null:
                var landed_music_path := str(audio_director.get("_current_music_path"))
                _check(landed_music_path == "res://assets/audio/bandes_son/ile_02/theme_principal.mp3", "débarquer au royaume suivant rétablit sa bande-son dédiée : " + landed_music_path)

    # Revenir au Royaume musical pour que la boucle ci-dessous couvre bien les
    # onze identités de véhicules depuis l'île 1.
    world.call("_load_island", 0, true)
    for _frame in range(12):
        await get_tree().physics_frame

    # Charge réellement chaque royaume actif. Ce test attrape les régressions
    # que l'audit de fichiers ne voit pas : mauvais signal island_changed,
    # véhicule absent, village non reconstruit ou ancien contenu non libéré.
    var tested_vehicle_styles := {}
    for first_vehicle in get_tree().get_nodes_in_group("island_vehicle"):
        tested_vehicle_styles[str(first_vehicle.get("style_key"))] = true
    for island_index in range(1, 10):
        world.call("_load_island", island_index, true)
        for _frame in range(8):
            await get_tree().physics_frame
        var island_id := island_index + 1
        var island_vehicles := get_tree().get_nodes_in_group("island_vehicle")
        _check(island_vehicles.size() == 2, "île %02d : deux véhicules reconstruits" % island_id)
        for island_vehicle in island_vehicles:
            tested_vehicle_styles[str(island_vehicle.get("style_key"))] = true
        _check(get_tree().root.find_children("Maison_%02d_*" % island_id, "StaticBody3D", true, false).size() >= 10, "île %02d : village chargé" % island_id)
        _check(get_tree().root.find_child("RolePNJ", true, false) != null, "île %02d : habitants et métiers chargés" % island_id)
        if island_id == 5:
            _check(get_tree().root.find_child("TourHeroiqueMarvel", true, false) != null, "île 05 : la grande tour du Royaume Marvel est visible")
        elif island_id == 6:
            _check(get_tree().root.find_child("PokeballGeante_*", true, false) != null, "île 06 : les Pokéballs géantes identifient le Royaume Pokémon")
        var models_on_island := {}
        for enemy_on_island in get_tree().get_nodes_in_group("enemy"):
            if not bool(enemy_on_island.get("boss")):
                models_on_island[str(enemy_on_island.get("model_path"))] = true
        _check(models_on_island.size() >= 3, "île %02d : au moins trois modèles ennemis actifs" % island_id)

    for boss_id in range(1, 11):
        GameState.mark_boss_defeated(boss_id)
    world.call("_load_island", 10, true)
    for _frame in range(10):
        await get_tree().physics_frame
    var final_vehicles := get_tree().get_nodes_in_group("island_vehicle")
    _check(final_vehicles.size() == 2, "île 11 : deux véhicules spectraux reconstruits")
    for final_vehicle in final_vehicles:
        tested_vehicle_styles[str(final_vehicle.get("style_key"))] = true
    _check(tested_vehicle_styles.size() == 11, "les onze royaumes ont chacun un style de véhicule propre")
    _check(get_tree().root.find_children("RuineTroublee_*", "StaticBody3D", true, false).size() >= 8, "île 11 : village remplacé par des ruines")
    _check(get_tree().root.find_child("RolePNJ", true, false) == null, "île 11 : aucun habitant vivant n'est généré")

    var final_boss := get_tree().get_first_node_in_group("enemy") as WorldEnemy
    if ResourceLoader.exists(str(WorldCatalog.island(10)["boss"])):
        _check(final_boss != null and final_boss.boss, "île 11 : grande boss issue du GLB final chargée")
        if final_boss != null:
            final_boss.receive_damage(final_boss.max_health * 0.55)
            _check(bool(final_boss.get("_phase_two")), "la grande boss entre réellement en phase 2")
            final_boss.receive_damage(final_boss.max_health * 2.0)
            for _frame in range(24):
                await get_tree().physics_frame
            _check(GameState.is_boss_defeated(11), "la défaite du grand boss final est enregistrée")
            var trophy := get_tree().root.find_child("TropheeFinal", true, false) as Node3D
            var trophy_beacon := get_tree().root.find_child("BaliseTropheeFinalV130", true, false) as Node3D
            _check(trophy != null, "le trophée final apparaît réellement après la victoire")
            _check(trophy_beacon != null, "une balise lumineuse rend le trophée final impossible à manquer")
            _check(get_tree().root.find_child("SocleTropheeFinal", true, false) != null, "le trophée final possède toujours un socle visible")
            if trophy != null:
                player.global_position = trophy.global_position + Vector3.UP
                player.velocity = Vector3.ZERO
                for _frame in range(8):
                    await get_tree().physics_frame
                _check(GameState.final_reward_collected, "approcher du trophée termine réellement la campagne")

    if _failures == 0:
        # Marqueur historique conservé pour le workflow existant.
        print("CHK_PIRATE_WARRIOR_2_V4_RUNTIME_GROUNDED_JUMP_OK")
        print("CHK_PIRATE_WARRIOR_2_V4_RUNTIME_ALL_TOUCH_AND_DAMAGE_OK")
        print("CHK_PIRATE_WARRIOR_2_V5_RUNTIME_VEHICLES_VILLAGES_VARIETY_OK")
        print("CHK_PIRATE_WARRIOR_2_V5_RUNTIME_FATAL_RESPAWN_OK")
        print("CHK_PIRATE_WARRIOR_2_V1_30_RUNTIME_BOAT_TROPHY_REVERSE_OK")
        print("CHK_PIRATE_WARRIOR_2_V1_30_HOTFIX_2_AUDIO_OK")
        print("CHK_PIRATE_WARRIOR_2_V1_30_HOTFIX_3_VOICE_MIX_OK")
    await _finish(main)

func _finish(main: Node) -> void:
    for action in ["jump", "attack", "ability_1", "ability_2", "dodge", "interact", "move_forward", "move_back"]:
        Input.action_release(action)
    if main != null and is_instance_valid(main):
        main.queue_free()
    await get_tree().process_frame
    get_tree().quit(_failures)
