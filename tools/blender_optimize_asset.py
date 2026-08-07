import bpy
import math
import os
import sys
from mathutils import Vector


def arg_after_double_dash():
    argv = sys.argv
    if "--" not in argv:
        raise RuntimeError("Arguments manquants")
    return argv[argv.index("--") + 1:]


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def import_and_optimize(source_path, category):
    clear_scene()
    bpy.ops.import_scene.fbx(filepath=source_path)

    # Nous ne gardons que les meshes statiques du pack de décor.
    for obj in list(bpy.context.scene.objects):
        if obj.type not in {"MESH"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"Aucun mesh trouvé dans {source_path}")

    # Appliquer rotation et échelle avant fusion afin d'obtenir un GLB propre.
    for obj in meshes:
        select_only([obj])
        try:
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        except Exception:
            pass

    # Fusion des sous-meshes en un objet unique. Les slots de matériaux sont conservés.
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    select_only(meshes)
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = os.path.splitext(os.path.basename(source_path))[0]

    # Nettoyage géométrique léger.
    select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.remove_doubles(threshold=0.00001)
    except Exception:
        try:
            bpy.ops.mesh.merge_by_distance(threshold=0.00001)
        except Exception:
            pass
    try:
        bpy.ops.mesh.normals_make_consistent(inside=False)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")

    obj.data.validate(verbose=False)
    obj.data.update()

    # Les modèles Kenney sont déjà low-poly. On ne décime que les modèles
    # réellement denses afin de préserver la silhouette et les détails utiles.
    face_count = len(obj.data.polygons)
    ratio = 1.0
    if face_count > 20000:
        ratio = 0.78 if category == "boat" else 0.82
    elif face_count > 10000:
        ratio = 0.86 if category == "boat" else 0.90
    elif face_count > 5000:
        ratio = 0.93

    if ratio < 1.0:
        modifier = obj.modifiers.new(name="CHK_Mobile_Decimate", type="DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)

    # Repositionner l'origine au centre du sol pour faciliter le placement dans Godot.
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_x = min(v.x for v in corners)
    max_x = max(v.x for v in corners)
    min_y = min(v.y for v in corners)
    max_y = max(v.y for v in corners)
    min_z = min(v.z for v in corners)
    center = Vector(((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, min_z))
    obj.location -= center
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    # Kenney Pirate Kit utilise principalement des matériaux couleur unie.
    # Les UV inutiles peuvent être supprimés afin d'alléger les modèles statiques.
    if obj.data.uv_layers:
        while obj.data.uv_layers:
            obj.data.uv_layers.remove(obj.data.uv_layers[0])

    return obj, face_count, len(obj.data.polygons)


def export_glb(obj, output_path):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    select_only([obj])
    kwargs = dict(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=False,
        export_normals=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    bpy.ops.export_scene.gltf(**kwargs)


def render_preview(obj, output_path):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    scene = bpy.context.scene

    # Calcul de la taille du modèle après optimisation.
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_x = min(v.x for v in corners)
    max_x = max(v.x for v in corners)
    min_y = min(v.y for v in corners)
    max_y = max(v.y for v in corners)
    min_z = min(v.z for v in corners)
    max_z = max(v.z for v in corners)
    width = max_x - min_x
    depth = max_y - min_y
    height = max_z - min_z
    radius = max(width, depth, height, 0.1)
    target = Vector((0.0, 0.0, height * 0.38))

    # Caméra isométrique douce.
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = Vector((radius * 1.45, -radius * 1.75, radius * 1.15))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = radius * 2.15
    look_at(camera, target)
    scene.camera = camera

    # Éclairage léger pour bien lire les formes sans texture.
    key_data = bpy.data.lights.new(name="Key", type="AREA")
    key_data.energy = 900
    key_data.size = radius * 2.0
    key = bpy.data.objects.new(name="Key", object_data=key_data)
    scene.collection.objects.link(key)
    key.location = Vector((radius * 1.5, -radius * 1.0, radius * 2.2))
    look_at(key, target)

    fill_data = bpy.data.lights.new(name="Fill", type="AREA")
    fill_data.energy = 450
    fill_data.size = radius * 2.5
    fill = bpy.data.objects.new(name="Fill", object_data=fill_data)
    scene.collection.objects.link(fill)
    fill.location = Vector((-radius * 1.4, -radius * 0.5, radius * 1.2))
    look_at(fill, target)

    sun_data = bpy.data.lights.new(name="Sun", type="SUN")
    sun_data.energy = 1.5
    sun = bpy.data.objects.new(name="Sun", object_data=sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(35), math.radians(-20), math.radians(25))

    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        try:
            scene.render.engine = "BLENDER_EEVEE"
        except Exception:
            pass

    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.filepath = output_path

    # Color management stable entre versions de Blender.
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "Medium High Contrast"
        scene.view_settings.exposure = 0.0
        scene.view_settings.gamma = 1.0
    except Exception:
        pass

    bpy.ops.render.render(write_still=True)


def main():
    args = arg_after_double_dash()
    if len(args) != 4:
        raise RuntimeError("Usage: blender --background --python script.py -- source.fbx sortie.glb aperçu.png catégorie")

    source_path, output_glb, output_png, category = args
    obj, before_faces, after_faces = import_and_optimize(source_path, category)
    export_glb(obj, output_glb)
    render_preview(obj, output_png)

    source_size = os.path.getsize(source_path)
    output_size = os.path.getsize(output_glb)
    print(
        f"CHK_ASSET_OK source={source_path} glb={output_glb} "
        f"source_bytes={source_size} glb_bytes={output_size} "
        f"faces_before={before_faces} faces_after={after_faces}"
    )


if __name__ == "__main__":
    main()
