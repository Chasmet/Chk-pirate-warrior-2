class_name ArchipelagoDirector
extends Node3D

const WorldEnemyScript = preload("res://scripts/world/world_enemy.gd")
const BoatControllerScript = preload("res://scripts/player/boat_controller.gd")

@export var terrain_resolution := 34
@export var prop_count := 28
@export var soldier_count := 8
@export var day_length_seconds := 780.0

var _positions: Array[Vector3] = []
var _current_index := -1
var _island_root: Node3D
var _player: CharacterBody3D
var _sun: DirectionalLight3D
var _environment: Environment
var _day_clock := 0.25
var _boss_defeated := {}
var _notification_label: Label
var _horizon_root: Node3D
var _horizon_proxies: Array[Node3D] = []

func _ready() -> void:
    add_to_group("world_director")
    _positions = WorldCatalog.world_positions()
    _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    _create_environment()
    _create_ocean()
    _create_horizon_islands()
    _create_notification_ui()
    var start_index := clampi(GameState.current_island - 1, 0, WorldCatalog.island_count() - 1)
    _load_island(start_index, true)

func _process(delta: float) -> void:
    _day_clock = fmod(_day_clock + delta / maxf(60.0, day_length_seconds), 1.0)
    _update_day_night()
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
        return
    var nearest := _nearest_island_index(_player.global_position)
    if nearest != _current_index:
        _load_island(nearest, false)

func current_island_data() -> Dictionary:
    return WorldCatalog.island(_current_index if _current_index >= 0 else 0)

func on_boss_defeated(_enemy: Node) -> void:
    if _current_index < 0:
        return
    _boss_defeated[_current_index] = true
    var info := WorldCatalog.island(_current_index)
    _notify("Boss vaincu — %s" % str(info["name"]))
    if _current_index == 10:
        _spawn_final_reward(info)
        _notify("Le trophée final est apparu. La campagne principale est terminée.")
    elif _current_index + 1 < WorldCatalog.island_count():
        _notify("La route maritime vers %s est ouverte." % str(WorldCatalog.island(_current_index + 1)["name"]))

func request_boat_interaction() -> bool:
    if _player == null:
        return false
    var active := get_tree().get_first_node_in_group("active_controller")
    if active != null and active.has_method("disembark"):
        active.disembark()
        return true
    var best_boat: Node3D
    var best_distance := INF
    for boat in get_tree().get_nodes_in_group("boat"):
        if boat is Node3D:
            var d: float = (boat as Node3D).global_position.distance_to(_player.global_position)
            if d < best_distance:
                best_distance = d
                best_boat = boat as Node3D
    if best_boat != null and best_distance <= 9.0 and best_boat.has_method("try_interact"):
        return bool(best_boat.try_interact(_player))
    _notify("Approche-toi d'un bateau pour embarquer.")
    return false

func _nearest_island_index(world_position: Vector3) -> int:
    var result := 0
    var best := INF
    for i in range(_positions.size()):
        var delta := world_position - _positions[i]
        delta.y = 0.0
        var distance := delta.length()
        if distance < best:
            best = distance
            result = i
    return result

func _load_island(index: int, place_player: bool) -> void:
    index = clampi(index, 0, WorldCatalog.island_count() - 1)
    if index == _current_index and _island_root != null:
        return
    if _island_root != null and is_instance_valid(_island_root):
        _island_root.queue_free()
    _current_index = index
    _update_horizon_islands(index)
    GameState.set_island(index + 1)
    var info := WorldCatalog.island(index)
    _apply_weather(info)

    _island_root = Node3D.new()
    _island_root.name = "Royaume_%02d_%s" % [index + 1, str(info["slug"])]
    _island_root.position = _positions[index]
    add_child(_island_root)

    _build_terrain(info)
    _build_port(info)
    _scatter_real_props(info)
    _spawn_population_and_enemies(info)
    _spawn_boat(info)

    if place_player and _player != null:
        var size: Vector2 = info["size"]
        _player.global_position = _positions[index] + Vector3(0.0, 8.0, size.y * 0.28)
    _notify("ÎLE %02d — %s" % [index + 1, str(info["name"])])

func _create_environment() -> void:
    _sun = DirectionalLight3D.new()
    _sun.name = "SoleilDynamique"
    _sun.shadow_enabled = true
    _sun.light_energy = 1.25
    add_child(_sun)

    _environment = Environment.new()
    _environment.background_mode = Environment.BG_COLOR
    _environment.background_color = Color("78b7d8")
    _environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    _environment.ambient_light_color = Color("b8d5e3")
    _environment.ambient_light_energy = 0.72
    _environment.fog_enabled = true
    _environment.fog_density = 0.0025
    _environment.fog_sky_affect = 0.45
    var world_environment := WorldEnvironment.new()
    world_environment.environment = _environment
    add_child(world_environment)

