extends CharacterBody3D

signal health_changed(value: float, maximum: float)
signal energy_changed(value: float, maximum: float)
signal aura_changed(value: float)
signal ability_used(index: int, ability: Dictionary)
signal jumped()
signal landed()

@export var move_speed := 5.5
@export var run_speed := 8.0
@export var rotation_speed := 12.0
@export var gravity := 22.0
@export var jump_velocity := 7.4
@export var coyote_time := 0.13
@export var max_health := 165.0
@export var max_energy := 100.0
@export var target_visual_height := 1.82

var health := 165.0
var energy := 100.0
var aura := 100.0
var hero_data: Dictionary = {}
var hero_model: Node3D
var backpack_node: Node3D
var weapon_node: Node3D
var cooldowns := [0.0, 0.0]

var _virtual_move := Vector2.ZERO
var _last_move_dir := Vector3(0.0, 0.0, -1.0)
var _visual_scale_factor := 1.0
var _animation_player: AnimationPlayer
var _current_animation := ""
var _attack_lock := 0.0
var _dodge_time := 0.0
var _dodge_cooldown := 0.0
var _dodge_direction := Vector3.ZERO
var _coyote_remaining := 0.0

func _ready() -> void:
    add_to_group("player")
    GameState.hero_changed.connect(_on_hero_changed)
    hero_data = GameState.get_hero_data()
    _load_visuals()
    health_changed.emit(health, max_health)
    energy_changed.emit(energy, max_energy)
    aura_changed.emit(aura)

func set_virtual_move(value: Vector2) -> void:
    _virtual_move = value.limit_length(1.0)

func _physics_process(delta: float) -> void:
    _update_cooldowns(delta)
    _attack_lock = maxf(0.0, _attack_lock - delta)
    _dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
    _dodge_time = maxf(0.0, _dodge_time - delta)

    var grounded_before := is_on_floor()
    if grounded_before:
        _coyote_remaining = coyote_time
        if velocity.y < 0.0:
            velocity.y = -0.35
    else:
        _coyote_remaining = maxf(0.0, _coyote_remaining - delta)
        velocity.y -= gravity * delta

    var keyboard_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := _virtual_move
    if keyboard_vec.length() > input_vec.length():
        input_vec = keyboard_vec

    var direction := _camera_relative_direction(input_vec)
    var jumped_this_frame := false

    if Input.is_action_just_pressed("jump") and _coyote_remaining > 0.0 and _dodge_time <= 0.0:
        velocity.y = jump_velocity
        _coyote_remaining = 0.0
        jumped_this_frame = true
        _play_animation_by_keywords(["jump"], false)
        jumped.emit()

    if Input.is_action_just_pressed("dodge") and _dodge_cooldown <= 0.0:
        _start_dodge(direction)

    if _dodge_time > 0.0:
        velocity.x = _dodge_direction.x * 13.5
        velocity.z = _dodge_direction.z * 13.5
    elif direction.length() > 0.05:
        direction = direction.normalized()
        _last_move_dir = direction
        var input_strength := clampf(input_vec.length(), 0.0, 1.0)
        var speed_blend := clampf((input_strength - 0.32) / 0.68, 0.0, 1.0)
        var current_speed := lerpf(move_speed, run_speed, speed_blend)
        if not grounded_before:
            current_speed *= 0.78
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
        var target_angle := atan2(-direction.x, -direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, minf(1.0, rotation_speed * delta))
        if grounded_before and not jumped_this_frame and _attack_lock <= 0.0:
            _play_locomotion_animation(true, speed_blend >= 0.56)
    else:
        velocity.x = move_toward(velocity.x, 0.0, move_speed * 7.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, move_speed * 7.0 * delta)
        if grounded_before and not jumped_this_frame and _attack_lock <= 0.0:
            _play_locomotion_animation(false)

    if not grounded_before and velocity.y < -0.8 and _attack_lock <= 0.0:
        _play_animation_by_keywords(["fall"], true)

    move_and_slide()

    if not grounded_before and is_on_floor():
        landed.emit()
        _play_animation_by_keywords(["land"], false)

    if Input.is_action_just_pressed("attack"):
        basic_attack()
    if Input.is_action_just_pressed("ability_1"):
        use_ability(0)
    if Input.is_action_just_pressed("ability_2"):
        use_ability(1)
    if Input.is_action_just_pressed("quick_save"):
        GameState.quick_save()

func _camera_relative_direction(input_vec: Vector2) -> Vector3:
    if input_vec.length() <= 0.01:
        return Vector3.ZERO
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return Vector3(input_vec.x, 0.0, input_vec.y)
    var forward := -camera.global_transform.basis.z
    var right := camera.global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()
    return (right * input_vec.x) + (forward * -input_vec.y)

