class_name MainMenuRuntime
extends CanvasLayer

var _root: Control
var _hero_panel: PanelContainer
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
    panel.anchor_right = 0.34
    panel.anchor_top = 0.38
    panel.anchor_bottom = 0.86
    panel.add_theme_constant_override("separation", 16)
    _root.add_child(panel)

    var title := Label.new()
    title.text = "CHK PIRATE WARRIOR 2"
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color("f4d477"))
    panel.add_child(title)

    _add_menu_button(panel, "NOUVELLE AVENTURE", _new_game)
    _add_menu_button(panel, "CONTINUER", _continue_game)
    _add_menu_button(panel, "CHOISIR LE HÉROS", _toggle_hero_panel)

    _status = Label.new()
    _status.text = "11 royaumes • monde ouvert • navigation libre"
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.add_theme_font_size_override("font_size", 18)
    _status.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.9))
    panel.add_child(_status)

    _build_hero_panel()

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

func _add_hero_button(parent: Control, text_value: String, hero_id: String) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 64)
    button.add_theme_font_size_override("font_size", 20)
    button.pressed.connect(func():
        GameState.set_hero(hero_id)
        if _status != null:
            _status.text = "%s sélectionné." % text_value
    )
    parent.add_child(button)

func _toggle_hero_panel() -> void:
    _hero_panel.visible = not _hero_panel.visible

func _new_game() -> void:
    GameState.current_island = 1
    GameState.inventory.clear()
    _start_game()

func _continue_game() -> void:
    GameState.load_save()
    _start_game()

func _start_game() -> void:
    get_tree().paused = false
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(_root, "modulate:a", 0.0, 0.35)
    tween.tween_callback(queue_free)
