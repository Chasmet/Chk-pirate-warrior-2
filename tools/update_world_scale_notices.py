#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

ISLANDS = {
    1: {
        "path": "assets/royaumes/01_royaume_musical/README.md",
        "size": "1,2 km × 1,0 km",
        "walk": "8 à 12 minutes",
        "prev": None,
        "next": (2, "700 m"),
    },
    2: {
        "path": "assets/royaumes/02_royaume_sucrerie/README.md",
        "size": "1,3 km × 1,1 km",
        "walk": "9 à 13 minutes",
        "prev": (1, "700 m"),
        "next": (3, "850 m"),
    },
    3: {
        "path": "assets/royaumes/03_royaume_nourriture/README.md",
        "size": "1,5 km × 1,2 km",
        "walk": "10 à 15 minutes",
        "prev": (2, "850 m"),
        "next": (4, "1 000 m"),
    },
    4: {
        "path": "assets/royaumes/04_royaume_fantastique/README.md",
        "size": "1,7 km × 1,4 km",
        "walk": "12 à 17 minutes",
        "prev": (3, "1 000 m"),
        "next": (5, "1 150 m"),
    },
    5: {
        "path": "assets/royaumes/05_royaume_marvel/README.md",
        "size": "2,2 km × 1,7 km",
        "walk": "15 à 22 minutes",
        "prev": (4, "1 150 m"),
        "next": (6, "900 m"),
    },
    6: {
        "path": "assets/royaumes/06_royaume_pokemon/README.md",
        "size": "1,9 km × 1,5 km",
        "walk": "13 à 18 minutes",
        "prev": (5, "900 m"),
        "next": (7, "1 250 m"),
    },
    7: {
        "path": "assets/royaumes/07_ile_des_pirates/README.md",
        "size": "2,4 km × 1,8 km",
        "walk": "16 à 24 minutes",
        "prev": (6, "1 250 m"),
        "next": (8, "1 350 m"),
    },
    8: {
        "path": "assets/royaumes/08_royaume_des_neiges/README.md",
        "size": "2,2 km × 1,8 km",
        "walk": "15 à 22 minutes",
        "prev": (7, "1 350 m"),
        "next": (9, "1 100 m"),
    },
    9: {
        "path": "assets/royaumes/09_royaume_de_feu/README.md",
        "size": "2,3 km × 1,8 km",
        "walk": "15 à 22 minutes",
        "prev": (8, "1 100 m"),
        "next": (10, "1 400 m"),
    },
    10: {
        "path": "assets/royaumes/10_royaume_de_la_terre/README.md",
        "size": "2,6 km × 2,0 km",
        "walk": "18 à 26 minutes",
        "prev": (9, "1 400 m"),
        "next": (11, "1 500 m"),
    },
    11: {
        "path": "assets/royaumes/11_royaume_trouble_final/README.md",
        "size": "3,0 km × 2,3 km",
        "walk": "20 à 30 minutes",
        "prev": (10, "1 500 m"),
        "next": None,
    },
}

START = "<!-- WORLD_SCALE_START -->"
END = "<!-- WORLD_SCALE_END -->"


def replace_block(text: str, block: str, before_heading: str | None = None) -> str:
    pattern = re.compile(re.escape(START) + r".*?" + re.escape(END), re.S)
    if pattern.search(text):
        return pattern.sub(block, text)
    if before_heading and before_heading in text:
        return text.replace(before_heading, block + "\n\n" + before_heading, 1)
    return text.rstrip() + "\n\n" + block + "\n"


def route_line(route, direction: str) -> str:
    if route is None:
        return ""
    island, distance = route
    return f"- Mer ouverte vers l’Île {island:02d} ({direction}) : **{distance} entre les côtes navigables**."


def island_block(index: int, data: dict) -> str:
    routes = [route_line(data["prev"], "royaume précédent"), route_line(data["next"], "royaume suivant")]
    routes = "\n".join(x for x in routes if x)
    return f"""{START}
## Échelle officielle, dimensions et navigation maritime

Cette règle est obligatoire pour la construction de la version jouable de l’Île {index:02d}.

- **Dimension cible de l’île : {data['size']}** d’emprise terrestre jouable approximative, hors mer.
- **Aucune île principale ne doit descendre sous 1 km de dimension utile.** Les dimensions indiquées sont des cibles minimales de conception et peuvent être agrandies si le relief ou le contenu le justifie.
- Temps de traversée recherché en exploration normale, avec routes, reliefs, rencontres et détours : **{data['walk']}**. Il ne s’agit pas du temps d’un sprint parfaitement droit d’un bord à l’autre.
- Les distances maritimes sont toujours mesurées **de côte navigable à côte navigable**, jamais de centre d’île à centre d’île.
{routes}
- L’arrivée depuis la mer doit rester continue : le joueur navigue réellement jusqu’au port, à une plage ou à un point d’accostage. Pas de téléportation automatique entre deux îles principales.
- L’île doit rester visible progressivement depuis la mer grâce à sa silhouette, ses montagnes, tours, lumières ou monuments caractéristiques.
- Pour Android, le territoire doit être découpé en cellules de streaming d’environ **250 × 250 m**, regroupées en macro-secteurs pouvant atteindre **500 × 500 m**. Seules les zones proches du joueur sont maintenues en haute qualité.
- Utiliser LOD, occlusion, MultiMesh/instances, collisions simplifiées et chargement/déchargement par distance afin que la taille du royaume ne force jamais le téléphone à charger toute l’île en détail simultanément.
- Les panoramas lointains et les autres îles visibles à l’horizon peuvent employer des versions très simplifiées jusqu’à l’approche du joueur.
{END}"""


