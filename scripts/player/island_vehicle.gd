class_name IslandVehicle
extends CharacterBody3D

@export var vehicle_name := "Véhicule d'île"
@export var style_key := "cart"
@export var main_color := Color("68462d")
@export var accent_color := Color("e0b44f")
@export var maximum_speed := 15.0
@export var reverse_speed := 5.0
@export var acceleration := 10.0
@export var turn_speed := 1.75
@export var interaction_radius := 6.5

var _driver: CharacterBody3D
var _driver_collision: CollisionShape3D
var _virtual_move := Vector2.ZERO
var _current_speed := 0.0
var _visual_root: Node3D
var _wheels: Array[Node3D] = []
var _horse_legs: Array[Node3D] = []
var _snapshot_accumulator := 0.0
var _animation_time := 0.0

func configure(spec: Dictionary) -> void:
    vehicle_name = str(spec.get("name", vehicle_name))
    style_key = str(spec.get("style", style_key))
    main_color = spec.get("main_color", main_color)
    accent_color = spec.get("accent_color", accent_color)
    maximum_speed = float(spec.get("maximum_speed", maximum_speed))
    reverse_speed = float(spec.get("reverse_speed", reverse_speed))
    acceleration = float(spec.get("acceleration", acceleration))
    turn_speed = float(spec.get("turn_speed", turn_speed))
    if is_inside_tree():
        _ensure_collision()
        _build_visual()

func _ready() -> void:
    add_to_group("island_vehicle")
    floor_snap_length = 0.8
    floor_max_angle = deg_to_rad(48.0)
    safe_margin = 0.08
    _ensure_collision()
    _build_visual()

func _exit_tree() -> void:
    if not is_boarded():
        return
    var player := _driver
    if player != null and is_instance_valid(player) and player.has_method("clear_mounted_pose"):
        player.call("clear_mounted_pose")
    if _driver_collision != null and is_instance_valid(_driver_collision):
        _driver_collision.set_deferred("disabled", false)
    if player != null and is_instance_valid(player):
        player.set_physics_process(true)
        player.velocity = Vector3.ZERO
        if player.is_inside_tree():
            player.global_position = global_position + Vector3.UP * 2.0
            player.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
    remove_from_group("active_controller")
    _driver = null
    _driver_collision = null
    _virtual_move = Vector2.ZERO

func set_virtual_move(value: Vector2) -> void:
    _virtual_move = value.limit_length(1.0)

func is_boarded() -> bool:
    return _driver != null and is_instance_valid(_driver)

func camera_distance() -> float:
    match style_key:
        "4x4": return 7.1
        "quad": return 5.8
        "horse": return 5.5
        _: return 6.2

func camera_height() -> float:
    match style_key:
        "4x4": return 2.55
        "horse": return 2.45
        "quad": return 2.05
        _: return 2.15

func try_interact(player: CharacterBody3D) -> bool:
    if is_boarded():
        disembark()
        return true
    if player == null or global_position.distance_to(player.global_position) > interaction_radius:
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
    _current_speed = 0.0
    _snapshot_accumulator = 0.0
    add_to_group("active_controller")
    if player.has_method("set_mounted_pose"):
        player.call("set_mounted_pose", style_key)
    _sync_driver_to_seat()
    GameState.set_exact_snapshot(player.global_position, global_rotation.y, false)
    var verb := "MONTER" if style_key == "horse" else "CONDUIRE"
    _notify("%s • joystick pour %s • INTERAGIR pour descendre" % [vehicle_name.to_upper(), verb.to_lower()])

func disembark() -> void:
    if not is_boarded():
        return
    var landing := _find_safe_disembark_position()
    if not bool(landing.get("found", false)):
        _notify("Impossible de descendre ici : cherche un sol stable.")
        return
    _release_driver_at(_driver, landing["position"], global_rotation.y, true)

func force_disembark_at(world_position: Vector3, yaw: float = 0.0) -> bool:
    if not is_boarded():
        return false
    _release_driver_at(_driver, world_position, yaw, false)
    return true

