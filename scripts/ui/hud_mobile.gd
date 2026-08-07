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
var ability_1_button: Button
var ability_2_button: Button
var subtitle_timer: Timer

func _ready() -> void:
    add_to_group("hud")
    _build_hud()
    _connect_player.call_deferred()

func _build_hud() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var stats := _panel(Vector2(18, 16), Vector2(420, 150))
    root.add_child(stats)
    hero_label = _label("CHEIKH", 26)
    hero_label.position = Vector2(14, 8)
    stats.add_child(hero_label)
    level_label = _label("NIVEAU 1", 20)
    level_label.position = Vector2(305, 12)
    stats.add_child(level_label)
    health_bar = _stat_bar(stats, "VIE", 48, 165.0)
    energy_bar = _stat_bar(stats, "ÉNERGIE", 82, 100.0)
    aura_bar = _stat_bar(stats, "AURA", 116, 100.0)

    var mission := _panel(Vector2(505, 16), Vector2(660, 106))
    root.add_child(mission)
    mission_title = _label("PORT DES NAUFRAGES", 27)
    mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_title.position = Vector2(10, 8)
    mission_title.size = Vector2(640, 34)
    mission.add_child(mission_title)
    mission_text = _label("Élimine 8 ennemis pour faire apparaître le boss de l'île.", 18)
    mission_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mission_text.position = Vector2(10, 50)
    mission_text.size = Vector2(640, 42)
    mission.add_child(mission_text)

    root.add_child(_action_button("CARTE", "open_map", Vector2(1320, 18), Vector2(92, 56)))
    root.add_child(_action_button("SAUVEG.", "quick_save", Vector2(1420, 18), Vector2(110, 56)))
    root.add_child(_action_button("PAUSE", "pause_game", Vector2(1538, 18), Vector2(100, 56)))

    var map_panel := _panel(Vector2(1320, 82), Vector2(318, 178))
    root.add_child(map_panel)
    var map_title := _label("GRAND ARCHIPEL • NAVIGATION RÉELLE", 14)
    map_title.position = Vector2(12, 10)
    map_title.size = Vector2(290, 26)
    map_panel.add_child(map_title)
    var map_hint := _label("●──●──●──●\nPORT   ÎLES   MER   CIEL", 17)
    map_hint.position = Vector2(50, 62)
    map_hint.size = Vector2(230, 80)
    map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_panel.add_child(map_hint)

    var left_stick := _joystick_visual(Vector2(38, 760), 145.0, "DÉPLACEMENT")
    root.add_child(left_stick)
    var camera_stick := _joystick_visual(Vector2(255, 805), 110.0, "CAMÉRA 360°")
    root.add_child(camera_stick)

    root.add_child(_action_button("HÉROS", "open_inventory", Vector2(425, 900), Vector2(112, 90)))
    root.add_child(_action_button("EMBARQUER", "embark", Vector2(548, 900), Vector2(150, 90)))

    root.add_child(_action_button("ESQUIVE", "dodge", Vector2(1210, 900), Vector2(118, 90)))
    ability_1_button = _action_button("POUVOIR 1", "ability_1", Vector2(1338, 870), Vector2(126, 120))
    root.add_child(ability_1_button)
    ability_2_button = _action_button("POUVOIR 2", "ability_2", Vector2(1474, 846), Vector2(126, 144))
    root.add_child(ability_2_button)
    root.add_child(_action_button("ATTAQUE", "attack", Vector2(1610, 820), Vector2(130, 170)))

    subtitle_panel = _panel(Vector2(510, 790), Vector2(650, 74))
    subtitle_panel.visible = false
    root.add_child(subtitle_panel)
    subtitle_label = _label("", 22)
    subtitle_label.position = Vector2(15, 10)
    subtitle_label.size = Vector2(620, 54)
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle_panel.add_child(subtitle_label)

    subtitle_timer = Timer.new()
    subtitle_timer.one_shot = true
    subtitle_timer.timeout.connect(func(): subtitle_panel.visible = false)
    add_child(subtitle_timer)

    _refresh_hero_labels()

func _connect_player() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        return
    if player.has_signal("health_changed"):
        player.health_changed.connect(func(v, m): health_bar.max_value = m; health_bar.value = v)
    if player.has_signal("energy_changed"):
        player.energy_changed.connect(func(v, m): energy_bar.max_value = m; energy_bar.value = v)
    if player.has_signal("aura_changed"):
        player.aura_changed.connect(func(v): aura_bar.value = v)

func _refresh_hero_labels() -> void:
    var hero := GameState.get_hero_data()
    hero_label.text = str(hero.get("display_name", "HÉROS")).to_upper()
    var abilities: Array = hero.get("abilities", [])
    if abilities.size() > 0:
        ability_1_button.text = str(abilities[0].get("name", "POUVOIR 1")).to_upper()
    if abilities.size() > 1:
        ability_2_button.text = str(abilities[1].get("name", "POUVOIR 2")).to_upper()

func show_subtitle(text: String, seconds: float = 3.5) -> void:
    subtitle_label.text = text
    subtitle_panel.visible = true
    subtitle_timer.start(seconds)

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
    bar.size = Vector2(290, 24)
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

func _joystick_visual(pos: Vector2, diameter: float, caption: String) -> Control:
    var holder := Control.new()
    holder.position = pos
    holder.size = Vector2(diameter, diameter + 30)
    var outer := Panel.new()
    outer.position = Vector2.ZERO
    outer.size = Vector2(diameter, diameter)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.07, 0.09, 0.60)
    style.border_color = Color(0.85, 0.65, 0.25, 0.90)
    style.set_border_width_all(5)
    style.set_corner_radius_all(int(diameter / 2.0))
    outer.add_theme_stylebox_override("panel", style)
    holder.add_child(outer)
    var title := _label(caption, 15)
    title.position = Vector2(0, -26)
    title.size = Vector2(diameter, 24)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    holder.add_child(title)
    return holder
