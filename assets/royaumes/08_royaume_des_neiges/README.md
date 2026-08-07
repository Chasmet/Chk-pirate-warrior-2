# Notice de conception — Île 08 : Royaume des neiges

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel royaume 8.jpg`. Le soldat déjà présent est `solda pharaon.glb`.

## Identité générale

Le Royaume des neiges est une île glacée construite sur les vestiges d’une ancienne civilisation royale. Le visuel doit mélanger banquise, montagnes, temples gelés, pyramides de glace, statues ensevelies et villages protégés du froid.

La présence du modèle `solda pharaon.glb` impose une identité particulière : le royaume ne doit pas être une simple zone polaire, mais une civilisation ancienne figée dans la glace, gardée par des soldats inspirés des pharaons.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 08.

- **Dimension cible de l’île : 2,2 km × 1,8 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **15 à 22 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 07 (royaume précédent) : **1 350 m entre les côtes navigables**.
- Mer ouverte vers l’Île 09 (royaume suivant) : **1 100 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Banquise côtière traversée de fissures.
- Hautes montagnes enneigées entourant le centre de l’île.
- Glacier principal descendant jusqu’à la mer.
- Vallée des pyramides gelées.
- Désert blanc où des dunes de neige recouvrent des ruines.
- Grottes de cristal bleu sous le glacier.
- Lac gelé pouvant se fissurer sous le poids ou pendant un combat.
- Cité souterraine ancienne protégée du vent.
- Falaises offrant des chemins verticaux et des points de vue.
- Petits villages reliés par des tunnels, ponts de corde et traîneaux.

## Météo et lumière

Le climat est extrêmement froid et changeant.

- Neige légère dans les zones habitées.
- Blizzards réduisant presque totalement la visibilité.
- Vent violent sur les sommets et la banquise.
- Brouillard glacé dans les vallées.
- Aurores boréales révélant des symboles ou chemins secrets.
- Pluie verglaçante rendant certaines surfaces très glissantes.
- Craquements du glacier annonçant des effondrements.
- Courtes périodes de soleil très lumineux produisant une forte réverbération.

La météo influence la température du joueur, les traces dans la neige, les déplacements des animaux et l’accès à certaines régions.

## Flore et faune

### Flore

- Pins couverts de givre.
- Lichens et mousses résistantes au froid.
- Fleurs de glace rares utilisées pour les soins.
- Arbustes protégés dans les vallées.
- Champignons lumineux dans les grottes.

### Faune

- Loups blancs vivant en meutes.
- Ours polaires et grands félins des neiges.
- Mammouths ou grands herbivores anciens.
- Chèvres de montagne.
- Hiboux, corbeaux et oiseaux migrateurs.
- Phoques et morses sur les côtes.
- Baleines et créatures marines sous la banquise.
- Scarabées de glace autour des temples anciens.

Les animaux doivent chercher des abris pendant les tempêtes et laisser des traces exploitables par le joueur.

## Population et architecture

La capitale, **Néferglace**, est partiellement construite sous la montagne pour se protéger du climat.

- Palais gelé inspiré d’une ancienne dynastie.
- Pyramides et temples pris dans la glace.
- Quartier troglodyte chauffé par des sources chaudes.
- Marché couvert.
- Casernes des soldats-pharaons.
- Archives anciennes contenant l’histoire du royaume.
- Port renforcé contre les glaces dérivantes.
- Villages de chasseurs, pêcheurs et mineurs de cristal.

Les habitants doivent couper du bois, entretenir les feux, pêcher sous la glace, déplacer des provisions et se réfugier à l’approche des blizzards.

## Ennemis, soldats et boss

Le soldat `solda pharaon.glb` représente la garde ancienne réveillée par les perturbations du royaume.

Types d’ennemis recommandés :

- soldats-pharaons gelés ;
- archers de glace ;
- momies couvertes de givre ;
- golems de cristal ;
- loups corrompus ;
- esprits du blizzard ;
- pillards cherchant les trésors des tombeaux.

Le boss principal reste à créer. Il doit être un souverain ancien, un gardien de glacier ou une créature royale réveillée dans la pyramide centrale. Son combat doit utiliser le froid, le vent, les murs de glace, les fissures du sol et les avalanches.

## Gameplay, quêtes et exploration

- Retrouver des habitants disparus pendant un blizzard.
- Réparer les systèmes de chauffage d’un village.
- Explorer une pyramide libérée par le recul du glacier.
- Suivre des traces d’animaux ou de soldats dans la neige.
- Traverser une banquise qui se fracture.
- Libérer les esprits enfermés dans les statues.
- Protéger un convoi de provisions.
- Réactiver des miroirs solaires anciens.
- Découvrir une source chaude cachée donnant accès à la cité souterraine.

## Approche maritime

La navigation autour de l’île doit être dangereuse à cause des icebergs, de la glace dérivante, du brouillard et des créatures marines. Le joueur doit parfois ralentir, contourner un passage ou utiliser un itinéraire ouvert temporairement.

## Ambiance sonore

Vent, craquements de glace, neige étouffant les pas et chants anciens doivent dominer. La musique mélange chœurs, percussions lentes et instruments cristallins. Pendant un blizzard, les sons proches deviennent difficiles à localiser.

## Règles de réalisation

- Conserver l’identité de civilisation pharaonique gelée.
- Ne pas utiliser uniquement du blanc : ajouter pierre, or ancien, bleu profond et lumière chaude dans les zones habitées.
- Prévoir un système de froid simple et compréhensible.
- Limiter les particules de neige selon les performances Android.
- Les tempêtes doivent modifier réellement le comportement des PNJ, animaux et ennemis.
