class_name GLBSceneryDirector
extends Node3D

const DECOR := "res://assets/decors_glb/glb/"
const MAX_DECOR_PER_ISLAND := 34

const PALMS := [
    DECOR + "palmier_long.glb",
    DECOR + "palmier_court.glb",
    DECOR + "palmier_detaille_long.glb",
    DECOR + "palmier_detaille_court.glb"
]
const ROCKS := [
    DECOR + "rocher_large.glb",
    DECOR + "rocher_moyen.glb",
    DECOR + "formation_pierre_grande.glb",
    DECOR + "formation_pierre_moyenne.glb"
]
const PIRATE_PROPS := [
    DECOR + "coffre_pirate.glb",
    DECOR + "canon_pirate.glb",
    DECOR + "canon_lourd.glb",
    DECOR + "canon_mobile.glb",
    DECOR + "tour_pirate.glb",
    DECOR + "pelle_tresor.glb",
    DECOR + "bouteille_pirate.glb",
    DECOR + "grande_bouteille_pirate.glb",
    DECOR + "epee_pirate_decor.glb",
    DECOR + "cimeterre_decor.glb",
    DECOR + "rame_en_bois.glb",
    DECOR + "trou_de_sable.glb"
]

var _serial: int = 0

func _ready() -> void:
    add_to_group("glb_scenery")
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _on_island_changed(island_id: int) -> void:
    _serial += 1
    call_deferred("_rebuild", clampi(island_id, 1, 11), _serial)

