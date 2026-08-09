extends "res://scripts/player/hero_controller.gd"

var _v2_invulnerability := 0.0
var _energy_emit_accumulator := 0.0
var _position_snapshot_accumulator := 0.0
var _respawn_in_progress := false
var _damage_immunity_until_ms := 0
var _impact_velocity := Vector3.ZERO

func _physics_process(delta: float) -> void:
    _v2_invulnerability = maxf(0.0, _v2_invulnerability - delta)
    super._physics_process(delta)

    # Un impact ne doit plus laisser le héros parfaitement immobile. Le recul est
    # appliqué comme un second mouvement collisionné puis amorti rapidement.
    if _impact_velocity.length_squared() > 0.01:
        var collision := move_and_collide(_impact_velocity * delta)
        if collision != null:
            _impact_velocity = _impact_velocity.slide(collision.get_normal()) * 0.42
        _impact_velocity = _impact_velocity.move_toward(Vector3.ZERO, 22.0 * delta)

    if energy < max_energy and _attack_lock <= 0.0:
        var before := energy
        energy = minf(max_energy, energy + delta * 8.5)
        _energy_emit_accumulator += absf(energy - before)
        if _energy_emit_accumulator >= 0.8 or is_equal_approx(energy, max_energy):
            _energy_emit_accumulator = 0.0
            energy_changed.emit(energy, max_energy)

    if get_tree().get_first_node_in_group("active_controller") == null:
        _position_snapshot_accumulator += delta
        if _position_snapshot_accumulator >= 0.20:
            _position_snapshot_accumulator = 0.0
            GameState.set_exact_snapshot(global_position, global_rotation.y, false)
    else:
        _position_snapshot_accumulator = 0.0

func _start_dodge(direction: Vector3) -> void:
    super._start_dodge(direction)
    _v2_invulnerability = 0.30
    _damage_immunity_until_ms = Time.get_ticks_msec() + 300

func receive_damage(amount: float) -> void:
    # L'horloge monotone continue même lorsque la physique du héros est coupée
    # à bord d'un bateau/véhicule. Un simple compteur delta restait sinon figé.
    if _respawn_in_progress or Time.get_ticks_msec() < _damage_immunity_until_ms or amount <= 0.0:
        return
    var resolved_amount := amount * GameState.difficulty_damage_multiplier()
    health = maxf(0.0, health - resolved_amount)
    health_changed.emit(health, max_health)
    _apply_damage_recoil()
    # Une courte fenêtre empêche les six ennemis voisins d'appliquer tous leurs
    # dégâts pendant la même frame. L'esquive conserve sa fenêtre plus courte.
    _v2_invulnerability = 0.48
    _damage_immunity_until_ms = Time.get_ticks_msec() + 480
    if health <= 0.0:
        _respawn_in_progress = true
        _complete_respawn.call_deferred()

func _apply_damage_recoil() -> void:
    var nearest: Node3D
    var best := INF
    for node in get_tree().get_nodes_in_group("enemy"):
        if not (node is Node3D) or not is_instance_valid(node):
            continue
        var d := global_position.distance_squared_to((node as Node3D).global_position)
        if d < best:
            best = d
            nearest = node as Node3D

    var away := global_transform.basis.z
    if nearest != null:
        away = global_position - nearest.global_position
    away.y = 0.0
    if away.length_squared() < 0.01:
        away = global_transform.basis.z
    away = away.normalized()
    var strength := 8.0 if nearest != null and bool(nearest.get("boss")) else 5.6
    _impact_velocity = away * strength

func _complete_respawn() -> void:
    # Le respawn est différé : les callbacks de tous les ennemis de la frame en
    # cours ont fini avant que le héros, le bateau ou un véhicule ne soit déplacé.
    health = max_health
    energy = max_energy
    aura = 0.0
    velocity = Vector3.ZERO
    _impact_velocity = Vector3.ZERO
    _virtual_move = Vector2.ZERO
    health_changed.emit(health, max_health)
    energy_changed.emit(energy, max_energy)
    aura_changed.emit(aura)
    get_tree().call_group("world_director", "respawn_player")
    GameState.quick_save()
    _v2_invulnerability = 1.15
    _damage_immunity_until_ms = Time.get_ticks_msec() + 1150
    _respawn_in_progress = false
