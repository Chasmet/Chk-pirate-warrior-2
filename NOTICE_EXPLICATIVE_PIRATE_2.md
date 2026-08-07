# Notice explicative du jeu — **Pirate 2**

## 1. Concept général

**Pirate 2** est un jeu d’aventure, d’exploration et de combat en monde ouvert. Le joueur voyage librement entre plusieurs royaumes à bord de son bateau, explore de vastes îles, rencontre différentes populations, affronte des ennemis et progresse jusqu’à l’île finale.

Le monde doit donner l’impression d’être **vivant, immense et en mouvement**, aussi bien sur terre que sur mer.

## 2. Organisation du monde

Le jeu est composé de :

- **10 grandes îles-royaumes principales** ;
- **1 onzième île finale**, représentant la fin du jeu ;
- de vastes zones maritimes reliant les royaumes ;
- des îlots secondaires, épaves, grottes, ports et lieux secrets.

Chaque île doit être suffisamment grande pour permettre une véritable exploration. Elle doit posséder une identité visuelle, une ambiance, une population, une faune et des dangers différents.

### Les 10 royaumes

1. Royaume musical
2. Royaume de la sucrerie
3. Royaume de la nourriture
4. Royaume fantastique
5. Royaume Marvel
6. Royaume Pokémon
7. Île des pirates
8. Royaume des neiges
9. Royaume de feu
10. Royaume de la terre

### Onzième royaume

**Royaume Trouble — Île finale**

Cette île représente la conclusion de l’aventure. Elle doit être plus dangereuse, mystérieuse et difficile que les autres. Le joueur y affronte les dernières épreuves et peut obtenir un **objet extrêmement rare**, lié à la fin du jeu et à l’histoire principale.

<!-- WORLD_SCALE_START -->
## Échelle officielle du monde et distances entre les îles

Les dimensions et distances ci-dessous deviennent la référence obligatoire de conception du monde ouvert.

### Taille minimale des royaumes

- **Chaque île principale doit mesurer au minimum 1 km dans sa dimension utile.**
- Les dimensions ci-dessous correspondent à l’emprise terrestre jouable cible, hors surface maritime.
- Une île peut être agrandie si son contenu, son relief ou ses quêtes le nécessitent, mais elle ne doit pas être réduite sous cette échelle sans décision explicite de conception.

| Royaume | Emprise jouable cible | Traversée en exploration normale |
|---|---:|---:|
| Île 01 | 1,2 km × 1,0 km | 8 à 12 minutes |
| Île 02 | 1,3 km × 1,1 km | 9 à 13 minutes |
| Île 03 | 1,5 km × 1,2 km | 10 à 15 minutes |
| Île 04 | 1,7 km × 1,4 km | 12 à 17 minutes |
| Île 05 | 2,2 km × 1,7 km | 15 à 22 minutes |
| Île 06 | 1,9 km × 1,5 km | 13 à 18 minutes |
| Île 07 | 2,4 km × 1,8 km | 16 à 24 minutes |
| Île 08 | 2,2 km × 1,8 km | 15 à 22 minutes |
| Île 09 | 2,3 km × 1,8 km | 15 à 22 minutes |
| Île 10 | 2,6 km × 2,0 km | 18 à 26 minutes |
| Île 11 | 3,0 km × 2,3 km | 20 à 30 minutes |

### Distances maritimes officielles

Les distances sont mesurées **entre les côtes navigables les plus logiques des îles voisines**, et non entre leurs centres. Cela garantit une vraie zone maritime même lorsque les îles font plusieurs kilomètres de large.

| Liaison principale | Mer ouverte à parcourir |
|---|---:|
| Île 01 ↔ Île 02 | 700 m |
| Île 02 ↔ Île 03 | 850 m |
| Île 03 ↔ Île 04 | 1 000 m |
| Île 04 ↔ Île 05 | 1 150 m |
| Île 05 ↔ Île 06 | 900 m |
| Île 06 ↔ Île 07 | 1 250 m |
| Île 07 ↔ Île 08 | 1 350 m |
| Île 08 ↔ Île 09 | 1 100 m |
| Île 09 ↔ Île 10 | 1 400 m |
| Île 10 ↔ Île 11 | 1 500 m |

La règle générale est donc : **environ 700 m à 1,5 km de mer ouverte entre deux royaumes voisins**.

### Conséquences obligatoires pour le gameplay

- Les déplacements entre royaumes doivent se faire réellement en bateau, sans écran de téléportation automatique.
- Les traversées maritimes doivent contenir de l’activité : navires marchands, pirates, équipages indépendants, pêcheurs, faune marine, épaves, météo et événements aléatoires.
- Les îles doivent apparaître progressivement à l’horizon. Leurs repères majeurs doivent être visibles avant l’arrivée lorsque la météo le permet.
- La mer ne doit pas ressembler à un simple couloir entre deux niveaux : le joueur doit pouvoir s’écarter de la route directe pour explorer, combattre ou chercher des secrets.
- Les zones côtières, ports et points d’accostage doivent être conçus à l’échelle des distances réelles.

### Streaming et optimisation Android