func _create_ocean() -> void:
    var ocean := MeshInstance3D.new()
    ocean.name = "OceanContinu"
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(30000.0, 30000.0)
    ocean.mesh = mesh
    var positions := WorldCatalog.world_positions()
    var min_z := 0.0
    var max_z := 0.0
    for p in positions:
        min_z = minf(min_z, p.z)
        max_z = maxf(max_z, p.z)
    # Les bateaux et les équipages naviguent autour de Y=-0,55. L'ancien plan
    # à Y=-2,2 les faisait visuellement flotter 1,65 m au-dessus de l'eau.
    ocean.position = Vector3(0.0, -0.65, (min_z + max_z) * 0.5)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.025, 0.25, 0.42, 0.94)
    material.metallic = 0.12
    material.roughness = 0.18
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ocean.material_override = material
    add_child(ocean)

func _create_horizon_islands() -> void:
    _horizon_root = Node3D.new()
    _horizon_root.name = "RoyaumesHorizonLOD"
    add_child(_horizon_root)
    _horizon_proxies.clear()
    for i in range(WorldCatalog.island_count()):
        var info: Dictionary = WorldCatalog.island(i)
        var size: Vector2 = info["size"]
        var proxy := Node3D.new()
        proxy.name = "HorizonRoyaume_%02d" % (i + 1)
        proxy.position = _positions[i]
        _horizon_root.add_child(proxy)

        var coast := MeshInstance3D.new()
        coast.name = "SilhouetteCotiere"
        var coast_mesh := SphereMesh.new()
        coast_mesh.radius = 1.0
        coast_mesh.height = 2.0
        coast_mesh.radial_segments = 16
        coast_mesh.rings = 6
        coast.mesh = coast_mesh
        coast.scale = Vector3(size.x * 0.46, 34.0 + float(i) * 2.8, size.y * 0.46)
        coast.position.y = -31.0
        coast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        coast.material_override = _horizon_material(info["color"])
        proxy.add_child(coast)

        var peak_height := 82.0 + float((i * 37) % 115)
        var peak := MeshInstance3D.new()
        peak.name = "SommetLointain"
        var peak_mesh := CylinderMesh.new()
        peak_mesh.bottom_radius = 1.0
        peak_mesh.top_radius = 0.08
        peak_mesh.height = 2.0
        peak_mesh.radial_segments = 10
        peak.mesh = peak_mesh
        var peak_radius := minf(size.x, size.y) * (0.10 + float(i % 3) * 0.018)
        peak.scale = Vector3(peak_radius, peak_height * 0.5, peak_radius)
        peak.position = Vector3(size.x * (-0.10 + float(i % 4) * 0.055), peak_height * 0.5 - 1.0, -size.y * 0.06)
        peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        peak.material_override = _horizon_material(info["accent"])
        proxy.add_child(peak)

        if i == 0:
            for pipe_index in range(5):
                var pipe := MeshInstance3D.new()
                pipe.name = "OrgueHorizon_%02d" % pipe_index
                var pipe_mesh := CylinderMesh.new()
                pipe_mesh.bottom_radius = 1.0
                pipe_mesh.top_radius = 1.0
                pipe_mesh.height = 2.0
                pipe_mesh.radial_segments = 8
                pipe.mesh = pipe_mesh
                var pipe_height := 54.0 + float(2 - abs(pipe_index - 2)) * 18.0
                pipe.scale = Vector3(7.0, pipe_height * 0.5, 7.0)
                pipe.position = Vector3(-36.0 + float(pipe_index) * 18.0, pipe_height * 0.5, size.y * 0.05)
                pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                pipe.material_override = _horizon_material(info["accent"])
                proxy.add_child(pipe)

        _horizon_proxies.append(proxy)

func _horizon_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color.darkened(0.12)
    material.roughness = 1.0
    return material

func _update_horizon_islands(active_index: int) -> void:
    for i in range(_horizon_proxies.size()):
        var proxy := _horizon_proxies[i]
        if proxy != null and is_instance_valid(proxy):
            proxy.visible = i != active_index

