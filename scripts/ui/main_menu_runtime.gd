class_name MainMenuRuntime
extends CanvasLayer

var _root: Control
var _hero_panel: PanelContainer
var _difficulty_panel: Control
var _status: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    get_tree().paused = true
    _build_menu()

func _build_menu() -> void:
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_root)

    var background := TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var background_path := "res://assets/interface/menu_principal_chk_pirate_warrior_2.png"
    if ResourceLoader.exists(background_path):
        background.texture = load(background_path)
    background.modulate = Color(0.78, 0.78, 0.78, 1.0)
    _root.add_child(background)

    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0.015, 0.025, 0.04, 0.48)
    _root.add_child(veil)

    var logo := TextureRect.new()
    logo.anchor_left = 0.04
    logo.anchor_right = 0.36
    logo.anchor_top = 0.035
    logo.anchor_bottom = 0.34
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var logo_path := "res://assets/interface/logo_chk_pirate_warrior_2.png"
    if ResourceLoader.exists(logo_path):
        logo.texture = load(logo_path)
    _root.add_child(logo)

    var panel := VBoxContainer.new()
    panel.anchor_left = 0.06
    panel.anchor_right = 0.35
    panel.anchor_top = 0.36
    panel.anchor_bottom = 0.88
    panel.add_theme_constant_override("separation", 14)
    _root.add_child(panel)

    var title := Label.new()
    title.text = "CHK PIRATE WARRIOR 2"
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color("f4d477"))
    panel.add_child(title)

    _add_menu_button(panel, "NOUVELLE AVENTURE", _open_difficulty)
    _add_menu_button(panel, "CONTINUER", _continue_game)
    _add_menu_button(panel, "CHOISIR LE HÉROS", _toggle_hero_panel)

    _status = Label.new()
    _status.text = "11 royaumes • monde ouvert • navigation réelle • progression sauvegardée"
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.add_theme_font_size_override("font_size", 18)
    _status.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.9))
    panel.add_child(_status)

    _build_hero_panel()
    _build_difficulty_panel()

func _add_menu_button(parent: Control, text_value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0.0, 62.0)
    button.add_theme_font_size_override("font_size", 22)
    button.pressed.connect(callback)
    parent.add_child(button)

func _build_hero_panel() -> void:
    _hero_panel = PanelContainer.new()
    _hero_panel.anchor_left = 0.64
    _hero_panel.anchor_right = 0.95
    _hero_panel.anchor_top = 0.20
    _hero_panel.anchor_bottom = 0.78
    _hero_panel.visible = false
    _root.add_child(_hero_panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    _hero_panel.add_child(box)

    var label := Label.new()
    label.text = "CHOISIS TON HÉROS"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 28)
    box.add_child(label)

    _add_hero_button(box, "CHEIKH — Capitaine", "cheikh")
    _add_hero_button(box, "YVANE — Éclaireur", "yvane")
    _add_hero_button(box, "NELVYN — Combattant", "nelvyn")

    var close := Button.new()
    close.text = "FERMER"
    close.custom_minimum_size = Vector2(0, 52)
    close.pressed.connect(func(): _hero_panel.visible = false)
    box.add_child(close)

func _build_difficulty_panel() -> void:
    _difficulty_panel = Control.new()
    _difficulty_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _difficulty_panel.visible = false
    _difficulty_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(_difficulty_panel)

    var background := TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var art_path := "res://assets/interface/menu_choix difficulté_aventure_chk_pirate_warrior_2.png"
    if ResourceLoader.exists(art_path):
        background.texture = load(art_path)
    else:
        background.modulate = Color(0.08, 0.10, 0.14, 1.0)
    _difficulty_panel.add_child(background)

    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0.01, 0.02, 0.035, 0.36)
    _difficulty_panel.add_child(veil)

    var title := Label.new()
    title.text = "CHOISIS TON NIVEAU D’AVENTURE"
    title.anchor_left = 0.22
    title.anchor_right = 0.78
    title.anchor_top = 0.08
    title.anchor_bottom = 0.16
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color("f4d477"))
    _difficulty_panel.add_child(title)

    var choices := HBoxContainer.new()
    choices.anchor_left = 0.10
    choices.anchor_right = 0.90
    choices.anchor_top = 0.31
    choices.anchor_bottom = 0.72
    choices.add_theme_constant_override("separation", 22)
    _difficulty_panel.add_child(choices)

    _add_difficulty_card(choices, "DÉCOUVERTE", "Pour explorer librement. Ennemis moins résistants et dégâts réduits.", "decouverte")
    _add_difficulty_card(choices, "AVENTURE", "Équilibre recommandé : exploration, combats et progression normale.", "aventure")
    _add_difficulty_card(choices, "LÉGENDE", "Pour un défi plus dur : ennemis renforcés et combats plus exigeants.", "legende")

    var back := Button.new()
    back.text = "RETOUR"
    back.anchor_left = 0.42
    back.anchor_right = 0.58
    back.anchor_top = 0.82
    back.anchor_bottom = 0.89
    back.add_theme_font_size_override("font_size", 20)
    back.pressed.connect(func(): _difficulty_panel.visible = false)
    _difficulty_panel.add_child(back)

func _add_difficulty_card(parent: HBoxContainer, title_text: String, description: String, difficulty_id: String) -> void:
    var card := VBoxContainer.new()
    card.custom_minimum_size = Vector2(440, 0)
    card.add_theme_constant_override("separation", 14)
    parent.add_child(card)

    var label := Label.new()
    label.text = title_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 28)
    label.add_theme_color_override("font_color", Color("f1d37b"))
    card.add_child(label)

    var detail := Label.new()
    detail.text = description
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail.custom_minimum_size = Vector2(420, 120)
    detail.add_theme_font_size_override("font_size", 18)
    card.add_child(detail)

    var choose := Button.new()
    choose.text = "JOUER EN %s" % title_text
    choose.custom_minimum_size = Vector2(0, 70)
    choose.add_theme_font_size_override("font_size", 20)
    choose.pressed.connect(func(): _start_new_game(difficulty_id))
    card.add_child(choose)

func _add_hero_button(parent: Control, text_value: String, hero_id: String) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 64)
    button.add_theme_font_size_override("font_size", 20)
    button.pressed.connect(func():
        GameState.set_hero(hero_id)
        if _status != null:
            _status.text = "%s sélectionné pour la prochaine aventure." % text_value
    )
    parent.add_child(button)

func _toggle_hero_panel() -> void:
    _hero_panel.visible = not _hero_panel.visible

func _open_difficulty() -> void:
    _hero_panel.visible = false
    _difficulty_panel.visible = true

func _start_new_game(difficulty_id: String) -> void:
    GameState.new_game(GameState.selected_hero, difficulty_id)
    GameState.quick_save()
    _start_game()

func _continue_game() -> void:
    if not GameState.load_save():
        _status.text = "Aucune sauvegarde trouvée. Lance une nouvelle aventure."
        return
    _status.text = "Sauvegarde chargée • Île %02d • %s • %d/10 boss" % [GameState.current_island, GameState.difficulty_label(), GameState.defeated_main_boss_count()]
    _start_game()

func _start_game() -> void:
    get_tree().paused = false
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(_root, "modulate:a", 0.0, 0.35)
    tween.tween_callback(queue_free)
