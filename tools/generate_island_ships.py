import bpy
import math
import os
import pathlib
import sys
from mathutils import Vector


VARIANTS = [
    {"island": 1, "slug": "corsaire_du_rivage", "base": "dark", "feature": "corsair", "scale": (1.00, 1.00, 1.00), "primary": (0.08, 0.08, 0.10, 1), "secondary": (0.75, 0.12, 0.08, 1)},
    {"island": 2, "slug": "requin_noir", "base": "dark", "feature": "shark", "scale": (1.06, 0.95, 0.98), "primary": (0.03, 0.09, 0.12, 1), "secondary": (0.05, 0.60, 0.72, 1)},
    {"island": 3, "slug": "galion_gourmand", "base": "light", "feature": "gourmand", "scale": (0.98, 1.04, 1.02), "primary": (0.52, 0.18, 0.05, 1), "secondary": (0.95, 0.72, 0.12, 1)},
    {"island": 4, "slug": "roc_des_mers", "base": "dark", "feature": "rock", "scale": (1.12, 1.02, 0.95), "primary": (0.22, 0.24, 0.26, 1), "secondary": (0.52, 0.56, 0.58, 1)},
    {"island": 5, "slug": "volcan_rouge", "base": "dark", "feature": "volcano", "scale": (1.04, 1.00, 1.04), "primary": (0.20, 0.02, 0.01, 1), "secondary": (0.95, 0.18, 0.02, 1)},
    {"island": 6, "slug": "brume_des_marais", "base": "dark", "feature": "marsh", "scale": (0.96, 1.06, 1.00), "primary": (0.05, 0.18, 0.10, 1), "secondary": (0.30, 0.75, 0.35, 1)},
    {"island": 7, "slug": "forteresse_flottante", "base": "light", "feature": "fortress", "scale": (1.16, 1.08, 1.00), "primary": (0.18, 0.18, 0.20, 1), "secondary": (0.65, 0.58, 0.42, 1)},
    {"island": 8, "slug": "jungle_emeraude", "base": "light", "feature": "jungle", "scale": (1.02, 1.00, 1.08), "primary": (0.04, 0.24, 0.08, 1), "secondary": (0.12, 0.70, 0.20, 1)},
    {"island": 9, "slug": "abysses_bleus", "base": "dark", "feature": "abyss", "scale": (1.08, 0.98, 1.10), "primary": (0.02, 0.04, 0.15, 1), "secondary": (0.12, 0.38, 0.95, 1)},
    {"island": 10, "slug": "galion_royal", "base": "light", "feature": "royal", "scale": (1.10, 1.05, 1.10), "primary": (0.35, 0.10, 0.28, 1), "secondary": (0.95, 0.72, 0.16, 1)},
    {"island": 11, "slug": "spectre_des_souvenirs", "base": "dark", "feature": "memory", "scale": (1.00, 0.94, 1.14), "primary": (0.20, 0.16, 0.28, 1), "secondary": (0.72, 0.58, 0.92, 1)},
]


def args_after_double_dash():
    argv = sys.argv
    if "--" not in argv:
        raise RuntimeError("Usage: blender --background --python generate_island_ships.py -- repo_root")
    return argv[argv.index("--") + 1:]


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights, bpy.data.materials):
        pass


