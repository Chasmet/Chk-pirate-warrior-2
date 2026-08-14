class_name WorldMapRuntimeV11_3
extends "res://scripts/ui/world_map_runtime.gd"

func _ready() -> void:
    super._ready()
    _name_map_controls.call_deferred()

func _name_map_controls() -> void:
    if _root == null:
        return
    for child in _root.get_children():
        if child is PanelContainer:
            child.name = "WorldMapMainPanel"
        elif child is Button:
            var button := child as Button
            if button.text == "FERMER LA CARTE":
                button.name = "WorldMapCloseButton"
