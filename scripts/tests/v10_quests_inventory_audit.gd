extends SceneTree

func _init() -> void:
    var failures: Array[String] = []
    var quests := _load_json("res://data/island_quests.json")
    var items := _load_json("res://data/items.json")

    if quests.size() != 11:
        failures.append("Le catalogue doit contenir exactement 11 quêtes.")

    for island_id in range(1, 12):
        var key := str(island_id)
        if not quests.has(key):
            failures.append("Quête absente pour l'île %d." % island_id)
            continue
        var quest: Dictionary = quests[key]
        for field in ["id", "title", "description", "item_id", "required", "reward_item", "chest_item"]:
            if not quest.has(field):
                failures.append("Île %d : champ %s absent." % [island_id, field])
        for item_field in ["item_id", "reward_item", "chest_item"]:
            var item_id := str(quest.get(item_field, ""))
            if item_id.is_empty() or not items.has(item_id):
                failures.append("Île %d : objet inconnu %s." % [island_id, item_id])
        if int(quest.get("required", 0)) < 3:
            failures.append("Île %d : quête trop courte." % island_id)

    for island_id in range(1, 12):
        var quest: Dictionary = quests.get(str(island_id), {})
        var quest_item := str(quest.get("item_id", ""))
        if items.has(quest_item):
            var data: Dictionary = items[quest_item]
            if not bool(data.get("quest_item", false)):
                failures.append("%s doit être marqué quest_item." % quest_item)
            if int(data.get("slot_cost", 1)) != 0:
                failures.append("%s ne doit pas bloquer la capacité du sac." % quest_item)

    if not FileAccess.file_exists("res://scripts/world/island_collectible_director_v10.gd"):
        failures.append("Directeur de coffres V10 absent.")
    if not FileAccess.file_exists("res://scripts/player/hero_controller_v10.gd"):
        failures.append("Contrôleur héros V10 absent.")
    if not FileAccess.file_exists("res://scripts/ui/hud_mobile_v10.gd"):
        failures.append("HUD sac V10 absent.")

    if failures.is_empty():
        print("CHK_PIRATE_WARRIOR_2_V10_QUESTS_INVENTORY_OK")
        quit(0)
        return

    for failure in failures:
        push_error("V10 AUDIT: %s" % failure)
    quit(2)

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
