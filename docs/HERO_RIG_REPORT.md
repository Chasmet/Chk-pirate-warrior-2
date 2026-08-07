# Rapport des rigs des héros

Généré automatiquement avec Blender.

## Cheikh

- Fichier : `joueur 1 cheikh anime.glb`
- Armatures : 1
- Meshes : 2
- Armature `Cheikh_Humanoid_Skin` : 22 os

### Os

- `root`
- `hips`
- `spine`
- `chest`
- `neck`
- `head`
- `clavicle.L`
- `upper_arm.L`
- `forearm.L`
- `hand.L`
- `clavicle.R`
- `upper_arm.R`
- `forearm.R`
- `hand.R`
- `thigh.L`
- `shin.L`
- `foot.L`
- `toe.L`
- `thigh.R`
- `shin.R`
- `foot.R`
- `toe.R`

### Animations / actions

- `Attack_1_Cheikh_Humanoid_Skin`
- `Attack_2_Cheikh_Humanoid_Skin`
- `Block_Cheikh_Humanoid_Skin`
- `Boat_Balance_Cheikh_Humanoid_Skin`
- `Carry_Idle_Cheikh_Humanoid_Skin`
- `Carry_Walk_Cheikh_Humanoid_Skin`
- `Climb_Cheikh_Humanoid_Skin`
- `Crouch_Idle_Cheikh_Humanoid_Skin`
- `Crouch_Walk_Cheikh_Humanoid_Skin`
- `Death_Cheikh_Humanoid_Skin`
- `Dodge_Left_Cheikh_Humanoid_Skin`
- `Dodge_Right_Cheikh_Humanoid_Skin`
- `Fall_Cheikh_Humanoid_Skin`
- `Fight_Idle_Cheikh_Humanoid_Skin`
- `Grab_Object_Cheikh_Humanoid_Skin`
- `Helm_Idle_Cheikh_Humanoid_Skin`
- `Helm_Left_Cheikh_Humanoid_Skin`
- `Helm_Right_Cheikh_Humanoid_Skin`
- `Hit_Cheikh_Humanoid_Skin`
- `Idle_Cheikh_Humanoid_Skin`
- `Interact_Cheikh_Humanoid_Skin`
- `Jump_Cheikh_Humanoid_Skin`
- `Land_Cheikh_Humanoid_Skin`
- `PickUp_Cheikh_Humanoid_Skin`
- `Push_Cheikh_Humanoid_Skin`
- `RESET_Cheikh_Humanoid_Skin`
- `Roll_Cheikh_Humanoid_Skin`
- `Run_Cheikh_Humanoid_Skin`
- `Sit_Boat_Cheikh_Humanoid_Skin`
- `Sprint_Cheikh_Humanoid_Skin`
- `Swim_Cheikh_Humanoid_Skin`
- `Swim_Fast_Cheikh_Humanoid_Skin`
- `Sword_Attack_1_Cheikh_Humanoid_Skin`
- `Sword_Attack_2_Cheikh_Humanoid_Skin`
- `Sword_Block_Cheikh_Humanoid_Skin`
- `Sword_Idle_Cheikh_Humanoid_Skin`
- `Walk_Cheikh_Humanoid_Skin`

## Yvane

- Fichier : `Yvane_anime_Godot_Draco.glb`
- ERREUR import : `Error: Python: Traceback (most recent call last):
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/__init__.py", line 1709, in execute
    return self.import_gltf2(context)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/__init__.py", line 1742, in import_gltf2
    return self.unit_import(self.filepath, import_settings)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/__init__.py", line 1757, in unit_import
    BlenderGlTF.create(gltf_importer)
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_gltf.py", line 35, in create
    BlenderGlTF._create(gltf)
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_gltf.py", line 42, in _create
    BlenderScene.create(gltf)
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_scene.py", line 37, in create
    BlenderNode.create_vnode(gltf, 'root')
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_node.py", line 46, in create_vnode
    BlenderNode.create_vnode(gltf, child)
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_node.py", line 46, in create_vnode
    BlenderNode.create_vnode(gltf, child)
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_node.py", line 32, in create_vnode
    obj = BlenderNode.create_object(gltf, vnode_id)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_node.py", line 53, in create_object
    obj = BlenderNode.create_mesh_object(gltf, vnode)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_node.py", line 272, in create_mesh_object
    mesh = BlenderMesh.create(gltf, pynode.mesh, pynode.skin)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_mesh.py", line 25, in create
    return create_mesh(gltf, mesh_idx, skin_idx)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_mesh.py", line 46, in create_mesh
    do_primitives(gltf, mesh_idx, skin_idx, mesh, tmp_ob)
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_blender_mesh.py", line 161, in do_primitives
    decode_primitive(gltf, prim)
  File "/usr/share/blender/scripts/addons/io_scene_gltf2/blender/imp/gltf2_io_draco_compression_extension.py", line 20, in decode_primitive
    dll = cdll.LoadLibrary(str(dll_path().resolve()))
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/lib/python3.12/ctypes/__init__.py", line 460, in LoadLibrary
    return self._dlltype(name)
           ^^^^^^^^^^^^^^^^^^^
  File "/usr/lib/python3.12/ctypes/__init__.py", line 379, in __init__
    self._handle = _dlopen(self._name, mode)
                   ^^^^^^^^^^^^^^^^^^^^^^^^^
OSError: /usr/bin/4.0/python/lib/python3.12/site-packages/libextern_draco.so: cannot open shared object file: No such file or directory
Location: /usr/share/blender/scripts/modules/bpy/ops.py:109
`

