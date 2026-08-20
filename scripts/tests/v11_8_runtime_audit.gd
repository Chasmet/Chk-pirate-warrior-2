extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if condition:
        print("AUDIT V11.8 OK • ", message)
    else:
        _failures.append(message)
        push_error("AUDIT V11.8 ÉCHEC • " + message)

func _run() -> void:
    GameState.new_game("cheikh", "aventure")
    var packed := load("res://scenes/main/main.tscn") as PackedScene
    _check(packed != null, "scène principale chargeable")
    if packed == null:
        _finish()
        return

    var main := packed.instantiate()
    root.add_child(main)
    for _i in range(4):
        await process_frame

    _audit_core_nodes()
    await _audit_menu_layout()

    # Le menu met volontairement SceneTree.paused=true. Les audits de gameplay
    # doivent ensuite tester leur propre état et non hériter de cette pause.
    var menu := root.find_child("MainMenu", true, false)
    if menu != null:
        menu.queue_free()
    await process_frame
    paused = false

    await _audit_hud_layout()
    await _audit_touch_controls()
    await _audit_endgame_overlay()

    if is_instance_valid(main):
        main.queue_free()
    await process_frame
    _finish()

func _audit_core_nodes() -> void:
    _check(get_first_node_in_group("player") != null, "joueur principal présent")
    _check(get_first_node_in_group("world_director") != null, "directeur du monde présent")
    _check(get_first_node_in_group("hud") != null, "HUD principal présent")
    _check(get_first_node_in_group("gameplay_ux") != null, "overlay gameplay présent")
    _check(root.find_child("MobileInputOverlay", true, false) != null, "overlay tactile présent")
    _check(root.find_child("EndgameTrophyOverlay", true, false) != null, "overlay de fin présent")
    _check(AudioServer.get_bus_index("Music") >= 0, "bus Music disponible")
    _check(AudioServer.get_bus_index("Voice") >= 0, "bus Voice disponible")
    _check(AudioServer.get_bus_index("SFX") >= 0, "bus SFX disponible")
    _check(AudioServer.get_bus_index("Ambience") >= 0, "bus Ambience disponible")

func _audit_menu_layout() -> void:
    var menu := root.find_child("MainMenu", true, false)
    _check(menu != null, "menu principal présent")
    if menu == null:
        return
    if menu.has_method("_open_difficulty"):
        menu.call("_open_difficulty")
    await process_frame
    await process_frame

    var panel = menu.get("_difficulty_panel")
    _check(panel is Control, "panneau de difficulté construit")
    if not panel is Control:
        return

    var choices := _find_difficulty_choices(panel as Control)
    _check(choices != null, "rangée des trois difficultés trouvée")
    if choices == null:
        return

    var cards: Array[Control] = []
    for child in choices.get_children():
        if child is Control:
            cards.append(child as Control)
    _check(cards.size() == 3, "exactement trois cartes de difficulté")
    if cards.size() != 3:
        return

    var choices_rect: Rect2 = choices.get_global_rect()
    var previous_right: float = -INF
    for card: Control in cards:
        var rect: Rect2 = card.get_global_rect()
        _check(rect.size.x >= 200.0, "carte %s suffisamment large" % card.name)
        _check(rect.position.x >= choices_rect.position.x - 2.0, "carte %s ne déborde pas à gauche" % card.name)
        _check(rect.end.x <= choices_rect.end.x + 2.0, "carte %s ne déborde pas à droite" % card.name)
        _check(rect.position.x >= previous_right - 1.0, "cartes de difficulté sans chevauchement")
        previous_right = rect.end.x

func _find_difficulty_choices(node: Node) -> HBoxContainer:
    if node is HBoxContainer:
        var gameplay_cards := 0
        for child in node.get_children():
            if child is VBoxContainer:
                for grandchild in child.get_children():
                    if grandchild is Button and (grandchild as Button).text.begins_with("JOUER EN"):
                        gameplay_cards += 1
                        break
        if gameplay_cards == 3:
            return node as HBoxContainer
    for child in node.get_children():
        var found := _find_difficulty_choices(child)
        if found != null:
            return found
    return null

