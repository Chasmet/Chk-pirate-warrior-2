class_name MainMenuRuntime
extends CanvasLayer

var _root: Control
var _hero_panel: PanelContainer
var _difficulty_panel: Control
var _multiplayer_panel: Control
var _multiplayer_status: Label
var _sessions_box: VBoxContainer
var _manual_ip: LineEdit
var _status: Label
var _found_servers: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100
    get_tree().paused = true
    _connect_network_signals()
    _build_menu()
    AudioDirector.play_menu_audio()

func _connect_network_signals() -> void:
    if not NetworkManager.session_discovered.is_connected(_on_session_discovered):
        NetworkManager.session_discovered.connect(_on_session_discovered)
    if not NetworkManager.connection_status_changed.is_connected(_on_network_status_changed):
        NetworkManager.connection_status_changed.connect(_on_network_status_changed)
    if not NetworkManager.lobby_changed.is_connected(_on_lobby_changed):
        NetworkManager.lobby_changed.connect(_on_lobby_changed)
    if not NetworkManager.game_start_received.is_connected(_on_network_game_started):
        NetworkManager.game_start_received.connect(_on_network_game_started)
    if not NetworkManager.session_closed.is_connected(_on_session_closed):
        NetworkManager.session_closed.connect(_on_session_closed)

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
    panel.anchor_right = 0.38
    panel.anchor_top = 0.33
    panel.anchor_bottom = 0.92
    panel.add_theme_constant_override("separation", 10)
    _root.add_child(panel)

    var title := Label.new()
    title.text = "CHK PIRATE WARRIOR 2"
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", Color("f4d477"))
    panel.add_child(title)

    _add_menu_button(panel, "NOUVELLE AVENTURE", _open_difficulty)
    _add_menu_button(panel, "CONTINUER", _continue_game)
    _add_menu_button(panel, "CHOISIR LE HÉROS", _toggle_hero_panel)
    _add_menu_button(panel, "COOP LOCALE WI-FI", _open_multiplayer_panel)

    _status = Label.new()
    _status.text = "11 royaumes • solo ou coop locale jusqu'à 3 joueurs • progression sauvegardée"
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.add_theme_font_size_override("font_size", 17)
    _status.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.9))
    panel.add_child(_status)

    _build_hero_panel()
    _build_difficulty_panel()
    _build_multiplayer_panel()

func _add_menu_button(parent: Control, text_value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0.0, 58.0)
    button.add_theme_font_size_override("font_size", 21)
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
    close.pressed.connect(_close_hero_panel)
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
    back.pressed.connect(_close_difficulty_panel)
    _difficulty_panel.add_child(back)

func _build_multiplayer_panel() -> void:
    _multiplayer_panel = Control.new()
    _multiplayer_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _multiplayer_panel.visible = false
    _multiplayer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(_multiplayer_panel)

    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0.01, 0.02, 0.04, 0.91)
    _multiplayer_panel.add_child(veil)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.20
    panel.anchor_right = 0.80
    panel.anchor_top = 0.07
    panel.anchor_bottom = 0.94
    _multiplayer_panel.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)

    var title := Label.new()
    title.text = "COOP LOCALE WI-FI — 3 JOUEURS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color("f4d477"))
    box.add_child(title)

    var explanation := Label.new()
    explanation.text = "Connectez les téléphones au même Wi-Fi. Un téléphone crée la partie, les deux autres la rejoignent. Choisis ton héros avant de rejoindre."
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    explanation.add_theme_font_size_override("font_size", 17)
    box.add_child(explanation)

    _multiplayer_status = Label.new()
    _multiplayer_status.text = "Recherche des parties disponibles…"
    _multiplayer_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _multiplayer_status.add_theme_font_size_override("font_size", 19)
    _multiplayer_status.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0))
    box.add_child(_multiplayer_status)

    var host := Button.new()
    host.text = "CRÉER LA PARTIE SUR CE TÉLÉPHONE"
    host.custom_minimum_size = Vector2(0, 62)
    host.add_theme_font_size_override("font_size", 20)
    host.pressed.connect(_host_local_game)
    box.add_child(host)

    var refresh := Button.new()
    refresh.text = "RECHERCHER LES PARTIES"
    refresh.custom_minimum_size = Vector2(0, 48)
    refresh.pressed.connect(_restart_scan)
    box.add_child(refresh)

    var sessions_title := Label.new()
    sessions_title.text = "PARTIES DÉTECTÉES"
    sessions_title.add_theme_font_size_override("font_size", 19)
    box.add_child(sessions_title)

    _sessions_box = VBoxContainer.new()
    _sessions_box.custom_minimum_size = Vector2(0, 150)
    _sessions_box.add_theme_constant_override("separation", 6)
    box.add_child(_sessions_box)

    var manual_row := HBoxContainer.new()
    manual_row.add_theme_constant_override("separation", 8)
    box.add_child(manual_row)

    _manual_ip = LineEdit.new()
    _manual_ip.placeholder_text = "Adresse IP de l'hôte, ex. 192.168.1.24"
    _manual_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _manual_ip.custom_minimum_size = Vector2(0, 50)
    manual_row.add_child(_manual_ip)

    var manual_join := Button.new()
    manual_join.text = "REJOINDRE IP"
    manual_join.custom_minimum_size = Vector2(180, 50)
    manual_join.pressed.connect(_join_manual_ip)
    manual_row.add_child(manual_join)

    var back := Button.new()
    back.text = "RETOUR"
    back.custom_minimum_size = Vector2(0, 52)
    back.pressed.connect(_close_multiplayer_panel)
    box.add_child(back)

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
    if _hero_panel.visible:
        AudioDirector.play_interface_audio()
    else:
        AudioDirector.play_menu_audio()