func _rebuild(island_id: int, serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial:
        return
    var island_root: Node3D = _active_island_root()
    if island_root == null:
        return
    var previous: Node = island_root.get_node_or_null("DecorGLBV3")
    if previous != null:
        previous.queue_free()
        await get_tree().process_frame
    if serial != _serial:
        return

    var decor_root: Node3D = Node3D.new()
    decor_root.name = "DecorGLBV3"
    island_root.add_child(decor_root)

    var info: Dictionary = WorldCatalog.island(island_id - 1)
    if island_id == 1:
        _build_musical_arrival(decor_root, info)
    _build_port_landmark(decor_root, info, island_id)
    _scatter_theme(decor_root, info, island_id)

func _build_musical_arrival(parent: Node3D, info: Dictionary) -> void:
    var musical_root := Node3D.new()
    musical_root.name = "AccordiaMusicale"
    parent.add_child(musical_root)

    var size: Vector2 = info["size"]
    var port_z := size.y * 0.45
    var arrival_z := size.y * 0.34
    _build_harp_gate(musical_root, info, port_z - 4.0)
    _build_piano_promenade(musical_root, info, arrival_z + 14.0, port_z - 20.0)
    _build_accordia_city(musical_root, info, arrival_z - 78.0)
    _build_resonance_monument(musical_root, info, -size.y * 0.05)

func _build_harp_gate(parent: Node3D, info: Dictionary, z: float) -> void:
    var base_y := maxf(_terrain_height(info, -13.0, z), _terrain_height(info, 13.0, z))
    var gold := Color("d8a93e")
    var dark_gold := Color("936622")
    _add_landmark_box(parent, "ArcheHarpe_Gauche", Vector3(-13.0, base_y + 9.0, z), Vector3(1.7, 18.0, 1.8), gold, Vector3.ZERO, true)
    _add_landmark_box(parent, "ArcheHarpe_Droite", Vector3(13.0, base_y + 9.0, z), Vector3(1.7, 18.0, 1.8), gold, Vector3.ZERO, true)
    _add_landmark_box(parent, "ArcheHarpe_SommetG", Vector3(-6.5, base_y + 17.2, z), Vector3(14.0, 1.5, 1.8), gold, Vector3(0.0, 0.0, deg_to_rad(-12.0)), true)
    _add_landmark_box(parent, "ArcheHarpe_SommetD", Vector3(6.5, base_y + 17.2, z), Vector3(14.0, 1.5, 1.8), gold, Vector3(0.0, 0.0, deg_to_rad(12.0)), true)
    for i in range(9):
        var string_x := -8.0 + float(i) * 2.0
        var string_height := 8.0 + (8.0 - absf(string_x)) * 0.58
        _add_landmark_cylinder(
            parent,
            "CordeHarpe_%02d" % i,
            Vector3(string_x, base_y + 4.0 + string_height * 0.5, z),
            0.09,
            string_height,
            Color("f8df83"),
            false
        )
    _add_landmark_box(parent, "SeuilHarpe", Vector3(0.0, base_y + 0.2, z), Vector3(29.0, 0.45, 4.0), dark_gold, Vector3.ZERO, true)
    _add_world_label(parent, "PORT D’ACCORDIA", Vector3(0.0, base_y + 20.8, z), Color("ffe9a0"))

func _build_piano_promenade(parent: Node3D, info: Dictionary, start_z: float, end_z: float) -> void:
    var center_z := (start_z + end_z) * 0.5
    var base_y := _terrain_height(info, 0.0, center_z)
    _add_landmark_box(
        parent,
        "PontPiano_Collision",
        Vector3(0.0, base_y - 0.15, center_z),
        Vector3(16.0, 0.55, end_z - start_z + 5.0),
        Color("493b35"),
        Vector3.ZERO,
        true
    )
    var key_count := 18
    var key_step := (end_z - start_z) / float(key_count - 1)
    var black_pattern := [1, 3, 6, 8, 10, 13, 15]
    for i in range(key_count):
        var key_z := start_z + float(i) * key_step
        _add_landmark_box(
            parent,
            "PontPiano_ToucheBlanche_%02d" % i,
            Vector3(0.0, base_y + 0.22, key_z),
            Vector3(15.0, 0.22, maxf(2.8, key_step - 0.22)),
            Color("f2ead7"),
            Vector3.ZERO,
            false
        )
        if i in black_pattern:
            _add_landmark_box(
                parent,
                "PontPiano_ToucheNoire_%02d" % i,
                Vector3(4.2, base_y + 0.43, key_z + key_step * 0.22),
                Vector3(6.1, 0.28, maxf(1.7, key_step * 0.55)),
                Color("211f25"),
                Vector3.ZERO,
                false
            )

func _build_accordia_city(parent: Node3D, info: Dictionary, city_z: float) -> void:
    var city_root := Node3D.new()
    city_root.name = "Accordia"
    parent.add_child(city_root)
    var district_colors := [Color("b76873"), Color("4d8795"), Color("c39445"), Color("755f9a")]
    for i in range(16):
        var side := -1.0 if i % 2 == 0 else 1.0
        var row := float(i / 2)
        var x := side * (29.0 + float(i % 4) * 10.0)
        var z := city_z - row * 11.0
        var ground_y := _terrain_height(info, x, z)
        var building_height := 8.0 + float(i % 4) * 2.4
        var color: Color = district_colors[i % district_colors.size()]
        _add_landmark_box(
            city_root,
            "MaisonMusicale_%02d" % i,
            Vector3(x, ground_y + building_height * 0.5, z),
            Vector3(13.0, building_height, 9.0),
            color,
            Vector3.ZERO,
            true
        )
        _add_landmark_cylinder(
            city_root,
            "ToitMaison_%02d" % i,
            Vector3(x, ground_y + building_height + 2.2, z),
            5.2,
            4.4,
            color.lightened(0.22),
            false,
            0.35
        )

    var amphitheater_z := city_z + 20.0
    for tier in range(3):
        var radius := 20.0 + float(tier) * 7.0
        for seat in range(9):
            var angle := lerpf(-2.55, -0.59, float(seat) / 8.0)
            var x := cos(angle) * radius
            var z := amphitheater_z + sin(angle) * radius
            var y := _terrain_height(info, x, z) + float(tier) * 0.75
            _add_landmark_box(
                city_root,
                "Amphitheatre_%d_%02d" % [tier, seat],
                Vector3(x, y + 0.35, z),
                Vector3(7.8, 0.7, 3.0),
                Color("cdbb91"),
                Vector3(0.0, -angle - PI * 0.5, 0.0),
                true
            )

    var conservatory_z := city_z - 102.0
    var conservatory_y := _terrain_height(info, 0.0, conservatory_z)
    _add_landmark_box(parent, "GrandConservatoire", Vector3(0.0, conservatory_y + 9.0, conservatory_z), Vector3(62.0, 18.0, 31.0), Color("d8c9a4"), Vector3.ZERO, true)
    for column in range(7):
        _add_landmark_cylinder(parent, "ColonneConservatoire_%02d" % column, Vector3(-21.0 + float(column) * 7.0, conservatory_y + 8.0, conservatory_z + 17.0), 0.8, 16.0, Color("eee3c7"), true)
    _add_landmark_cylinder(parent, "DomeConservatoire", Vector3(0.0, conservatory_y + 21.0, conservatory_z), 11.0, 8.0, Color("c49a45"), false, 5.0)
    _add_world_label(parent, "ACCORDIA", Vector3(0.0, conservatory_y + 25.5, conservatory_z + 1.0), Color("fff1bb"))

func _build_resonance_monument(parent: Node3D, info: Dictionary, z: float) -> void:
    var base_y := _terrain_height(info, 0.0, z)
    var heights := [34.0, 43.0, 54.0, 68.0, 76.0, 68.0, 54.0, 43.0, 34.0]
    for i in range(heights.size()):
        var height: float = heights[i]
        var x := -32.0 + float(i) * 8.0
        _add_landmark_cylinder(
            parent,
            "OrgueMontResonance_%02d" % i,
            Vector3(x, base_y + height * 0.5, z),
            3.0,
            height,
            Color("655b6e").lightened(float(i % 3) * 0.07),
            true
        )
    _add_world_label(parent, "MONT DE LA RÉSONANCE", Vector3(0.0, base_y + 84.0, z), Color("d9c8ff"))

func _add_landmark_box(parent: Node3D, node_name: String, center: Vector3, box_size: Vector3, color: Color, rotation_value: Vector3, solid: bool) -> void:
    var anchor := StaticBody3D.new()
    anchor.name = node_name
    anchor.position = center
    anchor.rotation = rotation_value
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    visual.mesh = mesh
    visual.material_override = _landmark_material(color)
    anchor.add_child(visual)
    if solid:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = box_size
        collision.shape = shape
        anchor.add_child(collision)
    parent.add_child(anchor)

func _add_landmark_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color, solid: bool, top_radius: float = -1.0) -> void:
    var anchor := StaticBody3D.new()
    anchor.name = node_name
    anchor.position = center
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = radius
    mesh.top_radius = radius if top_radius < 0.0 else top_radius
    mesh.height = height
    mesh.radial_segments = 12
    visual.mesh = mesh
    visual.material_override = _landmark_material(color)
    anchor.add_child(visual)
    if solid:
        var collision := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = height
        collision.shape = shape
        anchor.add_child(collision)
    parent.add_child(anchor)

