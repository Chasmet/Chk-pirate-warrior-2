class_name StoryQuestIdentityV11_4
extends "res://scripts/world/story_quest_item_fix_v11_2.gd"

const QUEST_IDENTITIES := {
    1: {"shape": "ovale", "color": "e53935", "accent": "ff8a80"},
    2: {"shape": "carre", "color": "1e88e5", "accent": "82b1ff"},
    3: {"shape": "triangle", "color": "22a447", "accent": "8be9a8"},
    4: {"shape": "etoile", "color": "f6c945", "accent": "fff2a8"},
    5: {"shape": "losange", "color": "8e44cf", "accent": "d7a8ff"},
    6: {"shape": "hexagone", "color": "f07c25", "accent": "ffc084"},
    7: {"shape": "coeur", "color": "f06292", "accent": "ffb2c8"},
    8: {"shape": "croix", "color": "28d7e5", "accent": "a6f7ff"},
    9: {"shape": "pentagone", "color": "8b5a3c", "accent": "d6a27d"},
    10: {"shape": "demi_lune", "color": "f4f6f8", "accent": "a9d8ff"},
    11: {"shape": "octogone", "color": "101116", "accent": "b15cff"}
}

func _spawn_quest_object(key: String, world_position: Vector3, quest: Dictionary, phase: float) -> void:
    var pickup := Node3D.new()
    pickup.name = "ObjetQueteV114_%s" % key
    _root.add_child(pickup)
    pickup.global_position = world_position
    pickup.set_meta("collect_key", key)
    pickup.set_meta("kind", "quest_item")
    pickup.set_meta("item_id", str(quest.get("item_id", "")))
    pickup.set_meta("phase", phase)
    pickup.set_meta("base_y", world_position.y)

    var identity: Dictionary = QUEST_IDENTITIES.get(_current_island, QUEST_IDENTITIES[1])
    pickup.set_meta("identity_shape", str(identity.get("shape", "ovale")))
    pickup.set_meta("identity_island", _current_island)

    var core_color := Color(str(identity.get("color", "ffffff")))
    var accent_color := Color(str(identity.get("accent", "ffffff")))
    var material := _quest_material(core_color, accent_color, _current_island == 11)
    _build_identity_shape(pickup, str(identity.get("shape", "ovale")), material)
    _add_identity_halo(pickup, accent_color)

    _pickups.append(pickup)
    _interactive_by_key[key] = pickup

func _build_identity_shape(parent: Node3D, shape_id: String, material: StandardMaterial3D) -> void:
    match shape_id:
        "ovale":
            var visual := MeshInstance3D.new()
            var mesh := SphereMesh.new()
            mesh.radius = 0.38
            mesh.height = 0.76
            mesh.radial_segments = 12
            mesh.rings = 6
            visual.mesh = mesh
            visual.scale = Vector3(1.30, 0.82, 0.88)
            visual.material_override = material
            parent.add_child(visual)
        "carre":
            _add_polygon_prism(parent, PackedVector2Array([
                Vector2(-0.48, -0.48), Vector2(0.48, -0.48),
                Vector2(0.48, 0.48), Vector2(-0.48, 0.48)
            ]), material, 0.28)
        "triangle":
            _add_polygon_prism(parent, PackedVector2Array([
                Vector2(0.0, 0.58), Vector2(-0.54, -0.42), Vector2(0.54, -0.42)
            ]), material, 0.30)
        "etoile":
            var points := PackedVector2Array()
            for i in range(10):
                var radius := 0.58 if i % 2 == 0 else 0.26
                var angle := -PI * 0.5 + float(i) * PI / 5.0
                points.append(Vector2(cos(angle), sin(angle)) * radius)
            _add_polygon_prism(parent, points, material, 0.24)
        "losange":
            _add_polygon_prism(parent, PackedVector2Array([
                Vector2(0.0, 0.62), Vector2(0.48, 0.0),
                Vector2(0.0, -0.62), Vector2(-0.48, 0.0)
            ]), material, 0.30)
        "hexagone":
            _add_regular_polygon(parent, 6, 0.56, material, 0.30, PI / 6.0)
        "coeur":
            _add_polygon_prism(parent, PackedVector2Array([
                Vector2(0.0, -0.60),
                Vector2(-0.46, -0.12), Vector2(-0.52, 0.18),
                Vector2(-0.36, 0.44), Vector2(-0.12, 0.49),
                Vector2(0.0, 0.32),
                Vector2(0.12, 0.49), Vector2(0.36, 0.44),
                Vector2(0.52, 0.18), Vector2(0.46, -0.12)
            ]), material, 0.25)
        "croix":
            _add_polygon_prism(parent, PackedVector2Array([
                Vector2(-0.18, 0.58), Vector2(0.18, 0.58),
                Vector2(0.18, 0.20), Vector2(0.56, 0.20),
                Vector2(0.56, -0.20), Vector2(0.18, -0.20),
                Vector2(0.18, -0.58), Vector2(-0.18, -0.58),
                Vector2(-0.18, -0.20), Vector2(-0.56, -0.20),
                Vector2(-0.56, 0.20), Vector2(-0.18, 0.20)
            ]), material, 0.25)
        "pentagone":
            _add_regular_polygon(parent, 5, 0.58, material, 0.31, -PI * 0.5)
        "demi_lune":
            _add_polygon_prism(parent, PackedVector2Array([
                Vector2(0.0, 0.60), Vector2(0.29, 0.52), Vector2(0.50, 0.30),
                Vector2(0.58, 0.0), Vector2(0.50, -0.30), Vector2(0.29, -0.52),
                Vector2(0.0, -0.60)
            ]), material, 0.25)
        "octogone":
            _add_regular_polygon(parent, 8, 0.58, material, 0.32, PI / 8.0)
        _:
            _add_regular_polygon(parent, 8, 0.55, material, 0.28, 0.0)