La grande taille du monde ne signifie jamais que tout doit être chargé simultanément.

- Découper les îles en cellules d’environ **250 × 250 m**.
- Regrouper les cellules en macro-secteurs jusqu’à **500 × 500 m** pour l’organisation du monde.
- Charger en détail uniquement les secteurs proches du joueur.
- Décharger les PNJ, collisions complexes, intérieurs et objets interactifs éloignés.
- Employer plusieurs niveaux de détail pour bâtiments, végétation, bateaux et reliefs.
- Les îles éloignées doivent utiliser des silhouettes/meshes très simplifiés jusqu’à l’approche.
- Les routes maritimes doivent utiliser le même principe de streaming afin que les navires et événements éloignés n’occupent pas inutilement la mémoire.
- Éviter les murs invisibles autour des îles ; les limites du monde doivent être placées largement au-delà de l’archipel ou justifiées par le scénario.
<!-- WORLD_SCALE_END -->

## 3. Contenu obligatoire de chaque île

Chaque île doit comporter :

- une grande ville, un village ou une capitale ;
- des habitants et des PNJ avec leurs propres activités ;
- des soldats protégeant le royaume ;
- plusieurs types d’ennemis ;
- des animaux terrestres et marins ;
- un ou plusieurs boss ;
- des quêtes principales et secondaires ;
- des marchands, artisans et lieux de repos ;
- des ports et des zones d’accostage ;
- des grottes, temples, ruines ou passages secrets ;
- des objets rares et des récompenses ;
- des événements aléatoires ;
- des zones naturelles : plages, forêts, plaines, montagnes, falaises ou rivières.

Les îles ne doivent pas être de simples niveaux vides. Elles doivent contenir de la vie, des déplacements, des conversations, des combats et des événements visibles même lorsque le joueur n’intervient pas.

## 4. Les trois équipages indépendants

Le monde contient **trois équipages autonomes**, qui ne sont ni totalement amis ni totalement ennemis.

Chaque équipage :

- possède son propre bateau ;
- possède un capitaine et plusieurs membres ;
- voyage librement entre les royaumes ;
- peut commercer, explorer, combattre ou chercher des trésors ;
- peut aider le joueur dans certaines situations ;
- peut également attaquer ou gêner le joueur ;
- prend ses propres décisions selon ses objectifs ;
- peut entrer en conflit avec les soldats, les pirates ou les autres équipages.

Le comportement des équipages ne doit pas être fixé définitivement. Une rencontre peut être pacifique, tendue ou hostile selon les actions du joueur et les événements du monde.

## 5. Vie maritime

La mer est une partie essentielle du jeu et ne doit pas être vide.

Le joueur doit pouvoir y rencontrer :

- des bateaux marchands ;
- des navires militaires ;
- des pirates ;
- les trois équipages indépendants ;
- des pêcheurs ;
- des créatures marines ;
- des épaves ;
- des tempêtes ;
- des trésors flottants ;
- des batailles navales ;
- des événements aléatoires et des appels de détresse.

Chaque bateau important doit pouvoir se déplacer, accoster, poursuivre une cible, fuir ou participer à un combat naval.

## 6. Progression du joueur

Le joueur progresse en :

- explorant les royaumes ;
- accomplissant des quêtes ;
- affrontant les boss ;
- découvrant des lieux secrets ;
- améliorant son personnage ;
- recrutant ou rencontrant de nouveaux alliés ;
- améliorant son bateau ;
- récupérant des armes, équipements et objets rares.

L’accès à l’île finale doit être obtenu après avoir accompli plusieurs objectifs majeurs dans les dix premiers royaumes.

## 7. Monde vivant et évolutif

Le jeu doit intégrer :

- un cycle jour et nuit ;
- une météo dynamique ;
- des habitants avec des routines ;
- des animaux qui se déplacent naturellement ;
- des soldats qui patrouillent ;
- des ennemis qui protègent leur territoire ;
- des bateaux qui circulent réellement entre les îles ;
- des événements qui peuvent apparaître sans être déclenchés directement par le joueur.

Les royaumes doivent continuer à vivre même lorsque le joueur se trouve ailleurs.

## 8. Règles importantes pour les développeurs et agents

- Ne jamais réduire les royaumes à de petites zones fermées.
- Chaque île doit être vaste, différente et reconnaissable immédiatement.
- La mer doit contenir autant d’activité que les îles.
- Les PNJ ne doivent pas rester immobiles sans fonction.
- Les trois équipages doivent être autonomes et imprévisibles.
- Les boss doivent avoir une apparence, des attaques et une histoire propres.
- L’exploration doit toujours être récompensée.
- Le joueur doit pouvoir choisir son chemin et son ordre d’exploration.
- L’île finale ne doit être accessible qu’après une progression importante.
- Tous les systèmes ajoutés doivent rester optimisés pour Android et mobile.

## Objectif final

Créer un véritable monde d’aventure maritime dans lequel le joueur ressent qu’il voyage entre **onze royaumes immenses, vivants et uniques**, jusqu’à découvrir le secret de l’île finale et obtenir l’objet rare qui marque la conclusion du jeu.
