# Audio — CHK Pirate Warrior 2

L'audio est séparé en trois zones principales.

## 1. `bandes_son/`

Un dossier par île : `ile_01` à `ile_11`. Les onze musiques réelles sont
installées sous le nom `theme_principal.mp3`.

Fichiers prévus dans chaque dossier :

- `theme_principal.mp3` : musique d'exploration actuellement active ;
- `ambiance.ogg` : ambiance de l'île ;
- `combat.ogg` : musique de combat ;
- `boss.ogg` : musique de boss.

La traversée maritime utilise `bandes_son/mer/traversee_mer.mp3`. Le jeu passe
automatiquement de la musique du royaume à celle de la mer avec un fondu.

## 2. `personnages_principaux/`

Trois dossiers contiennent les vrais enregistrements :

- `cheikh/`
- `yvane/`
- `nelvyn/`

Cheikh, Yvane et Nelvyn possèdent chacun leur banque séparée. Le jeu ne réutilise
jamais la voix d'un autre héros quand une réplique manque.

## 3. `pnj_accueil/`

Chaque île possède un agent d'accueil vocal. Il détecte le héros contrôlé et choisit automatiquement :

- `bonjour_cheikh.ogg`
- `bonjour_yvane.ogg`
- `bonjour_nelvyn.ogg`

Les 33 premières salutations sont générées automatiquement en français pour servir de voix temporaires. Elles pourront être remplacées plus tard sans modifier le code.

## Formats

- voix courtes et musiques actuellement intégrées : `.mp3` ;
- `.ogg` reste accepté pour de futurs ajouts ;
- sources brutes : `.wav` accepté ;
- compresser les futurs fichiers pour limiter la taille de l'APK Android.
