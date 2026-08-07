extends CharacterBody3D

signal health_changed(value: float, maximum: float)
signal energy_changed(value: float, maximum: float)
signal aura_changed(value: float)
signal ability_used(index: int, ability: Dictionary)

@export var move_speed := 5.5
@export var run_speed := 8.0
@export var rotation_speed := 10.0
@export var max_health := 165.0
@export var max_energy := 100.0

var health := 165.0
var energy := 100.0
var aura := 100.0
var hero_data: Dictionary = {}
var hero_model: Node3D
var backpack_node: Node3D
var weapon_node: Node3D
var cooldowns := [0.0, 0.0]

func _ready() -> void:
    add_to_group("player")
    hero_data = GameState.get_hero_data()
    _load_visuals()
    health_changed.emit(health, max_health)
    energy_changed.emit(energy, max_energy)
    aura_changed.emit(aura)

func _physics_process(delta: float) -> void:
    _update_cooldowns(delta)
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := Vector3(input_vec.x, 0.0, input_vec.y)
    if direction.length() > 0.05:
        direction = direction.normalized()
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        var target_angle := atan2(direction.x, direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)
    move_and_slide()

    if Input.is_action_just_pressed("attack"):
        basic_attack()
    if Input.is_action_just_pressed("ability_1"):
        use_ability(0)
    if Input.is_action_just_pressed("ability_2"):
        use_ability(1)
    if Input.is_action_just_pressed("quick_save"):
        GameState.quick_save()

func basic_attack() -> void:
    var attack_name := str(hero_data.get("base_attack", "Attaque"))
    print("%s: %s" % [hero_data.get("display_name", "Héros"), attack_name])

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
    _apply_ability_effect(index, ability)
    return true

func receive_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)
    health_changed.emit(health, max_health)

func restore_energy(amount: float) -> void:
    energy = minf(max_energy, energy + amount)
    energy_changed.emit(energy, max_energy)

func _apply_ability_effect(index: int, ability: Dictionary) -> void:
    var damage := float(ability.get("damage", 0.0))
    var radius := 3.2 if index == 0 else 5.0
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if enemy is Node3D and global_position.distance_to(enemy.global_position) <= radius:
            if enemy.has_method("receive_damage"):
                enemy.receive_damage(damage)

func _load_visuals() -> void:
    var model_path := str(hero_data.get("model", ""))
    if ResourceLoader.exists(model_path):
        var packed = load(model_path)
        if packed is PackedScene:
            hero_model = packed.instantiate()
            add_child(hero_model)

    var backpack_path := str(hero_data.get("backpack", ""))
    if ResourceLoader.exists(backpack_path):
        var backpack_scene = load(backpack_path)
        if backpack_scene is PackedScene:
            backpack_node = backpack_scene.instantiate()
            _attach_to_bone_or_fallback(backpack_node, ["Spine2", "Spine_02", "UpperChest", "Chest", "Spine1"], Vector3(0.0, 0.05, 0.20), Vector3(0.0, 180.0, 0.0))

    var weapon_path := str(hero_data.get("weapon", ""))
    if weapon_path != "" and ResourceLoader.exists(weapon_path):
        var weapon_scene = load(weapon_path)
        if weapon_scene is PackedScene:
            weapon_node = weapon_scene.instantiate()
            _attach_to_bone_or_fallback(weapon_node, ["RightHand", "Hand.R", "mixamorig_RightHand", "hand_r"], Vector3.ZERO, Vector3(0.0, 0.0, 90.0))

func _attach_to_bone_or_fallback(node: Node3D, bone_candidates: Array, local_pos: Vector3, local_rot_deg: Vector3) -> void:
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

func _update_cooldowns(delta: float) -> void:
    for i in range(cooldowns.size()):
        cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