func _add_regular_polygon(
    parent: Node3D,
    sides: int,
    radius: float,
    material: StandardMaterial3D,
    depth: float,
    angle_offset: float
) -> void:
    var points := PackedVector2Array()
    for i in range(maxi(3, sides)):
        var angle := angle_offset + TAU * float(i) / float(maxi(3, sides))
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    _add_polygon_prism(parent, points, material, depth)

func _add_polygon_prism(
    parent: Node3D,
    points: PackedVector2Array,
    material: StandardMaterial3D,
    depth: float
) -> void:
    if points.size() < 3:
        return

    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var front_z := depth * 0.5
    var back_z := -front_z

    for i in range(points.size()):
        var next := (i + 1) % points.size()
        surface.add_vertex(Vector3(0.0, 0.0, front_z))
        surface.add_vertex(Vector3(points[i].x, points[i].y, front_z))
        surface.add_vertex(Vector3(points[next].x, points[next].y, front_z))

        surface.add_vertex(Vector3(0.0, 0.0, back_z))
        surface.add_vertex(Vector3(points[next].x, points[next].y, back_z))
        surface.add_vertex(Vector3(points[i].x, points[i].y, back_z))

        var a := Vector3(points[i].x, points[i].y, front_z)
        var b := Vector3(points[next].x, points[next].y, front_z)
        var c := Vector3(points[next].x, points[next].y, back_z)
        var d := Vector3(points[i].x, points[i].y, back_z)
        surface.add_vertex(a)
        surface.add_vertex(b)
        surface.add_vertex(c)
        surface.add_vertex(a)
        surface.add_vertex(c)
        surface.add_vertex(d)

    surface.generate_normals()
    var mesh := surface.commit()
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = material
    visual.rotation_degrees.x = -8.0
    parent.add_child(visual)

func _add_identity_halo(parent: Node3D, accent_color: Color) -> void:
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.70
    torus.outer_radius = 0.77
    torus.rings = 18
    torus.ring_segments = 6
    ring.mesh = torus
    ring.rotation.x = PI * 0.5
    ring.scale = Vector3(1.0, 1.0, 0.82)
    ring.material_override = _halo_material(accent_color)
    parent.add_child(ring)

    var beacon := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.86
    sphere.height = 1.72
    sphere.radial_segments = 8
    sphere.rings = 4
    beacon.mesh = sphere
    beacon.scale = Vector3(1.0, 0.12, 1.0)
    beacon.position.y = -0.52
    beacon.material_override = _halo_material(Color(accent_color.r, accent_color.g, accent_color.b, 0.18))
    parent.add_child(beacon)

func _quest_material(core: Color, accent: Color, black_core: bool) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = core
    material.metallic = 0.28
    material.roughness = 0.24
    material.emission_enabled = true
    material.emission = accent.darkened(0.86) if black_core else core.darkened(0.22)
    material.emission_energy_multiplier = 0.55 if black_core else 0.90
    return material

func _halo_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(color.r, color.g, color.b, minf(color.a, 0.72))
    material.emission_enabled = true
    material.emission = Color(color.r, color.g, color.b, 1.0)
    material.emission_energy_multiplier = 1.85
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material
