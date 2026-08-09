class_name CoastalDetailDirector
extends Node3D

const SHALLOW_WATER_MIN_Y := -0.98
const SHALLOW_WATER_RADIAL_LIMIT := 0.94

var _detail_root: Node3D
var _current_island := -1
var _rebuild_serial := 0

func _ready() -> void:
    add_to_group("coastal_details")
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _on_island_changed(island_id: int) -> void:
    var resolved := clampi(island_id, 1, WorldCatalog.island_count())
    if resolved == _current_island and _detail_root != null:
        return
    _current_island = resolved
    _rebuild_serial += 1
    _rebuild.call_deferred(_rebuild_serial)

func _rebuild(serial: int) -> void:
    await get_tree().physics_frame
    if serial != _rebuild_serial:
        return
    if _detail_root != null and is_instance_valid(_detail_root):
        _detail_root.queue_free()
    _detail_root = Node3D.new()
    _detail_root.name = "DetailsCotiers_%02d" % _current_island
    add_child(_detail_root)

    var index := _current_island - 1
    var info := WorldCatalog.island(index)
    var centers := WorldCatalog.world_positions()
    _detail_root.global_position = centers[index]

    _build_beach_arcs(info)
    _build_shallow_coves(info)
    _build_cliff_multimesh(info)
    _build_rock_multimesh(info)
    _build_tree_multimesh(info)
    _build_grass_multimesh(info)

func _build_beach_arcs(info: Dictionary) -> void:
    # Plus de cercle de sable artificiel sur 360°. Les plages occupent seulement
    # les secteurs bas de la côte et le port ; les autres zones deviennent rocheuses.
    var island_size: Vector2 = info["size"]
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var segments := 96
    var inner_radial := 0.78
    var outer_radial := 0.925

    for i in range(segments):
        var next := (i + 1) % segments
        var a0 := TAU * float(i) / float(segments)
        var a1 := TAU * float(next) / float(segments)
        var mid := (a0 + a1) * 0.5
        if not _is_beach_sector(mid, int(info["id"])):
            continue
        var p00 := _coast_point(info, island_size, a0, inner_radial)
        var p01 := _coast_point(info, island_size, a1, inner_radial)
        var p10 := _coast_point(info, island_size, a0, outer_radial)
        var p11 := _coast_point(info, island_size, a1, outer_radial)
        _add_beach_triangle(surface, p00, p10, p01)
        _add_beach_triangle(surface, p10, p11, p01)

    surface.generate_normals()
    var mesh := surface.commit()
    if mesh == null:
        return
    var beach := MeshInstance3D.new()
    beach.name = "PetitesPlagesNaturelles"
    beach.mesh = mesh
    beach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := StandardMaterial3D.new()
    material.albedo_color = _beach_color(int(info["id"]))
    material.roughness = 0.96
    beach.material_override = material
    _detail_root.add_child(beach)

func _is_beach_sector(angle: float, island_id: int) -> bool:
    # Le port se trouve vers +Z : on y garantit une plage d'arrivée lisible.
    if sin(angle) > 0.72:
        return true
    var cliff_strength := pow(absf(sin(angle * 2.5 + float(island_id) * 0.71)), 3.0)
    return cliff_strength < 0.38

func _coast_point(info: Dictionary, island_size: Vector2, angle: float, radial: float) -> Vector3:
    var wobble := 1.0 + sin(angle * 5.0 + float(info["id"])) * 0.035 + cos(angle * 9.0) * 0.022
    var x := cos(angle) * island_size.x * 0.5 * radial * wobble
    var z := sin(angle) * island_size.y * 0.5 * radial * wobble
    var y := _terrain_height_at(info, x, z) + 0.06
    return Vector3(x, y, z)

func _add_beach_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    for point in [a, b, c]:
        surface.set_uv(Vector2(point.x * 0.015, point.z * 0.015))
        surface.add_vertex(point)

func _build_shallow_coves(info: Dictionary) -> void:
    var island_size: Vector2 = info["size"]
    var specs := [
        Vector3(-0.22, 0.0, 0.36),
        Vector3(0.29, 0.0, -0.25),
        Vector3(0.05, 0.0, -0.46)
    ]
    for i in range(specs.size()):
        var unit: Vector3 = specs[i]
        var local_x := unit.x * island_size.x
        var local_z := unit.z * island_size.y
        var ground := _terrain_height_at(info, local_x, local_z)
        var water_y := ground + 0.18 + float(i % 2) * 0.08
        var water := MeshInstance3D.new()
        water.name = "EauPeuProfonde_%02d" % i
        var plane := PlaneMesh.new()
        plane.size = Vector2(72.0 + float(i) * 18.0, 40.0 + float((i + 1) % 3) * 14.0)
        plane.subdivide_width = 5
        plane.subdivide_depth = 4
        water.mesh = plane
        water.position = Vector3(local_x, water_y, local_z)
        water.rotation.y = 0.35 + float(i) * 0.72
        water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        water.material_override = _shallow_water_material()
        _detail_root.add_child(water)

