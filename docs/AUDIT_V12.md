# Audit CHK Pirate Warrior 2 — 13 septembre 2026

## Base examinée

Branche `agent/v11-8-full-audit-fixes`, commit `4fee58f` ; copie de sécurité
`backup/pre-v12-20260912`. `main` contient encore le prototype ; la nouvelle version
reprend la V11.8 pour conserver les onze royaumes, trois héros, la coop, les véhicules,
les quêtes et le trophée final. Aucun serveur Render ni route MCP distante modifiés.

## Constats et corrections

| Priorité | Constat vérifié | Correction V12 |
|---|---|---|
| Critique | Une clé debug neuve était générée par les workflows : aucune continuité de signature assurée. | Aucune génération de clé. Publication conditionnée à une clé existante ET au même certificat que le dernier APK publié. |
| Haute | Sauvegardes écrites directement dans le fichier principal. Une interruption pouvait tronquer le JSON. | Écriture temporaire, synchronisation, copie de secours valide, renommage et récupération du JSON précédent. |
| Haute | La sauvegarde coop était réécrite deux fois et à chaque snapshot réseau. | Une seule écriture avec identité/sièges inclus ; snapshots sur disque espacés de cinq secondes. Sauvegarde explicite immédiate. |
| Haute | Passer l'app en arrière-plan depuis le menu pouvait sauvegarder l'état initial avant CONTINUER. | Sauvegarde de suspension seulement après entrée en partie. |
| Haute | Herbe, fleurs, buissons et faune utilisaient global_position avant leur insertion dans la scène. | Insertion avant placement ; suppression des erreurs de transformation répétées. |
| Moyenne | Petite inclinaison du joystick déclenchait déjà une vitesse élevée. | Vitesse progressive selon l'amplitude du joystick. |
| Moyenne | Saut anticipé perdu à l'atterrissage. | Tampon de saut de 150 ms, conservation du coyote time. |
| Moyenne | Appels directs répétés aux attaques pouvaient répéter dégâts et effets. | Verrou partagé, une attaque suivante en attente, combo à trois coups. Bonus de troisième coup limité au solo pour conserver l'autorité coop. |
| Moyenne | Caméra potentiellement raccourcie par la collision du héros, vitesse au joystick dépendante du FPS. | Héros exclu du SpringArm, vitesse normalisée, sensibilité/distance/FOV réglables. |
| Moyenne | Aucun menu global de réglages ni circuit de mise à jour vérifié. | Menu accessible depuis l'accueil et en jeu, réglages persistants, plugin Android Java. |
| Moyenne | Les captures réelles montrent un HUD trop volumineux, des commandes au centre et deux logos superposés à l'accueil. | HUD par défaut compact, commandes regroupées en bas et à droite, accueil nettoyé, thème marine/turquoise/or. Les dispositions personnalisées restent prioritaires. |
| Moyenne | Les onze noms de royaumes se superposaient dans la mini-carte compacte. | Repères espacés et légende du royaume courant dans la miniature ; les noms restent sur la grande carte. |
| Moyenne | La capture globale du joystick pouvait traverser le menu de réglages en coop ; la touche pause pouvait être traitée deux fois. | Contacts ignorés pendant les réglages et un seul traitement de la touche pause. |
| Moyenne | Les plugins MCP de l'éditeur pouvaient être emportés dans l'APK. | Conservés dans le projet source et exclus du circuit d'export V12. |

## Ajouts réels

Huit GLB originaux, 101 052 octets au total, géométrie par matériaux pour limiter les
appels de rendu. Trois modèles animés. Neuf placements dans chacun des onze royaumes :
phare, marché, arche praticable, sanctuaire, réserves, deux bannières, passerelle et corail.
Collisions simples et distance d'affichage limitée. Le sanctuaire restaure santé/énergie
hors combat et sauvegarde. Les modèles sont des créations stylisées légères, pas des
modèles photoréalistes.

Son : volumes séparés musique/voix/effets/ambiance. Image : trois niveaux de qualité,
30/60 FPS, champ de vision et compteur FPS. Commandes : sensibilité, recul caméra,
aide au corps à corps, vibrations. Les outils de personnalisation existants sont conservés.

## Mise à jour et sauvegardes

Identifiant conservé : `com.chasmet.chkpiratewarrior2`. Noms et formats de sauvegarde
solo/coop existants conservés. Les réglages ajoutent leur propre JSON, sans réinitialiser
les dispositions des touches ni l'identité coop.

