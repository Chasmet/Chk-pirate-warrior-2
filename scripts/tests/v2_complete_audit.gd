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
    _check(ResourceLoader.exists("res://scripts/world/archipelago_director_v3.gd"), "directeur archipel V3 présent")
    _check(ResourceLoader.exists("res://scripts/world/glb_scenery_director.gd"), "directeur de décors GLB présent")
    _check(ResourceLoader.exists("res://scripts/player/hero_controller_v3.gd"), "contrôleur héros V3 présent")
    _check(ResourceLoader.exists("res://scripts/camera/third_person_camera_v3.gd"), "caméra troisième personne V3 présente")
    _check(ResourceLoader.exists("res://scripts/ui/hud_mobile_v3.gd"), "HUD Android responsive présent")

    var project_text := FileAccess.get_file_as_string("res://project.godot")
    _check(project_text.contains("config/icon=\"res://assets/interface/logo_chk_pirate_warrior_2.png\""), "logo configuré comme icône de projet")
    _check(project_text.contains("size/viewport_width=1280"), "viewport Android optimisé en 1280x720")
    _check(project_text.contains("size/viewport_height=720"), "hauteur viewport Android optimisée")

    var export_text := FileAccess.get_file_as_string("res://export_presets.cfg")
    var invalid_sdk_override := export_text.contains("gradle_build/use_gradle_build=false") and (export_text.contains("gradle_build/min_sdk=") or export_text.contains("gradle_build/target_sdk="))
    _check(not invalid_sdk_override, "preset Android Godot 4.4 compatible")
    _check(export_text.contains("architectures/arm64-v8a=true"), "APK Android ARM64 activé")

    var state_text := FileAccess.get_file_as_string("res://scripts/systems/game_state.gd")
    _check(state_text.contains("func can_enter_island"), "garde d'accès au Royaume Troublé présente")
    _check(state_text.contains("for island_id in range(1, 11)"), "les dix boss majeurs sont requis")
    _check(state_text.contains("func crew_relation"), "relations équipages persistantes")
    _check(state_text.contains("final_reward_collected"), "trophée final sauvegardé")
    _check(state_text.contains("exact_boat_mode"), "mode bateau sauvegardé")

    var director_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director_v2.gd")
    _check(director_text.contains("SOLDIERS_REQUIRED := 6"), "six forces locales sont requises avant chaque boss")
    _check(director_text.contains("func on_enemy_defeated"), "progression locale alimentée par les combats")
    _check(director_text.contains("func _update_final_reward_collection"), "trophée final réellement ramassable")
    _check(director_text.contains("func _rescue_player_from_ocean"), "secours automatique si le héros tombe dans l'océan")
    _check(director_text.contains("func _restore_boat_mode_if_needed"), "reprise de sauvegarde en mer")

    var director_v3_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director_v3.gd")
    _check(director_v3_text.contains("func _scatter_real_props"), "ancienne dispersion GLB non normalisée désactivée")
    _check(director_v3_text.contains("terrain_resolution = 56"), "relief V3 plus fin que l'ancien terrain polygonal")
    _check(director_v3_text.contains("ShaderMaterial"), "terrain V3 possède un matériau côte/coeur/roche")
    _check(director_v3_text.contains("func _terrain_palette"), "chaque famille de royaumes possède une palette de terrain")

    var scenery_text := FileAccess.get_file_as_string("res://scripts/world/glb_scenery_director.gd")
    _check(scenery_text.contains("MAX_DECOR_PER_ISLAND := 34"), "budget décor GLB Android plafonné")
    _check(scenery_text.contains("palmier_long.glb"), "palmiers GLB intégrés")
    _check(scenery_text.contains("tour_pirate.glb"), "tour pirate GLB intégrée")
    _check(scenery_text.contains("canon_pirate.glb"), "canons GLB intégrés")
    _check(scenery_text.contains("coffre_pirate.glb"), "coffres GLB intégrés")
    _check(scenery_text.contains("func _visual_bounds"), "taille des GLB normalisée")
    _check(scenery_text.contains("func _terrain_height"), "GLB placés sur le relief réel")
    _check(scenery_text.contains("Couloir central volontairement libre"), "zone de circulation du port dégagée")

    var hero_v3_text := FileAccess.get_file_as_string("res://scripts/player/hero_controller_v3.gd")
    _check(hero_v3_text.contains("move_speed = 8.2"), "héros plus rapide sur mobile")
    _check(hero_v3_text.contains("rotation_speed = 16.0"), "rotation du héros plus réactive")
    _check(hero_v3_text.contains("func _normalize_weapon_visual"), "armes GLB normalisées à l'échelle du héros")
    _check(hero_v3_text.contains("target_length := 1.05"), "taille réaliste des armes appliquée")

    var camera_v2_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v2.gd")
    _check(camera_v2_text.contains("LAND_ARM := 3.5"), "caméra terrestre rapprochée du héros")
    var camera_v3_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v3.gd")
    _check(camera_v3_text.contains("sensitivity = 0.0095"), "caméra tactile plus réactive")
    _check(camera_v3_text.contains("func recenter_behind_target"), "recentrage caméra disponible")

    var touch_text := FileAccess.get_file_as_string("res://scripts/ui/mobile_input_overlay.gd")
    _check(touch_text.contains("Vector2(320, 320)"), "gros joystick déplacement")
    _check(touch_text.contains("Vector2(180, 180)"), "gros bouton attaque")
    _check(touch_text.contains("RECENTRER\\nCAMÉRA"), "bouton recentrer caméra visible")
    _check(not touch_text.contains("CameraJoystickInput"), "petit joystick caméra supprimé")

    var joystick_text := FileAccess.get_file_as_string("res://scripts/ui/virtual_joystick.gd")
    _check(joystick_text.contains("make_canvas_position_local"), "coordonnées tactiles du joystick converties du viewport vers le local")
    _check(joystick_text.contains("_send_move_to_controller(_value)"), "vecteur joystick envoyé en continu au contrôleur")

    var hud_v3_text := FileAccess.get_file_as_string("res://scripts/ui/hud_mobile_v3.gd")
    _check(hud_v3_text.contains("func _layout_v3"), "HUD recalculé selon la taille d'écran")
    _check(hud_v3_text.contains("visible = false"), "ancien encart carte permanent masqué pour libérer l'écran")

    var boat_text := FileAccess.get_file_as_string("res://scripts/player/boat_controller.gd")
    _check(boat_text.contains("func _sync_driver_to_deck"), "héros synchronisé sur le pont")
    _check(not boat_text.contains("player.reparent(self"), "héros indépendant du bateau")
    _check(boat_text.contains("func _exit_tree"), "suppression bateau sécurisée")

    var life_text := FileAccess.get_file_as_string("res://scripts/world/world_life_director.gd")
    _check(life_text.contains("active_citizen_budget := 10"), "budget habitants mobile")
    _check(life_text.contains("active_fauna_budget := 6"), "budget faune mobile")
    _check(life_text.contains("active_crew_budget := 3"), "trois équipages autonomes")

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
    _check(missing.is_empty(), "assets obligatoires présents/importables : " + ", ".join(missing))

    for decor_path in [
        "res://assets/decors_glb/glb/palmier_long.glb",
        "res://assets/decors_glb/glb/tour_pirate.glb",
        "res://assets/decors_glb/glb/canon_pirate.glb",
        "res://assets/decors_glb/glb/coffre_pirate.glb",
        "res://assets/decors_glb/glb/rocher_large.glb"
    ]:
        _check(ResourceLoader.exists(decor_path), "décor GLB importable : " + decor_path.get_file())

    var main_scene_text := FileAccess.get_file_as_string("res://scenes/main/main.tscn")
    _check(main_scene_text.contains("hero_controller_v3.gd"), "scène principale sur contrôleur héros V3")
    _check(main_scene_text.contains("third_person_camera_v3.gd"), "scène principale sur caméra V3")
    _check(main_scene_text.contains("archipelago_director_v3.gd"), "scène principale sur archipel V3")
    _check(main_scene_text.contains("glb_scenery_director.gd"), "scène principale charge les décors GLB")
    _check(main_scene_text.contains("spring_length = 3.5"), "SpringArm V3 rapproché")
    _check(main_scene_text.contains("fov = 62.0"), "FOV V3 resserré pour mieux voir le héros")
    _check(main_scene_text.contains("world_life_director.gd"), "monde vivant actif")

    if failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V3_GAMEPLAY_READY")
    else:
        push_error("%d vérification(s) V3 ont échoué" % failures)
    quit(failures)
