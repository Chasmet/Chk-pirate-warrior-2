class_name ArchipelagoDirectorV2
extends ArchipelagoDirector

const SOLDIERS_REQUIRED := 6
const COMMANDANT_2_REQUIRED := 1
const COMMANDANT_1_REQUIRED := 1
const FINAL_PICKUP_RADIUS := 5.0
const SAFE_LAND_MIN_Y := -1.15

var _final_gate_notice_cooldown := 0.0
var _boss_spawned_for_island := -1
var _ocean_rescue_cooldown := 0.0

func _ready() -> void:
    _day_clock = clampf(GameState.world_time, 0.0, 1.0)
    super._ready()

func _process(delta: float) -> void:
    _final_gate_notice_cooldown = maxf(0.0, _final_gate_notice_cooldown - delta)
    _ocean_rescue_cooldown = maxf(0.0, _ocean_rescue_cooldown - delta)
    super._process(delta)
    GameState.world_time = _day_clock
    _update_final_reward_collection()
    _rescue_player_from_ocean()

func restore_loaded_game() -> void:
    _day_clock = clampf(GameState.world_time, 0.0, 1.0)
    var target_index: int = clampi(GameState.current_island - 1, 0, WorldCatalog.island_count() - 1)
    if target_index == 10 and not GameState.can_enter_island(11):
        target_index = 9
        GameState.exact_position.clear()
        GameState.exact_boat_mode = false
    _current_index = -1
    _load_island(target_index, true)

func _load_island(index: int, place_player: bool) -> void:
    var resolved := clampi(index, 0, WorldCatalog.island_count() - 1)
    if resolved == 10 and not GameState.can_enter_island(11):
        _reject_final_kingdom()
        return
    _preserve_active_boat_for_transition()
    _boss_spawned_for_island = -1
    super._load_island(resolved, place_player)
    _update_hud_mission(resolved)
    _restore_exact_position_if_needed(resolved, place_player)
    _restore_boat_mode_if_needed(resolved, place_player)
    _ensure_safe_spawn(resolved, place_player)
    if resolved == 10 and GameState.is_boss_defeated(11) and not GameState.final_reward_collected:
        _ensure_final_reward()

func on_enemy_defeated(_enemy: Node) -> void:
    if _current_index < 0:
        return
    var island_id := _current_index + 1
    if island_id == 11 or GameState.is_boss_defeated(island_id):
        return
    var stage := _enemy_progress_stage(island_id)
    if stage == "soldiers":
        var current := clampi(int(GameState.get_quest_value(_soldier_key(island_id), 0)), 0, SOLDIERS_REQUIRED)
        if current >= SOLDIERS_REQUIRED:
            return
        current += 1
        GameState.set_quest_value(_soldier_key(island_id), current)
        GameState.add_xp(28 + island_id * 4)
        GameState.add_coins(12 + island_id * 2)
        if current < SOLDIERS_REQUIRED:
            _notify("Forces locales vaincues : %d/%d" % [current, SOLDIERS_REQUIRED])
        else:
            _notify("FORCES LOCALES VAINCUES • LE COMMANDANT 2 ARRIVE")
            _spawn_hierarchy_enemy(_current_index, 2)
    elif stage == "commandant_2":
        GameState.set_quest_value(_commandant_key(island_id, 2), 1)
        GameState.add_xp(110 + island_id * 8)
        GameState.add_coins(55 + island_id * 5)
        _notify("COMMANDANT 2 VAINCU • LE COMMANDANT 1 ARRIVE")
        _spawn_hierarchy_enemy(_current_index, 1)
    elif stage == "commandant_1":
        GameState.set_quest_value(_commandant_key(island_id, 1), 1)
        GameState.add_xp(180 + island_id * 12)
        GameState.add_coins(90 + island_id * 8)
        _notify("COMMANDANT 1 VAINCU • LE GRAND BOSS ARRIVE")
        _spawn_current_boss()
    else:
        return
    GameState.quick_save()
    _update_hud_mission(_current_index)

