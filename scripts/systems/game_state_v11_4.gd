class_name GameStateV11_4
extends "res://scripts/systems/game_state_v11_2.gd"

const PLAYER_ID_PATH := "user://player_identity_v11_4.json"
const IDENTITY_COLORS := {
    "cheikh": "22c55e",
    "yvane": "ef4444",
    "nelvyn": "facc15"
}

var player_profile_id := ""

func _ready() -> void:
    super._ready()
    _ensure_player_profile_id()

func profile_id() -> String:
    _ensure_player_profile_id()
    return player_profile_id

func hero_identity_color_hex(hero_id: String = selected_hero) -> String:
    var resolved := hero_id.to_lower()
    return str(IDENTITY_COLORS.get(resolved, "ffffff"))

func hero_identity_color(hero_id: String = selected_hero) -> Color:
    return Color(hero_identity_color_hex(hero_id))

func _decorate_coop_save(data: Dictionary) -> void:
    data["local_player_profile_id"] = profile_id()
    data["identity_schema"] = 1

    var network := get_node_or_null("/root/NetworkManager")
    if network != null:
        if network.has_method("coop_session_id"):
            data["coop_session_id"] = str(network.call("coop_session_id"))
        if network.has_method("vehicle_seats_snapshot"):
            var seats = network.call("vehicle_seats_snapshot")
            if seats is Dictionary:
                data["coop_vehicle_seats"] = seats

func _ensure_player_profile_id() -> void:
    if not player_profile_id.is_empty():
        return

    var existing := CHKSaveFiles.read_json(PLAYER_ID_PATH)
    var saved := str(existing.get("player_profile_id", "")).strip_edges()
    if not saved.is_empty():
        player_profile_id = saved
        return

    var rng := RandomNumberGenerator.new()
    rng.randomize()
    player_profile_id = "chk-%08x-%08x-%08x" % [
        int(Time.get_unix_time_from_system()) & 0xffffffff,
        int(Time.get_ticks_msec()) & 0xffffffff,
        int(rng.randi()) & 0xffffffff
    ]

    var data := {
        "schema": 1,
        "player_profile_id": player_profile_id,
        "created_at_unix": int(Time.get_unix_time_from_system())
    }
    var result := CHKSaveFiles.write_json(PLAYER_ID_PATH, data)
    if result != OK:
        push_warning("Identité coop non sauvegardée : %s" % error_string(result))
