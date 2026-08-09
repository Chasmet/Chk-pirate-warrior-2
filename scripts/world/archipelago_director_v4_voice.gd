class_name ArchipelagoDirectorV4Voice
extends ArchipelagoDirectorV3

# Couche de mise en scène vocale : les répliques sont déclenchées par les vrais
# événements de gameplay, pas par un minuteur arbitraire.

func on_boss_defeated(enemy: Node) -> void:
    var island_id := maxi(1, GameState.current_island)
    var was_already_defeated := GameState.is_boss_defeated(island_id)
    super.on_boss_defeated(enemy)
    if not was_already_defeated and GameState.is_boss_defeated(island_id):
        get_tree().call_group("hero_voice_director", "play_event", "victoire")

func request_boat_interaction() -> bool:
    var active_before := get_tree().get_first_node_in_group("active_controller")
    var was_on_boat := active_before is BoatController and (active_before as BoatController).is_boarded()

    var result := super.request_boat_interaction()
    if not result:
        return false

    var active_after := get_tree().get_first_node_in_group("active_controller")
    var is_on_boat_now := active_after is BoatController and (active_after as BoatController).is_boarded()
    if not was_on_boat and is_on_boat_now:
        get_tree().call_group("hero_voice_director", "play_event", "embarquement")
    return true
