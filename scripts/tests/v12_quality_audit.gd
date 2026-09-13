extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    _run.call_deferred()

func check(value: bool, label: String) -> void:
    if value:
        print("V12 OK • ", label)
    else:
        failures.append(label)
        push_error("V12 ÉCHEC • " + label)

func _run() -> void:
    var path := "user://v12_save_test.json"
    check(CHKSaveFiles.write_json(path, {"coins": 731, "hero": "yvane"}) == OK, "écriture initiale")
    check(CHKSaveFiles.write_json(path, {"coins": 812, "hero": "yvane"}) == OK, "remplacement atomique")
    check(CHKSaveFiles.read_json(path).get("coins") == 812, "nouvelle sauvegarde lisible")
    var corrupt := FileAccess.open(path, FileAccess.WRITE)
    corrupt.store_string("{interrompu")
    corrupt.close()
    check(CHKSaveFiles.read_json(path).get("coins") == 731, "récupération de la copie de secours après corruption")
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(path + suffix):
            DirAccess.remove_absolute(path + suffix)

    var settings := root.get_node("GameSettings")
    settings.set_value("sensitivity", 999)
    check(is_equal_approx(float(settings.get_value("sensitivity")), 2.0), "bornage de la sensibilité")
    settings.set_value("sensitivity", "invalide")
    check(is_equal_approx(float(settings.get_value("sensitivity")), 1.0), "réglage malformé remplacé par défaut")
    settings.set_value("quality", 0)
    check(root.msaa_3d == Viewport.MSAA_DISABLED, "mode économie appliqué au rendu")
    settings.set_value("quality", 1)
    settings.set_value("music", 0.25)
    root.get_node("AudioDirector")._update_voice_ducking(5.0)
    check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.25)), "le mixage des voix conserve le volume musique choisi")
    settings.set_value("music", 0.75)

    var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    current_scene = main
    for _i in range(12):
        await process_frame
    var menu := main.get_node("MainMenu")
    var overlay := root.get_node("SettingsMenu")
    overlay.open()
    check(paused and overlay.is_open(), "réglages accessibles depuis le menu en pause")
    overlay.close()
    check(paused, "fermer les réglages conserve la pause du menu")
    menu.get("_root").hide()
    paused = false
    var hero := get_first_node_in_group("player") as CharacterBody3D
    hero.set_physics_process(false)
    overlay.open()
    check(paused, "réglages mettent la partie solo en pause")
    overlay.close()
    check(not paused, "retour reprend la partie solo")
    Input.action_press("pause_game")
    await process_frame
    Input.action_release("pause_game")
    await process_frame
    check(paused and overlay.is_open(), "touche pause ouvre les réglages une seule fois")
    var movement := root.find_child("MovementJoystickInput", true, false) as Control
    var touch := InputEventScreenTouch.new()
    touch.index = 91
    touch.pressed = true
    touch.position = movement.global_position + movement.size * .5
    movement._input(touch)
    var drag := InputEventScreenDrag.new()
    drag.index = 91
    drag.position = touch.position + Vector2(0, 80)
    movement._input(drag)
    check(movement.get_input_value().is_zero_approx(), "les réglages bloquent les contacts destinés au joystick")
    Input.action_press("pause_game")
    await process_frame
    Input.action_release("pause_game")
    await process_frame
    check(not paused and not overlay.is_open(), "touche pause reprend sans double bascule")
    var touch_overlay := main.get_node("MobileInputOverlay")
    var layout: ConfigFile = touch_overlay.get("_layout_config")
    layout.set_value(str(movement.name), "scale", .5)
    layout.set_value(str(movement.name), "center", Vector2(.2, .7))
    touch_overlay._layout_controls()
    check(movement.size.is_equal_approx(Vector2(141, 141)), "ancienne échelle personnalisée du joystick conservée")
    layout.erase_section(str(movement.name))
    touch_overlay._layout_controls()
    var view := Rect2(Vector2(350, 310), Vector2(450, 180))
    for control in touch_overlay._editable_controls():
        check(not control.get_global_rect().intersects(view), "centre de l'écran libre : " + str(control.name))

    hero.set("_attack_lock", 0.0)
    hero.basic_attack()
    var lock: float = hero.get("_attack_lock")
    hero.basic_attack()
    hero.basic_attack()
    check(hero.get("_combo_step") == 1 and is_equal_approx(float(hero.get("_attack_lock")), lock), "touches rapides mises en file sans multiplier les attaques")
    check(int(hero.get("_queued_attack_until")) > 0, "une attaque suivante mémorisée")
    hero.set("_attack_lock", 0.0)
    hero.basic_attack()
    check(hero.get("_combo_step") == 2, "deuxième coup de combo disponible")
    check(int(hero.get("_queued_attack_until")) == 0, "attaque directe consomme l'attaque en attente")
    hero.set("_attack_lock", 0.0)
    hero.basic_attack()
    check(hero.get("_combo_step") == 3, "troisième coup de combo disponible")

    var scenery := main.get_node("SceneryV12")
    for island in range(1, 12):
        await scenery._build(island, scenery.get("_generation"))
        var decoration: Node3D = scenery.get("_scenery")
        check(decoration != null and decoration.get_child_count() == 9, "neuf placements GLB dans le royaume %d" % island)
        check(decoration.global_position.is_finite(), "origine du royaume %d valide" % island)
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/decors_v12/manifest.json"))
    check(data is Array and data.size() == 8, "huit GLB originaux embarqués")
    for entry in data:
        var model := (load("res://assets/decors_v12/" + str(entry.file)) as PackedScene).instantiate()
        check(not model.find_children("*", "MeshInstance3D", true, false).is_empty(), "géométrie réelle : " + str(entry.file))
        if bool(entry.animated):
            check(not model.find_children("*", "AnimationPlayer", true, false).is_empty(), "animation embarquée : " + str(entry.file))
        model.free()

    main.queue_free()
    await process_frame
    if failures.is_empty():
        print("CHK_V12_QUALITY_AUDIT_OK")
    quit(0 if failures.is_empty() else 1)