## Nelvyn

- Fichier : `player_3_Nelvyn_Godot_anime (1).glb`
- Armatures : 1
- Meshes : 4
- Armature `Nelvyn_Humanoid_Skin` : 22 os

### Os

- `root`
- `hips`
- `spine`
- `chest`
- `neck`
- `head`
- `clavicle.L`
- `upper_arm.L`
- `forearm.L`
- `hand.L`
- `clavicle.R`
- `upper_arm.R`
- `forearm.R`
- `hand.R`
- `thigh.L`
- `shin.L`
- `foot.L`
- `toe.L`
- `thigh.R`
- `shin.R`
- `foot.R`
- `toe.R`

### Animations / actions

- `Attack_1_Cheikh_Humanoid_Skin`
- `Attack_1_Nelvyn_Humanoid_Skin`
- `Attack_2_Cheikh_Humanoid_Skin`
- `Attack_2_Nelvyn_Humanoid_Skin`
- `Block_Cheikh_Humanoid_Skin`
- `Block_Nelvyn_Humanoid_Skin`
- `Boat_Balance_Cheikh_Humanoid_Skin`
- `Boat_Balance_Nelvyn_Humanoid_Skin`
- `Carry_Idle_Cheikh_Humanoid_Skin`
- `Carry_Walk_Cheikh_Humanoid_Skin`
- `Climb_Cheikh_Humanoid_Skin`
- `Climb_Nelvyn_Humanoid_Skin`
- `Crouch_Idle_Cheikh_Humanoid_Skin`
- `Crouch_Idle_Nelvyn_Humanoid_Skin`
- `Crouch_Walk_Cheikh_Humanoid_Skin`
- `Crouch_Walk_Nelvyn_Humanoid_Skin`
- `Death_Cheikh_Humanoid_Skin`
- `Death_Nelvyn_Humanoid_Skin`
- `Dodge_Left_Cheikh_Humanoid_Skin`
- `Dodge_Left_Nelvyn_Humanoid_Skin`
- `Dodge_Right_Cheikh_Humanoid_Skin`
- `Dodge_Right_Nelvyn_Humanoid_Skin`
- `Fall_Cheikh_Humanoid_Skin`
- `Fall_Nelvyn_Humanoid_Skin`
- `Fight_Idle_Cheikh_Humanoid_Skin`
- `Fight_Idle_Nelvyn_Humanoid_Skin`
- `Grab_Object_Cheikh_Humanoid_Skin`
- `Helm_Idle_Cheikh_Humanoid_Skin`
- `Helm_Idle_Nelvyn_Humanoid_Skin`
- `Helm_Left_Cheikh_Humanoid_Skin`
- `Helm_Left_Nelvyn_Humanoid_Skin`
- `Helm_Right_Cheikh_Humanoid_Skin`
- `Helm_Right_Nelvyn_Humanoid_Skin`
- `Hit_Cheikh_Humanoid_Skin`
- `Hit_Nelvyn_Humanoid_Skin`
- `Idle_Cheikh_Humanoid_Skin`
- `Idle_Nelvyn_Humanoid_Skin`
- `Interact_Cheikh_Humanoid_Skin`
- `Interact_Nelvyn_Humanoid_Skin`
- `Jump_Cheikh_Humanoid_Skin`
- `Jump_Nelvyn_Humanoid_Skin`
- `Land_Cheikh_Humanoid_Skin`
- `Land_Nelvyn_Humanoid_Skin`
- `PickUp_Cheikh_Humanoid_Skin`
- `PickUp_Nelvyn_Humanoid_Skin`
- `Push_Cheikh_Humanoid_Skin`
- `Push_Nelvyn_Humanoid_Skin`
- `RESET_Cheikh_Humanoid_Skin`
- `RESET_Nelvyn_Humanoid_Skin`
- `Roll_Cheikh_Humanoid_Skin`
- `Roll_Nelvyn_Humanoid_Skin`
- `Run_Cheikh_Humanoid_Skin`
- `Run_Nelvyn_Humanoid_Skin`
- `Sit_Boat_Cheikh_Humanoid_Skin`
- `Sit_Boat_Nelvyn_Humanoid_Skin`
- `Sprint_Cheikh_Humanoid_Skin`
- `Sprint_Nelvyn_Humanoid_Skin`
- `Swim_Cheikh_Humanoid_Skin`
- `Swim_Fast_Cheikh_Humanoid_Skin`
- `Swim_Fast_Nelvyn_Humanoid_Skin`
- `Swim_Nelvyn_Humanoid_Skin`
- `Sword_Attack_1_Cheikh_Humanoid_Skin`
- `Sword_Attack_2_Cheikh_Humanoid_Skin`
- `Sword_Block_Cheikh_Humanoid_Skin`
- `Sword_Idle_Cheikh_Humanoid_Skin`
- `Walk_Cheikh_Humanoid_Skin`
- `Walk_Nelvyn_Humanoid_Skin`

