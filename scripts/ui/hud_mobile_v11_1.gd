class_name HUDMobileV11_1
extends "res://scripts/ui/hud_mobile_v10.gd"

var quest_dialogue_panel: Panel
var quest_speaker_label: Label
var quest_body_label: Label
var quest_objective_label: Label
var quest_close_button: Button

func _ready() -> void:
    super._ready()
    _build_quest_dialogue()
    get_viewport().size_changed.connect(_layout_story_dialogue)
    _layout_story_dialogue.call_deferred()

func _build_quest_dialogue() -> void:
    if quest_dialogue_panel != null:
        return

    quest_dialogue_panel = Panel.new()
    quest_dialogue_panel.name = "QuestDialoguePanelV11_1"
    quest_dialogue_panel.visible = false
    quest_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    quest_dialogue_panel.z_index = 195
    quest_dialogue_panel.process_mode = Node.PROCESS_MODE_ALWAYS

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.012, 0.030, 0.038, 0.965)
    style.border_color = Color(0.94, 0.71, 0.24, 0.98)
    style.set_border_width_all(4)
    style.set_corner_radius_all(18)
    style.shadow_color = Color(0, 0, 0, 0.62)
    style.shadow_size = 10
    quest_dialogue_panel.add_theme_stylebox_override("panel", style)
    add_child(quest_dialogue_panel)

    quest_speaker_label = Label.new()
    quest_speaker_label.name = "QuestSpeaker"
    quest_speaker_label.text = "HABITANT"
    quest_speaker_label.add_theme_font_size_override("font_size", 24)
    quest_speaker_label.add_theme_color_override("font_color", Color("ffd96a"))
    quest_speaker_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    quest_speaker_label.add_theme_constant_override("shadow_offset_x", 2)
    quest_speaker_label.add_theme_constant_override("shadow_offset_y", 2)
    quest_dialogue_panel.add_child(quest_speaker_label)

    quest_body_label = Label.new()
    quest_body_label.name = "QuestDialogueText"
    quest_body_label.text = "Dialogue de mission"
    quest_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    quest_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    quest_body_label.add_theme_font_size_override("font_size", 20)
    quest_body_label.add_theme_color_override("font_color", Color("f5eed8"))
    quest_body_label.add_theme_constant_override("line_spacing", 5)
    quest_dialogue_panel.add_child(quest_body_label)

    quest_objective_label = Label.new()
    quest_objective_label.name = "QuestDialogueObjective"
    quest_objective_label.text = "OBJECTIF"
    quest_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    quest_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    quest_objective_label.add_theme_font_size_override("font_size", 16)
    quest_objective_label.add_theme_color_override("font_color", Color("9ee7ff"))
    quest_dialogue_panel.add_child(quest_objective_label)

    quest_close_button = Button.new()
    quest_close_button.name = "QuestDialogueClose"
    quest_close_button.text = "CONTINUER"
    quest_close_button.focus_mode = Control.FOCUS_NONE
    quest_close_button.add_theme_font_size_override("font_size", 16)
    quest_close_button.add_theme_color_override("font_color", Color("ffe7a2"))
    var button_style := StyleBoxFlat.new()
    button_style.bg_color = Color(0.08, 0.12, 0.13, 0.98)
    button_style.border_color = Color(0.91, 0.68, 0.20, 0.96)
    button_style.set_border_width_all(2)
    button_style.set_corner_radius_all(11)
    quest_close_button.add_theme_stylebox_override("normal", button_style)
    var pressed := button_style.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.25, 0.17, 0.03, 0.98)
    quest_close_button.add_theme_stylebox_override("pressed", pressed)
    quest_close_button.add_theme_stylebox_override("hover", pressed)
    quest_close_button.pressed.connect(hide_quest_dialogue)
    quest_dialogue_panel.add_child(quest_close_button)

func show_quest_dialogue(speaker: String, body: String, objective: String = "") -> void:
    if quest_dialogue_panel == null:
        _build_quest_dialogue()
    quest_speaker_label.text = speaker.to_upper()
    quest_body_label.text = body
    quest_objective_label.text = objective
    quest_objective_label.visible = not objective.strip_edges().is_empty()
    quest_dialogue_panel.visible = true
    _layout_story_dialogue()

func hide_quest_dialogue() -> void:
    if quest_dialogue_panel != null:
        quest_dialogue_panel.visible = false

func is_quest_dialogue_open() -> bool:
    return quest_dialogue_panel != null and quest_dialogue_panel.visible

func _layout_v3() -> void:
    super._layout_v3()
    _layout_story_dialogue()

func _layout_story_dialogue() -> void:
    if quest_dialogue_panel == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    var panel_w := clampf(viewport_size.x * 0.50, 620.0, 820.0)
    var panel_h := clampf(viewport_size.y * 0.34, 230.0, 300.0)
    var panel_x := clampf((viewport_size.x - panel_w) * 0.5, 20.0, viewport_size.x - panel_w - 20.0)
    var panel_y := maxf(110.0, viewport_size.y - panel_h - 34.0)
    quest_dialogue_panel.position = Vector2(panel_x, panel_y)
    quest_dialogue_panel.size = Vector2(panel_w, panel_h)

    quest_speaker_label.position = Vector2(24.0, 14.0)
    quest_speaker_label.size = Vector2(panel_w - 190.0, 42.0)

    quest_close_button.position = Vector2(panel_w - 158.0, 14.0)
    quest_close_button.size = Vector2(134.0, 44.0)

    quest_body_label.position = Vector2(26.0, 62.0)
    quest_body_label.size = Vector2(panel_w - 52.0, panel_h - 128.0)

    quest_objective_label.position = Vector2(26.0, panel_h - 62.0)
    quest_objective_label.size = Vector2(panel_w - 52.0, 46.0)