func _build_terrain(info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var resolution := maxi(18, terrain_resolution)
    var noise := FastNoiseLite.new()
    noise.seed = 731 + int(info["id"]) * 97
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.0065
    noise.fractal_octaves = 4
    noise.fractal_gain = 0.52

    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for z in range(resolution):
        for x in range(resolution):
            var p00 := _terrain_vertex(x, z, resolution, size, noise)
            var p10 := _terrain_vertex(x + 1, z, resolution, size, noise)
            var p01 := _terrain_vertex(x, z + 1, resolution, size, noise)
            var p11 := _terrain_vertex(x + 1, z + 1, resolution, size, noise)
            # Godot considère l'autre enroulement comme la face avant. L'ancien
            # ordre rendait l'île invisible vue d'en haut et la collision
            # concave rejetait le héros : il tombait sous le terrain en boucle.
            _add_triangle(surface, p00, p10, p01, size)
            _add_triangle(surface, p10, p11, p01, size)
    surface.generate_normals()
    var terrain_mesh := surface.commit()

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "TerrainRelief"
    mesh_instance.mesh = terrain_mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = info["color"]
    material.roughness = 0.92
    material.metallic = 0.02
    mesh_instance.material_override = material
    _island_root.add_child(mesh_instance)

    var body := StaticBody3D.new()
    body.name = "CollisionTerrain"
    var collision := CollisionShape3D.new()
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(terrain_mesh.get_faces())
    # Sécurité mobile : un bord de triangle ou une arrivée depuis un relief
    # abrupt ne doit jamais permettre de traverser l'île.
    shape.backface_collision = true
    collision.shape = shape
    body.add_child(collision)
    _island_root.add_child(body)

func _terrain_vertex(ix: int, iz: int, resolution: int, size: Vector2, noise: FastNoiseLite) -> Vector3:
    var u := float(ix) / float(resolution)
    var v := float(iz) / float(resolution)
    var x := (u - 0.5) * size.x
    var z := (v - 0.5) * size.y
    var nx := x / maxf(1.0, size.x * 0.5)
    var nz := z / maxf(1.0, size.y * 0.5)
    var radial := sqrt(nx * nx + nz * nz)
    var coast := smoothstep(1.0, 0.72, radial)
    var raw := noise.get_noise_2d(x, z)
    var ridge := absf(noise.get_noise_2d(x * 0.42 + 913.0, z * 0.42 - 441.0))
    var height := (raw * 28.0 + ridge * 16.0) * coast
    if radial > 0.94:
        height -= (radial - 0.94) * 145.0
    if absf(x) < 115.0 and z > size.y * 0.18:
        height *= 0.12
    return Vector3(x, height, z)

func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, size: Vector2) -> void:
    for p in [a, b, c]:
        surface.set_uv(Vector2(p.x / size.x + 0.5, p.z / size.y + 0.5))
        surface.add_vertex(p)

