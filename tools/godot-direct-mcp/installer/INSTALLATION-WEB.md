# CHK Godot Direct MCP — Tableau de bord local v1.2.0

**Aucun hébergement Render, Supabase, Tailscale supplémentaire, ni commande CMD n'est nécessaire.**

## Première installation (une seule fois)

1. Télécharger **CHK-Godot-Installation.exe v1.2.0** depuis la Release GitHub.
2. Sur le PC Windows où Tailscale est déjà installé, double-cliquer sur le fichier.
3. Le petit lanceur ouvre automatiquement **http://127.0.0.1:8792/** dans le navigateur.
4. Le lanceur peut se fermer : le site et son petit serveur local restent actifs.
5. Sur le site, cliquer **INSTALLER ET CONNECTER AUTOMATIQUEMENT**.
6. Le site installe le moteur privé dans AppData/Local/CHKGodotDirectMCP,
   réutilise les jetons existants, puis configure le port HTTPS Tailscale 10000
   seulement s'il est libre. Aucun fichier d'une application déjà ouverte n'est écrasé.
7. Si une autorisation Tailscale est requise, la valider dans la page ouverte, puis
   relancer l'installation depuis la page locale.
8. Une fois le test HTTPS réellement réussi, cliquer **COPIER MON LIEN CHATGPT**,
   le coller dans ChatGPT > Plugins > Ajouter > URL du serveur, puis
   **Sans authentification**.
9. Dans Godot 4.7, ouvrir le panneau CHK Direct et copier l'adresse et la
   clé éditeur depuis les deux autres boutons du site.

## Depuis la prochaine ouverture de Windows

La page locale est accessible à l'adresse :

    http://127.0.0.1:8792/

Il faut l'ouvrir **sur le PC qui héberge le serveur**, pas depuis le téléphone.
L'accès distant ChatGPT passe exclusivement par Tailscale Funnel HTTPS.
Le navigateur web est une interface d'administration locale. Un navigateur seul
ne peut pas installer un programme Windows pour des raisons de sécurité :
le premier double-clic sur le petit lanceur EXE est donc nécessaire.

L'installation démarre automatiquement à la connexion Windows. Le tableau de
bord et le moteur serveur sont séparés : fermer l'onglet du navigateur
n'interrompt pas le serveur MCP.

## Port et sécurité

- Interface d'administration : 127.0.0.1:8792 uniquement.
- Moteur MCP : 127.0.0.1:8791 uniquement.
- Port HTTPS public Tailscale Funnel : 10000.
- Port 8443 du MCP existant et port 443 IIS : non modifiés.
- Secrets privés générés localement, préservés si déjà présents.
- La page impose son propre jeton anti-CSRF et refuse les noms d'hôte externes.
- Le lien ChatGPT n'est affiché qu'après initialisation MCP HTTPS réussie.
- Le panneau de contrôle **n'est jamais publié sur Tailscale Funnel**.
- Le port 10000 n'est jamais écrasé s'il appartient à un autre service.
- Le serveur dépend de l'alimentation du PC et de Tailscale, mais pas de Render.

## Si un problème apparaît

Cliquer **VOIR LE DIAGNOSTIC** dans la page. Le programme reste accessible
et affiche le motif. Le rapport local se trouve dans :

    %LOCALAPPDATA%\CHKGodotDirectMCP\diagnostic.log

Il n'est pas nécessaire de supprimer l'ancien installateur ni les anciens
fichiers, surtout pas le fichier settings.json contenant les clés existantes.

La build Windows valide les tests Python du site local, la régression WinError32,
la vérification du bundle Node MCP, ainsi qu'un vrai EXE PyInstaller.
