class_name WorldEnemyProjectileV116
extends Node3D

var _source: Node
var _target: Node3D
var _damage := 0.0
var _speed := 20.0
var _lifetime := 4.0
var _radius := 0.72
var _direction := Vector3.FORWARD
var _initialized := false

func configure(source: Node, target: Node3D, damage: float, speed: float, color: Color, radius: float = 0.72, direction_override: Vector3 = Vector3.ZERO) -> void:
    _source = source
    _target = target
    _damage = maxf(0.0, damage)
    _speed = maxf(1.0, speed)
    _radius = maxf(0.25, radius)
    if direction_override.length_squared() > 0.001:
        _direction = direction_override.normalized()
    elif _target != null and is_instance_valid(_target):
        _direction = (_target.global_position + Vector3.UP * 1.0 - global_position).normalized()
    _build_visual(color)
    _initialized = true

func _physics_process(delta: float) -> void:
    if not _initialized:
        return
    _lifetime -= delta
    if _lifetime <= 0.0:
        queue_free()
        return

    if _target == null or not is_instance_valid(_target):
        queue_free()
        return

    var aim := _target.global_position + Vector3.UP * 0.95
    var desired := aim - global_position
    if desired.length_squared() > 0.001:
        var desired_dir := desired.normalized()
        # Léger guidage : le projectile reste esquivable et ne fait pas un virage instantané.
        _direction = _direction.slerp(desired_dir, minf(1.0, delta * 2.15)).normalized()

    var from := global_position
    var to := from + _direction * _speed * delta
    var hit := _raycast(from, to)
    if not hit.is_empty():
        var collider = hit.get("collider")
        if _collider_belongs_to_target(collider):
            _deal_damage()
        queue_free()
        return

    global_position = to
    if global_position.distance_to(aim) <= _radius:
        _deal_damage()
        queue_free()

func _raycast(from: Vector3, to: Vector3) -> Dictionary:
    if get_world_3d() == null:
        return {}
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    query.collide_with_areas = false
    var excluded: Array[RID] = []
    if _source is CollisionObject3D and is_instance_valid(_source):
        excluded.append((_source as CollisionObject3D).get_rid())
    query.exclude = excluded
    return get_world_3d().direct_space_state.intersect_ray(query)

func _collider_belongs_to_target(collider: Variant) -> bool:
    if collider == null or _target == null or not is_instance_valid(_target):
        return false
    if collider == _target:
        return true
    if collider is Node:
        var node := collider as Node
        return _target.is_ancestor_of(node) or node.is_ancestor_of(_target)
    return false

func _deal_damage() -> void:
    if _source != null and is_instance_valid(_source) and _source.has_method("apply_damage_to_target"):
        _source.call("apply_damage_to_target", _target, _damage)
    elif _target != null and is_instance_valid(_target) and _target.has_method("receive_damage"):
        _target.call("receive_damage", _damage)

func _build_visual(color: Color) -> void:
    var core := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.18
    sphere.height = 0.36
    sphere.radial_segments = 10
    sphere.rings = 6
    core.mesh = sphere
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 3.2
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    core.material_override = material
    add_child(core)

    var halo := MeshInstance3D.new()
    var halo_sphere := SphereMesh.new()
    halo_sphere.radius = 0.30
    halo_sphere.height = 0.60
    halo_sphere.radial_segments = 8
    halo_sphere.rings = 4
    halo.mesh = halo_sphere
    var halo_material := StandardMaterial3D.new()
    halo_material.albedo_color = Color(color.r, color.g, color.b, 0.22)
    halo_material.emission_enabled = true
    halo_material.emission = color
    halo_material.emission_energy_multiplier = 1.7
    halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    halo.material_override = halo_material
    add_child(halo)
