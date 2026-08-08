extends CanvasLayer

const ArchipelagoMinimapScript = preload("res://scripts/ui/archipelago_minimap.gd")

var health_bar: ProgressBar
var energy_bar: ProgressBar
var aura_bar: ProgressBar
var health_value_label: Label
var energy_value_label: Label
var aura_value_label: Label
var hero_label: Label
var level_label: Label
var mission_title: Label
var mission_text: Label
var stats_panel: PanelContainer
var mission_panel: PanelContainer
var map_panel: PanelContainer
var subtitle_panel: PanelContainer
var subtitle_label: Label
var subtitle_timer: Timer
var inventory_panel: PanelContainer
var inventory_text: RichTextLabel

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("hud")
    _build_hud()
    GameState.hero_changed.connect(_on_hero_changed)
    GameState.inventory_changed.connect(_on_inventory_changed)
    GameState.progression_changed.connect(_on_progression_changed)
    _connect_player.call_deferred()

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("open_inventory"):
        toggle_inventory()
    if Input.is_action_just_pressed("pause_game"):
        get_tree().paused = not get_tree().paused
        show_subtitle("Jeu en pause" if get_tree().paused else "Reprise", 1.2)

func _build_hud() -> void:
    var root := Control.new()
    root.name = "HUDRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    stats_panel = _panel(Vector2(18, 16), Vector2(440, 150))
    stats_panel.name = "StatsPanel"
    root.add_child(stats_panel)
    hero_label = _label("CHEIKH", 26)
    hero_label.position = Vector2(14, 8)
    hero_label.size = Vector2(250, 32)
    stats_panel.add_child(hero_label)
    level_label = _label("NV 1 • 250 PIÈCES", 17)
    level_label.position = Vector2(250, 12)
    level_label.size = Vector2(176, 28)
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    stats_panel.add_child(level_label)
    health_bar = _stat_bar(stats_panel, "VIE", 48, 165.0, Color("d84b45"))
    energy_bar = _stat_bar(stats_panel, "ÉNERGIE", 82, 100.0, Color("3fa9e8"))
    aura_bar = _stat_bar(stats_panel, "AURA", 116, 100.0, Color("d5a62e"))

    health_value_label = _value_label(stats_panel, 48, "165 / 165")
    energy_value_label = _value_label(stats_panel, 82, "100 / 100")
    aura_value_label = _value_label(stats_panel, 116, "100 %")

    mission_panel = _panel(Vector2(510, 16), Vector2(680, 106))
    mission_panel.name = "MissionPanel"
    root.add_child(mission_panel)
    mission_title = _label("PORT DES NAUFRAGES", 27)
    mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_title.position = Vector2(10, 8)
    mission_title.size = Vector2(660, 34)
    mission_panel.add_child(mission_title)
    mission_text = _label("Sécurise le royaume pour faire apparaître son boss.", 18)
    mission_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mission_text.position = Vector2(10, 45)
    mission_text.size = Vector2(660, 52)
    mission_panel.add_child(mission_text)

    root.add_child(_action_button("CARTE", "open_map", Vector2(1300, 18), Vector2(92, 56)))
    root.add_child(_action_button("SAC", "open_inventory", Vector2(1400, 18), Vector2(86, 56)))
    root.add_child(_action_button("SAUVEG.", "quick_save", Vector2(1494, 18), Vector2(110, 56)))
    root.add_child(_action_button("PAUSE", "pause_game", Vector2(1612, 18), Vector2(100, 56)))

    map_panel = _panel(Vector2(1394, 86), Vector2(360, 220))
    map_panel.name = "ArchipelagoMapPanel"
    map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(map_panel)
    var map_title := _label("GRAND ARCHIPEL • 11 ROYAUMES", 15)
    map_title.name = "ArchipelagoMapTitle"
    map_title.position = Vector2(10, 8)
    map_title.size = Vector2(340, 24)
    map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_panel.add_child(map_title)
    var minimap := ArchipelagoMinimapScript.new() as Control
    minimap.name = "ArchipelagoMinimap"
    minimap.position = Vector2(8, 32)
    minimap.size = Vector2(344, 180)
    map_panel.add_child(minimap)

    subtitle_panel = _panel(Vector2(520, 820), Vector2(670, 74))
    subtitle_panel.visible = false
    root.add_child(subtitle_panel)
    subtitle_label = _label("", 22)
    subtitle_label.position = Vector2(15, 10)
    subtitle_label.size = Vector2(640, 54)
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle_panel.add_child(subtitle_label)

    inventory_panel = _panel(Vector2(650, 210), Vector2(620, 560))
    inventory_panel.visible = false
    inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(inventory_panel)
    var inventory_title := _label("SAC À DOS", 30)
    inventory_title.position = Vector2(24, 20)
    inventory_title.size = Vector2(450, 45)
    inventory_panel.add_child(inventory_title)
    var close_button := Button.new()
    close_button.text = "FERMER"
    close_button.position = Vector2(485, 18)
    close_button.size = Vector2(110, 48)
    close_button.pressed.connect(toggle_inventory)
    inventory_panel.add_child(close_button)
    inventory_text = RichTextLabel.new()
    inventory_text.position = Vector2(24, 80)
    inventory_text.size = Vector2(570, 450)
    inventory_text.bbcode_enabled = true
    inventory_text.fit_content = false
    inventory_text.add_theme_font_size_override("normal_font_size", 22)
    inventory_panel.add_child(inventory_text)

    subtitle_timer = Timer.new()
    subtitle_timer.one_shot = true
    subtitle_timer.timeout.connect(_hide_subtitle)
    add_child(subtitle_timer)

    _refresh_progression_labels()
    _refresh_inventory()

