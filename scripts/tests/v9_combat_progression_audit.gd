extends SceneTree

const EXPECTED := {
    "cheikh": {
        "base": "Épée des Trois Cerbères",
        "specials": [
            "Épée Isolant",
            "Triple Morsure de Cerbère",
            "Tempête des Trois Lames",
            "Jugement du Roi Pirate"
        ]
    },
    "yvane": {
        "base": "Foudre Serpentine",
        "specials": ["Éco Sphère", "La Méga Boule d'Énergie"]
    },
    "nelvyn": {
        "base": "La Boule de Bing Bang",
        "specials": ["Boule de Feu Suprême", "La Lame de Crystal"]
    }
}

var _errors: Array[String] = []

func _init() -> void:
    _run_audit()
    if _errors.is_empty():
        print("CHK_PIRATE_WARRIOR_2_V9_COMBAT_PROGRESSION_OK")
        quit(0)
        return
    for message in _errors:
        push_error(message)
    quit(1)

func _run_audit() -> void:
    var file := FileAccess.open("res://data/heroes.json", FileAccess.READ)
    if file == null:
        _errors.append("data/heroes.json introuvable")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        _errors.append("data/heroes.json invalide")
        return

    var heroes: Dictionary = parsed
    for hero_id in EXPECTED.keys():
        if not heroes.has(hero_id):
            _errors.append("Héros absent: %s" % hero_id)
            continue
        var hero: Dictionary = heroes[hero_id]
        var expected: Dictionary = EXPECTED[hero_id]
        _expect(str(hero.get("base_attack", "")) == str(expected["base"]), "%s: attaque 1 incorrecte" % hero_id)
        _expect(float(hero.get("base_attack_damage", 0.0)) > 0.0, "%s: dégâts de base invalides" % hero_id)
        _expect(float(hero.get("base_attack_radius", 0.0)) >= 1.0, "%s: portée de base invalide" % hero_id)
        _expect(float(hero.get("base_health", 0.0)) >= 100.0, "%s: PV de base invalides" % hero_id)
        _expect(float(hero.get("base_energy", 0.0)) >= 80.0, "%s: énergie de base invalide" % hero_id)
        _expect(float(hero.get("damage_growth", 0.0)) > 0.0, "%s: croissance de dégâts absente" % hero_id)

        var abilities: Array = hero.get("abilities", [])
        var expected_specials: Array = expected["specials"]
        _expect(abilities.size() == expected_specials.size(), "%s: nombre d'attaques spéciales incorrect" % hero_id)
        var previous_unlock := 1
        for i in range(mini(abilities.size(), expected_specials.size())):
            var ability: Dictionary = abilities[i]
            _expect(str(ability.get("name", "")) == str(expected_specials[i]), "%s: nom attaque %d incorrect" % [hero_id, i + 2])
            var unlock_level := int(ability.get("unlock_level", 0))
            _expect(unlock_level > previous_unlock, "%s: progression des déblocages non croissante" % hero_id)
            previous_unlock = unlock_level
            _expect(float(ability.get("damage", 0.0)) > 0.0, "%s: dégâts invalides pour %s" % [hero_id, ability.get("name", "")])
            _expect(float(ability.get("radius", 0.0)) >= 1.0, "%s: portée invalide pour %s" % [hero_id, ability.get("name", "")])
            _expect(float(ability.get("energy", -1.0)) >= 0.0, "%s: coût énergie invalide" % hero_id)
            _expect(float(ability.get("cooldown", 0.0)) > 0.0, "%s: cooldown invalide" % hero_id)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        _errors.append(message)
