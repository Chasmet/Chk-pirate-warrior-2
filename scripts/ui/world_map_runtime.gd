class_name WorldMapRuntime
extends CanvasLayer

var _root: Control
var _list: VBoxContainer
var _summary: Label

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
    shade.color = Color(0.008, 0.025, 0.04, 0.94)
    _root.add_child(shade)

    var logo := TextureRect.new()
    logo.anchor_left = 0.025
    logo.anchor_right = 0.21
    logo.anchor_top = 0.025
    logo.anchor_bottom = 0.20
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var logo_path := "res://assets/interface/logo_chk_pirate_warrior_2.png"
    if ResourceLoader.exists(logo_path):
        logo.texture = load(logo_path)
    _root.add_child(logo)

    var title := Label.new()
    title.text = "CARTE DU GRAND ARCHIPEL — 11 ROYAUMES"
    title.anchor_left = 0.22
    title.anchor_right = 0.80
    title.anchor_top = 0.04
    title.anchor_bottom = 0.11
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color("f0cf72"))
    _root.add_child(title)

    _summary = Label.new()
    _summary.anchor_left = 0.22
    _summary.anchor_right = 0.80
    _summary.anchor_top = 0.115
    _summary.anchor_bottom = 0.18
    _summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _summary.add_theme_font_size_override("font_size", 20)
    _root.add_child(_summary)

    var scroll := ScrollContainer.new()
    scroll.anchor_left = 0.08
    scroll.anchor_right = 0.92
    scroll.anchor_top = 0.22
    scroll.anchor_bottom = 0.88
    _root.add_child(scroll)

    _list = VBoxContainer.new()
    _list.custom_minimum_size = Vector2(1500, 0)
    _list.add_theme_constant_override("separation", 10)
    scroll.add_child(_list)

    var close := Button.new()
    close.text = "FERMER LA CARTE"
    close.anchor_left = 0.40
    close.anchor_right = 0.60
    close.anchor_top = 0.91
    close.anchor_bottom = 0.975
    close.add_theme_font_size_override("font_size", 20)
    close.pressed.connect(func(): visible = false)
    _root.add_child(close)

    _refresh()

func _refresh() -> void:
    if _list == null:
        return
    for child in _list.get_children():
        child.queue_free()

    _summary.text = "Difficulté : %s  •  Boss majeurs : %d/10  •  Bateau niveau %d  •  %d pièces" % [
        GameState.difficulty_label(),
        GameState.defeated_main_boss_count(),
        GameState.boat_level,
        GameState.coins
    ]

    for index in range(WorldCatalog.island_count()):
        var island_id := index + 1
        var info := WorldCatalog.island(index)
        var row := PanelContainer.new()
        row.custom_minimum_size = Vector2(0, 72)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.04, 0.09, 0.12, 0.92)
        style.border_color = Color("d0a943") if island_id == GameState.current_island else Color(0.25, 0.34, 0.39, 0.9)
        style.set_border_width_all(2)
        style.set_corner_radius_all(12)
        row.add_theme_stylebox_override("panel", style)
        _list.add_child(row)

        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 24)
        row.add_child(line)

        var number := Label.new()
        number.text = "ÎLE %02d" % island_id
        number.custom_minimum_size = Vector2(115, 60)
        number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        number.add_theme_font_size_override("font_size", 19)
        number.add_theme_color_override("font_color", Color("f0cf72"))
        line.add_child(number)

        var name_label := Label.new()
        name_label.text = str(info["name"])
        name_label.custom_minimum_size = Vector2(470, 60)
        name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 21)
        line.add_child(name_label)

        var size: Vector2 = info["size"]
        var size_label := Label.new()
        size_label.text = "%d × %d m" % [roundi(size.x), roundi(size.y)]
        size_label.custom_minimum_size = Vector2(210, 60)
        size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        size_label.add_theme_font_size_override("font_size", 18)
        line.add_child(size_label)

        var state := Label.new()
        state.custom_minimum_size = Vector2(500, 60)
        state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        state.add_theme_font_size_override("font_size", 18)
        if island_id == 11 and not GameState.can_enter_island(11):
            state.text = "SCELLÉ • vaincs les 10 boss majeurs"
            state.add_theme_color_override("font_color", Color("e38a6d"))
        elif GameState.is_boss_defeated(island_id):
            state.text = "LIBÉRÉ • exploration libre"
            state.add_theme_color_override("font_color", Color("79d68c"))
        elif GameState.discovered_islands.has(island_id):
            state.text = "DÉCOUVERT • boss à vaincre"
            state.add_theme_color_override("font_color", Color("e6c16a"))
        else:
            state.text = "À DÉCOUVRIR PAR LA MER"
            state.add_theme_color_override("font_color", Color("9eb9c8"))
        line.add_child(state)
