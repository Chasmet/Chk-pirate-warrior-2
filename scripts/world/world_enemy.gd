class_name WorldEnemy
extends CharacterBody3D

@export var model_path := ""
@export var max_health := 100.0
@export var move_speed := 3.2
@export var detection_radius := 28.0
@export var attack_radius := 2.4
@export var attack_damage := 8.0
@export var boss := false

var health := 100.0
var _visual: Node3D
var _player: Node3D
var _attack_cooldown := 0.0
var _death_reported := false
var _objective_marker: Node3D
var _marker_base_y := 0.0
var _marker_time := 0.0

func _ready() -> void:
    add_to_group("enemy")
    health = max_health
    _player = get_tree().get_first_node_in_group("player") as Node3D
    _load_visual()
    _ensure_objective_marker()

func configure(path: String, is_boss: bool, difficulty: float = 1.0) -> void:
    model_path = path
    boss = is_boss
    max_health = (620.0 if boss else 105.0) * maxf(0.75, difficulty)
    health = max_health
    move_speed = (2.8 if boss else 3.5) + minf(1.5, difficulty * 0.15)
    attack_damage = (22.0 if boss else 8.0) * maxf(0.8, difficulty)
    detection_radius = 45.0 if boss else 30.0
    if is_inside_tree():
        _load_visual()
        _ensure_objective_marker()

func receive_damage(amount: float) -> void:
    if _death_reported or amount <= 0.0:
        return
    health = maxf(0.0, health - amount)
    if health <= 0.0:
        _death_reported = true
        if boss:
            get_tree().call_group("world_director", "on_boss_defeated", self)
        else:
            get_tree().call_group("world_director", "on_enemy_defeated", self)
        queue_free()

func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
    _marker_time += delta
    if _objective_marker != null and is_instance_valid(_objective_marker):
        _objective_marker.position.y = _marker_base_y + sin(_marker_time * 2.7) * 0.16
        _objective_marker.rotation.y = fmod(_marker_time * 1.4, TAU)

    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D
        return
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    var flat_delta := _player.global_position - global_position
    flat_delta.y = 0.0
    var distance := flat_delta.length()
    if distance <= detection_radius and distance > attack_radius:
        var direction := flat_delta.normalized()
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 8.0 * delta))
    else:
        velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
    if distance <= attack_radius and _attack_cooldown <= 0.0:
        _attack_cooldown = 1.2 if boss else 1.65
        if _player.has_method("receive_damage"):
            _player.receive_damage(attack_damage)
    move_and_slide()

func _load_visual() -> void:
    if _visual != null and is_instance_valid(_visual):
        _visual.queue_free()
    _visual = null
    if model_path != "" and ResourceLoader.exists(model_path):
        var resource: Resource = load(model_path)
        if resource is PackedScene:
            var instance: Node = (resource as PackedScene).instantiate()
            if instance is Node3D:
                var candidate := instance as Node3D
                add_child(candidate)
                var meshes: Array[MeshInstance3D] = []
                _collect_meshes(candidate, meshes)
                if not meshes.is_empty():
                    _visual = candidate
                    _normalize_model(_visual, 3.4 if boss else 1.9)
                    return
                candidate.queue_free()
            else:
                instance.queue_free()
    _fallback_visual()

func _normalize_model(root: Node3D, target_height: float) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return
    var min_corner := Vector3(INF, INF, INF)
    var max_corner := Vector3(-INF, -INF, -INF)
    var inverse := root.global_transform.affine_inverse()
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var box := mesh_instance.get_aabb()
        var xf := inverse * mesh_instance.global_transform
        for i in range(8):
            var p: Vector3 = xf * box.get_endpoint(i)
            min_corner = Vector3(minf(min_corner.x, p.x), minf(min_corner.y, p.y), minf(min_corner.z, p.z))
            max_corner = Vector3(maxf(max_corner.x, p.x), maxf(max_corner.y, p.y), maxf(max_corner.z, p.z))
    var height := max_corner.y - min_corner.y
    if height <= 0.01:
        return
    var factor := clampf(target_height / height, 0.015, 40.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= min_corner.y * factor

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _fallback_visual() -> void:
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.55 if boss else 0.34
    mesh.height = 2.8 if boss else 1.7
    body.mesh = mesh
    body.position.y = mesh.height * 0.55
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("9b302d") if boss else Color("5f4036")
    body.material_override = material
    add_child(body)
    _visual = body

func _ensure_objective_marker() -> void:
    if _objective_marker != null and is_instance_valid(_objective_marker):
        return
    _objective_marker = Node3D.new()
    _objective_marker.name = "ObjectiveMarker"
    _marker_base_y = 4.4 if boss else 2.75
    _objective_marker.position.y = _marker_base_y
    add_child(_objective_marker)

    var marker_color := Color("ffb347") if boss else Color("ff5c4d")

    var core := MeshInstance3D.new()
    core.name = "MarkerCore"
    var sphere := SphereMesh.new()
    sphere.radius = 0.30 if boss else 0.22
    sphere.height = sphere.radius * 2.0
    sphere.radial_segments = 10
    sphere.rings = 6
    core.mesh = sphere
    core.material_override = _marker_material(marker_color)
    _objective_marker.add_child(core)

    var ring := MeshInstance3D.new()
    ring.name = "MarkerRing"
    var torus := TorusMesh.new()
    torus.inner_radius = 0.46 if boss else 0.34
    torus.outer_radius = 0.58 if boss else 0.44
    torus.rings = 14
    torus.ring_segments = 6
    ring.mesh = torus
    ring.material_override = _marker_material(marker_color)
    _objective_marker.add_child(ring)

    # Nom lisible à distance : le GPS ne doit plus pointer vers une cible anonyme.
    var nameplate := Label3D.new()
    nameplate.name = "EnemyNameplate"
    nameplate.text = "BOSS" if boss else "ENNEMI"
    nameplate.position = Vector3(0.0, 0.72, 0.0)
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.no_depth_test = true
    nameplate.font_size = 32 if boss else 24
    nameplate.outline_size = 8
    nameplate.modulate = marker_color
    nameplate.outline_modulate = Color(0.0, 0.0, 0.0, 0.92)
    _objective_marker.add_child(nameplate)

func _marker_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.6
    return material
