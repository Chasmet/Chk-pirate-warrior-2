# Notice de conception — Île 02 : Royaume de la sucrerie

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel ile 2.png`. Le boss déjà présent est `boss gardien du fromage.glb`.

## Identité générale

Le Royaume de la sucrerie est une île colorée, accueillante en apparence, mais remplie de dangers liés au sucre, à la chaleur et aux matières collantes. Sa silhouette doit être immédiatement identifiable grâce à ses montagnes de bonbons, ses tours pâtissières, ses forêts de sucettes et ses rivières de chocolat.

L’ambiance commence légère et merveilleuse, puis devient plus étrange dans les zones industrielles, les caves de fermentation et les marais de caramel.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 02.

- **Dimension cible de l’île : 1,3 km × 1,1 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **9 à 13 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 01 (royaume précédent) : **700 m entre les côtes navigables**.
- Mer ouverte vers l’Île 03 (royaume suivant) : **850 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Côte rose et blanche composée de sable sucré et de rochers cristallisés.
- Montagnes de sucre dur aux sommets brillants.
- Rivière de chocolat traversant le centre de l’île.
- Marais de caramel ralentissant les déplacements.
- Forêt de cannes à sucre et de sucettes géantes.
- Collines de génoise fragiles pouvant s’effondrer.
- Cavernes de nougat et galeries de sucre cristallisé.
- Plateau salé dissimulé sous l’île, servant de transition vers le domaine du Gardien du Fromage.

La capitale doit être construite sur plusieurs niveaux, avec des ponts en biscuit, des moulins à sucre et de grandes cuisines collectives.

## Météo et lumière

Le climat est chaud, humide et changeant.

- Pluie de sirop légère rendant les surfaces glissantes.
- Brouillard de sucre filé réduisant la visibilité.
- Vagues de chaleur faisant fondre certains chemins en chocolat.
- Refroidissements nocturnes durcissant le caramel et ouvrant de nouveaux passages.
- Orages de sucre cristallisé créant de petits projectiles naturels.

La météo doit transformer le terrain : un chemin peut être liquide le jour, praticable la nuit ou cassant après un refroidissement brutal.

## Flore et faune

### Flore

- Arbres à bonbons et fruits gélifiés.
- Roseaux de réglisse près des rivières.
- Buissons de barbe à papa.
- Fleurs vanillées attirant les insectes.
- Champignons meringués dans les grottes humides.

### Faune

- Ours gélifiés sauvages vivant en groupes.
- Sangliers cacao fouillant les champs.
- Oiseaux-gaufres nichant dans les tours.
- Escargots caramel laissant une trace collante.
- Poissons chocolat dans les cours d’eau chauds.
- Abeilles pâtissières produisant un miel très recherché.

La faune ne doit pas être décorative : certaines espèces peuvent être observées, apprivoisées, chassées par les ennemis ou utilisées dans des quêtes.

## Population et architecture

La capitale, **Confiseria**, regroupe pâtissiers, cultivateurs, transporteurs, gardes et marchands. Les bâtiments ressemblent à des gâteaux, mais doivent conserver une structure crédible et praticable.

- Palais central en sucre cristallisé.
- Grand marché des saveurs.
- Fabriques de chocolat et de caramel.
- Quartier des boulangers.
- Port aux quais en biscuit renforcé.
- Villages agricoles dans les plaines de canne à sucre.
- Caves d’affinage souterraines surveillées par des gardiens.

Les habitants travaillent selon l’heure, transportent des ingrédients, ouvrent les boutiques le matin et organisent des fêtes le soir.

## Ennemis et boss

Types d’ennemis recommandés :

- soldats en armure de sucre dur ;
- créatures de caramel capables d’immobiliser le joueur ;
- pâtissiers corrompus lançant des mélanges brûlants ;
- guêpes de sirop ;
- golems de biscuit fragiles mais nombreux ;
- gardes des caves salées.

Le boss `boss gardien du fromage.glb` doit protéger les caves profondes où sont conservés les aliments les plus rares. Son arène mélange meules géantes, vapeur, moisissures lumineuses et plateformes tournantes. Il attaque avec des charges, des projections, des zones d’odeur étourdissante et des morceaux de sol qui s’effondrent.

## Gameplay, quêtes et exploration

- Réparer les canaux de chocolat alimentant la capitale.
- Sauver une récolte menacée par une pluie trop chaude.
- Escorter des caravanes d’ingrédients entre les villages.
- Préparer une recette géante pour une fête royale.
- Explorer les caves de nougat et les galeries cristallisées.
- Trouver des ingrédients légendaires donnant des bonus temporaires.
- Libérer des ouvriers prisonniers du Gardien du Fromage.
- Résoudre des énigmes utilisant la fonte, le refroidissement et la solidification.

## Approche maritime

L’île doit être visible de loin grâce à ses montagnes pastel et à ses cheminées de vapeur parfumée. Autour des côtes circulent des bateaux marchands, des barges d’ingrédients et des pirates cherchant à voler les cargaisons.

## Ambiance sonore

Utiliser une musique légère, rythmée et gourmande dans les villes, puis des sons plus lourds et étranges dans les caves. Les bruits de matière doivent informer le joueur : caramel collant, sucre qui craque, chocolat qui bout, biscuit qui s’effondre.

## Règles de réalisation

- Ne pas transformer l’île en simple décor enfantin : elle doit rester vaste, vivante et dangereuse.
- Donner une fonction de gameplay à chaque matière principale.
- Prévoir des chemins alternatifs selon la température et la météo.
- Optimiser les matières brillantes et liquides pour Android.
- Conserver des couleurs lisibles et éviter une saturation visuelle permanente.
