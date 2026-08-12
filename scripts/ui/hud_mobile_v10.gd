class_name HUDMobileV10
extends "res://scripts/ui/hud_mobile_v3.gd"

var xp_caption: Label
var xp_bar: ProgressBar
var xp_value_label: Label
var next_level_label: Label

func _ready() -> void:
    super._ready()
    _ensure_level_progress_widgets()
    _refresh_progression_labels()
    _refresh_inventory()
    _layout_v3.call_deferred()

func _ensure_level_progress_widgets() -> void:
    if stats_panel == null or xp_bar != null:
        return

    xp_caption = _label("XP", 12)
    xp_caption.name = "XpCaption"
    stats_panel.add_child(xp_caption)

    xp_bar = ProgressBar.new()
    xp_bar.name = "XpProgressBar"
    xp_bar.show_percentage = false
    xp_bar.min_value = 0.0
    xp_bar.max_value = 1.0
    xp_bar.value = 0.0

    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.01, 0.025, 0.035, 0.95)
    background.border_color = Color(0.42, 0.43, 0.40, 0.85)
    background.set_border_width_all(1)
    background.set_corner_radius_all(8)
    xp_bar.add_theme_stylebox_override("background", background)

    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("e8b83d")
    fill.set_corner_radius_all(8)
    xp_bar.add_theme_stylebox_override("fill", fill)
    stats_panel.add_child(xp_bar)

    xp_value_label = _label("0 / 120", 10)
    xp_value_label.name = "XpValueLabel"
    xp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    stats_panel.add_child(xp_value_label)

    next_level_label = _label("PROCHAIN NIVEAU", 11)
    next_level_label.name = "NextLevelLabel"
    next_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    next_level_label.add_theme_color_override("font_color", Color("ffe59a"))
    stats_panel.add_child(next_level_label)

func _refresh_progression_labels() -> void:
    super._refresh_progression_labels()
    if level_label == null:
        return

    var max_level := int(GameState.MAX_PLAYER_LEVEL) if "MAX_PLAYER_LEVEL" in GameState else 50
    level_label.text = "NIVEAU %d / %d" % [GameState.level, max_level]

    if xp_bar == null:
        return

    if GameState.level >= max_level:
        xp_bar.max_value = 1.0
        xp_bar.value = 1.0
        xp_value_label.text = "MAX"
        next_level_label.text = "NIVEAU MAXIMUM ATTEINT"
        return

    var current_floor := GameState.xp_current_level_floor() if GameState.has_method("xp_current_level_floor") else 120 * (GameState.level - 1) * (GameState.level - 1)
    var next_threshold := GameState.xp_next_level_threshold() if GameState.has_method("xp_next_level_threshold") else 120 * GameState.level * GameState.level
    var span := maxi(1, next_threshold - current_floor)
    var progress := clampi(GameState.xp - current_floor, 0, span)
    var remaining := GameState.xp_to_next_level() if GameState.has_method("xp_to_next_level") else maxi(0, next_threshold - GameState.xp)

    xp_bar.max_value = float(span)
    xp_bar.value = float(progress)
    xp_value_label.text = "%d / %d" % [progress, span]
    next_level_label.text = "NIVEAU SUIVANT : %d XP" % remaining

