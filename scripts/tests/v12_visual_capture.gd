extends SceneTree

var _output := ""

func _initialize() -> void:
    _run.call_deferred()

func _capture(filename: String) -> void:
    for _i in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png(_output.path_join(filename))
    if error != OK:
        push_error("Capture impossible : " + filename)
        quit(1)

func _run() -> void:
    _output = OS.get_environment("CHK_CAPTURE_DIR")
    if _output.is_empty():
        _output = ProjectSettings.globalize_path("user://visual_v12")
    DirAccess.make_dir_recursive_absolute(_output)
    var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    current_scene = main
    for _i in range(20):
        await process_frame
    await _capture("01-accueil.png")
    var settings := root.get_node("SettingsMenu")
    settings.open()
    await _capture("02-reglages.png")
    var tabs := settings.find_children("*", "TabContainer", true, false)[0] as TabContainer
    tabs.current_tab = 3
    await _capture("03-mises-a-jour.png")
    settings.close()
    var menu := main.get_node("MainMenu")
    menu.queue_free()
    await process_frame
    paused = false
    var hero := get_first_node_in_group("player") as Node3D
    await create_timer(4.2).timeout
    await _capture("04-jeu-camera-joueur.png")
    # Le véritable port et ses GLB intégrés, cadrés depuis une caméra de contrôle.
    var scenery := main.get_node("SceneryV12")
    var decoration := scenery.get("_scenery") as Node3D
    var arch := decoration.get_node("arche_du_port") as Node3D
    var camera := Camera3D.new()
    main.add_child(camera)
    camera.global_position = arch.global_position + Vector3(38, 22, 43)
    camera.look_at(arch.global_position + Vector3(-3, 2, -8))
    camera.far = 700.0
    camera.current = true
    await _capture("04-port-en-jeu.png")
    for layer in main.find_children("*", "CanvasLayer", true, false):
        layer.hide()
    settings.hide()
    await _capture("04-port-sans-interface.png")
    # Galerie de géométrie : même importeur et mêmes matériaux que dans le jeu.
    for layer in main.find_children("*", "CanvasLayer", true, false):
        layer.hide()
    settings.hide()
    var gallery := Node3D.new()
    main.add_child(gallery)
    gallery.position = Vector3(0, 800, 0)
    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(75, 42)
    ground.mesh = plane
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("273c49")
    ground.material_override = material
    gallery.add_child(ground)
    var models: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/decors_v12/manifest.json"))
    for i in range(models.size()):
        var model := (load("res://assets/decors_v12/" + str(models[i].file)) as PackedScene).instantiate() as Node3D
        gallery.add_child(model)
        model.position = Vector3((i % 4) * 13 - 19.5, 0, (i / 4) * 16 - 8)
        var label := Label3D.new()
        label.text = str(models[i].file).trim_suffix(".glb").replace("_", " ")
        label.font_size = 36
        label.pixel_size = 0.016
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.position = model.position + Vector3(0, 0.7, 4.0)
        gallery.add_child(label)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 32.0
    camera.far = 120.0
    camera.global_position = gallery.global_position + Vector3(8, 20, 30)
    camera.look_at(gallery.global_position + Vector3(0, 2, 0))
    await _capture("05-glb-originaux.png")
    print("CHK_V12_VISUAL_CAPTURE_OK")
    quit()
