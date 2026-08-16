class_name WorldEnemy
extends CharacterBody3D

const PROJECTILE_SCRIPT := preload("res://scripts/world/world_enemy_projectile_v11_6.gd")

enum AIState {
    IDLE,
    ALERT,
    SEARCH,
    COMBAT,
    RETREAT
}

@export var model_path := ""
@export var max_health := 100.0
@export var move_speed := 3.2
@export var detection_radius := 28.0
@export var attack_radius := 2.4
@export var attack_damage := 8.0
@export var boss := false
@export var display_name := ""
@export var archetype := "melee"
@export var variant_index := 0
@export var field_of_view_degrees := 125.0
@export var memory_seconds := 4.5
@export var obstacle_probe_distance := 3.8

var health := 100.0
var _visual: Node3D
var _player: Node3D
var _attack_cooldown := 0.0
var _death_reported := false
var _objective_marker: Node3D
var _marker_base_y := 0.0
var _marker_time := 0.0
var _attack_interval := 1.65
var _preferred_distance := 0.0
var _attack_windup := 0.0
var _attack_queued := false
var _phase_two := false
var _strafe_sign := 1.0

# V11.6 — cerveau de combat.
var _ai_state: AIState = AIState.IDLE
var _home_position := Vector3.ZERO
var _last_seen_position := Vector3.ZERO
var _memory_left := 0.0
var _target_scan_cooldown := 0.0
var _los_scan_cooldown := 0.0
var _target_visible := false
var _threat_by_peer: Dictionary = {}
var _navigation_agent: NavigationAgent3D
var _navigation_target := Vector3.INF
var _last_motion_position := Vector3.ZERO
var _stuck_time := 0.0
var _stuck_detour_time := 0.0
var _patrol_phase := 0.0

func _ready() -> void:
    add_to_group("enemy")
    health = max_health
    _home_position = global_position
    _last_seen_position = global_position
    _last_motion_position = global_position
    _patrol_phase = float(variant_index) * 1.37
    _target_scan_cooldown = 0.05 + float(variant_index % 4) * 0.05
    _ensure_navigation_agent()
    _select_best_target(true)
    _load_visual()
    _ensure_objective_marker()
    _set_ai_state(AIState.IDLE)

func configure(path: String, is_boss: bool, difficulty: float = 1.0, enemy_name: String = "", combat_archetype: String = "melee", visual_variant: int = 0) -> void:
    model_path = path
    boss = is_boss
    display_name = enemy_name if not enemy_name.is_empty() else ("Boss" if boss else "Force locale")
    archetype = combat_archetype
    variant_index = visual_variant
    max_health = (620.0 if boss else 105.0) * maxf(0.75, difficulty)
    move_speed = (2.8 if boss else 3.5) + minf(1.5, difficulty * 0.15)
    attack_damage = (22.0 if boss else 8.0) * maxf(0.8, difficulty)
    detection_radius = 52.0 if boss else 34.0
    attack_radius = 3.1 if boss else 2.4
    field_of_view_degrees = 200.0 if boss else 125.0
    memory_seconds = 7.0 if boss else 4.5
    _attack_interval = 1.35 if boss else 1.65
    _preferred_distance = 0.0
    _strafe_sign = -1.0 if visual_variant % 2 == 0 else 1.0
    _apply_archetype_stats()
    health = max_health
    if is_inside_tree():
        _load_visual()
        _ensure_objective_marker()
        _refresh_nameplate()
        _refresh_navigation_settings()

