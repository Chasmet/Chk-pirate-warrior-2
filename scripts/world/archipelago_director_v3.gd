class_name ArchipelagoDirectorV3
extends "res://scripts/world/archipelago_director_v2.gd"

# La V3 ne disperse plus des GLB sans normalisation via le vieux système.
# Le décor est construit par GLBSceneryDirector avec taille, placement au sol
# et zones de circulation mobile contrôlées.
func _scatter_real_props(_info: Dictionary) -> void:
    pass

# Le joueur ne démarre plus au bout étroit du quai entouré d'eau.
# Il arrive à l'entrée du port, sur une zone large, dégagée et orientée vers l'île.
func _safe_port_spawn(index: int) -> Vector3:
    var resolved := clampi(index, 0, WorldCatalog.island_count() - 1)
    var info := WorldCatalog.island(resolved)
    var size: Vector2 = info["size"]
    var local_z := size.y * 0.34
    return _positions[resolved] + Vector3(0.0, 10.0, local_z)
