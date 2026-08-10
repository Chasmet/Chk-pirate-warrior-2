class_name CombatHUDV130
extends CanvasLayer

const REFRESH_INTERVAL := 0.08
const ENEMY_TRACK_DISTANCE := 72.0
const BOSS_TRACK_DISTANCE := 150.0

var _player: CharacterBody3D
var _legacy_hud: CanvasLayer
var _enemy_panel: PanelContainer
var _enemy_name: Label
var _enemy_bar: ProgressBar
var _enemy_value: Label
var _refresh_accumulator := 0.0

func _ready() -> void:
    layer = 22
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("combat_hud_v1_30")
    _build_enemy_hud()
    _bind_existing_hud.call_deferred()

func _process(delta: float) -> void:
    if get_tree().paused:
        return
    _refresh_accumulator += delta
    if _refresh_accumulator < REFRESH_INTERVAL:
        return
    _refresh_accumulator = 0.0
    _refresh_player_bars()
    _refresh_enemy_bar()

func _bind_existing_hud() -> void:
    await get_tree().process_frame
    _legacy_hud = get_tree().get_first_node_in_group("hud") as CanvasLayer
    _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    _rename_energy_to_power(_legacy_hud)
    _refresh_player_bars()

func _rename_energy_to_power(node: Node) -> void:
    if node == null:
        return
    if node is Label and (node as Label).text == "ÉNERGIE":
        (node as Label).text = "POUVOIR"
    for child in node.get_children():
        _rename_energy_to_power(child)

func _refresh_player_bars() -> void:
    if _legacy_hud == null or not is_instance_valid(_legacy_hud):
        _legacy_hud = get_tree().get_first_node_in_group("hud") as CanvasLayer
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if _legacy_hud == null or _player == null:
        return

    var health_bar := _legacy_hud.get("health_bar") as ProgressBar
    var energy_bar := _legacy_hud.get("energy_bar") as ProgressBar
    var aura_bar := _legacy_hud.get("aura_bar") as ProgressBar

    if health_bar != null:
        var health := float(_player.get("health"))
        var maximum := maxf(1.0, float(_player.get("max_health")))
        health_bar.max_value = maximum
        health_bar.value = health
        _set_bar_fill(health_bar, _life_color(health / maximum))
    if energy_bar != null:
        var energy := float(_player.get("energy"))
        var max_energy := maxf(1.0, float(_player.get("max_energy")))
        energy_bar.max_value = max_energy
        energy_bar.value = energy
        _set_bar_fill(energy_bar, Color("34b8ff"))
    if aura_bar != null:
        _set_bar_fill(aura_bar, Color("dcae35"))

func _build_enemy_hud() -> void:
    var root := Control.new()
    root.name = "CombatHUDRootV130"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    _enemy_panel = PanelContainer.new()
    _enemy_panel.name = "EnemyHealthPanel"
    _enemy_panel.position = Vector2(0.0, 138.0)
    _enemy_panel.size = Vector2(560.0, 84.0)
    _enemy_panel.visible = false
    _enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.012, 0.022, 0.030, 0.90)
    panel_style.border_color = Color("d7b34a")
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(12)
    panel_style.content_margin_left = 14.0
    panel_style.content_margin_right = 14.0
    panel_style.content_margin_top = 7.0
    panel_style.content_margin_bottom = 9.0
    _enemy_panel.add_theme_stylebox_override("panel", panel_style)
    root.add_child(_enemy_panel)

    var column := VBoxContainer.new()
    column.name = "EnemyHealthContent"
    column.custom_minimum_size = Vector2(532.0, 66.0)
    column.add_theme_constant_override("separation", 5)
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _enemy_panel.add_child(column)

    _enemy_name = Label.new()
    _enemy_name.custom_minimum_size = Vector2(0.0, 27.0)
    _enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _enemy_name.add_theme_font_size_override("font_size", 18)
    _enemy_name.add_theme_color_override("font_color", Color("fff1bc"))
    _enemy_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
    _enemy_name.add_theme_constant_override("shadow_offset_x", 2)
    _enemy_name.add_theme_constant_override("shadow_offset_y", 2)
    column.add_child(_enemy_name)

    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0.0, 25.0)
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(row)

    _enemy_bar = ProgressBar.new()
    _enemy_bar.custom_minimum_size = Vector2(350.0, 23.0)
    _enemy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _enemy_bar.show_percentage = false
    _enemy_bar.max_value = 100.0
    _enemy_bar.value = 100.0
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.015, 0.02, 0.025, 0.98)
    bg.border_color = Color(0.42, 0.42, 0.40, 0.95)
    bg.set_border_width_all(1)
    bg.set_corner_radius_all(8)
    _enemy_bar.add_theme_stylebox_override("background", bg)
    row.add_child(_enemy_bar)

    _enemy_value = Label.new()
    _enemy_value.custom_minimum_size = Vector2(90.0, 24.0)
    _enemy_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _enemy_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _enemy_value.add_theme_font_size_override("font_size", 14)
    _enemy_value.add_theme_color_override("font_color", Color("f5ead0"))
    row.add_child(_enemy_value)

    get_viewport().size_changed.connect(_layout_enemy_panel)
    _layout_enemy_panel.call_deferred()