func on_boss_defeated(enemy: Node) -> void:
    if _current_index < 0:
        return
    var island_id := _current_index + 1
    if GameState.is_boss_defeated(island_id):
        return
    GameState.mark_boss_defeated(island_id)
    GameState.add_xp(450 + island_id * 75)
    GameState.add_coins(180 + island_id * 35)
    super.on_boss_defeated(enemy)
    _update_hud_mission(_current_index)
    if island_id == 10 and GameState.can_enter_island(11):
        _notify("LES DIX ROYAUMES SONT LIBÉRÉS • LE ROYAUME TROUBLÉ EST ACCESSIBLE")
    elif island_id == 11:
        _ensure_final_reward()
        GameState.quick_save()
        _notify("GARDIEN FINAL VAINCU • APPROCHE-TOI DU TROPHÉE RARE")

func _spawn_population_and_enemies(info: Dictionary) -> void:
    var island_id := int(info["id"])
    if GameState.is_boss_defeated(island_id):
        return

    var size: Vector2 = info["size"]
    var difficulty_multiplier := GameState.difficulty_enemy_multiplier()
    var soldier_paths: Array = info.get("soldiers", [])
    var soldier_names: Array = info.get("soldier_names", [])
    var soldier_archetypes: Array = info.get("soldier_archetypes", [])
    var progress := clampi(int(GameState.get_quest_value(_soldier_key(island_id), 0)), 0, SOLDIERS_REQUIRED)

    if island_id != 11 and progress < SOLDIERS_REQUIRED and not soldier_paths.is_empty():
        var remaining := SOLDIERS_REQUIRED - progress
        var spawn_count := clampi(maxi(remaining, 3), 3, soldier_count)
        for i in range(spawn_count):
            var variant := (i + progress) % soldier_paths.size()
            var path := str(soldier_paths[variant])
            var display_name := str(soldier_names[variant % soldier_names.size()]) if not soldier_names.is_empty() else "Force locale"
            var archetype := str(soldier_archetypes[variant % soldier_archetypes.size()]) if not soldier_archetypes.is_empty() else "melee"
            var angle := TAU * float(i) / float(maxi(1, spawn_count))
            var radius := minf(size.x, size.y) * (0.12 + float(i % 3) * 0.045)
            var base_difficulty := 0.8 + float(island_id) * 0.12
            _spawn_enemy(path, Vector3(cos(angle) * radius, 10.0, sin(angle) * radius), false, base_difficulty * difficulty_multiplier, display_name, archetype, variant)
        return

    if island_id == 11:
        _spawn_boss(info, difficulty_multiplier)
    elif progress >= SOLDIERS_REQUIRED and int(GameState.get_quest_value(_commandant_key(island_id, 2), 0)) == 0:
        _spawn_hierarchy_enemy(_current_index, 2)
    elif int(GameState.get_quest_value(_commandant_key(island_id, 2), 0)) == 1 and int(GameState.get_quest_value(_commandant_key(island_id, 1), 0)) == 0:
        _spawn_hierarchy_enemy(_current_index, 1)
    else:
        _spawn_current_boss()

func _commandant_key(island_id: int, rank: int) -> String:
    return "island_%02d_commandant_%d" % [island_id, rank]

func _enemy_progress_stage(island_id: int) -> String:
    if int(GameState.get_quest_value(_soldier_key(island_id), 0)) < SOLDIERS_REQUIRED:
        return "soldiers"
    if int(GameState.get_quest_value(_commandant_key(island_id, 2), 0)) == 0:
        return "commandant_2"
    if int(GameState.get_quest_value(_commandant_key(island_id, 1), 0)) == 0:
        return "commandant_1"
    return "grand_boss"

func _hierarchy_asset(info: Dictionary, rank: int) -> String:
    # Les noms des GLB font foi : commandant 1 et commandant 2 sont recherchés
    # dans le dossier du royaume avant d'utiliser un modèle de renfort vrac.
    var folder := str(info.get("folder", ""))
    var dir := DirAccess.open(folder)
    var candidates: Array[String] = []
    if dir != null:
        for filename in dir.get_files():
            var lower := filename.to_lower()
            if not lower.ends_with(".glb") or not lower.contains("commandant"):
                continue
            if rank == 1 and (lower.contains("1 er") or lower.contains("1er") or lower.contains("1er")):
                candidates.append(folder + "/" + filename)
            elif rank == 2 and (lower.contains("2") or lower.contains("2eme") or lower.contains("2 ème") or lower.contains("2ème")):
                candidates.append(folder + "/" + filename)
    if not candidates.is_empty() and ResourceLoader.exists(candidates[0]):
        return candidates[0]
    var fallback := "res://assets/vrac/chef_militaire_anime_compresse.glb" if rank == 1 else "res://assets/vrac/commandant_arbre_anime_compresse.glb"
    return fallback if ResourceLoader.exists(fallback) else str(info.get("soldiers", [""])[0])

