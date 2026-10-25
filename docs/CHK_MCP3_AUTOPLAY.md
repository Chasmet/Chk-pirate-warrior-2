# CHK Pirate Serveur 3 : pilotage Godot et tests automatiques

## État et limites

Cette intégration est basée sur **CHK Pirate Warrior 2 V11.8** et Godot **4.7.1**.
Le module `addons/godot_mcp` expose déjà les commandes d'inspection, de jeu,
d'entrées virtuelles, de captures et de retouches. Le module
`addons/chk_mcp_relay` transmet ces commandes entre le relais et l'éditeur.

Deux modes complémentaires :

1. **Éditeur Godot réellement connecté** : le serveur MCP 3 peut transmettre des
   méthodes `scene.*`, `input.*`, `runtime.*`, `node.*`, `engine.*`
   à l'éditeur; l'exécution réelle des commandes du serveur 3 exige une
   **approbation dans son panneau local**. Un message « queued » ne prouve
   pas qu'une commande a été exécutée.
2. **Sans éditeur connecté** : `scripts/tests/mcp3_autoplay_audit.gd`
   charge le jeu, fait jouer le héros automatiquement (déplacement, saut,
   attaque et pouvoir), vérifie collisions et interface, puis émet un
   **rapport JSON**. Il s'agit d'un test Godot headless, pas d'un enregistrement
   vidéo ni d'une mesure de FPS Android.

## Configurer le relais CHK Pirate Serveur 3

Sur l'ordinateur hébergeant Godot, configurer la variable d'environnement
`CHK_PIRATE_MCP3_WS_URL` avec l'**adresse WebSocket réelle et autorisée**
du relais Godot de CHK Pirate Serveur 3.

- Accepte `wss://...` (connexion chiffrée) ou `ws://127.0.0.1:PORT`
  (uniquement en boucle locale).
- L'adresse HTTPS du point d'entrée MCP de ChatGPT **n'est pas forcément**
  une adresse WebSocket Godot : ne pas les confondre.
- Ne pas publier de clés ou de jetons dans `project.godot` ou GitHub.
- Redémarrer l'éditeur Godot après modification de cette variable.
- Sans variable définie, l'ancien relais est conservé pour compatibilité.
- Vérifier `godot_status.editor_connected == true` sur le serveur 3
  **avant** de promettre des actions sur l'éditeur réel.

## Session de contrôle via MCP 3

Exemples de méthodes du module `godot_mcp` quand l'éditeur est connecté :

| Action | Méthode |
| --- | --- |
| Consulter le monde et les nœuds | `scene.get_tree` / `runtime.tree` |
| Jouer la scène | `scene.play` |
| Déclencher une touche / action | `input.tap` / `input.action` |
| Observer un objet pendant le jeu | `runtime.monitor` |
| Inspecter les erreurs | `runtime.errors` |
| Capturer des images | `runtime.screenshot` / `runtime.capture_frames` |
| Enregistrer / rejouer des commandes | `runtime.start_recording`, `runtime.stop_recording`, `runtime.replay` |
| Modifier le projet | méthodes `node.*`, `scene.*` ou `fs.*` disponibles dans l'addon |

Après chaque écriture, relire l'état réel, effectuer une sauvegarde et lancer
le test de régression. Conserver un commit Git séparé avant les grandes retouches.

## Test autonome sans PC / sans interface graphique

Depuis le dépôt Godot, après importation des ressources :

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://scripts/tests/mcp3_autoplay_audit.gd
```

Le test vérifie : chargement de la scène, héros, caméra, HUD, contrôles
tactiles, monde, contact au sol, déplacement, saut, attaque, pouvoir et état
du héros. Il imprime `CHK_MCP3_PLAYTEST_JSON={...}`, sauvegarde le rapport
dans `user://chk_mcp3_playtest_report.json`, puis termine avec le code
`0` si tout passe ou `12` si une vérification échoue.

Le workflow **CHK MCP3 - Test automatique du jeu**
(`.github/workflows/mcp3-playtest.yml`) lance le contrôle sur GitHub Actions,
avec le binaire officiel Godot 4.7.1 vérifié par SHA-256 et des journaux joints.

## Limites importantes

- Les tests headless ne certifient ni les animations visuelles, ni les
  interactions multijoueurs réelles, ni les FPS d'un téléphone.
- Pour **jouer visuellement**, piloter la souris, regarder des captures ou
  corriger directement une scène ouverte sur PC, la connexion **live**
  de l'éditeur est nécessaire.
- Les actions d'écriture envoyées par CHK Pirate Serveur 3 requièrent
  l'approbation locale prévue par le serveur. Cette mise à jour ne la contourne pas.
- Le serveur 3 doit fournir un point d'entrée WebSocket Godot compatible :
  **l'adresse ne peut pas être déduite** de son seul statut.
