class_name ArchipelagoDirectorV2
extends ArchipelagoDirector

var _final_gate_notice_cooldown := 0.0

func _process(delta: float) -> void:
    _final_gate_notice_cooldown = maxf(0.0, _final_gate_notice_cooldown - delta)
    super._process(delta)
    GameState.world_time = _day_clock

func _load_island(index: int, place_player: bool) -> void:
    var resolved := clampi(index, 0, WorldCatalog.island_count() - 1)
    if resolved == 10 and not GameState.can_enter_island(11):
        _reject_final_kingdom()
        return
    super._load_island(resolved, place_player)
    _update_hud_mission(resolved)
    _restore_exact_position_if_needed(resolved, place_player)

func on_boss_defeated(enemy: Node) -> void:
    if _current_index < 0:
        return
    var island_id := _current_index + 1
    GameState.mark_boss_defeated(island_id)
    GameState.add_xp(450 + island_id * 75)
    GameState.add_coins(180 + island_id * 35)
    super.on_boss_defeated(enemy)
    _update_hud_mission(_current_index)
    if island_id == 10 and GameState.can_enter_island(11):
        _notify("LES DIX ROYAUMES SONT LIBÉRÉS • LE ROYAUME TROUBLÉ EST ACCESSIBLE")
    elif island_id == 11:
        GameState.final_reward_collected = true
        GameState.quick_save()

func _spawn_population_and_enemies(info: Dictionary) -> void:
    var island_id := int(info["id"])
    var size: Vector2 = info["size"]
    var difficulty_multiplier := GameState.difficulty_enemy_multiplier()
    var soldier_paths: Array = info.get("soldiers", [])
    if island_id != 11 and not soldier_paths.is_empty():
        for i in range(soldier_count):
            var path := str(soldier_paths[i % soldier_paths.size()])
            var angle := TAU * float(i) / float(maxi(1, soldier_count))
            var radius := minf(size.x, size.y) * (0.12 + float(i % 3) * 0.045)
            var base_difficulty := 0.8 + float(island_id) * 0.12
            _spawn_enemy(path, Vector3(cos(angle) * radius, 10.0, sin(angle) * radius), false, base_difficulty * difficulty_multiplier)

    if GameState.is_boss_defeated(island_id):
        return
    var boss_path := str(info["boss"])
    if ResourceLoader.exists(boss_path):
        var boss_difficulty := (1.0 + float(island_id) * 0.16) * difficulty_multiplier
        _spawn_enemy(boss_path, Vector3(0.0, 12.0, -size.y * 0.18), true, boss_difficulty)

func request_boat_interaction() -> bool:
    var active := get_tree().get_first_node_in_group("active_controller")
    if active != null and active.has_method("disembark"):
        var nearest := _nearest_island_index(active.global_position if active is Node3D else _player.global_position)
        if nearest == 10 and not GameState.can_enter_island(11):
            _notify("Le Royaume Troublé reste scellé. Libère les dix premiers royaumes.")
            return false
    var result := super.request_boat_interaction()
    if result:
        _capture_snapshot()
    return result

func _reject_final_kingdom() -> void:
    if _final_gate_notice_cooldown <= 0.0:
        _final_gate_notice_cooldown = 4.0
        var remaining := 10 - GameState.defeated_main_boss_count()
        _notify("ROYAUME TROUBLÉ SCELLÉ • %d boss majeurs restent à vaincre" % maxi(0, remaining))
    if _player == null or not is_instance_valid(_player):
        return
    var positions := WorldCatalog.world_positions()
    if positions.size() < 11:
        return
    var safe_center: Vector3 = positions[9]
    var final_center: Vector3 = positions[10]
    var away := safe_center - final_center
    away.y = 0.0
    if away.length_squared() < 0.01:
        away = Vector3.FORWARD
    var info := WorldCatalog.island(9)
    var safe_size: Vector2 = info["size"]
    _player.global_position = safe_center + away.normalized() * maxf(safe_size.x, safe_size.y) * 0.57 + Vector3.UP * 3.0
    _player.velocity = Vector3.ZERO

func _update_hud_mission(index: int) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud == null or not hud.has_method("set_mission"):
        return
    var info := WorldCatalog.island(index)
    var island_id := index + 1
    var description := ""
    if island_id == 11:
        description = "Trouve et vaincs le gardien final, puis récupère le trophée du Royaume Troublé."
    elif GameState.is_boss_defeated(island_id):
        description = "Royaume libéré • explore les secrets, améliore ton équipage ou reprends la mer."
    else:
        description = "Explore le royaume, combats les forces locales et vaincs le boss majeur. Progression : %d/10 boss." % GameState.defeated_main_boss_count()
    hud.set_mission("ÎLE %02d • %s" % [island_id, str(info["name"])], description)

func _capture_snapshot() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var boat_mode := get_tree().get_first_node_in_group("active_controller") != null
    GameState.set_exact_snapshot(_player.global_position, _player.rotation.y, boat_mode)
    GameState.quick_save()

func _restore_exact_position_if_needed(index: int, place_player: bool) -> void:
    if not place_player or index + 1 != GameState.current_island:
        return
    var saved := GameState.exact_position_vector()
    if not saved.is_finite() or _player == null or not is_instance_valid(_player):
        return
    var center := _positions[index]
    var info := WorldCatalog.island(index)
    var size: Vector2 = info["size"]
    var flat := Vector2(saved.x - center.x, saved.z - center.z)
    if flat.length() <= maxf(size.x, size.y) * 0.75:
        _player.global_position = saved
        _player.rotation.y = GameState.exact_rotation_y
