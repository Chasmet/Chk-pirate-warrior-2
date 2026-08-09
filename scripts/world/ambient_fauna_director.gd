class_name AmbientFaunaDirector
extends Node3D

@export var crab_budget := 8
@export var bird_budget := 6

var _root: Node3D
var _crabs: Array[Node3D] = []
var _birds: Array[Node3D] = []
var _current_island := -1
var _time := 0.0
var _serial := 0

func _ready() -> void:
    add_to_group("ambient_fauna")
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _process(delta: float) -> void:
    _time += delta
    _animate_crabs(delta)
    _animate_birds()

func _on_island_changed(island_id: int) -> void:
    _current_island = clampi(island_id, 1, WorldCatalog.island_count())
    _serial += 1
    _rebuild.call_deferred(_serial)

func _rebuild(serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial:
        return
    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _crabs.clear()
    _birds.clear()

    _root = Node3D.new()
    _root.name = "FauneAmbiante_%02d" % _current_island
    add_child(_root)

    var info := WorldCatalog.island(_current_island - 1)
    var center := WorldCatalog.world_positions()[_current_island - 1]
    _spawn_crabs(info, center)
    _spawn_birds(info, center)

func _spawn_crabs(info: Dictionary, center: Vector3) -> void:
    var size: Vector2 = info["size"]
    var rng := RandomNumberGenerator.new()
    rng.seed = 12000 + _current_island * 239
    for i in range(maxi(0, crab_budget)):
        var angle := TAU * float(i) / maxf(1.0, float(crab_budget)) + rng.randf_range(-0.18, 0.18)
        var radial := rng.randf_range(0.73, 0.88)
        var local := Vector3(cos(angle) * size.x * 0.5 * radial, 0.0, sin(angle) * size.y * 0.5 * radial)
        var world := _snap_to_ground(center + local, 0.12)
        var crab := _make_crab(i)
        crab.global_position = world
        crab.set_meta("home", world)
        crab.set_meta("phase", float(i) * 0.87)
        crab.set_meta("radius", rng.randf_range(2.2, 5.0))
        _root.add_child(crab)
        _crabs.append(crab)

func _make_crab(index: int) -> Node3D:
    var root := Node3D.new()
    root.name = "Crabe_%02d" % index

    var shell_mat := StandardMaterial3D.new()
    shell_mat.albedo_color = [Color("c4553e"), Color("d06b45"), Color("a84639")][index % 3]
    shell_mat.roughness = 0.85

    var body := MeshInstance3D.new()
    var body_mesh := SphereMesh.new()
    body_mesh.radius = 0.30
    body_mesh.height = 0.42
    body_mesh.radial_segments = 8
    body_mesh.rings = 4
    body.mesh = body_mesh
    body.scale = Vector3(1.25, 0.52, 0.88)
    body.position.y = 0.20
    body.material_override = shell_mat
    root.add_child(body)

    for side in [-1.0, 1.0]:
        for leg in range(3):
            var limb := MeshInstance3D.new()
            var limb_mesh := BoxMesh.new()
            limb_mesh.size = Vector3(0.34, 0.05, 0.07)
            limb.mesh = limb_mesh
            limb.position = Vector3(side * (0.30 + float(leg) * 0.07), 0.12, -0.15 + float(leg) * 0.15)
            limb.rotation.y = side * (0.38 + float(leg) * 0.18)
            limb.material_override = shell_mat
            root.add_child(limb)

        var claw := MeshInstance3D.new()
        var claw_mesh := SphereMesh.new()
        claw_mesh.radius = 0.12
        claw_mesh.height = 0.20
        claw_mesh.radial_segments = 6
        claw_mesh.rings = 3
        claw.mesh = claw_mesh
        claw.scale = Vector3(1.35, 0.55, 0.85)
        claw.position = Vector3(side * 0.46, 0.20, -0.25)
        claw.material_override = shell_mat
        root.add_child(claw)
    return root

func _spawn_birds(info: Dictionary, center: Vector3) -> void:
    var size: Vector2 = info["size"]
    for i in range(maxi(0, bird_budget)):
        var bird := _make_bird(i)
        bird.set_meta("center", center)
        bird.set_meta("radius_x", size.x * (0.20 + float(i % 3) * 0.05))
        bird.set_meta("radius_z", size.y * (0.18 + float((i + 1) % 3) * 0.05))
        bird.set_meta("height", 26.0 + float(i % 4) * 7.0)
        bird.set_meta("phase", TAU * float(i) / maxf(1.0, float(bird_budget)))
        bird.set_meta("speed", 0.10 + float(i % 3) * 0.025)
        _root.add_child(bird)
        _birds.append(bird)

func _make_bird(index: int) -> Node3D:
    var root := Node3D.new()
    root.name = "OiseauCotier_%02d" % index
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("e8e5dc") if index % 3 != 0 else Color("b8b9b5")
    mat.roughness = 0.92

    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.15
    body_mesh.height = 0.55
    body.mesh = body_mesh
    body.rotation.x = PI * 0.5
    body.material_override = mat
    root.add_child(body)

    for side in [-1.0, 1.0]:
        var wing := MeshInstance3D.new()
        var wing_mesh := BoxMesh.new()
        wing_mesh.size = Vector3(0.72, 0.035, 0.18)
        wing.mesh = wing_mesh
        wing.position.x = side * 0.42
        wing.rotation.z = side * 0.16
        wing.material_override = mat
        wing.set_meta("side", side)
        wing.set_meta("wing", true)
        root.add_child(wing)
    return root

func _animate_crabs(delta: float) -> void:
    for i in range(_crabs.size()):
        var crab := _crabs[i]
        if not is_instance_valid(crab):
            continue
        var home: Vector3 = crab.get_meta("home", crab.global_position)
        var phase := float(crab.get_meta("phase", 0.0))
        var radius := float(crab.get_meta("radius", 3.0))
        var target := home + Vector3(
            sin(_time * 0.55 + phase) * radius,
            0.0,
            cos(_time * 0.38 + phase) * radius * 0.45
        )
        var direction := target - crab.global_position
        direction.y = 0.0
        if direction.length_squared() > 0.01:
            crab.global_position += direction.normalized() * minf(direction.length(), delta * 0.75)
            crab.rotation.y = lerp_angle(crab.rotation.y, atan2(-direction.x, -direction.z) + PI * 0.5, minf(1.0, delta * 4.0))

func _animate_birds() -> void:
    for i in range(_birds.size()):
        var bird := _birds[i]
        if not is_instance_valid(bird):
            continue
        var center: Vector3 = bird.get_meta("center", Vector3.ZERO)
        var rx := float(bird.get_meta("radius_x", 140.0))
        var rz := float(bird.get_meta("radius_z", 120.0))
        var height := float(bird.get_meta("height", 30.0))
        var phase := float(bird.get_meta("phase", 0.0))
        var speed := float(bird.get_meta("speed", 0.12))
        var angle := _time * speed + phase
        var pos := center + Vector3(cos(angle) * rx, height + sin(angle * 2.1) * 2.2, sin(angle) * rz)
        bird.global_position = pos
        bird.rotation.y = -angle
        var flap := sin(_time * 5.5 + phase) * 0.26
        for child in bird.get_children():
            if child is MeshInstance3D and bool(child.get_meta("wing", false)):
                var side := float(child.get_meta("side", 1.0))
                child.rotation.z = side * (0.16 + flap)

func _snap_to_ground(world_position: Vector3, offset: float) -> Vector3:
    if get_world_3d() == null:
        return world_position
    var query := PhysicsRayQueryParameters3D.create(
        Vector3(world_position.x, 160.0, world_position.z),
        Vector3(world_position.x, -80.0, world_position.z),
        1
    )
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.has("position"):
        var result: Vector3 = hit["position"]
        result.y += offset
        return result
    return world_position
