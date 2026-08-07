class_name BoatController
extends CharacterBody3D

@export var model_path := "res://assets/bateaux_glb/glb/navire_pirate_clair.glb"
@export var cruise_speed := 24.0
@export var boost_speed := 38.0
@export var turn_speed := 1.45
@export var water_height := -0.55
@export var boarding_radius := 7.0

var _virtual_move := Vector2.ZERO
var _driver: CharacterBody3D
var _driver_parent: Node
var _driver_collision: CollisionShape3D
var _visual: Node3D
var _bobbing_time := 0.0

func _ready() -> void:
    add_to_group("boat")
    _load_visual()

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
    _driver_parent = player.get_parent()
    _driver_collision = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if _driver_collision != null:
        _driver_collision.disabled = true
    player.set_physics_process(false)
    player.velocity = Vector3.ZERO
    player.reparent(self, true)
    player.position = Vector3(0.0, 1.25, 0.25)
    player.rotation = Vector3.ZERO
    add_to_group("active_controller")

func disembark() -> void:
    if not is_boarded():
        return
    var player := _driver
    var target_parent := _driver_parent if _driver_parent != null and is_instance_valid(_driver_parent) else get_parent()
    player.reparent(target_parent, true)
    var right := global_transform.basis.x.normalized()
    player.global_position = global_position + right * 4.2 + Vector3.UP * 1.5
    player.rotation = Vector3(0.0, rotation.y, 0.0)
    if _driver_collision != null:
        _driver_collision.disabled = false
    player.set_physics_process(true)
    remove_from_group("active_controller")
    _driver = null
    _driver_parent = null
    _driver_collision = null
    _virtual_move = Vector2.ZERO

func _physics_process(delta: float) -> void:
    _bobbing_time += delta
    global_position.y = water_height + sin(_bobbing_time * 1.7) * 0.10
    if not is_boarded():
        velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
        move_and_slide()
        return

    var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := _virtual_move if _virtual_move.length() >= keyboard.length() else keyboard
    rotation.y -= input_vec.x * turn_speed * delta
    var throttle := clampf(-input_vec.y, -0.35, 1.0)
    var speed := boost_speed if Input.is_action_pressed("dodge") else cruise_speed
    var forward := -global_transform.basis.z
    var target_velocity := forward * throttle * speed
    velocity.x = move_toward(velocity.x, target_velocity.x, speed * 1.8 * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, speed * 1.8 * delta)
    velocity.y = 0.0
    move_and_slide()

    if Input.is_action_just_pressed("interact"):
        disembark()

func _load_visual() -> void:
    if _visual != null and is_instance_valid(_visual):
        _visual.queue_free()
    _visual = null
    if not ResourceLoader.exists(model_path):
        _create_fallback_visual()
        return
    var resource := load(model_path)
    if resource is PackedScene:
        _visual = resource.instantiate()
        add_child(_visual)
        _normalize_visual(_visual)
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
        var xf := root.global_transform.affine_inverse() * mesh_instance.global_transform
        for i in range(8):
            var p: Vector3 = xf * box.get_endpoint(i)
            min_corner = min_corner.min(p)
            max_corner = max_corner.max(p)
    var size := max_corner - min_corner
    if size.length() <= 0.01:
        return
    var longest := maxf(size.x, size.z)
    var factor := clampf(12.0 / maxf(0.1, longest), 0.02, 12.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= min_corner.y * factor

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node)
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
