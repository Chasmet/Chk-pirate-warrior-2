# Audio — CHK Pirate Warrior 2

L'audio est séparé en trois zones principales.

## 1. `bandes_son/`

Un dossier par île : `ile_01` à `ile_11`.

Fichiers prévus dans chaque dossier :

- `theme_principal.ogg` : musique d'exploration ;
- `ambiance.ogg` : ambiance de l'île ;
- `combat.ogg` : musique de combat ;
- `boss.ogg` : musique de boss.

Tu peux déposer progressivement tes propres bandes son dans ces dossiers. Le jeu charge automatiquement les fichiers quand ils existent.

## 2. `personnages_principaux/`

Trois dossiers réservés aux vrais enregistrements :

- `cheikh/`
- `yvane/`
- `nelvyn/`

Les README de chaque héros indiquent les noms conseillés (`bonjour.ogg`, `attaque_01.ogg`, `pouvoir_01.ogg`, etc.).

## 3. `pnj_accueil/`

Chaque île possède un agent d'accueil vocal. Il détecte le héros contrôlé et choisit automatiquement :

- `bonjour_cheikh.ogg`
- `bonjour_yvane.ogg`
- `bonjour_nelvyn.ogg`

Les 33 premières salutations sont générées automatiquement en français pour servir de voix temporaires. Elles pourront être remplacées plus tard sans modifier le code.

## Formats

- voix et musiques : `.ogg` recommandé ;
- sources brutes : `.wav` accepté ;
- éviter les MP3 très lourds pour la version Android.