func _spawn_hierarchy_enemy(index: int, rank: int) -> void:
    if index < 0 or index >= WorldCatalog.island_count() or _has_live_boss():
        return
    var info := WorldCatalog.island(index)
    var island_id := int(info["id"])
    var key := _commandant_key(island_id, rank)
    if int(GameState.get_quest_value(key, 0)) == 1:
        return
    var path := _hierarchy_asset(info, rank)
    if not ResourceLoader.exists(path):
        _notify("GLB du commandant %d indisponible pour l’île %02d" % [rank, island_id])
        return
    var size: Vector2 = info["size"]
    var name := "Commandant 1" if rank == 1 else "Commandant 2"
    var archetype := "boss_duelist" if rank == 1 else "boss_guard"
    _spawn_enemy(path, Vector3(0.0, 12.0, -size.y * (0.10 if rank == 1 else 0.05)), false, (1.25 + island_id * 0.14), name, archetype, 20 + rank)

func _spawn_current_boss() -> void:
    if _current_index < 0 or _island_root == null or not is_instance_valid(_island_root):
        return
    if _boss_spawned_for_island == _current_index:
        return
    if _has_live_boss():
        _boss_spawned_for_island = _current_index
        return
    var info := WorldCatalog.island(_current_index)
    _spawn_boss(info, GameState.difficulty_enemy_multiplier())

func _spawn_boss(info: Dictionary, difficulty_multiplier: float) -> void:
    var island_id := int(info["id"])
    if GameState.is_boss_defeated(island_id) or _has_live_boss():
        return
    var boss_path := str(info["boss"])
    if not ResourceLoader.exists(boss_path):
        _notify("Boss indisponible pour l’île %02d : modèle GLB invalide." % island_id)
        return
    var size: Vector2 = info["size"]
    var boss_difficulty := (1.0 + float(island_id) * 0.16) * difficulty_multiplier
    _spawn_enemy(
        boss_path,
        Vector3(0.0, 12.0, -size.y * 0.18),
        true,
        boss_difficulty,
        str(info.get("boss_name", "Boss")),
        str(info.get("boss_archetype", "boss_brute")),
        0
    )
    _boss_spawned_for_island = _current_index

func _has_live_boss() -> bool:
    for node in get_tree().get_nodes_in_group("enemy"):
        if is_instance_valid(node) and bool(node.get("boss")):
            return true
    return false

func request_boat_interaction() -> bool:
    var active_before := get_tree().get_first_node_in_group("active_controller")
    if active_before != null and active_before.has_method("disembark"):
        var nearest := _nearest_island_index(active_before.global_position if active_before is Node3D else _player.global_position)
        if nearest == 10 and not GameState.can_enter_island(11):
            _notify("Le Royaume Troublé reste scellé. Libère les dix premiers royaumes.")
            return false
    var result := super.request_boat_interaction()
    if result:
        if active_before is BoatController and is_instance_valid(active_before) and not active_before.is_boarded():
            if _island_root != null and is_instance_valid(_island_root):
                active_before.reparent(_island_root, true)
        _capture_snapshot()
    return result

func respawn_player() -> void:
    if _player == null or not is_instance_valid(_player) or _current_index < 0:
        return
    var active := get_tree().get_first_node_in_group("active_controller")
    if active != null and active.has_method("force_disembark_at"):
        active.call("force_disembark_at", _safe_port_spawn(_current_index), 0.0)
    _place_player_at_safe_port(_current_index, true)
    _notify("Retour au port de l’île %02d." % (_current_index + 1))

