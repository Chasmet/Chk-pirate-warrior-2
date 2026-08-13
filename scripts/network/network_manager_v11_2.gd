class_name NetworkManagerV11_2
extends "res://scripts/network/network_manager_v10.gd"

signal host_migration_started(candidate_name: String)
signal host_migration_completed(new_host_name: String)

var _migration_active := false
var _last_campaign_before_disconnect: Dictionary = {}

func _on_server_disconnected() -> void:
    if not is_client():
        super._on_server_disconnected()
        return

    _last_campaign_before_disconnect = GameState.multiplayer_snapshot().duplicate(true)
    if GameState.has_method("save_coop_snapshot"):
        GameState.call("save_coop_snapshot")

    var old_local_id := multiplayer.get_unique_id()
    var candidates: Array[int] = []
    for raw_id in _player_infos.keys():
        var peer_id := int(raw_id)
        if peer_id > 1:
            candidates.append(peer_id)
    if old_local_id > 1 and not candidates.has(old_local_id):
        candidates.append(old_local_id)
    candidates.sort()

    var elected_id := candidates[0] if not candidates.is_empty() else -1
    var elected_name := "Joueur"
    if elected_id > 1:
        var info_value = _player_infos.get(elected_id, {})
        if info_value is Dictionary:
            elected_name = str((info_value as Dictionary).get("name", elected_name))

    super.disconnect_session("")

    if elected_id < 0:
        session_closed.emit("Hôte perdu • sauvegarde coop conservée.")
        return

    _migration_active = true
    host_migration_started.emit(elected_name)
    connection_status_changed.emit("Hôte perdu • %s reprend la partie coop…" % elected_name)
    get_tree().call_group("gameplay_ux", "show_network_notice", "%s REPREND LA PARTIE COOP" % elected_name.to_upper())

    if old_local_id == elected_id:
        _become_replacement_host.call_deferred()
    else:
        start_discovery_scan()
        session_closed.emit("%s reprend la partie. Recherche-la dans COOP LOCALE WI-FI pour la rejoindre." % elected_name)

func _become_replacement_host() -> void:
    await get_tree().create_timer(0.8).timeout
    if not _migration_active:
        return

    var campaign := _last_campaign_before_disconnect.duplicate(true)
    if not campaign.is_empty():
        GameState.apply_multiplayer_snapshot(campaign)

    var err := super.create_host(_local_name, _local_hero)
    if err != OK:
        _migration_active = false
        session_closed.emit("Impossible de reprendre automatiquement la partie • sauvegarde coop conservée.")
        return

    _migration_active = false
    GameState.quick_save()
    host_migration_completed.emit(_local_name)
    connection_status_changed.emit("COOP CONTINUE • %s est le nouvel hôte" % _local_name)
    get_tree().call_group("gameplay_ux", "show_network_notice", "%s EST LE NOUVEL HÔTE" % _local_name.to_upper())

func migration_active() -> bool:
    return _migration_active