func _connect_player() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        return
    if player.has_signal("health_changed"):
        player.health_changed.connect(_on_health_changed)
    if player.has_signal("energy_changed"):
        player.energy_changed.connect(_on_energy_changed)
    if player.has_signal("aura_changed"):
        player.aura_changed.connect(_on_aura_changed)
    if player.get("health") != null and player.get("max_health") != null:
        _on_health_changed(float(player.get("health")), float(player.get("max_health")))
    if player.get("energy") != null and player.get("max_energy") != null:
        _on_energy_changed(float(player.get("energy")), float(player.get("max_energy")))
    if player.get("aura") != null:
        _on_aura_changed(float(player.get("aura")))

func _on_health_changed(value: float, maximum: float) -> void:
    health_bar.max_value = maximum
    health_bar.value = value
    if health_value_label != null:
        health_value_label.text = "%d / %d" % [roundi(value), roundi(maximum)]

func _on_energy_changed(value: float, maximum: float) -> void:
    energy_bar.max_value = maximum
    energy_bar.value = value
    if energy_value_label != null:
        energy_value_label.text = "%d / %d" % [roundi(value), roundi(maximum)]

func _on_aura_changed(value: float) -> void:
    aura_bar.value = value
    if aura_value_label != null:
        aura_value_label.text = "%d %%" % roundi(value)

func _on_hero_changed(_hero_id: String) -> void:
    _refresh_progression_labels()
    _refresh_inventory()
    show_subtitle("Héros contrôlé : %s" % GameState.get_hero_data().get("display_name", "Héros"), 1.8)

func _on_inventory_changed(_items: Dictionary) -> void:
    _refresh_inventory()

func _on_progression_changed() -> void:
    _refresh_progression_labels()

func _refresh_progression_labels() -> void:
    if hero_label == null or level_label == null:
        return
    var hero := GameState.get_hero_data()
    hero_label.text = str(hero.get("display_name", "HÉROS")).to_upper()
    level_label.text = "NV %d • %d PIÈCES" % [GameState.level, GameState.coins]

func toggle_inventory() -> void:
    inventory_panel.visible = not inventory_panel.visible
    if inventory_panel.visible:
        _refresh_inventory()

func _refresh_inventory() -> void:
    if inventory_text == null:
        return
    var hero := GameState.get_hero_data()
    var lines := PackedStringArray()
    lines.append("[b]%s[/b] — capacité : %d emplacements" % [hero.get("display_name", "Héros"), GameState.max_slots])
    lines.append("")
    if GameState.inventory.is_empty():
        lines.append("Le sac est vide.")
    else:
        for item_id in GameState.inventory.keys():
            lines.append("• %s × %d" % [str(item_id).replace("_", " ").capitalize(), int(GameState.inventory[item_id])])
    lines.append("")
    lines.append("Bateau niveau %d/5 • Difficulté : %s" % [GameState.boat_level, GameState.difficulty_label()])
    inventory_text.text = "\n".join(lines)

func show_subtitle(text: String, seconds: float = 3.5) -> void:
    subtitle_label.text = text
    subtitle_panel.visible = true
    subtitle_timer.start(seconds)

func _hide_subtitle() -> void:
    subtitle_panel.visible = false

func set_mission(title: String, description: String) -> void:
    mission_title.text = title.to_upper()
    mission_text.text = description

func _panel(pos: Vector2, panel_size: Vector2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.position = pos
    panel.size = panel_size
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.045, 0.065, 0.91)
    style.border_color = Color(0.82, 0.63, 0.24, 0.98)
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
    style.shadow_size = 5
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _label(text_value: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.78))
    label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    return label

func _stat_bar(parent: Control, caption: String, y: float, maximum: float, fill_color: Color) -> ProgressBar:
    var label := _label(caption, 15)
    label.position = Vector2(14, y)
    label.size = Vector2(82, 24)
    parent.add_child(label)

    var bar := ProgressBar.new()
    bar.position = Vector2(94, y + 2)
    bar.size = Vector2(218, 20)
    bar.max_value = maximum
    bar.value = maximum
    bar.show_percentage = false

    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.01, 0.025, 0.035, 0.95)
    background.border_color = Color(0.42, 0.43, 0.40, 0.85)
    background.set_border_width_all(1)
    background.set_corner_radius_all(8)
    bar.add_theme_stylebox_override("background", background)

    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(8)
    bar.add_theme_stylebox_override("fill", fill)
    parent.add_child(bar)
    return bar

func _value_label(parent: Control, y: float, text_value: String) -> Label:
    var value := _label(text_value, 14)
    value.position = Vector2(316, y)
    value.size = Vector2(108, 24)
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    parent.add_child(value)
    return value

func _action_button(text_value: String, action: String, pos: Vector2, button_size: Vector2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = button_size
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 16)
    button.add_theme_color_override("font_color", Color("f5e1a2"))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.025, 0.085, 0.115, 0.94)
    normal.border_color = Color(0.86, 0.66, 0.25)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(13)
    button.add_theme_stylebox_override("normal", normal)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.22, 0.15, 0.035, 0.98)
    pressed.border_color = Color("ffe49b")
    button.add_theme_stylebox_override("pressed", pressed)
    button.button_down.connect(func(): Input.action_press(action))
    button.button_up.connect(func(): Input.action_release(action))
    return button
