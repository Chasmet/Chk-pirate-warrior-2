class_name HUDMobileV10
extends "res://scripts/ui/hud_mobile_v3.gd"

func _ready() -> void:
    super._ready()
    _refresh_inventory()

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
