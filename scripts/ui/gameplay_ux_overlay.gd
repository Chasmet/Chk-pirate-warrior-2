class_name GameplayUXOverlay
extends CanvasLayer

var _root: Control
var _coin_panel: PanelContainer
var _coin_label: Label
var _nav_panel: PanelContainer
var _nav_label: Label
var _arrow: Polygon2D
var _feedback_label: Label
var _feedback_timer: Timer
var _player: Node3D
var _last_coins := -1
var _scan_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 27
    add_to_group("gameplay_ux")
    _build_ui()
    _last_coins = GameState.coins
    GameState.progression_changed.connect(_on_progression_changed)
    GameState.island_changed.connect(_on_island_changed)
    get_viewport().size_changed.connect(_layout)
    _layout.call_deferred()
    _refresh_wallet()
    _hide_legacy_sac_button.call_deferred()

func _process(delta: float) -> void:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D
    _scan_timer += delta
    if _scan_timer >= 0.10:
        _scan_timer = 0.0
        _update_navigation()
        _refresh_interact_label()

func _build_ui() -> void:
    _root = Control.new()
    _root.name = "GameplayUXRoot"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    _coin_panel = _make_panel()
    _coin_panel.name = "CoinCounterPanel"
    _coin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_coin_panel)
    _coin_label = _make_label("PIÈCES 0000", 18)
    _coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _coin_panel.add_child(_coin_label)

    _nav_panel = _make_panel()
    _nav_panel.name = "NavigationPanel"
    _nav_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_nav_panel)
    _nav_label = _make_label("OBJECTIF", 16)
    _nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _nav_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _nav_panel.add_child(_nav_label)

    _arrow = Polygon2D.new()
    _arrow.name = "NavigationArrow"
    _arrow.polygon = PackedVector2Array([
        Vector2(0.0, -25.0),
        Vector2(18.0, 17.0),
        Vector2(0.0, 10.0),
        Vector2(-18.0, 17.0)
    ])
    _arrow.color = Color("f4c95d")
    _root.add_child(_arrow)

    _feedback_label = _make_label("", 18)
    _feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _feedback_label.visible = false
    _root.add_child(_feedback_label)

    _feedback_timer = Timer.new()
    _feedback_timer.one_shot = true
    _feedback_timer.timeout.connect(func(): _feedback_label.visible = false)
    add_child(_feedback_timer)

func _layout() -> void:
    var size := get_viewport().get_visible_rect().size
    var w := size.x
    var h := size.y

    # Le compteur possède sa propre ligne sous la carte joueur.
    _coin_panel.position = Vector2(18.0, 174.0)
    _coin_panel.size = Vector2(188.0, 42.0)
    _coin_label.position = Vector2.ZERO
    _coin_label.size = _coin_panel.size

    # Le GPS se cale sous la mission réelle : il ne peut plus recouvrir le titre
    # « ÎLE xx • ... » ni venir se coller sur sa dernière ligne.
    var nav_w := minf(500.0, w * 0.42)
    var nav_x := (w - nav_w) * 0.5
    var nav_y := 136.0
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null:
        var mission_value = hud.get("mission_panel")
        if mission_value is Control:
            var mission := mission_value as Control
            nav_w = mission.size.x
            nav_x = mission.global_position.x
            nav_y = mission.global_position.y + mission.size.y + 8.0
    _nav_panel.position = Vector2(nav_x, nav_y)
    _nav_panel.size = Vector2(nav_w, 42.0)
    _nav_label.position = Vector2(42.0, 0.0)
    _nav_label.size = Vector2(nav_w - 50.0, 42.0)
    _arrow.position = Vector2(nav_x + 24.0, nav_y + 21.0)

    _feedback_label.position = Vector2((w - 420.0) * 0.5, nav_y + 48.0)
    _feedback_label.size = Vector2(420.0, 42.0)

func _on_progression_changed() -> void:
    var delta := GameState.coins - _last_coins
    if _last_coins >= 0 and delta != 0:
        if delta > 0:
            _show_feedback("+%d PIÈCES  •  SAC : %d" % [delta, GameState.coins])
        else:
            _show_feedback("%d PIÈCES  •  SAC : %d" % [delta, GameState.coins])
    _last_coins = GameState.coins
    _refresh_wallet()
    _inject_wallet_into_inventory.call_deferred()

func _on_island_changed(_island_id: int) -> void:
    _update_navigation.call_deferred()
    _layout.call_deferred()

func _refresh_wallet() -> void:
    if _coin_label != null:
        _coin_label.text = "PIÈCES  %d" % GameState.coins

func _show_feedback(text: String) -> void:
    _feedback_label.text = text
    _feedback_label.visible = true
    _feedback_timer.start(1.5)

func _toggle_bag() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("toggle_inventory"):
        hud.call("toggle_inventory")
        _inject_wallet_into_inventory.call_deferred()

func _inject_wallet_into_inventory() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud == null:
        return
    var inventory_text = hud.get("inventory_text")
    if inventory_text is RichTextLabel:
        var label := inventory_text as RichTextLabel
        var body := label.text
        var marker := "[b]PORTE-MONNAIE[/b]"
        if body.begins_with(marker):
            var split_index := body.find("\n\n")
            if split_index >= 0:
                body = body.substr(split_index + 2)
        label.text = "%s • %d PIÈCES\n\n%s" % [marker, GameState.coins, body]

