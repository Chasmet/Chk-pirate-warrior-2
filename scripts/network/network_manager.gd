extends Node

enum Mode { SOLO, HOST, CLIENT }

signal session_discovered(info: Dictionary)
signal lobby_changed(players: Dictionary)
signal connection_status_changed(text: String)
signal joined_session()
signal game_start_received()
signal session_closed(reason: String)

const GAME_PORT := 24567
const DISCOVERY_PORT := 24568
const MAX_PLAYERS := 3
const PROTOCOL_VERSION := 2
const MOTION_INTERVAL_SECONDS := 0.05
const MUSIC_SYNC_INTERVAL_SECONDS := 3.0
const REMOTE_AVATAR_SCRIPT := preload("res://scripts/network/remote_player_avatar.gd")

var _mode: Mode = Mode.SOLO
var _local_name := "Joueur"
var _local_hero := "cheikh"
var _player_infos: Dictionary = {}
var _peer_snapshots: Dictionary = {}
var _remote_avatars: Dictionary = {}
var _advertiser: PacketPeerUDP
var _scanner: PacketPeerUDP
var _advertise_accumulator := 0.0
var _motion_accumulator := 0.0
var _campaign_accumulator := 0.0
var _music_sync_accumulator := 0.0
var _campaign_dirty := false
var _host_game_active := false
var _hero_catalog: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _hero_catalog = _load_json("res://data/heroes.json")
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    if not GameState.progression_changed.is_connected(_on_campaign_changed):
        GameState.progression_changed.connect(_on_campaign_changed)
    if not GameState.island_changed.is_connected(_on_island_changed):
        GameState.island_changed.connect(_on_island_changed)
    if not GameState.hero_changed.is_connected(_on_local_hero_changed):
        GameState.hero_changed.connect(_on_local_hero_changed)

func _process(delta: float) -> void:
    _poll_discovery(delta)
    if _mode == Mode.SOLO:
        return
    _motion_accumulator += delta
    if _motion_accumulator >= MOTION_INTERVAL_SECONDS:
        _motion_accumulator = 0.0
        _send_motion_snapshot()
    if _mode == Mode.HOST:
        _campaign_accumulator += delta
        if _campaign_dirty and _campaign_accumulator >= 0.25:
            _campaign_accumulator = 0.0
            _campaign_dirty = false
            rpc("_receive_campaign_snapshot", GameState.multiplayer_snapshot())
        elif _campaign_accumulator >= 1.5:
            _campaign_accumulator = 0.0
            rpc("_receive_campaign_snapshot", GameState.multiplayer_snapshot())
        _music_sync_accumulator += delta
        if _music_sync_accumulator >= MUSIC_SYNC_INTERVAL_SECONDS:
            _music_sync_accumulator = 0.0
            rpc("_receive_music_sync", AudioDirector.multiplayer_music_snapshot())

func mode_name() -> String:
    match _mode:
        Mode.HOST: return "host"
        Mode.CLIENT: return "client"
        _: return "solo"

func is_multiplayer_active() -> bool:
    return _mode != Mode.SOLO

func is_host() -> bool:
    return _mode == Mode.HOST

func is_client() -> bool:
    return _mode == Mode.CLIENT

func can_write_campaign_save() -> bool:
    return _mode != Mode.CLIENT

func player_count() -> int:
    return _player_infos.size()

func players_snapshot() -> Dictionary:
    return _player_infos.duplicate(true)

func start_discovery_scan() -> Error:
    stop_discovery_scan()
    _scanner = PacketPeerUDP.new()
    _scanner.set_broadcast_enabled(true)
    var err := _scanner.bind(DISCOVERY_PORT, "0.0.0.0")
    if err != OK:
        _scanner = null
        connection_status_changed.emit("Impossible d'écouter les parties Wi-Fi.")
        return err
    connection_status_changed.emit("Recherche des parties sur le Wi-Fi…")
    return OK

func stop_discovery_scan() -> void:
    if _scanner != null:
        _scanner.close()
    _scanner = null

