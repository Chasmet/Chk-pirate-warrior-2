class_name MobileInputOverlayV11_3
extends "res://scripts/ui/mobile_input_overlay_v10.gd"

const V113_MIN_SCALE := 0.30
const V113_MAX_SCALE := 2.25
const V113_SCALE_STEP := 0.05

func _ready() -> void:
    super._ready()
    add_to_group("mobile_ui_editor_v11_3")
    _notify_extreme_editor.call_deferred()

func _toggle_edit_mode() -> void:
    super._toggle_edit_mode()
    _notify_extreme_editor()
    if _edit_mode and _edit_status != null:
        _edit_status.text = "PERSONNALISATION EXTRÊME • TOUCHE = ICI • CASE HUD = ÉDITEUR BLEU"
    _layout_editor_toolbar()

func _notify_extreme_editor() -> void:
    var editor := get_tree().get_first_node_in_group("ui_extreme_customizer")
    if editor != null and editor.has_method("set_edit_mode"):
        editor.call("set_edit_mode", _edit_mode)

func _resize_selected(delta_scale: float) -> void:
    if _selected_edit_control == null:
        if _edit_status != null:
            _edit_status.text = "TOUCHE UNE COMMANDE OU UNE CASE DU HUD"
        return
    var direction := signf(delta_scale)
    if is_zero_approx(direction):
        return
    var old_center := _selected_edit_control.position + _selected_edit_control.size * 0.5
    var current_scale := float(_selected_edit_control.get_meta("layout_scale", 1.0))
    var new_scale := clampf(current_scale + direction * V113_SCALE_STEP, V113_MIN_SCALE, V113_MAX_SCALE)
    _selected_edit_control.set_meta("layout_scale", new_scale)

    var base_size: Vector2 = _selected_edit_control.get_meta("base_size", _selected_edit_control.size)
    var new_size := base_size * new_scale
    _selected_edit_control.custom_minimum_size = new_size
    _selected_edit_control.size = new_size
    _selected_edit_control.position = old_center - new_size * 0.5
    _apply_button_font_scale(_selected_edit_control, new_scale)
    _move_selected_to(_selected_edit_control.position)
    _save_selected_layout()

    if _edit_status != null:
        _edit_status.text = "%s • TAILLE %d%% • GLISSE POUR DÉPLACER" % [
            _control_display_name(_selected_edit_control),
            roundi(new_scale * 100.0)
        ]

func _apply_saved_layout() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    for control in _editable_controls():
        var section := str(control.name)
        if not _layout_config.has_section(section):
            continue
        var scale_value := clampf(
            float(_layout_config.get_value(section, "scale", 1.0)),
            V113_MIN_SCALE,
            V113_MAX_SCALE
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

func _apply_button_font_scale(control: Control, scale_value: float) -> void:
    if control is TouchActionButton:
        var button := control as TouchActionButton
        var base_font := int(button.get_meta("base_font_size", button.font_size))
        button.font_size = maxi(8, int(round(float(base_font) * clampf(scale_value, 0.55, 1.75))))
        button.call("_refresh_label")

func _layout_editor_toolbar() -> void:
    super._layout_editor_toolbar()
    if not _edit_mode:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y
    var toolbar_y := maxf(8.0, h - 58.0)
    var total_width := 54.0 + 8.0 + 54.0 + 8.0 + 82.0 + 8.0 + 60.0
    var start_x := maxf(12.0, w * 0.5 - total_width * 0.5)
    _edit_minus.position = Vector2(start_x, toolbar_y)
    _edit_plus.position = Vector2(start_x + 62.0, toolbar_y)
    _edit_reset.position = Vector2(start_x + 124.0, toolbar_y)
    _edit_done.position = Vector2(start_x + 214.0, toolbar_y)
    _edit_status.position = Vector2(maxf(8.0, w * 0.5 - 300.0), maxf(8.0, toolbar_y - 36.0))
    _edit_status.size = Vector2(minf(600.0, w - 16.0), 30.0)
