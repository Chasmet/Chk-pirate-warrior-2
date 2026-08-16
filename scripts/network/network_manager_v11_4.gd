class_name NetworkManagerV11_4
extends "res://scripts/network/network_manager_v11_2.gd"

signal vehicle_seats_changed(vehicle_id: String, seats: Array)

const REMOTE_AVATAR_V114_SCRIPT := preload("res://scripts/network/remote_player_avatar_v11_4.gd")

var _vehicle_seats: Dictionary = {}
var _coop_session_uid := ""

func _ready() -> void:
    super._ready()
    if not host_migration_completed.is_connected(_on_v114_host_migration_completed):
        host_migration_completed.connect(_on_v114_host_migration_completed)

func create_host(player_name: String, hero_id: String) -> Error:
    var err := super.create_host(player_name, hero_id)
    if err != OK:
        return err
    _coop_session_uid = _new_session_uid()
    _vehicle_seats.clear()
    _player_infos[1] = _build_player_info(_local_name, _local_hero, _local_profile_id())
    _broadcast_lobby()
    _apply_vehicle_seats()
    return OK

func join_host(address: String, player_name: String, hero_id: String) -> Error:
    _vehicle_seats.clear()
    _coop_session_uid = ""
    return super.join_host(address, player_name, hero_id)

func disconnect_session(reason: String = "Partie quittée") -> void:
    _vehicle_seats.clear()
    _apply_vehicle_seats()
    _coop_session_uid = ""
    super.disconnect_session(reason)

func coop_session_id() -> String:
    return _coop_session_uid

func vehicle_seats_snapshot() -> Dictionary:
    return _vehicle_seats.duplicate(true)

func request_vehicle_interaction(vehicle_id: String) -> bool:
    var resolved := vehicle_id.strip_edges()
    if resolved.is_empty() or not is_multiplayer_active():
        return false
    if is_host():
        return _host_toggle_vehicle_seat(1, resolved)
    if is_client():
        rpc_id(1, "_request_vehicle_seat_v11_4", resolved)
        return true
    return false

func _on_connected_to_server() -> void:
    if not is_client():
        return
    rpc_id(1, "_register_player_v11_4", _local_name, _local_hero, _local_profile_id())
    connection_status_changed.emit("Connecté • identité coop + progression en synchronisation…")

@rpc("any_peer", "call_remote", "reliable")
func _register_player_v11_4(player_name: String, hero_id: String, profile_id: String) -> void:
    if not is_host():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id <= 1:
        return

    var resolved_profile := _sanitize_profile_id(profile_id, sender_id)
    _remove_duplicate_profile(sender_id, resolved_profile)
    _player_infos[sender_id] = _build_player_info(player_name, hero_id, resolved_profile)
    _broadcast_lobby()
    _ensure_remote_avatars()

    if _host_game_active:
        rpc_id(
            sender_id,
            "_accept_join",
            _player_infos,
            GameState.multiplayer_snapshot(),
            AudioDirector.multiplayer_music_snapshot()
        )
        _broadcast_vehicle_seats()

    connection_status_changed.emit(
        "%s a rejoint • identité %s • %d/%d" % [
            str(_player_infos[sender_id].get("name", "Joueur")),
            resolved_profile.right(8),
            _player_infos.size(),
            MAX_PLAYERS
        ]
    )

@rpc("authority", "call_remote", "reliable")
func _accept_join(players: Dictionary, campaign: Dictionary, music_state: Dictionary) -> void:
    super._accept_join(players, campaign, music_state)
    _adopt_session_uid(players)

@rpc("authority", "call_remote", "reliable")
func _receive_lobby(players: Dictionary) -> void:
    super._receive_lobby(players)
    _adopt_session_uid(players)

func _on_local_hero_changed(hero_id: String) -> void:
    var resolved := _sanitize_hero(hero_id)
    _local_hero = resolved
    if is_host():
        var info: Dictionary = _player_infos.get(1, _build_player_info(_local_name, resolved, _local_profile_id()))
        info["hero"] = resolved
        info["identity_color"] = _identity_color_hex(resolved)
        info["profile_id"] = str(info.get("profile_id", _local_profile_id()))
        info["session_id"] = _coop_session_uid
        _player_infos[1] = info
        _broadcast_lobby()
        _ensure_remote_avatars()
    elif is_client():
        var local_peer_id := multiplayer.get_unique_id()
        if _player_infos.has(local_peer_id):
            var local_info: Dictionary = _player_infos[local_peer_id]
            local_info["hero"] = resolved
            local_info["identity_color"] = _identity_color_hex(resolved)
            _player_infos[local_peer_id] = local_info
            lobby_changed.emit(_player_infos.duplicate(true))
        rpc_id(1, "_request_hero_change_v11_4", resolved, _local_profile_id())