func _landmark_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.76
    material.metallic = 0.14 if color.r > 0.65 and color.g > 0.45 else 0.02
    return material

func _add_world_label(parent: Node3D, value: String, position_value: Vector3, color: Color) -> void:
    var label := Label3D.new()
    label.name = value.to_snake_case().capitalize().replace(" ", "")
    label.text = value
    label.position = position_value
    label.font_size = 64
    label.pixel_size = 0.018
    label.modulate = color
    label.outline_size = 12
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)

func _active_island_root() -> Node3D:
    var world: Node = get_tree().get_first_node_in_group("world_director")
    if world == null:
        return null
    for child in world.get_children():
        if child is Node3D and str(child.name).begins_with("Royaume_"):
            return child as Node3D
    return null

func _build_port_landmark(parent: Node3D, info: Dictionary, island_id: int) -> void:
    var size: Vector2 = info["size"]
    var port_z: float = size.y * 0.45

    # Couloir central volontairement libre pour que le joueur puisse courir du quai vers l'île.
    if island_id != 8 and island_id != 9 and island_id != 11:
        _spawn_glb(parent, str(PALMS[0]), _ground(info, -25.0, port_z - 8.0), 6.5, 0.15, false)
        _spawn_glb(parent, str(PALMS[1]), _ground(info, 25.0, port_z - 5.0), 5.2, -0.20, false)

    _spawn_glb(parent, DECOR + "coffre_pirate.glb", _ground(info, 11.0, port_z + 7.0), 1.5, 0.35, false)
    _spawn_glb(parent, DECOR + "canon_pirate.glb", _ground(info, -14.0, port_z + 3.0), 2.6, -0.35, true)
    _spawn_glb(parent, DECOR + "canon_lourd.glb", _ground(info, 15.5, port_z - 12.0), 3.0, 0.30, true)

    var tower_z: float = size.y * 0.30
    var tower_x: float = -34.0 if island_id % 2 == 0 else 34.0
    _spawn_glb(parent, DECOR + "tour_pirate.glb", _ground(info, tower_x, tower_z), 9.5, 0.0, true)

    _spawn_glb(parent, DECOR + "bouteille_pirate.glb", _ground(info, -8.5, port_z + 10.0), 0.75, 0.6, false)
    _spawn_glb(parent, DECOR + "rame_en_bois.glb", _ground(info, 8.5, port_z + 10.0), 2.4, -0.8, false)

