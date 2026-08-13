class_name StoryQuestDirectorV11_2
extends "res://scripts/world/story_quest_director_v11_1.gd"

const V112_INTERACTION_DISTANCE := 6.0

func _ready() -> void:
    super._ready()
    _repair_legacy_quest_pickups.call_deferred()

func request_interaction() -> bool:
    if NetworkManager.is_client():
        return super.request_interaction()
    var nearest := _nearest_interactive(V112_INTERACTION_DISTANCE)
    if nearest == null:
        _notify("RIEN À INTERAGIR • APPROCHE-TOI DAVANTAGE")
        return false
    _collect_interactive(nearest)
    return true

func interaction_prompt_v11_2() -> Dictionary:
    var pickup := _nearest_interactive(V112_INTERACTION_DISTANCE)
    if pickup == null or _player == null:
        return {}
    var kind := str(pickup.get_meta("kind", ""))
    var label := "INTERAGIR"
    if kind == "quest_npc":
        label = "PARLER"
    elif kind == "quest_item":
        label = "PRENDRE OBJET"
    elif kind == "chest":
        label = "OUVRIR COFFRE"
    return {
        "kind": kind,
        "label": label,
        "distance": _player.global_position.distance_to(pickup.global_position)
    }

func navigation_target_v11_2() -> Dictionary:
    var quest := _current_quest()
    if quest.is_empty():
        return {}
    var quest_id := str(quest.get("id", ""))
    if bool(GameState.get_quest_value("quest_done_%s" % quest_id, false)):
        return {}

    var accepted := bool(GameState.get_quest_value("quest_accepted_%s" % quest_id, false))
    if not accepted and _npc_node != null and is_instance_valid(_npc_node):
        return {
            "position": _npc_node.global_position,
            "label": "PARLER À %s" % str(quest.get("npc_name", "PNJ")).to_upper()
        }

    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    var count := GameState.inventory_count(item_id)
    if count >= required and _npc_node != null and is_instance_valid(_npc_node):
        return {
            "position": _npc_node.global_position,
            "label": "RETOUR %s" % str(quest.get("npc_name", "PNJ")).to_upper()
        }

    var target := _nearest_kind("quest_item")
    if target != null and is_instance_valid(target):
        return {
            "position": target.global_position,
            "label": "%s %d/%d" % [str(quest.get("object_label", "OBJET")).to_upper(), count, required]
        }

    if _cave_node != null and is_instance_valid(_cave_node):
        return {
            "position": _cave_node.global_position,
            "label": str(quest.get("location_name", "GROTTE DE MISSION")).to_upper()
        }
    return {}

func _nearest_interactive(max_distance: float) -> Node3D:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D
    if _player == null:
        return null
    var nearest: Node3D = null
    var best := max_distance
    for pickup in _pickups:
        if pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        var kind := str(pickup.get_meta("kind", ""))
        if kind not in ["quest_npc", "quest_item", "chest"]:
            continue
        var distance := _player.global_position.distance_to(pickup.global_position)
        if distance <= best:
            best = distance
            nearest = pickup
    return nearest

func _repair_legacy_quest_pickups() -> void:
    var quest := _current_quest()
    if quest.is_empty():
        return
    var quest_id := str(quest.get("id", ""))
    if not bool(GameState.get_quest_value("quest_accepted_%s" % quest_id, false)):
        return
    if bool(GameState.get_quest_value("quest_done_%s" % quest_id, false)):
        return

    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    var real_count := mini(required, GameState.inventory_count(item_id))
    var kept_flags := 0
    var changed := false
    for i in range(required):
        var key := "quest_obj_%02d_%02d" % [_current_island, i]
        if not bool(GameState.get_quest_value(key, false)):
            continue
        if kept_flags < real_count:
            kept_flags += 1
        else:
            GameState.quest_progress.erase(key)
            changed = true
    if changed:
        GameState.progression_changed.emit()
        GameState.quick_save()
        _rebuild_serial += 1
        _rebuild.call_deferred(_rebuild_serial)