@rpc("any_peer", "call_remote", "reliable")
func _request_hero_change_v11_4(hero_id: String, profile_id: String) -> void:
    if not is_host():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id <= 1 or not _player_infos.has(sender_id):
        return
    var info: Dictionary = _player_infos[sender_id]
    var known_profile := str(info.get("profile_id", ""))
    if not known_profile.is_empty() and known_profile != _sanitize_profile_id(profile_id, sender_id):
        return
    var resolved := _sanitize_hero(hero_id)
    info["hero"] = resolved
    info["identity_color"] = _identity_color_hex(resolved)
    _player_infos[sender_id] = info
    _broadcast_lobby()
    _ensure_remote_avatars()

func _ensure_remote_avatars() -> void:
    if _mode == Mode.SOLO:
        return
    var local_peer_id := multiplayer.get_unique_id()
    for raw_id in _player_infos.keys():
        var peer_id := int(raw_id)
        if peer_id == local_peer_id:
            continue
        var info: Dictionary = _player_infos[raw_id]
        if _remote_avatars.has(peer_id) and is_instance_valid(_remote_avatars[peer_id]):
            _remote_avatars[peer_id].update_identity(
                str(info.get("hero", "cheikh")),
                str(info.get("name", "Joueur"))
            )
            continue
        var avatar = REMOTE_AVATAR_V114_SCRIPT.new()
        avatar.setup(peer_id, str(info.get("hero", "cheikh")), str(info.get("name", "Joueur")))
        var scene := get_tree().current_scene
        if scene != null:
            scene.add_child(avatar)
            _remote_avatars[peer_id] = avatar

func _local_motion_snapshot() -> Dictionary:
    var snapshot := super._local_motion_snapshot()
    if snapshot.is_empty():
        return snapshot
    var local_peer_id := multiplayer.get_unique_id() if is_multiplayer_active() else 1
    var seat := _peer_vehicle_seat(local_peer_id)
    if seat.is_empty():
        snapshot["vehicle_id"] = ""
        snapshot["seat_index"] = -1
        snapshot["vehicle_style"] = ""
        return snapshot

    var vehicle_id := str(seat.get("vehicle_id", ""))
    var seat_index := int(seat.get("seat_index", -1))
    var vehicle := _find_coop_vehicle(vehicle_id)
    var style := str(vehicle.get("style_key")) if vehicle != null and _object_has_property(vehicle, "style_key") else ""
    snapshot["vehicle_id"] = vehicle_id
    snapshot["seat_index"] = seat_index
    snapshot["vehicle_style"] = style
    if seat_index > 0:
        snapshot["mount"] = ""
    return snapshot

func _sanitize_motion_snapshot(value: Dictionary) -> Dictionary:
    var snapshot := super._sanitize_motion_snapshot(value)
    var vehicle_id := str(value.get("vehicle_id", "")).strip_edges()
    var seat_index := int(value.get("seat_index", -1))
    var vehicle_style := str(value.get("vehicle_style", ""))
    if not _vehicle_seats.has(vehicle_id):
        vehicle_id = ""
        seat_index = -1
        vehicle_style = ""
    snapshot["vehicle_id"] = vehicle_id
    snapshot["seat_index"] = clampi(seat_index, -1, 2)
    snapshot["vehicle_style"] = vehicle_style
    return snapshot

func _apply_remote_snapshots(snapshot: Dictionary) -> void:
    super._apply_remote_snapshots(snapshot)
    var local_peer_id := multiplayer.get_unique_id()
    for raw_id in snapshot.keys():
        var peer_id := int(raw_id)
        if peer_id == local_peer_id:
            continue
        var state_value = snapshot[raw_id]
        if not state_value is Dictionary:
            continue
        var state: Dictionary = state_value
        var vehicle_id := str(state.get("vehicle_id", ""))
        var seat_index := int(state.get("seat_index", -1))
        var style := str(state.get("vehicle_style", ""))

        if _remote_avatars.has(peer_id) and is_instance_valid(_remote_avatars[peer_id]):
            var avatar = _remote_avatars[peer_id]
            if avatar.has_method("set_shared_vehicle_state"):
                avatar.call("set_shared_vehicle_state", style, seat_index)

        if vehicle_id.is_empty() or seat_index != 0:
            continue
        var position = state.get("position", Vector3.ZERO)
        var velocity = state.get("velocity", Vector3.ZERO)
        if not position is Vector3:
            continue
        if not velocity is Vector3:
            velocity = Vector3.ZERO
        get_tree().call_group(
            "coop_vehicle",
            "apply_network_driver_snapshot",
            vehicle_id,
            peer_id,
            position,
            float(state.get("yaw", 0.0)),
            velocity
        )

func _on_peer_disconnected(peer_id: int) -> void:
    if is_host():
        _remove_peer_from_vehicle_seats(peer_id, false)
    super._on_peer_disconnected(peer_id)
    if is_host():
        _broadcast_vehicle_seats()