func _open_difficulty() -> void:
    _hero_panel.visible = false
    _multiplayer_panel.visible = false
    _difficulty_panel.visible = true
    AudioDirector.play_interface_audio()

func _open_multiplayer_panel() -> void:
    _hero_panel.visible = false
    _difficulty_panel.visible = false
    _multiplayer_panel.visible = true
    _found_servers.clear()
    _refresh_server_buttons()
    _restart_scan()
    AudioDirector.play_interface_audio()

func _close_hero_panel() -> void:
    _hero_panel.visible = false
    AudioDirector.play_menu_audio()

func _close_difficulty_panel() -> void:
    _difficulty_panel.visible = false
    AudioDirector.play_menu_audio()

func _close_multiplayer_panel() -> void:
    if NetworkManager.is_client():
        NetworkManager.disconnect_session("Connexion annulée.")
    elif not NetworkManager.is_host():
        NetworkManager.stop_discovery_scan()
    _multiplayer_panel.visible = false
    AudioDirector.play_menu_audio()

func _restart_scan() -> void:
    _found_servers.clear()
    _refresh_server_buttons()
    if _multiplayer_status != null:
        _multiplayer_status.text = "Recherche des parties sur le même Wi-Fi…"
    NetworkManager.start_discovery_scan()

func _on_session_discovered(info: Dictionary) -> void:
    var ip := str(info.get("ip", ""))
    if ip.is_empty():
        return
    _found_servers[ip] = info.duplicate(true)
    _refresh_server_buttons()

func _refresh_server_buttons() -> void:
    if _sessions_box == null:
        return
    for child in _sessions_box.get_children():
        child.queue_free()
    if _found_servers.is_empty():
        var empty := Label.new()
        empty.text = "Aucune partie détectée pour le moment."
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _sessions_box.add_child(empty)
        return
    for ip in _found_servers.keys():
        var info: Dictionary = _found_servers[ip]
        var button := Button.new()
        button.text = "%s  •  %d/%d joueurs  •  REJOINDRE" % [
            str(info.get("name", "Partie CHK")),
            int(info.get("players", 1)),
            int(info.get("max_players", 3))
        ]
        button.custom_minimum_size = Vector2(0, 48)
        button.pressed.connect(func(): _join_ip(str(ip)))
        _sessions_box.add_child(button)

func _host_local_game() -> void:
    var chosen_hero := GameState.selected_hero
    var err := NetworkManager.create_host(_local_player_name(), chosen_hero)
    if err != OK:
        return
    if GameState.has_save():
        GameState.load_save()
        GameState.set_hero(chosen_hero)
    else:
        GameState.new_game(chosen_hero, "aventure")
    GameState.quick_save()
    _restore_world_from_state()
    _status.text = "COOP WI-FI • hôte • les autres téléphones peuvent rejoindre maintenant"
    _start_game()

func _join_ip(ip: String) -> void:
    if _multiplayer_status != null:
        _multiplayer_status.text = "Connexion à %s…" % ip
    NetworkManager.join_host(ip, _local_player_name(), GameState.selected_hero)

func _join_manual_ip() -> void:
    if _manual_ip == null:
        return
    _join_ip(_manual_ip.text)

func _local_player_name() -> String:
    var hero := GameState.get_hero_data(GameState.selected_hero)
    return str(hero.get("display_name", GameState.selected_hero.capitalize()))

func _on_network_status_changed(text: String) -> void:
    if _multiplayer_status != null:
        _multiplayer_status.text = text

func _on_lobby_changed(players: Dictionary) -> void:
    if _multiplayer_status == null:
        return
    _multiplayer_status.text = "Joueurs connectés : %d/3" % players.size()

func _on_network_game_started() -> void:
    if not NetworkManager.is_client():
        return
    _restore_world_from_state()
    _status.text = "COOP WI-FI • connecté à la campagne de l'hôte"
    _start_game()

func _on_session_closed(reason: String) -> void:
    if _status != null:
        _status.text = reason

func _start_new_game(difficulty_id: String) -> void:
    NetworkManager.disconnect_session("")
    GameState.new_game(GameState.selected_hero, difficulty_id)
    GameState.quick_save()
    _restore_world_from_state()
    _start_game()

func _continue_game() -> void:
    NetworkManager.disconnect_session("")
    if not GameState.load_save():
        _status.text = "Aucune sauvegarde trouvée. Lance une nouvelle aventure."
        return
    _restore_world_from_state()
    _status.text = "Sauvegarde chargée • Île %02d • %s • %d/10 boss" % [GameState.current_island, GameState.difficulty_label(), GameState.defeated_main_boss_count()]
    _start_game()

func _restore_world_from_state() -> void:
    var world: Node = get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("restore_loaded_game"):
        world.call("restore_loaded_game")

func _start_game() -> void:
    if _root == null or not is_instance_valid(_root):
        return
    get_tree().paused = false
    AudioDirector.start_gameplay_audio()
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(_root, "modulate:a", 0.0, 0.35)
    tween.tween_callback(queue_free)
