import bpy
import pathlib
import sys

ROOT = pathlib.Path(sys.argv[sys.argv.index('--') + 1]).resolve() if '--' in sys.argv else pathlib.Path.cwd()
HEROES = {
    'cheikh': ROOT / 'joueur 1 cheikh anime.glb',
    'yvane': ROOT / 'Yvane_anime_Godot_Draco.glb',
    'nelvyn': ROOT / 'player_3_Nelvyn_Godot_anime (1).glb',
}

lines = ['# Rapport des rigs des héros', '', 'Généré automatiquement avec Blender.', '']

for hero, path in HEROES.items():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    lines += [f'## {hero.capitalize()}', '', f'- Fichier : `{path.name}`']
    if not path.exists():
        lines += ['- ERREUR : fichier absent', '']
        continue
    try:
        bpy.ops.import_scene.gltf(filepath=str(path))
    except Exception as exc:
        lines += [f'- ERREUR import : `{exc}`', '']
        continue

    armatures = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    lines += [f'- Armatures : {len(armatures)}', f'- Meshes : {len(meshes)}']
    if not armatures:
        lines += ['- Aucun squelette détecté.', '']
        continue

    for armature in armatures:
        bones = [b.name for b in armature.data.bones]
        lines += [f'- Armature `{armature.name}` : {len(bones)} os', '', '### Os', '']
        lines += [f'- `{name}`' for name in bones]

    actions = sorted({a.name for a in bpy.data.actions})
    lines += ['', '### Animations / actions', '']
    if actions:
        lines += [f'- `{name}`' for name in actions]
    else:
        lines += ['- Aucune action Blender détectée après import.']
    lines += ['']

out = ROOT / 'docs/HERO_RIG_REPORT.md'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(out)