func _on_server_disconnected() -> void:
    var previous_session := _coop_session_uid
    _vehicle_seats.clear()
    _apply_vehicle_seats()
    super._on_server_disconnected()
    if _coop_session_uid.is_empty():
        _coop_session_uid = previous_session

func _on_v114_host_migration_completed(_new_host_name: String) -> void:
    if _coop_session_uid.is_empty():
        _coop_session_uid = _new_session_uid()
    _vehicle_seats.clear()
    _player_infos[1] = _build_player_info(_local_name, _local_hero, _local_profile_id())
    _broadcast_lobby()
    _broadcast_vehicle_seats()

@rpc("any_peer", "call_remote", "reliable")
func _request_vehicle_seat_v11_4(vehicle_id: String) -> void:
    if not is_host():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id <= 1 or not _player_infos.has(sender_id):
        return
    _host_toggle_vehicle_seat(sender_id, vehicle_id.strip_edges())

@rpc("authority", "call_remote", "reliable")
func _receive_vehicle_seats_v11_4(seats: Dictionary) -> void:
    if not is_client():
        return
    _vehicle_seats = seats.duplicate(true)
    _apply_vehicle_seats()

@rpc("authority", "call_remote", "reliable")
func _vehicle_interaction_result_v11_4(ok: bool, text: String) -> void:
    if not is_client():
        return
    connection_status_changed.emit(text)
    get_tree().call_group("gameplay_ux", "show_network_notice", text.to_upper())

func _host_toggle_vehicle_seat(peer_id: int, vehicle_id: String) -> bool:
    if vehicle_id.is_empty() or not _player_infos.has(peer_id):
        return false

    var existing := _peer_vehicle_seat(peer_id)
    if not existing.is_empty() and str(existing.get("vehicle_id", "")) == vehicle_id:
        _remove_peer_from_vehicle_seats(peer_id, true)
        _send_vehicle_result(peer_id, true, "DESCENTE DU VÉHICULE")
        return true

    var vehicle := _find_coop_vehicle(vehicle_id)
    if vehicle == null:
        _send_vehicle_result(peer_id, false, "VÉHICULE INTROUVABLE")
        return false
    if not _peer_is_close_to_vehicle(peer_id, vehicle):
        _send_vehicle_result(peer_id, false, "APPROCHE-TOI DU VÉHICULE")
        return false

    _remove_peer_from_vehicle_seats(peer_id, false)
    var capacity := 1
    if vehicle.has_method("coop_seat_capacity"):
        capacity = clampi(int(vehicle.call("coop_seat_capacity")), 1, 3)
    var seats := _normalized_seats(_vehicle_seats.get(vehicle_id, []), capacity)
    var seat_index := seats.find(0)
    if seat_index < 0:
        _send_vehicle_result(peer_id, false, "VÉHICULE COMPLET")
        _broadcast_vehicle_seats()
        return false

    seats[seat_index] = peer_id
    _vehicle_seats[vehicle_id] = seats
    _broadcast_vehicle_seats()
    var role := "CONDUCTEUR" if seat_index == 0 else "PASSAGER %d" % seat_index
    _send_vehicle_result(peer_id, true, "%s • %s" % [str(vehicle.get("vehicle_name")).to_upper(), role])
    return true

func _remove_peer_from_vehicle_seats(peer_id: int, broadcast_now: bool) -> void:
    var changed := false
    for vehicle_id in _vehicle_seats.keys():
        var raw = _vehicle_seats[vehicle_id]
        if not raw is Array:
            continue
        var seats: Array = raw.duplicate()
        var index := seats.find(peer_id)
        if index < 0:
            continue
        seats[index] = 0
        if index == 0:
            for passenger_index in range(1, seats.size()):
                if int(seats[passenger_index]) > 0:
                    seats[0] = int(seats[passenger_index])
                    seats[passenger_index] = 0
                    break
        var occupied := false
        for value in seats:
            if int(value) > 0:
                occupied = true
                break
        if occupied:
            _vehicle_seats[vehicle_id] = seats
        else:
            _vehicle_seats.erase(vehicle_id)
        changed = true
        break
    if changed and broadcast_now:
        _broadcast_vehicle_seats()

func _broadcast_vehicle_seats() -> void:
    if not is_host():
        return
    var snapshot := _vehicle_seats.duplicate(true)
    _apply_vehicle_seats()
    rpc("_receive_vehicle_seats_v11_4", snapshot)

