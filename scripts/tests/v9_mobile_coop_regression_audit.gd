extends SceneTree

var failures := 0

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK V9  ", message)
    else:
        failures += 1
        push_error("ÉCHEC V9  " + message)

func _initialize() -> void:
    var hud := FileAccess.get_file_as_string("res://scripts/ui/hud_mobile.gd")
    var hero := FileAccess.get_file_as_string("res://scripts/player/hero_controller_v3.gd")
    var joystick := FileAccess.get_file_as_string("res://scripts/ui/virtual_joystick.gd")
    var network := FileAccess.get_file_as_string("res://scripts/network/network_manager.gd")
    var remote := FileAccess.get_file_as_string("res://scripts/network/remote_player_avatar.gd")
    var audio := FileAccess.get_file_as_string("res://scripts/audio/audio_director.gd")
    var vegetation := FileAccess.get_file_as_string("res://scripts/world/island_vegetation_director.gd")
    var visuals := FileAccess.get_file_as_string("res://scripts/world/visual_upgrade.gd")
    var project := FileAccess.get_file_as_string("res://project.godot")

    _check(hud.contains("var stats_panel: Panel"), "HUD de vie sans Container qui superpose les enfants")
    _check(hud.contains("var mission_panel: Panel"), "mission sans empilement titre/description")
    _check(hud.contains("var inventory_panel: Panel"), "inventaire librement positionné")

    _check(hero.contains("func _should_face_movement"), "recul visuel distinct de la marche avant")
    _check(not hero.contains("quick_turn_input_threshold"), "aucun demi-tour forcé au joystick bas maximum")
    _check(joystick.contains("response_curve := 0.88"), "réponse analogique progressive et vive")
    _check(joystick.contains("func get_input_value"), "valeur 360 degrés du joystick testable")

    _check(network.contains("PROTOCOL_VERSION := 2"), "protocole coop incompatible avec les anciens paquets incomplets")
    _check(network.contains("func _request_hero_change"), "changement de héros répliqué vers l'hôte")
    _check(network.contains("update_identity("), "avatar distant reconstruit après changement de héros")
    _check(not network.contains("_local_name = _hero_display_name"), "changement de héros sans écraser le pseudonyme")
    _check(network.contains("MOTION_INTERVAL_SECONDS := 0.05"), "mouvement coop transmis à 20 Hz")
    _check(remote.contains("func update_identity"), "identité distante modifiable à chaud")
    _check(remote.contains("_target_velocity * 0.055"), "interpolation réseau avec courte anticipation")

    _check(audio.contains("func multiplayer_music_snapshot"), "position musicale de l'hôte exportée")
    _check(audio.contains("func synchronize_multiplayer_music"), "nouveau joueur recalé sur la lecture de l'hôte")
    _check(audio.contains("_pending_music_path"), "connexion correcte même pendant un fondu musical")
    _check(network.contains("MUSIC_SYNC_INTERVAL_SECONDS := 3.0"), "dérive musicale corrigée périodiquement")

    _check(vegetation.contains("ArriveeHerbeDenseMultiMesh"), "herbe dense visible près de l'arrivée")
    _check(vegetation.contains("arrival_grass_blade_budget := 720"), "densité d'herbe suffisante sans draw calls multiples")
    _check(visuals.contains("soil_patch"), "terrain enrichi de variations de sol")
    _check(project.contains("anti_aliasing/quality/msaa_3d=1"), "anticrénelage mobile 2x activé")

    if failures == 0:
        print("CHK_PIRATE_WARRIOR_2_V9_MOBILE_COOP_GRAPHICS_OK")
    quit(failures)