func _apply_archetype_stats() -> void:
    match archetype:
        "guard":
            max_health *= 1.42
            move_speed *= 0.76
            attack_damage *= 0.92
            attack_radius = 2.8
            _attack_interval = 1.78
        "charger":
            max_health *= 0.92
            move_speed *= 1.30
            attack_damage *= 1.20
            _attack_interval = 1.58
        "ranged":
            max_health *= 0.82
            move_speed *= 0.92
            attack_damage *= 0.78
            attack_radius = 11.5
            _preferred_distance = 7.2
            _attack_interval = 1.95
        "duelist":
            max_health *= 0.90
            move_speed *= 1.18
            attack_damage *= 1.04
            attack_radius = 2.7
            _attack_interval = 1.02
        "boss_guard":
            max_health *= 1.38
            move_speed *= 0.76
            attack_damage *= 1.05
            attack_radius = 3.7
            _attack_interval = 1.55
        "boss_ranged":
            max_health *= 1.08
            move_speed *= 0.94
            attack_damage *= 0.88
            attack_radius = 15.0
            _preferred_distance = 9.5
            _attack_interval = 1.72
        "boss_duelist":
            max_health *= 0.96
            move_speed *= 1.24
            attack_damage *= 1.10
            attack_radius = 3.25
            _attack_interval = 0.92
        "boss_brute":
            max_health *= 1.24
            move_speed *= 0.84
            attack_damage *= 1.26
            attack_radius = 3.8
            _attack_interval = 1.46

func receive_damage(amount: float) -> void:
    receive_damage_from_peer(amount, _default_attacker_peer())

func receive_damage_from_peer(amount: float, attacker_peer: int = 0, _origin: Vector3 = Vector3.ZERO) -> void:
    if _death_reported or amount <= 0.0:
        return
    if attacker_peer > 0:
        _threat_by_peer[attacker_peer] = float(_threat_by_peer.get(attacker_peer, 0.0)) + amount * 2.2 + 18.0
        _target_scan_cooldown = 0.0
    health = maxf(0.0, health - amount)
    if boss and not _phase_two and health <= max_health * 0.50:
        _enter_phase_two()
    if health <= 0.0:
        _death_reported = true
        if boss:
            get_tree().call_group("world_director", "on_boss_defeated", self)
        else:
            get_tree().call_group("world_director", "on_enemy_defeated", self)
        queue_free()

func _physics_process(delta: float) -> void:
    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
    _target_scan_cooldown = maxf(0.0, _target_scan_cooldown - delta)
    _los_scan_cooldown = maxf(0.0, _los_scan_cooldown - delta)
    _stuck_detour_time = maxf(0.0, _stuck_detour_time - delta)
    _decay_threat(delta)

    if _attack_queued:
        _attack_windup = maxf(0.0, _attack_windup - delta)
        if _attack_windup <= 0.0:
            _perform_attack()

    _marker_time += delta
    if _objective_marker != null and is_instance_valid(_objective_marker):
        _objective_marker.position.y = _marker_base_y + sin(_marker_time * 2.7) * 0.16
        _objective_marker.rotation.y = fmod(_marker_time * 1.4, TAU)

    if not is_on_floor():
        velocity.y -= 18.0 * delta

    if _player == null or not is_instance_valid(_player) or _target_scan_cooldown <= 0.0:
        _select_best_target(false)

    if _player == null or not is_instance_valid(_player):
        _set_ai_state(AIState.IDLE)
        _run_idle_patrol(delta)
        move_and_slide()
        _update_stuck_state(delta)
        return

    var flat_delta := _player.global_position - global_position
    flat_delta.y = 0.0
    var distance := flat_delta.length()

    if _los_scan_cooldown <= 0.0:
        _los_scan_cooldown = 0.11 + float(variant_index % 3) * 0.025
        _target_visible = _can_see_target(_player)

    if _target_visible:
        _last_seen_position = _player.global_position
        _memory_left = memory_seconds
        if _should_retreat(distance):
            _set_ai_state(AIState.RETREAT)
        elif distance <= detection_radius:
            _set_ai_state(AIState.COMBAT if distance <= maxf(attack_radius * 1.55, _preferred_distance + 5.0) else AIState.ALERT)
    else:
        _memory_left = maxf(0.0, _memory_left - delta)
        if _memory_left > 0.0:
            _set_ai_state(AIState.SEARCH)
        else:
            _set_ai_state(AIState.IDLE)
            if distance > detection_radius * 1.35:
                _player = null

    _run_state_movement(delta, distance)

    if _player != null and is_instance_valid(_player) and _target_visible and distance <= attack_radius and _attack_cooldown <= 0.0 and not _attack_queued:
        _queue_attack()

    move_and_slide()
    _update_stuck_state(delta)

