extends "res://scripts/player/hero_controller.gd"

var _v2_invulnerability := 0.0
var _energy_emit_accumulator := 0.0
var _position_snapshot_accumulator := 0.0

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
    Input.vibrate_handheld(18)

func receive_damage(amount: float) -> void:
    if _v2_invulnerability > 0.0 or amount <= 0.0:
        return
    var resolved_amount := amount * GameState.difficulty_damage_multiplier()
    health = maxf(0.0, health - resolved_amount)
    health_changed.emit(health, max_health)
    Input.vibrate_handheld(45)
    if health <= 0.0:
        health = max_health
        energy = max_energy
        aura = 0.0
        health_changed.emit(health, max_health)
        energy_changed.emit(energy, max_energy)
        aura_changed.emit(aura)
        get_tree().call_group("world_director", "respawn_player")
        GameState.quick_save()