func _start_dodge(direction: Vector3) -> void:
    _dodge_direction = direction.normalized() if direction.length() > 0.05 else _last_move_dir.normalized()
    _dodge_time = 0.24
    _dodge_cooldown = 0.75
    _attack_lock = maxf(_attack_lock, 0.25)

func basic_attack() -> void:
    var attack_name := str(hero_data.get("base_attack", "Attaque"))
    print("%s: %s" % [hero_data.get("display_name", "Héros"), attack_name])
    _attack_lock = 0.48
    _play_animation_by_keywords(["attack", "punch", "slash", "hit", "swing"], false)
    _damage_enemies(2.45, 28.0)

func use_ability(index: int) -> bool:
    var abilities: Array = hero_data.get("abilities", [])
    if index < 0 or index >= abilities.size() or cooldowns[index] > 0.0:
        return false
    var ability: Dictionary = abilities[index]
    var cost := float(ability.get("energy", 0.0))
    if energy < cost:
        return false
    energy -= cost
    cooldowns[index] = float(ability.get("cooldown", 1.0))
    energy_changed.emit(energy, max_energy)
    ability_used.emit(index, ability)
    _attack_lock = 0.65
    _play_animation_by_keywords(["attack", "skill", "power", "slash", "punch"], false)
    _apply_ability_effect(index, ability)
    return true

func receive_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    health_changed.emit(health, max_health)
    if health <= 0.0:
        health = max_health
        global_position = Vector3(0.0, 4.0, 0.0)
        health_changed.emit(health, max_health)

func restore_energy(amount: float) -> void:
    energy = minf(max_energy, energy + amount)
    energy_changed.emit(energy, max_energy)

func _damage_enemies(radius: float, damage: float) -> void:
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if enemy is Node3D and global_position.distance_to(enemy.global_position) <= radius:
            if enemy.has_method("receive_damage"):
                enemy.receive_damage(damage)

func _apply_ability_effect(index: int, ability: Dictionary) -> void:
    var damage := float(ability.get("damage", 0.0))
    var radius := 4.0 if index == 0 else 6.5
    _damage_enemies(radius, damage)

func _on_hero_changed(_hero_id: String) -> void:
    hero_data = GameState.get_hero_data()
    _clear_visuals()
    cooldowns = [0.0, 0.0]
    energy = max_energy
    _load_visuals()
    energy_changed.emit(energy, max_energy)

func _clear_visuals() -> void:
    if backpack_node != null and is_instance_valid(backpack_node):
        backpack_node.queue_free()
    if weapon_node != null and is_instance_valid(weapon_node):
        weapon_node.queue_free()
    if hero_model != null and is_instance_valid(hero_model):
        hero_model.queue_free()
    hero_model = null
    backpack_node = null
    weapon_node = null
    _animation_player = null
    _current_animation = ""
    _visual_scale_factor = 1.0

func _load_visuals() -> void:
    var model_loaded := false
    var model_path := str(hero_data.get("model", ""))
    if ResourceLoader.exists(model_path):
        var packed = load(model_path)
        if packed is PackedScene:
            hero_model = packed.instantiate()
            add_child(hero_model)
            model_loaded = true
            _normalize_model_size()

    if not model_loaded:
        _create_fallback_hero()

    _animation_player = _find_animation_player(hero_model)
    _play_locomotion_animation(false)

    var backpack_path := str(hero_data.get("backpack", ""))
    if ResourceLoader.exists(backpack_path):
        var backpack_scene = load(backpack_path)
        if backpack_scene is PackedScene:
            var backpack_visual := backpack_scene.instantiate() as Node3D
            if backpack_visual != null:
                _attach_backpack(backpack_visual)

    var weapon_path := str(hero_data.get("weapon", ""))
    if weapon_path != "" and ResourceLoader.exists(weapon_path):
        var weapon_scene = load(weapon_path)
        if weapon_scene is PackedScene:
            weapon_node = weapon_scene.instantiate()
            _attach_to_bone_or_fallback(
                weapon_node,
                ["hand.R", "RightHand", "Hand.R", "mixamorig_RightHand", "hand_r"],
                Vector3(0.0, 0.58, 0.0),
                Vector3.ZERO,
                true
            )

