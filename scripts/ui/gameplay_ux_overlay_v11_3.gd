class_name GameplayUXOverlayV11_3
extends "res://scripts/ui/gameplay_ux_overlay_v11_2.gd"

func _ready() -> void:
    super._ready()
    _name_extreme_targets.call_deferred()

func _process(delta: float) -> void:
    super._process(delta)
    _sync_arrow_to_panel(_nav_panel, _arrow)
    _sync_arrow_to_panel(_mission_panel, _mission_arrow)
    _sync_arrow_to_panel(_team_panel, _team_arrow)

func _name_extreme_targets() -> void:
    if _coin_panel != null:
        _coin_panel.name = "CoinCounterPanel"
    if _nav_panel != null:
        _nav_panel.name = "EnemyNavigationPanel"
    if _mission_panel != null:
        _mission_panel.name = "MissionNavigationPanel"
    if _team_panel != null:
        _team_panel.name = "TeamNavigationPanel"
    if _feedback_label != null:
        _feedback_label.name = "GameplayFeedbackLabel"

func _sync_arrow_to_panel(panel: Control, arrow: Polygon2D) -> void:
    if panel == null or arrow == null or not is_instance_valid(panel) or not is_instance_valid(arrow):
        return
    var scale_value := maxf(0.35, panel.scale.x)
    arrow.position = panel.position + Vector2(24.0 * scale_value, panel.size.y * 0.5 * scale_value)
    arrow.scale = Vector2.ONE * scale_value
    var arrow_color := arrow.color
    arrow_color.a = panel.modulate.a
    arrow.color = arrow_color
