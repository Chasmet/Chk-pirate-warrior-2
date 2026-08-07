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

func _ready() -> void:
    add_to_group("enemy")
    health = max_health
    _player = get_tree().get_first_node_in_group("player") as Node3D
    _load_visual()

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

func receive_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    if health <= 0.0:
        if boss:
            get_tree().call_group("world_director", "on_boss_defeated", self)
        queue_free()

func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
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
        var resource := load(model_path)
        if resource is PackedScene:
            _visual = resource.instantiate()
            add_child(_visual)
            _normalize_model(_visual, 3.4 if boss else 1.9)
            return
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
            min_corner = min_corner.min(p)
            max_corner = max_corner.max(p)
    var height := max_corner.y - min_corner.y
    if height <= 0.01:
        return
    var factor := clampf(target_height / height, 0.015, 40.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= min_corner.y * factor

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node)
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
