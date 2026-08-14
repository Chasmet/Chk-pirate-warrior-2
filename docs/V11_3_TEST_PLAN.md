# V11.3 — plan de test téléphone

## Personnalisation extrême

1. Appuyer sur **MODIFIER**.
2. Vérifier qu'une touche tactile peut être déplacée et redimensionnée entre 30 % et 225 %.
3. Toucher une case HUD vide (VIE/XP, mission, mini-carte, pièces, ENNEMI, MISSION ou ÉQUIPE).
4. Vérifier l'encadrement bleu puis : déplacement, TAILLE -/+, OPACITÉ -/+.
5. Quitter MODIFIER, fermer puis relancer le jeu : positions, tailles et opacités doivent rester identiques.
6. Vérifier **RÉINIT. CASE** puis **TOUT RÉINIT.**.
7. Ouvrir le SAC, un dialogue de quête et la carte plein écran ; vérifier que leurs panneaux deviennent aussi personnalisables lorsqu'ils sont visibles.

## Stabilité Android

1. Passer plusieurs fois application -> écran d'accueil -> application : aucun bouton ne doit rester bloqué pressé.
2. Monter/descendre bateau, cheval et véhicule puis changer d'île : un seul contrôleur actif doit rester.
3. Provoquer plusieurs changements de héros et de royaume : aucun HUD en double.
4. Tester une longue session : le héros ne doit pas disparaître sous le monde ou partir avec une vitesse anormale.
5. Vérifier après un retour d'application que la caméra revient correctement si elle avait perdu son état actif.
6. Vérifier que `user://runtime_v11_3.log` reçoit les anomalies et un diagnostic périodique sans dépasser environ 256 Ko.

## Régressions prioritaires V11.2

- 3 flèches ENNEMI / MISSION / ÉQUIPE.
- coffres et objets de quête avec INTERAGIR.
- sauvegarde solo distincte de la sauvegarde coop.
- changement d'hôte coop.
- attaques 1 / 2 niveau 20 / 3 niveau 30.
