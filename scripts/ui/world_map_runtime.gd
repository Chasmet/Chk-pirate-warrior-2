class_name WorldMapRuntime
extends CanvasLayer

const ArchipelagoMinimapScript = preload("res://scripts/ui/archipelago_minimap.gd")

var _root: Control
var _summary: Label
var _current_label: Label
var _map: Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 80
    _build()
    visible = false
    GameState.progression_changed.connect(_refresh)
    GameState.island_changed.connect(func(_id: int): _refresh())

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("open_map"):
        visible = not visible
        if visible:
            _refresh()

func _build() -> void:
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_root)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.006, 0.018, 0.028, 0.96)
    _root.add_child(shade)

    var title := Label.new()
    title.text = "CARTE DU GRAND ARCHIPEL"
    title.anchor_left = 0.18
    title.anchor_right = 0.82
    title.anchor_top = 0.035
    title.anchor_bottom = 0.105
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 31)
    title.add_theme_color_override("font_color", Color("f0cf72"))
    _root.add_child(title)

    _summary = Label.new()
    _summary.anchor_left = 0.15
    _summary.anchor_right = 0.85
    _summary.anchor_top = 0.105
    _summary.anchor_bottom = 0.165
    _summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _summary.add_theme_font_size_override("font_size", 18)
    _summary.add_theme_color_override("font_color", Color("d7e1e6"))
    _root.add_child(_summary)

    var map_panel := PanelContainer.new()
    map_panel.anchor_left = 0.10
    map_panel.anchor_right = 0.90
    map_panel.anchor_top = 0.19
    map_panel.anchor_bottom = 0.78
    var map_style := StyleBoxFlat.new()
    map_style.bg_color = Color(0.015, 0.055, 0.078, 0.96)
    map_style.border_color = Color("d8b45d")
    map_style.set_border_width_all(3)
    map_style.set_corner_radius_all(18)
    map_style.shadow_color = Color(0, 0, 0, 0.55)
    map_style.shadow_size = 8
    map_panel.add_theme_stylebox_override("panel", map_style)
    _root.add_child(map_panel)

    _map = ArchipelagoMinimapScript.new() as Control
    _map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
    map_panel.add_child(_map)

    _current_label = Label.new()
    _current_label.anchor_left = 0.16
    _current_label.anchor_right = 0.84
    _current_label.anchor_top = 0.80
    _current_label.anchor_bottom = 0.865
    _current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _current_label.add_theme_font_size_override("font_size", 19)
    _current_label.add_theme_color_override("font_color", Color("ffe49b"))
    _root.add_child(_current_label)

    var legend := Label.new()
    legend.text = "BLEU : position actuelle    •    VERT : royaume libéré    •    OR : royaume découvert    •    GRIS : à découvrir"
    legend.anchor_left = 0.12
    legend.anchor_right = 0.88
    legend.anchor_top = 0.865
    legend.anchor_bottom = 0.91
    legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    legend.add_theme_font_size_override("font_size", 14)
    legend.add_theme_color_override("font_color", Color(0.76, 0.80, 0.82, 1.0))
    _root.add_child(legend)

    var close := Button.new()
    close.text = "FERMER LA CARTE"
    close.anchor_left = 0.40
    close.anchor_right = 0.60
    close.anchor_top = 0.92
    close.anchor_bottom = 0.98
    close.add_theme_font_size_override("font_size", 18)
    close.focus_mode = Control.FOCUS_NONE
    var close_style := StyleBoxFlat.new()
    close_style.bg_color = Color(0.03, 0.09, 0.12, 0.96)
    close_style.border_color = Color("d8b45d")
    close_style.set_border_width_all(2)
    close_style.set_corner_radius_all(12)
    close.add_theme_stylebox_override("normal", close_style)
    close.pressed.connect(func(): visible = false)
    _root.add_child(close)

    _refresh()

func _refresh() -> void:
    if _summary == null:
        return
    _summary.text = "11 ROYAUMES • Boss majeurs %d/10 • Bateau niveau %d • %d pièces" % [
        GameState.defeated_main_boss_count(),
        GameState.boat_level,
        GameState.coins
    ]

    var current_index := clampi(GameState.current_island - 1, 0, WorldCatalog.island_count() - 1)
    var info := WorldCatalog.island(current_index)
    var state := "LIBÉRÉ" if GameState.is_boss_defeated(GameState.current_island) else "À CONQUÉRIR"
    _current_label.text = "POSITION : ÎLE %02d • %s • %s" % [GameState.current_island, str(info.get("name", "Île")), state]
    if _map != null:
        _map.queue_redraw()
