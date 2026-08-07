# Notice de conception — Île 03 : Royaume de la nourriture

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel royaume 3.jpg`. Les personnages déjà présents sont `goku boss.png` et `solda 1 er commandant de goku.png`.

## Identité générale

Le Royaume de la nourriture est une île fertile et très peuplée, organisée autour de cultures géantes, de marchés, de cuisines monumentales et de régions inspirées de différentes traditions culinaires. Il doit donner l’impression d’un territoire abondant, chaud, animé et indispensable aux autres royaumes.

L’île ne doit pas être une copie du Royaume de la sucrerie : ici, l’identité repose sur les aliments complets, les cultures, les épices, la cuisson, les marchés et la diversité des cuisines.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 03.

- **Dimension cible de l’île : 1,5 km × 1,2 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **10 à 15 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 02 (royaume précédent) : **850 m entre les côtes navigables**.
- Mer ouverte vers l’Île 04 (royaume suivant) : **1 000 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Grandes plaines agricoles traversées par des canaux d’irrigation.
- Collines de pain et plateaux de céréales.
- Rizières en terrasses sur les pentes humides.
- Forêts d’arbres fruitiers géants.
- Lacs de bouillon chaud alimentés par des sources souterraines.
- Marmites volcaniques et cheminées de vapeur dans les hauteurs.
- Vallée des épices où le vent transporte des poudres colorées.
- Côte poissonneuse avec villages de pêcheurs et marchés flottants.
- Réseau de caves servant de réserves, de chambres froides et de passages secrets.

La capitale doit être construite autour du **Grand Marché**, véritable cœur économique du royaume.

## Météo et lumière

Le climat est chaud et fertile, avec plusieurs microclimats.

- Soleil généreux dans les plaines.
- Mousson saisonnière remplissant les canaux et les rizières.
- Brouillard de vapeur près des zones de cuisson naturelle.
- Tempêtes d’épices réduisant la visibilité et irritant les personnages non protégés.
- Orages tropicaux sur les côtes.
- Nuits fraîches dans les montagnes et les réserves souterraines.

La météo doit influencer les récoltes, les déplacements, les prix du marché et certaines quêtes.

## Flore et faune

### Flore

- Céréales géantes, rizières, vergers et potagers.
- Arbres à fruits tropicaux.
- Plantes aromatiques et médicinales.
- Lianes de haricots servant parfois de chemins verticaux.
- Champignons comestibles ou toxiques dans les grottes.

### Faune

- Bœufs de trait, chèvres, volailles et animaux d’élevage.
- Sangliers sauvages dans les vergers.
- Singes voleurs de fruits.
- Oiseaux migrateurs dans les rizières.
- Poissons géants, crabes et tortues marines près des côtes.
- Insectes pollinisateurs indispensables aux cultures.

Les animaux doivent interagir avec les habitants, les cultures et les prédateurs.

## Population et architecture

La capitale, **Grand-Gourmand**, est divisée en quartiers culinaires reliés au marché central.

- Halles couvertes et marchés de rue.
- Grandes cuisines publiques.
- Quartier des boulangers, des pêcheurs, des bouchers et des épiciers.
- Entrepôts, silos et réserves.
- Auberges proposant des bonus différents selon les plats.
- École des cuisiniers et laboratoire des saveurs.
- Port commercial très fréquenté.
- Villages agricoles avec moulins, granges et systèmes d’irrigation.

Les PNJ doivent cultiver, transporter, vendre, cuisiner, nettoyer, négocier et participer aux fêtes.

## Ennemis, commandant et boss

Le premier commandant est représenté par `solda 1 er commandant de goku.png`. Il dirige les forces qui contrôlent les routes commerciales et les réserves.

Types d’ennemis recommandés :

- pillards des récoltes ;
- soldats protégeant les entrepôts ;
- bêtes affamées attirées par les marchés ;
- cuisiniers de combat utilisant le feu, la vapeur et les couteaux ;
- créatures nées des marmites volcaniques ;
- contrebandiers contrôlant les ports secondaires.

Le boss actuel est représenté par `goku boss.png`. Son combat doit se dérouler dans une grande arène de cuisson entourée de marmites volcaniques. Il utilise sa force, des déplacements rapides, des ondes d’énergie et l’environnement. Le commandant intervient dans l’histoire avant l’affrontement final.

## Gameplay, quêtes et exploration

- Réparer les canaux après une tempête.
- Protéger une récolte contre des pillards.
- Escorter des convois alimentaires vers le port.
- Participer à un tournoi de cuisine et de combat.
- Réunir des ingrédients rares dans plusieurs biomes.
- Résoudre une pénurie provoquée par le blocage des réserves.
- Découvrir des recettes donnant des améliorations temporaires ou permanentes.
- Explorer les réserves souterraines et les cuisines anciennes.
- Choisir entre plusieurs factions commerciales aux intérêts opposés.

## Approche maritime

La côte doit être très active : bateaux de pêche, cargos alimentaires, marchés flottants, navires militaires et pirates. L’arrivée par le port principal doit montrer immédiatement l’importance économique de l’île.

## Ambiance sonore

Les villes utilisent des percussions, des instruments chaleureux, des bruits de marché et de cuisine. Les campagnes doivent être plus calmes, avec vent, animaux, eau et outils agricoles. Les zones volcaniques utilisent vapeur, grondements et métal chauffé.

## Règles de réalisation

- Montrer une vraie chaîne de production entre champs, villages, marchés, cuisines et bateaux.
- Éviter les décors alimentaires uniquement décoratifs : chaque région doit avoir une logique et une fonction.
- Prévoir des routines de PNJ nombreuses mais optimisées par distance.
- Limiter les particules de vapeur et les foules complètes sur Android.
- Les repas et recettes doivent servir au gameplay sans devenir une gestion trop complexe.
