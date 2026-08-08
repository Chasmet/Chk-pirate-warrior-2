class_name BoatController
extends CharacterBody3D

@export var model_path := "res://assets/bateaux_glb/glb/navire_pirate_clair.glb"
@export var cruise_speed := 24.0
@export var boost_speed := 38.0
@export var turn_speed := 1.45
@export var water_height := -0.55
@export var boarding_radius := 9.0

var _virtual_move := Vector2.ZERO
var _driver: CharacterBody3D
var _driver_collision: CollisionShape3D
var _visual: Node3D
var _bobbing_time := 0.0
var _forward_speed := 0.0
var _steering_velocity := 0.0
var _snapshot_accumulator := 0.0

func _ready() -> void:
    add_to_group("boat")
    _load_visual()

func _exit_tree() -> void:
    if not is_boarded():
        return
    var player: CharacterBody3D = _driver
    if _driver_collision != null and is_instance_valid(_driver_collision):
        _driver_collision.set_deferred("disabled", false)
    if player != null and is_instance_valid(player):
        player.set_physics_process(true)
        player.velocity = Vector3.ZERO
        if player.is_inside_tree():
            player.global_position = global_position + Vector3.UP * 2.0
            player.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
            GameState.set_exact_snapshot(player.global_position, player.global_rotation.y, false)
    _driver = null
    _driver_collision = null
    _virtual_move = Vector2.ZERO

func setup(path: String) -> void:
    model_path = path
    if is_inside_tree():
        _load_visual()

func set_virtual_move(value: Vector2) -> void:
    _virtual_move = value.limit_length(1.0)

func is_boarded() -> bool:
    return _driver != null and is_instance_valid(_driver)

func try_interact(player: CharacterBody3D) -> bool:
    if is_boarded():
        disembark()
        return true
    if player == null or global_position.distance_to(player.global_position) > boarding_radius:
        return false
    board(player)
    return true

func board(player: CharacterBody3D) -> void:
    if player == null or is_boarded():
        return
    _driver = player
    _driver_collision = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if _driver_collision != null:
        _driver_collision.set_deferred("disabled", true)
    player.set_physics_process(false)
    player.velocity = Vector3.ZERO
    _forward_speed = 0.0
    _steering_velocity = 0.0
    _snapshot_accumulator = 0.0
    add_to_group("active_controller")
    _sync_driver_to_deck()
    GameState.set_exact_snapshot(global_position, rotation.y, true)

func disembark() -> void:
    if not is_boarded():
        return
    var player: CharacterBody3D = _driver
    var landing := _find_safe_disembark_position()
    if not bool(landing.get("found", false)):
        _show_disembark_warning()
        return
    _release_driver_at(player, landing["position"], global_rotation.y, true)

func force_disembark_at(world_position: Vector3, yaw: float = 0.0) -> bool:
    if not is_boarded():
        return false
    _release_driver_at(_driver, world_position, yaw, false)
    return true

func _release_driver_at(player: CharacterBody3D, world_position: Vector3, yaw: float, save_now: bool) -> void:
    if _driver_collision != null:
        _driver_collision.set_deferred("disabled", false)
    player.global_position = world_position
    player.global_rotation = Vector3(0.0, yaw, 0.0)
    player.velocity = Vector3.ZERO
    player.set_physics_process(true)
    remove_from_group("active_controller")
    GameState.set_exact_snapshot(player.global_position, player.global_rotation.y, false)
    if save_now:
        GameState.quick_save()
    _driver = null
    _driver_collision = null
    _virtual_move = Vector2.ZERO
    _forward_speed = 0.0
    _steering_velocity = 0.0
    _snapshot_accumulator = 0.0

func _find_safe_disembark_position() -> Dictionary:
    var space := get_world_3d().direct_space_state
    var right := global_transform.basis.x.normalized()
    var forward := -global_transform.basis.z.normalized()
    var offsets: Array[Vector3] = [
        -right * 4.8 + forward * 5.0,
        right * 4.8 + forward * 5.0,
        -right * 5.4,
        right * 5.4
    ]
    for offset: Vector3 in offsets:
        var ray_start: Vector3 = global_position + offset + Vector3.UP * 12.0
        var ray_end: Vector3 = ray_start + Vector3.DOWN * 28.0
        var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
        query.exclude = [get_rid()]
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            continue
        var point: Vector3 = hit.get("position", Vector3.ZERO)
        if point.y <= water_height + 0.35:
            continue
        return {"found": true, "position": point + Vector3.UP * 1.05}
    return {"found": false}

func _show_disembark_warning() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.show_subtitle("Approche le bateau d’un quai ou d’une rive pour débarquer.", 2.4)

func force_reposition(world_position: Vector3, yaw: float) -> void:
    global_position = Vector3(world_position.x, water_height, world_position.z)
    rotation = Vector3(0.0, yaw, 0.0)
    velocity = Vector3.ZERO
    _forward_speed = 0.0
    _steering_velocity = 0.0
    _virtual_move = Vector2.ZERO
    _sync_driver_to_deck()
    GameState.set_exact_snapshot(global_position, rotation.y, is_boarded())