func _layout_enemy_panel() -> void:
    if _enemy_panel == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var width := clampf(viewport_size.x * 0.36, 430.0, 590.0)
    _enemy_panel.size = Vector2(width, 84.0)
    _enemy_panel.position.x = (viewport_size.x - width) * 0.5

func _refresh_enemy_bar() -> void:
    if _enemy_panel == null:
        return
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if _player == null:
        _enemy_panel.visible = false
        return

    var target: Node3D
    var best_score := INF
    for node in get_tree().get_nodes_in_group("enemy"):
        if not (node is Node3D) or not is_instance_valid(node):
            continue
        var enemy := node as Node3D
        var distance := _player.global_position.distance_to(enemy.global_position)
        var is_boss := bool(enemy.get("boss"))
        var max_distance := BOSS_TRACK_DISTANCE if is_boss else ENEMY_TRACK_DISTANCE
        if distance > max_distance:
            continue
        var score := distance - (75.0 if is_boss else 0.0)
        if score < best_score:
            best_score = score
            target = enemy

    if target == null:
        _enemy_panel.visible = false
        return

    var health := float(target.get("health"))
    var maximum := maxf(1.0, float(target.get("max_health")))
    var ratio := clampf(health / maximum, 0.0, 1.0)
    var display_name := str(target.get("display_name"))
    if display_name.is_empty():
        display_name = "ENNEMI"
    var prefix := "GRAND BOSS" if bool(target.get("boss")) else _enemy_rank_prefix(display_name)
    _enemy_name.text = "%s • %s" % [prefix, display_name.to_upper()]
    _enemy_bar.max_value = maximum
    _enemy_bar.value = health
    _set_bar_fill(_enemy_bar, _life_color(ratio))
    _enemy_value.text = "%d / %d" % [roundi(health), roundi(maximum)]
    _enemy_panel.visible = true

func _enemy_rank_prefix(display_name: String) -> String:
    var lower := display_name.to_lower()
    if lower.contains("commandant 1"):
        return "COMMANDANT 1"
    if lower.contains("commandant 2"):
        return "COMMANDANT 2"
    return "ENNEMI"

func _life_color(ratio: float) -> Color:
    # Règle demandée : vert quand les PV sont confortables, jaune autour de la
    # moitié, rouge lorsque la vie devient critique.
    if ratio > 0.55:
        return Color("39c66b")
    if ratio > 0.25:
        return Color("f0c53d")
    return Color("e34842")

func _set_bar_fill(bar: ProgressBar, color: Color) -> void:
    if bar == null:
        return
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.set_corner_radius_all(8)
    bar.add_theme_stylebox_override("fill", fill)
