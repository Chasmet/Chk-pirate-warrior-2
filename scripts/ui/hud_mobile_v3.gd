class_name HUDMobileV3
extends "res://scripts/ui/hud_mobile.gd"

func _ready() -> void:
    super._ready()
    get_viewport().size_changed.connect(_layout_v3)
    _layout_v3.call_deferred()

func _layout_v3() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y

    if hero_label != null and hero_label.get_parent() is Control:
        var stats := hero_label.get_parent() as Control
        stats.position = Vector2(12.0, 12.0)
        stats.size = Vector2(405.0, 146.0)
        hero_label.size = Vector2(205.0, 32.0)
        hero_label.add_theme_font_size_override("font_size", 23)
        level_label.position = Vector2(202.0, 12.0)
        level_label.size = Vector2(188.0, 28.0)
        level_label.add_theme_font_size_override("font_size", 15)
        for bar in [health_bar, energy_bar, aura_bar]:
            if bar != null:
                bar.size.x = 286.0

    if mission_title != null and mission_title.get_parent() is Control:
        var mission := mission_title.get_parent() as Control
        var mission_width := clampf(w * 0.32, 390.0, 470.0)
        mission.position = Vector2((w - mission_width) * 0.5, 12.0)
        mission.size = Vector2(mission_width, 96.0)
        mission_title.position = Vector2(10.0, 8.0)
        mission_title.size = Vector2(mission_width - 20.0, 29.0)
        mission_title.add_theme_font_size_override("font_size", 18)
        mission_text.position = Vector2(10.0, 37.0)
        mission_text.size = Vector2(mission_width - 20.0, 51.0)
        mission_text.add_theme_font_size_override("font_size", 14)

    _place_hud_button("CARTE", Vector2(w - 430.0, 14.0), Vector2(92.0, 58.0))
    _place_hud_button("SAC", Vector2(w - 330.0, 14.0), Vector2(82.0, 58.0))
    _place_hud_button("SAUVEG.", Vector2(w - 240.0, 14.0), Vector2(108.0, 58.0))
    _place_hud_button("PAUSE", Vector2(w - 124.0, 14.0), Vector2(110.0, 58.0))

    var map_title := _find_label_by_text(self, "GRAND ARCHIPEL")
    if map_title != null and map_title.get_parent() is Control:
        # La carte complète reste accessible via CARTE ; on libère l'écran de jeu.
        (map_title.get_parent() as Control).visible = false

    if subtitle_panel != null:
        var subtitle_width := minf(520.0, w * 0.46)
        subtitle_panel.position = Vector2((w - subtitle_width) * 0.5, maxf(135.0, h - 150.0))
        subtitle_panel.size = Vector2(subtitle_width, 68.0)
        if subtitle_label != null:
            subtitle_label.size = Vector2(subtitle_width - 30.0, 50.0)
            subtitle_label.add_theme_font_size_override("font_size", 18)

    if inventory_panel != null:
        var inv_w := minf(620.0, w - 80.0)
        var inv_h := minf(560.0, h - 110.0)
        inventory_panel.position = Vector2((w - inv_w) * 0.5, (h - inv_h) * 0.5)
        inventory_panel.size = Vector2(inv_w, inv_h)
        if inventory_text != null:
            inventory_text.size = Vector2(inv_w - 50.0, inv_h - 110.0)

func _place_hud_button(text_value: String, pos: Vector2, button_size: Vector2) -> void:
    var button := _find_button_by_text(self, text_value)
    if button == null:
        return
    button.position = pos
    button.size = button_size
    button.custom_minimum_size = button_size
    button.add_theme_font_size_override("font_size", 17)

func _find_button_by_text(node: Node, text_value: String) -> Button:
    if node is Button and (node as Button).text == text_value:
        return node as Button
    for child in node.get_children():
        var found := _find_button_by_text(child, text_value)
        if found != null:
            return found
    return null

func _find_label_by_text(node: Node, text_value: String) -> Label:
    if node is Label and (node as Label).text == text_value:
        return node as Label
    for child in node.get_children():
        var found := _find_label_by_text(child, text_value)
        if found != null:
            return found
    return null
