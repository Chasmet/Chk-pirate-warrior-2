# Notice de conception — Île 07 : Île des pirates

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel royaume 7.jpg`. Le boss déjà présent est `baggy boss .glb`.

## Identité générale

L’Île des pirates est le royaume le plus directement lié à la vie maritime, aux équipages, aux trésors et aux batailles navales. Elle doit être dangereuse, bruyante, libre et imprévisible. Plusieurs factions pirates y cohabitent sans véritable autorité centrale.

L’île doit immédiatement se distinguer par sa grande baie, ses épaves, ses tavernes, son fort, ses falaises, ses grottes et ses nombreux navires au mouillage.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 07.

- **Dimension cible de l’île : 2,4 km × 1,8 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **16 à 24 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 06 (royaume précédent) : **1 250 m entre les côtes navigables**.
- Mer ouverte vers l’Île 08 (royaume suivant) : **1 350 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Grande baie en forme de crâne servant de port principal.
- Falaises hautes abritant canons, forts et postes d’observation.
- Jungle tropicale dense au centre de l’île.
- Mangroves et marais au sud.
- Grottes marines accessibles uniquement à marée basse.
- Réseau de tunnels de contrebandiers.
- Plages cachées servant de points d’accostage clandestins.
- Anciennes ruines contenant des cartes et mécanismes de trésor.
- Récifs dangereux et épaves autour des côtes.
- Petite montagne centrale visible depuis le large.

La carte doit favoriser les raccourcis, les passages secrets et les itinéraires de fuite.

## Météo et lumière

Le climat est tropical et très maritime.

- Fort soleil et humidité élevée.
- Averses rapides dans la jungle.
- Brouillard côtier au lever du jour.
- Orages tropicaux et vents violents.
- Tempêtes capables de modifier la mer et de déplacer certaines épaves.
- Cyclones rares déclenchant de grands événements mondiaux.
- Marées influençant l’accès aux grottes et aux plages.

La météo doit modifier la navigation, la visibilité, les patrouilles et certains trésors accessibles.

## Flore et faune

### Flore

- Palmiers, mangroves et lianes.
- Plantes médicinales utilisées par les équipages.
- Fleurs toxiques dans les marais.
- Arbres géants servant de points d’observation.
- Champignons lumineux dans les tunnels.

### Faune

- Perroquets, mouettes et oiseaux marins.
- Singes voleurs dans la jungle.
- Crocodiles dans les mangroves.
- Sangliers et serpents sur terre.
- Requins, raies, tortues et dauphins autour des côtes.
- Baleines visibles au large.
- Crabes géants dans certaines grottes.

La faune doit réagir aux tirs de canon, aux tempêtes et à la présence des navires.

## Population et architecture

La ville principale, **Port-Franc**, est une cité portuaire construite sans plan régulier.

- Grand port rempli de navires et de chantiers.
- Tavernes, auberges et salles de jeu.
- Marché noir et vendeurs de cartes.
- Quartier des réparateurs de bateaux.
- Fort principal dominant la baie.
- Prison et entrepôts de marchandises volées.
- Quartiers contrôlés par différents capitaines.
- Village de pêcheurs neutre à l’écart de la ville.
- Repaires secrets dans les falaises et la jungle.

Les PNJ doivent boire, jouer, commercer, se battre, embarquer, décharger des cargaisons et diffuser des rumeurs.

## Ennemis et boss

Types d’ennemis recommandés :

- pirates ordinaires ;
- tireurs installés sur les toits ;
- capitaines de petites factions ;
- gardes du fort ;
- contrebandiers ;
- chasseurs de primes ;
- bêtes sauvages dans les zones naturelles ;
- équipages ennemis arrivant par bateau.

Le boss `baggy boss .glb` contrôle une partie du port et plusieurs navires. Son combat doit être spectaculaire, mobile et trompeur. Il peut utiliser des attaques à distance, des pièges, des canons, des faux doubles et des éléments de décor. Une phase du combat peut se dérouler sur un bateau quittant le port.

## Gameplay, quêtes et exploration

- Reconstituer plusieurs cartes au trésor.
- Gagner la confiance ou la haine de différentes factions.
- Participer à des batailles navales.
- Infiltrer le fort par plusieurs chemins.
- Libérer des prisonniers ou capturer un capitaine.
- Explorer des épaves sous-marines.
- Suivre des rumeurs entendues dans les tavernes.
- Défendre un village contre une attaque pirate.
- Voler ou protéger une cargaison rare.
- Découvrir un trésor majeur caché sous la montagne.

Les décisions du joueur doivent modifier la réaction des factions et la sécurité du port.

## Approche maritime

La zone maritime autour de l’île doit être particulièrement dense : navires pirates, marchands, patrouilles, pêcheurs, épaves, monstres marins et batailles aléatoires. L’arrivée ne doit jamais sembler vide.

## Ambiance sonore

Musique pirate énergique dans le port, percussions et chants dans les tavernes, ambiance plus tendue dans la jungle et les grottes. La mer, les cordages, les canons et les équipages doivent être audibles sans masquer les informations importantes.

## Règles de réalisation

- Le bateau du joueur doit être pleinement utilisable autour de l’île.
- Prévoir plusieurs points d’accostage officiels et clandestins.
- Faire circuler réellement des équipages entre le port, les tavernes et les navires.
- Utiliser les tempêtes et les marées comme mécaniques, pas seulement comme effets visuels.
- Optimiser la densité des navires et PNJ selon la distance pour Android.