func _release_driver_at(player: CharacterBody3D, world_position: Vector3, yaw: float, save_now: bool) -> void:
    if player == null or not is_instance_valid(player):
        return
    if player.has_method("clear_mounted_pose"):
        player.call("clear_mounted_pose")
    if _driver_collision != null and is_instance_valid(_driver_collision):
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
    _current_speed = 0.0
    _snapshot_accumulator = 0.0

func _find_safe_disembark_position() -> Dictionary:
    if get_world_3d() == null:
        return {"found": false}
    var right := global_transform.basis.x.normalized()
    var forward := -global_transform.basis.z.normalized()
    for offset in [right * 3.2, -right * 3.2, forward * 3.5, -forward * 3.5]:
        var ray_start: Vector3 = global_position + offset + Vector3.UP * 8.0
        var query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + Vector3.DOWN * 18.0, 1)
        query.exclude = [get_rid()]
        var hit := get_world_3d().direct_space_state.intersect_ray(query)
        if hit.has("position"):
            var point: Vector3 = hit["position"]
            if point.y > -1.05:
                return {"found": true, "position": point + Vector3.UP * 1.05}
    return {"found": false}

func _physics_process(delta: float) -> void:
    _animation_time += delta
    if not is_on_floor():
        velocity.y -= 22.0 * delta
    elif velocity.y < 0.0:
        velocity.y = -0.45

    if not is_boarded():
        _current_speed = move_toward(_current_speed, 0.0, acceleration * 0.7 * delta)
        velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
        velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
        move_and_slide()
        _animate_vehicle(delta, 0.0)
        return

    var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := _virtual_move if _virtual_move.length() >= keyboard.length() else keyboard
    var throttle := clampf(-input_vec.y, -1.0, 1.0)
    var steering := clampf(input_vec.x, -1.0, 1.0)
    var target_speed := throttle * (maximum_speed if throttle >= 0.0 else reverse_speed)
    var drive_acceleration := acceleration if absf(throttle) > 0.05 else acceleration * 1.35
    _current_speed = move_toward(_current_speed, target_speed, drive_acceleration * delta)

    var speed_ratio := clampf(absf(_current_speed) / maxf(0.1, maximum_speed), 0.0, 1.0)
    var minimum_grip := 0.60 if style_key in ["quad", "horse"] else 0.34
    var steering_grip := lerpf(minimum_grip, 1.0, speed_ratio)
    var reverse_sign := -1.0 if _current_speed < -0.2 else 1.0
    rotation.y -= steering * turn_speed * steering_grip * reverse_sign * delta
    var forward := -global_transform.basis.z
    velocity.x = forward.x * _current_speed
    velocity.z = forward.z * _current_speed
    move_and_slide()
    _sync_driver_to_seat()
    _animate_vehicle(delta, _current_speed)

    _snapshot_accumulator += delta
    if _snapshot_accumulator >= 0.25:
        _snapshot_accumulator = 0.0
        GameState.set_exact_snapshot(_driver.global_position, global_rotation.y, false)

    if Input.is_action_just_pressed("interact"):
        disembark()

func _seat_offset() -> Vector3:
    match style_key:
        "quad": return Vector3(0.0, 1.62, 0.18)
        "4x4": return Vector3(0.0, 2.02, 0.42)
        "horse": return Vector3(0.0, 2.18, 0.10)
        _: return Vector3(0.0, 1.85, 0.30)

func _sync_driver_to_seat() -> void:
    if not is_boarded():
        return
    _driver.global_position = global_transform * _seat_offset()
    _driver.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
    _driver.velocity = Vector3.ZERO

func _animate_vehicle(delta: float, speed: float) -> void:
    for wheel in _wheels:
        if is_instance_valid(wheel):
            wheel.rotation.x += speed * delta * 0.72

    var speed_ratio := clampf(absf(speed) / maxf(0.1, maximum_speed), 0.0, 1.0)
    if style_key == "horse":
        var gait := sin(_animation_time * lerpf(4.0, 11.0, speed_ratio)) * minf(0.72, speed_ratio * 0.90)
        for i in range(_horse_legs.size()):
            var leg := _horse_legs[i]
            if is_instance_valid(leg):
                var phase_sign := 1.0 if i % 2 == 0 else -1.0
                leg.rotation.x = gait * phase_sign
        if _visual_root != null and is_instance_valid(_visual_root):
            _visual_root.position.y = absf(sin(_animation_time * lerpf(4.0, 10.0, speed_ratio))) * 0.055 * speed_ratio
        return

    if _visual_root != null and is_instance_valid(_visual_root):
        var hover := sin(_animation_time * 2.5) * 0.07 if style_key in ["hover", "spectral"] else 0.0
        _visual_root.position.y = hover