func _shallow_water_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec4 eau : source_color = vec4(0.08, 0.62, 0.72, 0.46);
void vertex() {
    float vague = sin(VERTEX.x * 0.12 + TIME * 1.7) * 0.035;
    vague += cos(VERTEX.z * 0.16 - TIME * 1.25) * 0.025;
    VERTEX.y += vague;
}
void fragment() {
    ALBEDO = eau.rgb;
    ALPHA = eau.a;
    ROUGHNESS = 0.22;
    METALLIC = 0.04;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _build_cliff_multimesh(info: Dictionary) -> void:
    var island_size: Vector2 = info["size"]
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 8
    mesh.rings = 5
    var material := StandardMaterial3D.new()
    material.albedo_color = _cliff_color(int(info["id"]))
    material.roughness = 1.0
    mesh.material = material

    var transforms: Array[Transform3D] = []
    var rng := RandomNumberGenerator.new()
    rng.seed = 7100 + int(info["id"]) * 181
    for i in range(58):
        var angle := rng.randf_range(0.0, TAU)
        if sin(angle) > 0.68:
            continue
        var cliff_strength := pow(absf(sin(angle * 2.5 + float(info["id"]) * 0.71)), 3.0)
        if cliff_strength < 0.52:
            continue
        var radial := rng.randf_range(0.79, 0.90)
        var x := cos(angle) * island_size.x * 0.5 * radial
        var z := sin(angle) * island_size.y * 0.5 * radial
        var ground := _terrain_height_at(info, x, z)
        var sy := rng.randf_range(2.4, 5.8) * (0.72 + cliff_strength * 0.55)
        var scale := Vector3(rng.randf_range(2.0, 4.8), sy, rng.randf_range(1.8, 4.2))
        var basis := Basis.IDENTITY.rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(scale)
        transforms.append(Transform3D(basis, Vector3(x, ground + sy * 0.72, z)))

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = transforms.size()
    for i in range(transforms.size()):
        multimesh.set_instance_transform(i, transforms[i])

    var cliffs := MultiMeshInstance3D.new()
    cliffs.name = "FalaisesRocheusesMultiMesh"
    cliffs.multimesh = multimesh
    cliffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    _detail_root.add_child(cliffs)

func _build_rock_multimesh(info: Dictionary) -> void:
    var island_size: Vector2 = info["size"]
    var mesh := SphereMesh.new()
    mesh.radius = 0.65
    mesh.height = 1.15
    mesh.radial_segments = 8
    mesh.rings = 4
    var material := StandardMaterial3D.new()
    material.albedo_color = _cliff_color(int(info["id"])).lightened(0.08)
    material.roughness = 1.0
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = 42

    var rng := RandomNumberGenerator.new()
    rng.seed = 4100 + int(info["id"]) * 97
    for i in range(multimesh.instance_count):
        var angle := rng.randf_range(0.0, TAU)
        var radial := rng.randf_range(0.56, 0.90)
        var x := cos(angle) * island_size.x * 0.5 * radial
        var z := sin(angle) * island_size.y * 0.5 * radial
        var y := _terrain_height_at(info, x, z) + 0.35
        var scale := Vector3(rng.randf_range(0.45, 1.75), rng.randf_range(0.35, 1.25), rng.randf_range(0.55, 1.85))
        var basis := Basis.IDENTITY.rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(scale)
        multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))

    var rocks := MultiMeshInstance3D.new()
    rocks.name = "RochersCotiersMultiMesh"
    rocks.multimesh = multimesh
    rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _detail_root.add_child(rocks)

