extends SceneTree

var failures := PackedStringArray()

func _init() -> void:
    var quests := _load_json("res://data/island_quests.json")
    var heroes := _load_json("res://data/heroes.json")

    _check(quests.size() == 11, "11 quêtes scénarisées présentes")
    for island_id in range(1, 12):
        var quest: Dictionary = quests.get(str(island_id), {})
        _check(not quest.is_empty(), "quête île %02d présente" % island_id)
        for field in [
            "id", "title", "npc_name", "npc_role", "dialogue_intro",
            "dialogue_active", "dialogue_return", "dialogue_done",
            "location_name", "location_type", "location_hint",
            "item_id", "object_label", "required", "reward_item"
        ]:
            _check(quest.has(field) and not str(quest.get(field, "")).strip_edges().is_empty(), "île %02d champ %s" % [island_id, field])
        _check(str(quest.get("location_type", "")) == "cave", "île %02d possède une grotte de mission" % island_id)
        _check(int(quest.get("required", 0)) >= 3, "île %02d demande plusieurs objets" % island_id)

    for hero_id in ["cheikh", "yvane", "nelvyn"]:
        var hero: Dictionary = heroes.get(hero_id, {})
        var abilities: Array = hero.get("abilities", [])
        _check(abilities.size() == 2, "%s possède attaque 2 et attaque 3" % hero_id)
        if abilities.size() == 2:
            _check(int((abilities[0] as Dictionary).get("unlock_level", 0)) == 20, "%s attaque 2 débloquée niveau 20" % hero_id)
            _check(int((abilities[1] as Dictionary).get("unlock_level", 0)) == 30, "%s attaque 3 débloquée niveau 30" % hero_id)
            _check(float((abilities[1] as Dictionary).get("damage", 0.0)) > float((abilities[0] as Dictionary).get("damage", 0.0)), "%s attaque 3 sensiblement plus puissante" % hero_id)
            _check(float((abilities[1] as Dictionary).get("radius", 0.0)) > float((abilities[0] as Dictionary).get("radius", 0.0)), "%s attaque 3 possède une plus grande portée" % hero_id)
        _check(not str(hero.get("aura_style", "")).is_empty(), "%s possède un style d'aura" % hero_id)
        _check(not str(hero.get("aura_color", "")).is_empty(), "%s possède une couleur d'aura" % hero_id)

    var aura_styles := {
        str(heroes.get("cheikh", {}).get("aura_style", "")): true,
        str(heroes.get("yvane", {}).get("aura_style", "")): true,
        str(heroes.get("nelvyn", {}).get("aura_style", "")): true
    }
    _check(aura_styles.size() == 3, "les trois héros ont des auras différentes")

    for path in [
        "res://scripts/world/story_quest_director_v11_1.gd",
        "res://scripts/ui/hud_mobile_v11_1.gd",
        "res://scripts/player/hero_controller_v11_1.gd"
    ]:
        _check(FileAccess.file_exists(path), "%s présent" % path)

    if failures.is_empty():
        print("CHK_PIRATE_WARRIOR_2_V11_1_STORY_QUESTS_OK")
        quit(0)
        return

    for failure in failures:
        push_error("V11.1 AUDIT: %s" % failure)
    quit(2)

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK V11.1  ", message)
    else:
        failures.append(message)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