Le plugin consulte `releases/latest`, exige un manifeste `update.json` associé à un APK
présent dans cette même release, contrôle version, taille, SHA-256, package et certificat.
Téléchargement en arrière-plan avec pourcentage, erreurs explicites et nouvelle tentative
par VÉRIFIER. L'installation passe par Android et sa confirmation ; aucune désinstallation.
Aucun fichier de sauvegarde n'est effacé par ce plugin.

Le code du plugin Java cible SDK 34 / min 21. Le jeu garde Godot 4.7.1 : son modèle
Android nécessite SDK 36 / min 24. Abaisser artificiellement le minimum du moteur à 21
n'assurerait pas la compatibilité ; le moteur et le jeu existants sont conservés.

## Vérifications

Audit statique : scripts, cinq scènes, JSON, modèles, audio et images parcourus.
112 GLB sources normalisés dans une copie de compilation, dont deux Draco et treize
quantifiés ; aucun modèle isolé. Les sources originales ne sont pas remplacées.
Après ajout : huit GLB supplémentaires, validés par l'importeur Godot.

Tests exécutés localement avec Godot 4.7.1 : audit complet V11.8, contrôle tactile et HUD,
régression coop/graphismes, écran final, tests V12 de sauvegarde corrompue, réglages,
pause, attaques et placements dans les onze royaumes. Tous ont passé.
Les limites de validation Android et la compilation définitive sont rapportées dans les
Actions V12. Aucun test sur téléphone physique n'a encore été réalisé.

La première compilation GitHub du 13 septembre a réussi : plugin Java debug/release,
audit complet (173 scripts, 5 scènes, 4 JSON, 119 GLB dans assets, 82 audios, 164 images),
tests V11.8/V10/V12, captures OpenGL et APK complet avec plugin vérifié dans le manifeste.
122 GLB au total normalisés dans la copie d'export, en incluant les trois GLB racine et
les deux montures CC0 téléchargées. Le paquet n'est pas signé : la clé historique
n'est pas disponible dans la configuration de cette compilation.

Les captures ont ensuite guidé la réduction de l'encombrement du HUD. La CI contrôle
également la conservation d'une ancienne échelle tactile, l'absence de commandes
dans la zone centrale, le bouton pause et le blocage du joystick derrière les réglages.
L'alignement ZIP et ELF à 16 Ko est contrôlé avant signature, conformément à la
[documentation Android](https://developer.android.com/guide/practices/page-sizes).

La [compilation finale V12](https://github.com/Chasmet/Chk-pirate-warrior-2/actions/runs/34756950549)
a également réussi : 176 scripts audités, 65 vérifications ciblées V12, tests hérités,
122 GLB importés, captures du rendu et APK Android. Les bibliothèques `libgodot_android.so`
et `libc++_shared.so`, ainsi que leur stockage dans le ZIP, passent le contrôle 16 Ko.
Les outils Godot signalent encore une à deux ressources non libérées à leur fermeture ;
les marqueurs de réussite passent, sans erreur de script ou d'accès pendant les tests.

Les [captures réelles de la V12](visuels-v12/README.md) présentent l'accueil, les commandes,
les réglages et les huit modèles. Elles proviennent d'un rendu logiciel OpenGL en CI,
et ne constituent pas une mesure des performances sur téléphone.

## Limite de publication à résoudre

Les anciens workflows ne conservaient pas leur keystore généré. Aucune clé correspondante
n'a été trouvée dans le dépôt audité. Une clé privée ne peut pas être reconstruite à partir
de l'APK. La CI peut produire un APK non signé vérifiable ; elle ne publie une version
installable qu'avec la clé historique et après comparaison au certificat de la dernière
release. Aucun nouveau secret ni nouvelle clé n'est créé. Une signature différente sur
une version installée depuis un ancien artifact reste un cas à vérifier séparément.

## Points restants

- Valider sur un appareil Android les performances, la qualité élevée,
  la permission d'installation et le maintien des sauvegardes après remplacement.
- Le projet contient toujours de nombreuses couches héritées V2 à V11 : elles sont
  conservées pour limiter les régressions, mais augmentent le coût des futures évolutions.
- La majorité des assets lourds existants n'est pas retopologisée. Les nouveaux modèles
  sont légers ; aucune promesse de 60 FPS sur tous les téléphones.
- La coop et les serveurs existants ne font pas l'objet d'un test de pénétration distant.
