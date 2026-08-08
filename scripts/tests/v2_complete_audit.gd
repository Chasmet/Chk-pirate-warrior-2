extends SceneTree

const GameStateScript = preload("res://scripts/systems/game_state.gd")

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

    var director_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director_v2.gd")
    _check(director_text.contains("SOLDIERS_REQUIRED := 6"), "six forces locales sont requises avant chaque boss")
    _check(director_text.contains("func on_enemy_defeated"), "les ennemis ordinaires alimentent la progression locale")
    _check(director_text.contains("func _update_final_reward_collection"), "le trophée final doit réellement être ramassé")
    _check(director_text.contains("func respawn_player"), "le respawn est géré par l'île active")

    var enemy_text := FileAccess.get_file_as_string("res://scripts/world/world_enemy.gd")
    _check(enemy_text.contains("on_enemy_defeated"), "la mort d'un soldat est signalée au directeur du monde")

    var camera_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v2.gd")
    _check(camera_text.contains("BOAT_ARM := 11.5"), "la caméra bateau cadre le navire en troisième personne")

    var game_state := GameStateScript.new()
    game_state._heroes = game_state._load_json("res://data/heroes.json")
    game_state._items = game_state._load_json("res://data/items.json")
    game_state.new_game("cheikh", "decouverte")
    _check(game_state.difficulty_enemy_multiplier() < 1.0, "mode Découverte réduit la difficulté ennemie")
    _check(not game_state.can_enter_island(11), "Royaume Troublé scellé au début")
    for island_id in range(1, 10):
        game_state.mark_boss_defeated(island_id)
    _check(game_state.defeated_main_boss_count() == 9, "neuf boss majeurs sont comptés")
    _check(not game_state.can_enter_island(11), "le dixième boss reste obligatoire")
    game_state.mark_boss_defeated(10)
    _check(game_state.defeated_main_boss_count() == 10, "dix boss majeurs sont comptés")
    _check(game_state.can_enter_island(11), "Royaume Troublé débloqué après les dix boss")

    game_state.adjust_crew_reputation("equipage_1", 35)
    game_state.adjust_crew_reputation("equipage_2", -35)
    _check(game_state.crew_relation("equipage_1") == "allie", "relation d'équipage alliée persistante")
    _check(game_state.crew_relation("equipage_2") == "hostile", "relation d'équipage hostile persistante")
    game_state.free()

    var life := WorldLifeDirector.new()
    _check(life.active_citizen_budget <= 14, "budget habitants adapté au mobile")
    _check(life.active_fauna_budget <= 8, "budget faune adapté au mobile")
    _check(life.active_crew_budget == 3, "trois équipages autonomes prévus")
    life.free()

    var required_assets := WorldCatalog.required_asset_paths()
    var missing := PackedStringArray()
    for path in required_assets:
        if not ResourceLoader.exists(str(path)):
            missing.append(str(path))
    _check(missing.is_empty(), "tous les assets obligatoires du catalogue sont importables : " + ", ".join(missing))

    var main_scene_text := FileAccess.get_file_as_string("res://scenes/main/main.tscn")
    _check(main_scene_text.contains("hero_controller_v2.gd"), "la scène principale active le contrôleur héros final")
    _check(main_scene_text.contains("third_person_camera_v2.gd"), "la scène principale active la caméra finale")
    _check(main_scene_text.contains("archipelago_director_v2.gd"), "la scène principale active l'archipel V2")
    _check(main_scene_text.contains("world_life_director.gd"), "la scène principale active le monde vivant")
    _check(main_scene_text.contains("world_map_runtime.gd"), "la scène principale active la carte V2")

    var main_scene_resource: Resource = load("res://scenes/main/main.tscn")
    _check(main_scene_resource is PackedScene, "scène principale V2 chargeable")
    if main_scene_resource is PackedScene:
        var main := (main_scene_resource as PackedScene).instantiate()
        _check(main.get_node_or_null("ArchipelagoDirector") != null, "scène principale contient le directeur archipel")
        _check(main.get_node_or_null("WorldLifeDirector") != null, "scène principale contient le monde vivant")
        _check(main.get_node_or_null("WorldMap") != null, "scène principale contient la carte V2")
        main.free()

    if failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V2_COMPLETE_READY")
    else:
        push_error("%d vérification(s) V2 ont échoué" % failures)
    quit(failures)
