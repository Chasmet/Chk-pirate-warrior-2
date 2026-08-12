extends "res://scripts/network/network_manager.gd"

# V9 conserve le réseau V7/V8 tel quel et remplace uniquement le calcul des
# dégâts. L'hôte reste autoritaire : un client ne peut pas utiliser une attaque
# qui n'est pas encore débloquée par le niveau de la campagne.
func _combat_values(hero_id: String, action: String, ability_index: int) -> Dictionary:
    var hero: Dictionary = _hero_catalog.get(_sanitize_hero(hero_id), {})
    if hero.is_empty():
        return {}

    var level := maxi(1, GameState.level)
    var growth := maxf(0.0, float(hero.get("damage_growth", 0.02)))
    var level_multiplier := 1.0 + float(level - 1) * growth

    if action == "basic":
        return {
            "radius": maxf(1.0, float(hero.get("base_attack_radius", 2.45))),
            "damage": maxf(0.0, float(hero.get("base_attack_damage", 28.0))) * level_multiplier
        }

    if action != "ability":
        return {}

    var abilities: Array = hero.get("abilities", [])
    if ability_index < 0 or ability_index >= abilities.size():
        return {}

    var ability: Dictionary = abilities[ability_index]
    if level < int(ability.get("unlock_level", 1)):
        return {}

    return {
        "radius": maxf(1.0, float(ability.get("radius", 4.0))),
        "damage": maxf(0.0, float(ability.get("damage", 0.0))) * level_multiplier
    }
