class_name GameStateV11_2
extends "res://scripts/systems/game_state_v10.gd"

const COOP_SAVE_PATH := "user://savegame_coop_v11_2.json"
var _last_coop_disk_write_ms := -5000

func quick_save() -> void:
    if _is_coop_session_active():
        _write_coop_save()
        return
    super.quick_save()

func has_save() -> bool:
    if _is_coop_session_active():
        return has_coop_save()
    return super.has_save()

func load_save() -> bool:
    if _is_coop_session_active():
        return load_coop_save()
    return super.load_save()

func has_personal_save() -> bool:
    return super.has_save()

func has_coop_save() -> bool:
    return not CHKSaveFiles.read_json(COOP_SAVE_PATH).is_empty()

func load_personal_save() -> bool:
    return super.load_save()

func load_coop_save() -> bool:
    var data := CHKSaveFiles.read_json(COOP_SAVE_PATH)
    if data.is_empty():
        return false

    var saved_hero := str(data.get("hero", selected_hero))
    if not get_hero_data(saved_hero).is_empty():
        selected_hero = saved_hero

    exact_position = data.get("exact_position", []) if data.get("exact_position", []) is Array else []
    exact_rotation_y = float(data.get("exact_rotation_y", 0.0))
    exact_boat_mode = bool(data.get("exact_boat_mode", false))

    super.apply_multiplayer_snapshot(data)
    hero_changed.emit(selected_hero)
    return true

func apply_multiplayer_snapshot(data: Dictionary) -> void:
    super.apply_multiplayer_snapshot(data)
    if _is_coop_session_active() and Time.get_ticks_msec() - _last_coop_disk_write_ms >= 5000:
        _write_coop_save()

func save_coop_snapshot() -> void:
    _write_coop_save()

func coop_save_summary() -> Dictionary:
    var data := CHKSaveFiles.read_json(COOP_SAVE_PATH)
    if data.is_empty():
        return {}
    return {
        "island": clampi(int(data.get("island", 1)), 1, 11),
        "level": clampi(int(data.get("level", 1)), 1, MAX_PLAYER_LEVEL),
        "coins": maxi(0, int(data.get("coins", 0))),
        "bosses": (data.get("defeated_bosses", {}) as Dictionary).size() if data.get("defeated_bosses", {}) is Dictionary else 0,
        "saved_at": int(data.get("coop_saved_at_unix", 0))
    }

func _is_coop_session_active() -> bool:
    var network := get_node_or_null("/root/NetworkManager")
    return network != null and network.has_method("is_multiplayer_active") and bool(network.call("is_multiplayer_active"))

func _write_coop_save() -> void:
    var network := get_node_or_null("/root/NetworkManager")
    var players: Dictionary = {}
    if network != null and network.has_method("players_snapshot"):
        var snapshot = network.call("players_snapshot")
        if snapshot is Dictionary:
            players = snapshot.duplicate(true)

    var data := {
        "save_version": 3,
        "save_mode": "coop",
        "hero": selected_hero,
        "island": current_island,
        "inventory": inventory.duplicate(true),
        "difficulty": difficulty,
        "discovered_islands": discovered_islands.duplicate(),
        "defeated_bosses": defeated_bosses.duplicate(true),
        "quest_progress": quest_progress.duplicate(true),
        "crew_reputation": crew_reputation.duplicate(true),
        "coins": coins,
        "xp": xp,
        "level": level,
        "boat_level": boat_level,
        "world_time": world_time,
        "final_unlocked": final_unlocked,
        "final_reward_collected": final_reward_collected,
        "exact_position": exact_position.duplicate(),
        "exact_rotation_y": exact_rotation_y,
        "exact_boat_mode": exact_boat_mode,
        "coop_players": players,
        "coop_saved_at_unix": int(Time.get_unix_time_from_system())
    }
    _decorate_coop_save(data)
    if CHKSaveFiles.write_json(COOP_SAVE_PATH, data) == OK:
        _last_coop_disk_write_ms = Time.get_ticks_msec()

func _decorate_coop_save(_data: Dictionary) -> void:
    pass
