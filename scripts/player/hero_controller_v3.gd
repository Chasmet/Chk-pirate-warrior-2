class_name HeroControllerV3
extends "res://scripts/player/hero_controller_v2.gd"

signal basic_attack_used(attack: Dictionary)
signal special_selection_changed(index: int, ability: Dictionary)

@export var backpedal_rotation_threshold := 0.10
@export var backpedal_face_speed_multiplier := 2.4

var _mount_pose_active := false
var _mount_visual_position := Vector3.ZERO
var _mount_visual_rotation := Vector3.ZERO
var _selected_special_index := -1
var _last_known_level := 1

func _ready() -> void:
    move_speed = 8.2
    run_speed = 11.0
    rotation_speed = 16.0
    floor_snap_length = 0.72
    floor_max_angle = deg_to_rad(50.0)
    floor_stop_on_slope = true
    floor_constant_speed = true
    safe_margin = 0.055
    super._ready()
    _last_known_level = maxi(1, GameState.level)
    _ensure_combat_slots(true)
    _apply_level_stats()
    _select_first_unlocked_special()
    if not GameState.progression_changed.is_connected(_on_progression_changed):
        GameState.progression_changed.connect(_on_progression_changed)

func _physics_process(delta: float) -> void:
    # Déplacement caméra-relatif 360°. Toute la moitié basse du joystick produit
    # un vrai recul, même au maximum : l'ancienne zone extrême retournait le
    # héros et donnait sur téléphone l'impression que « bas » ne fonctionnait pas.
    super._physics_process(delta)
    _apply_backward_facing(delta)

func _movement_input() -> Vector2:
    var keyboard_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := _virtual_move
    if keyboard_vec.length() > input_vec.length():
        input_vec = keyboard_vec
    return input_vec.limit_length(1.0)

func _should_face_movement(input_vec: Vector2) -> bool:
    return input_vec.y <= backpedal_rotation_threshold

func _apply_backward_facing(delta: float) -> void:
    if _dodge_time > 0.0 or _attack_lock > 0.0 or _mount_pose_active:
        return
    var input_vec := _movement_input()
    if input_vec.length() <= 0.05 or input_vec.y <= backpedal_rotation_threshold:
        return
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var facing := -camera.global_transform.basis.z
    facing.y = 0.0
    if facing.length_squared() <= 0.001:
        return
    facing = facing.normalized()
    var target_angle := atan2(-facing.x, -facing.z)
    rotation.y = lerp_angle(
        rotation.y,
        target_angle,
        minf(1.0, rotation_speed * backpedal_face_speed_multiplier * delta)
    )

func set_mounted_pose(mount_style: String) -> void:
    if hero_model == null or not is_instance_valid(hero_model):
        return
    if _mount_pose_active:
        clear_mounted_pose()
    _mount_pose_active = true
    _mount_visual_position = hero_model.position
    _mount_visual_rotation = hero_model.rotation

    if mount_style == "horse":
        if not _play_animation_by_keywords(["ride", "horse", "riding", "sit"], true):
            _play_animation_by_keywords(["idle", "stand"], true)
        hero_model.position = _mount_visual_position + Vector3(0.0, -0.38, 0.04)
    else:
        if not _play_animation_by_keywords(["drive", "driving", "sit", "vehicle"], true):
            _play_animation_by_keywords(["idle", "stand"], true)
        hero_model.position = _mount_visual_position + Vector3(0.0, -0.30, 0.02)

    if backpack_node != null and is_instance_valid(backpack_node):
        backpack_node.visible = false
    if weapon_node != null and is_instance_valid(weapon_node):
        weapon_node.visible = false

func clear_mounted_pose() -> void:
    if not _mount_pose_active:
        return
    _mount_pose_active = false
    if hero_model != null and is_instance_valid(hero_model):
        hero_model.position = _mount_visual_position
        hero_model.rotation = _mount_visual_rotation
    if backpack_node != null and is_instance_valid(backpack_node):
        backpack_node.visible = true
    if weapon_node != null and is_instance_valid(weapon_node):
        weapon_node.visible = true
    _play_locomotion_animation(false)

func _load_visuals() -> void:
    super._load_visuals()
    _align_loaded_hero_visual()
    _normalize_weapon_visual()

func _align_loaded_hero_visual() -> void:
    if hero_model == null or not is_instance_valid(hero_model):
        return
    var hero_id := str(GameState.selected_hero).to_lower()
    if hero_id in ["cheikh", "yvane", "nelvyn"]:
        hero_model.rotation_degrees.y += 180.0

