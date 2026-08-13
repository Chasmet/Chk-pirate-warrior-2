class_name GameplayUXOverlayV11_2
extends "res://scripts/ui/gameplay_ux_overlay.gd"

var _mission_panel: PanelContainer
var _mission_label: Label
var _mission_arrow: Polygon2D
var _team_panel: PanelContainer
var _team_label: Label
var _team_arrow: Polygon2D

func _ready() -> void:
    super._ready()
    _nav_label.text = "ENNEMI"
    _arrow.color = Color("ff795f")
    _mission_panel = _make_panel()
    _mission_label = _make_label("MISSION", 15)
    _mission_panel.add_child(_mission_label)
    _root.add_child(_mission_panel)
    _mission_arrow = _make_direction_arrow(Color("63c9ff"))
    _root.add_child(_mission_arrow)

    _team_panel = _make_panel()
    _team_label = _make_label("ÉQUIPE", 15)
    _team_panel.add_child(_team_label)
    _root.add_child(_team_panel)
    _team_arrow = _make_direction_arrow(Color("75e38f"))
    _root.add_child(_team_arrow)
    _layout.call_deferred()

func _make_direction_arrow(color_value: Color) -> Polygon2D:
    var arrow := Polygon2D.new()
    arrow.polygon = PackedVector2Array([
        Vector2(0.0, -20.0), Vector2(14.0, 14.0),
        Vector2(0.0, 8.0), Vector2(-14.0, 14.0)
    ])
    arrow.color = color_value
    return arrow

func _layout() -> void:
    super._layout()
    if _mission_panel == null:
        return
    var nav_x := _nav_panel.position.x
    var nav_y := _nav_panel.position.y
    var nav_w := _nav_panel.size.x

    _mission_panel.position = Vector2(nav_x, nav_y + 48.0)
    _mission_panel.size = Vector2(nav_w, 40.0)
    _mission_label.position = Vector2(42.0, 0.0)
    _mission_label.size = Vector2(nav_w - 50.0, 40.0)
    _mission_arrow.position = Vector2(nav_x + 24.0, nav_y + 68.0)

    _team_panel.position = Vector2(nav_x, nav_y + 94.0)
    _team_panel.size = Vector2(nav_w, 40.0)
    _team_label.position = Vector2(42.0, 0.0)
    _team_label.size = Vector2(nav_w - 50.0, 40.0)
    _team_arrow.position = Vector2(nav_x + 24.0, nav_y + 114.0)

func _update_navigation() -> void:
    if _player == null or not is_instance_valid(_player):
        _set_indicator_visible(_nav_panel, _arrow, false)
        _set_indicator_visible(_mission_panel, _mission_arrow, false)
        _set_indicator_visible(_team_panel, _team_arrow, false)
        return

    _update_indicator(_nav_panel, _nav_label, _arrow, super._navigation_target(), "ENNEMI")

    var mission_target: Dictionary = {}
    var director := get_tree().get_first_node_in_group("island_collectibles")
    if director != null and director.has_method("navigation_target_v11_2"):
        var value = director.call("navigation_target_v11_2")
        if value is Dictionary:
            mission_target = value
    _update_indicator(_mission_panel, _mission_label, _mission_arrow, mission_target, "MISSION")

    _update_indicator(_team_panel, _team_label, _team_arrow, _nearest_teammate_target(), "ÉQUIPE")

func _update_indicator(panel: Control, label: Label, arrow: Polygon2D, target: Dictionary, prefix: String) -> void:
    if panel == null or label == null or arrow == null:
        return
    if target.is_empty() or _player == null:
        _set_indicator_visible(panel, arrow, false)
        return
    var target_position = target.get("position", Vector3.INF)
    if not target_position is Vector3 or target_position == Vector3.INF:
        _set_indicator_visible(panel, arrow, false)
        return

    var direction: Vector3 = target_position - _player.global_position
    direction.y = 0.0
    var distance := direction.length()
    if distance < 0.35:
        _set_indicator_visible(panel, arrow, false)
        return

    _set_indicator_visible(panel, arrow, true)
    label.text = "%s • %s • %d m" % [prefix, str(target.get("label", "OBJECTIF")), roundi(distance)]
    _rotate_arrow_to_direction(arrow, direction)

func _set_indicator_visible(panel: Control, arrow: Polygon2D, value: bool) -> void:
    if panel != null:
        panel.visible = value
    if arrow != null:
        arrow.visible = value

func _rotate_arrow_to_direction(arrow: Polygon2D, direction: Vector3) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera == null or direction.length_squared() < 0.001:
        return
    var flat := direction.normalized()
    var right := camera.global_transform.basis.x
    var forward := -camera.global_transform.basis.z
    right.y = 0.0
    forward.y = 0.0
    right = right.normalized()
    forward = forward.normalized()
    arrow.rotation = atan2(flat.dot(right), flat.dot(forward))

func _nearest_teammate_target() -> Dictionary:
    if not NetworkManager.is_multiplayer_active() or _player == null:
        return {}
    var best_node: Node3D = null
    var best_distance := INF
    var best_name := "COÉQUIPIER"
    for node in get_tree().root.find_children("RemotePlayer_*", "Node3D", true, false):
        if not node is Node3D or not is_instance_valid(node):
            continue
        var remote := node as Node3D
        var distance := _player.global_position.distance_to(remote.global_position)
        if distance < best_distance:
            best_distance = distance
            best_node = remote
            var display_value = remote.get("display_name")
            if display_value != null:
                best_name = str(display_value).to_upper()
    if best_node == null:
        return {}
    return {"position": best_node.global_position, "label": best_name}

func _refresh_interact_label() -> void:
    var interact := get_tree().root.find_child("InteractButton", true, false)
    var director := get_tree().get_first_node_in_group("island_collectibles")
    if interact != null and interact.has_method("set_button_text") and director != null and director.has_method("interaction_prompt_v11_2"):
        var value = director.call("interaction_prompt_v11_2")
        if value is Dictionary and not (value as Dictionary).is_empty():
            interact.call("set_button_text", str((value as Dictionary).get("label", "INTERAGIR")))
            return
    super._refresh_interact_label()

func show_network_notice(text: String) -> void:
    _show_feedback(text)