func _attach_backpack(backpack_visual: Node3D) -> void:
    var anchor := Node3D.new()
    anchor.name = "BackpackAnchor"
    add_child(anchor)
    anchor.position = Vector3(0.0, 1.24, 0.27)
    anchor.rotation_degrees = Vector3(0.0, 180.0, 0.0)
    anchor.add_child(backpack_visual)

    var result := _calculate_visual_bounds(anchor)
    if bool(result.get("valid", false)):
        var bounds: AABB = result.get("bounds", AABB())
        var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
        if longest > 0.001:
            var factor := clampf(0.42 / longest, 0.001, 100.0)
            backpack_visual.scale *= Vector3.ONE * factor
            var centered_result := _calculate_visual_bounds(anchor)
            if bool(centered_result.get("valid", false)):
                var centered_bounds: AABB = centered_result.get("bounds", AABB())
                var center := centered_bounds.position + centered_bounds.size * 0.5
                backpack_visual.position -= center

    backpack_node = anchor

func _normalize_model_size() -> void:
    if hero_model == null:
        return
    var result := _calculate_visual_bounds(hero_model)
    if not bool(result.get("valid", false)):
        return
    var bounds: AABB = result.get("bounds", AABB())
    if bounds.size.y < 0.01:
        return
    _visual_scale_factor = clampf(target_visual_height / bounds.size.y, 0.03, 80.0)
    hero_model.scale *= Vector3.ONE * _visual_scale_factor
    hero_model.position.y -= bounds.position.y * _visual_scale_factor

func _calculate_visual_bounds(root: Node3D) -> Dictionary:
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
    if not found:
        return {"valid": false, "bounds": AABB()}
    return {"valid": true, "bounds": AABB(min_corner, max_corner - min_corner)}

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        out.append(node)
    for child in node.get_children():
        _collect_meshes(child, out)

func _create_fallback_hero() -> void:
    _visual_scale_factor = 1.0
    hero_model = Node3D.new()
    hero_model.name = "FallbackHero"
    add_child(hero_model)

    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.35
    body.mesh = capsule
    body.position = Vector3(0.0, 1.0, 0.0)

    var material := StandardMaterial3D.new()
    match GameState.selected_hero:
        "yvane":
            material.albedo_color = Color(0.08, 0.28, 0.65)
        "nelvyn":
            material.albedo_color = Color(0.08, 0.08, 0.10)
        _:
            material.albedo_color = Color(0.86, 0.32, 0.08)
    material.roughness = 0.72
    body.material_override = material
    hero_model.add_child(body)

    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.23
    sphere.height = 0.46
    head.mesh = sphere
    head.position = Vector3(0.0, 1.92, 0.0)
    head.material_override = material
    hero_model.add_child(head)

func _attach_to_bone_or_fallback(node: Node3D, bone_candidates: Array, local_pos: Vector3, local_rot_deg: Vector3, compensate_model_scale: bool = false) -> void:
    var skeleton := _find_skeleton(hero_model)
    if skeleton != null:
        for bone_name in bone_candidates:
            var bone_idx := skeleton.find_bone(str(bone_name))
            if bone_idx >= 0:
                var attachment := BoneAttachment3D.new()
                attachment.bone_name = str(bone_name)
                skeleton.add_child(attachment)
                attachment.add_child(node)
                node.position = local_pos
                node.rotation_degrees = local_rot_deg
                if compensate_model_scale and _visual_scale_factor > 0.001:
                    node.scale = Vector3.ONE / _visual_scale_factor
                return
    add_child(node)
    node.position = Vector3(0.0, 1.25, 0.25)
    node.rotation_degrees = local_rot_deg

func _find_skeleton(root: Node) -> Skeleton3D:
    if root == null:
        return null
    if root is Skeleton3D:
        return root
    for child in root.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _find_animation_player(root: Node) -> AnimationPlayer:
    if root == null:
        return null
    if root is AnimationPlayer:
        return root
    for child in root.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _play_locomotion_animation(moving: bool, running: bool = false) -> void:
    if moving:
        var keywords := ["run", "sprint", "walk", "move"] if running else ["walk", "run", "move"]
        if not _play_animation_by_keywords(keywords, true):
            _play_animation_by_keywords(["idle"], true)
    else:
        _play_animation_by_keywords(["idle", "stand"], true)

func _play_animation_by_keywords(keywords: Array, loop_requested: bool) -> bool:
    if _animation_player == null:
        return false
    var names := _animation_player.get_animation_list()
    var selected := ""
    for keyword in keywords:
        for animation_name in names:
            if str(animation_name).to_lower().contains(str(keyword).to_lower()):
                selected = str(animation_name)
                break
        if selected != "":
            break
    if selected == "":
        return false
    if selected == _current_animation and _animation_player.is_playing():
        return true
    var animation := _animation_player.get_animation(selected)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR if loop_requested else Animation.LOOP_NONE
    _animation_player.play(selected, 0.12)
    _current_animation = selected
    return true

func _update_cooldowns(delta: float) -> void:
    for i in range(cooldowns.size()):
        cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