func _refresh_inventory() -> void:
    if inventory_text == null:
        return

    var hero := GameState.get_hero_data()
    var used := GameState.inventory_used_slots() if GameState.has_method("inventory_used_slots") else GameState.inventory.size()
    var free := GameState.inventory_free_slots() if GameState.has_method("inventory_free_slots") else maxi(0, GameState.max_slots - used)
    var lines := PackedStringArray()

    lines.append("[font_size=25][b]%s[/b][/font_size]" % str(hero.get("display_name", "Héros")))
    if used > GameState.max_slots:
        lines.append("[color=#ff9b7a][b]SAC SURCHARGÉ • %d/%d emplacements[/b][/color]" % [used, GameState.max_slots])
    else:
        lines.append("Capacité physique : [b]%d/%d[/b] • libres : %d" % [used, GameState.max_slots, free])
    lines.append("Les objets de quête et reliques ne prennent pas d'emplacement.")
    lines.append("")

    if GameState.inventory.is_empty():
        lines.append("[i]Le sac est vide. Explore une île, ouvre un coffre ou récupère un objet de quête.[/i]")
    else:
        var quest_lines := PackedStringArray()
        var treasure_lines := PackedStringArray()
        var normal_lines := PackedStringArray()
        var ids := GameState.inventory.keys()
        ids.sort_custom(func(a, b):
            var name_a := GameState.item_display_name(str(a)) if GameState.has_method("item_display_name") else str(a)
            var name_b := GameState.item_display_name(str(b)) if GameState.has_method("item_display_name") else str(b)
            return name_a.naturalnocasecmp_to(name_b) < 0
        )

        for raw_id in ids:
            var item_id := str(raw_id)
            var amount := maxi(0, int(GameState.inventory[item_id]))
            if amount <= 0:
                continue
            var name_value := GameState.item_display_name(item_id) if GameState.has_method("item_display_name") else item_id.replace("_", " ").capitalize()
            var category := GameState.item_category(item_id) if GameState.has_method("item_category") else "objet"
            var line := "• %s  ×%d" % [name_value, amount]
            if category == "quete":
                quest_lines.append(line)
            elif category in ["relique", "tresor", "rare"]:
                treasure_lines.append(line)
            else:
                normal_lines.append(line)

        if not quest_lines.is_empty():
            lines.append("[color=#f5d76e][b]OBJETS DE QUÊTE[/b][/color]")
            lines.append_array(quest_lines)
            lines.append("")
        if not treasure_lines.is_empty():
            lines.append("[color=#9ee7ff][b]RELIQUES & TRÉSORS[/b][/color]")
            lines.append_array(treasure_lines)
            lines.append("")
        if not normal_lines.is_empty():
            lines.append("[b]ÉQUIPEMENT & CONSOMMABLES[/b]")
            lines.append_array(normal_lines)

    lines.append("")
    lines.append("Bateau niveau %d/5 • Difficulté : %s" % [GameState.boat_level, GameState.difficulty_label()])
    inventory_text.text = "\n".join(lines)

func _layout_v3() -> void:
    super._layout_v3()

    if stats_panel != null:
        var stats_w := stats_panel.size.x
        stats_panel.size.y = 318.0

        hero_label.add_theme_font_size_override("font_size", 18)
        hero_label.position = Vector2(14.0, 5.0)
        hero_label.size = Vector2(maxf(118.0, stats_w - 215.0), 48.0)

        level_label.add_theme_font_size_override("font_size", 20)
        level_label.position = Vector2(maxf(126.0, stats_w - 224.0), 5.0)
        level_label.size = Vector2(minf(210.0, stats_w - 138.0), 48.0)
        level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        if xp_caption != null:
            xp_caption.position = Vector2(12.0, 226.0)
            xp_caption.size = Vector2(58.0, 34.0)
            xp_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            xp_caption.add_theme_font_size_override("font_size", 12)
        if xp_bar != null:
            xp_bar.position = Vector2(76.0, 232.0)
            xp_bar.size = Vector2(maxf(150.0, stats_w - 176.0), 24.0)
        if xp_value_label != null:
            xp_value_label.position = Vector2(stats_w - 92.0, 226.0)
            xp_value_label.size = Vector2(76.0, 34.0)
            xp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            xp_value_label.add_theme_font_size_override("font_size", 10)
        if next_level_label != null:
            next_level_label.position = Vector2(72.0, 266.0)
            next_level_label.size = Vector2(stats_w - 88.0, 38.0)
            next_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            next_level_label.add_theme_font_size_override("font_size", 11)

    if inventory_panel == null:
        return

    var viewport_size := get_viewport().get_visible_rect().size
    var inv_w := minf(720.0, maxf(470.0, viewport_size.x - 80.0))
    var inv_h := minf(620.0, maxf(390.0, viewport_size.y - 70.0))
    inventory_panel.position = Vector2((viewport_size.x - inv_w) * 0.5, (viewport_size.y - inv_h) * 0.5)
    inventory_panel.size = Vector2(inv_w, inv_h)

    if inventory_text != null:
        inventory_text.position = Vector2(22.0, 82.0)
        inventory_text.size = Vector2(inv_w - 44.0, inv_h - 104.0)
        inventory_text.add_theme_font_size_override("normal_font_size", 19)
        inventory_text.scroll_active = true

    var close_button := _find_button_by_text(inventory_panel, "FERMER")
    if close_button != null:
        close_button.position = Vector2(inv_w - 132.0, 16.0)
        close_button.size = Vector2(112.0, 50.0)
        close_button.add_theme_font_size_override("font_size", 16)
