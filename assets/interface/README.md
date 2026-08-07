# Interface — CHK Pirate Warrior 2

Ce dossier est réservé aux visuels d’interface du jeu.

## Fichiers principaux à déposer ici

### 1. Menu principal

Nom exact recommandé :

`menu_principal_chk_pirate_warrior_2.png`

Ce visuel correspond à l’écran de démarrage avec :

- logo `CHK Pirate Warrior 2` ;
- les trois personnages principaux en version 3D ninja ;
- `Nouvelle partie` ;
- `Continuer` ;
- `Sauvegarde` ;
- `Options`.

### 2. Menu de choix d’aventure

Nom exact recommandé :

`menu_choix_aventure_chk_pirate_warrior_2.png`

Ce visuel correspond au second menu avec :

- `Débutant` ;
- `Visite des îles` ;
- `Ennemis légers` ;
- `Moyen` ;
- `Expert` ;
- bouton `Retour` ;
- carte ou archipel en arrière-plan.

### 3. Logo du jeu

Nom exact recommandé :

`logo_chk_pirate_warrior_2.png`

Le logo doit pouvoir être utilisé dans :

- écran titre ;
- menus ;
- écran de chargement ;
- communication du jeu ;
- future icône ou splash screen après adaptation.

## Direction artistique de l’interface

L’interface principale doit conserver une identité commune :

- aventure pirate + ninja ;
- personnages principaux en rendu 3D ;
- vêtements ninja sombres avec accents bleu et orange ;
- boutons métalliques ou pierre sombre ;
- détails dorés ;
- mer, îles, bateaux et royaumes visibles en arrière-plan ;
- textes en français ;
- boutons suffisamment gros pour une utilisation tactile sur Android.

## Arborescence attendue

```text
assets/interface/
├── README.md
├── menu_principal_chk_pirate_warrior_2.png
├── menu_choix_aventure_chk_pirate_warrior_2.png
└── logo_chk_pirate_warrior_2.png
```

## Futures interfaces à ajouter dans ce dossier

- sélection du personnage ;
- sélection de sauvegarde ;
- écran de chargement ;
- HUD de vie, énergie et pouvoir ;
- mini-carte ;
- boutons tactiles Android ;
- inventaire ;
- carte des 11 royaumes ;
- menu pause ;
- options audio, vidéo et commandes ;
- écran victoire/défaite ;
- écran de fin du jeu ;
- icônes de quêtes, objets et compétences.

## Règles techniques

- Format conseillé pour les menus : PNG 16:9.
- Prévoir ensuite des éléments UI séparés pour rendre les boutons réellement interactifs dans le jeu ; l’image complète sert d’abord de référence visuelle.
- Le logo doit idéalement avoir aussi une version avec fond transparent.
- Garder les textes lisibles sur écran de téléphone.
- Ne pas intégrer les boutons fonctionnels uniquement dans une image finale : les boutons réels devront être recréés dans l’interface du moteur de jeu.
