extends Node3D

const ARCHIPEL_MODEL := "res://assets/vrac/Archipel_Horizon_Simulateur.glb"
const AURORA_MODEL := "res://assets/vrac/aurora-nx7 (1).glb"
const OCTAVIUS_MODEL := "res://assets/vrac/octavius.glb"

const URBAN_ISLAND_ID := 5
const OCTAVIUS_VARIANT := 77
const HORIZON_TARGET_SIZE := 1100.0
const AURORA_TARGET_SIZE := 22.0

var _visual_root: Node3D
var _archipel_anchor: Node3D
var _aurora_anchor: Node3D
var _current_island := 1
var _serial := 0
var _flight_time := 0.0
var _flight_center := Vector3.ZERO
var _octavius_notified := false

func _ready() -> void:
    add_to_group("latest_glb_integration_v12")
    GameState.island_changed.connect(_on_island_changed)
    GameSettings.changed.connect(_on_settings_changed)
    _on_island_changed(GameState.current_island)

func _on_island_changed(island_id: int) -> void:
    _current_island = clampi(island_id, 1, WorldCatalog.island_count())
    _serial += 1
    _octavius_notified = false
    _rebuild.call_deferred(_current_island, _serial)

func _on_settings_changed(key: String, _value: Variant) -> void:
    if key != "quality":
        return
    _serial += 1
    _rebuild.call_deferred(_current_island, _serial)

