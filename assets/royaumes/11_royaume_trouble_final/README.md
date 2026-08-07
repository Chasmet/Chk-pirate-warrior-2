# Notice de conception — Île 11 : Royaume Trouble — Île finale

> Référence obligatoire pour tout développeur ou agent travaillant sur l’île finale. Le visuel principal à respecter est `visuel royaume 11.jpg`. Les assets déjà présents sont `boss sorcière.glb`, `grande boss sorcière des cauchemars.glb` et `ymu_sama_ 1er commandant de la grande boss sorcière.glb`.

## Identité générale

Le Royaume Trouble est un royaume abandonné où sont enfermés les souvenirs oubliés du monde. Il représente clairement la fin du jeu. L’île doit être inquiétante, silencieuse, magique et beaucoup plus difficile que les dix royaumes précédents.

Son identité visuelle repose sur d’immenses ruines, des palais fissurés, des horloges géantes arrêtées, des bibliothèques anciennes, des miroirs brisés, des portes flottantes et des fragments de mémoire lumineux suspendus dans les airs.

Une épaisse vapeur dorée recouvre presque entièrement le royaume. Cette brume doit être si dense que le joueur distingue difficilement les bâtiments et les chemins. Elle fait perdre les repères, masque les distances et rend le retour vers la sortie très difficile. Seules quelques lueurs dorées, des cristaux, des silhouettes de monuments et des fragments de souvenirs apparaissent à travers le brouillard.

Aucun humain vivant et aucun animal naturel ne doivent peupler l’île. Seuls des échos, des silhouettes, des illusions, des gardiens et les forces de la sorcière peuvent y apparaître.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 11.

- **Dimension cible de l’île : 3,0 km × 2,3 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **20 à 30 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 10 (royaume précédent) : **1 500 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Port abandonné presque invisible dans la brume.
- Grande avenue de statues menant vers la cité centrale.
- Palais royal fissuré flottant partiellement au-dessus du sol.
- Horloges géantes arrêtées à différentes heures.
- Bibliothèque infinie dont les couloirs se déplacent.
- Quartier des miroirs brisés créant de faux passages.
- Portes flottantes ouvrant sur des fragments des dix anciens royaumes.
- Ponts incomplets reliant des ruines suspendues.
- Vallée des souvenirs où flottent des scènes du passé.
- Tour finale visible seulement lorsque plusieurs sceaux sont détruits.
- Sous-sol composé d’archives, de prisons de mémoire et de salles interdites.

La carte ne doit pas être aléatoire au point d’être injuste, mais elle doit sembler instable. Les repères changent, certaines portes déplacent le joueur et la brume masque les raccourcis.

## Météo, brume et lumière

Le Royaume Trouble n’a pas de météo naturelle normale.

- Brume dorée permanente et volumétrique.
- Vagues de brouillard réduisant temporairement la visibilité à quelques mètres.
- Pluie de fragments lumineux ressemblant à des souvenirs brisés.
- Orages silencieux où des éclairs apparaissent sans tonnerre immédiat.
- Distorsions du temps ralentissant ou accélérant certains éléments.
- Zones de gravité instable autour des portes flottantes.
- Nuits artificielles apparaissant au milieu de la journée.
- Couleurs des royaumes précédents traversant parfois la brume.

La brume doit être un mécanisme de gameplay : elle cache les ennemis, modifie la carte, étouffe les sons et oblige le joueur à suivre des cristaux, des cloches ou des fragments lumineux.

## Flore et faune

Il ne doit y avoir ni flore naturelle vivante ni faune normale.

Éléments autorisés :

- arbres pétrifiés sans feuilles ;
- racines noires traversant les ruines ;
- fleurs de mémoire apparaissant puis disparaissant ;
- oiseaux d’ombre non réels ;
- silhouettes d’animaux venant des souvenirs des anciennes îles ;
- créatures de cauchemar créées par la sorcière ;
- fragments de monstres ou boss déjà affrontés.

Ces apparitions doivent renforcer l’idée que le royaume copie et déforme les souvenirs du joueur.

## Architecture et lieux majeurs

- **Palais des Heures Brisées** : centre politique abandonné.
- **Bibliothèque des Noms Oubliés** : archives de l’histoire du monde.
- **Galerie des Miroirs** : zone d’illusions et de faux ennemis.
- **Place des Dix Portes** : chaque porte représente un royaume précédent.
- **Prison des Souvenirs** : contient les fragments nécessaires à l’ouverture de la tour finale.
- **Tour du Dernier Songe** : domaine de la grande sorcière.
- **Salle du Point de Non-Retour** : avertissement clair avant la fin du jeu.

