class_name KingdomIdentityV130
extends Node3D

# Renfort artistique ciblé V1 30/100. Les décors existants restent intacts ; cette
# couche ajoute de gros repères lisibles de loin aux royaumes Marvel et Pokémon.
var _root: Node3D
var _serial := 0
var _world: Node

func _ready() -> void:
    add_to_group("kingdom_identity_v1_30")
    _world = get_tree().get_first_node_in_group("world_director")
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _on_island_changed(island_id: int) -> void:
    _serial += 1
    _rebuild.call_deferred(clampi(island_id, 1, WorldCatalog.island_count()), _serial)

func _rebuild(island_id: int, serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial:
        return
    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _root = null
    if island_id not in [5, 6]:
        return

    _world = get_tree().get_first_node_in_group("world_director")
    var info := WorldCatalog.island(island_id - 1)
    var center := WorldCatalog.world_positions()[island_id - 1]
    _root = Node3D.new()
    _root.name = "IdentiteRenforceeV130_%02d" % island_id
    _root.global_position = center
    add_child(_root)

    if island_id == 5:
        _build_marvel_kingdom(info)
    else:
        _build_pokemon_kingdom(info)

func _build_marvel_kingdom(info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var tower_z := -size.y * 0.07
    var ground := _ground_y(info, 0.0, tower_z)

    var tower := Node3D.new()
    tower.name = "TourHeroiqueMarvel"
    tower.position = Vector3(0.0, ground, tower_z)
    _root.add_child(tower)

    _box(tower, "SocleTour", Vector3(0, 2.0, 0), Vector3(34, 4, 30), Color("343a46"), 0.12)
    _box(tower, "CorpsCentral", Vector3(0, 27.0, 0), Vector3(18, 50, 18), Color("56616f"), 0.28)
    _box(tower, "FacadeVerre", Vector3(0, 28.0, -9.15), Vector3(12, 43, 0.45), Color("4ca6d8"), 0.62)
    _box(tower, "AileRouge", Vector3(-13.0, 17.0, 1.5), Vector3(9, 28, 16), Color("a83835"), 0.18)
    _box(tower, "AileBleue", Vector3(13.0, 17.0, 1.5), Vector3(9, 28, 16), Color("315a8d"), 0.18)
    _box(tower, "Couronne", Vector3(0, 54.0, 0), Vector3(24, 4, 24), Color("bfc7ce"), 0.32)
    _cylinder(tower, "Fleche", Vector3(0, 65.0, 0), 0.85, 20.0, Color("dce6ec"), 0.42)

    # Silhouette en A très lisible sur la façade sans reprendre un logo importé.
    _box(tower, "EmblemeA_G", Vector3(-3.7, 35.0, -9.7), Vector3(1.2, 15.0, 0.6), Color("f1f3f5"), 0.35, -0.35)
    _box(tower, "EmblemeA_D", Vector3(3.7, 35.0, -9.7), Vector3(1.2, 15.0, 0.6), Color("f1f3f5"), 0.35, 0.35)
    _box(tower, "EmblemeA_Barre", Vector3(0, 35.5, -9.8), Vector3(7.0, 1.2, 0.7), Color("f1f3f5"), 0.35)

    var label := _label3d("ROYAUME MARVEL\nTOUR DES HÉROS", Color("f4e6c0"), 52)
    label.position = Vector3(0, 59.0, -14.0)
    tower.add_child(label)

    # Quartier urbain héroïque autour de la tour : bâtiments et balises d'énergie.
    for i in range(8):
        var side := -1.0 if i % 2 == 0 else 1.0
        var row := i / 2
        var x := side * (34.0 + float(row % 2) * 20.0)
        var z := tower_z + 24.0 - float(row) * 24.0
        var y := _ground_y(info, x, z)
        var h := 12.0 + float((i * 7) % 16)
        _box(_root, "ImmeubleHeroique_%02d" % i, Vector3(x, y + h * 0.5, z), Vector3(14, h, 14), Color("454e5c") if i % 2 == 0 else Color("5b6572"), 0.30)
        _cylinder(_root, "BaliseEnergie_%02d" % i, Vector3(x, y + h + 2.5, z), 0.42, 5.0, Color("58c8ff") if i % 2 == 0 else Color("ff6157"), 0.75)

func _build_pokemon_kingdom(info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var center_z := -size.y * 0.04
    var ground := _ground_y(info, 0.0, center_z)

    var center := Node3D.new()
    center.name = "CentreDresseursPokemon"
    center.position = Vector3(0.0, ground, center_z)
    _root.add_child(center)

    _box(center, "CentreBase", Vector3(0, 3.5, 0), Vector3(32, 7, 24), Color("f1f1ed"), 0.18)
    _box(center, "CentreToit", Vector3(0, 8.2, 0), Vector3(36, 2.6, 28), Color("d94a45"), 0.16)
    _box(center, "Entree", Vector3(0, 3.2, -12.3), Vector3(8, 6.2, 0.8), Color("4aa6d8"), 0.52)
    _cylinder(center, "TourDresseurs", Vector3(0, 17.0, 5.0), 4.2, 18.0, Color("f3f3ef"), 0.20)
    _sphere(center, "OrbeSommet", Vector3(0, 28.5, 5.0), 4.8, Color("e84b46"), 0.32)

    var label := _label3d("ROYAUME POKÉMON\nCENTRE DES DRESSEURS", Color("fff1a8"), 48)
    label.position = Vector3(0, 20.0, -15.0)
    center.add_child(label)

    # Grande arène circulaire.
    var arena_z := center_z - 58.0
    var arena_y := _ground_y(info, 0.0, arena_z)
    _cylinder(_root, "ArenePokemon", Vector3(0, arena_y + 0.6, arena_z), 24.0, 1.2, Color("d8c982"), 0.70)
    _torus(_root, "ContourArene", Vector3(0, arena_y + 1.25, arena_z), 21.5, 23.2, Color("e24c47"), 0.55)

    # Pokéballs géantes immédiatement identifiables depuis le port.
    var positions := [
        Vector3(-30, 0, center_z + 28), Vector3(30, 0, center_z + 28),
        Vector3(-42, 0, center_z - 28), Vector3(42, 0, center_z - 28),
        Vector3(0, 0, arena_z - 30)
    ]
    for i in range(positions.size()):
        var p: Vector3 = positions[i]
        p.y = _ground_y(info, p.x, p.z)
        _build_capture_ball("PokeballGeante_%02d" % i, p, 5.0 if i < 4 else 6.5)

func _build_capture_ball(node_name: String, position: Vector3, radius: float) -> void:
    var root := Node3D.new()
    root.name = node_name
    root.position = position
    _root.add_child(root)

    _sphere(root, "CoqueBlanche", Vector3(0, radius, 0), radius, Color("f2f2ee"), 0.22)
    var red_top := MeshInstance3D.new()
    red_top.name = "DemiCoqueRouge"
    var top_mesh := SphereMesh.new()
    top_mesh.radius = radius
    top_mesh.height = radius * 2.0
    top_mesh.radial_segments = 24
    top_mesh.rings = 12
    red_top.mesh = top_mesh
    red_top.position = Vector3(0, radius * 1.24, 0)
    red_top.scale = Vector3(1.01, 0.52, 1.01)
    red_top.material_override = _material(Color("df4742"), 0.25, 0.0)
    root.add_child(red_top)

    _torus(root, "CeintureNoire", Vector3(0, radius, 0), radius * 0.92, radius * 1.04, Color("202226"), 0.38)
    _cylinder(root, "BoutonNoir", Vector3(0, radius, -radius * 0.98), radius * 0.34, radius * 0.28, Color("202226"), 0.30, Vector3(PI * 0.5, 0, 0))
    _cylinder(root, "BoutonBlanc", Vector3(0, radius, -radius * 1.14), radius * 0.19, radius * 0.18, Color("f4f4ef"), 0.24, Vector3(PI * 0.5, 0, 0))

func _ground_y(info: Dictionary, x: float, z: float) -> float:
    if _world == null or not is_instance_valid(_world):
        _world = get_tree().get_first_node_in_group("world_director")
    if _world != null and _world.has_method("_terrain_height_at"):
        var result = _world.call("_terrain_height_at", info, x, z)
        if result != null:
            return float(result)
    return 0.0

func _box(parent: Node3D, node_name: String, pos: Vector3, box_size: Vector3, color: Color, metallic: float = 0.0, yaw: float = 0.0) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = box_size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.rotation.y = yaw
    mesh_instance.material_override = _material(color, 0.36, metallic)
    parent.add_child(mesh_instance)
    return mesh_instance

func _cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, color: Color, emission: float = 0.0, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 16
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.rotation = rotation_value
    mesh_instance.material_override = _material(color, 0.38, 0.05, emission)
    parent.add_child(mesh_instance)
    return mesh_instance

func _sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 20
    mesh.rings = 10
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = _material(color, 0.34, 0.03, emission)
    parent.add_child(mesh_instance)
    return mesh_instance

func _torus(parent: Node3D, node_name: String, pos: Vector3, inner_radius: float, outer_radius: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := TorusMesh.new()
    mesh.inner_radius = inner_radius
    mesh.outer_radius = outer_radius
    mesh.rings = 28
    mesh.ring_segments = 8
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = _material(color, 0.34, 0.04, emission)
    parent.add_child(mesh_instance)
    return mesh_instance

func _label3d(text_value: String, color: Color, font_size: int) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.font_size = font_size
    label.outline_size = 10
    label.modulate = color
    label.outline_modulate = Color(0, 0, 0, 0.94)
    return label

func _material(color: Color, roughness: float, metallic: float, emission: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission
    return material