func _audit_hud_layout() -> void:
    var hud := get_first_node_in_group("hud")
    if hud == null:
        return
    await process_frame
    var stats = hud.get("stats_panel")
    var mission = hud.get("mission_panel")
    var map_panel = hud.get("map_panel")
    _check(stats is Control and mission is Control and map_panel is Control, "panneaux HUD principaux construits")
    if not (stats is Control and mission is Control and map_panel is Control):
        return

    var viewport_rect: Rect2 = root.get_visible_rect()
    var controls: Array[Control] = [stats as Control, mission as Control, map_panel as Control]
    for control: Control in controls:
        var rect: Rect2 = control.get_global_rect()
        _check(_rect_inside(rect, viewport_rect, 3.0), "%s reste dans l'écran" % control.name)

    _check(not (stats as Control).get_global_rect().intersects((mission as Control).get_global_rect()), "stats et mission ne se chevauchent pas")
    _check(not (mission as Control).get_global_rect().intersects((map_panel as Control).get_global_rect()), "mission et mini-carte ne se chevauchent pas")

func _audit_touch_controls() -> void:
    var movement := root.find_child("MovementJoystickInput", true, false) as Control
    _check(movement != null, "joystick de déplacement trouvé")
    if movement == null:
        return

    var viewport_rect: Rect2 = root.get_visible_rect()
    _check(_rect_inside(movement.get_global_rect(), viewport_rect, 3.0), "joystick dans les limites de l'écran")

    var touch := InputEventScreenTouch.new()
    touch.index = 77
    touch.pressed = true
    touch.position = movement.global_position + movement.size * 0.5
    movement.call("_input", touch)

    var drag := InputEventScreenDrag.new()
    drag.index = 77
    drag.position = movement.global_position + Vector2(movement.size.x * 0.5, movement.size.y * 0.95)
    movement.call("_input", drag)
    var before: Vector2 = movement.call("get_input_value")
    _check(before.length() > 0.25, "joystick produit un vecteur avant interruption")

    movement.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    await process_frame
    var after: Vector2 = movement.call("get_input_value")
    _check(after.is_zero_approx(), "joystick annulé après perte de focus")
    _check(not Input.is_action_pressed("move_back") and not Input.is_action_pressed("move_forward") and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "actions de déplacement relâchées après interruption")

func _audit_endgame_overlay() -> void:
    var overlay := root.find_child("EndgameTrophyOverlay", true, false)
    _check(overlay != null, "écran final accessible")
    if overlay == null:
        return

    var end_root = overlay.get("_root")
    _check(end_root is Control, "racine de l'écran final construite")
    if not end_root is Control:
        return

    _check(not paused, "gameplay actif avant le test de fin")
    GameState.set_quest_value("island_11_boss_sorciere_defeated", true)
    await process_frame
    _check(not (end_root as Control).visible, "première sorcière seule ne déclenche pas la fin")

    GameState.mark_boss_defeated(11)
    await process_frame
    await process_frame
    _check((end_root as Control).visible, "victoire du boss final déclenche l'écran trophée")
    _check(paused, "jeu mis en pause pendant l'écran final")

    if overlay.has_method("_continue_game"):
        overlay.call("_continue_game")
    await process_frame
    _check(not paused, "CONTINUE reprend correctement la partie")
    _check(bool(GameState.get_quest_value("endgame_trophy_seen", false)), "CONTINUE mémorise l'écran final")

    GameState.new_game("cheikh", "aventure")
    paused = false

func _rect_inside(rect: Rect2, outer: Rect2, margin: float = 0.0) -> bool:
    return rect.position.x >= outer.position.x - margin \
        and rect.position.y >= outer.position.y - margin \
        and rect.end.x <= outer.end.x + margin \
        and rect.end.y <= outer.end.y + margin

func _finish() -> void:
    if _failures.is_empty():
        print("CHK_PIRATE_WARRIOR_2_V11_8_RUNTIME_AUDIT_OK")
        quit(0)
        return
    print("AUDIT V11.8 • %d échec(s)" % _failures.size())
    for failure in _failures:
        print(" - ", failure)
    quit(10)
