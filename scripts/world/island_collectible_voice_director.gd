class_name IslandCollectibleVoiceDirector
extends IslandCollectibleDirector

# La détection est faite juste avant le ramassage réel de la classe parente afin
# de jouer "coffre trouvé" uniquement lorsqu'un petit butin est effectivement pris.
func _collect_nearby() -> void:
    var loot_will_be_collected := false
    if _player != null and is_instance_valid(_player):
        for pickup: Node3D in _pickups:
            if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
                continue
            if str(pickup.get_meta("kind", "coin")) != "loot":
                continue
            if _player.global_position.distance_to(pickup.global_position) <= 1.75:
                loot_will_be_collected = true
                break

    super._collect_nearby()
    if loot_will_be_collected:
        get_tree().call_group("hero_voice_director", "play_event", "coffre_trouve")
