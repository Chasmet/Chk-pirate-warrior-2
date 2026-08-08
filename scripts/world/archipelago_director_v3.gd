class_name ArchipelagoDirectorV3
extends "res://scripts/world/archipelago_director_v2.gd"

# La V3 ne disperse plus des GLB sans normalisation via le vieux système.
# Le décor est construit par GLBSceneryDirector avec taille, placement au sol
# et zones de circulation mobile contrôlées.
func _scatter_real_props(_info: Dictionary) -> void:
    pass