func _rebuild(island_id: int, serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial or not is_inside_tree():
        return

    _clear_visuals()

    var world := get_tree().get_first_node_in_group("world_director")
    if world == null:
        await get_tree().process_frame
        world = get_tree().get_first_node_in_group("world_director")
    if world == null or serial != _serial:
        return

    _visual_root = Node3D.new()
    _visual_root.name = "DerniersGLBV12"
    add_child(_visual_root)

    var positions := WorldCatalog.world_positions()
    if island_id < 1 or island_id > positions.size():
        return
    var center: Vector3 = positions[island_id - 1]
    _flight_center = center

    var quality := int(GameSettings.get_value("quality"))
    if quality >= 1:
        _spawn_archipel_horizon(center)
        if island_id == URBAN_ISLAND_ID:
            _spawn_aurora_patrol(center)

    if island_id == URBAN_ISLAND_ID:
        _spawn_octavius_elite(world)

func _clear_visuals() -> void:
    _archipel_anchor = null
    _aurora_anchor = null
    if _visual_root != null and is_instance_valid(_visual_root):
        _visual_root.queue_free()
    _visual_root = null

func _spawn_archipel_horizon(center: Vector3) -> void:
    var result := _instantiate_normalized(ARCHIPEL_MODEL, HORIZON_TARGET_SIZE, true)
    if result.is_empty():
        push_warning("GLB horizon indisponible : " + ARCHIPEL_MODEL)
        return
    _archipel_anchor = result["anchor"] as Node3D
    var model := result["model"] as Node3D
    _archipel_anchor.name = "ArchipelHorizonSimulateur"
    _visual_root.add_child(_archipel_anchor)
    _archipel_anchor.global_position = center + Vector3(0.0, -115.0, -1450.0)
    _archipel_anchor.rotation.y = PI
    _make_decorative(model, 550.0, 4300.0)

func _spawn_aurora_patrol(center: Vector3) -> void:
    var result := _instantiate_normalized(AURORA_MODEL, AURORA_TARGET_SIZE, false)
    if result.is_empty():
        push_warning("GLB Aurora indisponible : " + AURORA_MODEL)
        return
    _aurora_anchor = result["anchor"] as Node3D
    var model := result["model"] as Node3D
    _aurora_anchor.name = "AuroraNX7Patrouille"
    _visual_root.add_child(_aurora_anchor)
    _flight_time = 0.0
    _aurora_anchor.global_position = center + Vector3(180.0, 92.0, 0.0)
    _make_decorative(model, 0.0, 1000.0)

func _spawn_octavius_elite(world: Node) -> void:
    if not ResourceLoader.exists(OCTAVIUS_MODEL) or not world.has_method("_spawn_enemy"):
        return
    var island_root := world.get("_island_root") as Node3D
    if island_root == null or not is_instance_valid(island_root):
        return
    if island_root.get_node_or_null("Ennemi_%02d" % OCTAVIUS_VARIANT) != null:
        return

    world.call(
        "_spawn_enemy",
        OCTAVIUS_MODEL,
        Vector3(62.0, 10.0, -52.0),
        false,
        2.35,
        "Octavius — Élite",
        "ranged",
        OCTAVIUS_VARIANT
    )
    var elite := island_root.get_node_or_null("Ennemi_%02d" % OCTAVIUS_VARIANT)
    if elite != null:
        elite.add_to_group("octavius_elite_v12")
        elite.set_meta("source_glb", OCTAVIUS_MODEL)
        if not _octavius_notified and world.has_method("_notify"):
            world.call("_notify", "ALERTE • Octavius patrouille le royaume urbain.")
            _octavius_notified = true

func _process(delta: float) -> void:
    if _current_island != URBAN_ISLAND_ID or _aurora_anchor == null or not is_instance_valid(_aurora_anchor):
        return
    _flight_time = fmod(_flight_time + delta, 600.0)
    var angle := _flight_time * 0.12
    var next_angle := angle + 0.035
    var current := _flight_center + Vector3(
        cos(angle) * 190.0,
        88.0 + sin(angle * 2.1) * 11.0,
        sin(angle) * 145.0
    )
    var target := _flight_center + Vector3(
        cos(next_angle) * 190.0,
        88.0 + sin(next_angle * 2.1) * 11.0,
        sin(next_angle) * 145.0
    )
    _aurora_anchor.global_position = current
    if current.distance_squared_to(target) > 0.01:
        _aurora_anchor.look_at(target, Vector3.UP, true)
        _aurora_anchor.rotate_object_local(Vector3.FORWARD, sin(angle * 1.6) * 0.06)

func _instantiate_normalized(path: String, target_size: float, align_bottom: bool) -> Dictionary:
    if not ResourceLoader.exists(path):
        return {}
    var resource := load(path)
    if not resource is PackedScene:
        return {}
    var model := (resource as PackedScene).instantiate() as Node3D
    if model == null:
        return {}

    var anchor := Node3D.new()
    anchor.add_child(model)
    add_child(anchor)
    var bounds := _visual_bounds(model)
    anchor.remove_child(model)
    remove_child(anchor)
    anchor.add_child(model)

    if not bool(bounds.get("valid", false)):
        anchor.free()
        return {}

    var box: AABB = bounds["bounds"]
    var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
    if longest <= 0.001:
        anchor.free()
        return {}

    var factor := clampf(target_size / longest, 0.0005, 120.0)
    model.scale *= Vector3.ONE * factor
    var center := box.position + box.size * 0.5
    model.position.x -= center.x * factor
    model.position.z -= center.z * factor
    model.position.y -= (box.position.y if align_bottom else center.y) * factor
    return {"anchor": anchor, "model": model}

func _make_decorative(node: Node, begin_distance: float, end_distance: float) -> void:
    if node is GeometryInstance3D:
        var geometry := node as GeometryInstance3D
        geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        geometry.visibility_range_begin = begin_distance
        geometry.visibility_range_end = end_distance
        geometry.visibility_range_begin_margin = 60.0
        geometry.visibility_range_end_margin = 100.0
    if node is CollisionObject3D:
        var collision_object := node as CollisionObject3D
        collision_object.collision_layer = 0
        collision_object.collision_mask = 0
    if node is CollisionShape3D:
        (node as CollisionShape3D).disabled = true
    if node is AnimationPlayer:
        var player := node as AnimationPlayer
        for animation_name in player.get_animation_list():
            if animation_name != "RESET":
                var animation := player.get_animation(animation_name)
                if animation != null:
                    animation.loop_mode = Animation.LOOP_LINEAR
                player.play(animation_name)
                break
    for child in node.get_children():
        _make_decorative(child, begin_distance, end_distance)

func _visual_bounds(root: Node3D) -> Dictionary:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return {"valid": false, "bounds": AABB()}
    var inverse := root.global_transform.affine_inverse()
    var minimum := Vector3(INF, INF, INF)
    var maximum := Vector3(-INF, -INF, -INF)
    var found := false
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var box := mesh_instance.get_aabb()
        var transform_to_root := inverse * mesh_instance.global_transform
        for endpoint in range(8):
            var point := transform_to_root * box.get_endpoint(endpoint)
            minimum = Vector3(minf(minimum.x, point.x), minf(minimum.y, point.y), minf(minimum.z, point.z))
            maximum = Vector3(maxf(maximum.x, point.x), maxf(maximum.y, point.y), maxf(maximum.z, point.z))
            found = true
    return {"valid": found, "bounds": AABB(minimum, maximum - minimum) if found else AABB()}

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)
