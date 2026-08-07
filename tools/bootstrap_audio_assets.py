import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path.cwd()
AUDIO = ROOT / "assets/audio"

islands = {
    1: "Royaume Musical",
    2: "Royaume Sucrerie",
    3: "Royaume de la Nourriture",
    4: "Royaume Fantastique",
    5: "Royaume des Héros Futuristes",
    6: "Royaume des Créatures",
    7: "Île des Pirates",
    8: "Royaume des Neiges",
    9: "Royaume de Feu",
    10: "Royaume de la Terre",
    11: "Royaume Troublé",
}
heroes = {
    "cheikh": "Cheikh",
    "yvane": "Yvane",
    "nelvyn": "Nelvyn",
}

music_root = AUDIO / "bandes_son"
voice_root = AUDIO / "personnages_principaux"
npc_root = AUDIO / "pnj_accueil"
for p in (music_root, voice_root, npc_root):
    p.mkdir(parents=True, exist_ok=True)

(music_root / "README.md").write_text(
    "# Bandes son des 11 îles\n\nChaque île possède son propre dossier.\n\n"
    "Fichiers recommandés par île : `theme_principal.ogg`, `ambiance.ogg`, `combat.ogg`, `boss.ogg`.\n"
    "Le jeu charge automatiquement `theme_principal.ogg` et `ambiance.ogg` quand ils sont présents.\n",
    encoding="utf-8",
)

for island_id, island_name in islands.items():
    folder = music_root / f"ile_{island_id:02d}"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "README.md").write_text(
        f"# Audio — Île {island_id} — {island_name}\n\n"
        "Déposer ici :\n\n"
        "- `theme_principal.ogg` : musique d'exploration ;\n"
        "- `ambiance.ogg` : ambiance naturelle/urbaine ;\n"
        "- `combat.ogg` : musique de combat ;\n"
        "- `boss.ogg` : musique du boss.\n",
        encoding="utf-8",
    )

(voice_root / "README.md").write_text(
    "# Voix des personnages principaux\n\n"
    "Déposer ici les vrais enregistrements de Cheikh, Yvane et Nelvyn. Les fichiers peuvent remplacer ou compléter les voix de gameplay sans modifier le code.\n",
    encoding="utf-8",
)

expected = [
    "bonjour.ogg",
    "attaque_01.ogg",
    "attaque_02.ogg",
    "pouvoir_01.ogg",
    "pouvoir_02.ogg",
    "douleur_01.ogg",
    "victoire.ogg",
    "coffre_trouve.ogg",
    "objet_rare.ogg",
    "embarquement.ogg",
]
for hero_id, hero_name in heroes.items():
    folder = voice_root / hero_id
    folder.mkdir(parents=True, exist_ok=True)
    lines = [f"# Voix — {hero_name}", "", "Déposer les enregistrements dans ce dossier.", "", "Noms conseillés :"]
    lines.extend([f"- `{name}`" for name in expected])
    (folder / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

(npc_root / "README.md").write_text(
    "# Agents d'accueil vocaux\n\n"
    "Chaque île contient trois salutations françaises : une pour Cheikh, une pour Yvane et une pour Nelvyn.\n\n"
    "Les fichiers générés automatiquement sont des voix temporaires hors ligne. Ils pourront être remplacés plus tard par de meilleures voix françaises sans changer les noms de fichiers.\n",
    encoding="utf-8",
)

dialogues = {}
for island_id, island_name in islands.items():
    folder = npc_root / f"ile_{island_id:02d}"
    folder.mkdir(parents=True, exist_ok=True)
    dialogues[str(island_id)] = {}
    readme = [f"# Agent d'accueil — Île {island_id} — {island_name}", ""]
    for hero_id, hero_name in heroes.items():
        text = f"Bonjour {hero_name}. Bienvenue sur l'île numéro {island_id}."
        dialogues[str(island_id)][hero_id] = text
        wav = folder / f"bonjour_{hero_id}.wav"
        ogg = folder / f"bonjour_{hero_id}.ogg"
        subprocess.run([
            "espeak-ng", "-v", "fr-fr", "-s", "155", "-p", "48", "-w", str(wav), text
        ], check=True)
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(ogg)
        ], check=True)
        wav.unlink(missing_ok=True)
        readme.append(f"- `{ogg.name}` → « {text} »")
    (folder / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")

(npc_root / "dialogues.json").write_text(json.dumps(dialogues, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("Audio initialisé : 11 dossiers de bandes son, 3 dossiers héros et 33 salutations vocales PNJ.")
