class_name GameplayStabilityDirectorV11_3
extends "res://scripts/v1_30/gameplay_stability_director.gd"

const DEBUG_LOG_PATH := "user://runtime_v11_3.log"
const DEBUG_LOG_MAX_BYTES := 262144
const HEARTBEAT_SECONDS := 30.0
const MAX_SAFE_WORLD_COORD := 20000.0
const MIN_SAFE_WORLD_Y := -80.0
const MAX_PLAYER_SPEED := 48.0

var _last_heartbeat_msec := 0

func _ready() -> void:
    super._ready()
    add_to_group("gameplay_stability_v11_3")
    _last_heartbeat_msec = Time.get_ticks_msec()
    _log_event("BOOT", "V11.8 stabilité active")

func _repair_all() -> void:
    super._repair_all()
    _repair_invalid_player_transform()
    _repair_player_velocity()
    _repair_camera_state()
    _repair_duplicate_ui_layers()
    _repair_multiple_active_controllers()
    _write_heartbeat_if_needed()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        _cancel_mobile_inputs()
        GameState.quick_save()
        _log_event("APP_SUSPEND", "Entrées tactiles annulées et sauvegarde demandée")
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        _repair_all.call_deferred()
        _log_event("FOCUS_IN", "Retour application, auto-réparation lancée")

func _repair_invalid_player_transform() -> void:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if _player == null:
        return

    var p := _player.global_position
    var invalid := not _vector3_is_finite(p)
    invalid = invalid or absf(p.x) > MAX_SAFE_WORLD_COORD or absf(p.z) > MAX_SAFE_WORLD_COORD
    invalid = invalid or p.y < MIN_SAFE_WORLD_Y or p.y > MAX_SAFE_WORLD_COORD
    if not invalid:
        return

    var positions := WorldCatalog.world_positions()
    var index := clampi(GameState.current_island - 1, 0, maxi(0, positions.size() - 1))
    var safe := Vector3(0.0, 14.0, 0.0)
    if not positions.is_empty():
        safe = positions[index] + Vector3(0.0, 14.0, 0.0)
    _player.global_position = safe
    _player.velocity = Vector3.ZERO
    _player.set_physics_process(true)
    _log_event("PLAYER_RECOVER", "Position invalide réparée vers %s" % str(safe))
    _notify("Position du héros restaurée automatiquement.")

func _repair_player_velocity() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    if not _vector3_is_finite(_player.velocity):
        _player.velocity = Vector3.ZERO
        _log_event("VELOCITY_NAN", "Vitesse invalide remise à zéro")
        return
    var speed := _player.velocity.length()
    if speed > MAX_PLAYER_SPEED:
        _player.velocity = _player.velocity.limit_length(MAX_PLAYER_SPEED)
        _log_event("VELOCITY_CLAMP", "Vitesse %.2f limitée à %.2f" % [speed, MAX_PLAYER_SPEED])

func _repair_camera_state() -> void:
    var viewport := get_viewport()
    if viewport == null:
        return
    var camera := viewport.get_camera_3d()
    if camera != null and is_instance_valid(camera):
        return
    if _player == null or not is_instance_valid(_player):
        return
    var fallback := _player.find_child("Camera3D", true, false) as Camera3D
    if fallback != null:
        fallback.current = true
        _log_event("CAMERA_RECOVER", "Caméra principale réactivée")

func _repair_duplicate_ui_layers() -> void:
    _dedupe_group("hud", "HUD")
    _dedupe_group("gameplay_ux", "GAMEPLAY_UX")

func _dedupe_group(group_name: StringName, label: String) -> void:
    var nodes := get_tree().get_nodes_in_group(group_name)
    if nodes.size() <= 1:
        return
    var keeper: Node = nodes[0]
    for i in range(1, nodes.size()):
        var duplicate: Node = nodes[i]
        if duplicate == null or duplicate == keeper or not is_instance_valid(duplicate):
            continue
        duplicate.queue_free()
        _log_event("UI_DEDUP", "%s dupliqué supprimé: %s" % [label, str(duplicate.name)])

func _repair_multiple_active_controllers() -> void:
    var actives := get_tree().get_nodes_in_group("active_controller")
    if actives.size() <= 1:
        return

    var keeper: Node = null
    for candidate in actives:
        if candidate == null or not is_instance_valid(candidate):
            continue
        if candidate.has_method("is_boarded") and bool(candidate.call("is_boarded")):
            keeper = candidate
            break
    if keeper == null:
        keeper = actives[0]

    for candidate in actives:
        if candidate == null or candidate == keeper or not is_instance_valid(candidate):
            continue
        candidate.remove_from_group("active_controller")
        _log_event("CONTROLLER_DEDUP", "Contrôleur actif fantôme retiré: %s" % str(candidate.name))

func _cancel_mobile_inputs() -> void:
    var overlay := get_tree().root.find_child("MobileInputOverlay", true, false)
    if overlay != null and overlay.has_method("_cancel_all_touches"):
        overlay.call("_cancel_all_touches")
    for action in ["attack", "ability_1", "ability_2", "dodge", "jump", "interact", "move_left", "move_right", "move_forward", "move_back"]:
        if InputMap.has_action(action):
            Input.action_release(action)

func _write_heartbeat_if_needed() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_heartbeat_msec < int(HEARTBEAT_SECONDS * 1000.0):
        return
    _last_heartbeat_msec = now
    var position_text := "absent"
    if _player != null and is_instance_valid(_player):
        position_text = str(_player.global_position)
    var mode := "solo"
    if NetworkManager != null and NetworkManager.has_method("mode_name"):
        mode = str(NetworkManager.call("mode_name"))
    _log_event(
        "HEARTBEAT",
        "île=%02d héros=%s niv=%d fps=%d mode=%s pos=%s" % [
            GameState.current_island,
            GameState.selected_hero,
            GameState.level,
            roundi(Engine.get_frames_per_second()),
            mode,
            position_text
        ]
    )

func _vector3_is_finite(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _log_event(kind: String, details: String) -> void:
    var file: FileAccess = null
    if FileAccess.file_exists(DEBUG_LOG_PATH):
        file = FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
        if file != null and file.get_length() > DEBUG_LOG_MAX_BYTES:
            file = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
        elif file != null:
            file.seek_end()
    else:
        file = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
    if file == null:
        return
    var stamp := Time.get_datetime_string_from_system()
    file.store_line("[%s] %s • %s" % [stamp, kind, details])
