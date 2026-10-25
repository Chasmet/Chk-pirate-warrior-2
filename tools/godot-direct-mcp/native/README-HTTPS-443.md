# CHK Godot Direct MCP — port standard HTTPS 443 (version 1.4.0)

L'application Windows ouvre toujours son interface locale sur:
http://127.0.0.1:8792/

Le moteur MCP privé écoute sur:
http://127.0.0.1:8791/

L'accès distant de ChatGPT est désormais publié sur **HTTPS 443** grâce à
Tailscale Funnel, qui crée et gère automatiquement le certificat TLS.
**Aucun nouvel hébergement Render, Supabase ou autre plateforme** n'est
nécessaire. Tailscale fonctionne déjà sur le PC.

## Adresse ChatGPT obtenue

Si HTTPS 443 est libre dans Tailscale, le bouton « COPIER MON LIEN CHATGPT »
copie automatiquement un lien de ce type:

    https://pc-salon.taild9e4de.ts.net/mcp/<JETON_CHATGPT_GENERE_SUR_LE_PC>

Si 443 héberge DÉJÀ une application publique via Tailscale Funnel,
l'installateur ajoute **uniquement** une route dédiée sans remplacer
l'application existante et copie:

    https://pc-salon.taild9e4de.ts.net/chk-godot/mcp/<JETON_CHATGPT>

Ces valeurs sont des exemples de forme; ne copiez pas un jeton d'exemple.
Le programme lit la véritable clé privée existante depuis
%LOCALAPPDATA%\CHKGodotDirectMCP\settings.json, la conserve et ne la publie
pas sur GitHub.

Pour connecter l'éditeur Godot, utiliser les boutons
« COPIER L'ADRESSE GODOT » et « COPIER LA CLÉ GODOT ».
Le panneau CHK Direct concatène /relay/godot/<JETON_EDITEUR>.

## Sécurité et coexistence

Le logiciel inspecte d'abord la configuration Tailscale en JSON:
- S'il existe déjà une route **privée** 443 (Tailscale Serve), aucune
  transformation en Funnel n'est effectuée. En effet, cela pourrait
  exposer d'autres sites privés par accident.
- Si le port 443 est en mode TCP ou si /chk-godot est utilisé par
  une autre application, l'installation s'interrompt sans écraser.
- Si le port 443 est libre, le serveur utilise le point d'entrée racine.
- Si le port 443 est DÉJÀ public, il partage ce HTTPS avec son
  chemin /chk-godot sans retirer les routes existantes.
- Le port 8443 du MCP déjà connecté, le port 10000 des anciens essais,
  et les routes IIS ne sont jamais remis à zéro, ni supprimés.
- Le logiciel vérifie réellement le handshake MCP Streamable HTTP
  sur l'adresse HTTPS extérieure avant d'activer le bouton « Copier ».
- Si le réseau ne répond pas, le bouton reste désactivé et une erreur
  lisible indique le blocage au lieu de présenter une URL fictive.

L'installation n'est pas une preuve que ChatGPT acceptera le serveur:
seul le test dans la page Plugins de ChatGPT peut confirmer la connexion.

## Utilisation depuis Windows

1. Fermer les anciennes fenêtres du logiciel CHK Godot.
2. Double-cliquer sur le nouveau CHK-Godot-Serveur-Personnel.exe.
3. Ouvrir l'adresse locale http://127.0.0.1:8792/ dans Chrome si
   l'ouverture automatique échoue à cause de l'association Windows.
4. Cliquer « INSTALLER ET CONNECTER ».
5. Autoriser Tailscale Funnel si Tailscale demande une approbation.
6. Une fois l'accès HTTPS vérifié, cliquer « COPIER MON LIEN CHATGPT ».
7. Dans ChatGPT Plugins, « URL du serveur », coller la valeur exacte
   et choisir « Sans authentification ». Le jeton est dans le chemin;
   cela ne signifie pas que le serveur est ouvert sans sécurité.

Le PC et le logiciel doivent rester allumés pour le travail en direct.
Le code source du jeu et le MCP restent développables sur GitHub
séparément des connexions en direct.