func create_host(player_name: String, hero_id: String) -> Error:
    disconnect_session("")
    _local_name = _sanitize_name(player_name)
    _local_hero = _sanitize_hero(hero_id)
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
    if err != OK:
        connection_status_changed.emit("Impossible de créer la partie locale.")
        return err
    multiplayer.multiplayer_peer = peer
    _mode = Mode.HOST
    _player_infos = {
        1: {"name": _local_name, "hero": _local_hero}
    }
    _peer_snapshots.clear()
    _music_sync_accumulator = 0.0
    _host_game_active = true
    _start_advertising()
    lobby_changed.emit(_player_infos.duplicate(true))
    connection_status_changed.emit("Partie Wi-Fi créée • %d/%d joueurs" % [_player_infos.size(), MAX_PLAYERS])
    return OK

func join_host(address: String, player_name: String, hero_id: String) -> Error:
    var resolved := address.strip_edges()
    if resolved.is_empty():
        return ERR_INVALID_PARAMETER
    disconnect_session("")
    _local_name = _sanitize_name(player_name)
    _local_hero = _sanitize_hero(hero_id)
    stop_discovery_scan()
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(resolved, GAME_PORT)
    if err != OK:
        connection_status_changed.emit("Connexion impossible à %s." % resolved)
        return err
    multiplayer.multiplayer_peer = peer
    _mode = Mode.CLIENT
    _player_infos.clear()
    _peer_snapshots.clear()
    _music_sync_accumulator = 0.0
    connection_status_changed.emit("Connexion à la partie…")
    return OK

func disconnect_session(reason: String = "Partie quittée") -> void:
    stop_discovery_scan()
    _stop_advertising()
    _clear_remote_avatars()
    _peer_snapshots.clear()
    _music_sync_accumulator = 0.0
    _player_infos.clear()
    _host_game_active = false
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    var had_session := _mode != Mode.SOLO
    _mode = Mode.SOLO
    if had_session and not reason.is_empty():
        session_closed.emit(reason)
        connection_status_changed.emit(reason)

func request_combat(action: String, ability_index: int = -1) -> void:
    if _mode != Mode.CLIENT:
        return
    rpc_id(1, "_request_combat", action, ability_index)

func host_broadcast_combat(action: String, ability_index: int, origin: Vector3) -> void:
    if _mode != Mode.HOST:
        return
    var values := _combat_values(_local_hero, action, ability_index)
    if values.is_empty():
        return
    rpc("_apply_area_damage", 1, origin, float(values["radius"]), float(values["damage"]), action)

func host_broadcast_music_now() -> void:
    if _mode != Mode.HOST:
        return
    _music_sync_accumulator = 0.0
    rpc("_receive_music_sync", AudioDirector.multiplayer_music_snapshot())

func _start_advertising() -> void:
    _stop_advertising()
    _advertiser = PacketPeerUDP.new()
    _advertiser.set_broadcast_enabled(true)
    _advertiser.bind(0, "0.0.0.0")
    _advertise_accumulator = 10.0

func _stop_advertising() -> void:
    if _advertiser != null:
        _advertiser.close()
    _advertiser = null

func _poll_discovery(delta: float) -> void:
    if _advertiser != null and _mode == Mode.HOST:
        _advertise_accumulator += delta
        if _advertise_accumulator >= 0.75:
            _advertise_accumulator = 0.0
            var payload := {
                "game": "chk_pirate_warrior_2",
                "protocol": PROTOCOL_VERSION,
                "name": "Partie de %s" % _local_name,
                "players": _player_infos.size(),
                "max_players": MAX_PLAYERS,
                "port": GAME_PORT,
                "hero": _local_hero
            }
            _advertiser.set_dest_address("255.255.255.255", DISCOVERY_PORT)
            _advertiser.put_packet(JSON.stringify(payload).to_utf8_buffer())

    if _scanner == null:
        return
    while _scanner.get_available_packet_count() > 0:
        var packet := _scanner.get_packet()
        var source_ip := _scanner.get_packet_ip()
        var parsed = JSON.parse_string(packet.get_string_from_utf8())
        if not parsed is Dictionary:
            continue
        var info: Dictionary = parsed
        if str(info.get("game", "")) != "chk_pirate_warrior_2":
            continue
        if int(info.get("protocol", -1)) != PROTOCOL_VERSION:
            continue
        if int(info.get("players", MAX_PLAYERS)) >= MAX_PLAYERS:
            continue
        info["ip"] = source_ip
        session_discovered.emit(info)

