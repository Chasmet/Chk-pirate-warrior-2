extends "res://scripts/player/hero_controller_v11_4.gd"

var _queued_attack_until := 0
var _combo_until := 0
var _combo_step := 0
var _doing_basic := false

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if _queued_attack_until > 0 and _attack_lock <= 0.0:
        var valid := Time.get_ticks_msec() <= _queued_attack_until
        _queued_attack_until = 0
        if valid:
            basic_attack()

func basic_attack() -> void:
    if get_tree().paused or get_node("/root/SettingsMenu").is_open() or _respawn_in_progress or _mount_pose_active:
        return
    if _attack_lock > 0.0:
        # One pending hit only: touch spam cannot multiply damage or effects.
        _queued_attack_until = Time.get_ticks_msec() + 550
        return
    _queued_attack_until = 0
    var now := Time.get_ticks_msec()
    _combo_step = (_combo_step % 3) + 1 if now < _combo_until else 1
    _combo_until = now + 1250
    if bool(GameSettings.get_value("aim_assist")):
        _face_near_enemy()
    _doing_basic = true
    super.basic_attack()
    _doing_basic = false
    GameSettings.vibrate(14 if _combo_step < 3 else 28)

func use_ability(index: int) -> bool:
    if get_tree().paused or get_node("/root/SettingsMenu").is_open() or _attack_lock > 0.0 or _respawn_in_progress or _mount_pose_active:
        return false
    _queued_attack_until = 0
    return super.use_ability(index)

func _face_near_enemy() -> void:
    var closest: Node3D
    var best := 16.0
    for candidate in get_tree().get_nodes_in_group("enemy"):
        if not candidate is Node3D or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
            continue
        var offset: Vector3 = candidate.global_position - global_position
        if absf(offset.y) > 2.5:
            continue
        var distance := offset.length_squared()
        if distance < best:
            var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, candidate.global_position + Vector3.UP, 1, [get_rid()])
            var hit := get_world_3d().direct_space_state.intersect_ray(query)
            if not hit.is_empty() and hit.get("collider") != candidate:
                continue
            best = distance
            closest = candidate
    if closest != null:
        var direction := closest.global_position - global_position
        rotation.y = atan2(-direction.x, -direction.z)

func _damage_enemies(radius: float, damage: float) -> void:
    # Combo is feedback only in coop, where the host owns damage calculation.
    var multiplier := 1.25 if _doing_basic and _combo_step == 3 and not NetworkManager.is_multiplayer_active() else 1.0
    super._damage_enemies(radius, damage * multiplier)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PAUSED:
        _queued_attack_until = 0
        _virtual_move = Vector2.ZERO
