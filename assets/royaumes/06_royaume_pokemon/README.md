# Notice de conception — Île 06 : Royaume des créatures

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel royaume 6.png`. Le boss déjà présent est `brok boss .glb`.

## Identité générale

Le Royaume des créatures est une grande île naturelle divisée en plusieurs biomes. Les habitants vivent avec des créatures élémentaires qu’ils observent, entraînent, protègent ou affrontent. L’île doit paraître plus sauvage que les royaumes précédents, avec de vastes espaces, des villages espacés, des arènes et des réserves naturelles.

L’identité repose sur l’exploration, la découverte d’espèces, les combats tactiques et la relation entre les humains et les créatures.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 06.

- **Dimension cible de l’île : 1,9 km × 1,5 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **13 à 18 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 05 (royaume précédent) : **900 m entre les côtes navigables**.
- Mer ouverte vers l’Île 07 (royaume suivant) : **1 250 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Grande plaine centrale servant de zone de migration.
- Forêt dense à l’ouest avec ruines couvertes de végétation.
- Marais lumineux au sud.
- Volcan actif et terres rocheuses à l’est.
- Hautes montagnes froides au nord.
- Lacs, cascades et grottes élémentaires.
- Archipel côtier accessible en bateau ou à dos de créature.
- Plusieurs arènes installées dans les principales régions.
- Sanctuaire ancien au centre de l’île, lié au boss.

Chaque biome doit être relié naturellement aux autres et posséder ses propres espèces, ressources et dangers.

## Météo et lumière

Le climat dépend fortement des biomes.

- Soleil et vents doux dans les plaines.
- Pluie fréquente et brouillard dans la forêt.
- Orages électriques dans les montagnes.
- Cendres et chaleur près du volcan.
- Pluie lourde dans les marais.
- Neige et gel sur les sommets.
- Phénomènes élémentaires rares provoqués par les créatures puissantes.

La météo influence l’apparition des espèces, leurs comportements et l’efficacité de certaines attaques.

## Flore et faune

### Flore

- Hautes herbes cachant de petites créatures.
- Arbres fruitiers utilisés pour les soins ou l’apprivoisement.
- Plantes électriques dans les zones orageuses.
- Fleurs aquatiques dans les marais.
- Mousses chaudes près du volcan.
- Herbes médicinales rares dans les montagnes.

### Faune et créatures

- Créatures terrestres, volantes, aquatiques et souterraines.
- Espèces de feu autour du volcan.
- Espèces d’eau dans les lacs et sur les côtes.
- Espèces de roche et de terre dans les montagnes.
- Espèces végétales dans la forêt.
- Espèces électriques pendant les orages.
- Prédateurs rares défendant leur territoire.
- Créatures pacifiques vivant près des villages.

Les créatures doivent avoir des routines, des territoires, des relations de prédation, des migrations et des réactions aux changements de météo.

## Population et architecture

La capitale, **Bestaria**, est moins verticale que les grandes villes des autres royaumes. Elle est organisée autour d’une grande arène et d’un centre de recherche.

- Centre d’étude et de soins des créatures.
- Grande arène principale.
- Marché d’équipements et de nourriture.
- École des dresseurs et explorateurs.
- Villages spécialisés par biome.
- Postes de garde protégeant les réserves.
- Refuges permettant au joueur de se reposer.
- Port accueillant chercheurs, commerçants et aventuriers.

Les habitants doivent soigner, nourrir, observer, entraîner et déplacer les créatures.

## Ennemis et boss

Types d’ennemis recommandés :

- braconniers capturant des créatures rares ;
- groupes de pillards utilisant des créatures dressées ;
- scientifiques corrompus ;
- créatures territoriales très puissantes ;
- gardiens anciens des sanctuaires ;
- rivaux défiant le joueur dans les arènes.

Le boss `brok boss .glb` doit être le maître du sanctuaire central ou le chef d’une faction contrôlant les créatures les plus dangereuses. Son combat alterne attaques directes, invocations, changements de terrain et utilisation de plusieurs éléments.

## Gameplay, quêtes et exploration

- Observer et enregistrer de nouvelles espèces.
- Sauver des créatures blessées.
- Arrêter un réseau de braconniers.
- Participer à des combats d’arène.
- Suivre une migration à travers plusieurs régions.
- Résoudre des problèmes entre habitants et créatures sauvages.
- Trouver des œufs, traces, tanières et sanctuaires.
- Utiliser certaines créatures pour franchir l’eau, grimper, voler ou casser des obstacles.
- Stabiliser un phénomène élémentaire menaçant un village.

Le joueur doit être encouragé à comprendre le comportement des espèces plutôt qu’à combattre systématiquement tout ce qu’il rencontre.

## Approche maritime

Les côtes sont sauvages, avec plages, falaises et petites réserves. Des créatures marines accompagnent parfois les bateaux. Le port principal reste actif, mais moins industrialisé que celui du Royaume de la nourriture ou de la ville des héros.

## Ambiance sonore

La musique doit laisser de la place aux sons naturels et aux cris des créatures. Chaque biome possède une ambiance spécifique. Les cris doivent aider à identifier une espèce, un danger ou un événement sans saturer le paysage sonore.

## Règles de réalisation

- Concevoir des créatures originales et lisibles.
- Ne pas remplir les zones d’animaux immobiles : utiliser des groupes et routines optimisés.
- Chaque biome doit proposer un gameplay différent.
- Prévoir un système simple d’observation, d’apprivoisement ou de coopération.
- Pour une publication commerciale, remplacer les noms, objets et symboles protégés par des créations originales.
