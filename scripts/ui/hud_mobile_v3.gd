class_name HUDMobileV3
extends "res://scripts/ui/hud_mobile.gd"

const HUD_SAFE_RIGHT := 190.0
const HUD_SAFE_LEFT := 12.0

func _ready() -> void:
    super._ready()
    get_viewport().size_changed.connect(_layout_v3)
    _layout_v3.call_deferred()

func _layout_v3() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y
    var usable_right := w - HUD_SAFE_RIGHT

    # Carte joueur compacte à gauche, comme la maquette.
    if stats_panel != null:
        var stats_w := clampf(w * 0.27, 320.0, 360.0)
        stats_panel.position = Vector2(HUD_SAFE_LEFT, 12.0)
        stats_panel.size = Vector2(stats_w, 146.0)
        hero_label.position = Vector2(14.0, 8.0)
        hero_label.size = Vector2(stats_w * 0.56, 32.0)
        hero_label.add_theme_font_size_override("font_size", 23)
        level_label.position = Vector2(stats_w * 0.54, 12.0)
        level_label.size = Vector2(stats_w * 0.42, 28.0)
        level_label.add_theme_font_size_override("font_size", 14)
        for bar in [health_bar, energy_bar, aura_bar]:
            if bar != null:
                bar.position.x = 88.0
                bar.size.x = maxf(128.0, stats_w - 190.0)
        for value_label in [health_value_label, energy_value_label, aura_value_label]:
            if value_label != null:
                value_label.position.x = stats_w - 104.0
                value_label.size.x = 90.0
                value_label.add_theme_font_size_override("font_size", 13)

    # Boutons supérieurs : CARTE / SAC / SAUVEG. / PAUSE.
    var top_buttons := [
        ["CARTE", Vector2(78.0, 54.0)],
        ["SAC", Vector2(68.0, 54.0)],
        ["SAUVEG.", Vector2(94.0, 54.0)],
        ["PAUSE", Vector2(82.0, 54.0)]
    ]
    var total_buttons_w := 78.0 + 68.0 + 94.0 + 82.0 + 3.0 * 8.0
    var buttons_x := usable_right - total_buttons_w
    var cursor_x := buttons_x
    for entry in top_buttons:
        var text_value: String = entry[0]
        var button_size: Vector2 = entry[1]
        _place_hud_button(text_value, Vector2(cursor_x, 14.0), button_size)
        cursor_x += button_size.x + 8.0

    # Mission au centre, sans chevaucher les stats ni les boutons supérieurs.
    if mission_panel != null:
        var left_limit := (stats_panel.position.x + stats_panel.size.x + 12.0) if stats_panel != null else 360.0
        var available := maxf(300.0, buttons_x - left_limit - 12.0)
        var mission_width := minf(520.0, available)
        var mission_x := left_limit + (available - mission_width) * 0.5
        mission_panel.position = Vector2(mission_x, 12.0)
        mission_panel.size = Vector2(mission_width, 96.0)
        mission_title.position = Vector2(10.0, 7.0)
        mission_title.size = Vector2(mission_width - 20.0, 29.0)
        mission_title.add_theme_font_size_override("font_size", 18)
        mission_text.position = Vector2(10.0, 36.0)
        mission_text.size = Vector2(mission_width - 20.0, 52.0)
        mission_text.add_theme_font_size_override("font_size", 13)

    # Vraie carte d'archipel visible en permanence sous les boutons.
    if map_panel != null:
        var map_w := clampf(w * 0.27, 300.0, 350.0)
        var map_h := clampf(h * 0.29, 180.0, 220.0)
        map_panel.visible = true
        map_panel.position = Vector2(usable_right - map_w, 78.0)
        map_panel.size = Vector2(map_w, map_h)
        var minimap := map_panel.get_node_or_null("ArchipelagoMinimap") as Control
        if minimap != null:
            minimap.position = Vector2(8.0, 32.0)
            minimap.size = Vector2(map_w - 16.0, map_h - 40.0)
            minimap.queue_redraw()
        var title := map_panel.get_node_or_null("ArchipelagoMapTitle") as Label
        if title != null:
            title.size = Vector2(map_w - 20.0, 24.0)
            title.add_theme_font_size_override("font_size", 14)

    if subtitle_panel != null:
        var subtitle_width := minf(500.0, w * 0.40)
        subtitle_panel.position = Vector2((w - subtitle_width) * 0.5, maxf(120.0, h - 190.0))
        subtitle_panel.size = Vector2(subtitle_width, 62.0)
        if subtitle_label != null:
            subtitle_label.size = Vector2(subtitle_width - 30.0, 44.0)
            subtitle_label.add_theme_font_size_override("font_size", 16)

    if inventory_panel != null:
        var inv_w := minf(620.0, w - 100.0)
        var inv_h := minf(560.0, h - 100.0)
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
    button.add_theme_font_size_override("font_size", 14)

func _find_button_by_text(node: Node, text_value: String) -> Button:
    if node is Button and (node as Button).text == text_value:
        return node as Button
    for child in node.get_children():
        var found := _find_button_by_text(child, text_value)
        if found != null:
            return found
    return null
