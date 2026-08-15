class_name IslandVehicleV11_4
extends "res://scripts/player/island_vehicle.gd"

@export var network_vehicle_id := ""

var _local_network_seat := -1
var _passenger_player: CharacterBody3D
var _passenger_collision: CollisionShape3D
var _network_driver_peer := 0
var _network_target_position := Vector3.ZERO
var _network_target_yaw := 0.0
var _network_target_velocity := Vector3.ZERO
var _network_has_transform := false

func configure(spec: Dictionary) -> void:
    network_vehicle_id = str(spec.get("network_vehicle_id", network_vehicle_id))
    super.configure(spec)

func _ready() -> void:
    super._ready()
    add_to_group("coop_vehicle")

func set_network_vehicle_id(value: String) -> void:
    network_vehicle_id = value.strip_edges()

func coop_seat_capacity() -> int:
    if style_key in ["horse", "quad"]:
        return 1
    return 3

func local_network_seat() -> int:
    return _local_network_seat

func try_interact(player: CharacterBody3D) -> bool:
    if not NetworkManager.is_multiplayer_active() or network_vehicle_id.is_empty():
        return super.try_interact(player)
    if player == null:
        return false
    if _local_network_seat < 0 and global_position.distance_to(player.global_position) > interaction_radius:
        return false
    if not NetworkManager.has_method("request_vehicle_interaction"):
        return super.try_interact(player)
    NetworkManager.call("request_vehicle_interaction", network_vehicle_id)
    return true

func apply_network_seats(vehicle_id: String, seats: Array) -> void:
    if vehicle_id != network_vehicle_id:
        return
    var local_peer_id := multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active() else 1
    var new_seat := seats.find(local_peer_id)
    var driver_peer := int(seats[0]) if not seats.is_empty() else 0
    _network_driver_peer = driver_peer

    if new_seat != _local_network_seat:
        _apply_local_seat_change(new_seat)

    var remote_driver := driver_peer > 0 and driver_peer != local_peer_id
    visible = not remote_driver
    if not remote_driver:
        _network_has_transform = false

func apply_network_driver_snapshot(
    vehicle_id: String,
    driver_peer: int,
    world_position: Vector3,
    yaw: float,
    linear_velocity: Vector3
) -> void:
    if vehicle_id != network_vehicle_id:
        return
    var local_peer_id := multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active() else 1
    if driver_peer <= 0 or driver_peer == local_peer_id:
        return
    _network_driver_peer = driver_peer
    _network_target_position = world_position
    _network_target_yaw = yaw
    _network_target_velocity = linear_velocity.limit_length(60.0)
    _network_has_transform = true

func clear_network_driver(vehicle_id: String) -> void:
    if vehicle_id != network_vehicle_id:
        return
    _network_driver_peer = 0
    _network_has_transform = false
    visible = true

func _physics_process(delta: float) -> void:
    if _local_network_seat > 0:
        _follow_network_driver(delta)
        _sync_passenger_to_seat()
        _animate_vehicle(delta, _network_target_velocity.length())
        return

    if _network_driver_peer > 0 and _local_network_seat != 0:
        _follow_network_driver(delta)
        _animate_vehicle(delta, _network_target_velocity.length())
        return

    super._physics_process(delta)

func _apply_local_seat_change(new_seat: int) -> void:
    var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
    if player == null:
        _local_network_seat = new_seat
        return

    var previous := _local_network_seat
    if previous == new_seat:
        return

    if previous == 0:
        _release_driver_for_network_change(player)
    elif previous > 0:
        _release_passenger_for_network_change(player)

    _local_network_seat = new_seat

    if new_seat == 0:
        visible = true
        super.board(player)
        _local_network_seat = 0
        _notify("%s • CONDUCTEUR • 3 places coop maximum" % vehicle_name.to_upper())
    elif new_seat > 0:
        _board_passenger(player, new_seat)
        _notify("%s • PASSAGER %d • INTERAGIR pour descendre" % [vehicle_name.to_upper(), new_seat])
    elif previous >= 0:
        _place_player_after_network_exit(player)

func _board_passenger(player: CharacterBody3D, seat_index: int) -> void:
    _passenger_player = player
    _passenger_collision = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if _passenger_collision != null:
        _passenger_collision.set_deferred("disabled", true)
    player.set_physics_process(false)
    player.velocity = Vector3.ZERO
    if player.has_method("set_mounted_pose"):
        player.call("set_mounted_pose", style_key)
    _local_network_seat = seat_index
    _sync_passenger_to_seat()

func _release_driver_for_network_change(player: CharacterBody3D) -> void:
    if player.has_method("clear_mounted_pose"):
        player.call("clear_mounted_pose")
    if _driver_collision != null and is_instance_valid(_driver_collision):
        _driver_collision.set_deferred("disabled", false)
    player.set_physics_process(true)
    player.velocity = Vector3.ZERO
    remove_from_group("active_controller")
    _driver = null
    _driver_collision = null
    _virtual_move = Vector2.ZERO
    _current_speed = 0.0
    _snapshot_accumulator = 0.0

func _release_passenger_for_network_change(player: CharacterBody3D) -> void:
    if player.has_method("clear_mounted_pose"):
        player.call("clear_mounted_pose")
    if _passenger_collision != null and is_instance_valid(_passenger_collision):
        _passenger_collision.set_deferred("disabled", false)
    player.set_physics_process(true)
    player.velocity = Vector3.ZERO
    _passenger_player = null
    _passenger_collision = null

func _place_player_after_network_exit(player: CharacterBody3D) -> void:
    var landing := _find_safe_disembark_position()
    var target := global_position + global_transform.basis.x.normalized() * 3.2 + Vector3.UP * 1.05
    if bool(landing.get("found", false)):
        target = landing.get("position", target)
    player.global_position = target
    player.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
    player.velocity = Vector3.ZERO
    player.set_physics_process(true)
    GameState.set_exact_snapshot(player.global_position, player.global_rotation.y, false)
    GameState.quick_save()

func _sync_passenger_to_seat() -> void:
    if _passenger_player == null or not is_instance_valid(_passenger_player):
        return
    if _local_network_seat <= 0:
        return
    _passenger_player.global_position = global_transform * _passenger_seat_offset(_local_network_seat)
    _passenger_player.global_rotation = Vector3(0.0, global_rotation.y, 0.0)
    _passenger_player.velocity = Vector3.ZERO

func _passenger_seat_offset(seat_index: int) -> Vector3:
    var side := -1.0 if seat_index == 1 else 1.0
    match style_key:
        "4x4":
            return Vector3(side * 0.72, 1.92, 0.68)
        "horse":
            return _seat_offset()
        "quad":
            return _seat_offset()
        _:
            return Vector3(side * 0.68, 1.78, 0.62)

func _follow_network_driver(delta: float) -> void:
    if not _network_has_transform:
        return
    var anticipated := _network_target_position + _network_target_velocity * 0.045
    if global_position.distance_to(anticipated) > 15.0:
        global_position = anticipated
        global_rotation.y = _network_target_yaw
        return
    var follow := 1.0 - exp(-20.0 * delta)
    global_position = global_position.lerp(anticipated, follow)
    global_rotation.y = lerp_angle(global_rotation.y, _network_target_yaw, minf(1.0, delta * 18.0))
