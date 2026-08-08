extends SceneTree

var failures := 0

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK V3  ", message)
    else:
        failures += 1
        push_error("ÉCHEC V3  " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(WorldCatalog.island_count() == 11, "onze royaumes sont déclarés")
    _check(WorldCatalog.world_positions().size() == 11, "onze positions de monde sont calculées")
    _check(ResourceLoader.exists("res://assets/interface/logo_chk_pirate_warrior_2.png"), "logo CHK présent")
    _check(ResourceLoader.exists("res://assets/interface/menu_principal_chk_pirate_warrior_2.png"), "interface menu principal présente")
    _check(ResourceLoader.exists("res://assets/interface/menu_choix difficulté_aventure_chk_pirate_warrior_2.png"), "interface de difficulté présente")
    _check(ResourceLoader.exists("res://scripts/world/archipelago_director_v3.gd"), "directeur archipel V3 présent")
    _check(ResourceLoader.exists("res://scripts/world/glb_scenery_director.gd"), "directeur de décors GLB présent")
    _check(ResourceLoader.exists("res://scripts/world/world_life_director.gd"), "monde vivant mobile présent")
    _check(ResourceLoader.exists("res://scripts/ui/world_map_runtime.gd"), "carte des onze royaumes présente")
    _check(ResourceLoader.exists("res://scripts/player/hero_controller_v2.gd"), "contrôleur héros présent")
    _check(ResourceLoader.exists("res://scripts/camera/third_person_camera_v3.gd"), "caméra troisième personne V3 présente")

    var project_text := FileAccess.get_file_as_string("res://project.godot")
    _check(project_text.contains("config/icon=\"res://assets/interface/logo_chk_pirate_warrior_2.png\""), "logo configuré comme icône de projet")

    var export_text := FileAccess.get_file_as_string("res://export_presets.cfg")
    var invalid_sdk_override := export_text.contains("gradle_build/use_gradle_build=false") and (export_text.contains("gradle_build/min_sdk=") or export_text.contains("gradle_build/target_sdk="))
    _check(not invalid_sdk_override, "preset Android Godot 4.4 sans override SDK incompatible hors Gradle")
    _check(export_text.contains("architectures/arm64-v8a=true"), "APK Android ARM64 activé")
    _check(export_text.contains("version/name=\"2.0.0\""), "version Android 2.0.0 configurée")

    var state_text := FileAccess.get_file_as_string("res://scripts/systems/game_state.gd")
    _check(state_text.contains("\"decouverte\": {\"enemy\": 0.72"), "mode Découverte réellement configuré")
    _check(state_text.contains("func can_enter_island"), "garde d'accès au Royaume Troublé présente")
    _check(state_text.contains("for island_id in range(1, 11)"), "les dix boss majeurs sont requis")
    _check(state_text.contains("func crew_relation"), "relations allié neutre hostile persistantes")
    _check(state_text.contains("final_reward_collected"), "état du trophée final sauvegardé")
    _check(state_text.contains("exact_boat_mode"), "mode bateau sauvegardé avec la position exacte")

    var director_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director_v2.gd")
    _check(director_text.contains("SOLDIERS_REQUIRED := 6"), "six forces locales sont requises avant chaque boss")
    _check(director_text.contains("func on_enemy_defeated"), "les ennemis ordinaires alimentent la progression locale")
    _check(director_text.contains("func _update_final_reward_collection"), "le trophée final doit réellement être ramassé")
    _check(director_text.contains("func respawn_player"), "le respawn est géré par l'île active")
    _check(director_text.contains("GameState.can_enter_island(11)"), "le Royaume Troublé est verrouillé par la progression")
    _check(director_text.contains("func _preserve_active_boat_for_transition"), "le bateau actif survit au changement d'île")
    _check(director_text.contains("func _restore_boat_mode_if_needed"), "une sauvegarde en mer restaure réellement le bateau")
    _check(director_text.contains("func restore_loaded_game"), "Continuer reconstruit le royaume sauvegardé")
    _check(director_text.contains("_island_root.is_ancestor_of(boat)"), "la reprise en mer ignore les bateaux des anciennes îles")
    _check(director_text.contains("func _rescue_player_from_ocean"), "le héros est secouru s'il tombe sous la mer")

    var director_v3_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director_v3.gd")
    _check(director_v3_text.contains("func _scatter_real_props"), "la V3 désactive l'ancienne dispersion GLB non normalisée")

    var scenery_text := FileAccess.get_file_as_string("res://scripts/world/glb_scenery_director.gd")
    _check(scenery_text.contains("MAX_DECOR_PER_ISLAND := 34"), "budget décor GLB Android plafonné")
    _check(scenery_text.contains("palmier_long.glb"), "palmiers GLB intégrés comme vrais décors")
    _check(scenery_text.contains("tour_pirate.glb"), "tour pirate GLB intégrée")
    _check(scenery_text.contains("canon_pirate.glb"), "canons GLB intégrés")
    _check(scenery_text.contains("coffre_pirate.glb"), "coffres GLB intégrés")
    _check(scenery_text.contains("func _visual_bounds"), "les GLB sont normalisés à une taille cohérente")
    _check(scenery_text.contains("func _terrain_height"), "les GLB sont placés sur le relief réel de l'île")
    _check(scenery_text.contains("Couloir central volontairement libre"), "la zone de marche du port reste dégagée")

    var boat_text := FileAccess.get_file_as_string("res://scripts/player/boat_controller.gd")
    _check(boat_text.contains("func _sync_driver_to_deck"), "le héros reste synchronisé visuellement sur le pont")
    _check(not boat_text.contains("player.reparent(self"), "le héros n'est plus enfant du bateau")
    _check(boat_text.contains("GameState.set_exact_snapshot(global_position, rotation.y, true)"), "la position bateau est mémorisée")
    _check(boat_text.contains("func force_reposition"), "le bateau peut être repositionné proprement")
    _check(boat_text.contains("func _exit_tree"), "un bateau supprimé libère le héros")

    var enemy_text := FileAccess.get_file_as_string("res://scripts/world/world_enemy.gd")
    _check(enemy_text.contains("on_enemy_defeated"), "la mort d'un soldat est signalée au directeur")

    var life_text := FileAccess.get_file_as_string("res://scripts/world/world_life_director.gd")
    _check(life_text.contains("active_citizen_budget := 10"), "budget habitants limité à dix actifs")
    _check(life_text.contains("active_fauna_budget := 6"), "budget faune limité à six actifs")
    _check(life_text.contains("active_crew_budget := 3"), "trois équipages autonomes prévus")
    _check(life_text.contains("if _current_island == 11"), "le Royaume Troublé reste sans habitants ni faune")
    _check(life_text.contains("GameState.crew_relation(crew_id)"), "les équipages appliquent leur réputation persistante")
    _check(life_text.contains("relation == \"hostile\""), "un équipage hostile poursuit et attaque")
    _check(life_text.contains("relation == \"allie\""), "un équipage allié escorte le joueur")
    _check(life_text.contains("floating_treasure_%02d"), "les trésors flottants sont collectables")
    _check(life_text.contains("wreck_salvaged_%02d"), "les épaves sont persistantes")

    var menu_text := FileAccess.get_file_as_string("res://scripts/ui/main_menu_runtime.gd")
    _check(menu_text.contains("_restore_world_from_state()"), "Nouvelle aventure et Continuer synchronisent le monde")
    _check(menu_text.contains("restore_loaded_game"), "Continuer déclenche le rechargement physique")

    var camera_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v2.gd")
    _check(camera_text.contains("BOAT_ARM := 11.5"), "caméra bateau troisième personne conservée")
    var camera_v3_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v3.gd")
    _check(camera_v3_text.contains("sensitivity = 0.0095"), "caméra tactile V3 plus réactive")
    _check(camera_v3_text.contains("func recenter_behind_target"), "recentrage caméra disponible")

    var hero_text := FileAccess.get_file_as_string("res://scripts/player/hero_controller_v2.gd")
    _check(hero_text.contains("_v2_invulnerability"), "l'esquive donne une courte invulnérabilité")
    _check(hero_text.contains("respawn_player"), "la défaite rappelle le respawn de l'île")
    _check(hero_text.contains("_position_snapshot_accumulator"), "la position exacte à pied est sauvegardée")

    var touch_text := FileAccess.get_file_as_string("res://scripts/ui/mobile_input_overlay.gd")
    _check(touch_text.contains("Vector2(320, 320)"), "joystick de déplacement fortement agrandi")
    _check(touch_text.contains("Vector2(180, 180)"), "bouton attaque fortement agrandi")
    _check(touch_text.contains("RECENTRER\\nCAMÉRA"), "bouton de recentrage caméra visible")
    _check(not touch_text.contains("CameraJoystickInput"), "le petit joystick caméra séparé a été supprimé")

    var required_assets := WorldCatalog.required_asset_paths()
    var missing := PackedStringArray()
    for raw_path in required_assets:
        var path := str(raw_path)
        var extension := path.get_extension().to_lower()
        if extension in ["md", "txt", "json"]:
            if not FileAccess.file_exists(path):
                missing.append(path)
        elif not ResourceLoader.exists(path):
            missing.append(path)
    _check(missing.is_empty(), "tous les assets obligatoires du catalogue sont présents/importables : " + ", ".join(missing))

    var main_scene_text := FileAccess.get_file_as_string("res://scenes/main/main.tscn")
    _check(main_scene_text.contains("hero_controller_v2.gd"), "la scène principale active le contrôleur héros")
    _check(main_scene_text.contains("third_person_camera_v3.gd"), "la scène principale active la caméra V3")
    _check(main_scene_text.contains("archipelago_director_v3.gd"), "la scène principale active l'archipel V3")
    _check(main_scene_text.contains("glb_scenery_director.gd"), "la scène principale active le décor GLB")
    _check(main_scene_text.contains("move_speed = 8.2"), "vitesse de déplacement mobile augmentée")
    _check(main_scene_text.contains("rotation_speed = 16.0"), "rotation du héros plus réactive")
    _check(main_scene_text.contains("world_life_director.gd"), "la scène principale active le monde vivant")
    _check(main_scene_text.contains("world_map_runtime.gd"), "la scène principale active la carte")

    if failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V3_GAMEPLAY_READY")
    else:
        push_error("%d vérification(s) V3 ont échoué" % failures)
    quit(failures)
