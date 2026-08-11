class_name IslandVehicleDirector
extends Node3D

const IslandVehicleScript = preload("res://scripts/player/island_vehicle.gd")

const VEHICLES := [
    [
        {"name": "Orgue roulant", "style": "organ", "main_color": Color("385d54"), "accent_color": Color("e6bf55"), "maximum_speed": 14.5},
        {"name": "Tempo-kart", "style": "organ", "main_color": Color("4e3566"), "accent_color": Color("73d5dc"), "maximum_speed": 17.0}
    ],
    [
        {"name": "Bonbon-mobile", "style": "candy", "main_color": Color("e68ab5"), "accent_color": Color("fff0a8"), "maximum_speed": 15.0},
        {"name": "Chariot caramel", "style": "candy", "main_color": Color("a85d46"), "accent_color": Color("ffb6d9"), "maximum_speed": 13.8}
    ],
    [
        {"name": "Chariot du marché", "style": "market", "main_color": Color("7f4e2f"), "accent_color": Color("e0b45a"), "maximum_speed": 13.5},
        {"name": "Marmite express", "style": "market", "main_color": Color("586b3d"), "accent_color": Color("e98e45"), "maximum_speed": 15.5}
    ],
    [
        {"name": "Rôdeur de cristal", "style": "crystal", "main_color": Color("314758"), "accent_color": Color("79ddff"), "maximum_speed": 16.0},
        {"name": "Carrosse runique", "style": "crystal", "main_color": Color("533d69"), "accent_color": Color("b99cff"), "maximum_speed": 14.2}
    ],
    [
        {"name": "Patrouilleur urbain", "style": "urban", "main_color": Color("343a45"), "accent_color": Color("ef5a50"), "maximum_speed": 18.0},
        {"name": "Moto-bloc héroïque", "style": "urban", "main_color": Color("405c75"), "accent_color": Color("66d2ff"), "maximum_speed": 19.0}
    ],
    [
        {"name": "Buggy d'entraînement", "style": "training", "main_color": Color("466443"), "accent_color": Color("f1d94c"), "maximum_speed": 16.8},
        {"name": "Transport des dresseurs", "style": "training", "main_color": Color("8b5340"), "accent_color": Color("d8e66c"), "maximum_speed": 14.8}
    ],
    [
        {"name": "Chariot corsaire", "style": "pirate", "main_color": Color("5e3c29"), "accent_color": Color("d6a84a"), "maximum_speed": 15.2},
        {"name": "Canon roulant", "style": "pirate", "main_color": Color("292c31"), "accent_color": Color("c98242"), "maximum_speed": 14.5}
    ],
    [
        {"name": "Traîneau royal", "style": "sled", "main_color": Color("bcd9e8"), "accent_color": Color("63a8d1"), "maximum_speed": 17.4},
        {"name": "Glisseur polaire", "style": "sled", "main_color": Color("e8f3f7"), "accent_color": Color("77cde8"), "maximum_speed": 18.3}
    ],
    [
        {"name": "Rôdeur de lave", "style": "lava", "main_color": Color("342827"), "accent_color": Color("ff5a2d"), "maximum_speed": 16.0},
        {"name": "Braise mécanique", "style": "lava", "main_color": Color("512f27"), "accent_color": Color("ffb33c"), "maximum_speed": 17.2}
    ],
    [
        {"name": "Crapahuteur tellurique", "style": "crawler", "main_color": Color("554c37"), "accent_color": Color("9fbd68"), "maximum_speed": 14.8},
        {"name": "Transport des bâtisseurs", "style": "crawler", "main_color": Color("6e6045"), "accent_color": Color("d0aa61"), "maximum_speed": 13.7}
    ],
    [
        {"name": "Carrosse spectral", "style": "spectral", "main_color": Color("292337"), "accent_color": Color("c08cff"), "maximum_speed": 17.0},
        {"name": "Rôdeur des cauchemars", "style": "spectral", "main_color": Color("3f2b3d"), "accent_color": Color("e2b956"), "maximum_speed": 18.0}
    ]
]

