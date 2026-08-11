extends CanvasLayer

var health_bar: ProgressBar
var energy_bar: ProgressBar
var aura_bar: ProgressBar
var hero_label: Label
var level_label: Label
var mission_title: Label
var mission_text: Label
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
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var stats := _panel(Vector2(18, 16), Vector2(440, 150))
    root.add_child(stats)
    hero_label = _label("CHEIKH", 26)
    hero_label.position = Vector2(14, 8)
    hero_label.size = Vector2(250, 32)
    stats.add_child(hero_label)
    level_label = _label("NV 1 • 250 PIÈCES", 17)
    level_label.position = Vector2(250, 12)
    level_label.size = Vector2(176, 28)
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    stats.add_child(level_label)
    health_bar = _stat_bar(stats, "VIE", 48, 165.0)
    energy_bar = _stat_bar(stats, "ÉNERGIE", 82, 100.0)
    aura_bar = _stat_bar(stats, "AURA", 116, 100.0)

    var mission := _panel(Vector2(510, 16), Vector2(680, 106))
    root.add_child(mission)
    mission_title = _label("PORT DES NAUFRAGES", 27)
    mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_title.position = Vector2(10, 8)
    mission_title.size = Vector2(660, 34)
    mission.add_child(mission_title)
    mission_text = _label("Sécurise le royaume pour faire apparaître son boss.", 18)
    mission_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mission_text.position = Vector2(10, 45)
    mission_text.size = Vector2(660, 52)
    mission.add_child(mission_text)

    root.add_child(_action_button("CARTE", "open_map", Vector2(1300, 18), Vector2(92, 56)))
    root.add_child(_action_button("SAC", "open_inventory", Vector2(1400, 18), Vector2(86, 56)))
    root.add_child(_action_button("SAUVEG.", "quick_save", Vector2(1494, 18), Vector2(110, 56)))
    root.add_child(_action_button("PAUSE", "pause_game", Vector2(1612, 18), Vector2(100, 56)))

    var map_panel := _panel(Vector2(1394, 86), Vector2(318, 150))
    root.add_child(map_panel)
    var map_title := _label("GRAND ARCHIPEL", 16)
    map_title.position = Vector2(12, 10)
    map_title.size = Vector2(294, 26)
    map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_panel.add_child(map_title)
    var map_hint := _label("11 ROYAUMES\nNavigation maritime réelle", 17)
    map_hint.position = Vector2(30, 50)
    map_hint.size = Vector2(258, 70)
    map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    map_panel.add_child(map_hint)

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

func _on_health_changed(value: float, maximum: float) -> void:
    health_bar.max_value = maximum
    health_bar.value = value

func _on_energy_changed(value: float, maximum: float) -> void:
    energy_bar.max_value = maximum
    energy_bar.value = value

func _on_aura_changed(value: float) -> void:
    aura_bar.value = value

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
    style.bg_color = Color(0.025, 0.055, 0.075, 0.88)
    style.border_color = Color(0.78, 0.59, 0.20, 0.95)
    style.set_border_width_all(2)
    style.set_corner_radius_all(16)
    panel.add_theme_stylebox_override("panel", style)
    return panel

func _label(text_value: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
    return label

func _stat_bar(parent: Control, caption: String, y: float, maximum: float) -> ProgressBar:
    var label := _label(caption, 16)
    label.position = Vector2(14, y)
    label.size = Vector2(86, 24)
    parent.add_child(label)
    var bar := ProgressBar.new()
    bar.position = Vector2(96, y)
    bar.size = Vector2(320, 24)
    bar.max_value = maximum
    bar.value = maximum
    bar.show_percentage = false
    parent.add_child(bar)
    return bar

func _action_button(text_value: String, action: String, pos: Vector2, button_size: Vector2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = button_size
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.add_theme_font_size_override("font_size", 17)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.06, 0.25, 0.34, 0.90)
    normal.border_color = Color(0.85, 0.64, 0.23)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(16)
    button.add_theme_stylebox_override("normal", normal)
    button.button_down.connect(func(): Input.action_press(action))
    button.button_up.connect(func(): Input.action_release(action))
    return button
