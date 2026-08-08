class_name IslandCollectibleDirector
extends Node3D

@export var coin_count_per_island := 18
@export var loot_count_per_island := 4

var _root: Node3D
var _pickups: Array[Node3D] = []
var _player: Node3D
var _current_island := -1
var _time := 0.0
var _scan_timer := 0.0
var _save_timer := -1.0
var _rebuild_serial := 0

func _ready() -> void:
    add_to_group("island_collectibles")
    GameState.island_changed.connect(_on_island_changed)
    _player = get_tree().get_first_node_in_group("player") as Node3D
    _on_island_changed(GameState.current_island)

func _process(delta: float) -> void:
    _time += delta
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D

    _animate_pickups()
    _scan_timer += delta
    if _scan_timer >= 0.10:
        _scan_timer = 0.0
        _collect_nearby()

    if _save_timer >= 0.0:
        _save_timer -= delta
        if _save_timer <= 0.0:
            _save_timer = -1.0
            GameState.quick_save()

func _on_island_changed(island_id: int) -> void:
    _current_island = clampi(island_id, 1, WorldCatalog.island_count())
    _rebuild_serial += 1
    _rebuild.call_deferred(_rebuild_serial)

func _rebuild(serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _rebuild_serial:
        return

    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _pickups.clear()

    _root = Node3D.new()
    _root.name = "CollectiblesIle_%02d" % _current_island
    add_child(_root)

    var info := WorldCatalog.island(_current_island - 1)
    var center := WorldCatalog.world_positions()[_current_island - 1]
    var island_size: Vector2 = info["size"]
    var rng := RandomNumberGenerator.new()
    rng.seed = 9001 + _current_island * 313

    for i in range(coin_count_per_island):
        var key := "coin_%02d_%02d" % [_current_island, i]
        if bool(GameState.get_quest_value(key, false)):
            continue
        var local := _pick_local_position(rng, island_size, i, coin_count_per_island)
        var world := _snap_to_ground(center + local, 0.55)
        _spawn_coin(key, world, 5 + (i % 4) * 2, float(i) * 0.43)

    for i in range(loot_count_per_island):
        var key := "loot_%02d_%02d" % [_current_island, i]
        if bool(GameState.get_quest_value(key, false)):
            continue
        var angle := TAU * (float(i) / maxf(1.0, float(loot_count_per_island))) + 0.62
        var radial := 0.48 + 0.08 * float(i % 3)
        var local := Vector3(
            cos(angle) * island_size.x * 0.5 * radial,
            0.0,
            sin(angle) * island_size.y * 0.5 * radial
        )
        var world := _snap_to_ground(center + local, 0.70)
        _spawn_loot(key, world, 18 + _current_island * 2, float(i) * 1.17)

func _pick_local_position(rng: RandomNumberGenerator, island_size: Vector2, index: int, count: int) -> Vector3:
    var base_angle := TAU * float(index) / maxf(1.0, float(count))
    var angle := base_angle + rng.randf_range(-0.20, 0.20)
    var radial := rng.randf_range(0.24, 0.72)
    var x := cos(angle) * island_size.x * 0.5 * radial
    var z := sin(angle) * island_size.y * 0.5 * radial

    # Laisser le grand couloir du port lisible, mais placer quelques pièces
    # juste à côté du chemin pour apprendre naturellement le ramassage.
    if absf(x) < 72.0 and z > island_size.y * 0.18:
        x += 90.0 if index % 2 == 0 else -90.0
    return Vector3(x, 0.0, z)

func _spawn_coin(key: String, world_position: Vector3, value: int, phase: float) -> void:
    var pickup := Node3D.new()
    pickup.name = "Piece_%s" % key
    pickup.global_position = world_position
    pickup.set_meta("collect_key", key)
    pickup.set_meta("value", value)
    pickup.set_meta("kind", "coin")
    pickup.set_meta("phase", phase)
    pickup.set_meta("base_y", world_position.y)

    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.34
    mesh.bottom_radius = 0.34
    mesh.height = 0.10
    mesh.radial_segments = 16
    visual.mesh = mesh
    visual.rotation.x = PI * 0.5

    var material := StandardMaterial3D.new()
    material.albedo_color = Color("f2c94c")
    material.metallic = 0.72
    material.roughness = 0.24
    material.emission_enabled = true
    material.emission = Color("7c5208")
    material.emission_energy_multiplier = 0.55
    visual.material_override = material
    pickup.add_child(visual)

    var halo := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.48
    sphere.height = 0.96
    sphere.radial_segments = 8
    sphere.rings = 4
    halo.mesh = sphere
    halo.scale = Vector3(1.0, 0.20, 1.0)
    var halo_material := StandardMaterial3D.new()
    halo_material.albedo_color = Color(1.0, 0.77, 0.18, 0.13)
    halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    halo.material_override = halo_material
    pickup.add_child(halo)

    _root.add_child(pickup)
    _pickups.append(pickup)

func _spawn_loot(key: String, world_position: Vector3, value: int, phase: float) -> void:
    var pickup := Node3D.new()
    pickup.name = "PetitButin_%s" % key
    pickup.global_position = world_position
    pickup.set_meta("collect_key", key)
    pickup.set_meta("value", value)
    pickup.set_meta("kind", "loot")
    pickup.set_meta("phase", phase)
    pickup.set_meta("base_y", world_position.y)

    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.62, 0.52, 0.62)
    visual.mesh = mesh
    visual.rotation_degrees = Vector3(0.0, 45.0, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("9c5fd6") if _current_island % 2 == 0 else Color("43b8bd")
    material.metallic = 0.20
    material.roughness = 0.38
    material.emission_enabled = true
    material.emission = material.albedo_color.darkened(0.35)
    material.emission_energy_multiplier = 0.45
    visual.material_override = material
    pickup.add_child(visual)

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.45
    torus.outer_radius = 0.53
    torus.rings = 12
    torus.ring_segments = 6
    ring.mesh = torus
    ring.position.y = -0.28
    var ring_material := StandardMaterial3D.new()
    ring_material.albedo_color = Color("f4d46b")
    ring_material.emission_enabled = true
    ring_material.emission = Color("6d4b0c")
    ring_material.emission_energy_multiplier = 0.50
    ring.material_override = ring_material
    pickup.add_child(ring)

    _root.add_child(pickup)
    _pickups.append(pickup)

func _animate_pickups() -> void:
    for pickup in _pickups:
        if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        var phase := float(pickup.get_meta("phase", 0.0))
        var base_y := float(pickup.get_meta("base_y", pickup.global_position.y))
        var pos := pickup.global_position
        pos.y = base_y + sin(_time * 2.6 + phase) * 0.14
        pickup.global_position = pos
        pickup.rotation.y = fmod(_time * 1.65 + phase, TAU)

func _collect_nearby() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    for pickup in _pickups.duplicate():
        if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        if _player.global_position.distance_to(pickup.global_position) > 1.75:
            continue

        var key := str(pickup.get_meta("collect_key", ""))
        var value := int(pickup.get_meta("value", 1))
        var kind := str(pickup.get_meta("kind", "coin"))
        if not key.is_empty():
            GameState.set_quest_value(key, true)
        GameState.add_coins(value)
        if kind == "loot":
            GameState.add_xp(8 + _current_island * 2)
            _notify("PETIT BUTIN • +%d pièces" % value)
        _pickups.erase(pickup)
        pickup.queue_free()
        _save_timer = 0.75

func _snap_to_ground(world_position: Vector3, offset: float) -> Vector3:
    if get_world_3d() == null:
        return world_position
    var from := Vector3(world_position.x, 160.0, world_position.z)
    var to := Vector3(world_position.x, -80.0, world_position.z)
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.has("position"):
        var result: Vector3 = hit["position"]
        result.y += offset
        return result
    return world_position

func _notify(text: String) -> void:
    var world := get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("_notify"):
        world.call("_notify", text)