func _build_tree_multimesh(info: Dictionary) -> void:
    if int(info["id"]) in [8, 9]:
        return
    var island_size: Vector2 = info["size"]
    var count := 30

    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.24
    trunk_mesh.bottom_radius = 0.38
    trunk_mesh.height = 4.2
    trunk_mesh.radial_segments = 6
    var trunk_mat := StandardMaterial3D.new()
    trunk_mat.albedo_color = Color("76533a")
    trunk_mat.roughness = 1.0
    trunk_mesh.material = trunk_mat

    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 1.7
    crown_mesh.height = 3.2
    crown_mesh.radial_segments = 8
    crown_mesh.rings = 5
    var crown_mat := StandardMaterial3D.new()
    var base: Color = info.get("color", Color("4b8f6a"))
    crown_mat.albedo_color = base.lightened(0.06)
    crown_mat.roughness = 0.95
    crown_mesh.material = crown_mat

    var trunks := MultiMesh.new()
    trunks.transform_format = MultiMesh.TRANSFORM_3D
    trunks.mesh = trunk_mesh
    trunks.instance_count = count
    var crowns := MultiMesh.new()
    crowns.transform_format = MultiMesh.TRANSFORM_3D
    crowns.mesh = crown_mesh
    crowns.instance_count = count

    var rng := RandomNumberGenerator.new()
    rng.seed = 8100 + int(info["id"]) * 211
    for i in range(count):
        var angle := rng.randf_range(0.0, TAU)
        var radial := rng.randf_range(0.26, 0.70)
        var x := cos(angle) * island_size.x * 0.5 * radial
        var z := sin(angle) * island_size.y * 0.5 * radial
        if absf(x) < 95.0 and z > island_size.y * 0.15:
            x += 120.0 if i % 2 == 0 else -120.0
        var y := _terrain_height_at(info, x, z)
        var yaw := rng.randf_range(0.0, TAU)
        var scale := rng.randf_range(0.78, 1.28)
        var trunk_basis := Basis.IDENTITY.rotated(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
        trunks.set_instance_transform(i, Transform3D(trunk_basis, Vector3(x, y + 2.1 * scale, z)))
        var crown_basis := Basis.IDENTITY.rotated(Vector3.UP, yaw).scaled(Vector3(scale * 1.05, scale, scale * 1.05))
        crowns.set_instance_transform(i, Transform3D(crown_basis, Vector3(x, y + 5.0 * scale, z)))

    var trunk_instances := MultiMeshInstance3D.new()
    trunk_instances.name = "ArbresTroncsMultiMesh"
    trunk_instances.multimesh = trunks
    trunk_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    _detail_root.add_child(trunk_instances)

    var crown_instances := MultiMeshInstance3D.new()
    crown_instances.name = "ArbresFeuillageMultiMesh"
    crown_instances.multimesh = crowns
    crown_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    _detail_root.add_child(crown_instances)

func _build_grass_multimesh(info: Dictionary) -> void:
    if int(info["id"]) in [8, 9]:
        return
    var island_size: Vector2 = info["size"]
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.09, 1.25, 0.48)
    var material := StandardMaterial3D.new()
    var base: Color = info.get("color", Color("4b8f6a"))
    material.albedo_color = base.lightened(0.12)
    material.roughness = 1.0
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = 82

    var rng := RandomNumberGenerator.new()
    rng.seed = 6200 + int(info["id"]) * 131
    for i in range(multimesh.instance_count):
        var angle := rng.randf_range(0.0, TAU)
        var radial := rng.randf_range(0.34, 0.82)
        var x := cos(angle) * island_size.x * 0.5 * radial
        var z := sin(angle) * island_size.y * 0.5 * radial
        var y := _terrain_height_at(info, x, z) + 0.62
        var scale := Vector3(1.0, rng.randf_range(0.65, 1.55), rng.randf_range(0.65, 1.35))
        var basis := Basis.IDENTITY.rotated(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(scale)
        multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))

    var grass := MultiMeshInstance3D.new()
    grass.name = "VegetationLegereMultiMesh"
    grass.multimesh = multimesh
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _detail_root.add_child(grass)

func _terrain_height_at(info: Dictionary, x: float, z: float) -> float:
    # Utiliser exactement la hauteur du vrai terrain V3 afin que plages, arbres,
    # falaises et collectibles ne flottent jamais après une évolution du relief.
    var world := get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("_terrain_height_at"):
        return float(world.call("_terrain_height_at", info, x, z))

    var island_size: Vector2 = info["size"]
    var nx := x / maxf(1.0, island_size.x * 0.5)
    var nz := z / maxf(1.0, island_size.y * 0.5)
    var radial := sqrt(nx * nx + nz * nz)
    var coast := smoothstep(1.0, 0.72, radial)
    var noise := FastNoiseLite.new()
    noise.seed = 731 + int(info["id"]) * 97
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.0065
    noise.fractal_octaves = 4
    noise.fractal_gain = 0.52
    var raw := noise.get_noise_2d(x, z)
    var ridge := absf(noise.get_noise_2d(x * 0.42 + 913.0, z * 0.42 - 441.0))
    var height := (raw * 28.0 + ridge * 16.0) * coast
    if radial > 0.94:
        height -= (radial - 0.94) * 145.0
    if absf(x) < 115.0 and z > island_size.y * 0.18:
        height *= 0.12
    if radial <= SHALLOW_WATER_RADIAL_LIMIT:
        height = maxf(height, SHALLOW_WATER_MIN_Y)
    return height

func _beach_color(island_id: int) -> Color:
    match island_id:
        2:
            return Color("e9b0c4")
        8:
            return Color("dbe9ee")
        9:
            return Color("6f4938")
        11:
            return Color("9b875f")
        _:
            return Color("d8c082")

func _cliff_color(island_id: int) -> Color:
    match island_id:
        2:
            return Color("71525f")
        4:
            return Color("384954")
        8:
            return Color("91a6b0")
        9:
            return Color("332826")
        11:
            return Color("3f3830")
        _:
            return Color("5b584f")