func _ensure_safe_spawn(index: int, place_player: bool) -> void:
    if not place_player or _player == null or not is_instance_valid(_player):
        return
    if GameState.exact_boat_mode:
        return
    var active := get_tree().get_first_node_in_group("active_controller")
    if active is BoatController and active.is_boarded():
        return
    var saved := GameState.exact_position_vector()
    if saved.is_finite() and _is_saved_land_position_safe(index, saved):
        return
    _place_player_at_safe_port(index, false)

func _is_saved_land_position_safe(index: int, position: Vector3) -> bool:
    if index < 0 or index >= _positions.size() or position.y < SAFE_LAND_MIN_Y:
        return false
    var info := WorldCatalog.island(index)
    var size: Vector2 = info["size"]
    var center := _positions[index]
    var nx := (position.x - center.x) / maxf(1.0, size.x * 0.5)
    var nz := (position.z - center.z) / maxf(1.0, size.y * 0.5)
    return sqrt(nx * nx + nz * nz) <= 0.72

func _safe_port_spawn(index: int) -> Vector3:
    var resolved := clampi(index, 0, WorldCatalog.island_count() - 1)
    var info := WorldCatalog.island(resolved)
    var size: Vector2 = info["size"]
    return _positions[resolved] + Vector3(0.0, 3.4, size.y * 0.45 + 12.0)

func _place_player_at_safe_port(index: int, save_now: bool) -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var safe := _safe_port_spawn(index)
    _player.global_position = safe
    _player.global_rotation = Vector3.ZERO
    _player.velocity = Vector3.ZERO
    GameState.set_exact_snapshot(safe, 0.0, false)
    if save_now:
        GameState.quick_save()

func _rescue_player_from_ocean() -> void:
    if _ocean_rescue_cooldown > 0.0 or _current_index < 0:
        return
    if _player == null or not is_instance_valid(_player):
        return
    var active := get_tree().get_first_node_in_group("active_controller")
    if active is BoatController and active.is_boarded():
        return
    if _player.global_position.y >= SAFE_LAND_MIN_Y:
        return
    _ocean_rescue_cooldown = 2.0
    if active != null and active.has_method("force_disembark_at"):
        active.call("force_disembark_at", _safe_port_spawn(_current_index), 0.0)
    _place_player_at_safe_port(_current_index, true)
    _notify("EAU TROP PROFONDE • retour automatique au port")

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
    var safe_position := safe_center + away.normalized() * maxf(safe_size.x, safe_size.y) * 0.57 + Vector3.UP * 3.0
    var active := get_tree().get_first_node_in_group("active_controller")
    if active is BoatController and active.is_boarded():
        active.force_reposition(safe_position, active.rotation.y)
    else:
        if active != null and active.has_method("force_disembark_at"):
            active.call("force_disembark_at", safe_position, 0.0)
        _player.global_position = safe_position
        _player.velocity = Vector3.ZERO
        GameState.set_exact_snapshot(_player.global_position, _player.global_rotation.y, false)

func _update_hud_mission(index: int) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud == null or not hud.has_method("set_mission"):
        return
    var info := WorldCatalog.island(index)
    var island_id := index + 1
    var description := ""
    if island_id == 11:
        if GameState.final_reward_collected:
            description = "AVENTURE PRINCIPALE TERMINÉE • le trophée rare est à toi. Exploration libre."
        elif GameState.is_boss_defeated(11):
            description = "Le gardien est vaincu • récupère maintenant le trophée rare du Royaume Troublé."
        else:
            description = "Affronte le gardien final, puis récupère le trophée rare du Royaume Troublé."
    elif GameState.is_boss_defeated(island_id):
        description = "Royaume libéré • explore les secrets, améliore ton équipage ou reprends la mer."
    else:
        var progress := clampi(int(GameState.get_quest_value(_soldier_key(island_id), 0)), 0, SOLDIERS_REQUIRED)
        if progress < SOLDIERS_REQUIRED:
            description = "Sécurise le royaume : forces locales %d/%d • puis Commandant 2 → Commandant 1 → Grand boss." % [progress, SOLDIERS_REQUIRED]
        elif int(GameState.get_quest_value(_commandant_key(island_id, 2), 0)) == 0:
            description = "OBJECTIF HIÉRARCHIQUE • vaincs le COMMANDANT 2."
        elif int(GameState.get_quest_value(_commandant_key(island_id, 1), 0)) == 0:
            description = "OBJECTIF HIÉRARCHIQUE • vaincs le COMMANDANT 1."
        else:
            description = "OBJECTIF MAJEUR • le GRAND BOSS est apparu. Vaincs-le pour libérer le royaume."
    description = "%d/10 royaumes libérés • %s" % [GameState.defeated_main_boss_count(), description]
    hud.set_mission("ÎLE %02d • %s" % [island_id, str(info["name"])], description)

