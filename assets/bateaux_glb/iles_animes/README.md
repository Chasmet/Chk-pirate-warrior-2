# Navires animés des 11 îles

Chaque île possède son propre navire pirate GLB avec silhouette/accessoires distinctifs et animations intégrées.

Animations intégrées :

- `Idle_Ocean` : roulis/tangage léger du navire ;
- `Flag_Wave` : mouvement des pavillons ;
- `Theme_Motion` : animation légère des éléments spécifiques au navire.

Les modèles de coque utilisés comme base proviennent du **Kenney Pirate Kit — CC0 1.0**. Les éléments distinctifs ont été générés spécifiquement pour CHK Pirate Warrior 2.

| Île | Navire | GLB | Taille |
|---:|---|---|---:|
| 1 | Corsaire Du Rivage | `ile_01_corsaire_du_rivage_anime.glb` | 228.1 Ko |
| 2 | Requin Noir | `ile_02_requin_noir_anime.glb` | 225.7 Ko |
| 3 | Galion Gourmand | `ile_03_galion_gourmand_anime.glb` | 242.2 Ko |
| 4 | Roc Des Mers | `ile_04_roc_des_mers_anime.glb` | 230.3 Ko |
| 5 | Volcan Rouge | `ile_05_volcan_rouge_anime.glb` | 228.8 Ko |
| 6 | Brume Des Marais | `ile_06_brume_des_marais_anime.glb` | 255.2 Ko |
| 7 | Forteresse Flottante | `ile_07_forteresse_flottante_anime.glb` | 244.8 Ko |
| 8 | Jungle Emeraude | `ile_08_jungle_emeraude_anime.glb` | 256.6 Ko |
| 9 | Abysses Bleus | `ile_09_abysses_bleus_anime.glb` | 252.0 Ko |
| 10 | Galion Royal | `ile_10_galion_royal_anime.glb` | 242.3 Ko |
| 11 | Spectre Des Souvenirs | `ile_11_spectre_des_souvenirs_anime.glb` | 247.5 Ko |

## Utilisation dans Godot

Importer le GLB puis choisir l'animation voulue dans `AnimationPlayer`. Pour un bateau contrôlé par le joueur, `Idle_Ocean` peut être désactivée pendant les déplacements si la physique du bateau gère déjà le roulis.

Licence des coques de base : **CC0 1.0 Universal**.