func _run_state_movement(delta: float, distance: float) -> void:
    match _ai_state:
        AIState.IDLE:
            _run_idle_patrol(delta)
        AIState.SEARCH:
            _move_toward_world(_last_seen_position, move_speed * 0.78, delta, false)
        AIState.ALERT:
            if _player != null and is_instance_valid(_player):
                _move_toward_world(_player.global_position, move_speed, delta, true)
        AIState.RETREAT:
            _run_retreat(delta)
        AIState.COMBAT:
            _run_combat_movement(distance, delta)

func _run_idle_patrol(delta: float) -> void:
    if boss:
        _brake_horizontal(move_speed * 5.0 * delta)
        return
    var radius := 3.8 + float(variant_index % 4) * 1.25
    var angle := _marker_time * (0.18 + float(variant_index % 3) * 0.025) + _patrol_phase
    var target := _home_position + Vector3(cos(angle) * radius, 0.0, sin(angle * 0.87) * radius)
    _move_toward_world(target, move_speed * 0.36, delta, false)

func _run_retreat(delta: float) -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var away := global_position - _player.global_position
    away.y = 0.0
    if away.length_squared() <= 0.01:
        away = global_transform.basis.z
    var flank := away.normalized().cross(Vector3.UP) * _strafe_sign * 0.58
    var desired := (away.normalized() + flank).normalized()
    desired = _apply_obstacle_steering(desired)
    desired = _apply_squad_separation(desired)
    _set_horizontal_velocity(desired, move_speed * 1.08, delta)
    _face_world_position(_player.global_position, delta)

func _run_combat_movement(distance: float, delta: float) -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var to_target := _player.global_position - global_position
    to_target.y = 0.0
    var direction := to_target.normalized() if to_target.length_squared() > 0.01 else -global_transform.basis.z
    var desired := Vector3.ZERO
    var speed_scale := 1.0

    if _preferred_distance > 0.0:
        if distance > attack_radius * 0.92:
            desired = direction
        elif distance < _preferred_distance * 0.70:
            desired = -direction
            speed_scale = 1.04
        else:
            desired = direction.cross(Vector3.UP).normalized() * _strafe_sign
            speed_scale = 0.72
    elif distance > attack_radius * 0.88:
        desired = direction
        if archetype == "charger" and distance < detection_radius * 0.55:
            speed_scale = 1.34
        elif archetype in ["duelist", "boss_duelist"] and distance < attack_radius * 2.8:
            desired = (direction + direction.cross(Vector3.UP) * _strafe_sign * 0.42).normalized()
            speed_scale = 1.10
    elif archetype in ["duelist", "boss_duelist"] and not _attack_queued:
        desired = direction.cross(Vector3.UP).normalized() * _strafe_sign
        speed_scale = 0.66

    if _stuck_detour_time > 0.0 and desired.length_squared() > 0.01:
        desired = (desired + desired.cross(Vector3.UP) * _strafe_sign * 0.95).normalized()

    if desired.length_squared() > 0.01 and not _attack_queued:
        desired = _navigation_or_direct_direction(global_position + desired * maxf(4.0, distance), desired)
        desired = _apply_obstacle_steering(desired)
        desired = _apply_squad_separation(desired)
        _set_horizontal_velocity(desired, move_speed * speed_scale, delta)
    else:
        _brake_horizontal(move_speed * 7.0 * delta)

    _face_world_position(_player.global_position, delta)