def material(name, rgba, metallic=0.0, roughness=0.55):
    mat = bpy.data.materials.new(name=name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    mat.use_backface_culling = False
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = rgba
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
    return mat


def assign_mat(obj, mat):
    if obj.type == "MESH":
        obj.data.materials.clear()
        obj.data.materials.append(mat)


def cube(name, location, scale, mat, parent):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign_mat(obj, mat)
    obj.parent = parent
    return obj


def sphere(name, location, radius, mat, parent):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    obj.parent = parent
    return obj


def cone(name, location, radius, depth, rotation, mat, parent):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=radius, radius2=0.0, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    obj.parent = parent
    return obj


def cylinder(name, location, radius, depth, rotation, mat, parent):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    obj.parent = parent
    return obj


def torus(name, location, major_radius, minor_radius, rotation, mat, parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius, major_segments=16, minor_segments=6, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign_mat(obj, mat)
    obj.parent = parent
    return obj


def mesh_flag(name, location, width, height, mat, parent):
    mesh = bpy.data.meshes.new(name + "Mesh")
    verts = [(0, 0, 0), (width, 0, -height * 0.15), (width * 0.72, 0, -height * 0.5), (width, 0, -height), (0, 0, -height)]
    faces = [(0, 1, 2, 3, 4)]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    assign_mat(obj, mat)
    obj.parent = parent
    return obj


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bounds(objects=None):
    objects = objects or mesh_objects()
    points = []
    for obj in objects:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    if not points:
        return (-1, 1, -1, 1, 0, 2)
    return (
        min(p.x for p in points), max(p.x for p in points),
        min(p.y for p in points), max(p.y for p in points),
        min(p.z for p in points), max(p.z for p in points),
    )


def normalize_import_root(root):
    top = [o for o in bpy.context.scene.objects if o is not root and o.parent is None and o.type not in {"CAMERA", "LIGHT"}]
    for obj in top:
        obj.parent = root


def add_flag_set(root, b, primary, secondary, island):
    min_x, max_x, min_y, max_y, min_z, max_z = b
    sx = max_x - min_x
    sy = max_y - min_y
    sz = max_z - min_z
    flag_ctrl = bpy.data.objects.new(f"Ile_{island:02d}_Flag_Control", None)
    bpy.context.scene.collection.objects.link(flag_ctrl)
    flag_ctrl.location = (0, 0, 0)
    flag_ctrl.parent = root
    f1 = mesh_flag("Grand_Pavillon", (0, min_y * 0.08, max_z * 0.96), sx * 0.22, sz * 0.18, primary, flag_ctrl)
    f2 = mesh_flag("Pavillon_Secondaire", (-sx * 0.12, min_y * 0.05, max_z * 0.72), sx * 0.13, sz * 0.11, secondary, flag_ctrl)
    for f in (f1, f2):
        f.rotation_euler = (math.radians(90), 0, 0)
    return flag_ctrl


def add_features(feature, root, b, primary, secondary):
    min_x, max_x, min_y, max_y, min_z, max_z = b
    sx = max_x - min_x
    sy = max_y - min_y
    sz = max_z - min_z
    deck_z = min_z + sz * 0.42
    accent_ctrl = bpy.data.objects.new("Theme_Animation_Control", None)
    bpy.context.scene.collection.objects.link(accent_ctrl)
    accent_ctrl.parent = root

    if feature == "corsair":
        for side in (-1, 1):
            cylinder("Canon_Decor", (side * sx * 0.28, 0, deck_z), sz * 0.035, sy * 0.18, (math.radians(90), 0, 0), secondary, root)
        cube("Coffre_Commandement", (0, -sy * 0.12, deck_z + sz * 0.05), (sx * 0.08, sy * 0.06, sz * 0.05), primary, root)

    elif feature == "shark":
        for side in (-1, 1):
            cone("Aileron", (side * sx * 0.42, min_y * 0.12, deck_z), sz * 0.10, sx * 0.34, (0, math.radians(90), 0), secondary, root)
        cone("Eperon_Requin", (0, min_y * 0.72, deck_z), sz * 0.12, sy * 0.42, (math.radians(90), 0, 0), primary, root)

    elif feature == "gourmand":
        fruit_colors = [secondary, material("Fruit_Rouge", (0.8, 0.08, 0.03, 1)), material("Fruit_Vert", (0.08, 0.55, 0.12, 1))]
        for i in range(7):
            x = (i % 4 - 1.5) * sx * 0.08
            y = (i // 4 - 0.5) * sy * 0.12
            sphere(f"Cargaison_Fruit_{i}", (x, y, deck_z + sz * 0.08), sz * 0.045, fruit_colors[i % len(fruit_colors)], accent_ctrl)
        cube("Grande_Caisse", (0, max_y * 0.18, deck_z + sz * 0.05), (sx * 0.12, sy * 0.09, sz * 0.07), primary, root)

    elif feature == "rock":
        for i, x in enumerate((-0.28, -0.12, 0.12, 0.28)):
            cone(f"Cristal_Roc_{i}", (sx * x, 0, deck_z + sz * 0.10), sz * 0.055, sz * 0.32, (0, 0, 0), secondary, accent_ctrl)
        for side in (-1, 1):
            cube("Blindage_Roc", (side * sx * 0.38, 0, deck_z), (sx * 0.05, sy * 0.22, sz * 0.08), primary, root)

    elif feature == "volcano":
        for i, x in enumerate((-0.22, 0.0, 0.22)):
            cone(f"Pic_Volcan_{i}", (sx * x, 0, deck_z + sz * 0.10), sz * 0.07, sz * 0.42, (0, 0, 0), secondary, accent_ctrl)
        cylinder("Cheminee_Volcan", (0, max_y * 0.12, deck_z + sz * 0.16), sz * 0.07, sz * 0.30, (0, 0, 0), primary, root)

    elif feature == "marsh":
        for i, x in enumerate((-0.30, -0.10, 0.10, 0.30)):
            sphere(f"Lanterne_Marais_{i}", (sx * x, 0, deck_z + sz * 0.18), sz * 0.04, secondary, accent_ctrl)
            cylinder(f"Poteau_Marais_{i}", (sx * x, 0, deck_z + sz * 0.08), sz * 0.015, sz * 0.18, (0, 0, 0), primary, root)
        torus("Anneau_Marais", (0, min_y * 0.28, deck_z + sz * 0.04), sx * 0.13, sz * 0.025, (math.radians(90), 0, 0), secondary, root)

    elif feature == "fortress":
        for side in (-1, 1):
            cube("Plaque_Blindage", (side * sx * 0.42, 0, deck_z), (sx * 0.055, sy * 0.34, sz * 0.11), primary, root)
            for j in (-0.20, 0.0, 0.20):
                cylinder("Canon_Forteresse", (side * sx * 0.46, sy * j, deck_z + sz * 0.03), sz * 0.025, sx * 0.12, (0, math.radians(90), 0), secondary, root)
        cube("Tour_Centrale", (0, max_y * 0.10, deck_z + sz * 0.16), (sx * 0.10, sy * 0.10, sz * 0.16), primary, root)

    elif feature == "jungle":
        for i, x in enumerate((-0.30, -0.10, 0.10, 0.30)):
            sphere(f"Feuillage_{i}", (sx * x, 0, deck_z + sz * 0.20), sz * 0.085, secondary, accent_ctrl)
            cylinder(f"Tronc_{i}", (sx * x, 0, deck_z + sz * 0.10), sz * 0.025, sz * 0.22, (0, 0, 0), primary, root)
        torus("Liane_Arc", (0, min_y * 0.22, deck_z + sz * 0.18), sx * 0.15, sz * 0.02, (math.radians(90), 0, 0), secondary, root)

    elif feature == "abyss":
        for i, x in enumerate((-0.32, -0.16, 0.0, 0.16, 0.32)):
            cone(f"Cristal_Abysses_{i}", (sx * x, 0, deck_z + sz * 0.14), sz * 0.045, sz * (0.24 + 0.03 * (i % 2)), (0, 0, 0), secondary, accent_ctrl)
        for side in (-1, 1):
            torus("Anneau_Abysses", (side * sx * 0.28, min_y * 0.18, deck_z), sx * 0.08, sz * 0.018, (math.radians(90), 0, 0), primary, root)

    elif feature == "royal":
        gold = secondary
        for side in (-1, 1):
            cube("Balcon_Royal", (side * sx * 0.32, max_y * 0.08, deck_z + sz * 0.10), (sx * 0.11, sy * 0.08, sz * 0.06), primary, root)
        for i, x in enumerate((-0.18, 0.0, 0.18)):
            cone(f"Pointe_Couronne_{i}", (sx * x, max_y * 0.12, deck_z + sz * 0.28), sz * 0.05, sz * 0.20, (0, 0, 0), gold, accent_ctrl)
        torus("Embleme_Royal", (0, min_y * 0.30, deck_z + sz * 0.12), sx * 0.11, sz * 0.025, (math.radians(90), 0, 0), gold, root)

    elif feature == "memory":
        for i, x in enumerate((-0.30, -0.15, 0.0, 0.15, 0.30)):
            sphere(f"Fragment_Souvenir_{i}", (sx * x, 0, deck_z + sz * (0.17 + 0.04 * (i % 2))), sz * 0.045, secondary, accent_ctrl)
        torus("Halo_Souvenir", (0, min_y * 0.24, deck_z + sz * 0.18), sx * 0.16, sz * 0.02, (math.radians(90), 0, 0), primary, accent_ctrl)
        cone("Eperon_Spectral", (0, min_y * 0.72, deck_z), sz * 0.10, sy * 0.38, (math.radians(90), 0, 0), secondary, root)

    return accent_ctrl


def animate(root, flag_ctrl, accent_ctrl, island):
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 120
    scene.render.fps = 30

    amp = math.radians(1.4 + island * 0.08)
    for frame, z, roll, pitch in [
        (1, 0.00, 0.0, -0.25),
        (30, 0.025, 1.0, 0.20),
        (60, 0.00, 0.0, 0.30),
        (90, -0.025, -1.0, -0.18),
        (120, 0.00, 0.0, -0.25),
    ]:
        scene.frame_set(frame)
        root.location.z = z
        root.rotation_euler.x = amp * roll
        root.rotation_euler.y = amp * pitch
        root.keyframe_insert(data_path="location", frame=frame)
        root.keyframe_insert(data_path="rotation_euler", frame=frame)
    if root.animation_data and root.animation_data.action:
        root.animation_data.action.name = "Idle_Ocean"

    for frame, angle in [(1, -5), (20, 7), (40, -8), (60, 6), (80, -7), (100, 8), (120, -5)]:
        scene.frame_set(frame)
        flag_ctrl.rotation_euler.z = math.radians(angle)
        flag_ctrl.rotation_euler.x = math.radians(angle * 0.25)
        flag_ctrl.keyframe_insert(data_path="rotation_euler", frame=frame)
    if flag_ctrl.animation_data and flag_ctrl.animation_data.action:
        flag_ctrl.animation_data.action.name = "Flag_Wave"

    for frame, z, rot in [(1, 0.0, 0), (30, 0.035, 4), (60, 0.0, 0), (90, -0.025, -4), (120, 0.0, 0)]:
        scene.frame_set(frame)
        accent_ctrl.location.z = z
        accent_ctrl.rotation_euler.z = math.radians(rot)
        accent_ctrl.keyframe_insert(data_path="location", frame=frame)
        accent_ctrl.keyframe_insert(data_path="rotation_euler", frame=frame)
    if accent_ctrl.animation_data and accent_ctrl.animation_data.action:
        accent_ctrl.animation_data.action.name = "Theme_Motion"

    scene.frame_set(1)


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_preview(output_png):
    scene = bpy.context.scene
    b = bounds()
    min_x, max_x, min_y, max_y, min_z, max_z = b
    sx, sy, sz = max_x - min_x, max_y - min_y, max_z - min_z
    radius = max(sx, sy, sz, 1.0)
    target = Vector(((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, min_z + sz * 0.45))

    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam = bpy.data.objects.new("PreviewCamera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = Vector((radius * 1.35, -radius * 1.65, radius * 0.95))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = radius * 2.05
    look_at(cam, target)
    scene.camera = cam

    key_data = bpy.data.lights.new("Key", type="AREA")
    key_data.energy = 1100
    key_data.size = radius * 2.2
    key = bpy.data.objects.new("Key", key_data)
    scene.collection.objects.link(key)
    key.location = Vector((radius * 1.4, -radius * 0.8, radius * 2.0))
    look_at(key, target)

    fill_data = bpy.data.lights.new("Fill", type="AREA")
    fill_data.energy = 500
    fill_data.size = radius * 2.8
    fill = bpy.data.objects.new("Fill", fill_data)
    scene.collection.objects.link(fill)
    fill.location = Vector((-radius * 1.0, -radius * 0.3, radius * 1.3))
    look_at(fill, target)

    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.filepath = str(output_png)
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "Medium High Contrast"
    except Exception:
        pass
    bpy.ops.render.render(write_still=True)


def export_glb(output_glb):
    scene = bpy.context.scene
    bpy.ops.object.select_all(action="DESELECT")
    for obj in scene.objects:
        if obj.type not in {"CAMERA", "LIGHT"}:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(output_glb),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=True,
        export_frame_range=True,
        export_force_sampling=True,
    )


def generate_variant(repo_root, variant, out_glb_dir, out_png_dir):
    clear_scene()
    base_name = "navire_pirate_sombre.glb" if variant["base"] == "dark" else "navire_pirate_clair.glb"
    base_path = repo_root / "assets/bateaux_glb/glb" / base_name
    if not base_path.exists():
        raise RuntimeError(f"Base introuvable : {base_path}")
    bpy.ops.import_scene.gltf(filepath=str(base_path))

    root = bpy.data.objects.new(f"CHK_Island_{variant['island']:02d}_Ship_Root", None)
    bpy.context.scene.collection.objects.link(root)
    root.rotation_mode = "XYZ"
    normalize_import_root(root)
    root.scale = variant["scale"]

    primary = material(f"Ile_{variant['island']:02d}_Primary", variant["primary"], metallic=0.10, roughness=0.50)
    secondary = material(f"Ile_{variant['island']:02d}_Secondary", variant["secondary"], metallic=0.18, roughness=0.40)

    b = bounds()
    flag_ctrl = add_flag_set(root, b, primary, secondary, variant["island"])
    accent_ctrl = add_features(variant["feature"], root, b, primary, secondary)
    animate(root, flag_ctrl, accent_ctrl, variant["island"])

    out_glb = out_glb_dir / f"ile_{variant['island']:02d}_{variant['slug']}_anime.glb"
    out_png = out_png_dir / f"ile_{variant['island']:02d}_{variant['slug']}.png"
    render_preview(out_png)
    export_glb(out_glb)
    return out_glb, out_png


def main():
    args = args_after_double_dash()
    if len(args) != 1:
        raise RuntimeError("Un seul argument attendu : repo_root")
    repo_root = pathlib.Path(args[0]).resolve()
    out_root = repo_root / "assets/bateaux_glb/iles_animes"
    out_glb_dir = out_root / "glb"
    out_png_dir = out_root / "png"
    out_glb_dir.mkdir(parents=True, exist_ok=True)
    out_png_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for variant in VARIANTS:
        glb, png = generate_variant(repo_root, variant, out_glb_dir, out_png_dir)
        rows.append((variant, glb.stat().st_size, png.stat().st_size))
        print(f"CHK_SHIP_OK ile={variant['island']} glb={glb} bytes={glb.stat().st_size}")

    readme = out_root / "README.md"
    lines = [
        "# Navires animés des 11 îles", "",
        "Chaque île possède son propre navire pirate GLB avec silhouette/accessoires distinctifs et animations intégrées.", "",
        "Animations intégrées :", "",
        "- `Idle_Ocean` : roulis/tangage léger du navire ;",
        "- `Flag_Wave` : mouvement des pavillons ;",
        "- `Theme_Motion` : animation légère des éléments spécifiques au navire.", "",
        "Les modèles de coque utilisés comme base proviennent du **Kenney Pirate Kit — CC0 1.0**. Les éléments distinctifs ont été générés spécifiquement pour CHK Pirate Warrior 2.", "",
        "| Île | Navire | GLB | Taille |", "|---:|---|---|---:|",
    ]
    for variant, glb_size, _ in rows:
        filename = f"ile_{variant['island']:02d}_{variant['slug']}_anime.glb"
        lines.append(f"| {variant['island']} | {variant['slug'].replace('_', ' ').title()} | `{filename}` | {glb_size/1024:.1f} Ko |")
    lines += [
        "", "## Utilisation dans Godot", "",
        "Importer le GLB puis choisir l'animation voulue dans `AnimationPlayer`. Pour un bateau contrôlé par le joueur, `Idle_Ocean` peut être désactivée pendant les déplacements si la physique du bateau gère déjà le roulis.",
        "", "Licence des coques de base : **CC0 1.0 Universal**.",
    ]
    readme.write_text("\n".join(lines) + "\n", encoding="utf-8")

    source_doc = out_root / "LICENSE_SOURCES.md"
    source_doc.write_text(
        "# Licence et provenance\n\n"
        "Coques de base : **Kenney — Pirate Kit**.\n\n"
        "- Licence : Creative Commons CC0 1.0 Universal\n"
        "- Page officielle : https://kenney.nl/assets/pirate-kit\n"
        "- Attribution non obligatoire\n"
        "- Usage commercial et non commercial autorisé\n\n"
        "Les accessoires, variantes et animations ajoutés par le pipeline du projet sont générés localement avec Blender.\n",
        encoding="utf-8"
    )


if __name__ == "__main__":
    main()
