extends "res://scripts/ui/mobile_input_overlay.gd"

var _combat_player: Node

func _ready() -> void:
    super._ready()
    _ability_2_button.action_name = &""
    if not _ability_2_button.activated.is_connected(_cycle_special_attack):
        _ability_2_button.activated.connect(_cycle_special_attack)
    if not GameState.progression_changed.is_connected(_on_attack_progression_changed):
        GameState.progression_changed.connect(_on_attack_progression_changed)
    _bind_combat_player.call_deferred()
    _refresh_ability_labels()

func _bind_combat_player() -> void:
    _combat_player = get_tree().get_first_node_in_group("player")
    if _combat_player == null:
        return
    if _combat_player.has_signal("special_selection_changed"):
        var callback := Callable(self, "_on_special_selection_changed")
        if not _combat_player.is_connected("special_selection_changed", callback):
            _combat_player.connect("special_selection_changed", callback)
    _refresh_ability_labels()

func _cycle_special_attack() -> void:
    if _combat_player == null or not is_instance_valid(_combat_player):
        _bind_combat_player()
    if _combat_player != null and _combat_player.has_method("cycle_special_attack"):
        _combat_player.call("cycle_special_attack")

func _on_special_selection_changed(_index: int, _ability: Dictionary) -> void:
    _refresh_ability_labels()

func _on_attack_progression_changed() -> void:
    _refresh_ability_labels.call_deferred()

func _on_hero_changed(hero_id: String) -> void:
    super._on_hero_changed(hero_id)
    _bind_combat_player.call_deferred()
    _refresh_ability_labels.call_deferred()

func _refresh_ability_labels() -> void:
    if _ability_1_button == null or _ability_2_button == null:
        return
    if _combat_player == null or not is_instance_valid(_combat_player):
        _combat_player = get_tree().get_first_node_in_group("player")

    var selected: Dictionary = {}
    var next_level := 0
    if _combat_player != null:
        if _combat_player.has_method("selected_special_attack"):
            selected = _combat_player.call("selected_special_attack")
        if _combat_player.has_method("next_attack_unlock_level"):
            next_level = int(_combat_player.call("next_attack_unlock_level"))

    if not selected.is_empty():
        _ability_1_button.set_button_text(_short_ability_name(str(selected.get("name", "SPÉCIAL"))))
    elif next_level > 0:
        _ability_1_button.set_button_text("ATTAQUE\nNIV. %d" % next_level)
    else:
        _ability_1_button.set_button_text("SPÉCIAL")

    _ability_2_button.set_button_text("ATTAQUE\nSUIVANTE")

func _control_display_name(control: Control) -> String:
    if control == _ability_1_button:
        return "ATTAQUE SPÉCIALE"
    if control == _ability_2_button:
        return "ATTAQUE SUIVANTE"
    return super._control_display_name(control)