func _move_toward_world(world_target: Vector3, speed: float, delta: float, face_target: bool) -> void:
    var direct := world_target - global_position
    direct.y = 0.0
    if direct.length_squared() <= 0.08:
        _brake_horizontal(move_speed * 6.0 * delta)
        return
    var desired := _navigation_or_direct_direction(world_target, direct.normalized())
    desired = _apply_obstacle_steering(desired)
    desired = _apply_squad_separation(desired)
    _set_horizontal_velocity(desired, speed, delta)
    if face_target:
        _face_world_position(world_target, delta)
    elif desired.length_squared() > 0.01:
        rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), minf(1.0, 6.0 * delta))

func _set_horizontal_velocity(direction: Vector3, speed: float, delta: float) -> void:
    if direction.length_squared() <= 0.001:
        _brake_horizontal(move_speed * 6.0 * delta)
        return
    var resolved := direction.normalized()
    var target_x := resolved.x * speed
    var target_z := resolved.z * speed
    velocity.x = move_toward(velocity.x, target_x, maxf(4.0, move_speed * 5.5) * delta)
    velocity.z = move_toward(velocity.z, target_z, maxf(4.0, move_speed * 5.5) * delta)

func _brake_horizontal(amount: float) -> void:
    velocity.x = move_toward(velocity.x, 0.0, amount)
    velocity.z = move_toward(velocity.z, 0.0, amount)

func _face_world_position(world_target: Vector3, delta: float) -> void:
    var direction := world_target - global_position
    direction.y = 0.0
    if direction.length_squared() <= 0.001:
        return
    rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 8.0 * delta))

func _queue_attack() -> void:
    _attack_cooldown = _attack_interval
    _attack_queued = true
    _attack_windup = 0.52 if archetype in ["guard", "boss_guard", "boss_brute"] else 0.28
    if archetype in ["ranged", "boss_ranged"]:
        _attack_windup += 0.12
    _set_telegraph(true)

func _perform_attack() -> void:
    _attack_queued = false
    _set_telegraph(false)
    if _player == null or not is_instance_valid(_player):
        return

    var flat_delta := _player.global_position - global_position
    flat_delta.y = 0.0
    var distance := flat_delta.length()
    if distance > attack_radius + (2.2 if boss else 1.0):
        return
    if not _can_see_target(_player, false):
        return

    if archetype in ["ranged", "boss_ranged"]:
        _fire_ranged_attack()
        return

    if archetype == "boss_brute" and _phase_two:
        var shockwave_radius := attack_radius + 3.4
        if distance <= shockwave_radius:
            apply_damage_to_target(_player, attack_damage * 1.12)
        return

    apply_damage_to_target(_player, attack_damage)

func _fire_ranged_attack() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var muzzle := global_position + Vector3.UP * (2.35 if boss else 1.45)
    var aim := _player.global_position + Vector3.UP * 0.95
    var base_direction := aim - muzzle
    if base_direction.length_squared() <= 0.001:
        return
    base_direction = base_direction.normalized()

    var spread_angles: Array[float] = [0.0]
    if boss and _phase_two:
        spread_angles = [-0.10, 0.0, 0.10]

    for spread in spread_angles:
        var projectile = PROJECTILE_SCRIPT.new()
        var parent := get_tree().current_scene
        if parent == null:
            parent = get_parent()
        parent.add_child(projectile)
        projectile.global_position = muzzle
        var direction := base_direction.rotated(Vector3.UP, spread)
        var color := Color("d7a7ff") if boss else Color("ff8f5a")
        projectile.call(
            "configure",
            self,
            _player,
            attack_damage * (0.72 if spread_angles.size() > 1 else 1.0),
            18.0 if boss else 21.5,
            color,
            0.86 if boss else 0.70,
            direction
        )

func apply_damage_to_target(target: Node3D, amount: float) -> void:
    if target == null or not is_instance_valid(target) or amount <= 0.0:
        return

    var network := get_node_or_null("/root/NetworkManager")
    if network != null and network.has_method("is_multiplayer_active") and bool(network.call("is_multiplayer_active")):
        # En coop l'hôte devient l'autorité des dégâts ennemis.
        if not network.has_method("is_host") or not bool(network.call("is_host")):
            return
        var target_peer := _peer_id_for_target(target)
        var local_peer := multiplayer.get_unique_id()
        if target_peer <= 0 or target_peer == local_peer:
            if target.has_method("receive_damage"):
                target.call("receive_damage", amount)
            return
        if network.has_method("host_apply_enemy_damage"):
            network.call("host_apply_enemy_damage", target_peer, amount, display_name)
        return

    if target.has_method("receive_damage"):
        target.call("receive_damage", amount)

