extends "res://scripts/ui/mobile_input_overlay_v11_3.gd"

func _layout_controls() -> void:
    super._layout_controls()
    var viewport := get_viewport().get_visible_rect().size
    var w := viewport.x
    var h := viewport.y
    # Chaque section déjà enregistrée garde sa taille et son emplacement.
    _default_control(_movement, Vector2(208, 208), Vector2(24, h - 244), 16)
    _default_control(_attack_button, Vector2(112, 112), Vector2(w - 144, h - 306), 15)
    _default_control(_ability_1_button, Vector2(96, 96), Vector2(w - 260, h - 214), 12)
    _default_control(_ability_2_button, Vector2(96, 96), Vector2(w - 144, h - 174), 12)
    _default_control(_jump_button, Vector2(96, 96), Vector2(w - 356, h - 134), 18)
    _default_control(_dodge_button, Vector2(96, 96), Vector2(w - 464, h - 134), 15)
    _default_control(_interact_button, Vector2(154, 64), Vector2(w * .5 - 77, h - 114), 15)
    _default_control(_hero_switch_button, Vector2(80, 80), Vector2(248, h - 116), 13)
    _default_control(_inventory_button, Vector2(80, 80), Vector2(344, h - 116), 15)
    _default_control(_enemy_recovery_button, Vector2(132, 58), Vector2(w - 150, 230), 12)
    _default_control(_camera_reset_button, Vector2(112, 50), Vector2(w - 130, 300), 12)
    _layout_editor_toolbar()
    _update_selection_frame()

func _default_control(control: Control, dimensions: Vector2, at: Vector2, font_size: int) -> void:
    if control == null or _layout_config.has_section(str(control.name)):
        return
    control.custom_minimum_size = dimensions
    control.size = dimensions
    control.position = at
    # Keep historical base_size metadata so old saved scale values retain meaning.
    var base_size: Vector2 = control.get_meta("base_size", dimensions)
    control.set_meta("layout_scale", dimensions.x / base_size.x)
    if control is TouchActionButton:
        control.font_size = font_size
        control.call("_refresh_label")
    elif control.has_method("cancel_input"):
        control.call("cancel_input")
    control.queue_redraw()
