class_name StoryQuestItemFixV11_2
extends "res://scripts/world/story_quest_director_v11_2.gd"

func _collect_interactive(pickup: Node3D) -> void:
    if pickup == null or not is_instance_valid(pickup):
        return
    if str(pickup.get_meta("kind", "")) != "quest_item":
        super._collect_interactive(pickup)
        return

    var quest := _current_quest()
    if quest.is_empty():
        return
    var item_id := str(pickup.get_meta("item_id", quest.get("item_id", "")))
    var key := str(pickup.get_meta("collect_key", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    if key.is_empty():
        return
    if not GameState.add_item(item_id, 1):
        if GameState.inventory_count(item_id) >= required:
            GameState.set_quest_value(key, true)
            _remove_interactive_pickup(pickup, false)
            _finish_quest_if_ready()
        else:
            _notify("OBJET NON RÉCUPÉRÉ • RÉESSAIE")
        return

    GameState.set_quest_value(key, true)
    GameState.add_xp(12 + _current_island * 2)
    _remove_interactive_pickup(pickup, false)
    _notify("OBJET RÉCUPÉRÉ • %d/%d" % [GameState.inventory_count(item_id), required])
    _finish_quest_if_ready()
    GameState.quick_save()
