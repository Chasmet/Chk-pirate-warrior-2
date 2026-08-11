# Modèles montables CC0

Ce dossier contient l'intégration des modèles 3D libres utilisés pour remplacer les visuels procéduraux du 4x4 et du cheval dans CHK Pirate Warrior 2.

Les gros fichiers binaires ne sont pas versionnés ici. Le workflow Android appelle `tools/fetch_cc0_ride_assets.sh` avant l'import Godot afin de récupérer des versions déterministes puis de les inclure dans le véritable APK.

## 4x4 / pickup Kenney

- Auteur : Kenney
- Source : dépôt `KenneyNL/Starter-Kit-Racing`
- Révision épinglée : `f5241ebdf00c25bc951bf4fdb7950bb1b78b4bcc`
- Fichier amont : `models/vehicle-truck-green.glb`
- Fichier généré pour le jeu : `assets/cc0_rides/4x4_kenney.glb`
- Licence des assets du Starter Kit Racing : CC0 1.0 / domaine public.

Le modèle possède une carrosserie et des roues séparées. L'adaptateur Godot anime les roues suivant la vitesse du véhicule.

## Cheval Quaternius

- Auteur original : Quaternius
- Pack original : `Ultimate Animated Animal Pack`
- Licence : CC0 1.0 / domaine public.
- Redistribution utilisée par le build : `animasim==0.2.1`, qui documente les modèles animaliers inclus comme provenant du pack Quaternius sous CC0.
- SHA-256 de la wheel AnimaSim 0.2.1 vérifiée par le script : `d111ffc9782f09872846b09ac7868d41e126ef72e3153d9d0173d401be3277a3`
- Fichier généré pour le jeu : `assets/cc0_rides/horse_quaternius.glb`

L'adaptateur Godot sélectionne automatiquement une animation d'arrêt, de marche ou d'allure rapide selon la vitesse du cheval.

## Robustesse

Si un modèle externe manque dans un checkout local, le système conserve automatiquement le 4x4 ou le cheval procédural déjà présent. Le jeu reste donc chargeable et jouable même sans téléchargement préalable des binaires.
