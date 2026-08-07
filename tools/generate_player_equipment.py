import bpy
import math
import pathlib
import sys
from mathutils import Vector


def repo_root():
    args = sys.argv
    if "--" in args:
        extra = args[args.index("--") + 1:]
        if extra:
            return pathlib.Path(extra[0]).resolve()
    return pathlib.Path.cwd()

ROOT = repo_root()
BAG_GLB = ROOT / "assets/equipements/sacs_a_dos/glb"
BAG_PNG = ROOT / "assets/equipements/sacs_a_dos/png"
WEAPON_GLB = ROOT / "assets/equipements/armes/glb"
WEAPON_PNG = ROOT / "assets/equipements/armes/png"
for p in (BAG_GLB, BAG_PNG, WEAPON_GLB, WEAPON_PNG):
    p.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass


def mat(name, color, metallic=0.0, roughness=0.55):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (*color, 1.0)
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
    return m


def rounded_box(name, dims, loc, material, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = o.modifiers.new('Bevel', 'BEVEL')
    mod.width = bevel
    mod.segments = 3
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.append(material)
    return o


def cylinder(name, radius, depth, loc, material, rotation=(0,0,0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    return o


def torus(name, major_radius, minor_radius, loc, material, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius, major_segments=24, minor_segments=8, location=loc, rotation=rotation)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    return o


def add_camera_and_lights(target=Vector((0,0,0))):
    bpy.ops.object.camera_add(location=(1.65, -2.65, 1.35))
    cam = bpy.context.object
    bpy.context.scene.camera = cam
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = 58
    bpy.ops.object.light_add(type='AREA', location=(2.2, -2.0, 3.0))
    key = bpy.context.object
    key.data.energy = 850
    key.data.shape = 'DISK'
    key.data.size = 4.0
    bpy.ops.object.light_add(type='AREA', location=(-2.0, -0.5, 1.8))
    fill = bpy.context.object
    fill.data.energy = 500
    fill.data.size = 3.0
    bpy.ops.object.light_add(type='AREA', location=(0.0, 2.0, 2.2))
    rim = bpy.context.object
    rim.data.energy = 600
    rim.data.size = 2.0


def render_preview(path):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = True
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def export_glb(path):
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format='GLB',
        export_apply=True,
        export_animations=False,
        export_materials='EXPORT',
        export_yup=True
    )


def make_backpack(name, color):
    clear_scene()
    fabric = mat(name + '_fabric', color, 0.0, 0.72)
    dark = mat(name + '_dark', (0.025, 0.03, 0.04), 0.05, 0.62)
    metal = mat(name + '_metal', (0.32, 0.34, 0.36), 0.75, 0.25)

    rounded_box('Corps', (0.50, 0.22, 0.64), (0, 0, 0.02), fabric, 0.075)
    rounded_box('PocheHaute', (0.42, 0.10, 0.20), (0, -0.145, 0.14), fabric, 0.045)
    rounded_box('PocheBasse', (0.44, 0.12, 0.23), (0, -0.155, -0.17), fabric, 0.05)
    rounded_box('FondRenforce', (0.46, 0.08, 0.07), (0, -0.02, -0.31), dark, 0.025)

    # Bretelles visibles au dos.
    rounded_box('BretelleG', (0.075, 0.055, 0.50), (-0.17, 0.145, -0.005), dark, 0.025)
    rounded_box('BretelleD', (0.075, 0.055, 0.50), (0.17, 0.145, -0.005), dark, 0.025)
    torus('Poignee', 0.105, 0.022, (0, 0.03, 0.39), dark, rotation=(math.radians(90), 0, 0))

    # Fermetures éclair / tirettes.
    rounded_box('ZipHaut', (0.39, 0.018, 0.018), (0, -0.211, 0.255), dark, 0.005)
    rounded_box('ZipMilieu', (0.38, 0.018, 0.018), (0, -0.221, 0.02), dark, 0.005)
    rounded_box('ZipBas', (0.39, 0.018, 0.018), (0, -0.231, -0.14), dark, 0.005)
    cylinder('Tirette1', 0.012, 0.075, (-0.13, -0.238, 0.22), metal, rotation=(math.radians(90), 0, 0), vertices=12)
    cylinder('Tirette2', 0.012, 0.075, (0.13, -0.238, 0.22), metal, rotation=(math.radians(90), 0, 0), vertices=12)

    # Poches latérales.
    rounded_box('PocheLateraleG', (0.08, 0.14, 0.22), (-0.29, 0.0, -0.14), fabric, 0.035)
    rounded_box('PocheLateraleD', (0.08, 0.14, 0.22), (0.29, 0.0, -0.14), fabric, 0.035)

    add_camera_and_lights(Vector((0, 0, 0.02)))
    export_glb(BAG_GLB / f'{name}.glb')
    render_preview(BAG_PNG / f'{name}.png')


def make_bat():
    clear_scene()
    wood = mat('bat_wood', (0.58, 0.27, 0.08), 0.0, 0.45)
    grip = mat('bat_grip', (0.025, 0.025, 0.03), 0.0, 0.78)
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.075, radius2=0.045, depth=1.15, location=(0,0,0.05))
    bat = bpy.context.object
    bat.name = 'BatteCheikh'
    bat.data.materials.append(wood)
    cylinder('Poignee', 0.038, 0.30, (0,0,-0.66), grip, vertices=24)
    cylinder('Pommeau', 0.052, 0.055, (0,0,-0.835), grip, vertices=24)
    add_camera_and_lights(Vector((0,0,0)))
    export_glb(WEAPON_GLB / 'batte_cheikh.glb')
    render_preview(WEAPON_PNG / 'batte_cheikh.png')


def make_sword():
    clear_scene()
    steel = mat('blade', (0.62, 0.67, 0.72), 0.85, 0.18)
    dark = mat('handle', (0.025, 0.03, 0.045), 0.15, 0.58)
    accent = mat('accent', (0.08, 0.18, 0.36), 0.45, 0.30)
    rounded_box('Lame', (0.075, 0.018, 0.92), (0,0,0.20), steel, 0.008)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.055, radius2=0.0, depth=0.16, location=(0,0,0.74), rotation=(0,0,math.radians(45)))
    tip = bpy.context.object
    tip.data.materials.append(steel)
    rounded_box('Garde', (0.30, 0.05, 0.045), (0,0,-0.29), accent, 0.015)
    cylinder('Poignee', 0.035, 0.30, (0,0,-0.47), dark, vertices=20)
    cylinder('Pommeau', 0.050, 0.060, (0,0,-0.65), accent, vertices=20)
    add_camera_and_lights(Vector((0,0,0)))
    export_glb(WEAPON_GLB / 'epee_nelvyn.glb')
    render_preview(WEAPON_PNG / 'epee_nelvyn.png')


make_backpack('sac_yvane_bleu', (0.025, 0.18, 0.72))
make_backpack('sac_nelvyn_noir', (0.025, 0.025, 0.035))
make_backpack('sac_cheikh_orange', (1.0, 0.31, 0.015))
make_bat()
make_sword()

print('Équipements générés : 3 sacs à dos + batte + épée')