func _physics_process(delta: float) -> void:
    _bobbing_time += delta
    var wave := sin(_bobbing_time * 1.7) * 0.10 + sin(_bobbing_time * 0.73 + global_position.x * 0.002) * 0.035
    global_position.y = water_height + wave
    if not is_boarded():
        _forward_speed = move_toward(_forward_speed, 0.0, 3.5 * delta)
        velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
        _animate_hull(0.0, 0.0, delta)
        move_and_slide()
        return

    var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := _virtual_move if _virtual_move.length() >= keyboard.length() else keyboard
    var throttle := clampf(-input_vec.y, -0.42, 1.0)
    var steering := clampf(input_vec.x, -1.0, 1.0)
    var upgrade_factor := 1.0 + float(maxi(0, GameState.boat_level - 1)) * 0.075
    var maximum_speed := (boost_speed if Input.is_action_pressed("dodge") else cruise_speed) * upgrade_factor
    var reverse_speed := maximum_speed * 0.30
    var target_speed := throttle * (maximum_speed if throttle >= 0.0 else reverse_speed)

    var acceleration := (9.0 + float(GameState.boat_level) * 0.8) if absf(throttle) > 0.05 else 4.8
    _forward_speed = move_toward(_forward_speed, target_speed, acceleration * delta)
    var speed_ratio := clampf(absf(_forward_speed) / maxf(maximum_speed, 0.1), 0.0, 1.0)

    var steering_grip := lerpf(0.36, 1.0, smoothstep(0.03, 0.72, speed_ratio))
    if absf(_forward_speed) < 0.8:
        steering_grip = maxf(steering_grip, 0.24)
    var reverse_sign := -1.0 if _forward_speed < -0.25 else 1.0
    var target_turn := steering * turn_speed * steering_grip * reverse_sign * (1.0 + float(GameState.boat_level - 1) * 0.025)
    _steering_velocity = move_toward(_steering_velocity, target_turn, 3.1 * delta)
    rotation.y -= _steering_velocity * delta

    var forward := -global_transform.basis.z
    var target_velocity := forward * _forward_speed
    var hull_response := lerpf(5.2, 8.6, speed_ratio)
    velocity.x = move_toward(velocity.x, target_velocity.x, hull_response * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, hull_response * delta)
    velocity.y = 0.0
    move_and_slide()
    _animate_hull(steering, speed_ratio, delta)
    _sync_driver_to_deck()

    _snapshot_accumulator += delta
    if _snapshot_accumulator >= 0.20:
        _snapshot_accumulator = 0.0
        GameState.set_exact_snapshot(global_position, rotation.y, true)

    if Input.is_action_just_pressed("interact"):
        disembark()

func _sync_driver_to_deck() -> void:
    if not is_boarded():
        return
    var deck_local := Vector3(0.0, 1.25, 0.25)
    _driver.global_position = global_transform * deck_local
    _driver.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
    _driver.velocity = Vector3.ZERO

func _animate_hull(steering: float, speed_ratio: float, delta: float) -> void:
    if _visual == null or not is_instance_valid(_visual):
        return
    var target_roll := -steering * 0.075 * speed_ratio + sin(_bobbing_time * 1.35) * 0.012
    var target_pitch := sin(_bobbing_time * 1.05 + 0.7) * (0.012 + speed_ratio * 0.018)
    _visual.rotation.z = lerpf(_visual.rotation.z, target_roll, 1.0 - exp(-3.2 * delta))
    _visual.rotation.x = lerpf(_visual.rotation.x, target_pitch, 1.0 - exp(-2.8 * delta))

func _load_visual() -> void:
    if _visual != null and is_instance_valid(_visual):
        _visual.queue_free()
    _visual = null
    if not ResourceLoader.exists(model_path):
        _create_fallback_visual()
        return
    var resource: Resource = load(model_path)
    if resource is PackedScene:
        var instance: Node = (resource as PackedScene).instantiate()
        if instance is Node3D:
            _visual = instance as Node3D
            add_child(_visual)
            _normalize_visual(_visual)
        else:
            instance.queue_free()
            _create_fallback_visual()
    else:
        _create_fallback_visual()

func _normalize_visual(root: Node3D) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return
    var min_corner := Vector3(INF, INF, INF)
    var max_corner := Vector3(-INF, -INF, -INF)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var box := mesh_instance.get_aabb()
        var transform := root.global_transform.affine_inverse() * mesh_instance.global_transform
        for i in range(8):
            var point: Vector3 = transform * box.get_endpoint(i)
            min_corner = Vector3(minf(min_corner.x, point.x), minf(min_corner.y, point.y), minf(min_corner.z, point.z))
            max_corner = Vector3(maxf(max_corner.x, point.x), maxf(max_corner.y, point.y), maxf(max_corner.z, point.z))
    var size := max_corner - min_corner
    if size.length() <= 0.01:
        return
    var longest := maxf(size.x, size.z)
    var factor := clampf(12.0 / maxf(0.1, longest), 0.02, 12.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= min_corner.y * factor

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _create_fallback_visual() -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(4.0, 1.2, 9.0)
    mesh_instance.mesh = mesh
    mesh_instance.position.y = 0.7
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("583b28")
    mesh_instance.material_override = material
    add_child(mesh_instance)
    _visual = mesh_instance