func _on_peer_connected(peer_id: int) -> void:
    if _mode == Mode.HOST:
        connection_status_changed.emit("Téléphone connecté • identification en cours…")

func _on_peer_disconnected(peer_id: int) -> void:
    if _mode != Mode.HOST:
        return
    _player_infos.erase(peer_id)
    _peer_snapshots.erase(peer_id)
    _remove_remote_avatar(peer_id)
    _broadcast_lobby()
    connection_status_changed.emit("Joueur déconnecté • %d/%d" % [_player_infos.size(), MAX_PLAYERS])

func _on_connected_to_server() -> void:
    if _mode != Mode.CLIENT:
        return
    rpc_id(1, "_register_player", _local_name, _local_hero)
    connection_status_changed.emit("Connecté • synchronisation de la partie…")

func _on_connection_failed() -> void:
    disconnect_session("")
    connection_status_changed.emit("Connexion Wi-Fi échouée.")

func _on_server_disconnected() -> void:
    disconnect_session("L'hôte a quitté la partie.")

@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String, hero_id: String) -> void:
    if _mode != Mode.HOST:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id <= 1:
        return
    _player_infos[sender_id] = {
        "name": _sanitize_name(player_name),
        "hero": _sanitize_hero(hero_id)
    }
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
    connection_status_changed.emit("%s a rejoint • %d/%d" % [str(_player_infos[sender_id]["name"]), _player_infos.size(), MAX_PLAYERS])

@rpc("authority", "call_remote", "reliable")
func _accept_join(players: Dictionary, campaign: Dictionary, music_state: Dictionary) -> void:
    if _mode != Mode.CLIENT:
        return
    _player_infos = players.duplicate(true)
    GameState.apply_multiplayer_snapshot(campaign)
    _ensure_remote_avatars()
    lobby_changed.emit(_player_infos.duplicate(true))
    joined_session.emit()
    game_start_received.emit()
    # game_start_received démarre d'abord la scène et ses lecteurs. Le recalage
    # vient juste après pour reprendre la même piste au même instant que l'hôte.
    AudioDirector.synchronize_multiplayer_music(music_state, true)
    connection_status_changed.emit("Partie rejointe • %d/%d joueurs" % [_player_infos.size(), MAX_PLAYERS])

func _broadcast_lobby() -> void:
    if _mode != Mode.HOST:
        return
    lobby_changed.emit(_player_infos.duplicate(true))
    rpc("_receive_lobby", _player_infos)

@rpc("authority", "call_remote", "reliable")
func _receive_lobby(players: Dictionary) -> void:
    if _mode != Mode.CLIENT:
        return
    _player_infos = players.duplicate(true)
    _ensure_remote_avatars()
    lobby_changed.emit(_player_infos.duplicate(true))

func _on_local_hero_changed(hero_id: String) -> void:
    var resolved := _sanitize_hero(hero_id)
    _local_hero = resolved
    if _mode == Mode.HOST:
        _player_infos[1] = {"name": _local_name, "hero": resolved}
        _broadcast_lobby()
        _ensure_remote_avatars()
    elif _mode == Mode.CLIENT:
        var local_peer_id := multiplayer.get_unique_id()
        if _player_infos.has(local_peer_id):
            var local_info: Dictionary = _player_infos[local_peer_id]
            local_info["hero"] = resolved
            _player_infos[local_peer_id] = local_info
            lobby_changed.emit(_player_infos.duplicate(true))
        rpc_id(1, "_request_hero_change", resolved)

