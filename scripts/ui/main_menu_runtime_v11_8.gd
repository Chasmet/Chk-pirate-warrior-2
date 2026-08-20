class_name MainMenuRuntimeV11_8
extends "res://scripts/ui/main_menu_runtime.gd"

func _add_difficulty_card(parent: HBoxContainer, title_text: String, description: String, difficulty_id: String) -> void:
    # L'ancienne carte imposait 440 px de large. Trois cartes + séparations
    # dépassaient déjà les 1024 px disponibles dans la zone de choix sur le
    # viewport officiel 1280x720, ce qui coupait les cartes latérales.
    var card := VBoxContainer.new()
    card.custom_minimum_size = Vector2.ZERO
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.size_flags_stretch_ratio = 1.0
    card.add_theme_constant_override("separation", 12)
    parent.add_child(card)

    var label := Label.new()
    label.text = title_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Color("f1d37b"))
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.clip_text = true
    card.add_child(label)

    var detail := Label.new()
    detail.text = description
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    detail.custom_minimum_size = Vector2(0.0, 112.0)
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail.add_theme_font_size_override("font_size", 16)
    card.add_child(detail)

    var choose := Button.new()
    choose.text = "JOUER EN %s" % title_text
    choose.custom_minimum_size = Vector2(0.0, 62.0)
    choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choose.add_theme_font_size_override("font_size", 17)
    choose.focus_mode = Control.FOCUS_NONE
    choose.pressed.connect(func(): _start_new_game(difficulty_id))
    card.add_child(choose)