func _hide_legacy_sac_button() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud == null:
        return
    var old := _find_button_by_text(hud, "SAC")
    if old != null:
        old.visible = false
        old.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _find_button_by_text(node: Node, text_value: String) -> Button:
    if node is Button and (node as Button).text == text_value:
        return node as Button
    for child in node.get_children():
        var result := _find_button_by_text(child, text_value)
        if result != null:
            return result
    return null

func _refresh_interact_label() -> void:
    var interact := get_tree().root.find_child("InteractButton", true, false)
    if interact == null or not interact.has_method("set_button_text"):
        return
    var active := get_tree().get_first_node_in_group("active_controller")
    if active is BoatController and (active as BoatController).is_boarded():
        interact.call("set_button_text", "DÉBARQUER")
        return
    if active != null:
        interact.call("set_button_text", "DESCENDRE")
        return
    if _player == null:
        interact.call("set_button_text", "INTERAGIR")
        return
    if _nearest_group_distance("island_vehicle") <= 8.0:
        interact.call("set_button_text", "CONDUIRE")
    elif _nearest_boat_distance() <= 13.0:
        interact.call("set_button_text", "EMBARQUER")
    else:
        interact.call("set_button_text", "INTERAGIR")

func _nearest_boat_distance() -> float:
    if _player == null:
        return INF
    var best := INF
    for node in get_tree().get_nodes_in_group("boat"):
        if node is Node3D and is_instance_valid(node):
            best = minf(best, _player.global_position.distance_to((node as Node3D).global_position))
    # Compatibilité : certains bateaux ne sont pas encore dans le groupe boat.
    var expected_name := "Bateau_%02d" % GameState.current_island
    var fallback := get_tree().root.find_child(expected_name, true, false)
    if fallback is Node3D:
        best = minf(best, _player.global_position.distance_to((fallback as Node3D).global_position))
    return best

func _nearest_group_distance(group_name: StringName) -> float:
    if _player == null:
        return INF
    var best := INF
    for node in get_tree().get_nodes_in_group(group_name):
        if node is Node3D and is_instance_valid(node):
            best = minf(best, _player.global_position.distance_to((node as Node3D).global_position))
    return best

func _update_navigation() -> void:
    if _player == null or not is_instance_valid(_player):
        _nav_panel.visible = false
        _arrow.visible = false
        return
    var target := _navigation_target()
    if target.is_empty():
        _nav_panel.visible = false
        _arrow.visible = false
        return

    var target_position: Vector3 = target["position"]
    var target_label := str(target["label"])
    var direction := target_position - _player.global_position
    direction.y = 0.0
    var distance := direction.length()
    if distance < 0.25:
        _nav_panel.visible = false
        _arrow.visible = false
        return

    _nav_panel.visible = true
    _arrow.visible = true
    _nav_label.text = "%s  •  %d m" % [target_label, roundi(distance)]

    var camera := get_viewport().get_camera_3d()
    if camera != null:
        var flat := direction.normalized()
        var right := camera.global_transform.basis.x.normalized()
        var forward := -camera.global_transform.basis.z.normalized()
        forward.y = 0.0
        right.y = 0.0
        forward = forward.normalized()
        right = right.normalized()
        var x := flat.dot(right)
        var z := flat.dot(forward)
        _arrow.rotation = atan2(x, z)

func _navigation_target() -> Dictionary:
    var island_id := clampi(GameState.current_island, 1, WorldCatalog.island_count())
    var index := island_id - 1
    var info := WorldCatalog.island(index)
    var positions := WorldCatalog.world_positions()
    var center: Vector3 = positions[index]
    var island_size: Vector2 = info["size"]

    var active := get_tree().get_first_node_in_group("active_controller")
    var sailing := active is BoatController and (active as BoatController).is_boarded()
    if sailing:
        var next_id := mini(island_id + 1, WorldCatalog.island_count())
        if island_id == WorldCatalog.island_count():
            next_id = island_id
        if next_id == 11 and not GameState.can_enter_island(11):
            next_id = 10
        var next_info := WorldCatalog.island(next_id - 1)
        return {
            "position": positions[next_id - 1],
            "label": "CAP SUR %s" % str(next_info["name"]).to_upper()
        }

    # Tant que le royaume n'est pas libéré, pointer vers l'ennemi vivant le plus proche.
    if not GameState.is_boss_defeated(island_id):
        var nearest_enemy: Node3D = null
        var best := INF
        for node in get_tree().get_nodes_in_group("enemy"):
            if node is Node3D and is_instance_valid(node):
                var d := _player.global_position.distance_to((node as Node3D).global_position)
                if d < best:
                    best = d
                    nearest_enemy = node as Node3D
        if nearest_enemy != null:
            var is_boss := bool(nearest_enemy.get("boss"))
            return {
                "position": nearest_enemy.global_position,
                "label": "BOSS" if is_boss else "FORCE LOCALE"
            }
        return {
            "position": center + Vector3(0.0, 0.0, -island_size.y * 0.18),
            "label": "OBJECTIF DU ROYAUME"
        }

    if island_id == 11 and not GameState.final_reward_collected:
        var trophy := get_tree().root.find_child("TropheeFinal", true, false)
        if trophy is Node3D:
            return {"position": (trophy as Node3D).global_position, "label": "TROPHÉE FINAL"}

    return {
        "position": center + Vector3(5.0, 0.0, island_size.y * 0.45 + 38.0),
        "label": "QUAI • REPRENDS LA MER"
    }

func _make_panel() -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.045, 0.065, 0.92)
    style.border_color = Color("d5a93d")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _make_label(value: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("f5e5b2"))
    label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    return label