func _attach_backpack(backpack_visual: Node3D) -> void:
    var anchor := Node3D.new()
    anchor.name = "BackpackAnchor"
    add_child(anchor)
    anchor.position = Vector3(0.0, 1.28, 0.30)

    var hero_id := str(GameState.selected_hero).to_lower()
    var bag_yaw := 180.0 if hero_id == "cheikh" else 0.0
    anchor.rotation_degrees = Vector3(0.0, bag_yaw, 0.0)
    anchor.add_child(backpack_visual)

    var result := _calculate_visual_bounds(anchor)
    if bool(result.get("valid", false)):
        var bounds: AABB = result.get("bounds", AABB())
        var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
        if longest > 0.001:
            var target_size := 0.36 if hero_id == "cheikh" else 0.34
            var factor := clampf(target_size / longest, 0.001, 100.0)
            backpack_visual.scale *= Vector3.ONE * factor
            var centered_result := _calculate_visual_bounds(anchor)
            if bool(centered_result.get("valid", false)):
                var centered_bounds: AABB = centered_result.get("bounds", AABB())
                var center := centered_bounds.position + centered_bounds.size * 0.5
                backpack_visual.position -= center

    backpack_node = anchor

func _normalize_weapon_visual() -> void:
    if weapon_node == null or not is_instance_valid(weapon_node):
        return
    var result := _calculate_visual_bounds(weapon_node)
    if not bool(result.get("valid", false)):
        return
    var bounds: AABB = result.get("bounds", AABB())
    var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
    if longest <= 0.001:
        return

    var target_length := 1.05
    var world_factor := clampf(target_length / longest, 0.001, 40.0)
    var parent_scaled_by_hero := hero_model != null and hero_model.is_ancestor_of(weapon_node)
    var local_factor := world_factor
    if parent_scaled_by_hero and _visual_scale_factor > 0.001:
        local_factor /= _visual_scale_factor
    weapon_node.scale = Vector3.ONE * local_factor

func basic_attack() -> void:
    var attack := {
        "id": "base_%s" % str(GameState.selected_hero),
        "name": str(hero_data.get("base_attack", "Attaque")),
        "damage": float(hero_data.get("base_attack_damage", 28.0)) * _level_damage_multiplier(),
        "radius": float(hero_data.get("base_attack_radius", 2.45)),
        "effect": str(hero_data.get("base_attack_effect", "basic")),
        "color": str(hero_data.get("base_attack_color", "ffffff")),
        "unlock_level": 1
    }
    print("%s: %s" % [hero_data.get("display_name", "Héros"), attack["name"]])
    _attack_lock = 0.48
    _play_attack_animation(str(attack["effect"]))
    basic_attack_used.emit(attack)

    if NetworkManager.is_client():
        NetworkManager.request_combat("basic", -1)
        get_tree().call_group("hero_voice_director", "play_event", "attaque")
        return

    _damage_enemies(float(attack["radius"]), float(attack["damage"]))
    if NetworkManager.is_host():
        NetworkManager.host_broadcast_combat("basic", -1, global_position)
    get_tree().call_group("hero_voice_director", "play_event", "attaque")

func use_ability(index: int) -> bool:
    var actual_index := _resolve_requested_ability_index(index)
    if actual_index < 0:
        _show_next_unlock_message()
        return false

    var abilities: Array = hero_data.get("abilities", [])
    if actual_index >= abilities.size():
        return false
    _ensure_combat_slots(false)
    if actual_index >= cooldowns.size() or cooldowns[actual_index] > 0.0:
        return false

    var ability: Dictionary = abilities[actual_index]
    var unlock_level := maxi(1, int(ability.get("unlock_level", 1)))
    if GameState.level < unlock_level:
        _show_hud_message("VERROUILLÉ • NIVEAU %d" % unlock_level, 1.0)
        return false

    var cost := float(ability.get("energy", 0.0))
    if energy < cost:
        _show_hud_message("POUVOIR INSUFFISANT", 0.85)
        return false

    if NetworkManager.is_client():
        energy -= cost
        cooldowns[actual_index] = float(ability.get("cooldown", 1.0))
        energy_changed.emit(energy, max_energy)
        ability_used.emit(actual_index, ability)
        _attack_lock = 0.65
        _play_attack_animation(str(ability.get("effect", "power")))
        NetworkManager.request_combat("ability", actual_index)
        get_tree().call_group("hero_voice_director", "play_event", "attaque")
        return true

    var used := super.use_ability(actual_index)
    if used:
        if NetworkManager.is_host():
            NetworkManager.host_broadcast_combat("ability", actual_index, global_position)
        get_tree().call_group("hero_voice_director", "play_event", "attaque")
    return used

func _apply_ability_effect(_index: int, ability: Dictionary) -> void:
    var damage := float(ability.get("damage", 0.0)) * _level_damage_multiplier()
    var radius := maxf(1.0, float(ability.get("radius", 4.0)))
    _damage_enemies(radius, damage)

func _play_attack_animation(effect: String) -> void:
    var lower := effect.to_lower()
    if lower.contains("blade") or lower.contains("crystal") or lower.contains("cerberus"):
        _play_animation_by_keywords(["slash", "swing", "attack", "skill", "power"], false)
    else:
        _play_animation_by_keywords(["power", "skill", "attack", "punch", "hit"], false)

func cycle_special_attack() -> void:
    var unlocked := _unlocked_special_indices()
    if unlocked.is_empty():
        _selected_special_index = -1
        special_selection_changed.emit(-1, {})
        _show_next_unlock_message()
        return

    var position := unlocked.find(_selected_special_index)
    if position < 0:
        _selected_special_index = int(unlocked[0])
    else:
        _selected_special_index = int(unlocked[(position + 1) % unlocked.size()])
    var ability := selected_special_attack()
    special_selection_changed.emit(_selected_special_index, ability)
    _show_hud_message("SÉLECTION • %s" % str(ability.get("name", "ATTAQUE")), 1.0)

