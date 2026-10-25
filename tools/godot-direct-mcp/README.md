# CHK Godot Direct MCP — serveur secondaire autonome

Serveur MCP **independant** du navigateur CHK, de Supabase et de Render. Il permet
a ChatGPT, depuis n'importe quel appareil, d'envoyer des commandes de
developpement au **vrai editeur Godot 4.7+** via le plugin officiel
'Godot MCP/CLI' deja inclus dans la branche active de CHK Pirate Warrior 2.

## Composition

- Serveur Node.js autonome: tools/godot-direct-mcp/server.mjs, port local 8791.
- Interface MCP Streamable HTTP: POST https://VOTRE-HTTPS/mcp/JETON_CHATGPT.
- Connexion editeur sortante WSS: wss://VOTRE-HTTPS/relay/godot/JETON_EDITEUR.
- Extension d'editeur: addons/chk_direct_mcp/plugin.gd, dock 'CHK Direct'.
- Authentifications DISTINCTES, 256 bits chacune. Aucun secret dans Git.
- Trois outils ChatGPT: godot_status, godot_run, godot_batch.
- 'godot_run' relaye les commandes du plugin Godot MCP/CLI officiel (316
  commandes selon sa documentation), au lieu de redefinir une API limitee.
- Erreur explicite quand l'editeur est hors ligne. Aucune fausse confirmation
  de manipulation en direct et aucun replay automatique apres interruption.

## Installer le serveur (Windows)

1. Installer Node.js 22+ si necessaire.
2. Telecharger ce dossier depuis le depot GitHub et conserver son arborescence.
3. Double-cliquer DEMARRER-SERVEUR-WINDOWS.cmd; il cree UNE FOIS .env
   avec deux jetons aleatoires, installe ws puis demarre le serveur.
4. Controler http://127.0.0.1:8791/health. Les deux jetons se trouvent
   dans le fichier local prive .env. Ne pas le partager ni le publier.
5. Pour fonctionner PC eteint, installer le serveur Node sur une machine
   independante toujours allumee. Si l'editeur Godot lui-meme est ferme,
   les actions en direct ne fonctionneront PAS, meme avec le serveur en ligne.

## HTTPS sans Supabase ni Render

Le serveur ecoute volontairement uniquement 127.0.0.1; NE PAS ouvrir 8791
a Internet. L'exposer derriere un proxy/tunnel HTTPS avec support WSS Upgrade.

### Tailscale Funnel, test personnel

Un exemple d'installation sur le PC possedant Tailscale CLI:
  tailscale funnel --bg --https=10000 http://127.0.0.1:8791

Tailscale accepte uniquement 443, 8443 et 10000 pour Funnel.
Le port 10000 doit etre libre. Cette commande ne doit PAS etre lancee
si un autre service y est configure. Elle n'affecte pas 443 (IIS) ni
le MCP existant 8443. Son port 10000 peut etre refuse par ChatGPT :
un test reel est indispensable. Le nom du domaine Tailscale est propre
a votre installation. Ne pas copier une adresse inventee.

Pour une URL HTTPS STANDARD port 443, utiliser un sous-domaine distinct
d'un domaine controle par vous et un tunnel inverse/terminateur TLS stable
(par exemple Cloudflare Tunnel avec hostname configure, ou Nginx sur
une machine possedant une IP publique). Verifier que WSS fonctionne.
Un domaine propre peut entrainer un cout; les Quick Tunnels ne sont pas
des adresses permanentes. Rien n'est deployee automatiquement par GitHub.

### ChatGPT : formulaire Plugins > Ajouter

  Nom: CHK Pirate Warrior 2 Direct
  URL du serveur: https://VOTRE-HTTPS/mcp/JETON_CHATGPT
  Authentification: Sans authentification

La capacite privee JETON_CHATGPT est dans l'URL: ceci n'est pas un acces
anonyme ! Elle controle l'editeur, y compris les ecritures. Pour un
produit multi-utilisateurs ou public, ajouter OAuth 2.1 veritable.
Ne jamais communiquer l'URL complete publiquement.

### Godot 4.7 (ordinateur ou editeur Android)

1. Ouvrir CHK Pirate Warrior 2 sur la branche utilisant Godot 4.7.
2. Activer Godot MCP/CLI **et** CHK Godot Direct MCP dans Project Settings > Plugins.
3. Ouvrir le dock CHK Direct.
4. Coller le **nom d'hote HTTPS public sans /mcp** dans le premier champ.
5. Coller la valeur CHK_GODOT_EDITOR_TOKEN du .env prive dans le second.
   NE PAS utiliser le jeton ChatGPT dans ce champ.
6. Cliquer Enregistrer et connecter. Le secret va dans res://.godot/
   (dossier ignore par Git). Fermer l'editeur coupe les outils en direct.
7. Dans ChatGPT, appeler godot_status, puis godot_run(method='scene.get_tree').
   Le resultat doit provenir de l'editeur et non du depot.

Le plugin CHK existant qui se connecte a Render reste intact. Le nouveau
plugin est separe : il est possible de desactiver l'un ou l'autre depuis
Project Settings > Plugins.

## Les actions developpement possibles

L'outil godot_run transmet les commandes Godot MCP/CLI (scenes, noeuds,
scripts, importation de modeles GLB, materiaux, eclairage, animations,
particules, interface, inspecteur du jeu, scripts de test). Les nouveaux
groupes de commandes du plugin officiel peuvent etre exploites sans
redefinir le catalogue du serveur ; les mises a jour de fonctionnalites
sont versionnees sur GitHub.

Cela ne signifie pas qu'un modele 3D complexe est genere de toutes pieces
sans ressource ni moteur adaptes : selon le besoin, ChatGPT peut creer
du code procedural, importer des assets autorises ou demander un outil
de modelisation. Toute modification du jeu doit etre verifiee dans Godot.
Les actions destructrices requierent une precaution particuliere; sauvegarder
une branche Git avant les changements majeurs.

## Tests et mises a jour

  cd tools/godot-direct-mcp
  npm install --no-audit --no-fund
  npm run check
  npm test

Un workflow GitHub Actions teste le transport Node et parse le plugin avec
Godot 4.7.2. Il publie les sources comme artefact de livraison apres test.
La mise a jour de code est geree par GitHub (pas de code distant auto-execute
sans revue). La configuration et les secrets locaux ne sont pas remplaces.

## Limites de fonctionnement

- Pas de machine allumee / process Node: pas d'endpoint public.
- Pas d'editeur Godot actif: MCP accessible, mais godot_run indisponible.
- Exposer un tunnel HTTPS est une etape distincte et reelle.
- Le serveur Node ne peut pas intervenir directement dans une partie Android
  exportee si le plugin d'editeur Godot n'est pas present : commandes de
  runtime dependantes du plugin officiel et de la session de debug.
- Streamable HTTP JSON (pas de SSE necessaire), WebSocket WSS requis
  entre le plugin et le serveur.
- Le dossier .godot/ du projet n'est jamais versionne.
