# Audit V11.8 — CHK Pirate Warrior 2

Cette révision renforce la validation automatique du jeu complet.

Contrôles automatisés :
- chargement récursif des scripts, scènes et ressources Godot ;
- validation JSON, héros, inventaire et catalogue des 11 royaumes ;
- présence des modèles critiques, boss, bateaux, trophée et ressources audio ;
- contrôle du menu de difficulté et des chevauchements HUD ;
- contrôle du joystick Android et des pertes de focus ;
- contrôle du déclenchement de la fin après la séquence des boss de l'île 11 ;
- test runtime mobile existant (recul/HUD/herbe) ;
- smoke test du projet ;
- réparation/validation GLB ;
- export, signature et vérification de l'APK Android complet.

Corrections principales intégrées :
- menu de difficulté rendu responsive ;
- joystick réinitialisé en perte de focus, suspension ou masquage ;
- correction d'une course critique entre suppression du premier boss de l'île 11 et apparition du boss final ;
- difficulté des commandants alignée sur le niveau choisi ;
- secours de fin de jeu si l'image trophée ne peut pas être décodée ;
- CI alignée sur Godot 4.7.1 avec le layout audio et les addons inclus dans l'export ;
- version Android V11.8.0 (code 118).
