# Gameplay

Ce dossier décrit les mécaniques principales de **CHK Pirate Warrior 2**.

## Héros

### Cheikh
- arme : batte de baseball ;
- sac : orange ;
- pouvoir 1 : **Impact du Capitaine** ;
- pouvoir 2 : **Onde de Fracas**.

### Yvane
- arme : combat aux poings ;
- sac : bleu ;
- technique ninja 1 : **Poing Éclair** ;
- technique ninja 2 : **Rafale des Ombres**.

### Nelvyn
- arme : épée ;
- sac : noir ;
- pouvoir 1 : **Lame du Vent** ;
- pouvoir 2 : **Croissant Fulgurant**.

Les données complètes sont dans `data/heroes.json`.

## Sacs à dos / inventaire

Le sac reste visible sur le dos du héros. Il représente son inventaire et stocke notamment :

- pièces ;
- boussoles ;
- coffres ;
- cartes ;
- clés ;
- potions ;
- matériaux ;
- objets rares des îles.

Les objets sont définis dans `data/items.json` et sauvegardés par `scripts/systems/game_state.gd`.

## HUD mobile

Le HUD reprend la référence fournie :

- vie, énergie et aura en haut à gauche ;
- mission en haut au centre ;
- carte, sauvegarde et pause en haut à droite ;
- mini-carte de l'archipel ;
- déplacement et caméra 360° à gauche ;
- héros / embarquer au centre ;
- esquive, deux pouvoirs et attaque à droite.

Scène : `scenes/ui/hud_mobile.tscn`.

## Dialogues d'accueil

Chaque île peut utiliser `scripts/npc/greeting_agent.gd`. L'agent détecte le héros contrôlé et lance la bonne salutation française : Cheikh, Yvane ou Nelvyn.

## Caméra

La base troisième personne 360° est dans `scripts/camera/third_person_camera.gd` avec rotation tactile ou souris.
