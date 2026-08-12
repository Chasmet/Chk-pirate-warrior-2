class_name IslandVegetationDirector
extends Node3D

@export var bush_budget := 40
@export var flower_budget := 28
@export var grass_cluster_budget := 52
@export var arrival_grass_blade_budget := 1200

var _root: Node3D
var _current_island := -1
var _serial := 0

func _ready() -> void:
    add_to_group("island_vegetation")
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _on_island_changed(island_id: int) -> void:
    _current_island = clampi(island_id, 1, WorldCatalog.island_count())
    _serial += 1
    _rebuild.call_deferred(_serial)

func _rebuild(serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial:
        return
    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _root = Node3D.new()
    _root.name = "VegetationRoyaume_%02d" % _current_island
    add_child(_root)

    var info := WorldCatalog.island(_current_island - 1)
    var center := WorldCatalog.world_positions()[_current_island - 1]
    var size: Vector2 = info["size"]
    _spawn_arrival_grass(
        center,
        size,
        info,
        260 if _current_island == 11 else arrival_grass_blade_budget,
        _current_island == 11
    )

    if _current_island == 11:
        _spawn_troubled_growth()
        return

    _spawn_bushes(center, size, info)
    _spawn_flowers(center, size, info)
    _spawn_grass_clusters(center, size, info)

func _spawn_arrival_grass(center: Vector3, size: Vector2, info: Dictionary, blade_count: int, troubled: bool) -> void:
    # Les anciennes brindilles commençaient à 16 m de la route, ne faisaient que
    # 3,5 cm de large et reprenaient presque la couleur du sol. Elles existaient
    # dans le MultiMesh mais restaient invisibles sur téléphone. Cette version
    # place de vraies touffes contrastées au bord du chemin et autour du point de
    # départ, toujours dans un seul draw call Android.
    var resolved_count := maxi(0, blade_count)
    if resolved_count == 0:
        return

    var blade_mesh := BoxMesh.new()
    blade_mesh.size = Vector3(0.11, 0.78, 0.065)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = blade_mesh
    multi.instance_count = resolved_count

    var base_color: Color = info.get("color", Color("4f7f4c"))
    var rng := RandomNumberGenerator.new()
    rng.seed = 61000 + _current_island * 263
    var blades_per_patch := 16
    var patch_origin := center
    var player_reference := center + Vector3(0.0, 0.0, size.y * 0.28)
    var active_player := get_tree().get_first_node_in_group("player") as Node3D
    if active_player != null and is_instance_valid(active_player):
        player_reference = active_player.global_position

    for i in range(resolved_count):
        var local_blade := i % blades_per_patch
        if local_blade == 0:
            var patch_index := int(i / blades_per_patch)
            var side := -1.0 if patch_index % 2 == 0 else 1.0
            var near_player_patch := patch_index < 24 and not troubled
            var near_port_patch := patch_index >= 24 and patch_index < 40 and not troubled
            var roadside_patch := patch_index % 3 != 2
            var patch_reference := center
            var x_offset := 0.0
            var z_offset := 0.0
            if near_player_patch:
                # Le point exact varie entre une partie neuve, une sauvegarde et
                # un retour au port. Ces 384 brindilles suivent le héros au
                # moment où le royaume finit de se construire.
                patch_reference = player_reference
                x_offset = side * rng.randf_range(11.0, 31.0)
                z_offset = rng.randf_range(-34.0, 34.0)
            elif near_port_patch:
                # 16 touffes x 16 brindilles sont garanties autour du spawn
                # sûr du port (z = 45 % de la longueur + 12 m). Elles sont donc
                # visibles dès l'arrivée, au lieu de dépendre du tirage aléatoire.
                x_offset = side * rng.randf_range(11.0, 31.0)
                z_offset = rng.randf_range(size.y * 0.415, size.y * 0.455)
            else:
                x_offset = side * (
                    rng.randf_range(10.5, 30.0)
                    if roadside_patch
                    else rng.randf_range(34.0, minf(92.0, size.x * 0.10))
                )
                z_offset = rng.randf_range(size.y * 0.205, size.y * 0.455)
            var plaza_z := size.y * 0.34
            if not near_player_patch and absf(x_offset) < 47.0 and absf(z_offset - plaza_z) < 38.0:
                x_offset = side * rng.randf_range(48.0, minf(78.0, size.x * 0.09))
            patch_origin = _snap_to_ground(patch_reference + Vector3(x_offset, 8.0, z_offset), 0.0)

        var angle := rng.randf_range(0.0, TAU)
        var radius := sqrt(rng.randf()) * rng.randf_range(0.45, 3.1)
        var height_scale := rng.randf_range(0.72, 1.42)
        var width_scale := rng.randf_range(0.82, 1.28)
        var tilt := rng.randf_range(-0.22, 0.22)
        var basis := Basis.from_euler(Vector3(tilt, angle, rng.randf_range(-0.12, 0.12)))
        basis = basis.scaled(Vector3(width_scale, height_scale, 1.0))
        var origin := patch_origin + Vector3(cos(angle) * radius, 0.39 * height_scale, sin(angle) * radius)
        multi.set_instance_transform(i, Transform3D(basis, origin))
        var visible_green := base_color.lerp(Color("72b957"), 0.58)
        var shade := rng.randf_range(-0.12, 0.22)
        var blade_color := Color("53605a") if troubled else (visible_green.lightened(shade) if shade >= 0.0 else visible_green.darkened(-shade))
        multi.set_instance_color(i, blade_color)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.98

    var grass := MultiMeshInstance3D.new()
    grass.name = "ArriveeHerbeDenseMultiMesh"
    grass.multimesh = multi
    grass.material_override = material
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    grass.visibility_range_end = 340.0
    grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    _root.add_child(grass)
    if not troubled:
        _spawn_guaranteed_visible_grass(player_reference, info)

func _spawn_guaranteed_visible_grass(player_reference: Vector3, info: Dictionary) -> void:
    # Sur l'export Android Godot 4.4, certains pilotes renvoient les transforms
    # du MultiMesh à zéro. Cette géométrie directe garde 160 vraies brindilles
    # visibles dans un seul mesh/draw call, indépendamment de ce chemin GPU.
    var blade_count := 160
    var rng := RandomNumberGenerator.new()
    rng.seed = 88000 + _current_island * 313
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var base_color: Color = info.get("color", Color("4f7f4c"))
    var anchor_in_root := _root.to_local(player_reference)

    for blade_index in range(blade_count):
        var side_sign := -1.0 if blade_index % 2 == 0 else 1.0
        # Deux bandes sur les côtés de la place : visibles dès l'arrivée sans
        # planter d'herbe au milieu du chemin emprunté par Cheikh.
        var x_offset := side_sign * rng.randf_range(47.0, 59.0)
        var z_offset := rng.randf_range(-25.0, 25.0)
        var ground_world := _snap_to_ground(player_reference + Vector3(x_offset, 8.0, z_offset), 0.01)
        var bottom := _root.to_local(ground_world) - anchor_in_root
        var height := rng.randf_range(0.72, 1.05)
        var half_width := rng.randf_range(0.055, 0.09)
        var yaw := rng.randf_range(0.0, TAU)
        var direction := Vector3(cos(yaw), 0.0, sin(yaw))
        var side := direction * half_width
        var cross_side := Vector3(-direction.z, 0.0, direction.x) * half_width
        var lean := direction * rng.randf_range(-0.10, 0.10)
        var visible_green := base_color.lerp(Color("78c35a"), 0.72)
        var shade := rng.randf_range(-0.08, 0.18)
        var blade_color := visible_green.lightened(shade) if shade >= 0.0 else visible_green.darkened(-shade)
        _append_grass_quad(surface, bottom, side, height, lean, blade_color)
        _append_grass_quad(surface, bottom, cross_side, height, lean, blade_color)

    var mesh := surface.commit()
    if mesh == null:
        return
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var visible_grass := MeshInstance3D.new()
    visible_grass.name = "BrindillesVisiblesAuDepart"
    visible_grass.mesh = mesh
    visible_grass.material_override = material
    visible_grass.position = anchor_in_root
    visible_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    visible_grass.set_meta("blade_count", blade_count)
    visible_grass.set_meta("player_reference", player_reference)
    _root.add_child(visible_grass)

func _append_grass_quad(surface: SurfaceTool, bottom: Vector3, side: Vector3, height: float, lean: Vector3, color: Color) -> void:
    var left_bottom := bottom - side
    var right_bottom := bottom + side
    var left_top := left_bottom + Vector3.UP * height + lean
    var right_top := right_bottom + Vector3.UP * height + lean
    var normal := side.normalized().cross(Vector3.UP).normalized()
    var vertices := [left_bottom, right_bottom, right_top, left_bottom, right_top, left_top]
    for vertex in vertices:
        surface.set_normal(normal)
        surface.set_color(color)
        surface.add_vertex(vertex)

func _spawn_bushes(center: Vector3, size: Vector2, info: Dictionary) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 33000 + _current_island * 197
    for i in range(maxi(0, bush_budget)):
        var p := _random_inland_point(rng, center, size, 0.18, 0.68)
        var world := _snap_to_ground(p, 0.03)
        var bush := Node3D.new()
        bush.name = "Buisson_%02d" % i
        bush.global_position = world
        bush.rotation.y = rng.randf_range(0.0, TAU)
        var scale_value := rng.randf_range(0.70, 1.45)
        bush.scale = Vector3.ONE * scale_value
        bush.add_child(_make_bush_visual(info, i))
        _root.add_child(bush)

func _spawn_flowers(center: Vector3, size: Vector2, info: Dictionary) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 41000 + _current_island * 211
    for i in range(maxi(0, flower_budget)):
        var p := _random_inland_point(rng, center, size, 0.16, 0.60)
        var flower := Node3D.new()
        flower.name = "Fleurs_%02d" % i
        flower.global_position = _snap_to_ground(p, 0.02)
        flower.rotation.y = rng.randf_range(0.0, TAU)
        flower.scale = Vector3.ONE * rng.randf_range(0.65, 1.15)
        flower.add_child(_make_flower_visual(info, i))
        _root.add_child(flower)

func _spawn_grass_clusters(center: Vector3, size: Vector2, info: Dictionary) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 52000 + _current_island * 227
    for i in range(maxi(0, grass_cluster_budget)):
        var p := _random_inland_point(rng, center, size, 0.08, 0.74)
        var cluster := Node3D.new()
        cluster.name = "Herbes_%02d" % i
        cluster.global_position = _snap_to_ground(p, 0.01)
        cluster.rotation.y = rng.randf_range(0.0, TAU)
        cluster.scale = Vector3.ONE * rng.randf_range(0.72, 1.28)
        cluster.add_child(_make_grass_visual(info, i))
        _root.add_child(cluster)

func _spawn_troubled_growth() -> void:
    var info := WorldCatalog.island(10)
    var center := WorldCatalog.world_positions()[10]
    var size: Vector2 = info["size"]
    var rng := RandomNumberGenerator.new()
    rng.seed = 99991
    for i in range(18):
        var p := _random_inland_point(rng, center, size, 0.22, 0.68)
        var root := Node3D.new()
        root.name = "RonceTrouble_%02d" % i
        root.global_position = _snap_to_ground(p, 0.02)
        root.rotation.y = rng.randf_range(0.0, TAU)
        root.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
        root.add_child(_make_bush_visual(info, i, true))
        _root.add_child(root)

func _make_bush_visual(info: Dictionary, index: int, troubled: bool = false) -> Node3D:
    var root := Node3D.new()
    var base: Color = info.get("color", Color("4f7f4c"))
    var leaf_color := Color("344239") if troubled else base.darkened(0.15 + float(index % 3) * 0.05)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = leaf_color
    mat.roughness = 0.96

    for j in range(3):
        var leaves := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.48 + float(j % 2) * 0.10
        mesh.height = 0.80 + float(j) * 0.08
        mesh.radial_segments = 7
        mesh.rings = 4
        leaves.mesh = mesh
        leaves.position = Vector3(-0.40 + float(j) * 0.40, 0.36 + float(j % 2) * 0.16, sin(float(j) * 1.7) * 0.22)
        leaves.scale = Vector3(1.15, 0.72, 1.0)
        leaves.material_override = mat
        leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(leaves)
    return root

func _make_flower_visual(info: Dictionary, index: int) -> Node3D:
    var root := Node3D.new()
    var stem_mat := StandardMaterial3D.new()
    stem_mat.albedo_color = Color("4d6d3f")
    stem_mat.roughness = 1.0
    var accent: Color = info.get("accent", Color("e9b562"))

    for j in range(4):
        var stem := MeshInstance3D.new()
        var stem_mesh := CylinderMesh.new()
        stem_mesh.top_radius = 0.025
        stem_mesh.bottom_radius = 0.035
        stem_mesh.height = 0.42 + float(j % 2) * 0.12
        stem_mesh.radial_segments = 5
        stem.mesh = stem_mesh
        stem.position = Vector3(-0.15 + float(j) * 0.10, stem_mesh.height * 0.5, sin(float(j) * 2.1) * 0.08)
        stem.material_override = stem_mat
        stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(stem)

        var bloom := MeshInstance3D.new()
        var bloom_mesh := SphereMesh.new()
        bloom_mesh.radius = 0.09
        bloom_mesh.height = 0.14
        bloom_mesh.radial_segments = 6
        bloom_mesh.rings = 3
        bloom.mesh = bloom_mesh
        bloom.position = stem.position + Vector3(0.0, stem_mesh.height * 0.5, 0.0)
        var bloom_mat := StandardMaterial3D.new()
        bloom_mat.albedo_color = accent.lightened(float((index + j) % 3) * 0.08)
        bloom_mat.roughness = 0.88
        bloom.material_override = bloom_mat
        bloom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(bloom)
    return root

func _make_grass_visual(info: Dictionary, index: int) -> Node3D:
    # Une touffe V6 contient davantage de petites brindilles, mais toutes sont
    # rendues dans un MultiMesh unique : beaucoup plus de densité visuelle sans
    # multiplier les MeshInstance3D et les draw calls sur téléphone.
    var root := Node3D.new()
    var base: Color = info.get("color", Color("4f7f4c"))
    var mat := StandardMaterial3D.new()
    mat.albedo_color = base.darkened(0.10 + float(index % 4) * 0.022)
    mat.roughness = 1.0

    var blade_mesh := BoxMesh.new()
    blade_mesh.size = Vector3(0.032, 0.52, 0.065)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade_mesh
    multi.instance_count = 14

    for j in range(multi.instance_count):
        var angle := float(j) * 2.399963
        var radial := 0.10 + float(j % 5) * 0.07
        var height_scale := 0.72 + float((j * 7 + index) % 6) * 0.085
        var width_scale := 0.82 + float((j + index) % 3) * 0.09
        var tilt := -0.16 + float((j * 3 + index) % 5) * 0.08
        var yaw := angle + float(index % 5) * 0.13
        var basis := Basis.from_euler(Vector3(tilt, yaw, -tilt * 0.55))
        basis = basis.scaled(Vector3(width_scale, height_scale, 1.0))
        var origin := Vector3(cos(angle) * radial, 0.26 * height_scale, sin(angle) * radial)
        multi.set_instance_transform(j, Transform3D(basis, origin))

    var grass := MultiMeshInstance3D.new()
    grass.name = "BrindillesMultiMesh"
    grass.multimesh = multi
    grass.material_override = mat
    grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(grass)
    return root

func _random_inland_point(rng: RandomNumberGenerator, center: Vector3, size: Vector2, min_radius: float, max_radius: float) -> Vector3:
    var angle := rng.randf_range(0.0, TAU)
    var radial := sqrt(rng.randf_range(min_radius * min_radius, max_radius * max_radius))
    return center + Vector3(
        cos(angle) * size.x * 0.5 * radial,
        8.0,
        sin(angle) * size.y * 0.5 * radial
    )

func _snap_to_ground(world_position: Vector3, offset: float) -> Vector3:
    if get_world_3d() == null:
        return world_position
    var query := PhysicsRayQueryParameters3D.create(
        Vector3(world_position.x, 170.0, world_position.z),
        Vector3(world_position.x, -90.0, world_position.z),
        1
    )
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.has("position"):
        var result: Vector3 = hit["position"]
        result.y += offset
        return result
    return world_position