func _enter_phase_two() -> void:
    _phase_two = true
    move_speed *= 1.22
    attack_damage *= 1.18
    _attack_interval *= 0.76
    if archetype == "boss_guard":
        attack_radius += 0.55
    elif archetype == "boss_ranged":
        _preferred_distance += 1.25
    _strafe_sign *= -1.0
    _refresh_navigation_settings()
    _refresh_nameplate()
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", "BOSS • %s ENTRE EN PHASE 2" % display_name.to_upper(), 2.8)

func _should_retreat(distance: float) -> bool:
    if boss or max_health <= 0.0:
        return false
    if archetype not in ["ranged", "duelist"]:
        return false
    return health / max_health <= 0.16 and distance < maxf(5.0, _preferred_distance * 0.9)

func _set_ai_state(value: AIState) -> void:
    if _ai_state == value:
        return
    _ai_state = value
    var label := "idle"
    match _ai_state:
        AIState.ALERT: label = "alert"
        AIState.SEARCH: label = "search"
        AIState.COMBAT: label = "combat"
        AIState.RETREAT: label = "retreat"
        _: label = "idle"
    set_meta("ai_state", label)

func _select_best_target(force: bool) -> void:
    if not force and _target_scan_cooldown > 0.0:
        return
    _target_scan_cooldown = 0.28 + float(variant_index % 4) * 0.045
    var candidates := _candidate_targets()
    if candidates.is_empty():
        _player = null
        return

    var best: Node3D
    var best_score := -INF
    for candidate in candidates:
        if candidate == null or not is_instance_valid(candidate):
            continue
        var distance := global_position.distance_to(candidate.global_position)
        var peer_id := _peer_id_for_target(candidate)
        var threat := float(_threat_by_peer.get(peer_id, 0.0)) if peer_id > 0 else 0.0
        if distance > detection_radius * 1.45 and threat <= 0.0:
            continue
        var visible := _can_see_target(candidate)
        var score := maxf(0.0, detection_radius * 1.25 - distance) * 1.8 + threat
        if visible:
            score += 34.0
        if candidate == _player:
            score += 7.5
        if distance <= attack_radius * 1.25:
            score += 18.0
        if score > best_score:
            best_score = score
            best = candidate

    if best != null:
        _player = best
        _target_visible = _can_see_target(_player)
        if _target_visible:
            _last_seen_position = _player.global_position
            _memory_left = memory_seconds

func _candidate_targets() -> Array[Node3D]:
    var result: Array[Node3D] = []
    for node in get_tree().get_nodes_in_group("player"):
        if node is Node3D and is_instance_valid(node):
            result.append(node as Node3D)

    var network := get_node_or_null("/root/NetworkManager")
    if network != null and network.has_method("is_host") and bool(network.call("is_host")):
        for node in get_tree().get_nodes_in_group("remote_player_avatar"):
            if node is Node3D and is_instance_valid(node) and not result.has(node):
                result.append(node as Node3D)
    return result

func _peer_id_for_target(target: Node3D) -> int:
    if target == null:
        return 0
    if _object_has_property(target, "peer_id"):
        return int(target.get("peer_id"))
    var network := get_node_or_null("/root/NetworkManager")
    if network != null and network.has_method("is_multiplayer_active") and bool(network.call("is_multiplayer_active")):
        return multiplayer.get_unique_id()
    return 0

func _default_attacker_peer() -> int:
    var network := get_node_or_null("/root/NetworkManager")
    if network != null and network.has_method("is_multiplayer_active") and bool(network.call("is_multiplayer_active")):
        return multiplayer.get_unique_id()
    return 0

