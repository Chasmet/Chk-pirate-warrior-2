# Décors GLB — CHK Pirate Warrior 2

Ce dossier contient des décors 3D légers destinés aux îles et zones maritimes du jeu.

## Organisation

- `glb/` : modèles 3D optimisés au format GLB ;
- `png/` : aperçu PNG 512×512 de chaque modèle ;
- `LICENSE_SOURCES.md` : licence et provenance des assets.

## Pack CC0 importé automatiquement

Le premier lot contient :

- `rocher_large.glb`
- `rocher_moyen.glb`
- `palmier_long.glb`
- `palmier_court.glb`
- `plante_tropicale.glb`
- `coffre_pirate.glb`
- `canon_pirate.glb`
- `tour_pirate.glb`

Les mêmes noms sont utilisés dans `png/` pour les aperçus.

## Optimisation mobile

Les fichiers sources CC0 sont nettoyés automatiquement avec Blender avant export :

- suppression des objets inutiles ;
- application des transformations ;
- fusion des meshes statiques ;
- fusion prudente des sommets en double ;
- simplification légère uniquement sur les modèles très denses ;
- export GLB standard sans compression propriétaire obligatoire ;
- matériaux conservés ;
- origine repositionnée pour faciliter le placement dans Godot.

Le but est de garder une bonne silhouette tout en réduisant la charge mémoire et le poids pour Android.
