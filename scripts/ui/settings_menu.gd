extends CanvasLayer

var _panel: Control
var _trigger: Button
var _status: Label
var _download: Button
var _install: Button
var _check: Button
var _progress: ProgressBar
var _fps: Label
var _previous_pause := false
var _native: Object
var _clock := 0.0
var _last_snapshot := ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 160
    get_tree().auto_accept_quit = false
    if Engine.has_singleton("CHKUpdater"):
        _native = Engine.get_singleton("CHKUpdater")
    _build()
    if _native != null and bool(GameSettings.get_value("auto_updates")):
        get_tree().create_timer(2.0, true).timeout.connect(func(): _native.check())

func _build() -> void:
    _trigger = Button.new()
    _trigger.name = "OpenSettings"
    _trigger.text = "⚙"
    _trigger.add_theme_font_size_override("font_size", 27)
    _trigger.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
    _trigger.offset_left = -64
    _trigger.offset_right = -8
    _trigger.offset_top = -28
    _trigger.offset_bottom = 28
    _trigger.pressed.connect(open)
    add_child(_trigger)
    _fps = Label.new()
    _fps.position = Vector2(12, 6)
    _fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_fps)

    _panel = Control.new()
    _panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_panel)
    var dim := ColorRect.new()
    dim.color = Color(0.015, 0.03, 0.05, 0.95)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _panel.add_child(dim)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 32)
    margin.add_theme_constant_override("margin_right", 32)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    _panel.add_child(margin)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    margin.add_child(layout)
    var header := HBoxContainer.new()
    layout.add_child(header)
    var title := Label.new()
    title.text = "RÉGLAGES  ·  CHK PIRATE WARRIOR 2"
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", Color("f4d477"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close_button := _button("RETOUR", close)
    header.add_child(close_button)

    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.add_theme_font_size_override("font_size", 21)
    layout.add_child(tabs)
    var controls := _tab(tabs, "COMMANDES")
    _slider(controls, "Sensibilité caméra", "sensitivity", .35, 2, .05)
    _slider(controls, "Distance caméra", "camera_distance", .85, 1.7, .05)
    _toggle(controls, "Aide à la visée au corps à corps", "aim_assist")
    _toggle(controls, "Vibrations", "vibration")
    _text(controls, "Effleure le joystick pour marcher. Double enchaînement puis troisième coup renforcé en solo. Le saut peut être préparé juste avant de toucher le sol.\nPersonnalisation des touches et du HUD : bouton ÉDITER dans le jeu.")
    var audio := _tab(tabs, "SON")
    for pair in [["Musique", "music"], ["Voix des héros", "voice"], ["Effets", "sfx"], ["Ambiance", "ambience"]]:
        _slider(audio, pair[0], pair[1], 0, 1, .05)
    var graphics := _tab(tabs, "IMAGE")
    _choice(graphics, "Qualité", "quality", ["Économie", "Équilibrée", "Élevée"], [0, 1, 2])
    _choice(graphics, "Images par seconde", "fps", ["30 — batterie", "60 — fluidité"], [30, 60])
    _slider(graphics, "Champ de vision", "fov", 55, 85, 1)
    _toggle(graphics, "Afficher les FPS", "show_fps")
    _text(graphics, "Les réglages s'appliquent immédiatement. Le mode Économie réduit la résolution 3D, l'anticrénelage et les ombres.")
    var updates := _tab(tabs, "MISES À JOUR")
    _text(updates, "Version installée : " + str(ProjectSettings.get_setting("application/config/version", "12.0.0")))
    _toggle(updates, "Rechercher automatiquement au démarrage", "auto_updates")
    _status = _text(updates, "Vérification disponible." if _native != null else "Les mises à jour APK sont disponibles dans la version Android du jeu.")
    _progress = ProgressBar.new()
    _progress.custom_minimum_size.y = 28
    updates.add_child(_progress)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 12)
    updates.add_child(buttons)
    _check = _button("VÉRIFIER", func(): _native.check() if _native != null else null)
    _download = _button("TÉLÉCHARGER", func(): _native.download() if _native != null else null)
    _install = _button("INSTALLER", _install_update)
    for button in [_check, _download, _install]:
        buttons.add_child(button)
        button.disabled = true
    _check.disabled = _native == null
    _text(updates, "La progression, les quêtes et les touches personnalisées sont conservées. Android demande de valider l'installation. En cas de signature différente, le jeu bloque la mise à jour.")
    var footer := Label.new()
    footer.text = "Réglages sauvegardés automatiquement · Solo / Coop Wi-Fi"
    footer.add_theme_color_override("font_color", Color("a4b9c5"))
    layout.add_child(footer)
    _panel.hide()