Les bâtiments doivent sembler immenses, anciens et partiellement détachés du monde réel.

## Ennemis, commandant et boss

Le premier commandant est représenté par `ymu_sama_ 1er commandant de la grande boss sorcière.glb`. Il surveille les portes et manipule les chemins, les souvenirs et les illusions.

Types d’ennemis recommandés :

- gardiens sans visage ;
- chevaliers de brume ;
- doubles du joueur ;
- versions déformées d’ennemis des dix royaumes ;
- bibliothécaires maudits ;
- créatures de miroir ;
- fragments de boss passés ;
- esprits capables d’effacer temporairement la mini-carte.

`boss sorcière.glb` représente une première forme ou une sorcière gardienne affrontée avant la tour finale.

`grande boss sorcière des cauchemars.glb` représente le boss final. Le combat doit comporter plusieurs phases :

1. illusions et copies des attaques des royaumes précédents ;
2. disparition presque complète dans la brume ;
3. destruction des horloges et modification du temps ;
4. combat dans une arène brisée flottant dans le vide ;
5. forme finale utilisant les souvenirs des trois héros et de leurs alliés.

Le combat final doit rester lisible malgré les effets. Les attaques mortelles doivent toujours être annoncées visuellement et sonorement.

## Gameplay, progression et exploration

- Récupérer des fragments de mémoire dans les dix portes.
- Reconstituer une carte temporaire à partir de cristaux.
- Identifier les vrais chemins parmi les illusions.
- Affronter des versions déformées d’anciens ennemis.
- Libérer les souvenirs de personnages rencontrés auparavant.
- Réactiver les horloges dans le bon ordre.
- Traverser la bibliothèque mouvante.
- Résister à des zones qui retirent temporairement certaines capacités.
- Choisir quels souvenirs conserver ou sacrifier pour avancer.
- Ouvrir la tour finale après avoir détruit les sceaux du commandant.

L’île doit vérifier la maîtrise des systèmes appris pendant tout le jeu : combat, exploration, navigation, observation, énigmes et gestion de l’environnement.

## Approche maritime

La mer autour de l’île doit être anormalement calme. La brume dorée apparaît avant que la terre soit visible. Les boussoles deviennent instables, les sons sont étouffés et des silhouettes de navires disparus peuvent apparaître.

L’accès à l’île doit rester verrouillé tant que les objectifs majeurs des dix premiers royaumes ne sont pas terminés. Une fois le point de non-retour franchi, le joueur doit recevoir un avertissement clair et pouvoir sauvegarder.

## Ambiance sonore

- Silence inhabituel interrompu par des sons très lointains.
- Horloges arrêtées émettant parfois un unique battement.
- Voix déformées provenant des souvenirs.
- Musiques des anciens royaumes ralenties ou inversées.
- Tintements de cristaux servant de guides.
- Thème final unique pour la grande sorcière.

Le son doit aider à s’orienter dans la brume sans rendre le chemin trop facile.

## Fin du jeu et récompenses

Après la victoire contre la grande sorcière :

- cinématique de libération des souvenirs ;
- disparition progressive de la brume ;
- révélation de l’objet rare lié à l’histoire principale ;
- déblocage du bateau légendaire **Navire du Chaos** ;
- titre **Maître des 11 Royaumes** ;
- tenue finale pour Cheikh, Yvane et Nelvyn ;
- équipage spécial déblocable ;
- mode **Nouvelle Aventure +** ;
- générique de fin, puis possibilité de reprendre l’exploration avant le point final.

## Règles de réalisation

- Respecter strictement la brume dorée dense et la faible visibilité du visuel.
- Ne placer aucun village vivant, aucune foule et aucun animal naturel.
- Utiliser les éléments des dix royaumes précédents sous forme déformée, jamais comme simple copie.
- Maintenir des repères discrets pour éviter une frustration excessive.
- Prévoir des réglages Android réduisant la qualité volumétrique sans supprimer la brume.
- Le boss final doit être difficile, mais ses mécaniques doivent rester compréhensibles et équitables.
- Cette île doit clairement donner le sentiment d’une conclusion, pas d’un royaume ordinaire supplémentaire.
