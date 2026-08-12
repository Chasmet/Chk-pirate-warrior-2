class_name AttackFXDirectorV9
extends "res://scripts/v1_30/power_fx_v1_30.gd"

var _attack_color_override := Color.WHITE
var _use_attack_color_override := false

func _bind_player() -> void:
    super._bind_player()
    if _player == null:
        return
    if _player.has_signal("basic_attack_used"):
        var callback := Callable(self, "_on_basic_attack_used")
        if not _player.is_connected("basic_attack_used", callback):
            _player.connect("basic_attack_used", callback)

func _on_basic_attack_used(attack: Dictionary) -> void:
    _boost_remaining = 0.58
    _spawn_attack_burst(attack, false)
    _show_attack_name(attack, 0.95)

func _on_ability_used(index: int, ability: Dictionary) -> void:
    _boost_remaining = 0.95
    _spawn_attack_burst(ability, index > 0)
    _show_attack_name(ability, 1.25)

func _spawn_attack_burst(attack: Dictionary, stronger: bool) -> void:
    if _player == null or not is_instance_valid(_player):
        return
    _attack_color_override = _attack_color(attack)
    _use_attack_color_override = true
    super._spawn_energy_burst(1 if stronger else 0, attack)
    _use_attack_color_override = false

    if _bursts.is_empty():
        return
    var burst := _bursts[_bursts.size() - 1]
    if burst == null or not is_instance_valid(burst):
        return
    var radius := maxf(1.0, float(attack.get("radius", 4.0)))
    burst.set_meta("radius", radius)
    burst.set_meta("duration", clampf(0.42 + radius * 0.055, 0.50, 0.95))

    var effect := str(attack.get("effect", "")).to_lower()
    var wave := burst.get_node_or_null("OndeEnergie") as MeshInstance3D
    if wave != null:
        if effect.contains("blade") or effect.contains("crystal") or effect.contains("cerberus"):
            wave.scale.y = 0.34
            wave.rotation_degrees.x = 62.0
        elif effect.contains("sphere") or effect.contains("ball") or effect.contains("bang"):
            wave.rotation_degrees.x = 90.0

func _hero_energy_color() -> Color:
    if _use_attack_color_override:
        return _attack_color_override
    return super._hero_energy_color()

func _attack_color(attack: Dictionary) -> Color:
    var value := str(attack.get("color", ""))
    if value.is_empty():
        return super._hero_energy_color()
    return Color(value)

func _show_attack_name(attack: Dictionary, duration: float) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", "ATTAQUE • %s" % str(attack.get("name", "Capacité")), duration)