func _decay_threat(delta: float) -> void:
    var to_remove: Array = []
    for raw_peer in _threat_by_peer.keys():
        var peer := int(raw_peer)
        var value := maxf(0.0, float(_threat_by_peer[raw_peer]) - delta * 2.6)
        if value <= 0.01:
            to_remove.append(raw_peer)
        else:
            _threat_by_peer[peer] = value
    for key in to_remove:
        _threat_by_peer.erase(key)

func _can_see_target(target: Node3D, use_fov: bool = true) -> bool:
    if target == null or not is_instance_valid(target) or get_world_3d() == null:
        return false
    var to_target := target.global_position - global_position
    var flat := Vector3(to_target.x, 0.0, to_target.z)
    var distance := flat.length()
    if distance > detection_radius * 1.48:
        return false

    if use_fov and distance > 4.5 and flat.length_squared() > 0.001:
        var forward := -global_transform.basis.z
        forward.y = 0.0
        forward = forward.normalized()
        var threshold := cos(deg_to_rad(field_of_view_degrees * 0.5))
        if forward.dot(flat.normalized()) < threshold:
            return false

    var eye_height := 2.25 if boss else 1.42
    var from := global_position + Vector3.UP * eye_height
    var to := target.global_position + Vector3.UP * 0.95
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    query.collide_with_areas = false
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return true
    return _collider_belongs_to_target(hit.get("collider"), target)

func _collider_belongs_to_target(collider: Variant, target: Node3D) -> bool:
    if collider == null or target == null:
        return false
    if collider == target:
        return true
    if collider is Node:
        var node := collider as Node
        return target.is_ancestor_of(node) or node.is_ancestor_of(target)
    return false

func _ensure_navigation_agent() -> void:
    if _navigation_agent != null and is_instance_valid(_navigation_agent):
        return
    _navigation_agent = NavigationAgent3D.new()
    _navigation_agent.name = "NavigationAgentV116"
    add_child(_navigation_agent)
    _refresh_navigation_settings()

func _refresh_navigation_settings() -> void:
    if _navigation_agent == null or not is_instance_valid(_navigation_agent):
        return
    _navigation_agent.radius = 0.72 if boss else 0.42
    _navigation_agent.path_desired_distance = 0.75 if boss else 0.55
    _navigation_agent.target_desired_distance = maxf(0.8, attack_radius * 0.78)
    _navigation_agent.path_max_distance = 3.5
    _navigation_agent.max_speed = maxf(1.0, move_speed * 1.45)
    _navigation_agent.simplify_path = true
    _navigation_agent.simplify_epsilon = 0.45

func _navigation_available() -> bool:
    if _navigation_agent == null or not is_instance_valid(_navigation_agent):
        return false
    var navigation_map := _navigation_agent.get_navigation_map()
    if not navigation_map.is_valid():
        return false
    return NavigationServer3D.map_get_iteration_id(navigation_map) > 0

func _navigation_or_direct_direction(world_target: Vector3, fallback: Vector3) -> Vector3:
    if not _navigation_available():
        return fallback.normalized() if fallback.length_squared() > 0.001 else Vector3.ZERO

    if _navigation_target == Vector3.INF or _navigation_target.distance_to(world_target) > 1.35:
        _navigation_target = world_target
        _navigation_agent.target_position = world_target

    if _navigation_agent.is_navigation_finished():
        return fallback.normalized() if fallback.length_squared() > 0.001 else Vector3.ZERO

    var next_position := _navigation_agent.get_next_path_position()
    var path_direction := next_position - global_position
    path_direction.y = 0.0
    if path_direction.length_squared() <= 0.01:
        return fallback.normalized() if fallback.length_squared() > 0.001 else Vector3.ZERO
    return path_direction.normalized()

