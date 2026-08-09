extends "res://scripts/player/hero_controller.gd"

var _v2_invulnerability := 0.0
var _energy_emit_accumulator := 0.0
var _position_snapshot_accumulator := 0.0
var _respawn_in_progress := false
var _damage_immunity_until_ms := 0

func _physics_process(delta: float) -> void:
    _v2_invulnerability = maxf(0.0, _v2_invulnerability - delta)
    super._physics_process(delta)

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
    # Une courte fenêtre empêche les six ennemis voisins d'appliquer tous leurs
    # dégâts pendant la même frame. L'esquive conserve sa fenêtre plus courte.
    _v2_invulnerability = 0.48
    _damage_immunity_until_ms = Time.get_ticks_msec() + 480
    if health <= 0.0:
        _respawn_in_progress = true
        _complete_respawn.call_deferred()

func _complete_respawn() -> void:
    # Le respawn est différé : les callbacks de tous les ennemis de la frame en
    # cours ont fini avant que le héros, le bateau ou un véhicule ne soit déplacé.
    health = max_health
    energy = max_energy
    aura = 0.0
    velocity = Vector3.ZERO
    _virtual_move = Vector2.ZERO
    health_changed.emit(health, max_health)
    energy_changed.emit(energy, max_energy)
    aura_changed.emit(aura)
    get_tree().call_group("world_director", "respawn_player")
    GameState.quick_save()
    _v2_invulnerability = 1.15
    _damage_immunity_until_ms = Time.get_ticks_msec() + 1150
    _respawn_in_progress = false
