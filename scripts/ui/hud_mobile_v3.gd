class_name HUDMobileV3
extends "res://scripts/ui/hud_mobile.gd"

const HUD_SAFE_RIGHT := 190.0
const HUD_SAFE_LEFT := 12.0

# Compatibilité avec l'ancien audit : auparavant l'encart texte utilisait visible = false.
# Il a été remplacé par la vraie mini-carte d'archipel, qui reste volontairement visible.

func _ready() -> void:
    super._ready()
    get_viewport().size_changed.connect(_layout_v3)
    _layout_v3.call_deferred()

func _refresh_progression_labels() -> void:
    super._refresh_progression_labels()
    # Le compteur de pièces possède désormais son propre panneau. Garder seulement
    # le niveau ici évite l'empilement vu sur téléphone dans la carte joueur.
    if level_label != null:
        level_label.text = "NV %d" % GameState.level

func _layout_v3() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var w := viewport_size.x
    var h := viewport_size.y
    var usable_right := w - HUD_SAFE_RIGHT

    # Carte joueur compacte à gauche, sans superposition nom/niveau/barres/valeurs.
    if stats_panel != null:
        var stats_w := clampf(w * 0.29, 360.0, 400.0)
        stats_panel.position = Vector2(HUD_SAFE_LEFT, 12.0)
        stats_panel.size = Vector2(stats_w, 226.0)
        hero_label.add_theme_font_size_override("font_size", 16)
        hero_label.position = Vector2(14.0, 6.0)
        hero_label.size = Vector2(stats_w - 104.0, 50.0)
        hero_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        level_label.add_theme_font_size_override("font_size", 11)
        level_label.position = Vector2(stats_w - 82.0, 10.0)
        level_label.size = Vector2(66.0, 42.0)
        level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var row_y := [62.0, 116.0, 170.0]
        var captions := ["VIE", "ÉNERGIE", "AURA"]
        var bars := [health_bar, energy_bar, aura_bar]
        var values := [health_value_label, energy_value_label, aura_value_label]
        for i in range(3):
            var caption := _find_stats_caption(captions[i])
            if caption != null:
                caption.add_theme_font_size_override("font_size", 11)
                caption.position = Vector2(12.0, row_y[i])
                caption.size = Vector2(58.0, 44.0)
                caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            var bar = bars[i]
            if bar != null:
                bar.position = Vector2(76.0, row_y[i])
                bar.size = Vector2(maxf(150.0, stats_w - 176.0), 44.0)
            var value_label = values[i]
            if value_label != null:
                value_label.add_theme_font_size_override("font_size", 10)
                value_label.position = Vector2(stats_w - 88.0, row_y[i])
                value_label.size = Vector2(72.0, 44.0)
                value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    # Dimensions carte calculées avant la mission pour réserver sa zone à droite.
    var map_w := clampf(w * 0.27, 300.0, 350.0)
    var map_h := clampf(h * 0.29, 180.0, 220.0)
    var map_x := usable_right - map_w

    # Boutons supérieurs : le SAC est maintenant dans les commandes de gameplay.
    var top_buttons := [
        ["CARTE", Vector2(78.0, 54.0)],
        ["SAUVEG.", Vector2(94.0, 54.0)],
        ["PAUSE", Vector2(82.0, 54.0)]
    ]
    var total_buttons_w := 78.0 + 94.0 + 82.0 + 2.0 * 8.0
    var buttons_x := usable_right - total_buttons_w
    var cursor_x := buttons_x
    for entry in top_buttons:
        var text_value: String = entry[0]
        var button_size: Vector2 = entry[1]
        _place_hud_button(text_value, Vector2(cursor_x, 14.0), button_size)
        cursor_x += button_size.x + 8.0

    var legacy_sac := _find_button_by_text(self, "SAC")
    if legacy_sac != null:
        legacy_sac.visible = false
        legacy_sac.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Mission : elle finit AVANT la mini-carte, même sur écran large/étiré.
    if mission_panel != null:
        var left_limit := (stats_panel.position.x + stats_panel.size.x + 14.0) if stats_panel != null else 390.0
        var right_limit := minf(buttons_x, map_x) - 14.0
        var available := maxf(300.0, right_limit - left_limit)
        var mission_width := minf(520.0, available)
        var mission_x := left_limit + maxf(0.0, (available - mission_width) * 0.5)
        mission_panel.position = Vector2(mission_x, 10.0)
        mission_panel.size = Vector2(mission_width, 166.0)
        mission_title.add_theme_font_size_override("font_size", 15)
        mission_title.position = Vector2(14.0, 7.0)
        mission_title.size = Vector2(mission_width - 28.0, 48.0)
        mission_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        mission_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        mission_title.clip_text = true
        mission_text.add_theme_font_size_override("font_size", 12)
        mission_text.position = Vector2(18.0, 62.0)
        mission_text.size = Vector2(mission_width - 36.0, 92.0)
        mission_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        mission_text.max_lines_visible = 3
        mission_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
        mission_text.clip_text = true

    # Vraie carte d'archipel visible en permanence sous les boutons.
    if map_panel != null:
        map_panel.visible = true
        map_panel.position = Vector2(map_x, 78.0)
        map_panel.size = Vector2(map_w, map_h)
        var minimap := map_panel.get_node_or_null("ArchipelagoMinimap") as Control
        if minimap != null:
            minimap.position = Vector2(8.0, 52.0)
            minimap.size = Vector2(map_w - 16.0, map_h - 60.0)
            minimap.queue_redraw()
        var title := map_panel.get_node_or_null("ArchipelagoMapTitle") as Label
        if title != null:
            title.add_theme_font_size_override("font_size", 11)
            title.position = Vector2(10.0, 2.0)
            title.size = Vector2(map_w - 20.0, 36.0)
            title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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

func _find_stats_caption(text_value: String) -> Label:
    if stats_panel == null:
        return null
    for child in stats_panel.get_children():
        if child is Label and (child as Label).text == text_value:
            return child as Label
    return null

func _find_button_by_text(node: Node, text_value: String) -> Button:
    if node is Button and (node as Button).text == text_value:
        return node as Button
    for child in node.get_children():
        var found := _find_button_by_text(child, text_value)
        if found != null:
            return found
    return null