func selected_special_attack() -> Dictionary:
    var abilities: Array = hero_data.get("abilities", [])
    if _selected_special_index < 0 or _selected_special_index >= abilities.size():
        return {}
    var ability: Dictionary = abilities[_selected_special_index]
    if GameState.level < int(ability.get("unlock_level", 1)):
        return {}
    return ability

func selected_special_index() -> int:
    return _selected_special_index

func next_attack_unlock_level() -> int:
    var result := 0
    var abilities: Array = hero_data.get("abilities", [])
    for raw_ability in abilities:
        var ability: Dictionary = raw_ability
        var unlock_level := int(ability.get("unlock_level", 1))
        if unlock_level > GameState.level and (result == 0 or unlock_level < result):
            result = unlock_level
    return result

func _resolve_requested_ability_index(requested_index: int) -> int:
    # Le premier bouton spécial déclenche l'attaque actuellement sélectionnée.
    # ability_2 reste utilisable au clavier/debug pour tester directement la
    # deuxième capacité sans ajouter de bouton supplémentaire sur mobile.
    if requested_index == 0:
        return _selected_special_index
    return requested_index

func _unlocked_special_indices() -> Array[int]:
    var result: Array[int] = []
    var abilities: Array = hero_data.get("abilities", [])
    for i in range(abilities.size()):
        var ability: Dictionary = abilities[i]
        if GameState.level >= int(ability.get("unlock_level", 1)):
            result.append(i)
    return result

func _select_first_unlocked_special() -> void:
    var unlocked := _unlocked_special_indices()
    _selected_special_index = int(unlocked[0]) if not unlocked.is_empty() else -1
    special_selection_changed.emit(_selected_special_index, selected_special_attack())

func _ensure_combat_slots(reset_values: bool) -> void:
    var abilities: Array = hero_data.get("abilities", [])
    var old_size := cooldowns.size()
    cooldowns.resize(abilities.size())
    for i in range(abilities.size()):
        if reset_values or i >= old_size:
            cooldowns[i] = 0.0

func _level_damage_multiplier() -> float:
    var growth := maxf(0.0, float(hero_data.get("damage_growth", 0.02)))
    return 1.0 + float(maxi(0, GameState.level - 1)) * growth

func _apply_level_stats() -> void:
    var previous_max_health := maxf(1.0, max_health)
    var previous_max_energy := maxf(1.0, max_energy)
    var health_ratio := clampf(health / previous_max_health, 0.0, 1.0)
    var energy_ratio := clampf(energy / previous_max_energy, 0.0, 1.0)
    var level_offset := float(maxi(0, GameState.level - 1))

    max_health = float(hero_data.get("base_health", 165.0)) + level_offset * float(hero_data.get("health_per_level", 5.0))
    max_energy = float(hero_data.get("base_energy", 100.0)) + level_offset * float(hero_data.get("energy_per_level", 1.0))
    health = clampf(max_health * health_ratio, 0.0, max_health)
    energy = clampf(max_energy * energy_ratio, 0.0, max_energy)
    health_changed.emit(health, max_health)
    energy_changed.emit(energy, max_energy)

func _on_progression_changed() -> void:
    var new_level := maxi(1, GameState.level)
    if new_level == _last_known_level:
        return

    var old_level := _last_known_level
    _last_known_level = new_level
    _apply_level_stats()
    _ensure_combat_slots(false)

    var abilities: Array = hero_data.get("abilities", [])
    var newly_unlocked: Dictionary = {}
    for raw_ability in abilities:
        var ability: Dictionary = raw_ability
        var unlock_level := int(ability.get("unlock_level", 1))
        if unlock_level > old_level and unlock_level <= new_level:
            newly_unlocked = ability

    if _selected_special_index < 0 or selected_special_attack().is_empty():
        _select_first_unlocked_special()

    if not newly_unlocked.is_empty():
        _show_hud_message("NOUVELLE ATTAQUE • %s" % str(newly_unlocked.get("name", "ATTAQUE")), 1.8)

func _show_next_unlock_message() -> void:
    var next_level := next_attack_unlock_level()
    if next_level > 0:
        _show_hud_message("PROCHAINE ATTAQUE • NIVEAU %d" % next_level, 1.15)
    else:
        _show_hud_message("TOUTES LES ATTAQUES SONT DÉBLOQUÉES", 1.15)

func _show_hud_message(text_value: String, duration: float) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", text_value, duration)

func _on_hero_changed(hero_id: String) -> void:
    super._on_hero_changed(hero_id)
    _last_known_level = maxi(1, GameState.level)
    _ensure_combat_slots(true)
    _apply_level_stats()
    _select_first_unlocked_special()

func receive_damage(amount: float) -> void:
    var health_before := health
    super.receive_damage(amount)
    if health < health_before:
        get_tree().call_group("hero_voice_director", "play_event", "douleur")
