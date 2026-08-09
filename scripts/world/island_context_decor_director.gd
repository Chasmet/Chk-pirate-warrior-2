class_name IslandContextDecorDirector
extends Node3D

@export var cluster_count := 10

var _root: Node3D
var _serial := 0

func _ready() -> void:
    add_to_group("island_context_decor")
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _on_island_changed(island_id: int) -> void:
    _serial += 1
    _rebuild.call_deferred(clampi(island_id, 1, WorldCatalog.island_count()), _serial)

func _rebuild(island_id: int, serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial:
        return
    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _root = Node3D.new()
    _root.name = "DecorContexte_%02d" % island_id
    add_child(_root)

    var info := WorldCatalog.island(island_id - 1)
    var center := WorldCatalog.world_positions()[island_id - 1]
    _root.global_position = center
    var size: Vector2 = info["size"]
    var rng := RandomNumberGenerator.new()
    rng.seed = 15500 + island_id * 719

    for i in range(cluster_count):
        var angle := TAU * float(i) / float(maxi(1, cluster_count)) + rng.randf_range(-0.16, 0.16)
        var radial := rng.randf_range(0.30, 0.66)
        var x := cos(angle) * size.x * 0.5 * radial
        var z := sin(angle) * size.y * 0.5 * radial
        # Garder l'axe du port et la place d'arrivée dégagés.
        if absf(x) < 105.0 and z > size.y * 0.16:
            x += 150.0 if i % 2 == 0 else -150.0
        var y := _terrain_height(info, x, z)
        var anchor := Node3D.new()
        anchor.name = "Contexte_%02d" % i
        anchor.position = Vector3(x, y, z)
        anchor.rotation.y = rng.randf_range(0.0, TAU)
        _root.add_child(anchor)
        _build_theme_cluster(anchor, island_id, i, info, rng)

func _build_theme_cluster(parent: Node3D, island_id: int, index: int, info: Dictionary, rng: RandomNumberGenerator) -> void:
    match island_id:
        1:
            _music_cluster(parent, index, info)
        2:
            _candy_cluster(parent, index)
        3:
            _food_market_cluster(parent, index)
        4:
            _fantasy_cluster(parent, index)
        5:
            _urban_hero_cluster(parent, index)
        6:
            _creature_training_cluster(parent, index)
        7:
            _pirate_cluster(parent, index)
        8:
            _snow_cluster(parent, index)
        9:
            _fire_cluster(parent, index)
        10:
            _earth_cluster(parent, index)
        11:
            _troubled_cluster(parent, index)

func _music_cluster(parent: Node3D, index: int, info: Dictionary) -> void:
    var accent: Color = info.get("accent", Color("d7b85a"))
    for pipe in range(3):
        var h := 2.8 + float((index + pipe) % 4) * 0.9
        _cylinder(parent, "Orgue_%d" % pipe, Vector3(-1.0 + pipe, h * 0.5, 0.0), 0.18, h, accent.lightened(float(pipe) * 0.06), 0.12)
    _sphere(parent, "Note", Vector3(1.5, 1.15, 0.3), 0.46, Color("f2cf65"), 0.22)
    _cylinder(parent, "HampeNote", Vector3(1.82, 2.2, 0.3), 0.10, 2.4, Color("f2cf65"), 0.18)

func _candy_cluster(parent: Node3D, index: int) -> void:
    var colors := [Color("ff8fb5"), Color("8fdcff"), Color("fff09a"), Color("c79cff")]
    var c: Color = colors[index % colors.size()]
    _cylinder(parent, "TigeSucette", Vector3(0.0, 1.5, 0.0), 0.12, 3.0, Color("f7efe3"), 0.0)
    _sphere(parent, "Bonbon", Vector3(0.0, 3.35, 0.0), 0.90, c, 0.12)
    _sphere(parent, "BonbonSol", Vector3(1.4, 0.45, 0.6), 0.48, colors[(index + 1) % colors.size()], 0.08)

func _food_market_cluster(parent: Node3D, index: int) -> void:
    var awnings := [Color("b54f3e"), Color("e4b84b"), Color("5ca768")]
    var c: Color = awnings[index % awnings.size()]
    _box(parent, "TableMarche", Vector3(0.0, 0.75, 0.0), Vector3(3.8, 0.35, 2.0), Color("7b5332"))
    _box(parent, "Auvent", Vector3(0.0, 2.6, 0.0), Vector3(4.3, 0.28, 2.4), c)
    for i in range(3):
        _sphere(parent, "Panier_%d" % i, Vector3(-1.0 + i, 1.18, 0.0), 0.34, [Color("d96b42"), Color("8db84f"), Color("e7c657")][i], 0.0)

func _fantasy_cluster(parent: Node3D, index: int) -> void:
    var colors := [Color("6be5ff"), Color("b28cff"), Color("75ffd0")]
    for i in range(3):
        var h := 2.8 + float((index + i) % 3)
        _crystal(parent, "Cristal_%d" % i, Vector3(-1.0 + i, h * 0.5, 0.0), 0.46, h, colors[i], 0.75)
    _torus(parent, "Rune", Vector3(0.0, 0.18, 0.0), 1.8, 0.12, Color("9bdfff"), 0.45)

func _urban_hero_cluster(parent: Node3D, index: int) -> void:
    var metal := Color("596675")
    _box(parent, "BaliseUrbaine", Vector3(0.0, 1.65, 0.0), Vector3(1.0, 3.3, 1.0), metal)
    _sphere(parent, "Signal", Vector3(0.0, 3.65, 0.0), 0.42, Color("ff6158") if index % 2 == 0 else Color("65b9ff"), 0.9)
    _box(parent, "BlocVille", Vector3(1.8, 0.65, 0.4), Vector3(2.4, 1.3, 1.8), Color("3f4955"))

func _creature_training_cluster(parent: Node3D, index: int) -> void:
    var colors := [Color("f6d94e"), Color("e55d55"), Color("5fa6ed")]
    _cylinder(parent, "PoteauEntrainement", Vector3(0.0, 1.3, 0.0), 0.22, 2.6, Color("6e543b"), 0.0)
    _sphere(parent, "Orbe", Vector3(0.0, 3.0, 0.0), 0.58, colors[index % colors.size()], 0.25)
    _sphere(parent, "OrbeSol", Vector3(1.4, 0.40, 0.6), 0.38, colors[(index + 1) % colors.size()], 0.12)

func _pirate_cluster(parent: Node3D, index: int) -> void:
    _cylinder(parent, "TonneauA", Vector3(-0.65, 0.7, 0.0), 0.58, 1.4, Color("754a2b"), 0.0)
    _cylinder(parent, "TonneauB", Vector3(0.65, 0.7, 0.3), 0.58, 1.4, Color("6a4128"), 0.0)
    _cylinder(parent, "Mat", Vector3(1.9, 2.8, 0.0), 0.12, 5.6, Color("553923"), 0.0)
    _box(parent, "Drapeau", Vector3(2.55, 4.6, 0.0), Vector3(1.3, 0.75, 0.08), Color("2a2525") if index % 2 == 0 else Color("8d352f"))

func _snow_cluster(parent: Node3D, index: int) -> void:
    for i in range(3):
        var h := 2.2 + float((index + i) % 3) * 0.7
        _crystal(parent, "Glace_%d" % i, Vector3(-0.9 + i * 0.9, h * 0.5, 0.0), 0.42, h, Color("bfe9ff").darkened(float(i) * 0.06), 0.25)
    _sphere(parent, "Congere", Vector3(1.7, 0.5, 0.8), 0.72, Color("eef8ff"), 0.0)

func _fire_cluster(parent: Node3D, index: int) -> void:
    _crystal(parent, "Basalte", Vector3(-0.5, 1.7, 0.0), 0.62, 3.4, Color("292527"), 0.0)
    _crystal(parent, "Basalte2", Vector3(0.7, 1.25, 0.5), 0.48, 2.5, Color("383033"), 0.0)
    _sphere(parent, "Braise", Vector3(0.0, 0.35, -0.5), 0.50, Color("ff5a32"), 1.25)
    _torus(parent, "Fissure", Vector3(0.0, 0.12, 0.0), 1.25, 0.11, Color("ff7a2e"), 1.0)

func _earth_cluster(parent: Node3D, index: int) -> void:
    var stone := Color("716b59")
    _box(parent, "TotemA", Vector3(-0.75, 1.7, 0.0), Vector3(0.85, 3.4, 0.85), stone)
    _box(parent, "TotemB", Vector3(0.75, 1.25, 0.4), Vector3(0.75, 2.5, 0.75), stone.darkened(0.09))
    _torus(parent, "CerclePierre", Vector3(0.0, 0.18, 0.0), 1.7, 0.18, Color("9b936f"), 0.0)

func _troubled_cluster(parent: Node3D, index: int) -> void:
    _crystal(parent, "Obelisque", Vector3(0.0, 2.4, 0.0), 0.75, 4.8, Color("211c26"), 0.05)
    _torus(parent, "AnneauTrouble", Vector3(0.0, 2.9, 0.0), 1.25, 0.10, Color("d3b65b"), 0.8)
    _sphere(parent, "Lueur", Vector3(0.0, 5.05, 0.0), 0.28, Color("e9cc68"), 1.1)

func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(visual)

func _sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 10
    mesh.rings = 6
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _crystal(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = radius
    mesh.top_radius = 0.06
    mesh.height = height
    mesh.radial_segments = 6
    visual.mesh = mesh
    visual.position = pos
    visual.rotation.z = deg_to_rad(4.0)
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _torus(parent: Node3D, node_name: String, pos: Vector3, radius: float, thickness: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := TorusMesh.new()
    mesh.inner_radius = maxf(0.05, radius - thickness)
    mesh.outer_radius = radius
    mesh.rings = 16
    mesh.ring_segments = 8
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _material(color: Color, emission: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.72
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission
    return material

func _terrain_height(info: Dictionary, x: float, z: float) -> float:
    var size: Vector2 = info["size"]
    var nx := x / maxf(1.0, size.x * 0.5)
    var nz := z / maxf(1.0, size.y * 0.5)
    var radial := sqrt(nx * nx + nz * nz)
    var coast := smoothstep(1.0, 0.72, radial)

    var macro := FastNoiseLite.new()
    macro.seed = 731 + int(info["id"]) * 97
    macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    macro.frequency = 0.0035
    macro.fractal_octaves = 3
    macro.fractal_gain = 0.55

    var detail := FastNoiseLite.new()
    detail.seed = 1731 + int(info["id"]) * 131
    detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    detail.frequency = 0.0105
    detail.fractal_octaves = 4
    detail.fractal_gain = 0.48

    var hills := maxf(0.0, macro.get_noise_2d(x, z) * 0.5 + 0.5)
    hills = pow(hills, 1.65) * 38.0
    var rough := detail.get_noise_2d(x, z) * 13.0
    var ridge := absf(detail.get_noise_2d(x * 0.55 + 913.0, z * 0.55 - 441.0)) * 14.0
    var height := (hills + rough + ridge) * coast

    if radial > 0.94:
        height -= (radial - 0.94) * 145.0
    if absf(x) < 115.0 and z > size.y * 0.18:
        height *= 0.12
    if radial <= 0.94:
        height = maxf(height, -0.98)
    return height
