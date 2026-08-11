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
var _snapshot_accumulator := 0.0
var _animation_time := 0.0

func configure(spec: Dictionary) -> void:
    vehicle_name = str(spec.get("name", vehicle_name))
    style_key = str(spec.get("style", style_key))
    main_color = spec.get("main_color", main_color)
    accent_color = spec.get("accent_color", accent_color)
    maximum_speed = float(spec.get("maximum_speed", maximum_speed))
    turn_speed = float(spec.get("turn_speed", turn_speed))
    if is_inside_tree():
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
    return 6.2

func camera_height() -> float:
    return 2.15

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
    _sync_driver_to_seat()
    GameState.set_exact_snapshot(player.global_position, global_rotation.y, false)
    _notify("%s • joystick pour conduire • INTERAGIR pour descendre" % vehicle_name.to_upper())

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
    var steering_grip := lerpf(0.34, 1.0, speed_ratio)
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

func _sync_driver_to_seat() -> void:
    if not is_boarded():
        return
    _driver.global_position = global_transform * Vector3(0.0, 1.85, 0.30)
    _driver.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
    _driver.velocity = Vector3.ZERO

func _animate_vehicle(delta: float, speed: float) -> void:
    for wheel in _wheels:
        if is_instance_valid(wheel):
            wheel.rotation.x += speed * delta * 0.72
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
    box.size = Vector3(2.7, 1.45, 4.2)
    collision.shape = box
    collision.position.y = 0.90

func _build_visual() -> void:
    if _visual_root != null and is_instance_valid(_visual_root):
        _visual_root.queue_free()
    _wheels.clear()
    _visual_root = Node3D.new()
    _visual_root.name = "Carrosserie_%s" % style_key
    add_child(_visual_root)

    _add_box(_visual_root, "Chassis", Vector3(0.0, 0.95, 0.0), Vector3(2.8, 0.72, 4.5), main_color)
    _add_box(_visual_root, "Poste", Vector3(0.0, 1.52, 0.45), Vector3(1.75, 0.62, 1.65), accent_color.darkened(0.22))
    _add_box(_visual_root, "Proue", Vector3(0.0, 1.25, -1.68), Vector3(2.35, 0.38, 0.72), accent_color)

    match style_key:
        "organ":
            for i in range(4):
                _add_cylinder(_visual_root, "Tuyau_%d" % i, Vector3(-0.72 + i * 0.48, 2.15 + absf(1.5 - i) * 0.18, 1.28), 0.12, 1.25 + i * 0.16, accent_color)
        "candy":
            _add_cylinder(_visual_root, "Sucette", Vector3(0.0, 2.35, 1.2), 0.34, 1.5, Color("ff8fc7"))
        "market":
            _add_box(_visual_root, "Caisse", Vector3(0.0, 2.05, 1.20), Vector3(1.7, 0.85, 1.0), Color("bc7a3d"))
        "crystal":
            _add_cylinder(_visual_root, "Cristal", Vector3(0.0, 2.32, 1.18), 0.32, 1.55, accent_color, 6)
        "urban":
            _add_box(_visual_root, "Gyrophare", Vector3(0.0, 2.15, 0.4), Vector3(0.72, 0.22, 0.30), Color("5cc8ff"))
        "training":
            _add_box(_visual_root, "Râtelier", Vector3(0.0, 2.2, 1.15), Vector3(1.8, 0.16, 0.16), accent_color)
        "pirate":
            _add_cylinder(_visual_root, "Mât", Vector3(0.0, 2.35, 1.1), 0.08, 2.1, Color("5a3926"))
            _add_box(_visual_root, "Drapeau", Vector3(0.48, 2.85, 1.1), Vector3(0.9, 0.55, 0.08), Color("20242a"))
        "sled":
            _add_box(_visual_root, "PatinG", Vector3(-1.0, 0.30, 0.0), Vector3(0.16, 0.18, 5.0), Color("d8eef6"))
            _add_box(_visual_root, "PatinD", Vector3(1.0, 0.30, 0.0), Vector3(0.16, 0.18, 5.0), Color("d8eef6"))
        "lava":
            _add_box(_visual_root, "CœurDeBraise", Vector3(0.0, 1.78, 1.28), Vector3(1.15, 0.42, 0.75), Color("ff5a24"), true)
        "crawler":
            _add_box(_visual_root, "Blindage", Vector3(0.0, 2.05, 0.7), Vector3(2.1, 0.65, 1.15), accent_color.darkened(0.30))
        "spectral":
            _add_cylinder(_visual_root, "FlammeSpectrale", Vector3(0.0, 2.28, 1.18), 0.38, 1.25, Color("b87cff"), 8, true)
        _:
            pass

    if style_key not in ["sled", "hover", "spectral"]:
        for wheel_position in [
            Vector3(-1.42, 0.58, -1.42), Vector3(1.42, 0.58, -1.42),
            Vector3(-1.42, 0.58, 1.42), Vector3(1.42, 0.58, 1.42)
        ]:
            _add_wheel(_visual_root, wheel_position)
    else:
        _add_box(_visual_root, "PropulseurG", Vector3(-1.05, 0.52, 0.0), Vector3(0.34, 0.34, 3.5), accent_color, true)
        _add_box(_visual_root, "PropulseurD", Vector3(1.05, 0.52, 0.0), Vector3(0.34, 0.34, 3.5), accent_color, true)

    var nameplate := Label3D.new()
    nameplate.name = "VehicleNameplate"
    nameplate.text = "CONDUIRE\n%s" % vehicle_name.to_upper()
    nameplate.position = Vector3(0.0, 3.55, 0.0)
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.no_depth_test = true
    nameplate.font_size = 22
    nameplate.outline_size = 7
    nameplate.modulate = accent_color
    nameplate.outline_modulate = Color(0.0, 0.0, 0.0, 0.92)
    _visual_root.add_child(nameplate)

func _add_wheel(parent: Node3D, local_position: Vector3) -> void:
    var pivot := Node3D.new()
    pivot.position = local_position
    parent.add_child(pivot)
    var visual := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.48
    mesh.bottom_radius = 0.48
    mesh.height = 0.38
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

func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, color: Color, sides: int = 10, emissive: bool = false) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius * 0.82
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = maxi(6, sides)
    visual.mesh = mesh
    visual.position = local_position
    visual.material_override = _material(color, emissive)
    parent.add_child(visual)

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.70
    if emissive:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.45
    return material

func _notify(text: String) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", text, 2.6)
