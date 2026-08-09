class_name IslandSettlementDirector
extends Node3D

const SETTLEMENT_NAMES := [
    "Village des Harmonies", "Bourg des Confiseries", "Grand Marché Gourmand",
    "Cité des Cristaux", "Quartier des Héros", "Camp des Dresseurs",
    "Port des Corsaires", "Hameau des Glaces", "Citadelle des Braises",
    "Village des Bâtisseurs", "Ruines des Souvenirs"
]

const PALETTES := [
    [Color("d3b878"), Color("365f58"), Color("e5bd50")],
    [Color("f2b7cf"), Color("c66b9e"), Color("fff0ae")],
    [Color("c99558"), Color("6f4b2f"), Color("e5b94f")],
    [Color("637b91"), Color("344a5b"), Color("7ed7ff")],
    [Color("626a78"), Color("343942"), Color("e45249")],
    [Color("8f9d66"), Color("4e6047"), Color("ecd94e")],
    [Color("8b6745"), Color("493426"), Color("d6a54d")],
    [Color("d6e8ef"), Color("7697ab"), Color("86c8e6")],
    [Color("5b3d36"), Color("282426"), Color("ff6234")],
    [Color("8f805d"), Color("514936"), Color("a8c771")],
    [Color("5b5050"), Color("2d2830"), Color("b88ae8")]
]

var _settlement_root: Node3D
var _current_island := -1
var _rebuild_serial := 0
var _materials: Dictionary = {}

func _ready() -> void:
    add_to_group("island_settlement_director")
    _settlement_root = Node3D.new()
    _settlement_root.name = "VillagesEtQuais"
    add_child(_settlement_root)
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _on_island_changed(island_id: int) -> void:
    var resolved := clampi(island_id, 1, WorldCatalog.island_count())
    if resolved == _current_island:
        return
    _current_island = resolved
    _rebuild_serial += 1
    _deferred_rebuild.call_deferred(_rebuild_serial)

func _deferred_rebuild(serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial == _rebuild_serial:
        _rebuild_settlement()

func _rebuild_settlement() -> void:
    if _settlement_root == null:
        return
    for child in _settlement_root.get_children():
        child.queue_free()
    _materials.clear()

    var info := WorldCatalog.island(_current_island - 1)
    var center: Vector3 = WorldCatalog.world_positions()[_current_island - 1]
    var island_size: Vector2 = info["size"]
    var palette: Array = PALETTES[_current_island - 1]
    var building_count := 9 if _current_island == 11 else 12

    for i in range(building_count):
        var row := i / 2
        var side := -1.0 if i % 2 == 0 else 1.0
        var local_x := side * (72.0 + float(row % 3) * 24.0)
        var local_z := island_size.y * 0.17 - float(row) * 58.0
        local_x += sin(float(i) * 1.73) * 12.0
        local_z += cos(float(i) * 1.29) * 9.0
        var base := _snap_to_ground(center + Vector3(local_x, 100.0, local_z))
        if _current_island == 11:
            _spawn_ruin(base, i, palette)
        else:
            _spawn_house(base, i, palette)

    _spawn_port_market(center, island_size, palette)
    _spawn_landmark(center, island_size, palette)
    _spawn_settlement_sign(center, island_size, palette)

func _spawn_house(base: Vector3, index: int, palette: Array) -> void:
    var body := StaticBody3D.new()
    body.name = "Maison_%02d_%02d" % [_current_island, index + 1]
    _settlement_root.add_child(body)
    body.global_position = base

    var width := 8.0 + float(index % 3) * 1.4
    var depth := 7.5 + float((index + 1) % 3) * 1.2
    var height := 7.2 + float(index % 4) * 1.1
    if _current_island == 5:
        height *= 1.55
        width *= 1.10
    var wall_color: Color = palette[0].lightened(float(index % 3) * 0.045)
    var roof_color: Color = palette[1]
    var accent: Color = palette[2]

    _add_box(body, "Murs", Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, depth), wall_color)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(width, height, depth)
    collision.shape = shape
    collision.position.y = height * 0.5
    body.add_child(collision)

    match _current_island:
        2:
            _add_cylinder(body, "ToitBonbon", Vector3(0.0, height + 1.25, 0.0), maxf(width, depth) * 0.58, 2.5, roof_color, 12)
        4:
            _add_cylinder(body, "FlècheCristal", Vector3(0.0, height + 2.1, 0.0), maxf(width, depth) * 0.42, 4.2, accent, 6, true, 0.06)
        8:
            _add_box(body, "ToitNeige", Vector3(0.0, height + 0.72, 0.0), Vector3(width + 1.8, 1.45, depth + 1.8), Color("eef8fb"))
        9:
            _add_box(body, "ToitBasalte", Vector3(0.0, height + 0.62, 0.0), Vector3(width + 1.2, 1.25, depth + 1.2), roof_color)
            _add_box(body, "Braise", Vector3(0.0, height + 1.38, depth * 0.18), Vector3(width * 0.55, 0.20, 0.20), accent, true)
        _:
            _add_box(body, "Toit", Vector3(0.0, height + 0.68, 0.0), Vector3(width + 1.4, 1.38, depth + 1.4), roof_color)

    _add_box(body, "Porte", Vector3(0.0, 1.65, depth * 0.505), Vector3(1.65, 3.3, 0.16), roof_color.darkened(0.18))
    _add_box(body, "FenetreG", Vector3(-width * 0.27, height * 0.60, depth * 0.508), Vector3(1.15, 1.25, 0.12), accent, true)
    _add_box(body, "FenetreD", Vector3(width * 0.27, height * 0.60, depth * 0.508), Vector3(1.15, 1.25, 0.12), accent, true)

    if _current_island == 1:
        for pipe_index in range(3):
            _add_cylinder(body, "Orgue_%d" % pipe_index, Vector3(-0.55 + pipe_index * 0.55, height + 1.9 + pipe_index * 0.28, -depth * 0.20), 0.13, 2.3 + pipe_index * 0.55, accent, 8)
    elif _current_island == 6 and index % 2 == 0:
        _add_box(body, "BanniereDresseur", Vector3(width * 0.42, height * 0.62, depth * 0.515), Vector3(0.85, 1.55, 0.10), accent)
    elif _current_island == 7:
        _add_box(body, "PoutreCorsaire", Vector3(0.0, height * 0.74, depth * 0.52), Vector3(width * 0.78, 0.24, 0.20), accent)

