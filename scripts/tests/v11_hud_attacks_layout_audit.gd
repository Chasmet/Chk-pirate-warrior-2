extends SceneTree

var failures := PackedStringArray()

func _init() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    if condition:
        print("OK V11  ", message)
    else:
        failures.append(message)
        push_error("ÉCHEC V11  %s" % message)

func _find_named(root: Node, node_name: String) -> Node:
    if str(root.name) == node_name:
        return root
    for child in root.get_children():
        var found := _find_named(child, node_name)
        if found != null:
            return found
    return null

func _button_label_text(control: Node) -> String:
    if control == null:
        return ""
    for child in control.get_children():
        if child is Label:
            return (child as Label).text
    return ""

func _run() -> void:
    await process_frame

    _check(GameState.MAX_PLAYER_LEVEL == 50, "niveau maximum fixé à 50")
    GameState.new_game("yvane", "aventure")
    GameState.add_xp(230)
    _check(GameState.level == 2, "230 XP place Yvane au niveau 2")
    _check(GameState.xp_to_next_level() == 250, "progression XP vers le niveau suivant calculée précisément")

    for hero_id in ["cheikh", "yvane", "nelvyn"]:
        var hero: Dictionary = GameState.get_hero_data(hero_id)
        var abilities: Array = hero.get("abilities", [])
        _check(not str(hero.get("base_attack", "")).is_empty(), "%s possède une attaque 1" % hero_id)
        _check(abilities.size() == 2, "%s possède exactement deux attaques supplémentaires" % hero_id)

    var overlay_scene := load("res://scenes/ui/mobile_input_overlay.tscn") as PackedScene
    _check(overlay_scene != null, "scène des commandes tactiles chargeable")
    var overlay := overlay_scene.instantiate() if overlay_scene != null else null
    if overlay != null:
        root.add_child(overlay)
        await process_frame
        await process_frame

        var attack_1 := _find_named(overlay, "AttackButton") as Control
        var attack_2 := _find_named(overlay, "Ability1Button") as Control
        var attack_3 := _find_named(overlay, "Ability2Button") as Control
        _check(attack_1 != null and attack_2 != null and attack_3 != null, "trois boutons d'attaque présents simultanément")

        if attack_1 != null:
            _check(attack_1.size.x <= 135.0, "ancien gros bouton attaque réduit")
            _check(_button_label_text(attack_1).contains("ATQ 1"), "attaque 1 clairement numérotée")
        if attack_2 != null:
            _check(_button_label_text(attack_2).contains("ATQ 2"), "attaque 2 clairement numérotée")
            _check(_button_label_text(attack_2).contains("ÉCO"), "Éco Sphère visible au niveau 2")
        if attack_3 != null:
            var locked_text := _button_label_text(attack_3)
            _check(locked_text.contains("ATQ 3"), "attaque 3 clairement numérotée")
            _check(locked_text.contains("NIV. 5"), "attaque 3 affiche son niveau de déblocage")

            overlay.set("_selected_edit_control", attack_3)
            for i in range(30):
                overlay.call("_resize_selected", 0.10)
            _check(is_equal_approx(float(attack_3.get_meta("layout_scale", 1.0)), 1.80), "taille maximale personnalisable à 180 %")
            for i in range(40):
                overlay.call("_resize_selected", -0.10)
            _check(is_equal_approx(float(attack_3.get_meta("layout_scale", 1.0)), 0.40), "taille minimale personnalisable à 40 %")

        GameState.add_xp(2000)
        await process_frame
        if attack_3 != null:
            _check(_button_label_text(attack_3).contains("MÉGA"), "attaque 3 révèle son nom après déblocage")

        overlay.queue_free()
        await process_frame

    var hud_scene := load("res://scenes/ui/hud_mobile.tscn") as PackedScene
    _check(hud_scene != null, "scène HUD mobile chargeable")
    var hud := hud_scene.instantiate() if hud_scene != null else null
    if hud != null:
        root.add_child(hud)
        await process_frame
        await process_frame
        var level_label := _find_named(hud, "LevelLabel") as Label
        var xp_bar := _find_named(hud, "XpProgressBar") as ProgressBar
        _check(level_label != null, "indicateur de niveau présent")
        if level_label != null:
            _check(level_label.text.contains("/ 50"), "niveau maximum 50 visible dans le HUD")
        _check(xp_bar != null, "barre XP visible dans la fiche du héros")
        hud.queue_free()
        await process_frame

    if failures.is_empty():
        print("CHK_PIRATE_WARRIOR_2_V11_HUD_ATTACKS_LAYOUT_OK")
        quit(0)
    else:
        print("V11: %d échec(s)" % failures.size())
        quit(1)