func _ensure_collision() -> void:
    var collision := get_node_or_null("VehicleCollision") as CollisionShape3D
    if collision == null:
        collision = CollisionShape3D.new()
        collision.name = "VehicleCollision"
        add_child(collision)
    var box := BoxShape3D.new()
    match style_key:
        "quad":
            box.size = Vector3(1.9, 1.25, 2.8)
            collision.position.y = 0.76
        "4x4":
            box.size = Vector3(2.85, 1.90, 4.55)
            collision.position.y = 1.05
        "horse":
            box.size = Vector3(1.25, 1.95, 2.55)
            collision.position.y = 1.05
        _:
            box.size = Vector3(2.7, 1.45, 4.2)
            collision.position.y = 0.90
    collision.shape = box

func _build_visual() -> void:
    if _visual_root != null and is_instance_valid(_visual_root):
        _visual_root.queue_free()
    _wheels.clear()
    _horse_legs.clear()
    _visual_root = Node3D.new()
    _visual_root.name = "Carrosserie_%s" % style_key
    add_child(_visual_root)

    match style_key:
        "quad":
            _build_quad_visual(_visual_root)
        "4x4":
            _build_4x4_visual(_visual_root)
        "horse":
            _build_horse_visual(_visual_root)
        _:
            _build_legacy_visual(_visual_root)

    var nameplate := Label3D.new()
    nameplate.name = "VehicleNameplate"
    nameplate.text = "%s\n%s" % ["MONTER" if style_key == "horse" else "CONDUIRE", vehicle_name.to_upper()]
    nameplate.position = Vector3(0.0, 3.55, 0.0)
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.no_depth_test = true
    nameplate.font_size = 22
    nameplate.outline_size = 7
    nameplate.modulate = accent_color
    nameplate.outline_modulate = Color(0.0, 0.0, 0.0, 0.92)
    _visual_root.add_child(nameplate)

func _build_quad_visual(root: Node3D) -> void:
    _add_box(root, "CadreQuad", Vector3(0.0, 0.82, 0.0), Vector3(1.35, 0.38, 1.85), main_color)
    _add_box(root, "CarénageAvant", Vector3(0.0, 1.02, -0.88), Vector3(1.42, 0.42, 0.72), accent_color)
    _add_box(root, "Selle", Vector3(0.0, 1.23, 0.36), Vector3(0.72, 0.24, 0.92), Color("202126"))
    _add_cylinder(root, "ColonneGuidon", Vector3(0.0, 1.38, -0.55), 0.06, 0.72, Color("34383d"), 8)
    _add_box(root, "Guidon", Vector3(0.0, 1.72, -0.55), Vector3(1.18, 0.08, 0.08), Color("26292d"))
    _add_sphere(root, "PhareQuad", Vector3(0.0, 1.17, -1.14), 0.18, Color("fff0b0"), true)
    for wheel_position in [
        Vector3(-0.88, 0.55, -0.83), Vector3(0.88, 0.55, -0.83),
        Vector3(-0.88, 0.55, 0.83), Vector3(0.88, 0.55, 0.83)
    ]:
        _add_wheel(root, wheel_position, 0.42, 0.34)

