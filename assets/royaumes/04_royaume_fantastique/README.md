# Notice de conception — Île 04 : Royaume fantastique

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel ile 4 royaume fantastique.png`. Les assets déjà présents sont `boss ile 4.glb`, `1 er commandant robot.glb` et `walli.png`.

## Identité générale

Le Royaume fantastique mélange magie ancienne, nature enchantée et technologie oubliée. L’île doit être immédiatement reconnaissable grâce à ses châteaux flottants, ses cristaux géants, ses forêts lumineuses, ses portails et ses machines anciennes encore actives.

L’identité ne doit pas être uniquement médiévale : la présence du commandant robot et de Walli impose une civilisation hybride où magie et mécanique coexistent.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 04.

- **Dimension cible de l’île : 1,7 km × 1,4 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **12 à 17 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 03 (royaume précédent) : **1 000 m entre les côtes navigables**.
- Mer ouverte vers l’Île 05 (royaume suivant) : **1 150 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Grande forêt enchantée occupant la partie basse de l’île.
- Chaîne de montagnes de cristal traversant le centre.
- Îlots et forteresses flottant au-dessus des vallées.
- Lac miroir reflétant parfois un autre ciel ou une autre époque.
- Ruines d’une ancienne civilisation mécanique.
- Vallée des portails reliant des zones éloignées.
- Gouffres où la gravité devient instable.
- Grottes de mana et mines de cristaux.
- Côte bordée de statues géantes et de quais anciens.

Le château principal doit être visible depuis plusieurs régions et servir de repère majeur.

## Météo et lumière

Le climat varie selon les concentrations de magie.

- Aurores de mana visibles même en journée.
- Pluie lumineuse faisant pousser certaines plantes.
- Brouillard violet dans les forêts profondes.
- Orages de portails déplaçant temporairement des objets ou des créatures.
- Vents inversés faisant monter les feuilles et les pierres.
- Nuits très claires grâce aux cristaux et aux animaux bioluminescents.

La météo peut modifier la gravité, activer des machines et ouvrir des portails temporaires.

## Flore et faune

### Flore

- Arbres géants aux feuilles lumineuses.
- Fleurs de mana réagissant aux pouvoirs du joueur.
- Lianes mobiles ouvrant ou bloquant des passages.
- Champignons servant de plateformes rebondissantes.
- Cristaux végétaux poussant près des ruines.

### Faune

- Cerfs lumineux et renards-esprits.
- Griffons dans les montagnes.
- Petits dragons dans les grottes chaudes.
- Oiseaux de cristal capables de traverser certains portails.
- Insectes mécaniques réparant les ruines.
- Golems et automates considérés comme une faune artificielle.

Certaines créatures sont pacifiques, d’autres territoriales. Les animaux magiques doivent avoir des comportements spécifiques selon l’heure et la météo.

## Population et architecture

La capitale, **Aetheria**, est construite sur plusieurs plateformes reliées par des ponts magiques et des ascenseurs mécaniques.

- Château flottant du souverain.
- Quartier des mages et alchimistes.
- Atelier des ingénieurs et réparateurs d’automates.
- Marché des cristaux et objets enchantés.
- Bibliothèque suspendue.
- Village forestier protégé par des esprits.
- Cité mécanique abandonnée sous la montagne.
- Port utilisant des grues enchantées.

Les habitants doivent pratiquer la magie, réparer des machines, récolter des cristaux et voyager par portail.

## Ennemis, commandant et boss

Le premier commandant est représenté par `1 er commandant robot.glb`. Il contrôle les automates anciens et peut verrouiller des zones entières.

Types d’ennemis recommandés :

- gardiens de cristal ;
- mages corrompus ;
- automates défectueux ;
- bêtes enchantées agressives ;
- chevaliers flottants ;
- créatures sorties de portails instables.

`walli.png` doit servir de référence pour un petit robot allié ou neutre capable d’aider le joueur à réparer certaines machines.

Le boss `boss ile 4.glb` doit combiner magie et technologie. Son arène se trouve dans une forteresse flottante instable. Le combat comporte des changements de gravité, des portails, des attaques de cristal et des automates invoqués.

## Gameplay, quêtes et exploration

- Réparer Walli pour accéder aux ruines mécaniques.
- Stabiliser les portails reliant les régions.
- Libérer une forêt envahie par une magie corrompue.
- Réactiver les ascenseurs de la montagne de cristal.
- Choisir entre une faction de mages et une faction d’ingénieurs.
- Résoudre des énigmes mêlant énergie, symboles, miroirs et gravité.
- Apprivoiser ou aider certaines créatures fantastiques.
- Explorer les forteresses flottantes et les gouffres inversés.
- Récupérer des fragments de technologie pour améliorer le bateau.

## Approche maritime

L’île doit apparaître comme une masse lumineuse entourée de petits rochers flottants. Des portails peuvent parfois s’ouvrir au-dessus de la mer. Le port principal accueille des navires classiques, des barges magiques et des machines volantes.

## Ambiance sonore

Mélanger orchestre fantastique, chœurs discrets, sons de cristal et bruits mécaniques. Les zones naturelles doivent rester aérées, tandis que les ruines utilisent des bourdonnements, impulsions et sons métalliques.

## Règles de réalisation

- Maintenir un équilibre clair entre magie et technologie.
- Utiliser les effets lumineux avec modération pour conserver de bonnes performances Android.
- Les portails doivent être lisibles et ne pas désorienter inutilement le joueur.
- Prévoir des repères visuels permanents malgré les changements de gravité.
- Les zones flottantes doivent sembler reliées à un monde cohérent, pas à une succession de plateformes isolées.
