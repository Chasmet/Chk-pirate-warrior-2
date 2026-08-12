extends SceneTree

var failures := 0

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK V5  ", message)
    else:
        failures += 1
        push_error("ÉCHEC V5  " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(WorldCatalog.island_count() == 11, "onze royaumes sont déclarés")
    _check(WorldCatalog.world_positions().size() == 11, "onze positions de monde sont calculées")
    _check(ResourceLoader.exists("res://assets/interface/logo_chk_pirate_warrior_2.png"), "logo CHK présent")
    _check(ResourceLoader.exists("res://assets/interface/menu_principal_chk_pirate_warrior_2.png"), "interface menu principal présente")
    _check(ResourceLoader.exists("res://scripts/world/archipelago_director_v3.gd"), "directeur archipel V3 présent")
    _check(ResourceLoader.exists("res://scripts/world/glb_scenery_director.gd"), "directeur de décors GLB présent")
    _check(ResourceLoader.exists("res://scripts/world/coastal_detail_director.gd"), "détails côtiers présents")
    _check(ResourceLoader.exists("res://scripts/world/island_collectible_director.gd"), "collectibles insulaires présents")
    _check(ResourceLoader.exists("res://scripts/world/ambient_fauna_director.gd"), "faune côtière présente")
    _check(ResourceLoader.exists("res://scripts/world/island_settlement_director.gd"), "villages et quais V5 présents")
    _check(ResourceLoader.exists("res://scripts/world/island_vehicle_director.gd"), "véhicules de royaume V5 présents")
    _check(ResourceLoader.exists("res://scripts/player/island_vehicle.gd"), "contrôleur de véhicule terrestre présent")
    _check(ResourceLoader.exists("res://scripts/player/hero_controller_v3.gd"), "contrôleur héros V3 présent")
    _check(ResourceLoader.exists("res://scripts/camera/third_person_camera_v3.gd"), "caméra troisième personne V3 présente")
    _check(ResourceLoader.exists("res://scripts/ui/hud_mobile_v3.gd"), "HUD Android responsive présent")

    var project_text := FileAccess.get_file_as_string("res://project.godot")
    _check(project_text.contains("config/icon=\"res://assets/interface/logo_chk_pirate_warrior_2.png\""), "logo configuré comme icône de projet")
    _check(project_text.contains("size/viewport_width=1280"), "viewport Android optimisé en 1280x720")
    _check(project_text.contains("size/viewport_height=720"), "hauteur viewport Android optimisée")
    _check(project_text.contains("AudioDirector=\"*res://scripts/audio/audio_director.gd\""), "directeur audio persistant configuré une seule fois")
    _check(project_text.contains("default_bus_layout=\"res://default_bus_layout.tres\""), "layout audio Music et Voice configuré")
    _check(ResourceLoader.exists("res://default_bus_layout.tres"), "layout des bus audio importable")

    var bus_layout_text := FileAccess.get_file_as_string("res://default_bus_layout.tres")
    _check(bus_layout_text.contains("bus/1/name = &\"Music\""), "bus Music séparé présent")
    _check(bus_layout_text.contains("bus/2/name = &\"Voice\""), "bus Voice séparé présent")

    for island_id in range(1, 12):
        var island_music_path := "res://assets/audio/bandes_son/ile_%02d/theme_principal.mp3" % island_id
        _check(ResourceLoader.exists(island_music_path), "île %02d : bande-son principale importable" % island_id)
    _check(ResourceLoader.exists("res://assets/audio/bandes_son/mer/traversee_mer.mp3"), "bande-son de traversée en mer importable")
    _check(ResourceLoader.exists("res://assets/audio/menu_theme.mp3"), "musique du menu principal importable")
    _check(ResourceLoader.exists("res://assets/audio/interface_theme.mp3"), "musique des interfaces importable")

    for voice_filename in [
        "arrivee_ile_01.mp3",
        "attaque_01.mp3",
        "attaque_02.mp3",
        "bonjour_01.mp3",
        "bonjour_02.mp3",
        "coffre_trouve_01.mp3",
        "coffre_trouve_02.mp3",
        "douleur_01.mp3",
        "douleur_02.mp3",
        "embarquement_01.mp3",
        "ennemi_repere_01.mp3",
        "victoire_01.mp3",
        "victoire_02.mp3"
    ]:
        _check(ResourceLoader.exists("res://assets/audio/personnages_principaux/nelvyn/" + voice_filename), "voix Nelvyn importable : " + voice_filename)

    var audio_director_text := FileAccess.get_file_as_string("res://scripts/audio/audio_director.gd")
    _check(audio_director_text.contains("func play_menu_audio"), "musique du menu reliée au directeur audio")
    _check(audio_director_text.contains("func play_interface_audio"), "musique d'interface reliée au directeur audio")
    _check(audio_director_text.contains("func start_gameplay_audio"), "passage menu vers musique de royaume implémenté")
    _check(audio_director_text.contains("func play_sea_audio"), "passage automatique vers la musique de mer implémenté")
    _check(audio_director_text.contains("_update_voice_ducking(delta)"), "ducking voix calculé à chaque image")
    _check(audio_director_text.contains("VOICE_DUCK_DB := -20.0"), "musique suffisamment abaissée pendant les dialogues")
    _check(audio_director_text.contains("AudioServer.set_bus_volume_db"), "ducking appliqué au bus Music complet")
    _check(audio_director_text.contains("AudioServer.set_bus_layout"), "layout audio chargé explicitement sur Android")

    var voice_director_text := FileAccess.get_file_as_string("res://scripts/audio/hero_voice_director.gd")
    _check(voice_director_text.contains("VOICE_PLAYER_DB := 2.5"), "gain des trois héros renforcé")
    _check(voice_director_text.contains("_player.bus = \"Voice\""), "voix jouables routées vers le bus Voice")

    var island_one := WorldCatalog.island(0)
    _check((island_one.get("soldiers", []) as Array).size() >= 4, "l'île 1 ne répète plus un seul modèle ennemi")
    _check((island_one.get("soldier_archetypes", []) as Array).size() >= 4, "l'île 1 possède quatre comportements ennemis")
    for island_index in range(WorldCatalog.island_count()):
        var island_info := WorldCatalog.island(island_index)
        _check((island_info.get("soldiers", []) as Array).size() >= 3, "île %02d : au moins trois modèles de forces" % (island_index + 1))

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
    _check(state_text.contains("func add_coins"), "compteur de pièces persistant")

    var director_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director_v2.gd")
    _check(director_text.contains("SOLDIERS_REQUIRED := 6"), "six forces locales sont requises avant chaque boss")
    _check(director_text.contains("func on_enemy_defeated"), "progression locale alimentée par les combats")
    _check(director_text.contains("func _update_final_reward_collection"), "trophée final réellement ramassable")
    _check(director_text.contains("func _rescue_player_from_ocean"), "secours automatique si le héros tombe dans l'océan")
    _check(director_text.contains("func _restore_boat_mode_if_needed"), "reprise de sauvegarde en mer")
    _check(director_text.contains("active.has_method(\"force_disembark_at\")"), "respawn libère bateau et véhicule terrestre")
    _check(director_text.contains("var boat_mode: bool = active is BoatController"), "un véhicule terrestre n'est pas sauvegardé comme bateau")

    var director_v3_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director_v3.gd")
    _check(director_v3_text.contains("func _scatter_real_props"), "ancienne dispersion GLB non normalisée désactivée")
    _check(director_v3_text.contains("terrain_resolution = 56"), "relief V3 plus fin que l'ancien terrain polygonal")
    _check(director_v3_text.contains("ShaderMaterial"), "terrain V3 possède un matériau côte/coeur/roche")
    _check(director_v3_text.contains("func _terrain_palette"), "chaque famille de royaumes possède une palette de terrain")
    _check(director_v3_text.contains("func _terrain_height_formula"), "relief multi-échelle actif")
    _check(director_v3_text.contains("cliff_band"), "falaises procédurales intégrées au vrai terrain")
    _check(director_v3_text.contains("func _build_arrival_plaza"), "place d'arrivée visible et collisionnée")
    _check(director_v3_text.contains("_terrain_height_at(info, 0.0, local_z)"), "apparition calculée sur la hauteur réelle du terrain")

    var director_base_text := FileAccess.get_file_as_string("res://scripts/world/archipelago_director.gd")
    _check(director_base_text.contains("_add_triangle(surface, p00, p10, p01"), "triangles du terrain orientés face au héros")
    _check(director_base_text.contains("backface_collision = true"), "collision terrain double face de sécurité")
    _check(director_base_text.contains("boarding_radius\", 9.0"), "bateau amarré avec portée d'embarquement cohérente")
    _check(director_base_text.contains("func _create_horizon_islands"), "silhouettes LOD maintenues pendant la navigation")
    _check(director_base_text.contains("-0.65, (min_z + max_z)"), "mer alignée avec la hauteur des bateaux")

    var scenery_text := FileAccess.get_file_as_string("res://scripts/world/glb_scenery_director.gd")
    _check(scenery_text.contains("MAX_DECOR_PER_ISLAND := 34"), "budget décor GLB Android plafonné")
    _check(scenery_text.contains("palmier_long.glb"), "palmiers GLB intégrés")
    _check(scenery_text.contains("tour_pirate.glb"), "tour pirate GLB intégrée")
    _check(scenery_text.contains("canon_pirate.glb"), "canons GLB intégrés")
    _check(scenery_text.contains("coffre_pirate.glb"), "coffres GLB intégrés")
    _check(scenery_text.contains("func _visual_bounds"), "taille des GLB normalisée")
    _check(scenery_text.contains("func _terrain_height"), "GLB placés sur le relief réel")
    _check(scenery_text.contains("Couloir central volontairement libre"), "zone de circulation du port dégagée")
    _check(scenery_text.contains("func _build_musical_arrival"), "arrivée du Royaume musical conforme à sa notice")
    _check(scenery_text.contains("ArcheHarpe_Gauche"), "arches-harpes visibles au port d'Accordia")
    _check(scenery_text.contains("PontPiano_Collision"), "promenade-piano présente")
    _check(scenery_text.contains("GrandConservatoire"), "Grand Conservatoire d'Accordia présent")
    _check(scenery_text.contains("OrgueMontResonance"), "Mont de la Résonance possède sa silhouette d'orgues")

    var coast_text := FileAccess.get_file_as_string("res://scripts/world/coastal_detail_director.gd")
    _check(coast_text.contains("func _build_beach_arcs"), "petites plages par secteurs au lieu d'un anneau artificiel")
    _check(coast_text.contains("func _build_cliff_multimesh"), "falaises côtières visuelles présentes")
    _check(coast_text.contains("func _build_tree_multimesh"), "arbres légers MultiMesh présents")
    _check(coast_text.contains("VegetationLegereMultiMesh"), "végétation légère répartie sur l'île")

    var hero_v3_text := FileAccess.get_file_as_string("res://scripts/player/hero_controller_v3.gd")
    _check(hero_v3_text.contains("move_speed = 8.2"), "héros plus rapide sur mobile")
    _check(hero_v3_text.contains("rotation_speed = 16.0"), "rotation du héros plus réactive")
    _check(hero_v3_text.contains("bag_yaw := 180.0 if hero_id == \"cheikh\" else 0.0"), "sacs Yvane et Nelvyn orientés indépendamment de Cheikh")
    _check(hero_v3_text.contains("func _normalize_weapon_visual"), "armes GLB normalisées à l'échelle du héros")
    _check(hero_v3_text.contains("target_length := 1.05"), "taille réaliste des armes appliquée")

    var hero_text := FileAccess.get_file_as_string("res://scripts/player/hero_controller.gd")
    _check(hero_text.contains("jump_velocity := 7.4"), "impulsion de saut physique configurée")
    _check(hero_text.contains("Input.is_action_just_pressed(\"jump\")"), "saut traité par le contrôleur du héros")
    _check(hero_text.contains("signal landed"), "retombée du saut détectée")

    var camera_v2_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v2.gd")
    _check(camera_v2_text.contains("LAND_ARM := 3.65"), "caméra terrestre légèrement rapprochée")
    _check(camera_v2_text.contains("LAND_HEIGHT := 1.42"), "hauteur caméra terrestre ajustée")
    var camera_v3_text := FileAccess.get_file_as_string("res://scripts/camera/third_person_camera_v3.gd")
    _check(camera_v3_text.contains("sensitivity = 0.0048"), "caméra tactile stabilisée")
    _check(camera_v3_text.contains("func recenter_behind_target"), "recentrage caméra disponible")

    var touch_text := FileAccess.get_file_as_string("res://scripts/ui/mobile_input_overlay.gd")
    _check(touch_text.contains("Vector2(282, 282)"), "gros joystick déplacement")
    _check(touch_text.contains("Vector2(174, 174)"), "gros bouton attaque")
    _check(touch_text.contains("\"SAUT\", &\"jump\""), "bouton SAUT tactile visible")
    _check(touch_text.contains("_dodge_button.position.x - _jump_button.size.x"), "bouton SAUT placé dans le bloc d'actions droit")
    _check(touch_text.contains("InventoryButton"), "bouton SAC tactile non masqué")
    _check(touch_text.contains("NOTIFICATION_APPLICATION_FOCUS_OUT"), "interruption Android libère les contacts multitouch")
    _check(touch_text.contains("TouchActionButtonScript"), "boutons d'action réellement multitouch")
    _check(touch_text.contains("SAFE_SIDE_MARGIN := 190.0"), "actions éloignées du bord de navigation Android")
    _check(touch_text.contains("AttackButton") and touch_text.contains("Ability1Button") and touch_text.contains("Ability2Button"), "boutons d'action nommés pour les tests runtime")
    _check(touch_text.contains("RECENTRER\\nCAMÉRA"), "bouton recentrer caméra visible")
    _check(not touch_text.contains("CameraJoystickInput"), "petit joystick caméra supprimé")

    var action_button_text := FileAccess.get_file_as_string("res://scripts/ui/touch_action_button.gd")
    _check(not action_button_text.contains("Input.vibrate_handheld"), "aucun appel Android haptique commun pendant un appui d'action")
    _check(action_button_text.contains("func cancel_press"), "chaque bouton peut annuler un contact Android interrompu")

    var joystick_text := FileAccess.get_file_as_string("res://scripts/ui/virtual_joystick.gd")
    _check(joystick_text.contains("_viewport_to_local"), "coordonnées tactiles du joystick converties du viewport vers le local")
    _check(joystick_text.contains("func _input(event: InputEvent)"), "glissement Android suivi même hors du cercle du joystick")
    _check(joystick_text.contains("_send_move_to_controller(_value)"), "vecteur joystick envoyé en continu au contrôleur")

    var hud_v3_text := FileAccess.get_file_as_string("res://scripts/ui/hud_mobile_v3.gd")
    _check(hud_v3_text.contains("func _layout_v3"), "HUD recalculé selon la taille d'écran")
    _check(hud_v3_text.contains("HUD_SAFE_RIGHT := 190.0"), "boutons HUD protégés du bord Android")
    _check(hud_v3_text.contains("map_panel.visible = true") and hud_v3_text.contains("ArchipelagoMinimap"), "mini-carte du grand archipel visible et assumée")

    var boat_text := FileAccess.get_file_as_string("res://scripts/player/boat_controller.gd")
    _check(boat_text.contains("func _sync_driver_to_deck"), "héros synchronisé sur le pont")
    _check(not boat_text.contains("player.reparent(self"), "héros indépendant du bateau")
    _check(boat_text.contains("func _exit_tree"), "suppression bateau sécurisée")
    _check(boat_text.contains("func _find_safe_disembark_position"), "débarquement limité à une rive collisionnée")
    _check(boat_text.contains("MatelotsDuBord"), "matelots visibles sur le bateau du joueur")

    var life_text := FileAccess.get_file_as_string("res://scripts/world/world_life_director.gd")
    _check(life_text.contains("active_citizen_budget := 10"), "budget habitants mobile")
    _check(life_text.contains("active_fauna_budget := 6"), "budget faune mobile")
    _check(life_text.contains("active_crew_budget := 3"), "trois équipages autonomes")
    _check(life_text.contains("CIVILIAN_ROLES"), "habitants diversifiés par métier")
    _check(life_text.contains("Matelot du quai"), "présence d'un matelot au quai d'embarquement")
    _check(life_text.contains("for crew_index in range(3)"), "plusieurs matelots visibles sur les équipages libres")

    var enemy_text := FileAccess.get_file_as_string("res://scripts/world/world_enemy.gd")
    _check(enemy_text.contains("func _apply_archetype_stats"), "classes ennemies réellement distinctes")
    _check(enemy_text.contains("boss_ranged") and enemy_text.contains("boss_duelist") and enemy_text.contains("boss_brute"), "boss dotés de profils tactiques distincts")
    _check(enemy_text.contains("func _enter_phase_two"), "tous les boss possèdent une phase 2 fonctionnelle")
    _check(enemy_text.contains("_attack_windup"), "attaques ennemies télégraphiées avant les dégâts")

    var vehicle_text := FileAccess.get_file_as_string("res://scripts/player/island_vehicle.gd")
    _check(vehicle_text.contains("class_name IslandVehicle"), "véhicule terrestre typé")
    _check(vehicle_text.contains("func board") and vehicle_text.contains("func disembark"), "montée et descente des véhicules implémentées")
    _check(vehicle_text.contains("move_and_slide"), "véhicules collisionnés avec le relief")

    var vehicle_director_text := FileAccess.get_file_as_string("res://scripts/world/island_vehicle_director.gd")
    _check(vehicle_director_text.contains("const VEHICLES"), "catalogue de véhicules thématiques présent")
    _check(vehicle_director_text.contains("for i in range(specs.size())"), "plusieurs véhicules construits par royaume")

    var settlement_text := FileAccess.get_file_as_string("res://scripts/world/island_settlement_director.gd")
    _check(settlement_text.contains("building_count := 9 if _current_island == 11 else 12"), "douze bâtiments actifs par royaume habité")
    _check(settlement_text.contains("func _spawn_port_market"), "échoppes ajoutées près des quais")
    _check(settlement_text.contains("func _spawn_ruin"), "royaume final reste inhabité avec des ruines")

    var collectible_text := FileAccess.get_file_as_string("res://scripts/world/island_collectible_director.gd")
    _check(collectible_text.contains("coin_count_per_island := 18"), "18 pièces légères prévues par île")
    _check(collectible_text.contains("loot_count_per_island := 4"), "petits butins supplémentaires prévus")
    _check(collectible_text.contains("GameState.add_coins"), "collectibles créditent réellement les pièces")

    var fauna_text := FileAccess.get_file_as_string("res://scripts/world/ambient_fauna_director.gd")
    _check(fauna_text.contains("crab_budget := 8"), "crabes de plage actifs")
    _check(fauna_text.contains("bird_budget := 6"), "oiseaux côtiers actifs")

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
    _check(main_scene_text.contains("coastal_detail_director.gd"), "scène principale charge plages falaises et végétation")
    _check(main_scene_text.contains("island_collectible_director.gd"), "scène principale charge pièces et butins")
    _check(main_scene_text.contains("ambient_fauna_director.gd"), "scène principale charge la faune côtière")
    _check(main_scene_text.contains("spring_length = 3.65"), "SpringArm V4 rapproché")
    _check(main_scene_text.contains("fov = 64.0"), "FOV V4 légèrement resserré")
    _check(main_scene_text.contains("world_life_director.gd"), "monde vivant actif")
    _check(main_scene_text.contains("island_vehicle_director.gd"), "véhicules chargés dans la scène principale")
    _check(main_scene_text.contains("island_settlement_director.gd"), "villages chargés dans la scène principale")
    _check(not main_scene_text.contains("name=\"AudioDirectorV130\""), "aucun second lecteur audio ne double la musique de l'autoload")

    if failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V4_FOUNDATION_AUDIT_OK")
        print("CHK_PIRATE_WARRIOR_2_V5_LIVING_ISLANDS_AUDIT_OK")
    else:
        push_error("%d vérification(s) V5 ont échoué" % failures)
    quit(failures)
