class_name HUDMobileV11_3
extends "res://scripts/ui/hud_mobile_v11_1.gd"

func _ready() -> void:
    super._ready()
    _name_customizable_controls.call_deferred()

func _name_customizable_controls() -> void:
    if stats_panel != null:
        stats_panel.name = "StatsPanel"
    if mission_panel != null:
        mission_panel.name = "MissionPanel"
    if map_panel != null:
        map_panel.name = "ArchipelagoMapPanel"
    if subtitle_panel != null:
        subtitle_panel.name = "SubtitlePanel"
    if inventory_panel != null:
        inventory_panel.name = "InventoryPanel"
    if quest_dialogue_panel != null:
        quest_dialogue_panel.name = "QuestDialoguePanel"

    _name_button("CARTE", "HudMapButton")
    _name_button("SAUVEG.", "HudSaveButton")
    _name_button("PAUSE", "HudPauseButton")
    _name_button("FERMER", "InventoryCloseButton")
    _name_button("CONTINUER", "QuestDialogueContinueButton")

func _name_button(text_value: String, resolved_name: String) -> void:
    var button := _find_button_by_text(self, text_value)
    if button != null:
        button.name = resolved_name
