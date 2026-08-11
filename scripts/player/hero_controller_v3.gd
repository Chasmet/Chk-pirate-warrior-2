class_name HeroControllerV3
extends "res://scripts/player/hero_controller_v2.gd"

@export var backpedal_rotation_threshold := 0.18

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
    # Le contrôleur de base gère le vrai déplacement 360°. Après son mouvement,
    # on corrige uniquement l'orientation quand le joueur tire franchement le
    # joystick vers le bas : le héros recule alors en gardant son torse vers
    # l'avant/caméra, au lieu de faire demi-tour et courir vers le joueur.
    super._physics_process(delta)
    _apply_backpedal_facing(delta)

func _apply_backpedal_facing(delta: float) -> void:
    if _dodge_time > 0.0 or _attack_lock > 0.0:
        return
    var keyboard_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var input_vec := _virtual_move
    if keyboard_vec.length() > input_vec.length():
        input_vec = keyboard_vec
    if input_vec.y <= backpedal_rotation_threshold:
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
    rotation.y = lerp_angle(rotation.y, target_angle, minf(1.0, rotation_speed * 1.15 * delta))

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
