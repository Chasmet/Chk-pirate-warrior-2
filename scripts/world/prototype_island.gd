extends Node3D

const EnemyScript = preload("res://scripts/world/enemy_dummy.gd")

const ISLAND_SIZE := 1200.0
const GRID_CELLS := 44
const WATER_LEVEL := 0.0

var _remaining_enemies := 0
var _boss_spawned := false

func _ready() -> void:
    _build_environment()
    _build_water()
    _build_terrain()
    _build_village()
    _build_nature()
    _spawn_regular_enemies()
    _add_island_title()
    _place_player.call_deferred()
    _update_mission.call_deferred()

func terrain_height(x: float, z: float) -> float:
    var radius := Vector2(x, z).length()
    var edge := clampf(1.0 - radius / 575.0, 0.0, 1.0)
    var large_hills := sin(x * 0.0105) * 1.45 + cos(z * 0.012) * 1.15
    var detail := sin((x + z) * 0.021) * 0.55 + cos((x - z) * 0.017) * 0.45
    var center_plateau := exp(-radius * radius / 52000.0) * 1.1
    return -1.05 + edge * 7.2 + (large_hills + detail) * pow(edge, 1.45) + center_plateau

func _build_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.36, 0.69, 0.90)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.78, 0.87, 0.93)
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment.environment = environment
    add_child(world_environment)

func _build_water() -> void:
    var water := MeshInstance3D.new()
    water.name = "Ocean"
    var plane := PlaneMesh.new()
    plane.size = Vector2(1800.0, 1800.0)
    plane.subdivide_width = 4
    plane.subdivide_depth = 4
    water.mesh = plane
    water.position.y = WATER_LEVEL

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.035, 0.31, 0.48, 0.88)
    material.metallic = 0.08
    material.roughness = 0.23
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    water.material_override = material
    add_child(water)

func _build_terrain() -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)

    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.93
    surface.set_material(material)

    var step := ISLAND_SIZE / float(GRID_CELLS)
    var half := ISLAND_SIZE * 0.5

    for z_index in range(GRID_CELLS + 1):
        var z := -half + float(z_index) * step
        for x_index in range(GRID_CELLS + 1):
            var x := -half + float(x_index) * step
            var y := terrain_height(x, z)
            surface.set_uv(Vector2(float(x_index) / GRID_CELLS, float(z_index) / GRID_CELLS) * 12.0)
            surface.set_color(_terrain_color(y))
            surface.add_vertex(Vector3(x, y, z))

    var row := GRID_CELLS + 1
    for z_index in range(GRID_CELLS):
        for x_index in range(GRID_CELLS):
            var i0 := z_index * row + x_index
            var i1 := i0 + 1
            var i2 := i0 + row
            var i3 := i2 + 1
            surface.add_index(i0)
            surface.add_index(i2)
            surface.add_index(i1)
            surface.add_index(i1)
            surface.add_index(i2)
            surface.add_index(i3)

    surface.generate_normals()
    var mesh := surface.commit()

    var terrain_mesh := MeshInstance3D.new()
    terrain_mesh.name = "Ile01Terrain"
    terrain_mesh.mesh = mesh
    add_child(terrain_mesh)

    var body := StaticBody3D.new()
    body.name = "Ile01Collision"
    var collision := CollisionShape3D.new()
    collision.shape = mesh.create_trimesh_shape()
    body.add_child(collision)
    add_child(body)

func _terrain_color(height: float) -> Color:
    if height < 0.65:
        return Color(0.78, 0.68, 0.45)
    if height < 4.6:
        return Color(0.15, 0.42, 0.16)
    return Color(0.25, 0.31, 0.20)

func _build_village() -> void:
    _add_hut(Vector3(-14.0, 0.0, -18.0), Color(0.43, 0.24, 0.10))
    _add_hut(Vector3(11.0, 0.0, -22.0), Color(0.34, 0.19, 0.08))
    _add_hut(Vector3(25.0, 0.0, -9.0), Color(0.49, 0.29, 0.12))
    _add_hut(Vector3(-28.0, 0.0, -5.0), Color(0.37, 0.21, 0.09))

    for p in [Vector3(-7, 0, -9), Vector3(-3, 0, -11), Vector3(4, 0, -13), Vector3(8, 0, -11)]:
        _add_crate(p)

    var fire := OmniLight3D.new()
    fire.position = Vector3(0.0, terrain_height(0.0, -12.0) + 1.1, -12.0)
    fire.light_color = Color(1.0, 0.48, 0.13)
    fire.light_energy = 2.2
    fire.omni_range = 11.0
    add_child(fire)

func _build_nature() -> void:
    var tree_positions := [
        Vector3(-38, 0, 20), Vector3(-31, 0, 31), Vector3(-18, 0, 38),
        Vector3(22, 0, 34), Vector3(36, 0, 24), Vector3(43, 0, 7),
        Vector3(-46, 0, -22), Vector3(47, 0, -29), Vector3(-34, 0, -39),
        Vector3(33, 0, -43), Vector3(-58, 0, 5), Vector3(58, 0, 13)
    ]
    for p in tree_positions:
        _add_tree(p)

    var rock_positions := [
        Vector3(-19, 0, 13), Vector3(16, 0, 17), Vector3(29, 0, 8),
        Vector3(-27, 0, 28), Vector3(7, 0, 39), Vector3(40, 0, -18)
    ]
    for p in rock_positions:
        _add_rock(p)

