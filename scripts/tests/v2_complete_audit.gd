extends SceneTree

var failures := 0

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK V2  ", message)
    else:
        failures += 1
        push_error("ÉCHEC V2  " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(WorldCatalog.island_count() == 11, "onze royaumes sont déclarés")
    _check(WorldCatalog.world_positions().size() == 11, "onze positions de monde sont calculées")
    _check(ResourceLoader.exists("res://assets/interface/logo_chk_pirate_warrior_2.png"), "logo CHK présent")
    _check(ResourceLoader.exists("res://assets/interface/menu_principal_chk_pirate_warrior_2.png"), "interface menu principal présente")
    _check(ResourceLoader.exists("res://assets/interface/menu_choix difficulté_aventure_chk_pirate_warrior_2.png"), "interface de difficulté présente")
    _check(ResourceLoader.exists("res://scripts/world/archipelago_director_v2.gd"), "directeur archipel V2 présent")
    _check(ResourceLoader.exists("res://scripts/world/world_life_director.gd"), "monde vivant mobile présent")
    _check(ResourceLoader.exists("res://scripts/ui/world_map_runtime.gd"), "carte des onze royaumes présente")
    _check(ResourceLoader.exists("res://scripts/player/hero_controller_v2.gd"), "contrôleur héros final présent")
    _check(ResourceLoader.exists("res://scripts/camera/third_person_camera_v2.gd"), "caméra troisième personne finale présente")

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
    _check(director_text.contains("func restore_loaded_game"), "Continuer peut reconstruire le royaume sauvegardé même si le monde était déjà initialisé")
    _check(director_text.contains("_current_index = -1"), "la reprise force le rechargement même pour une sauvegarde sur l'île 1")
    _check(director_text.contains("active.force_reposition"), "le verrou de l'île 11 repousse aussi le bateau actif")

    var boat_text := FileAccess.get_file_as_string("res://scripts/player/boat_controller.gd")
    _check(boat_text.contains("func _sync_driver_to_deck"), "le héros reste synchronisé visuellement sur le pont")
    _check(not boat_text.contains("player.reparent(self"), "le héros n'est plus enfant du bateau et ne peut plus être supprimé avec une île")
    _check(boat_text.contains("GameState.set_exact_snapshot(global_position, rotation.y, true)"), "la position du bateau est mémorisée pendant la navigation")
    _check(boat_text.contains("func force_reposition"), "le bateau peut être repositionné proprement par les garde-fous du monde")

    var enemy_text := FileAccess.get_file_as_string("res://scripts/world/world_enemy.gd")
    _check(enemy_text.contains("on_enemy_defeated"), "la mort d'un soldat est signalée au directeur du monde")

    var life_text := FileAccess.get_file_as_string("res://scripts/world/world_life_director.gd")
    _check(life_text.contains("active_citizen_budget := 10"), "budget habitants limité à dix actifs")
    _check(life_text.contains("active_fauna_budget := 6"), "budget faune limité à six actifs")
    _check(life_text.contains("active_crew_budget := 3"), "trois équipages autonomes prévus")
    _check(life_text.contains("if _current_island == 11"), "le Royaume Troublé reste sans habitants ni faune")
    _check(life_text.contains("GameState.crew_relation(crew_id)"), "les équipages appliquent réellement leur réputation persistante")
    _check(life_text.contains("relation == \"hostile\""), "un équipage hostile poursuit et attaque en mer")
    _check(life_text.contains("relation == \"allie\""), "un équipage allié escorte le joueur en mer")
    _check(life_text.contains("floating_treasure_%02d"), "les trésors flottants sont collectables et persistants")
    _check(life_text.contains("wreck_salvaged_%02d"), "les épaves sont fouillables et persistantes")
    _check(life_text.contains("_crew_relations_ready"), "l'initialisation des relations attend le démarrage réel de la partie")
    _check(not life_text.contains("_player = get_tree().get_first_node_in_group(\"player\") as Node3D\n    _initialize_crew_relations()"), "aucune sauvegarde n'est écrite depuis le menu au _ready")

    var menu_text := FileAccess.get_file_as_string("res://scripts/ui/main_menu_runtime.gd")
    _check(menu_text.contains("_restore_world_from_state()"), "Nouvelle aventure et Continuer synchronisent le monde avec GameState")
    _check(menu_text.contains("restore_loaded_game"), "le bouton Continuer déclenche le rechargement physique de l'île sauvegardée")

    var camera_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v2.gd")
    _check(camera_text.contains("BOAT_ARM := 11.5"), "la caméra bateau cadre le navire en troisième personne")
    _check(camera_text.contains("active_controller"), "la caméra détecte le bateau sans dépendre du parent du héros")

    var hero_text := FileAccess.get_file_as_string("res://scripts/player/hero_controller_v2.gd")
    _check(hero_text.contains("_v2_invulnerability"), "l'esquive donne une courte invulnérabilité")
    _check(hero_text.contains("respawn_player"), "la défaite rappelle le respawn de l'île active")
    _check(hero_text.contains("_position_snapshot_accumulator"), "la position exacte à pied est actualisée pour les sauvegardes")

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
    _check(main_scene_text.contains("hero_controller_v2.gd"), "la scène principale active le contrôleur héros final")
    _check(main_scene_text.contains("third_person_camera_v2.gd"), "la scène principale active la caméra finale")
    _check(main_scene_text.contains("archipelago_director_v2.gd"), "la scène principale active l'archipel V2")
    _check(main_scene_text.contains("world_life_director.gd"), "la scène principale active le monde vivant")
    _check(main_scene_text.contains("world_map_runtime.gd"), "la scène principale active la carte V2")

    if failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V2_COMPLETE_READY")
    else:
        push_error("%d vérification(s) V2 ont échoué" % failures)
    quit(failures)
