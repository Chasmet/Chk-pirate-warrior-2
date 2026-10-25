class_name RemotePlayerAvatar
extends Node3D

var peer_id: int = 0
var hero_id: String = "cheikh"
var display_name: String = "Joueur"

var _target_position := Vector3.ZERO
var _target_rotation_y := 0.0
var _target_speed := 0.0
var _target_velocity := Vector3.ZERO
var _has_snapshot := false
var _hero_visual: Node3D
var _animation_player: AnimationPlayer
var _name_label: Label3D
var _mount_visual: Node3D
var _mount_style := ""
var _current_animation := ""

func setup(id_value: int, hero_value: String, name_value: String) -> void:
    peer_id = id_value
    hero_id = hero_value if hero_value in ["cheikh", "yvane", "nelvyn"] else "cheikh"
    display_name = name_value.strip_edges() if not name_value.strip_edges().is_empty() else "Joueur"
    name = "RemotePlayer_%d" % peer_id
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_hero_visual()
    _build_name_label()

func update_identity(hero_value: String, name_value: String) -> void:
    var resolved_hero := hero_value if hero_value in ["cheikh", "yvane", "nelvyn"] else "cheikh"
    var resolved_name := name_value.strip_edges() if not name_value.strip_edges().is_empty() else "Joueur"
    display_name = resolved_name
    if _name_label != null:
        _name_label.text = display_name
    if resolved_hero == hero_id:
        return

    var previous_mount := _mount_style
    _mount_style = ""
    if _mount_visual != null and is_instance_valid(_mount_visual):
        _mount_visual.queue_free()
    _mount_visual = null
    if _hero_visual != null and is_instance_valid(_hero_visual):
        _hero_visual.queue_free()
    _hero_visual = null
    _animation_player = null
    _current_animation = ""
    hero_id = resolved_hero
    _build_hero_visual()
    if not previous_mount.is_empty():
        _set_mount_style(previous_mount)

func set_snapshot(world_position: Vector3, yaw: float, speed: float, mount_style: String = "", linear_velocity: Vector3 = Vector3.ZERO) -> void:
    _target_velocity = linear_velocity.limit_length(60.0)
    # Une courte anticipation masque l'intervalle entre deux paquets Wi-Fi sans
    # déplacer artificiellement le joueur de plusieurs mètres.
    _target_position = world_position + _target_velocity * 0.055
    _target_rotation_y = yaw
    _target_speed = maxf(0.0, speed)
    if mount_style != _mount_style:
        _set_mount_style(mount_style)
    if not _has_snapshot:
        global_position = _target_position
        global_rotation = Vector3(0.0, _target_rotation_y, 0.0)
        _has_snapshot = true
    elif global_position.distance_to(_target_position) > 18.0:
        # Téléportation, changement d'île ou respawn : ne pas traverser la carte
        # lentement avec l'interpolation.
        global_position = _target_position
        global_rotation.y = _target_rotation_y

func play_action(action: String) -> void:
    match action:
        "attack":
            _play_animation_by_keywords(["attack", "punch", "slash", "hit", "swing"], false)
        "ability":
            _play_animation_by_keywords(["attack", "skill", "power", "slash", "punch"], false)
        "jump":
            _play_animation_by_keywords(["jump"], false)

func _process(delta: float) -> void:
    if not _has_snapshot:
        return
    var follow := 1.0 - exp(-18.0 * delta)
    global_position = global_position.lerp(_target_position, follow)
    rotation.y = lerp_angle(rotation.y, _target_rotation_y, minf(1.0, delta * 15.0))
    if _mount_style.is_empty():
        if _target_speed > 6.2:
            _play_animation_by_keywords(["run", "sprint"], true)
        elif _target_speed > 0.35:
            _play_animation_by_keywords(["walk", "move"], true)
        else:
            _play_animation_by_keywords(["idle", "stand"], true)
    elif _mount_style == "horse":
        _play_animation_by_keywords(["ride", "riding", "sit", "idle"], true)
    else:
        _play_animation_by_keywords(["drive", "driving", "sit", "idle"], true)

func _build_hero_visual() -> void:
    var heroes := _load_heroes()
    var hero: Dictionary = heroes.get(hero_id, {})
    var model_path := str(hero.get("model", ""))
    if ResourceLoader.exists(model_path):
        var packed = load(model_path)
        if packed is PackedScene:
            _hero_visual = packed.instantiate() as Node3D
    if _hero_visual == null:
        _hero_visual = _fallback_hero()
    add_child(_hero_visual)
    _normalize_visual_height(_hero_visual, 1.82)
    _hero_visual.rotation_degrees.y += 180.0
    _animation_player = _find_animation_player(_hero_visual)
    _play_animation_by_keywords(["idle", "stand"], true)

func _build_name_label() -> void:
    _name_label = Label3D.new()
    _name_label.name = "PlayerName"
    _name_label.text = display_name
    _name_label.position = Vector3(0.0, 2.35, 0.0)
    _name_label.font_size = 34
    _name_label.outline_size = 8
    _name_label.modulate = Color(1.0, 0.92, 0.58, 1.0)
    _name_label.no_depth_test = true
    add_child(_name_label)

