extends "res://scripts/ui/mobile_input_overlay_v9.gd"

const V11_MIN_LAYOUT_SCALE := 0.40
const V11_MAX_LAYOUT_SCALE := 1.80
const V11_LAYOUT_STEP := 0.05

func _ready() -> void:
    super._ready()

    # V9 utilisait le troisième emplacement pour « ATTAQUE SUIVANTE ».
    # V11 le redevient une vraie attaque directe : 1 = base, 2 et 3 = pouvoirs.
    var cycle_callback := Callable(self, "_cycle_special_attack")
    if _ability_2_button != null and _ability_2_button.activated.is_connected(cycle_callback):
        _ability_2_button.activated.disconnect(cycle_callback)
    if _attack_button != null:
        _attack_button.action_name = &"attack"
    if _ability_1_button != null:
        _ability_1_button.action_name = &"ability_1"
    if _ability_2_button != null:
        _ability_2_button.action_name = &"ability_2"

    # Le gros bouton ATTAQUE est réduit. Les trois boutons ont désormais une
    # taille comparable et restent tous éditables individuellement.
    _set_v11_base_size(_attack_button, Vector2(132, 132), 16)
    _set_v11_base_size(_ability_1_button, Vector2(124, 124), 14)
    _set_v11_base_size(_ability_2_button, Vector2(124, 124), 14)

    if _edit_toggle != null:
        _edit_toggle.text = "MODIFIER"
    if _edit_minus != null:
        _edit_minus.tooltip_text = "Réduire la touche sélectionnée"
    if _edit_plus != null:
        _edit_plus.tooltip_text = "Agrandir la touche sélectionnée"

    _refresh_ability_labels()
    _layout_controls.call_deferred()

func _set_v11_base_size(control: Control, resolved_size: Vector2, font_size_value: int) -> void:
    if control == null:
        return
    control.set_meta("base_size", resolved_size)
    control.set_meta("base_font_size", font_size_value)
    control.custom_minimum_size = resolved_size
    control.size = resolved_size
    if control is TouchActionButton:
        var button := control as TouchActionButton
        button.font_size = font_size_value
        button.call("_refresh_label")

func _interact() -> void:
    var collectibles := get_tree().get_first_node_in_group("island_collectibles")
    if collectibles != null and collectibles.has_method("request_interaction"):
        if bool(collectibles.call("request_interaction")):
            return
    super._interact()

func _refresh_ability_labels() -> void:
    if _attack_button == null or _ability_1_button == null or _ability_2_button == null:
        return

    var hero := GameState.get_hero_data()
    var abilities: Array = hero.get("abilities", [])

    _attack_button.set_button_text(_attack_button_text(
        1,
        str(hero.get("base_attack", "Attaque")),
        1
    ))

    if abilities.size() > 0:
        var ability_2: Dictionary = abilities[0]
        _ability_1_button.set_button_text(_attack_button_text(
            2,
            str(ability_2.get("name", "Attaque 2")),
            maxi(1, int(ability_2.get("unlock_level", 1)))
        ))
    else:
        _ability_1_button.set_button_text("ATQ 2\nINDISPONIBLE")

    if abilities.size() > 1:
        var ability_3: Dictionary = abilities[1]
        _ability_2_button.set_button_text(_attack_button_text(
            3,
            str(ability_3.get("name", "Attaque 3")),
            maxi(1, int(ability_3.get("unlock_level", 1)))
        ))
    else:
        _ability_2_button.set_button_text("ATQ 3\nINDISPONIBLE")

    _apply_attack_lock_visuals()

func _attack_button_text(slot: int, attack_name: String, unlock_level: int) -> String:
    if GameState.level < unlock_level:
        return "ATQ %d\nVERROUILLÉE\nNIV. %d" % [slot, unlock_level]
    return "ATQ %d\n%s" % [slot, _compact_attack_name(attack_name)]

func _compact_attack_name(value: String) -> String:
    var cleaned := value.to_upper().strip_edges()
    for prefix in ["LA ", "LE ", "L'", "LES "]:
        if cleaned.begins_with(prefix):
            cleaned = cleaned.substr(prefix.length())
            break
    if cleaned.length() <= 15:
        return cleaned

    var words := cleaned.split(" ", false)
    if words.size() <= 1:
        return cleaned.left(15)

    var first_line := ""
    var second_line := ""
    for word in words:
        var token := str(word)
        if first_line.is_empty() or first_line.length() + 1 + token.length() <= 12:
            first_line = token if first_line.is_empty() else "%s %s" % [first_line, token]
        elif second_line.is_empty() or second_line.length() + 1 + token.length() <= 12:
            second_line = token if second_line.is_empty() else "%s %s" % [second_line, token]
    if second_line.is_empty():
        return first_line.left(15)
    return "%s\n%s" % [first_line, second_line]

func _apply_attack_lock_visuals() -> void:
    if _edit_mode:
        return
    var hero := GameState.get_hero_data()
    var abilities: Array = hero.get("abilities", [])
    _attack_button.modulate = Color.WHITE

    var unlock_2 := int((abilities[0] as Dictionary).get("unlock_level", 1)) if abilities.size() > 0 else 999
    var unlock_3 := int((abilities[1] as Dictionary).get("unlock_level", 1)) if abilities.size() > 1 else 999
    _ability_1_button.modulate = Color.WHITE if GameState.level >= unlock_2 else Color(0.58, 0.58, 0.58, 0.78)
    _ability_2_button.modulate = Color.WHITE if GameState.level >= unlock_3 else Color(0.48, 0.48, 0.48, 0.70)

