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

    var project_text := FileAccess.get_file_as_string("res://project.godot")
    _check(project_text.contains("config/icon=\"res://assets/interface/logo_chk_pirate_warrior_2.png\""), "logo configuré comme icône de projet")

    GameState.new_game("cheikh", "decouverte")
    _check(GameState.difficulty_enemy_multiplier() < 1.0, "mode Découverte réduit la difficulté ennemie")
    _check(not GameState.can_enter_island(11), "Royaume Troublé scellé au début")
    for island_id in range(1, 10):
        GameState.mark_boss_defeated(island_id)
    _check(GameState.defeated_main_boss_count() == 9, "neuf boss majeurs sont comptés")
    _check(not GameState.can_enter_island(11), "le dixième boss reste obligatoire")
    GameState.mark_boss_defeated(10)
    _check(GameState.defeated_main_boss_count() == 10, "dix boss majeurs sont comptés")
    _check(GameState.can_enter_island(11), "Royaume Troublé débloqué après les dix boss")

    GameState.adjust_crew_reputation("equipage_1", 35)
    GameState.adjust_crew_reputation("equipage_2", -35)
    _check(GameState.crew_relation("equipage_1") == "allie", "relation d'équipage alliée persistante")
    _check(GameState.crew_relation("equipage_2") == "hostile", "relation d'équipage hostile persistante")

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

    var main_scene_resource: Resource = load("res://scenes/main/main.tscn")
    _check(main_scene_resource is PackedScene, "scène principale V2 chargeable")
    if main_scene_resource is PackedScene:
        var main := (main_scene_resource as PackedScene).instantiate()
        root.add_child(main)
        await process_frame
        var world := main.get_node_or_null("ArchipelagoDirector")
        var life_node := main.get_node_or_null("WorldLifeDirector")
        var map_node := main.get_node_or_null("WorldMap")
        _check(world is ArchipelagoDirectorV2, "scène principale utilise ArchipelagoDirectorV2")
        _check(life_node is WorldLifeDirector, "scène principale utilise WorldLifeDirector")
        _check(map_node is WorldMapRuntime, "scène principale utilise la carte V2")
        main.queue_free()
        await process_frame

    if failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V2_COMPLETE_READY")
    else:
        push_error("%d vérification(s) V2 ont échoué" % failures)
    quit(failures)