@rpc("any_peer", "call_remote", "reliable")
func _request_hero_change(hero_id: String) -> void:
    if _mode != Mode.HOST:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id <= 1 or not _player_infos.has(sender_id):
        return
    var info: Dictionary = _player_infos[sender_id]
    var resolved := _sanitize_hero(hero_id)
    info["hero"] = resolved
    _player_infos[sender_id] = info
    _broadcast_lobby()
    _ensure_remote_avatars()

@rpc("authority", "call_remote", "reliable")
func _receive_music_sync(music_state: Dictionary) -> void:
    if _mode != Mode.CLIENT:
        return
    AudioDirector.synchronize_multiplayer_music(music_state, false)

func _send_motion_snapshot() -> void:
    var local := _local_motion_snapshot()
    if local.is_empty():
        return
    if _mode == Mode.CLIENT:
        rpc_id(1, "_submit_transform", local)
        return
    if _mode != Mode.HOST:
        return
    _peer_snapshots[1] = local
    var snapshot := _peer_snapshots.duplicate(true)
    _apply_remote_snapshots(snapshot)
    rpc("_receive_transform_snapshot", snapshot)

func _local_motion_snapshot() -> Dictionary:
    var hero := get_tree().get_first_node_in_group("player") as Node3D
    if hero == null:
        return {}
    var position := hero.global_position
    var yaw := hero.global_rotation.y
    var speed := 0.0
    var linear_velocity := Vector3.ZERO
    if hero is CharacterBody3D:
        linear_velocity = (hero as CharacterBody3D).velocity
        speed = linear_velocity.length()
    var mount_style := ""
    var controller := get_tree().get_first_node_in_group("active_controller")
    if controller is Node3D and _object_has_property(controller, "style_key"):
        mount_style = str(controller.get("style_key"))
        position = (controller as Node3D).global_position
        yaw = (controller as Node3D).global_rotation.y
        if controller is CharacterBody3D:
            linear_velocity = (controller as CharacterBody3D).velocity
            speed = linear_velocity.length()
    return {
        "position": position,
        "yaw": yaw,
        "speed": speed,
        "velocity": linear_velocity,
        "mount": mount_style
    }

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_transform(snapshot: Dictionary) -> void:
    if _mode != Mode.HOST:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if not _player_infos.has(sender_id):
        return
    _peer_snapshots[sender_id] = _sanitize_motion_snapshot(snapshot)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_transform_snapshot(snapshot: Dictionary) -> void:
    if _mode != Mode.CLIENT:
        return
    _peer_snapshots = snapshot.duplicate(true)
    _apply_remote_snapshots(_peer_snapshots)

func _sanitize_motion_snapshot(value: Dictionary) -> Dictionary:
    var position = value.get("position", Vector3.ZERO)
    if not position is Vector3:
        position = Vector3.ZERO
    var raw_velocity = value.get("velocity", Vector3.ZERO)
    var linear_velocity: Vector3 = raw_velocity if raw_velocity is Vector3 else Vector3.ZERO
    if linear_velocity.length() > 60.0:
        linear_velocity = linear_velocity.normalized() * 60.0
    return {
        "position": position,
        "yaw": float(value.get("yaw", 0.0)),
        "speed": clampf(float(value.get("speed", 0.0)), 0.0, 60.0),
        "velocity": linear_velocity,
        "mount": str(value.get("mount", "")) if str(value.get("mount", "")) in ["4x4", "quad", "horse"] else ""
    }

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
        var avatar = REMOTE_AVATAR_SCRIPT.new()
        avatar.setup(peer_id, str(info.get("hero", "cheikh")), str(info.get("name", "Joueur")))
        var scene := get_tree().current_scene
        if scene != null:
            scene.add_child(avatar)
            _remote_avatars[peer_id] = avatar

func _apply_remote_snapshots(snapshot: Dictionary) -> void:
    _ensure_remote_avatars()
    var local_peer_id := multiplayer.get_unique_id()
    for raw_id in snapshot.keys():
        var peer_id := int(raw_id)
        if peer_id == local_peer_id:
            continue
        if not _remote_avatars.has(peer_id) or not is_instance_valid(_remote_avatars[peer_id]):
            continue
        var state: Dictionary = snapshot[raw_id]
        var avatar = _remote_avatars[peer_id]
        avatar.set_snapshot(
            state.get("position", Vector3.ZERO),
            float(state.get("yaw", 0.0)),
            float(state.get("speed", 0.0)),
            str(state.get("mount", "")),
            state.get("velocity", Vector3.ZERO)
        )