func _on_special_selection_changed(_index: int, _ability: Dictionary) -> void:
    # Conservé pour compatibilité avec HeroControllerV3, mais il n'y a plus de
    # sélection circulaire : les trois attaques sont toujours affichées.
    _refresh_ability_labels()

func _control_display_name(control: Control) -> String:
    if control == _attack_button:
        return "ATTAQUE 1"
    if control == _ability_1_button:
        return "ATTAQUE 2"
    if control == _ability_2_button:
        return "ATTAQUE 3"
    return super._control_display_name(control)

func _refresh_gameplay_enabled_state() -> void:
    super._refresh_gameplay_enabled_state()
    if not _edit_mode:
        _apply_attack_lock_visuals()

func _toggle_edit_mode() -> void:
    super._toggle_edit_mode()
    if _edit_mode and _edit_status != null:
        _edit_status.text = "TOUCHE UNE COMMANDE • GLISSE = POSITION • − / + = TAILLE 40–180 %"
    elif not _edit_mode:
        _apply_attack_lock_visuals()

# Chaque commande est redimensionnée indépendamment de 40 % à 180 %.
# La position et la taille sont sauvegardées dans user://touch_layout.cfg.
func _resize_selected(delta_scale: float) -> void:
    if _selected_edit_control == null:
        _edit_status.text = "TOUCHE D'ABORD LA COMMANDE À MODIFIER"
        return

    var direction := signf(delta_scale)
    if is_zero_approx(direction):
        return
    var old_center := _selected_edit_control.position + _selected_edit_control.size * 0.5
    var current_scale := float(_selected_edit_control.get_meta("layout_scale", 1.0))
    var new_scale := clampf(current_scale + direction * V11_LAYOUT_STEP, V11_MIN_LAYOUT_SCALE, V11_MAX_LAYOUT_SCALE)
    _selected_edit_control.set_meta("layout_scale", new_scale)

    var base_size: Vector2 = _selected_edit_control.get_meta("base_size", _selected_edit_control.size)
    var new_size := base_size * new_scale
    _selected_edit_control.custom_minimum_size = new_size
    _selected_edit_control.size = new_size
    _selected_edit_control.position = old_center - new_size * 0.5
    _apply_button_font_scale(_selected_edit_control, new_scale)
    _move_selected_to(_selected_edit_control.position)
    _save_selected_layout()

    _edit_status.text = "%s • TAILLE %d %% • GLISSE POUR DÉPLACER" % [
        _control_display_name(_selected_edit_control),
        roundi(new_scale * 100.0)
    ]

func _apply_button_font_scale(control: Control, scale_value: float) -> void:
    if control is TouchActionButton:
        var button := control as TouchActionButton
        var base_font := int(button.get_meta("base_font_size", button.font_size))
        button.font_size = maxi(9, int(round(float(base_font) * clampf(scale_value, 0.65, 1.45))))
        button.call("_refresh_label")

func _apply_saved_layout() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    for control in _editable_controls():
        var section := str(control.name)
        if not _layout_config.has_section(section):
            continue
        var scale_value := clampf(
            float(_layout_config.get_value(section, "scale", 1.0)),
            V11_MIN_LAYOUT_SCALE,
            V11_MAX_LAYOUT_SCALE
        )
        control.set_meta("layout_scale", scale_value)
        var base_size: Vector2 = control.get_meta("base_size", control.size)
        var resolved_size := base_size * scale_value
        control.custom_minimum_size = resolved_size
        control.size = resolved_size
        _apply_button_font_scale(control, scale_value)
        if _layout_config.has_section_key(section, "center"):
            var normalized_center: Vector2 = _layout_config.get_value(section, "center", Vector2(0.5, 0.5))
            var center := Vector2(normalized_center.x * viewport_size.x, normalized_center.y * viewport_size.y)
            control.position = center - control.size * 0.5
            control.position = Vector2(
                clampf(control.position.x, 4.0, maxf(4.0, viewport_size.x - control.size.x - 4.0)),
                clampf(control.position.y, 4.0, maxf(4.0, viewport_size.y - control.size.y - 4.0))
            )

func _layout_controls() -> void:
    super._layout_controls()
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y
    var attack_x := w - SAFE_SIDE_MARGIN - 132.0
    var first_y := clampf(h - 470.0, 250.0, 330.0)

    # Une disposition déjà réglée par le joueur n'est jamais écrasée.
    if _attack_button != null and not _layout_config.has_section(str(_attack_button.name)):
        _attack_button.position = Vector2(attack_x, first_y)
    if _ability_1_button != null and not _layout_config.has_section(str(_ability_1_button.name)):
        _ability_1_button.position = Vector2(attack_x + 4.0, first_y + 138.0)
    if _ability_2_button != null and not _layout_config.has_section(str(_ability_2_button.name)):
        _ability_2_button.position = Vector2(attack_x + 4.0, first_y + 270.0)

    if _dodge_button != null and not _layout_config.has_section(str(_dodge_button.name)):
        _dodge_button.position = Vector2(attack_x - _dodge_button.size.x - 28.0, h - SAFE_BOTTOM_MARGIN - _dodge_button.size.y + 8.0)
    if _jump_button != null and not _layout_config.has_section(str(_jump_button.name)):
        _jump_button.position = Vector2(_dodge_button.position.x - _jump_button.size.x - 18.0, h - SAFE_BOTTOM_MARGIN - _jump_button.size.y + 8.0)

    _layout_editor_toolbar()
    _update_selection_frame()
