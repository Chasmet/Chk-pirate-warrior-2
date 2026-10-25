class_name EndgameTrophyOverlayV11_8
extends "res://scripts/ui/endgame_trophy_overlay.gd"

func _build_interface() -> void:
    super._build_interface()
    # Le parent construit l'écran normal si l'image est disponible. Si le WebP
    # intégré est illisible ou absent sur un appareil, il s'arrête après avoir
    # créé un fond noir. Sans secours, la victoire pouvait alors mettre le jeu
    # en pause sur un écran noir sans bouton : soft-lock définitif de la fin.
    if _root == null or _frame == null or _trophy_material != null:
        return
    _build_fallback_endgame_ui()

func _build_fallback_endgame_ui() -> void:
    var panel := Panel.new()
    panel.name = "EndgameFallbackPanel"
    panel.anchor_left = 0.16
    panel.anchor_top = 0.18
    panel.anchor_right = 0.84
    panel.anchor_bottom = 0.82
    panel.mouse_filter = Control.MOUSE_FILTER_STOP

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.018, 0.012, 0.97)
    style.border_color = Color("e7b83f")
    style.set_border_width_all(4)
    style.set_corner_radius_all(22)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
    style.shadow_size = 14
    panel.add_theme_stylebox_override("panel", style)
    _root.add_child(panel)

    var title := Label.new()
    title.text = "VICTOIRE"
    title.anchor_left = 0.08
    title.anchor_right = 0.92
    title.anchor_top = 0.10
    title.anchor_bottom = 0.28
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color("ffd86a"))
    panel.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "MAÎTRE DES 11 ROYAUMES"
    subtitle.anchor_left = 0.08
    subtitle.anchor_right = 0.92
    subtitle.anchor_top = 0.30
    subtitle.anchor_bottom = 0.50
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 25)
    subtitle.add_theme_color_override("font_color", Color("f8e9bd"))
    panel.add_child(subtitle)

    var info := Label.new()
    info.text = "L'image du trophée n'a pas pu être chargée, mais ta victoire et ta progression sont intactes."
    info.anchor_left = 0.10
    info.anchor_right = 0.90
    info.anchor_top = 0.50
    info.anchor_bottom = 0.66
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 16)
    info.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88, 1.0))
    panel.add_child(info)

    var continue_button := _make_button("CONTINUE")
    continue_button.anchor_left = 0.08
    continue_button.anchor_right = 0.43
    continue_button.anchor_top = 0.74
    continue_button.anchor_bottom = 0.92
    continue_button.pressed.connect(_continue_game)
    panel.add_child(continue_button)

    var restart_button := _make_button("RECOMMENCER")
    restart_button.anchor_left = 0.57
    restart_button.anchor_right = 0.92
    restart_button.anchor_top = 0.74
    restart_button.anchor_bottom = 0.92
    restart_button.pressed.connect(_restart_game)
    panel.add_child(restart_button)