def global_block() -> str:
    rows = []
    for i, d in ISLANDS.items():
        rows.append(f"| Île {i:02d} | {d['size']} | {d['walk']} |")
    route_rows = []
    for i in range(1, 11):
        distance = ISLANDS[i]["next"][1]
        route_rows.append(f"| Île {i:02d} ↔ Île {i+1:02d} | {distance} |")
    return f"""{START}
## Échelle officielle du monde et distances entre les îles

Les dimensions et distances ci-dessous deviennent la référence obligatoire de conception du monde ouvert.

### Taille minimale des royaumes

- **Chaque île principale doit mesurer au minimum 1 km dans sa dimension utile.**
- Les dimensions ci-dessous correspondent à l’emprise terrestre jouable cible, hors surface maritime.
- Une île peut être agrandie si son contenu, son relief ou ses quêtes le nécessitent, mais elle ne doit pas être réduite sous cette échelle sans décision explicite de conception.

| Royaume | Emprise jouable cible | Traversée en exploration normale |
|---|---:|---:|
{chr(10).join(rows)}

### Distances maritimes officielles

Les distances sont mesurées **entre les côtes navigables les plus logiques des îles voisines**, et non entre leurs centres. Cela garantit une vraie zone maritime même lorsque les îles font plusieurs kilomètres de large.

| Liaison principale | Mer ouverte à parcourir |
|---|---:|
{chr(10).join(route_rows)}

La règle générale est donc : **environ 700 m à 1,5 km de mer ouverte entre deux royaumes voisins**.

### Conséquences obligatoires pour le gameplay

- Les déplacements entre royaumes doivent se faire réellement en bateau, sans écran de téléportation automatique.
- Les traversées maritimes doivent contenir de l’activité : navires marchands, pirates, équipages indépendants, pêcheurs, faune marine, épaves, météo et événements aléatoires.
- Les îles doivent apparaître progressivement à l’horizon. Leurs repères majeurs doivent être visibles avant l’arrivée lorsque la météo le permet.
- La mer ne doit pas ressembler à un simple couloir entre deux niveaux : le joueur doit pouvoir s’écarter de la route directe pour explorer, combattre ou chercher des secrets.
- Les zones côtières, ports et points d’accostage doivent être conçus à l’échelle des distances réelles.

### Streaming et optimisation Android

La grande taille du monde ne signifie jamais que tout doit être chargé simultanément.

- Découper les îles en cellules d’environ **250 × 250 m**.
- Regrouper les cellules en macro-secteurs jusqu’à **500 × 500 m** pour l’organisation du monde.
- Charger en détail uniquement les secteurs proches du joueur.
- Décharger les PNJ, collisions complexes, intérieurs et objets interactifs éloignés.
- Employer plusieurs niveaux de détail pour bâtiments, végétation, bateaux et reliefs.
- Les îles éloignées doivent utiliser des silhouettes/meshes très simplifiés jusqu’à l’approche.
- Les routes maritimes doivent utiliser le même principe de streaming afin que les navires et événements éloignés n’occupent pas inutilement la mémoire.
- Éviter les murs invisibles autour des îles ; les limites du monde doivent être placées largement au-delà de l’archipel ou justifiées par le scénario.
{END}"""


def main() -> None:
    changed = []

    global_path = ROOT / "NOTICE_EXPLICATIVE_PIRATE_2.md"
    global_text = global_path.read_text(encoding="utf-8")
    updated_global = replace_block(global_text, global_block(), "## 3. Contenu obligatoire de chaque île")
    if updated_global != global_text:
        global_path.write_text(updated_global, encoding="utf-8")
        changed.append(str(global_path.relative_to(ROOT)))

    for index, data in ISLANDS.items():
        path = ROOT / data["path"]
        text = path.read_text(encoding="utf-8")
        updated = replace_block(text, island_block(index, data), "## Relief et géographie")
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed.append(data["path"])

    print("Notices mises à jour :")
    for path in changed:
        print("-", path)
    print(f"Total : {len(changed)} fichier(s)")


if __name__ == "__main__":
    main()