func _remove_remote_avatar(peer_id: int) -> void:
    if not _remote_avatars.has(peer_id):
        return
    var avatar = _remote_avatars[peer_id]
    if is_instance_valid(avatar):
        avatar.queue_free()
    _remote_avatars.erase(peer_id)

func _clear_remote_avatars() -> void:
    for avatar in _remote_avatars.values():
        if is_instance_valid(avatar):
            avatar.queue_free()
    _remote_avatars.clear()

func _on_campaign_changed() -> void:
    if _mode == Mode.HOST:
        _campaign_dirty = true

func _on_island_changed(_island_id: int) -> void:
    if _mode == Mode.HOST:
        _campaign_dirty = true

@rpc("authority", "call_remote", "reliable")
func _receive_campaign_snapshot(campaign: Dictionary) -> void:
    if _mode != Mode.CLIENT:
        return
    GameState.apply_multiplayer_snapshot(campaign)

@rpc("any_peer", "call_remote", "reliable")
func _request_combat(action: String, ability_index: int) -> void:
    if _mode != Mode.HOST:
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if not _player_infos.has(sender_id):
        return
    var info: Dictionary = _player_infos[sender_id]
    var values := _combat_values(str(info.get("hero", "cheikh")), action, ability_index)
    if values.is_empty():
        return
    var motion: Dictionary = _peer_snapshots.get(sender_id, {})
    var origin = motion.get("position", Vector3.ZERO)
    if not origin is Vector3:
        return
    var radius := float(values["radius"])
    var damage := float(values["damage"])
    _damage_local_enemies(origin, radius, damage)
    _play_remote_action(sender_id, action)
    rpc("_apply_area_damage", sender_id, origin, radius, damage, action)

@rpc("authority", "call_remote", "reliable")
func _apply_area_damage(attacker_peer: int, origin: Vector3, radius: float, damage: float, action: String) -> void:
    if _mode != Mode.CLIENT:
        return
    _damage_local_enemies(origin, radius, damage)
    _play_remote_action(attacker_peer, action)

func _damage_local_enemies(origin: Vector3, radius: float, damage: float) -> void:
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if not (enemy is Node3D) or not is_instance_valid(enemy):
            continue
        if origin.distance_to((enemy as Node3D).global_position) > radius:
            continue
        if enemy.has_method("receive_damage"):
            enemy.call("receive_damage", damage)

func _play_remote_action(peer_id: int, action: String) -> void:
    if not _remote_avatars.has(peer_id):
        return
    var avatar = _remote_avatars[peer_id]
    if is_instance_valid(avatar):
        avatar.play_action("ability" if action == "ability" else "attack")

func _combat_values(hero_id: String, action: String, ability_index: int) -> Dictionary:
    if action == "basic":
        return {"radius": 2.45, "damage": 28.0}
    if action != "ability":
        return {}
    var hero: Dictionary = _hero_catalog.get(_sanitize_hero(hero_id), {})
    var abilities: Array = hero.get("abilities", [])
    if ability_index < 0 or ability_index >= abilities.size():
        return {}
    var ability: Dictionary = abilities[ability_index]
    return {
        "radius": 4.0 if ability_index == 0 else 6.5,
        "damage": maxf(0.0, float(ability.get("damage", 0.0)))
    }

func _sanitize_name(value: String) -> String:
    var result := value.strip_edges()
    if result.is_empty():
        result = "Joueur"
    return result.left(20)

func _sanitize_hero(value: String) -> String:
    var result := value.to_lower()
    return result if result in ["cheikh", "yvane", "nelvyn"] else "cheikh"

func _object_has_property(object: Object, property_name: String) -> bool:
    for entry in object.get_property_list():
        if str(entry.get("name", "")) == property_name:
            return true
    return false

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