func _spawn_ruin(base: Vector3, index: int, palette: Array) -> void:
    var ruin := StaticBody3D.new()
    ruin.name = "RuineTroublee_%02d" % (index + 1)
    _settlement_root.add_child(ruin)
    ruin.global_position = base
    ruin.rotation.y = float(index % 5) * 0.18
    var width := 7.0 + float(index % 3) * 2.0
    var height := 3.0 + float(index % 4) * 1.2
    _add_box(ruin, "MurBrise", Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, 0.75), palette[0].darkened(0.18))
    _add_box(ruin, "RetourMur", Vector3(-width * 0.45, height * 0.38, 2.6), Vector3(0.75, height * 0.76, 5.5), palette[1])
    if index % 2 == 0:
        _add_cylinder(ruin, "LueurSouvenir", Vector3(width * 0.25, 1.4, 1.4), 0.22, 2.8, palette[2], 7, true)

func _spawn_port_market(center: Vector3, island_size: Vector2, palette: Array) -> void:
    if _current_island == 11:
        return
    for i in range(4):
        var side := -1.0 if i % 2 == 0 else 1.0
        var row := i / 2
        var base := _snap_to_ground(center + Vector3(side * (22.0 + row * 8.0), 80.0, island_size.y * (0.305 - row * 0.025)))
        var stall := StaticBody3D.new()
        stall.name = "EchoppeDuQuai_%02d" % (i + 1)
        _settlement_root.add_child(stall)
        stall.global_position = base
        _add_box(stall, "Comptoir", Vector3(0.0, 1.15, 0.0), Vector3(4.8, 2.3, 2.8), palette[0].darkened(0.08))
        _add_box(stall, "Auvent", Vector3(0.0, 2.75, 0.0), Vector3(5.5, 0.32, 3.5), palette[2])
        for post_x in [-2.15, 2.15]:
            _add_box(stall, "Poteau", Vector3(post_x, 1.65, 1.15), Vector3(0.18, 3.3, 0.18), palette[1])

