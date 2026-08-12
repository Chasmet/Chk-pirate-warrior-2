extends "res://scripts/ui/mobile_input_overlay_v9.gd"

func _interact() -> void:
    var collectibles := get_tree().get_first_node_in_group("island_collectibles")
    if collectibles != null and collectibles.has_method("request_interaction"):
        if bool(collectibles.call("request_interaction")):
            return
    super._interact()
