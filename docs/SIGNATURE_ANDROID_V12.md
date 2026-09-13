# Signature automatique V12

Une clé permanente a été préparée à la demande du propriétaire pour démarrer une
nouvelle série de versions signées. Son empreinte publique est conservée dans
`android-signing/identity.json`. La clé privée et ses mots de passe ne sont pas
dans ce dépôt. Une copie de secours privée est conservée dans le fichier
`CHK_Pirate_Warrior_2_signature_backup.zip`.

## Fonctionnement

GitHub Actions lit la configuration privée `CHK_ANDROID_SIGNING`, signe avec
les outils officiels Android, vérifie la signature et l'alignement 16 Ko, puis
publie l'APK, `update.json`, `SHA256.txt` et l'empreinte du certificat.
Les prochaines compilations réutilisent la même configuration. Aucune clé
n'est créée dans un runner et une clé différente est rejetée.

Le workflow `v12_sign_existing.yml` permet de signer directement l'APK V12.0.4
déjà validé par la compilation `34756950549`, sans reconstruire le jeu.
Le workflow `v12_quality_release.yml` assure les prochaines compilations complètes.

## Première installation

La clé des versions historiques est perdue. La première publication V12 avec
la nouvelle clé est donc une nouvelle installation, pas une mise à jour compatible
de ces anciens APK. Désinstaller une ancienne version supprime ses sauvegardes locales.

Cette transition est limitée à une référence précise : identifiant de release,
tag, identifiant de fichier et SHA-256 de l'APK historique. Dès la première V12
publiée, les nouvelles versions doivent garder le certificat permanent et un
numéro de version strictement supérieur.

## Conservation et contrôle

La copie privée contient la clé, le certificat public et le JSON de configuration.
Elle permet de restaurer la même identité sans signer manuellement chaque APK.
Le JSON est enregistré une fois dans les paramètres privés du dépôt ; il ne doit
pas être ajouté aux fichiers publics du projet ni aux artifacts Actions.

Les tests `tools/test_v12_signing.py` vérifient l'acceptation de la référence initiale,
les mises à jour avec la même clé et le rejet des mauvaises clés, fichiers,
identifiants d'application et numéros de version.

Sources : [signature Android](https://developer.android.com/studio/publish/app-signing),
[configuration privée GitHub Actions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).