func _build_4x4_visual(root: Node3D) -> void:
    _add_box(root, "Chassis4x4", Vector3(0.0, 0.90, 0.0), Vector3(2.55, 0.62, 4.25), main_color)
    _add_box(root, "Cabine4x4", Vector3(0.0, 1.72, 0.30), Vector3(2.32, 1.18, 2.10), main_color.lightened(0.05))
    _add_box(root, "Capot4x4", Vector3(0.0, 1.28, -1.55), Vector3(2.35, 0.66, 1.15), accent_color.darkened(0.14))
    _add_box(root, "PareBrise", Vector3(0.0, 1.92, -0.79), Vector3(1.95, 0.72, 0.08), Color("5c8da3"), true)
    _add_box(root, "PareChoc", Vector3(0.0, 0.76, -2.18), Vector3(2.60, 0.24, 0.24), Color("292d30"))
    _add_box(root, "Galerie", Vector3(0.0, 2.43, 0.38), Vector3(2.12, 0.10, 1.90), Color("2e3235"))
    _add_sphere(root, "PhareG", Vector3(-0.74, 1.30, -2.13), 0.18, Color("fff3b7"), true)
    _add_sphere(root, "PhareD", Vector3(0.74, 1.30, -2.13), 0.18, Color("fff3b7"), true)
    for wheel_position in [
        Vector3(-1.38, 0.62, -1.42), Vector3(1.38, 0.62, -1.42),
        Vector3(-1.38, 0.62, 1.42), Vector3(1.38, 0.62, 1.42)
    ]:
        _add_wheel(root, wheel_position, 0.58, 0.44)

func _build_horse_visual(root: Node3D) -> void:
    var coat := main_color
    var dark := main_color.darkened(0.28)
    _add_capsule(root, "CorpsCheval", Vector3(0.0, 1.38, 0.05), 0.46, 1.85, coat, Vector3(90.0, 0.0, 0.0))
    _add_capsule(root, "Encolure", Vector3(0.0, 1.76, -0.74), 0.25, 1.05, coat, Vector3(25.0, 0.0, 0.0))
    _add_sphere(root, "TeteCheval", Vector3(0.0, 2.22, -1.05), 0.34, coat)
    _add_box(root, "Museau", Vector3(0.0, 2.10, -1.35), Vector3(0.42, 0.34, 0.62), coat.lightened(0.03))
    _add_box(root, "OreilleG", Vector3(-0.16, 2.53, -1.04), Vector3(0.10, 0.34, 0.12), dark)
    _add_box(root, "OreilleD", Vector3(0.16, 2.53, -1.04), Vector3(0.10, 0.34, 0.12), dark)
    _add_box(root, "SelleCheval", Vector3(0.0, 1.78, 0.14), Vector3(0.82, 0.18, 0.90), accent_color.darkened(0.25))
    _add_box(root, "TapisSelle", Vector3(0.0, 1.66, 0.18), Vector3(0.96, 0.12, 1.10), accent_color)
    _add_cylinder(root, "Queue", Vector3(0.0, 1.52, 1.02), 0.09, 1.10, dark, 7, false, Vector3(-34.0, 0.0, 0.0))

    var leg_positions := [
        Vector3(-0.30, 1.04, -0.56), Vector3(0.30, 1.04, -0.56),
        Vector3(-0.30, 1.04, 0.62), Vector3(0.30, 1.04, 0.62)
    ]
    for i in range(leg_positions.size()):
        var pivot := Node3D.new()
        pivot.name = "JambeCheval_%02d" % i
        pivot.position = leg_positions[i]
        root.add_child(pivot)
        _add_cylinder(pivot, "Patte", Vector3(0.0, -0.46, 0.0), 0.10, 0.92, coat.darkened(0.08), 7)
        _add_box(pivot, "Sabot", Vector3(0.0, -0.94, -0.03), Vector3(0.23, 0.18, 0.34), dark)
        _horse_legs.append(pivot)

