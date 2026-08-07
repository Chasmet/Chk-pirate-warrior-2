# Notice de conception — Île 01 : Royaume musical

> Référence obligatoire pour tout développeur ou agent travaillant sur cette île. Le visuel principal à respecter est `visuel ile 1.png`. Les modèles déjà présents sont `solda ile 1 .glb` et `boss musique ultime.glb`.

## Identité générale

Le Royaume musical est une île spectaculaire où l’architecture, la nature et les mécanismes du monde réagissent au son. Dès l’arrivée en mer, le joueur doit reconnaître l’île grâce à ses instruments géants, ses falaises en forme d’orgues, ses ponts-pianos et sa grande cité construite autour d’un amphithéâtre naturel.

L’ambiance doit être joyeuse et vivante dans les zones habitées, puis devenir plus grave et inquiétante à mesure que le joueur approche du domaine du boss.

<!-- WORLD_SCALE_START -->
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île 01.

- **Dimension cible de l’île : 1,2 km × 1,0 km** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **8 à 12 minutes**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
- Mer ouverte vers l’Île 02 (royaume suivant) : **700 m entre les côtes navigables**.
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
<!-- WORLD_SCALE_END -->

## Relief et géographie

- Grande baie en forme de croissant servant de port principal.
- Montagne centrale appelée **Mont de la Résonance**, visible depuis presque toute l’île.
- Falaises verticales ressemblant à des tuyaux d’orgue.
- Vallées acoustiques où chaque bruit produit un écho différent.
- Ponts suspendus composés de touches de piano géantes.
- Grottes de cristal amplifiant les sons et révélant des passages secrets.
- Rivière claire traversant la capitale et faisant vibrer des carillons naturels.
- Petits îlots périphériques servant de scènes, de lieux de concerts et de zones d’entraînement.

## Météo et lumière

Le climat est tempéré et lumineux, mais directement influencé par les sons de l’île.

- Brise régulière faisant jouer les arbres-carillons.
- Pluie fine produisant des notes sur les toitures métalliques.
- Orages musicaux rares où le tonnerre suit un rythme précis.
- Brouillard sonore dans les vallées, réduisant la visibilité tout en déformant les bruits.
- Au coucher du soleil, des ondes colorées doivent parcourir le ciel au-dessus de la montagne centrale.

La météo modifie le gameplay : certaines portes ne s’ouvrent que pendant la pluie, certains ennemis deviennent plus puissants durant les orages et certains chemins sont révélés par les échos.

## Flore et faune

### Flore

- Arbres-carillons aux branches métalliques.
- Fleurs d’écho qui répètent brièvement les voix et les sons.
- Roseaux-flûtes près des rivières.
- Champignons-tambours dans les zones humides.
- Lianes vibrantes utilisables comme cordes ou plateformes.

### Faune

- Oiseaux chanteurs capables d’imiter les mélodies entendues.
- Tortues à carapace de tambour.
- Crabes-cloche vivant sur les plages rocheuses.
- Cerfs lumineux dont les bois résonnent dans les forêts.
- Dauphins sonores accompagnant parfois les bateaux.

Les animaux doivent avoir des routines naturelles : se nourrir, fuir, dormir, se regrouper et réagir aux concerts ou aux combats.

## Population et architecture

La capitale, **Accordia**, est organisée en quartiers correspondant à différentes familles d’instruments : cordes, vents, percussions et voix. Les habitants sont musiciens, artisans, fabricants d’instruments, pêcheurs et soldats.

- Grande place centrale servant de scène publique.
- Conservatoire royal dominant la ville.
- Marché des artisans sonores.
- Taverne où les musiciens donnent des informations et des quêtes.
- Casernes protégeant les routes menant au Mont de la Résonance.
- Villages secondaires consacrés à la fabrication des instruments et à la récolte des matériaux acoustiques.

Les PNJ doivent répéter, travailler, enseigner, se déplacer vers les concerts et rentrer chez eux la nuit.

## Ennemis, soldats et boss

Les soldats de l’île utilisent le son pour attaquer, repousser ou désorienter. Leur modèle de référence est `solda ile 1 .glb`.

Types d’ennemis recommandés :

- gardes-percussion frappant le sol pour créer des ondes de choc ;
- archers à cordes lançant des projectiles vibratoires ;
- mages du souffle créant des rafales ;
- automates musicaux protégeant les ruines ;
- créatures corrompues par les fausses notes.

Le boss, représenté par `boss musique ultime.glb`, doit combattre dans le Grand Conservatoire au sommet de la montagne. Le combat comporte plusieurs phases : rythme lent et lourd, accélération, destruction progressive de la scène, puis phase finale où le joueur doit éviter des vagues sonores synchronisées.

## Gameplay, quêtes et exploration

- Reconstituer une mélodie ancienne pour ouvrir un temple.
- Aider différents quartiers à préparer un grand festival.
- Retrouver des instruments volés dans les grottes acoustiques.
- Protéger un concert attaqué par des ennemis.
- Résoudre des énigmes de rythme, d’écho et d’ordre musical.
- Découvrir des partitions cachées améliorant les capacités du joueur.
- Affronter des mini-boss dans les quatre quartiers musicaux avant l’accès au boss principal.

L’exploration doit toujours être récompensée par des morceaux de musique, des améliorations, des raccourcis ou des informations sur l’histoire du royaume.

## Approche maritime

Le port doit être visible de loin grâce à de grandes arches en forme de harpes. Les vagues proches du royaume peuvent produire de faibles notes. Des navires marchands, des bateaux de musiciens et des patrouilles doivent circuler autour de l’île.

## Ambiance sonore

La musique évolue selon la zone, l’heure et la météo. Les éléments du décor doivent produire de vrais sons spatialisés, mais sans créer un mélange confus. Les sons importants pour le gameplay doivent rester clairement reconnaissables.

## Règles de réalisation

- Respecter le visuel de référence et conserver une silhouette immédiatement reconnaissable.
- Ne pas créer une île plate ou vide : alterner ville, forêts, vallées, montagne, grottes et littoral.
- Prévoir des niveaux de détail, des collisions simples et des effets sonores limités pour Android.
- Les mécanismes musicaux doivent être compréhensibles même pour un joueur sans connaissance musicale.
- L’île doit rester entièrement explorable à pied, avec des raccourcis déblocables après progression.
