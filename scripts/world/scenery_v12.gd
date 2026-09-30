extends Node3D

const ASSET_ROOT := "res://assets/decors_v12/"
var _generation := 0
var _scenery: Node3D
var _shrine: Node3D
var _rest_cooldown := 0.0
var _scan_clock := 0.0

func _ready() -> void:
    add_to_group("scenery_v12")
    GameState.island_changed.connect(_island_changed)
    GameSettings.changed.connect(_settings_changed)
    _island_changed(GameState.current_island)

func _island_changed(island_id: int) -> void:
    _generation += 1
    _build.call_deferred(island_id, _generation)

func _build(island_id: int, generation: int) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if generation != _generation or not is_inside_tree():
        return
    if is_instance_valid(_scenery):
        _scenery.queue_free()
    _shrine = null
    _scenery = Node3D.new()
    _scenery.name = "DecorOriginalV12_%02d" % island_id
    add_child(_scenery)
    _scenery.position = WorldCatalog.world_positions()[island_id - 1]
    var info := WorldCatalog.island(island_id - 1)
    var size: Vector2 = info["size"]
    var z := size.y * 0.28
    var placements := [
        ["phare_corsaire", Vector3(-36, 0, z + 14), 0.0],
        ["arche_du_port", Vector3(0, 0, z - 12), 0.0],
        ["marche_des_corsaires", Vector3(16, 0, z - 18), -0.3],
        ["reserves_du_port", Vector3(-13, 0, z - 16), 0.5],
        ["sanctuaire_des_marees", Vector3(-20, 0, z - 28), 0.0],
        ["banniere_chk", Vector3(-5, 0, z - 12), 0.0],
        ["banniere_chk", Vector3(5, 0, z - 12), 0.0],
        ["passerelle_cotiere", Vector3(24, 0, z + 12), 0.0],
        ["corail_des_abysses", Vector3(30, 0, z + 17), 0.6],
    ]
    var world := get_tree().get_first_node_in_group("world_director")
    if world == null:
        return
    for placement in placements:
        if generation != _generation:
            return
        var asset_name: String = placement[0]
        var packed := load(ASSET_ROOT + asset_name + ".glb") as PackedScene
        if packed == null:
            push_error("Décor V12 absent : " + asset_name)
            continue
        var model := packed.instantiate() as Node3D
        _scenery.add_child(model)
        model.name = asset_name
        var at: Vector3 = placement[1]
        at.y = float(world.call("_terrain_height_at", info, at.x, at.z))
        model.position = at
        model.rotation.y = float(placement[2])
        _animate_and_cull(model)
        match asset_name:
            "phare_corsaire": _collider(model, Vector3(3.4, 10, 3.4), Vector3(0, 5, 0))
            "arche_du_port":
                _collider(model, Vector3(1.5, 5, 1.8), Vector3(-3, 2.5, 0))
                _collider(model, Vector3(1.5, 5, 1.8), Vector3(3, 2.5, 0))
            "marche_des_corsaires": _collider(model, Vector3(4.5, 1.1, 1.6), Vector3(0, 0.55, .45))
            "reserves_du_port": _collider(model, Vector3(3, 1.3, 2.2), Vector3(-.3, .65, .1))
            "passerelle_cotiere": _collider(model, Vector3(3, .3, 6.6), Vector3(0, .25, 0))
            "sanctuaire_des_marees":
                _shrine = model
                var label := Label3D.new()
                label.text = "REFUGE\nSoins hors combat"
                label.font_size = 32
                label.pixel_size = .009
                label.position.y = 4.2
                label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
                label.modulate = Color("a5fff0")
                model.add_child(label)
    _settings_changed("quality", GameSettings.get_value("quality"))

func _animate_and_cull(node: Node) -> void:
    if node is AnimationPlayer:
        for animation_name in node.get_animation_list():
            if animation_name != "RESET":
                node.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
                node.play(animation_name)
                break
    if node is GeometryInstance3D:
        node.visibility_range_end = 240.0
        node.visibility_range_end_margin = 20.0
    for child in node.get_children():
        _animate_and_cull(child)

func _collider(model: Node3D, size: Vector3, center: Vector3) -> void:
    var body := StaticBody3D.new()
    var collision := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    collision.shape = box
    collision.position = center
    model.add_child(body)
    body.add_child(collision)

func _process(delta: float) -> void:
    _rest_cooldown = maxf(0.0, _rest_cooldown - delta)
    _scan_clock += delta
    if _scan_clock < 0.5 or _rest_cooldown > 0.0 or not is_instance_valid(_shrine):
        return
    _scan_clock = 0.0
    var hero := get_tree().get_first_node_in_group("player") as CharacterBody3D
    if hero == null or get_tree().get_first_node_in_group("active_controller") != null:
        return
    if hero.global_position.distance_squared_to(_shrine.global_position) > 18.0:
        return
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if is_instance_valid(enemy) and enemy is Node3D and enemy.global_position.distance_squared_to(hero.global_position) < 225.0:
            return
    if hero.health >= hero.max_health and hero.energy >= hero.max_energy:
        return
    hero.health = hero.max_health
    hero.health_changed.emit(hero.health, hero.max_health)
    hero.restore_energy(hero.max_energy)
    GameState.set_exact_snapshot(hero.global_position, hero.global_rotation.y, false)
    GameState.quick_save()
    _rest_cooldown = 30.0
    get_tree().call_group("gameplay_ux", "_show_feedback", "REFUGE • Santé et énergie restaurées")

func _settings_changed(key: String, _value: Variant) -> void:
    if key != "quality" or not is_instance_valid(_scenery):
        return
    for mesh in _scenery.find_children("*", "GeometryInstance3D", true, false):
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if int(GameSettings.get_value("quality")) == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
