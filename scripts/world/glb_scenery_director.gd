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
    _build_port_landmark(decor_root, info, island_id)
    _scatter_theme(decor_root, info, island_id)

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
