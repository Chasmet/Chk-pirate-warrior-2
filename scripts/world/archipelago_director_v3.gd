class_name ArchipelagoDirectorV3
extends "res://scripts/world/archipelago_director_v2.gd"

const SHALLOW_WATER_MIN_Y := -0.98
const SHALLOW_WATER_RADIAL_LIMIT := 0.94

func _ready() -> void:
    # Une seule île est active à la fois : 56 subdivisions restent légères sur Android
    # tout en supprimant l'aspect polygonal grossier vu sur téléphone.
    terrain_resolution = 56
    super._ready()

# La V3 ne disperse plus des GLB sans normalisation via le vieux système.
# Le décor est construit par GLBSceneryDirector avec taille, placement au sol
# et zones de circulation mobile contrôlées.
func _scatter_real_props(_info: Dictionary) -> void:
    pass

func _build_terrain(info: Dictionary) -> void:
    super._build_terrain(info)
    if _island_root == null or not is_instance_valid(_island_root):
        return
    var terrain: MeshInstance3D = _island_root.get_node_or_null("TerrainRelief") as MeshInstance3D
    if terrain == null:
        return

    var shader: Shader = Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 core_color : source_color = vec4(0.25, 0.55, 0.30, 1.0);
uniform vec4 coast_color : source_color = vec4(0.76, 0.62, 0.38, 1.0);
uniform vec4 rock_color : source_color = vec4(0.30, 0.29, 0.27, 1.0);
uniform vec2 island_half_size = vec2(600.0, 500.0);
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() {
    local_pos = VERTEX;
    local_normal = NORMAL;
}
void fragment() {
    vec2 normalized_xz = local_pos.xz / max(island_half_size, vec2(1.0));
    float radial = length(normalized_xz);
    float coast = smoothstep(0.68, 0.94, radial);
    float altitude_rock = smoothstep(15.0, 40.0, local_pos.y);
    float slope_rock = smoothstep(0.30, 0.78, 1.0 - abs(normalize(local_normal).y));
    float rock_mix = clamp(altitude_rock * 0.48 + slope_rock * 0.92, 0.0, 1.0);
    vec3 col = mix(core_color.rgb, coast_color.rgb, coast * (1.0 - rock_mix * 0.82));
    col = mix(col, rock_color.rgb, rock_mix);
    float variation = sin(local_pos.x * 0.032) * cos(local_pos.z * 0.027) * 0.045;
    variation += sin((local_pos.x + local_pos.z) * 0.091) * 0.018;
    ALBEDO = clamp(col + vec3(variation), vec3(0.0), vec3(1.0));
    ROUGHNESS = mix(0.84, 0.98, rock_mix);
    METALLIC = 0.0;
}
"""

    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    var palette: Dictionary = _terrain_palette(int(info["id"]), info["color"])
    material.set_shader_parameter("core_color", palette["core"])
    material.set_shader_parameter("coast_color", palette["coast"])
    material.set_shader_parameter("rock_color", palette["rock"])
    var size: Vector2 = info["size"]
    material.set_shader_parameter("island_half_size", size * 0.5)
    terrain.material_override = material
    _build_arrival_plaza(info)

func _build_arrival_plaza(info: Dictionary) -> void:
    if _island_root == null or not is_instance_valid(_island_root):
        return
    var size: Vector2 = info["size"]
    var plaza_z := size.y * 0.34
    var plaza_y := _terrain_height_at(info, 0.0, plaza_z)

    _add_static_box(
        _island_root,
        "PlaceArrivee",
        Vector3(0.0, plaza_y - 0.45, plaza_z),
        Vector3(86.0, 1.1, 68.0),
        Color("d7c58b")
    )

    for i in range(7):
        var road_z := plaza_z + 40.0 + float(i) * 12.0
        var road_y := _terrain_height_at(info, 0.0, road_z)
        _add_static_box(
            _island_root,
            "RoutePort_%02d" % i,
            Vector3(0.0, road_y - 0.30, road_z),
            Vector3(16.0, 0.8, 13.0),
            Color("a88958")
        )

func _add_static_box(parent: Node3D, node_name: String, center: Vector3, box_size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = center

    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    visual.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    visual.material_override = material
    body.add_child(visual)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box_size
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)

func _terrain_vertex(ix: int, iz: int, resolution: int, size: Vector2, noise: FastNoiseLite) -> Vector3:
    var u := float(ix) / float(resolution)
    var v := float(iz) / float(resolution)
    var x := (u - 0.5) * size.x
    var z := (v - 0.5) * size.y
    var island_id := maxi(1, GameState.current_island)
    var height := _terrain_height_formula(island_id, size, x, z, noise)
    return Vector3(x, height, z)

func _terrain_height_at(info: Dictionary, x: float, z: float) -> float:
    var size: Vector2 = info["size"]
    var noise := FastNoiseLite.new()
    noise.seed = 731 + int(info["id"]) * 97
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.0065
    noise.fractal_octaves = 4
    noise.fractal_gain = 0.52
    return _terrain_height_formula(int(info["id"]), size, x, z, noise)

func _terrain_height_formula(island_id: int, size: Vector2, x: float, z: float, noise: FastNoiseLite) -> float:
    var nx := x / maxf(1.0, size.x * 0.5)
    var nz := z / maxf(1.0, size.y * 0.5)
    var radial := sqrt(nx * nx + nz * nz)
    var coast := smoothstep(1.0, 0.70, radial)

    # Trois fréquences donnent une silhouette d'île lisible de loin et un sol
    # moins uniforme de près : grandes collines + crêtes + détails locaux.
    var macro := noise.get_noise_2d(x * 0.24 + 2100.0, z * 0.24 - 1700.0)
    var raw := noise.get_noise_2d(x, z)
    var ridge := absf(noise.get_noise_2d(x * 0.46 + 913.0, z * 0.46 - 441.0))
    var detail := noise.get_noise_2d(x * 1.85 - 511.0, z * 1.85 + 827.0)

    var center_lift := pow(maxf(0.0, 1.0 - radial), 1.15) * 13.0
    var macro_hills := maxf(0.0, macro + 0.18) * 28.0
    var height := (raw * 20.0 + ridge * 24.0 + detail * 4.0 + macro_hills + center_lift) * coast

    # Les falaises n'occupent que certains secteurs. Les autres restent ouverts
    # aux petites plages. Le port (+Z au centre) est exclu de ces parois.
    var angle := atan2(nz, nx)
    var cliff_sector := pow(absf(sin(angle * 2.5 + float(island_id) * 0.71)), 3.0)
    var cliff_band := smoothstep(0.70, 0.80, radial) * (1.0 - smoothstep(0.88, 0.94, radial))
    var cliff_noise := 0.55 + ridge * 0.75
    var port_clear := 0.0 if absf(x) < 125.0 and z > size.y * 0.12 else 1.0
    height += cliff_band * cliff_sector * cliff_noise * 18.0 * port_clear

    if radial > 0.94:
        height -= (radial - 0.94) * 155.0

    # Grande zone d'arrivée volontairement douce et praticable.
    if absf(x) < 115.0 and z > size.y * 0.18:
        height *= 0.12

    return _clamp_inland_water_depth(height, radial)

func _clamp_inland_water_depth(height: float, radial: float) -> float:
    if radial <= SHALLOW_WATER_RADIAL_LIMIT:
        return maxf(height, SHALLOW_WATER_MIN_Y)
    return height

func _terrain_palette(island_id: int, base_color: Color) -> Dictionary:
    match island_id:
        2:
            return {"core": base_color, "coast": Color("e9b0c4"), "rock": Color("7a5967")}
        4:
            return {"core": base_color, "coast": Color("7f9bab"), "rock": Color("35434e")}
        5:
            return {"core": base_color, "coast": Color("6e737c"), "rock": Color("30343b")}
        6:
            return {"core": base_color, "coast": Color("b9b66a"), "rock": Color("53634f")}
        7:
            return {"core": base_color, "coast": Color("b89562"), "rock": Color("493d31")}
        8:
            return {"core": Color("d9edf6"), "coast": Color("c5e3ef"), "rock": Color("8297a3")}
        9:
            return {"core": Color("5a3630"), "coast": Color("7d4130"), "rock": Color("272222")}
        10:
            return {"core": base_color, "coast": Color("9b875d"), "rock": Color("413d32")}
        11:
            return {"core": base_color, "coast": Color("76664a"), "rock": Color("2f2b27")}
        _:
            return {"core": base_color, "coast": Color("c8ad72"), "rock": Color("55514a")}

func _spawn_enemy(path: String, local_position: Vector3, is_boss: bool, difficulty: float, display_name: String = "", archetype: String = "melee", variant_index: int = 0) -> void:
    # Depuis l'ajout des vraies collines/falaises, Y=10 n'est plus une hauteur
    # de spawn valide : certaines forces apparaissaient sous une colline alors
    # que le GPS les suivait. On pose maintenant chaque ennemi sur le relief réel.
    var info := current_island_data()
    var ground_y := _terrain_height_at(info, local_position.x, local_position.z)
    local_position.y = ground_y + (0.22 if is_boss else 0.12)
    super._spawn_enemy(path, local_position, is_boss, difficulty, display_name, archetype, variant_index)

func _spawn_boat(info: Dictionary) -> void:
    # Le bateau piloté est conservé par ArchipelagoDirectorV2 pendant une
    # transition. Ne pas créer en plus le bateau de quai du nouveau royaume :
    # c'était la cause structurelle des deux coques superposées à l'arrivée.
    var active := get_tree().get_first_node_in_group("active_controller")
    if active is BoatController and is_instance_valid(active) and (active as BoatController).is_boarded():
        return
    super._spawn_boat(info)
    if _island_root == null or not is_instance_valid(_island_root):
        return
    var boat_name := "Bateau_%02d" % int(info["id"])
    var boat := _island_root.get_node_or_null(boat_name) as BoatController
    if boat == null:
        return
    var size: Vector2 = info["size"]
    # Position définitive hors collision du quai. Le StabilityDirector conserve
    # son correctif de migration pour les anciennes scènes/sauvegardes.
    boat.position = Vector3(3.4, boat.water_height, size.y * 0.45 + 41.8)
    boat.rotation.y = PI
    boat.velocity = Vector3.ZERO
    boat.moor_at_current_position()

func _safe_port_spawn(index: int) -> Vector3:
    var resolved: int = clampi(index, 0, WorldCatalog.island_count() - 1)
    var info: Dictionary = WorldCatalog.island(resolved)
    var size: Vector2 = info["size"]
    var local_z: float = size.y * 0.34
    var ground_y := _terrain_height_at(info, 0.0, local_z)
    return _positions[resolved] + Vector3(0.0, ground_y + 1.2, local_z)

func on_boss_defeated(enemy: Node) -> void:
    var island_id := maxi(1, GameState.current_island)
    var was_already_defeated := GameState.is_boss_defeated(island_id)
    super.on_boss_defeated(enemy)
    if not was_already_defeated and GameState.is_boss_defeated(island_id):
        get_tree().call_group("hero_voice_director", "play_event", "victoire")

func request_boat_interaction() -> bool:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if _player == null:
        return false

    var active_before := get_tree().get_first_node_in_group("active_controller")

    # Nettoyage défensif : un ancien bateau/véhicule sans conducteur ne doit pas
    # consommer INTERAGIR comme s'il était encore le contrôleur actif.
    if active_before != null and is_instance_valid(active_before) and active_before.has_method("is_boarded"):
        if not bool(active_before.call("is_boarded")):
            active_before.remove_from_group("active_controller")
            active_before = null

    var was_on_boat := active_before is BoatController and (active_before as BoatController).is_boarded()

    if active_before != null and is_instance_valid(active_before):
        var active_result := super.request_boat_interaction()
        if active_result:
            return true
        return false

    # La houle ne doit pas modifier la capacité à embarquer : on mesure le plan
    # X/Z via BoatController.boarding_distance_to(), tout en conservant le rayon
    # réel de 9 m demandé pour l'accès depuis le quai.
    var best_boat: BoatController
    var best_boat_distance := INF
    for candidate in get_tree().get_nodes_in_group("boat"):
        if not (candidate is BoatController) or not is_instance_valid(candidate):
            continue
        var boat := candidate as BoatController
        if boat.is_boarded():
            continue
        var distance := boat.boarding_distance_to(_player.global_position)
        if distance <= boat.boarding_radius and distance < best_boat_distance:
            best_boat_distance = distance
            best_boat = boat

    if best_boat != null:
        var boarded := best_boat.try_interact(_player)
        if boarded and best_boat.is_boarded():
            get_tree().call_group("hero_voice_director", "play_event", "embarquement")
        return boarded

    # Hors du rayon d'un bateau, le comportement historique reste intact pour
    # permettre l'utilisation normale des véhicules terrestres.
    var result := super.request_boat_interaction()
    if not result:
        return false
    var active_after := get_tree().get_first_node_in_group("active_controller")
    var is_on_boat_now := active_after is BoatController and (active_after as BoatController).is_boarded()
    if not was_on_boat and is_on_boat_now:
        get_tree().call_group("hero_voice_director", "play_event", "embarquement")
    return true
