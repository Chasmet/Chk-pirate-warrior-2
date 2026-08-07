# Notice de conception — Île 10 : Royaume de la terre

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel royaume 10.jpg`. Le soldat déjà présent est `Shelly solda .glb`.

## Identité générale

Le Royaume de la terre est une île massive, ancienne et minérale. Elle doit évoquer la puissance du sol, des montagnes, des canyons et des civilisations bâties directement dans la roche. Contrairement au Royaume de feu, la menace principale vient ici des séismes, des éboulements, des falaises, des cavernes et des gardiens de pierre.

L’île doit sembler stable et imposante à première vue, puis révéler un sous-sol immense, fragile et rempli de vestiges.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 10.

- **Dimension cible de l’île : 2,6 km × 2,0 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **18 à 26 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 09 (royaume précédent) : **1 400 m entre les côtes navigables**.
- Mer ouverte vers l’Île 11 (royaume suivant) : **1 500 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Grandes falaises en terrasses visibles depuis la mer.
- Chaîne de montagnes occupant le centre de l’île.
- Canyons profonds traversés par des ponts de pierre.
- Plateaux agricoles protégés du vent.
- Forêt sèche et vallées plus verdoyantes.
- Réseau de grottes, mines et temples souterrains.
- Arches naturelles et statues taillées dans les montagnes.
- Ancienne carrière devenue arène.
- Rivière souterraine alimentant la capitale.
- Littoral rocheux avec plusieurs ports creusés dans la falaise.

La verticalité doit être importante, avec escalade, ascenseurs anciens, passages souterrains et raccourcis débloqués.

## Météo et lumière

Le climat est sec sur les plateaux et plus humide dans les vallées.

- Vent chargé de poussière dans les canyons.
- Tempêtes de sable et de gravier.
- Pluies rares mais violentes provoquant des coulées de boue.
- Brouillard dans les vallées profondes.
- Séismes légers et réguliers.
- Orages faisant tomber des pierres sur les routes exposées.
- Lumière dorée au lever et au coucher du soleil.
- Obscurité presque totale dans les zones souterraines non équipées.

La météo et les séismes doivent ouvrir, fermer ou modifier certains chemins sans bloquer définitivement la progression.

## Flore et faune

### Flore

- Arbustes résistants au vent.
- Pins de montagne et arbres aux racines profondes.
- Cactus et plantes grasses sur les plateaux secs.
- Mousses et fougères dans les grottes humides.
- Fleurs minérales poussant près des cristaux.
- Cultures en terrasses autour des villages.

### Faune

- Chèvres de montagne.
- Aigles et vautours dans les falaises.
- Tatous et grands rongeurs fouisseurs.
- Taupes géantes dans les tunnels.
- Sangliers dans les vallées.
- Chauves-souris et insectes cavernicoles.
- Tortues rocheuses et petits golems naturels.
- Poissons aveugles dans les rivières souterraines.

La faune doit réagir aux séismes, chercher des abris et révéler parfois la présence de passages cachés.

## Population et architecture

La capitale, **Terracime**, est construite dans une montagne en gradins.

- Palais taillé dans la roche.
- Quartier des tailleurs de pierre.
- Mines et ateliers de métallurgie.
- Temple souterrain de l’ancienne civilisation.
- Marché installé sur plusieurs terrasses.
- Casernes surveillant les ponts et les tunnels.
- Villages agricoles sur les plateaux.
- Cité minière profonde reliée par des ascenseurs.
- Port creusé directement dans la falaise.

Les habitants doivent extraire, tailler, transporter, cultiver, réparer les routes et surveiller les mouvements du sol.

## Ennemis, soldats et boss

Le soldat `Shelly solda .glb` doit servir de référence à une unité mobile et résistante, capable de combattre dans les canyons et les tunnels.

Types d’ennemis recommandés :

- soldats de pierre ;
- mineurs rebelles ;
- golems anciens ;
- créatures fouisseuses ;
- archers placés sur les falaises ;
- gardiens des temples ;
- pillards cherchant les minerais rares.

Le boss principal reste à créer. Il doit être un titan de pierre, un souverain souterrain ou un gardien réveillé par les séismes. Son combat doit utiliser des murs qui se déplacent, des piliers qui tombent, des vagues de terre et des phases souterraines.

## Gameplay, quêtes et exploration

- Secourir des mineurs après un effondrement.
- Réparer un pont détruit par un séisme.
- Explorer une cité ensevelie.
- Suivre une rivière souterraine jusqu’à une zone secrète.
- Escalader les falaises pour atteindre un temple.
- Choisir entre plusieurs factions minières.
- Protéger un village contre des créatures fouisseuses.
- Réactiver des ascenseurs et mécanismes anciens.
- Trouver des minerais servant à améliorer armes, armures et bateau.
- Stabiliser le cœur géologique de l’île avant le combat final.

## Approche maritime

Les côtes sont hautes et difficiles d’accès. Le joueur doit repérer les ports creusés dans la falaise, les plages cachées et les passages entre les récifs. Des navires miniers et cargos transportent la pierre et les métaux vers les autres royaumes.

## Ambiance sonore

Utiliser des percussions profondes, sons de roche, échos de grottes, outils de mine et grondements souterrains. Les craquements doivent annoncer clairement un effondrement ou un séisme proche.

## Règles de réalisation

- Donner une vraie profondeur au sous-sol avec plusieurs niveaux reliés.
- Éviter les couloirs souterrains répétitifs : varier temples, mines, rivières, grottes et cités.
- Les destructions de terrain doivent être contrôlées et prédéfinies pour rester performantes.
- Prévoir des repères visuels clairs dans les canyons et les grottes.
- Optimiser les grandes vues, ombres et particules de poussière pour Android.
