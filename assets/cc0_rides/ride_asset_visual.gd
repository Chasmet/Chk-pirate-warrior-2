class_name RideAssetVisual
extends Node

const FOUR_BY_FOUR_PATH := "res://assets/cc0_rides/4x4_kenney.glb"
const HORSE_PATH := "res://assets/cc0_rides/horse_quaternius.glb"

var _vehicle: Node3D
var _style := ""
var _visual_root: Node3D
var _external_model: Node3D
var _animation_player: AnimationPlayer
var _animation_name := ""
var _external_wheels: Array[Node3D] = []

func _ready() -> void:
    set_process(false)
    call_deferred("_apply_upgrade")

func _apply_upgrade() -> void:
    _vehicle = get_parent() as Node3D
    if _vehicle == null:
        return

    _style = str(_vehicle.get("style_key"))
    var asset_path := ""
    match _style:
        "4x4": asset_path = FOUR_BY_FOUR_PATH
        "horse": asset_path = HORSE_PATH
        _: return

    if not ResourceLoader.exists(asset_path):
        return

    _visual_root = _find_procedural_visual_root()
    if _visual_root == null:
        await get_tree().process_frame
        _visual_root = _find_procedural_visual_root()
    if _visual_root == null:
        return

    var resource := ResourceLoader.load(asset_path)
    if not (resource is PackedScene):
        push_warning("Modèle CC0 non instanciable : %s" % asset_path)
        return

    var instance := (resource as PackedScene).instantiate()
    if not (instance is Node3D):
        if instance != null:
            instance.queue_free()
        push_warning("Modèle CC0 sans racine Node3D : %s" % asset_path)
        return

    _external_model = instance as Node3D
    _external_model.name = "ModeleCC0_%s" % _style
    _external_model.rotation.y = PI

    _hide_procedural_geometry(_visual_root)
    _visual_root.add_child(_external_model)

    if _style == "4x4":
        _fit_model_to_vehicle(_external_model, 2.20, 4.25, 0.08)
        _collect_external_wheels(_external_model)
    else:
        _fit_model_to_vehicle(_external_model, 2.48, 2.95, 0.04)
        _animation_player = _find_animation_player(_external_model)
        _update_horse_animation(0.0)

    set_process(true)

func _process(delta: float) -> void:
    if _vehicle == null or not is_instance_valid(_vehicle):
        set_process(false)
        return

    var speed := float(_vehicle.get("_current_speed"))
    if _style == "4x4":
        for wheel in _external_wheels:
            if is_instance_valid(wheel):
                wheel.rotation.x += speed * delta * 0.72
    elif _style == "horse":
        _update_horse_animation(speed)

func _find_procedural_visual_root() -> Node3D:
    if _vehicle == null:
        return null
    for child in _vehicle.get_children():
        if child is Node3D and str(child.name).begins_with("Carrosserie_"):
            return child as Node3D
    return null

func _hide_procedural_geometry(node: Node) -> void:
    for child in node.get_children():
        if child is Label3D:
            continue
        if child is GeometryInstance3D:
            var keep_saddle := _style == "horse" and str(child.name) in ["SelleCheval", "TapisSelle"]
            (child as GeometryInstance3D).visible = keep_saddle
        _hide_procedural_geometry(child)

func _fit_model_to_vehicle(model: Node3D, target_height: float, target_length: float, ground_y: float) -> void:
    var bounds := _calculate_model_bounds(model)
    if not bool(bounds.get("valid", false)):
        return

    var minimum: Vector3 = bounds["minimum"]
    var maximum: Vector3 = bounds["maximum"]
    var size := maximum - minimum
    var longest_horizontal := maxf(size.x, size.z)
    if size.y <= 0.001 or longest_horizontal <= 0.001:
        return

    var uniform_scale := minf(target_height / size.y, target_length / longest_horizontal)
    uniform_scale = clampf(uniform_scale, 0.02, 20.0)
    model.scale = Vector3.ONE * uniform_scale
    model.position.y = ground_y - minimum.y * uniform_scale

func _calculate_model_bounds(model: Node3D) -> Dictionary:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model, meshes)
    if meshes.is_empty():
        return {"valid": false}

    var minimum := Vector3(INF, INF, INF)
    var maximum := Vector3(-INF, -INF, -INF)
    var point_found := false

    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var aabb := mesh_instance.get_aabb()
        for index in range(8):
            var world_point := mesh_instance.to_global(aabb.get_endpoint(index))
            var model_point := model.to_local(world_point)
            minimum.x = minf(minimum.x, model_point.x)
            minimum.y = minf(minimum.y, model_point.y)
            minimum.z = minf(minimum.z, model_point.z)
            maximum.x = maxf(maximum.x, model_point.x)
            maximum.y = maxf(maximum.y, model_point.y)
            maximum.z = maxf(maximum.z, model_point.z)
            point_found = true

    return {
        "valid": point_found,
        "minimum": minimum,
        "maximum": maximum
    }

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _collect_external_wheels(node: Node) -> void:
    if node is Node3D:
        var lowered := str(node.name).to_lower()
        if lowered.begins_with("wheel"):
            _external_wheels.append(node as Node3D)
    for child in node.get_children():
        _collect_external_wheels(child)

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _update_horse_animation(speed: float) -> void:
    if _animation_player == null:
        return
    var maximum_speed := maxf(0.1, float(_vehicle.get("maximum_speed")))
    var ratio := clampf(absf(speed) / maximum_speed, 0.0, 1.0)
    if absf(speed) < 0.15:
        _play_best_animation(["idle", "stand", "breath"])
    elif ratio < 0.46:
        _play_best_animation(["walk", "walking", "trot"])
    else:
        _play_best_animation(["gallop", "run", "running", "trot", "walk"])

func _play_best_animation(keywords: Array[String]) -> void:
    if _animation_player == null:
        return
    var animations := _animation_player.get_animation_list()
    if animations.is_empty():
        return

    var selected: StringName = animations[0]
    var matched := false
    for keyword in keywords:
        for candidate in animations:
            if str(candidate).to_lower().contains(keyword):
                selected = candidate
                matched = true
                break
        if matched:
            break

    if str(selected) == _animation_name and _animation_player.is_playing():
        return
    _animation_name = str(selected)
    _animation_player.play(selected, 0.18)
