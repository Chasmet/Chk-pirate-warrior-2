extends CharacterBody3D

signal defeated(enemy: Node)

@export var max_health := 70.0
@export var move_speed := 2.4
@export var detection_radius := 20.0
@export var attack_radius := 1.85

var health := 70.0
var _player: Node3D
var _attack_cooldown := 0.0

func _ready() -> void:
    add_to_group("enemy")
    health = max_health
    _build_visual()

func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
    if not is_on_floor():
        velocity.y -= 18.0 * delta

    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D

    if _player != null:
        var to_player := _player.global_position - global_position
        var planar := Vector3(to_player.x, 0.0, to_player.z)
        var distance := planar.length()
        if distance <= detection_radius and distance > attack_radius:
            var direction := planar.normalized()
            velocity.x = direction.x * move_speed
            velocity.z = direction.z * move_speed
            rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 7.0 * delta))
        else:
            velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)

        if distance <= attack_radius and _attack_cooldown <= 0.0:
            if _player.has_method("receive_damage"):
                _player.receive_damage(8.0)
            _attack_cooldown = 1.1

    move_and_slide()

func receive_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        defeated.emit(self)
        queue_free()

func _build_visual() -> void:
    var collision := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.radius = 0.34
    capsule_shape.height = 1.75
    collision.position = Vector3(0.0, 0.88, 0.0)
    collision.shape = capsule_shape
    add_child(collision)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.32, 0.06, 0.045)
    material.roughness = 0.78

    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.45
    body.mesh = capsule
    body.position = Vector3(0.0, 0.92, 0.0)
    body.material_override = material
    add_child(body)

    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.24
    sphere.height = 0.48
    head.mesh = sphere
    head.position = Vector3(0.0, 1.78, 0.0)
    head.material_override = material
    add_child(head)

    var sword := MeshInstance3D.new()
    var sword_mesh := BoxMesh.new()
    sword_mesh.size = Vector3(0.07, 0.9, 0.08)
    sword.mesh = sword_mesh
    sword.position = Vector3(0.43, 0.92, -0.05)
    sword.rotation_degrees.z = -18.0
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.55, 0.58, 0.62)
    metal.metallic = 0.7
    sword.material_override = metal
    add_child(sword)