func _build_legacy_visual(root: Node3D) -> void:
    _add_box(root, "Chassis", Vector3(0.0, 0.95, 0.0), Vector3(2.8, 0.72, 4.5), main_color)
    _add_box(root, "Poste", Vector3(0.0, 1.52, 0.45), Vector3(1.75, 0.62, 1.65), accent_color.darkened(0.22))
    _add_box(root, "Proue", Vector3(0.0, 1.25, -1.68), Vector3(2.35, 0.38, 0.72), accent_color)

    match style_key:
        "organ":
            for i in range(4):
                _add_cylinder(root, "Tuyau_%d" % i, Vector3(-0.72 + i * 0.48, 2.15 + absf(1.5 - i) * 0.18, 1.28), 0.12, 1.25 + i * 0.16, accent_color)
        "candy":
            _add_cylinder(root, "Sucette", Vector3(0.0, 2.35, 1.2), 0.34, 1.5, Color("ff8fc7"))
        "market":
            _add_box(root, "Caisse", Vector3(0.0, 2.05, 1.20), Vector3(1.7, 0.85, 1.0), Color("bc7a3d"))
        "crystal":
            _add_cylinder(root, "Cristal", Vector3(0.0, 2.32, 1.18), 0.32, 1.55, accent_color, 6)
        "urban":
            _add_box(root, "Gyrophare", Vector3(0.0, 2.15, 0.4), Vector3(0.72, 0.22, 0.30), Color("5cc8ff"))
        "training":
            _add_box(root, "Râtelier", Vector3(0.0, 2.2, 1.15), Vector3(1.8, 0.16, 0.16), accent_color)
        "pirate":
            _add_cylinder(root, "Mât", Vector3(0.0, 2.35, 1.1), 0.08, 2.1, Color("5a3926"))
            _add_box(root, "Drapeau", Vector3(0.48, 2.85, 1.1), Vector3(0.9, 0.55, 0.08), Color("20242a"))
        "sled":
            _add_box(root, "PatinG", Vector3(-1.0, 0.30, 0.0), Vector3(0.16, 0.18, 5.0), Color("d8eef6"))
            _add_box(root, "PatinD", Vector3(1.0, 0.30, 0.0), Vector3(0.16, 0.18, 5.0), Color("d8eef6"))
        "lava":
            _add_box(root, "CœurDeBraise", Vector3(0.0, 1.78, 1.28), Vector3(1.15, 0.42, 0.75), Color("ff5a24"), true)
        "crawler":
            _add_box(root, "Blindage", Vector3(0.0, 2.05, 0.7), Vector3(2.1, 0.65, 1.15), accent_color.darkened(0.30))
        "spectral":
            _add_cylinder(root, "FlammeSpectrale", Vector3(0.0, 2.28, 1.18), 0.38, 1.25, Color("b87cff"), 8, true)
        _:
            pass

    if style_key not in ["sled", "hover", "spectral"]:
        for wheel_position in [
            Vector3(-1.42, 0.58, -1.42), Vector3(1.42, 0.58, -1.42),
            Vector3(-1.42, 0.58, 1.42), Vector3(1.42, 0.58, 1.42)
        ]:
            _add_wheel(root, wheel_position)
    else:
        _add_box(root, "PropulseurG", Vector3(-1.05, 0.52, 0.0), Vector3(0.34, 0.34, 3.5), accent_color, true)
        _add_box(root, "PropulseurD", Vector3(1.05, 0.52, 0.0), Vector3(0.34, 0.34, 3.5), accent_color, true)

func _add_wheel(parent: Node3D, local_position: Vector3, radius: float = 0.48, width: float = 0.38) -> void:
    var pivot := Node3D.new()
    pivot.position = local_position
    parent.add_child(pivot)
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = width
    mesh.radial_segments = 12
    visual.mesh = mesh
    visual.rotation.z = PI * 0.5
    visual.material_override = _material(Color("202126"))
    pivot.add_child(visual)
    _wheels.append(pivot)

func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, color: Color, emissive: bool = false) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = box_size
    visual.mesh = mesh
    visual.position = local_position
    visual.material_override = _material(color, emissive)
    parent.add_child(visual)

func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, color: Color, sides: int = 10, emissive: bool = false, rotation_deg: Vector3 = Vector3.ZERO) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius * 0.82
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = maxi(6, sides)
    visual.mesh = mesh
    visual.position = local_position
    visual.rotation_degrees = rotation_deg
    visual.material_override = _material(color, emissive)
    parent.add_child(visual)

func _add_sphere(parent: Node3D, node_name: String, local_position: Vector3, radius: float, color: Color, emissive: bool = false) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 10
    mesh.rings = 6
    visual.mesh = mesh
    visual.position = local_position
    visual.material_override = _material(color, emissive)
    parent.add_child(visual)

func _add_capsule(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, color: Color, rotation_deg: Vector3 = Vector3.ZERO) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    mesh.rings = 5
    visual.mesh = mesh
    visual.position = local_position
    visual.rotation_degrees = rotation_deg
    visual.material_override = _material(color)
    parent.add_child(visual)

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.70
    material.metallic = 0.16 if style_key in ["quad", "4x4"] else 0.0
    if emissive:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.45
    return material

func _notify(text: String) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", text, 2.6)