func _tab(parent: TabContainer, label: String) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.name = label
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    parent.add_child(scroll)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 20)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    return content

func _text(parent: Control, value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 19)
    parent.add_child(label)
    return label

func _button(label: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size = Vector2(150, 52)
    button.add_theme_font_size_override("font_size", 18)
    button.pressed.connect(callback)
    return button

func _slider(parent: Control, label: String, key: String, minimum: float, maximum: float, step: float) -> void:
    var row := HBoxContainer.new()
    row.custom_minimum_size.y = 52
    parent.add_child(row)
    var title := _text(row, label)
    title.custom_minimum_size.x = 270
    var slider := HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = step
    slider.value = float(GameSettings.get_value(key))
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.custom_minimum_size = Vector2(200, 52)
    row.add_child(slider)
    var number := _text(row, "%.2f" % slider.value)
    number.custom_minimum_size.x = 70
    slider.value_changed.connect(func(value: float):
        number.text = "%.2f" % value
        GameSettings.set_value(key, value))

func _toggle(parent: Control, label: String, key: String) -> void:
    var check := CheckButton.new()
    check.text = label
    check.custom_minimum_size.y = 54
    check.add_theme_font_size_override("font_size", 20)
    check.button_pressed = bool(GameSettings.get_value(key))
    parent.add_child(check)
    check.toggled.connect(func(value: bool): GameSettings.set_value(key, value))

func _choice(parent: Control, label: String, key: String, titles: Array, values: Array) -> void:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var title := _text(row, label)
    title.custom_minimum_size.x = 270
    var option := OptionButton.new()
    option.custom_minimum_size.y = 54
    option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    option.add_theme_font_size_override("font_size", 20)
    for i in range(titles.size()):
        option.add_item(str(titles[i]))
    option.select(maxi(0, values.find(GameSettings.get_value(key))))
    row.add_child(option)
    option.item_selected.connect(func(index: int): GameSettings.set_value(key, values[index]))

func open() -> void:
    if _panel.visible:
        return
    _previous_pause = get_tree().paused
    _cancel_inputs()
    if not NetworkManager.is_multiplayer_active():
        get_tree().paused = true
    _panel.show()
    _trigger.hide()

func close() -> void:
    _panel.hide()
    _trigger.show()
    _cancel_inputs()
    get_tree().paused = _previous_pause

func is_open() -> bool:
    return _panel != null and _panel.visible

func _cancel_inputs() -> void:
    get_tree().call_group("gameplay_stability_v11_3", "_cancel_mobile_inputs")
    for action in ["attack", "jump", "dodge", "interact", "ability_1", "ability_2"]:
        Input.action_release(action)

func _process(delta: float) -> void:
    _clock += delta
    if _clock < .25:
        return
    _clock = 0
    _fps.visible = bool(GameSettings.get_value("show_fps")) and not _panel.visible
    if _fps.visible:
        _fps.text = "%d FPS" % Engine.get_frames_per_second()
    if _native == null:
        return
    var snapshot: String = _native.getSnapshot()
    if snapshot == _last_snapshot:
        return
    _last_snapshot = snapshot
    var data = JSON.parse_string(snapshot)
    if not data is Dictionary:
        return
    var state: String = str(data.get("state", "idle"))
    _status.text = str(data.get("message", ""))
    _progress.value = float(data.get("progress", 0))
    _check.disabled = state in ["checking", "downloading"]
    _download.disabled = state != "available"
    _install.disabled = state not in ["ready", "permission"]
    if state == "available":
        _trigger.text = "⚙ ↑"

func _install_update() -> void:
    if _native == null:
        return
    var menu := get_tree().root.find_child("MainMenu", true, false)
    if menu == null or not is_instance_valid(menu.get("_root")) or not menu.get("_root").visible:
        GameState.quick_save()
    _native.install()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel"):
        close() if is_open() else open()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        close() if is_open() else open()
    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
        _install_save_before_exit()
        get_tree().quit()

func _install_save_before_exit() -> void:
    var menu := get_tree().root.find_child("MainMenu", true, false)
    if menu == null or not is_instance_valid(menu.get("_root")) or not menu.get("_root").visible:
        GameState.quick_save()
