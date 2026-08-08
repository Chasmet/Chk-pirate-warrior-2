class_name HeroControllerV3
extends "res://scripts/player/hero_controller_v2.gd"

func _ready() -> void:
    move_speed = 8.2
    run_speed = 11.0
    rotation_speed = 16.0
    super._ready()

func _load_visuals() -> void:
    super._load_visuals()
    _align_loaded_hero_visual()
    _normalize_weapon_visual()

func _align_loaded_hero_visual() -> void:
    if hero_model == null or not is_instance_valid(hero_model):
        return

    # Le GLB de Cheikh regarde vers +Z alors que le contrôleur Godot avance vers -Z.
    # Yvane et Nelvyn sont déjà orientés correctement et ne doivent surtout pas
    # recevoir cette rotation supplémentaire.
    var model_path := str(hero_data.get("model", "")).to_lower()
    if model_path.contains("joueur 1 cheikh"):
        hero_model.rotation_degrees.y += 180.0

func _attach_backpack(backpack_visual: Node3D) -> void:
    # Les trois sacs utilisent le même point d'attache dans le dos, mais leurs GLB
    # n'ont pas tous le même axe avant. Cheikh reste à 180° (validé sur téléphone),
    # tandis que les sacs Yvane/Nelvyn doivent rester à 0° pour ne plus être à l'envers.
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