const VEHICLE_SLOTS := [
    Vector2(-18.0, 0.325), Vector2(18.0, 0.325),
    Vector2(-34.0, 0.282), Vector2(34.0, 0.282),
    Vector2(0.0, 0.245)
]

var _vehicle_root: Node3D
var _current_island := -1
var _rebuild_serial := 0

func _ready() -> void:
    add_to_group("island_vehicle_director")
    _vehicle_root = Node3D.new()
    _vehicle_root.name = "VehiculesDesRoyaumes"
    add_child(_vehicle_root)
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
    # Le relief et sa collision sont créés par l'archipel dans la même frame.
    # Deux frames physiques garantissent que les rayons posent les roues au sol.
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial == _rebuild_serial:
        _rebuild_vehicles()

func _rebuild_vehicles() -> void:
    if _vehicle_root == null:
        return
    for child in _vehicle_root.get_children():
        child.queue_free()

    var info := WorldCatalog.island(_current_island - 1)
    var center: Vector3 = WorldCatalog.world_positions()[_current_island - 1]
    var island_size: Vector2 = info["size"]
    var base_specs: Array = VEHICLES[_current_island - 1]
    var specs: Array = base_specs.duplicate(true)
    specs.append_array(_mobility_specs(_current_island))

    for i in range(specs.size()):
        var vehicle := IslandVehicleScript.new() as IslandVehicle
        vehicle.name = "Vehicule_%02d_%02d" % [_current_island, i + 1]
        vehicle.configure(specs[i])
        _vehicle_root.add_child(vehicle)

        var slot: Vector2 = VEHICLE_SLOTS[mini(i, VEHICLE_SLOTS.size() - 1)]
        # Le garage du quai garde les cinq moyens de transport assez espacés pour
        # qu'un véhicule fraîchement conduit ne puisse pas apparaître dans un autre.
        var candidate := center + Vector3(slot.x, 70.0, island_size.y * slot.y)
        vehicle.global_position = _snap_to_ground(candidate) + Vector3.UP * 0.18
        vehicle.rotation.y = PI + clampf(slot.x / 180.0, -0.20, 0.20)

func _mobility_specs(island_id: int) -> Array:
    var island_specs: Array = VEHICLES[island_id - 1]
    var reference: Dictionary = island_specs[0]
    var main: Color = reference.get("main_color", Color("4d5b47"))
    var accent: Color = reference.get("accent_color", Color("e0b44f"))
    return [
        {
            "name": "Quad d'exploration",
            "style": "quad",
            "main_color": main.lightened(0.06),
            "accent_color": accent,
            "maximum_speed": 21.0,
            "reverse_speed": 7.0,
            "acceleration": 15.0,
            "turn_speed": 2.20
        },
        {
            "name": "4x4 d'expédition",
            "style": "4x4",
            "main_color": main.darkened(0.04),
            "accent_color": accent.lightened(0.06),
            "maximum_speed": 18.5,
            "reverse_speed": 6.2,
            "acceleration": 11.5,
            "turn_speed": 1.48
        },
        {
            "name": "Cheval du royaume",
            "style": "horse",
            "main_color": Color("7a5135").lerp(main, 0.18),
            "accent_color": accent,
            "maximum_speed": 13.2,
            "reverse_speed": 3.6,
            "acceleration": 10.5,
            "turn_speed": 2.35
        }
    ]

func _snap_to_ground(world_position: Vector3) -> Vector3:
    if get_world_3d() == null:
        return world_position
    var ray_start := Vector3(world_position.x, 180.0, world_position.z)
    var query := PhysicsRayQueryParameters3D.create(ray_start, Vector3(world_position.x, -90.0, world_position.z), 1)
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.has("position"):
        return hit["position"]
    return world_position