func _build_port(info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var port_z := size.y * 0.45
    var dock := StaticBody3D.new()
    dock.name = "PortPrincipal"
    dock.position = Vector3(0.0, 0.8, port_z)
    for i in range(7):
        var plank := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(8.0, 0.6, 5.5)
        plank.mesh = mesh
        plank.position = Vector3(0.0, 0.0, float(i) * 5.0)
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("6b452c")
        material.roughness = 0.9
        plank.material_override = material
        dock.add_child(plank)
    var collision := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(8.0, 1.2, 38.0)
    collision.shape = box
    collision.position.z = 16.5
    dock.add_child(collision)
    _island_root.add_child(dock)

func _scatter_real_props(info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var rng := RandomNumberGenerator.new()
    rng.seed = 5000 + int(info["id"]) * 101
    var prop_paths := Array(WorldCatalog.COMMON_PROPS)
    if int(info["id"]) == 7:
        prop_paths.append("res://assets/decors_glb/glb/canon_pirate.glb")
        prop_paths.append("res://assets/decors_glb/glb/canon_lourd.glb")
    for i in range(prop_count):
        var path := str(prop_paths[i % prop_paths.size()])
        var node := _instantiate_asset(path)
        if node == null:
            continue
        var angle := rng.randf_range(0.0, TAU)
        var radius := sqrt(rng.randf()) * 0.38
        node.position = Vector3(cos(angle) * size.x * radius, 5.0, sin(angle) * size.y * radius)
        node.rotation.y = rng.randf_range(0.0, TAU)
        var s := rng.randf_range(0.85, 1.6)
        node.scale *= Vector3.ONE * s
        _island_root.add_child(node)

func _spawn_population_and_enemies(info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var soldier_paths: Array = info.get("soldiers", [])
    if not soldier_paths.is_empty():
        for i in range(soldier_count):
            var path := str(soldier_paths[i % soldier_paths.size()])
            var angle := TAU * float(i) / float(maxi(1, soldier_count))
            var radius := minf(size.x, size.y) * (0.12 + float(i % 3) * 0.045)
            _spawn_enemy(path, Vector3(cos(angle) * radius, 10.0, sin(angle) * radius), false, 0.8 + float(info["id"]) * 0.12)
    if ResourceLoader.exists(str(info["boss"])):
        _spawn_enemy(str(info["boss"]), Vector3(0.0, 12.0, -size.y * 0.18), true, 1.0 + float(info["id"]) * 0.16)

func _spawn_enemy(path: String, local_position: Vector3, is_boss: bool, difficulty: float) -> void:
    var enemy := CharacterBody3D.new()
    enemy.name = "Boss" if is_boss else "Ennemi"
    enemy.set_script(WorldEnemyScript)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.7 if is_boss else 0.38
    shape.height = 3.0 if is_boss else 1.8
    collision.shape = shape
    collision.position.y = shape.height * 0.5
    enemy.add_child(collision)
    enemy.position = local_position
    enemy.set("model_path", path)
    enemy.set("boss", is_boss)
    enemy.set("max_health", (620.0 if is_boss else 105.0) * difficulty)
    enemy.set("health", (620.0 if is_boss else 105.0) * difficulty)
    enemy.set("attack_damage", (22.0 if is_boss else 8.0) * difficulty)
    _island_root.add_child(enemy)

func _spawn_boat(info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var boat := CharacterBody3D.new()
    boat.name = "Bateau_%02d" % int(info["id"])
    boat.set_script(BoatControllerScript)
    boat.set("model_path", str(info["ship"]))
    boat.set("water_height", -0.55)
    boat.set("boarding_radius", 9.0)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(5.0, 2.3, 12.0)
    collision.shape = shape
    collision.position.y = 1.0
    boat.add_child(collision)
    # Le bateau était à plus de 80 m du bout du quai de l'île 1 alors que la
    # portée d'embarquement est de 9 m. Il est désormais amarré au quai.
    boat.position = Vector3(7.0, -0.55, size.y * 0.45 + 39.0)
    _island_root.add_child(boat)

func _spawn_final_reward(info: Dictionary) -> void:
    if not info.has("reward") or _island_root == null:
        return
    var reward := _instantiate_asset(str(info["reward"]))
    if reward == null:
        return
    reward.name = "TropheeFinal"
    reward.position = Vector3(0.0, 7.0, -40.0)
    reward.scale *= Vector3.ONE * 1.6
    _island_root.add_child(reward)

func _instantiate_asset(path: String) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var resource := load(path)
    if resource is PackedScene:
        var node: Node = resource.instantiate()
        if node is Node3D:
            return node as Node3D
        node.queue_free()
    return null

func _apply_weather(info: Dictionary) -> void:
    if _environment == null:
        return
    var weather := str(info["weather"])
    _environment.fog_enabled = bool(info.get("fog", false)) or weather in ["neige", "cendres", "brume_doree", "brume_magique"]
    match weather:
        "brume_doree":
            _environment.fog_density = 0.026
            _environment.fog_light_color = Color("d4b55b")
            _environment.background_color = Color("786d4b")
        "neige":
            _environment.fog_density = 0.008
            _environment.fog_light_color = Color("dceaf2")
            _environment.background_color = Color("a5c4d5")
        "cendres":
            _environment.fog_density = 0.011
            _environment.fog_light_color = Color("75564b")
            _environment.background_color = Color("4e4140")
        "brume_magique":
            _environment.fog_density = 0.012
            _environment.fog_light_color = Color("8fb8c8")
            _environment.background_color = Color("637c8a")
        _:
            _environment.fog_density = 0.0028
            _environment.fog_light_color = Color("b6d4dc")
            _environment.background_color = Color("79b7d6")

func _update_day_night() -> void:
    if _sun == null or _environment == null:
        return
    var angle := (_day_clock * TAU) - PI * 0.5
    _sun.rotation = Vector3(angle, -0.55, 0.0)
    var daylight := clampf(sin(angle) * 0.5 + 0.58, 0.08, 1.0)
    _sun.light_energy = 0.15 + daylight * 1.25
    _environment.ambient_light_energy = 0.18 + daylight * 0.62

func _create_notification_ui() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 18
    add_child(layer)
    _notification_label = Label.new()
    _notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _notification_label.anchor_left = 0.28
    _notification_label.anchor_right = 0.72
    _notification_label.anchor_top = 0.17
    _notification_label.anchor_bottom = 0.25
    _notification_label.add_theme_font_size_override("font_size", 22)
    _notification_label.add_theme_color_override("font_color", Color.WHITE)
    _notification_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
    _notification_label.add_theme_constant_override("shadow_offset_x", 2)
    _notification_label.add_theme_constant_override("shadow_offset_y", 2)
    layer.add_child(_notification_label)

func _notify(text: String) -> void:
    if _notification_label == null:
        return
    _notification_label.text = text
    _notification_label.modulate.a = 1.0
    var tween := create_tween()
    tween.tween_interval(3.0)
    tween.tween_property(_notification_label, "modulate:a", 0.0, 0.8)