func _add_hut(position_2d: Vector3, tint: Color) -> void:
    var root := Node3D.new()
    var y := terrain_height(position_2d.x, position_2d.z)
    root.position = Vector3(position_2d.x, y, position_2d.z)
    add_child(root)

    var wall := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(5.4, 3.2, 4.6)
    wall.mesh = box
    wall.position.y = 1.6
    var wall_material := StandardMaterial3D.new()
    wall_material.albedo_color = tint
    wall_material.roughness = 0.95
    wall.material_override = wall_material
    root.add_child(wall)

    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(6.2, 0.55, 5.4)
    roof.mesh = roof_mesh
    roof.position = Vector3(0.0, 3.35, 0.0)
    var roof_material := StandardMaterial3D.new()
    roof_material.albedo_color = Color(0.16, 0.09, 0.045)
    roof_material.roughness = 1.0
    roof.material_override = roof_material
    root.add_child(roof)

func _add_crate(position_2d: Vector3) -> void:
    var crate := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.25, 1.25, 1.25)
    crate.mesh = mesh
    crate.position = Vector3(position_2d.x, terrain_height(position_2d.x, position_2d.z) + 0.63, position_2d.z)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.44, 0.25, 0.08)
    material.roughness = 0.92
    crate.material_override = material
    add_child(crate)

func _add_tree(position_2d: Vector3) -> void:
    var y := terrain_height(position_2d.x, position_2d.z)
    var root := Node3D.new()
    root.position = Vector3(position_2d.x, y, position_2d.z)
    add_child(root)

    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.24
    trunk_mesh.bottom_radius = 0.38
    trunk_mesh.height = 4.4
    trunk_mesh.radial_segments = 8
    trunk.mesh = trunk_mesh
    trunk.position.y = 2.2
    var trunk_material := StandardMaterial3D.new()
    trunk_material.albedo_color = Color(0.28, 0.15, 0.055)
    trunk_material.roughness = 1.0
    trunk.material_override = trunk_material
    root.add_child(trunk)

    var crown := MeshInstance3D.new()
    var crown_mesh := SphereMesh.new()
    crown_mesh.radius = 1.65
    crown_mesh.height = 2.4
    crown_mesh.radial_segments = 12
    crown_mesh.rings = 6
    crown.mesh = crown_mesh
    crown.position = Vector3(0.0, 4.75, 0.0)
    crown.scale = Vector3(1.25, 0.75, 1.25)
    var leaves := StandardMaterial3D.new()
    leaves.albedo_color = Color(0.055, 0.31, 0.08)
    leaves.roughness = 0.95
    crown.material_override = leaves
    root.add_child(crown)

func _add_rock(position_2d: Vector3) -> void:
    var rock := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 1.4
    mesh.radial_segments = 8
    mesh.rings = 5
    rock.mesh = mesh
    rock.position = Vector3(position_2d.x, terrain_height(position_2d.x, position_2d.z) + 0.55, position_2d.z)
    rock.scale = Vector3(1.2, 0.7, 0.9)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.30, 0.32, 0.31)
    material.roughness = 1.0
    rock.material_override = material
    add_child(rock)

func _spawn_regular_enemies() -> void:
    var positions := [
        Vector3(-12, 0, 12), Vector3(13, 0, 13), Vector3(-21, 0, -2), Vector3(21, 0, 1),
        Vector3(-29, 0, 18), Vector3(31, 0, 21), Vector3(-18, 0, 31), Vector3(17, 0, 35)
    ]
    _remaining_enemies = positions.size()
    for p in positions:
        _spawn_enemy(p, false)

func _spawn_enemy(position_2d: Vector3, boss: bool) -> void:
    var enemy = EnemyScript.new()
    if boss:
        enemy.max_health = 260.0
        enemy.move_speed = 2.9
        enemy.detection_radius = 30.0
        enemy.scale = Vector3(1.55, 1.55, 1.55)
        enemy.set_meta("boss", true)
    add_child(enemy)
    enemy.global_position = Vector3(position_2d.x, terrain_height(position_2d.x, position_2d.z) + 1.2, position_2d.z)
    enemy.defeated.connect(_on_enemy_defeated)

func _on_enemy_defeated(enemy: Node) -> void:
    if bool(enemy.get_meta("boss", false)):
        var hud := get_tree().get_first_node_in_group("hud")
        if hud != null and hud.has_method("set_mission"):
            hud.set_mission("ÎLE 1 SÉCURISÉE", "Le capitaine ennemi est vaincu. Explore le village et prépare la suite du voyage.")
        return

    _remaining_enemies = maxi(0, _remaining_enemies - 1)
    if _remaining_enemies <= 0 and not _boss_spawned:
        _boss_spawned = true
        _spawn_enemy(Vector3(0, 0, 28), true)
    _update_mission()

func _update_mission() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud == null or not hud.has_method("set_mission"):
        return
    if _boss_spawned:
        hud.set_mission("BOSS — CAPITAINE DU RIVAGE", "Le boss est apparu près du village. Utilise attaque, esquive et tes deux pouvoirs.")
    else:
        hud.set_mission("ÎLE 1 — ROYAUME MUSICAL", "Élimine les ennemis du village : %d restant(s) sur 8." % _remaining_enemies)

func _place_player() -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player != null:
        player.global_position = Vector3(0.0, terrain_height(0.0, 0.0) + 1.15, 6.0)

func _add_island_title() -> void:
    var label := Label3D.new()
    label.text = "ÎLE 1 — ROYAUME MUSICAL"
    label.font_size = 42
    label.outline_size = 10
    label.modulate = Color(1.0, 0.86, 0.45)
    label.position = Vector3(0.0, terrain_height(0.0, -31.0) + 6.7, -31.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)