func _set_mount_style(value: String) -> void:
    _mount_style = value
    if _mount_visual != null and is_instance_valid(_mount_visual):
        _mount_visual.queue_free()
    _mount_visual = null
    if _hero_visual == null:
        return
    _hero_visual.position = Vector3.ZERO
    if _mount_style.is_empty():
        return

    match _mount_style:
        "4x4":
            _mount_visual = _load_mount("res://assets/cc0_rides/4x4_kenney.glb", 4.4)
            _hero_visual.position = Vector3(0.0, 1.72, 0.36)
        "horse":
            _mount_visual = _load_mount("res://assets/cc0_rides/horse_quaternius.glb", 2.65)
            _hero_visual.position = Vector3(0.0, 1.78, 0.08)
        "quad":
            _mount_visual = _build_quad_proxy()
            _hero_visual.position = Vector3(0.0, 1.30, 0.12)
        _:
            _hero_visual.position = Vector3.ZERO

    if _mount_visual != null:
        _mount_visual.name = "RemoteMount"
        add_child(_mount_visual)
        move_child(_mount_visual, 0)

func _load_mount(path: String, target_longest: float) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var packed = load(path)
    if not packed is PackedScene:
        return null
    var result := packed.instantiate() as Node3D
    if result != null:
        _normalize_visual_longest(result, target_longest)
    return result

func _build_quad_proxy() -> Node3D:
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(1.25, 0.42, 1.85)
    body.mesh = box
    body.position = Vector3(0.0, 0.72, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.16, 0.18, 0.12)
    material.roughness = 0.72
    body.material_override = material
    root.add_child(body)
    for x in [-0.72, 0.72]:
        for z in [-0.68, 0.68]:
            var wheel := MeshInstance3D.new()
            var cylinder := CylinderMesh.new()
            cylinder.top_radius = 0.27
            cylinder.bottom_radius = 0.27
            cylinder.height = 0.22
            wheel.mesh = cylinder
            wheel.rotation_degrees.z = 90.0
            wheel.position = Vector3(x, 0.42, z)
            root.add_child(wheel)
    return root

func _fallback_hero() -> Node3D:
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.35
    body.mesh = capsule
    body.position = Vector3(0.0, 1.0, 0.0)
    var material := StandardMaterial3D.new()
    match hero_id:
        "yvane": material.albedo_color = Color(0.08, 0.28, 0.65)
        "nelvyn": material.albedo_color = Color(0.08, 0.08, 0.10)
        _: material.albedo_color = Color(0.86, 0.32, 0.08)
    body.material_override = material
    root.add_child(body)
    return root

func _load_heroes() -> Dictionary:
    var path := "res://data/heroes.json"
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

func _normalize_visual_height(root: Node3D, target_height: float) -> void:
    var bounds := _visual_bounds(root)
    if not bool(bounds.get("valid", false)):
        return
    var box: AABB = bounds.get("bounds", AABB())
    if box.size.y <= 0.001:
        return
    var factor := clampf(target_height / box.size.y, 0.01, 80.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= box.position.y * factor

func _normalize_visual_longest(root: Node3D, target_longest: float) -> void:
    var bounds := _visual_bounds(root)
    if not bool(bounds.get("valid", false)):
        return
    var box: AABB = bounds.get("bounds", AABB())
    var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
    if longest <= 0.001:
        return
    var factor := clampf(target_longest / longest, 0.01, 80.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= box.position.y * factor

func _visual_bounds(root: Node3D) -> Dictionary:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return {"valid": false, "bounds": AABB()}
    var inverse_root := root.global_transform.affine_inverse()
    var min_corner := Vector3(INF, INF, INF)
    var max_corner := Vector3(-INF, -INF, -INF)
    var found := false
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var aabb := mesh_instance.get_aabb()
        var transform_to_root: Transform3D = inverse_root * mesh_instance.global_transform
        for i in range(8):
            var point: Vector3 = transform_to_root * aabb.get_endpoint(i)
            min_corner.x = minf(min_corner.x, point.x)
            min_corner.y = minf(min_corner.y, point.y)
            min_corner.z = minf(min_corner.z, point.z)
            max_corner.x = maxf(max_corner.x, point.x)
            max_corner.y = maxf(max_corner.y, point.y)
            max_corner.z = maxf(max_corner.z, point.z)
            found = true
    return {"valid": found, "bounds": AABB(min_corner, max_corner - min_corner) if found else AABB()}

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        out.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, out)

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _play_animation_by_keywords(keywords: Array, loop_value: bool) -> bool:
    if _animation_player == null:
        return false
    var libraries := _animation_player.get_animation_library_list()
    for library_name in libraries:
        var library := _animation_player.get_animation_library(library_name)
        if library == null:
            continue
        for animation_name in library.get_animation_list():
            var lower := str(animation_name).to_lower()
            for keyword in keywords:
                if lower.contains(str(keyword).to_lower()):
                    var full_name := str(animation_name) if str(library_name).is_empty() else "%s/%s" % [library_name, animation_name]
                    if _current_animation != full_name or not _animation_player.is_playing():
                        var animation := library.get_animation(animation_name)
                        if animation != null:
                            animation.loop_mode = Animation.LOOP_LINEAR if loop_value else Animation.LOOP_NONE
                        _animation_player.play(full_name, 0.12)
                        _current_animation = full_name
                    return true
    return false