func _spawn_landmark(center: Vector3, island_size: Vector2, palette: Array) -> void:
    var base := _snap_to_ground(center + Vector3(0.0, 100.0, -island_size.y * 0.08))
    var landmark := StaticBody3D.new()
    landmark.name = "Monument_%02d" % _current_island
    _settlement_root.add_child(landmark)
    landmark.global_position = base
    if _current_island == 11:
        for i in range(5):
            _add_cylinder(landmark, "Obelisque_%d" % i, Vector3(-9.0 + i * 4.5, 4.0 + absf(2.0 - i), 0.0), 0.8, 8.0 + absf(2.0 - i) * 2.0, palette[1], 6, i == 2)
        return
    _add_box(landmark, "Socle", Vector3(0.0, 0.7, 0.0), Vector3(18.0, 1.4, 12.0), palette[1])
    match _current_island:
        1:
            for i in range(7):
                _add_cylinder(landmark, "GrandOrgue_%d" % i, Vector3(-6.0 + i * 2.0, 4.0 + (3 - abs(i - 3)) * 0.8, 0.0), 0.55, 6.5 + (3 - abs(i - 3)) * 1.6, palette[2], 10)
        2:
            _add_cylinder(landmark, "SucetteGeante", Vector3(0.0, 5.8, 0.0), 2.4, 10.0, palette[2], 14)
        3:
            _add_box(landmark, "HalleDuMarche", Vector3(0.0, 4.0, 0.0), Vector3(14.0, 6.6, 8.0), palette[0])
        4:
            _add_cylinder(landmark, "CristalMajeur", Vector3(0.0, 6.0, 0.0), 2.4, 11.0, palette[2], 6, true, 0.02)
        5:
            _add_box(landmark, "TourHeroique", Vector3(0.0, 7.0, 0.0), Vector3(8.0, 13.0, 8.0), palette[0])
        6:
            _add_cylinder(landmark, "Arena", Vector3(0.0, 1.3, 0.0), 7.0, 2.4, palette[2], 18)
        7:
            _add_cylinder(landmark, "MatDuPort", Vector3(0.0, 6.0, 0.0), 0.45, 11.0, Color("5a3825"), 10)
            _add_box(landmark, "Etendard", Vector3(2.4, 8.2, 0.0), Vector3(4.6, 2.6, 0.20), palette[2])
        8:
            _add_cylinder(landmark, "StatueDeGlace", Vector3(0.0, 5.2, 0.0), 2.0, 9.0, Color("c9efff"), 8, true, 0.03)
        9:
            _add_cylinder(landmark, "ForgeVolcanique", Vector3(0.0, 3.8, 0.0), 4.4, 6.3, palette[1], 10)
            _add_cylinder(landmark, "CoeurLave", Vector3(0.0, 6.6, 0.0), 1.3, 2.8, palette[2], 8, true)
        10:
            for i in range(3):
                _add_cylinder(landmark, "Totem_%d" % i, Vector3(-5.0 + i * 5.0, 4.0 + i, 0.0), 1.0, 7.0 + i * 2.0, palette[2], 7)

func _spawn_settlement_sign(center: Vector3, island_size: Vector2, palette: Array) -> void:
    var base := _snap_to_ground(center + Vector3(0.0, 80.0, island_size.y * 0.27))
    var sign_root := Node3D.new()
    sign_root.name = "PanneauVillage"
    _settlement_root.add_child(sign_root)
    sign_root.global_position = base
    _add_box(sign_root, "PoteauG", Vector3(-3.4, 1.8, 0.0), Vector3(0.30, 3.6, 0.30), palette[1])
    _add_box(sign_root, "PoteauD", Vector3(3.4, 1.8, 0.0), Vector3(0.30, 3.6, 0.30), palette[1])
    _add_box(sign_root, "Planche", Vector3(0.0, 3.1, 0.0), Vector3(7.3, 1.55, 0.38), palette[0])
    var label := Label3D.new()
    label.text = SETTLEMENT_NAMES[_current_island - 1].to_upper()
    label.position = Vector3(0.0, 3.1, 0.23)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.font_size = 30
    label.outline_size = 8
    label.modulate = palette[2]
    label.outline_modulate = Color(0.0, 0.0, 0.0, 0.92)
    sign_root.add_child(label)

func _snap_to_ground(world_position: Vector3) -> Vector3:
    if get_world_3d() == null:
        return world_position
    var ray_start := Vector3(world_position.x, 190.0, world_position.z)
    var query := PhysicsRayQueryParameters3D.create(ray_start, Vector3(world_position.x, -90.0, world_position.z), 1)
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.has("position"):
        return hit["position"]
    return world_position

func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, color: Color, emissive: bool = false) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = box_size
    visual.mesh = mesh
    visual.position = local_position
    visual.material_override = _material(color, emissive)
    parent.add_child(visual)

func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, color: Color, sides: int = 10, emissive: bool = false, top_ratio: float = 0.72) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = radius
    mesh.top_radius = radius * top_ratio
    mesh.height = height
    mesh.radial_segments = maxi(6, sides)
    visual.mesh = mesh
    visual.position = local_position
    visual.material_override = _material(color, emissive)
    parent.add_child(visual)

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var key := "%s_%s" % [color.to_html(true), str(emissive)]
    if _materials.has(key):
        return _materials[key]
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.84
    if emissive:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.35
    _materials[key] = material
    return material