func _scatter_theme(parent: Node3D, info: Dictionary, island_id: int) -> void:
    var size: Vector2 = info["size"]
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 9701 + island_id * 541
    var budget: int = 7

    var foliage_allowed: bool = island_id not in [8, 9, 11]
    if foliage_allowed:
        for i in range(10):
            if budget >= MAX_DECOR_PER_ISLAND:
                break
            var x: float = rng.randf_range(-size.x * 0.37, size.x * 0.37)
            var z: float = rng.randf_range(-size.y * 0.32, size.y * 0.26)
            if absf(x) < 18.0 and z > size.y * 0.18:
                x += 28.0 if x >= 0.0 else -28.0
            var path: String = str(PALMS[i % PALMS.size()]) if i < 6 else DECOR + "plante_tropicale.glb"
            var target: float = rng.randf_range(4.4, 7.0) if i < 6 else rng.randf_range(1.2, 2.0)
            _spawn_glb(parent, path, _ground(info, x, z), target, rng.randf_range(0.0, TAU), false)
            budget += 1

    var rock_count: int = 15 if island_id in [8, 9, 10, 11] else 10
    for i in range(rock_count):
        if budget >= MAX_DECOR_PER_ISLAND:
            break
        var angle: float = rng.randf_range(0.0, TAU)
        var rx: float = rng.randf_range(size.x * 0.20, size.x * 0.40)
        var rz: float = rng.randf_range(size.y * 0.18, size.y * 0.38)
        var x: float = cos(angle) * rx
        var z: float = sin(angle) * rz
        var target: float = rng.randf_range(2.2, 5.0)
        _spawn_glb(parent, str(ROCKS[i % ROCKS.size()]), _ground(info, x, z), target, rng.randf_range(0.0, TAU), true)
        budget += 1

    var extra: Array = _theme_props(island_id)
    for i in range(extra.size()):
        if budget >= MAX_DECOR_PER_ISLAND:
            break
        var path: String = str(extra[i])
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var x: float = side * rng.randf_range(size.x * 0.10, size.x * 0.30)
        var z: float = rng.randf_range(-size.y * 0.25, size.y * 0.18)
        var target: float = 2.7
        if path.ends_with("tour_pirate.glb"):
            target = 9.0
        elif path.ends_with("trou_de_sable.glb"):
            target = 4.0
        elif path.ends_with("coffre_pirate.glb"):
            target = 1.5
        _spawn_glb(parent, path, _ground(info, x, z), target, rng.randf_range(0.0, TAU), path.contains("canon") or path.ends_with("tour_pirate.glb"))
        budget += 1

func _theme_props(island_id: int) -> Array:
    match island_id:
        1:
            return [DECOR + "grande_bouteille_pirate.glb", DECOR + "coffre_pirate.glb", DECOR + "pelle_tresor.glb"]
        2:
            return [DECOR + "bouteille_pirate.glb", DECOR + "grande_bouteille_pirate.glb", DECOR + "coffre_pirate.glb"]
        3:
            return [DECOR + "coffre_pirate.glb", DECOR + "rame_en_bois.glb", DECOR + "pelle_tresor.glb"]
        4:
            return [DECOR + "tour_pirate.glb", DECOR + "epee_pirate_decor.glb", DECOR + "cimeterre_decor.glb"]
        5:
            return [DECOR + "canon_mobile.glb", DECOR + "canon_lourd.glb", DECOR + "coffre_pirate.glb"]
        6:
            return [DECOR + "trou_de_sable.glb", DECOR + "pelle_tresor.glb", DECOR + "coffre_pirate.glb"]
        7:
            return [DECOR + "canon_pirate.glb", DECOR + "canon_lourd.glb", DECOR + "tour_pirate.glb", DECOR + "coffre_pirate.glb"]
        8:
            return [DECOR + "tour_pirate.glb", DECOR + "epee_pirate_decor.glb", DECOR + "coffre_pirate.glb"]
        9:
            return [DECOR + "canon_lourd.glb", DECOR + "canon_mobile.glb", DECOR + "cimeterre_decor.glb"]
        10:
            return [DECOR + "pelle_tresor.glb", DECOR + "trou_de_sable.glb", DECOR + "tour_pirate.glb"]
        11:
            return [DECOR + "tour_pirate.glb", DECOR + "canon_lourd.glb", DECOR + "epee_pirate_decor.glb", DECOR + "cimeterre_decor.glb"]
        _:
            return PIRATE_PROPS.slice(0, 3)