func _apply_vehicle_seats() -> void:
    for vehicle in get_tree().get_nodes_in_group("coop_vehicle"):
        if vehicle == null or not is_instance_valid(vehicle):
            continue
        if not _object_has_property(vehicle, "network_vehicle_id"):
            continue
        var vehicle_id := str(vehicle.get("network_vehicle_id"))
        var raw = _vehicle_seats.get(vehicle_id, [])
        var seats: Array = raw.duplicate() if raw is Array else []
        if vehicle.has_method("apply_network_seats"):
            vehicle.call("apply_network_seats", vehicle_id, seats)
        vehicle_seats_changed.emit(vehicle_id, seats)

func _peer_vehicle_seat(peer_id: int) -> Dictionary:
    for vehicle_id in _vehicle_seats.keys():
        var raw = _vehicle_seats[vehicle_id]
        if not raw is Array:
            continue
        var seats: Array = raw
        var seat_index := seats.find(peer_id)
        if seat_index >= 0:
            return {"vehicle_id": str(vehicle_id), "seat_index": seat_index}
    return {}

func _find_coop_vehicle(vehicle_id: String) -> Node:
    for vehicle in get_tree().get_nodes_in_group("coop_vehicle"):
        if vehicle == null or not is_instance_valid(vehicle):
            continue
        if not _object_has_property(vehicle, "network_vehicle_id"):
            continue
        if str(vehicle.get("network_vehicle_id")) == vehicle_id:
            return vehicle
    return null

func _peer_is_close_to_vehicle(peer_id: int, vehicle: Node) -> bool:
    if not vehicle is Node3D:
        return false
    var origin := Vector3.INF
    if peer_id == 1:
        var local_player := get_tree().get_first_node_in_group("player") as Node3D
        if local_player != null:
            origin = local_player.global_position
    else:
        var motion: Dictionary = _peer_snapshots.get(peer_id, {})
        var value = motion.get("position", Vector3.INF)
        if value is Vector3:
            origin = value
    if origin == Vector3.INF:
        return false
    var radius := 6.5
    if _object_has_property(vehicle, "interaction_radius"):
        radius = float(vehicle.get("interaction_radius"))
    return origin.distance_to((vehicle as Node3D).global_position) <= radius + 1.25

func _normalized_seats(raw: Variant, capacity: int) -> Array:
    var seats: Array = []
    if raw is Array:
        seats = (raw as Array).duplicate()
    while seats.size() < capacity:
        seats.append(0)
    if seats.size() > capacity:
        seats.resize(capacity)
    for i in range(seats.size()):
        seats[i] = maxi(0, int(seats[i]))
    return seats

func _send_vehicle_result(peer_id: int, ok: bool, text: String) -> void:
    if peer_id == 1:
        connection_status_changed.emit(text)
        get_tree().call_group("gameplay_ux", "show_network_notice", text.to_upper())
    else:
        rpc_id(peer_id, "_vehicle_interaction_result_v11_4", ok, text)

func _remove_duplicate_profile(sender_id: int, profile_id: String) -> void:
    for raw_id in _player_infos.keys().duplicate():
        var peer_id := int(raw_id)
        if peer_id == sender_id:
            continue
        var info_value = _player_infos.get(raw_id, {})
        if not info_value is Dictionary:
            continue
        if str((info_value as Dictionary).get("profile_id", "")) != profile_id:
            continue
        _remove_peer_from_vehicle_seats(peer_id, false)
        _remove_remote_avatar(peer_id)
        _player_infos.erase(raw_id)
        _peer_snapshots.erase(raw_id)

func _build_player_info(player_name: String, hero_id: String, profile_id: String) -> Dictionary:
    var resolved_hero := _sanitize_hero(hero_id)
    return {
        "name": _sanitize_name(player_name),
        "hero": resolved_hero,
        "profile_id": profile_id,
        "identity_color": _identity_color_hex(resolved_hero),
        "session_id": _coop_session_uid
    }

func _local_profile_id() -> String:
    if GameState.has_method("profile_id"):
        return str(GameState.call("profile_id"))
    return "local-%d" % int(Time.get_unix_time_from_system())

func _sanitize_profile_id(value: String, peer_id: int) -> String:
    var resolved := value.strip_edges().left(80)
    if resolved.is_empty():
        resolved = "peer-%d-%d" % [peer_id, int(Time.get_unix_time_from_system())]
    return resolved

func _identity_color_hex(hero_id: String) -> String:
    if GameState.has_method("hero_identity_color_hex"):
        return str(GameState.call("hero_identity_color_hex", hero_id))
    match hero_id.to_lower():
        "cheikh": return "22c55e"
        "yvane": return "ef4444"
        "nelvyn": return "facc15"
        _: return "ffffff"

func _new_session_uid() -> String:
    return "%s-%d" % [_local_profile_id(), int(Time.get_unix_time_from_system())]

func _adopt_session_uid(players: Dictionary) -> void:
    var host_info = players.get(1, {})
    if host_info is Dictionary:
        var value := str((host_info as Dictionary).get("session_id", ""))
        if not value.is_empty():
            _coop_session_uid = value
