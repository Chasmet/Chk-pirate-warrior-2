# CHK Godot — Lanceur Web Local (Windows)

**Un seul EXE à double-cliquer** : ouvre automatiquement Chrome sur http://127.0.0.1:8793, puis permet de copier un programme \`CHK-Godot-Installation.exe\` hors OneDrive, le lancer et afficher ses erreurs. Aucun CMD, Python, Render, Supabase ou compte supplémentaire.

## Sur le PC
1. Télécharger l'artefact **CHK-Godot-Lanceur-Web-Windows** depuis le workflow GitHub Actions. Décompresser et placer le vrai \`CHK-Godot-Lanceur-Web.exe\` dans **Téléchargements**, pas dans OneDrive.
2. Double-cliquer sur le fichier. Garder le lanceur ouvert. Chrome ouvre la page du lanceur sur **http://127.0.0.1:8793/**.
3. Cliquer **Choisir mon programme CHK-Godot** et sélectionner le vrai \`CHK-Godot-Installation.exe\` (y compris les noms \`(7)\`). Le lanceur copie ce programme dans le dossier Windows local \`%LOCALAPPDATA%\CHK-Godot-Lanceur\` (la source n'est pas modifiée).
4. Sur la page, les boutons **Démarrer**, **Arrêter**, **Vérifier** et **Ouvrir Godot** permettent de gérer le programme. Quand il répond, le service Godot est accessible sur **http://127.0.0.1:8792/**.

**Important** : le navigateur ne peut pas lancer tout seul un programme Windows. C'est le petit lanceur natif qui rend ces boutons opérationnels. Si l'ancien programme refuse encore de démarrer, le lanceur indique son code de sortie et son erreur plutôt que d'afficher une page blanche. Il n'effectue aucune correction magique d'un programme défectueux.

## Sécurité
- Tout reste sur le PC, lié à \`127.0.0.1\`. Aucun hébergement tiers.
- L'importation est limitée à \`CHK-Godot-Installation.exe\` et \`CHK-Godot-Installation (N).exe\`.
- Le contrôle HTML nécessite un secret de session et refuse les origines différentes.
- Le lanceur ne prend pas de commandes arbitraires et n'arrête que les processus qu'il a lui-même lancés.
- Un ancien fichier local est sauvegardé sous \`version-precedente.exe\` avant remplacement.
- Une structure EXE Windows correcte ne prouve pas que le programme est sûr : sélectionner uniquement ton exécutable de confiance.

Le programme Windows compilé est créé par PyInstaller dans GitHub Actions. Un ZIP renommé en EXE ou un faux binaire n'est jamais publié.
