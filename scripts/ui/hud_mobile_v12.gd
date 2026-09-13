extends "res://scripts/ui/hud_mobile_v11_3.gd"

var _keep_custom_hud := false

func _ready() -> void:
    var saved := ConfigFile.new()
    if saved.load("user://ui_extreme_v11_3.cfg") == OK:
        _keep_custom_hud = not saved.get_sections().is_empty()
    super._ready()

func _layout_v3() -> void:
    super._layout_v3()
    if _keep_custom_hud or stats_panel == null:
        return
    var w := get_viewport().get_visible_rect().size.x
    var h := get_viewport().get_visible_rect().size.y
    stats_panel.size = Vector2(300, 174)
    _label_at(hero_label, Vector2(12, 5), Vector2(102, 28), 16)
    _label_at(level_label, Vector2(114, 5), Vector2(172, 28), 16)
    var captions := ["VIE", "ÉNERGIE", "AURA"]
    var bars := [health_bar, energy_bar, aura_bar]
    var values := [health_value_label, energy_value_label, aura_value_label]
    for i in range(3):
        var y := 40.0 + i * 28.0
        var caption := _find_stats_caption(captions[i])
        if caption == null and i == 1:
            caption = _find_stats_caption("POUVOIR")
        _label_at(caption, Vector2(12, y), Vector2(58, 22), 11)
        bars[i].position = Vector2(76, y + 2)
        bars[i].size = Vector2(140, 18)
        _label_at(values[i], Vector2(224, y), Vector2(64, 22), 11)
    if xp_bar != null:
        _label_at(xp_caption, Vector2(12, 124), Vector2(58, 20), 11)
        xp_bar.position = Vector2(76, 130)
        xp_bar.size = Vector2(140, 10)
        _label_at(xp_value_label, Vector2(224, 124), Vector2(64, 20), 10)
        _label_at(next_level_label, Vector2(12, 148), Vector2(276, 20), 10)

    var mission_w := minf(530, w - 640)
    mission_panel.position = Vector2(328, 12)
    mission_panel.size = Vector2(mission_w, 94)
    _label_at(mission_title, Vector2(14, 6), Vector2(mission_w - 28, 26), 15)
    _label_at(mission_text, Vector2(14, 36), Vector2(mission_w - 28, 50), 19)
    mission_text.max_lines_visible = 2
    map_panel.position = Vector2(w - 250, 74)
    map_panel.size = Vector2(238, 138)
    var minimap := map_panel.get_node_or_null("ArchipelagoMinimap") as Control
    if minimap != null:
        minimap.position = Vector2(8, 30)
        minimap.size = Vector2(222, 100)
        minimap.queue_redraw()
    var title := map_panel.get_node_or_null("ArchipelagoMapTitle") as Label
    _label_at(title, Vector2(8, 2), Vector2(222, 28), 10)
    _place_hud_button("CARTE", Vector2(w - 282, 14), Vector2(78, 48))
    _place_hud_button("SAUVEG.", Vector2(w - 196, 14), Vector2(94, 48))
    _place_hud_button("PAUSE", Vector2(w - 94, 14), Vector2(82, 48))
    subtitle_panel.position = Vector2((w - 480) * 0.5, h - 210)
    subtitle_panel.size = Vector2(480, 58)
    _label_at(subtitle_label, Vector2(15, 7), Vector2(450, 44), 16)

func _label_at(label: Label, at: Vector2, dimensions: Vector2, font_size: int) -> void:
    if label == null:
        return
    label.position = at
    label.size = dimensions
    label.add_theme_font_size_override("font_size", font_size)