func _apply_obstacle_steering(direction: Vector3) -> Vector3:
    if direction.length_squared() <= 0.001 or get_world_3d() == null:
        return direction
    var forward := direction.normalized()
    if not _probe_blocked(forward):
        return forward

    var left := forward.rotated(Vector3.UP, 0.78)
    var right := forward.rotated(Vector3.UP, -0.78)
    var left_blocked := _probe_blocked(left)
    var right_blocked := _probe_blocked(right)

    if not left_blocked and right_blocked:
        _strafe_sign = -1.0
        return left
    if not right_blocked and left_blocked:
        _strafe_sign = 1.0
        return right
    if not left_blocked and not right_blocked:
        return right if _strafe_sign > 0.0 else left

    _strafe_sign *= -1.0
    return (forward * -0.30 + forward.cross(Vector3.UP) * _strafe_sign).normalized()

func _probe_blocked(direction: Vector3) -> bool:
    var start := global_position + Vector3.UP * (1.2 if boss else 0.85)
    var finish := start + direction.normalized() * (obstacle_probe_distance + (1.0 if boss else 0.0))
    var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
    query.collide_with_areas = false
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return false
    if _player != null and is_instance_valid(_player) and _collider_belongs_to_target(hit.get("collider"), _player):
        return false
    return true

func _apply_squad_separation(direction: Vector3) -> Vector3:
    if direction.length_squared() <= 0.001:
        return direction
    var separation := Vector3.ZERO
    var range_limit := 5.2 if boss else 3.8
    for raw in get_tree().get_nodes_in_group("enemy"):
        if raw == self or not (raw is Node3D) or not is_instance_valid(raw):
            continue
        var other := raw as Node3D
        var away := global_position - other.global_position
        away.y = 0.0
        var distance := away.length()
        if distance <= 0.001 or distance >= range_limit:
            continue
        separation += away.normalized() * (1.0 - distance / range_limit)
    if separation.length_squared() <= 0.001:
        return direction.normalized()
    return (direction.normalized() + separation * 0.68).normalized()

func _update_stuck_state(delta: float) -> void:
    var moved := Vector2(global_position.x - _last_motion_position.x, global_position.z - _last_motion_position.z).length()
    var horizontal_speed := Vector2(velocity.x, velocity.z).length()
    if horizontal_speed > 0.75 and moved < 0.018:
        _stuck_time += delta
    else:
        _stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
    if _stuck_time >= 0.70:
        _stuck_time = 0.0
        _stuck_detour_time = 0.95
        _strafe_sign *= -1.0
        if _player != null and is_instance_valid(_player):
            _navigation_target = Vector3.INF
    _last_motion_position = global_position

func _object_has_property(object: Object, property_name: String) -> bool:
    if object == null:
        return false
    for entry in object.get_property_list():
        if str(entry.get("name", "")) == property_name:
            return true
    return false

func _load_visual() -> void:
    if _visual != null and is_instance_valid(_visual):
        _visual.queue_free()
    _visual = null
    if model_path != "" and ResourceLoader.exists(model_path):
        var resource: Resource = load(model_path)
        if resource is PackedScene:
            var instance: Node = (resource as PackedScene).instantiate()
            if instance is Node3D:
                var candidate := instance as Node3D
                add_child(candidate)
                var meshes: Array[MeshInstance3D] = []
                _collect_meshes(candidate, meshes)
                if not meshes.is_empty():
                    _visual = candidate
                    _normalize_model(_visual, 3.4 if boss else 1.9)
                    return
                candidate.queue_free()
            else:
                instance.queue_free()
    _fallback_visual()