func _ground(info: Dictionary, x: float, z: float) -> Vector3:
    return Vector3(x, _terrain_height(info, x, z), z)

func _terrain_height(info: Dictionary, x: float, z: float) -> float:
    var size: Vector2 = info["size"]
    var nx: float = x / maxf(1.0, size.x * 0.5)
    var nz: float = z / maxf(1.0, size.y * 0.5)
    var radial: float = sqrt(nx * nx + nz * nz)
    var coast: float = smoothstep(1.0, 0.72, radial)
    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = 731 + int(info["id"]) * 97
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.0065
    noise.fractal_octaves = 4
    noise.fractal_gain = 0.52
    var raw: float = noise.get_noise_2d(x, z)
    var ridge: float = absf(noise.get_noise_2d(x * 0.42 + 913.0, z * 0.42 - 441.0))
    var height: float = (raw * 28.0 + ridge * 16.0) * coast
    if radial > 0.94:
        height -= (radial - 0.94) * 145.0
    if absf(x) < 115.0 and z > size.y * 0.18:
        height *= 0.12
    return height

func _spawn_glb(parent: Node3D, path: String, ground_position: Vector3, target_size: float, yaw: float, solid: bool) -> void:
    if not ResourceLoader.exists(path):
        return
    var resource: Resource = load(path)
    if not resource is PackedScene:
        return
    var instance: Node3D = (resource as PackedScene).instantiate() as Node3D
    if instance == null:
        return

    var anchor: Node3D = Node3D.new()
    anchor.name = path.get_file().get_basename()
    anchor.position = ground_position
    anchor.rotation.y = yaw
    parent.add_child(anchor)
    anchor.add_child(instance)

    var bounds: Dictionary = _visual_bounds(instance)
    if not bool(bounds.get("valid", false)):
        anchor.queue_free()
        return
    var box: AABB = bounds["bounds"]
    var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
    if longest <= 0.001:
        anchor.queue_free()
        return
    var factor: float = clampf(target_size / longest, 0.001, 80.0)
    instance.scale *= Vector3.ONE * factor
    var center: Vector3 = box.position + box.size * 0.5
    instance.position += Vector3(-center.x * factor, -box.position.y * factor, -center.z * factor)

    if solid:
        var scaled_size: Vector3 = box.size * factor
        _add_simple_collision(anchor, scaled_size)

func _add_simple_collision(anchor: Node3D, visual_size: Vector3) -> void:
    var safe_size: Vector3 = Vector3(
        clampf(visual_size.x * 0.62, 0.7, 5.0),
        clampf(visual_size.y * 0.78, 0.8, 10.0),
        clampf(visual_size.z * 0.62, 0.7, 5.0)
    )
    var body: StaticBody3D = StaticBody3D.new()
    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = safe_size
    collision.shape = shape
    collision.position.y = safe_size.y * 0.5
    body.add_child(collision)
    anchor.add_child(body)

func _visual_bounds(root: Node3D) -> Dictionary:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return {"valid": false, "bounds": AABB()}
    var inverse: Transform3D = root.global_transform.affine_inverse()
    var minimum: Vector3 = Vector3(INF, INF, INF)
    var maximum: Vector3 = Vector3(-INF, -INF, -INF)
    var found: bool = false
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var local_box: AABB = mesh_instance.get_aabb()
        var transform_to_root: Transform3D = inverse * mesh_instance.global_transform
        for i in range(8):
            var point: Vector3 = transform_to_root * local_box.get_endpoint(i)
            minimum = Vector3(minf(minimum.x, point.x), minf(minimum.y, point.y), minf(minimum.z, point.z))
            maximum = Vector3(maxf(maximum.x, point.x), maxf(maximum.y, point.y), maxf(maximum.z, point.z))
            found = true
    return {"valid": found, "bounds": AABB(minimum, maximum - minimum) if found else AABB()}

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)
