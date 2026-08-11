class_name HeroControllerV3
extends "res://scripts/player/hero_controller_v2.gd"

@export var backpedal_rotation_threshold := 0.18
@export var backpedal_max_strength := 0.72
@export var quick_turn_input_threshold := 0.78
@export var quick_turn_speed_multiplier := 2.55

var _mount_pose_active := false
var _mount_visual_position := Vector3.ZERO
var _mount_visual_rotation := Vector3.ZERO

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

func _physics_process(delta: float) -> void:
    # Le contrôleur de base garde le déplacement caméra-relatif 360°.
    # V6 ajoute deux comportements analogiques :
    # - joystick tiré modérément vers le bas = vrai recul ;
    # - joystick tiré franchement au maximum = demi-tour rapide puis course.
    super._physics_process(delta)
    _apply_backward_and_turn_facing(delta)

func _movement_input() -> Vector2:
    var keyboard_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := _virtual_move
    if keyboard_vec.length() > input_vec.length():
        input_vec = keyboard_vec
    return input_vec.limit_length(1.0)

func _apply_backward_and_turn_facing(delta: float) -> void:
    if _dodge_time > 0.0 or _attack_lock > 0.0 or _mount_pose_active:
        return
    var input_vec := _movement_input()
    if input_vec.length() <= 0.05:
        return

    # Plein arrière : on ne force plus le héros à rester face caméra. Il pivote
    # très vite vers la direction demandée, ce qui donne un demi-tour net sans
    # glissade latérale.
    if input_vec.y >= quick_turn_input_threshold and input_vec.length() >= quick_turn_input_threshold:
        var turn_direction := _camera_relative_direction(input_vec)
        if turn_direction.length_squared() > 0.001:
            turn_direction = turn_direction.normalized()
            var turn_angle := atan2(-turn_direction.x, -turn_direction.z)
            rotation.y = lerp_angle(rotation.y, turn_angle, minf(1.0, rotation_speed * quick_turn_speed_multiplier * delta))
        return

    # Arrière partiel : recul contrôlé. Les diagonales restent possibles, donc le
    # joueur peut corriger sa trajectoire en reculant sans être bloqué sur un axe.
    if input_vec.y <= backpedal_rotation_threshold or input_vec.length() > backpedal_max_strength:
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
    rotation.y = lerp_angle(rotation.y, target_angle, minf(1.0, rotation_speed * 1.35 * delta))

func set_mounted_pose(mount_style: String) -> void:
    if hero_model == null or not is_instance_valid(hero_model):
        return
    if _mount_pose_active:
        clear_mounted_pose()
    _mount_pose_active = true
    _mount_visual_position = hero_model.position
    _mount_visual_rotation = hero_model.rotation

    # On tente d'abord les animations réellement présentes dans le GLB. En leur
    # absence, l'animation idle reste une solution propre et stable sur Android.
    if mount_style == "horse":
        if not _play_animation_by_keywords(["ride", "horse", "riding", "sit"], true):
            _play_animation_by_keywords(["idle", "stand"], true)
        hero_model.position = _mount_visual_position + Vector3(0.0, -0.38, 0.04)
    else:
        if not _play_animation_by_keywords(["drive", "driving", "sit", "vehicle"], true):
            _play_animation_by_keywords(["idle", "stand"], true)
        hero_model.position = _mount_visual_position + Vector3(0.0, -0.30, 0.02)

    # Évite les armes et sacs qui traversent le volant, le guidon ou la selle.
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

    # Les trois GLB joueurs ont été exportés face +Z, alors que le contrôleur
    # Godot considère -Z comme l'avant. Cheikh était déjà corrigé ; les captures
    # Android montrent que Yvane et Nelvyn regardaient encore la caméra quand ils
    # avançaient, ce qui plaçait aussi leur sac sur le torse. On aligne donc les
    # trois visuels sur le même repère de déplacement, sans toucher au CharacterBody.
    var hero_id := str(GameState.selected_hero).to_lower()
    if hero_id in ["cheikh", "yvane", "nelvyn"]:
        hero_model.rotation_degrees.y += 180.0

func _attach_backpack(backpack_visual: Node3D) -> void:
    # L'ancre +Z est le dos du contrôleur puisque l'avant de déplacement est -Z.
    # Une fois les trois modèles réalignés ci-dessus, le sac se retrouve donc bien
    # derrière le personnage. L'orientation propre du GLB de chaque sac reste
    # spécifique : Cheikh à 180° (déjà validé), Yvane/Nelvyn à 0°.
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
    super.basic_attack()
    # Réplique courte, aléatoire et limitée par le directeur vocal : jamais à chaque coup.
    get_tree().call_group("hero_voice_director", "play_event", "attaque")

func use_ability(index: int) -> bool:
    var used := super.use_ability(index)
    if used:
        # Tant qu'aucune prise "pouvoir" dédiée n'existe, les phrases d'attaque
        # servent aussi aux capacités offensives, avec le même anti-spam.
        get_tree().call_group("hero_voice_director", "play_event", "attaque")
    return used

func receive_damage(amount: float) -> void:
    var health_before := health
    super.receive_damage(amount)
    # Le son part uniquement si le coup a réellement traversé l'invulnérabilité.
    if health < health_before:
        get_tree().call_group("hero_voice_director", "play_event", "douleur")