func _soldier_key(island_id: int) -> String:
    return "island_%02d_forces" % island_id

func _ensure_final_reward() -> void:
    if _island_root == null or not is_instance_valid(_island_root) or GameState.final_reward_collected:
        return
    if _island_root.get_node_or_null("TropheeFinal") != null:
        return
    var info := WorldCatalog.island(10)
    if not info.has("reward"):
        return
    var reward := _instantiate_asset(str(info["reward"]))
    if reward == null:
        return
    reward.name = "TropheeFinal"
    reward.position = Vector3(0.0, 7.0, -40.0)
    reward.scale *= Vector3.ONE * 1.6
    _island_root.add_child(reward)

func _update_final_reward_collection() -> void:
    if _current_index != 10 or GameState.final_reward_collected or _player == null or not is_instance_valid(_player):
        return
    if not GameState.is_boss_defeated(11) or _island_root == null or not is_instance_valid(_island_root):
        return
    var reward := _island_root.get_node_or_null("TropheeFinal") as Node3D
    if reward == null:
        _ensure_final_reward()
        reward = _island_root.get_node_or_null("TropheeFinal") as Node3D
    if reward == null:
        return
    if _player.global_position.distance_to(reward.global_position) <= FINAL_PICKUP_RADIUS:
        GameState.final_reward_collected = true
        GameState.add_xp(2500)
        GameState.add_coins(2500)
        GameState.quick_save()
        reward.queue_free()
        _notify("CAMPAGNE TERMINÉE • TROPHÉE RARE OBTENU • EXPLORATION LIBRE")
        _update_hud_mission(10)

func _capture_snapshot() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var active := get_tree().get_first_node_in_group("active_controller")
    var boat_mode: bool = active is BoatController and (active as BoatController).is_boarded()
    GameState.set_exact_snapshot(_player.global_position, _player.global_rotation.y, boat_mode)
    GameState.quick_save()

func _restore_exact_position_if_needed(index: int, place_player: bool) -> void:
    if not place_player or index + 1 != GameState.current_island:
        return
    if GameState.exact_boat_mode:
        return
    var saved := GameState.exact_position_vector()
    if not saved.is_finite() or _player == null or not is_instance_valid(_player):
        return
    if _is_saved_land_position_safe(index, saved):
        _player.global_position = saved
        _player.global_rotation = Vector3(0.0, GameState.exact_rotation_y, 0.0)

func _restore_boat_mode_if_needed(index: int, place_player: bool) -> void:
    if not place_player or not GameState.exact_boat_mode or index + 1 != GameState.current_island:
        return
    if _player == null or not is_instance_valid(_player):
        return
    var saved := GameState.exact_position_vector()
    if not saved.is_finite():
        return
    var best_boat: BoatController
    var best_distance: float = INF
    for node in get_tree().get_nodes_in_group("boat"):
        if node is BoatController:
            var boat := node as BoatController
            if boat.is_boarded():
                continue
            if _island_root == null or not is_instance_valid(_island_root) or not _island_root.is_ancestor_of(boat):
                continue
            var distance: float = boat.global_position.distance_to(saved)
            if distance < best_distance:
                best_distance = distance
                best_boat = boat
    if best_boat == null:
        return
    best_boat.force_reposition(saved, GameState.exact_rotation_y)
    best_boat.board(_player)

func _preserve_active_boat_for_transition() -> void:
    var active := get_tree().get_first_node_in_group("active_controller")
    if not (active is BoatController) or not active.is_boarded():
        return
    if active.get_parent() == self:
        return
    active.reparent(self, true)
