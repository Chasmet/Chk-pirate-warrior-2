# Notice de conception — Île 09 : Royaume de feu

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel royaume 9.jpg`. Les assets déjà présents sont `boss Sangoku.glb` et `logan 1 er commandant de goku.glb`.

## Identité générale

Le Royaume de feu est une île volcanique hostile, dominée par la lave, les cendres, les citadelles noires et une population habituée à vivre sous la menace permanente des éruptions. Le territoire doit paraître dangereux dès l’approche en mer, avec une lueur rouge visible la nuit et un panache de fumée au-dessus du volcan central.

L’île ne doit pas être entièrement morte : des villes fortifiées, des oasis thermales, des mines, une végétation résistante et une faune adaptée au feu doivent montrer qu’un véritable royaume y survit.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 09.

- **Dimension cible de l’île : 2,3 km × 1,8 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **15 à 22 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 08 (royaume précédent) : **1 100 m entre les côtes navigables**.
- Mer ouverte vers l’Île 10 (royaume suivant) : **1 400 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Volcan central gigantesque entouré de plusieurs cratères secondaires.
- Rivières de lave modifiant certains chemins.
- Plaines de cendres et dunes de scories.
- Falaises d’obsidienne coupantes.
- Forêts brûlées où repoussent des plantes rouges et noires.
- Grottes de magma et anciennes mines.
- Sources chaudes et bassins thermaux dans les zones plus stables.
- Citadelle principale construite sur un plateau rocheux.
- Tunnels de refroidissement sous la ville.
- Côte noire avec plages de sable volcanique et arches de basalte.

## Météo et lumière

Le climat est sec, brûlant et instable.

- Chaleur intense près des coulées de lave.
- Pluie de cendres réduisant la visibilité.
- Tempêtes de poussière rouge.
- Orages volcaniques avec éclairs dans les nuages de cendres.
- Projections de pierres lors des éruptions.
- Vents brûlants accélérant la propagation des incendies.
- Nuits éclairées par la lave et les fissures du sol.

La météo doit influencer un indicateur de chaleur, la visibilité, la résistance des équipements et les déplacements des ennemis.

## Flore et faune

### Flore

- Palmiers de braise près des sources chaudes.
- Herbes rouges résistantes à la chaleur.
- Fleurs de cendre utilisées pour fabriquer des protections.
- Champignons thermiques dans les grottes.
- Arbres noirs dont les racines poussent entre les roches chaudes.

### Faune

- Lézards et salamandres de feu.
- Tortues à carapace volcanique.
- Rapaces vivant dans les courants chauds.
- Chèvres de roche sur les falaises.
- Dragons ou grands reptiles de magma dans les zones interdites.
- Poissons thermaux dans les bassins chauds.
- Insectes lumineux autour des fissures.

Les animaux doivent fuir avant une éruption et se regrouper dans les zones sûres.

## Population et architecture

La capitale, **Pyrocité**, est bâtie en pierre sombre et protégée par des canaux de refroidissement.

- Citadelle noire dominant la ville.
- Quartier des forgerons utilisant la chaleur naturelle.
- Mines d’obsidienne et de minerais rares.
- Marché couvert protégeant les habitants des cendres.
- Casernes et tours de surveillance.
- Sanctuaire du volcan.
- Villages miniers sur les pentes.
- Port taillé dans le basalte.
- Réseau d’abris souterrains pour les éruptions.

Les habitants doivent entretenir les canaux, travailler dans les forges, surveiller le volcan, évacuer lors des alertes et reconstruire après les dégâts.

## Ennemis, commandant et boss

Le premier commandant est représenté par `logan 1 er commandant de goku.glb`. Il contrôle les troupes protégeant l’accès à la citadelle et au volcan.

Types d’ennemis recommandés :

- soldats en armure thermique ;
- mineurs corrompus ;
- golems de lave ;
- lézards géants ;
- mages du feu ;
- archers utilisant des projectiles explosifs ;
- esprits de cendre.

Le boss `boss Sangoku.glb` doit combattre dans une arène située au bord du cratère. Le combat comporte plusieurs phases : affrontement sur terrain stable, montée de la lave, destruction de plateformes, pluie de roches et phase finale au-dessus du magma. Sa puissance doit sembler liée à l’énergie du volcan.

## Gameplay, quêtes et exploration

- Réparer un canal de refroidissement avant une éruption.
- Évacuer un village menacé par une coulée de lave.
- Escorter des mineurs vers une galerie instable.
- Forger un équipement résistant à la chaleur.
- Explorer des tunnels accessibles uniquement après refroidissement.
- Fermer des fissures libérant des créatures.
- Saboter ou protéger les installations du commandant.
- Traverser une tempête de cendres avec visibilité limitée.
- Découvrir un ancien temple sous le volcan.

## Approche maritime

La mer autour de l’île est réchauffée, chargée de vapeur et traversée de rochers volcaniques. Des coulées de lave atteignent parfois l’océan. Les navires militaires, miniers et marchands doivent circuler malgré les risques.

## Ambiance sonore

Grondements sourds, crépitements, vent chargé de cendres et chocs métalliques dominent. La musique utilise percussions lourdes, cuivres et textures tendues. Les signes d’éruption doivent être clairement audibles avant le danger.

## Règles de réalisation

- Préserver des zones habitées crédibles au milieu du danger.
- Utiliser la lave comme mécanique dynamique sans multiplier les simulations coûteuses.
- Prévoir plusieurs niveaux de qualité pour fumée, cendres et chaleur sur Android.
- Les alertes volcaniques doivent laisser au joueur le temps de réagir.
- Varier les couleurs avec obsidienne, métal, braises, vapeur et éclairages froids dans les abris.
