class_name NetworkManagerV11_6
extends "res://scripts/network/network_manager_v11_4.gd"

# V11.6 : l'hôte devient l'autorité des dégâts infligés par les ennemis aux
# joueurs distants. Les attaques des joueurs transportent aussi l'identité du
# peer jusqu'au cerveau ennemi pour alimenter son système de menace.

func host_apply_enemy_damage(peer_id: int, amount: float, source_name: String = "Ennemi") -> bool:
    if not is_host() or amount <= 0.0 or not _player_infos.has(peer_id):
        return false
    var resolved_damage := clampf(amount, 0.0, 250.0)
    if peer_id == multiplayer.get_unique_id():
        return _apply_enemy_damage_to_local_player(resolved_damage, source_name)
    rpc_id(peer_id, "_receive_enemy_damage_v11_6", resolved_damage, source_name.left(48))
    return true

@rpc("authority", "call_remote", "reliable")
func _receive_enemy_damage_v11_6(amount: float, source_name: String) -> void:
    if not is_client():
        return
    _apply_enemy_damage_to_local_player(clampf(amount, 0.0, 250.0), source_name)

func _apply_enemy_damage_to_local_player(amount: float, source_name: String) -> bool:
    var player := get_tree().get_first_node_in_group("player")
    if player == null or not is_instance_valid(player) or not player.has_method("receive_damage"):
        return false
    player.call("receive_damage", amount)
    if amount >= 18.0:
        get_tree().call_group("gameplay_ux", "show_network_notice", "%s • -%d PV" % [source_name.to_upper(), int(round(amount))])
    return true

func _damage_local_enemies(origin: Vector3, radius: float, damage: float) -> void:
    # Pendant un RPC, Godot conserve l'identité de l'émetteur : elle sert de
    # source de menace. Pour une attaque locale de l'hôte, on retombe sur peer 1.
    var attacker_peer := multiplayer.get_remote_sender_id()
    if attacker_peer <= 0:
        attacker_peer = multiplayer.get_unique_id() if is_multiplayer_active() else 0

    for enemy in get_tree().get_nodes_in_group("enemy"):
        if not (enemy is Node3D) or not is_instance_valid(enemy):
            continue
        if origin.distance_to((enemy as Node3D).global_position) > radius:
            continue
        if enemy.has_method("receive_damage_from_peer"):
            enemy.call("receive_damage_from_peer", damage, attacker_peer, origin)
        elif enemy.has_method("receive_damage"):
            enemy.call("receive_damage", damage)