func _normalize_model(root: Node3D, target_height: float) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return
    var min_corner := Vector3(INF, INF, INF)
    var max_corner := Vector3(-INF, -INF, -INF)
    var inverse := root.global_transform.affine_inverse()
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var box := mesh_instance.get_aabb()
        var xf := inverse * mesh_instance.global_transform
        for i in range(8):
            var p: Vector3 = xf * box.get_endpoint(i)
            min_corner = Vector3(minf(min_corner.x, p.x), minf(min_corner.y, p.y), minf(min_corner.z, p.z))
            max_corner = Vector3(maxf(max_corner.x, p.x), maxf(max_corner.y, p.y), maxf(max_corner.z, p.z))
    var height := max_corner.y - min_corner.y
    if height <= 0.01:
        return
    var factor := clampf(target_height / height, 0.015, 40.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= min_corner.y * factor

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _fallback_visual() -> void:
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.55 if boss else 0.34
    mesh.height = 2.8 if boss else 1.7
    body.mesh = mesh
    body.position.y = mesh.height * 0.55
    var material := StandardMaterial3D.new()
    var fallback_colors := [Color("5f4036"), Color("4c5966"), Color("78513a"), Color("4d567c")]
    material.albedo_color = Color("9b302d") if boss else fallback_colors[variant_index % fallback_colors.size()]
    body.material_override = material
    add_child(body)
    _visual = body

func _ensure_objective_marker() -> void:
    if _objective_marker != null and is_instance_valid(_objective_marker):
        return
    _objective_marker = Node3D.new()
    _objective_marker.name = "ObjectiveMarker"
    _marker_base_y = 4.4 if boss else 2.75
    _objective_marker.position.y = _marker_base_y
    add_child(_objective_marker)

    var marker_color := Color("ffb347") if boss else Color("ff5c4d")

    var core := MeshInstance3D.new()
    core.name = "MarkerCore"
    var sphere := SphereMesh.new()
    sphere.radius = 0.30 if boss else 0.22
    sphere.height = sphere.radius * 2.0
    sphere.radial_segments = 10
    sphere.rings = 6
    core.mesh = sphere
    core.material_override = _marker_material(marker_color)
    _objective_marker.add_child(core)

    var ring := MeshInstance3D.new()
    ring.name = "MarkerRing"
    var torus := TorusMesh.new()
    torus.inner_radius = 0.46 if boss else 0.34
    torus.outer_radius = 0.58 if boss else 0.44
    torus.rings = 14
    torus.ring_segments = 6
    ring.mesh = torus
    ring.material_override = _marker_material(marker_color)
    _objective_marker.add_child(ring)

    var nameplate := Label3D.new()
    nameplate.name = "EnemyNameplate"
    nameplate.text = _nameplate_text()
    nameplate.position = Vector3(0.0, 0.72, 0.0)
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.no_depth_test = true
    nameplate.font_size = 32 if boss else 24
    nameplate.outline_size = 8
    nameplate.modulate = marker_color
    nameplate.outline_modulate = Color(0.0, 0.0, 0.0, 0.92)
    _objective_marker.add_child(nameplate)

func _nameplate_text() -> String:
    var prefix := "GRAND BOSS" if boss else ("COMMANDANT 1" if display_name.to_lower().contains("commandant 1") else ("COMMANDANT 2" if display_name.to_lower().contains("commandant 2") else _archetype_label()))
    var phase := " • PHASE 2" if _phase_two else ""
    return "%s%s\n%s" % [prefix, phase, display_name.to_upper()]

func _archetype_label() -> String:
    match archetype:
        "guard":
            return "GARDE"
        "charger":
            return "CHARGEUR"
        "ranged":
            return "TIREUR"
        "duelist":
            return "DUELLISTE"
        _:
            return "ENNEMI"

func _refresh_nameplate() -> void:
    if _objective_marker == null or not is_instance_valid(_objective_marker):
        return
    var nameplate := _objective_marker.get_node_or_null("EnemyNameplate") as Label3D
    if nameplate != null:
        nameplate.text = _nameplate_text()

func _set_telegraph(active: bool) -> void:
    if _objective_marker == null or not is_instance_valid(_objective_marker):
        return
    var nameplate := _objective_marker.get_node_or_null("EnemyNameplate") as Label3D
    if nameplate != null:
        nameplate.modulate = Color("fff176") if active else (Color("ffb347") if boss else Color("ff5c4d"))
    _objective_marker.scale = Vector3.ONE * (1.22 if active else 1.0)

func _marker_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.6
    return material
