class_name GameplayUXOverlayV11_3
extends "res://scripts/ui/gameplay_ux_overlay_v11_2.gd"

func _ready() -> void:
    super._ready()
    _name_extreme_targets.call_deferred()

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
