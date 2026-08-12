extends "res://scripts/network/network_manager_v9.gd"

# L'hôte reste autoritaire sur les objets du monde, comme il l'est déjà sur les
# dégâts. Un client demande l'ouverture/la collecte, l'hôte valide la proximité,
# puis GameState diffuse l'inventaire et quest_progress aux autres téléphones.

func request_world_collectible(key: String) -> void:
    if not is_client() or key.is_empty():
        return
    rpc_id(1, "_request_world_collectible", key, GameState.current_island)

@rpc("any_peer", "call_remote", "reliable")
func _request_world_collectible(key: String, island_id: int) -> void:
    if not is_host() or key.is_empty():
        return
    if island_id != GameState.current_island:
        return

    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id <= 1 or not _player_infos.has(sender_id):
        return
    var motion: Dictionary = _peer_snapshots.get(sender_id, {})
    var origin = motion.get("position", Vector3.INF)
    if not origin is Vector3 or origin == Vector3.INF:
        return

    var director := get_tree().get_first_node_in_group("island_collectibles")
    if director != null and director.has_method("host_process_remote_interaction"):
        director.call("host_process_remote_interaction", sender_id, key, origin)
