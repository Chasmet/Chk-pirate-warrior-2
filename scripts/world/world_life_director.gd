class_name WorldLifeDirector
extends Node3D

const CIVILIAN_MODEL := "res://assets/vrac/Adventurer by Quaternius - 5EGWBMpuXq.glb"
const MERCHANT_MODEL := "res://assets/vrac/King by Quaternius - I1gTjmuK2m.glb"
const TREASURE_MODEL := "res://assets/decors_glb/glb/coffre_pirate.glb"
const WRECK_MODEL := "res://assets/bateaux_glb/glb/epave_navire.glb"

const CREWS := [
    {
        "id": "equipage_1",
        "name": "Équipage du Chapeau de Paille",
        "captain": "res://assets/equipages_libres/equipage_ami_ou_ennemi_01/Luffy capitaine équipage chapeau de paille.glb",
        "ship": "res://assets/bateaux_glb/glb/navire_pirate_clair.glb"
    },
    {
        "id": "equipage_2",
        "name": "Équipage Roux",
        "captain": "res://assets/equipages_libres/equipage_ami_ou_ennemi_02/shamks capitaine équipage libre 1 .glb",
        "ship": "res://assets/bateaux_glb/glb/navire_pirate_sombre.glb"
    },
    {
        "id": "equipage_3",
        "name": "Équipage des Horizons",
        "captain": CIVILIAN_MODEL,
        "ship": "res://assets/bateaux_glb/glb/barque_grande.glb"
    }
]

@export var active_citizen_budget := 10
@export var active_fauna_budget := 6
@export var active_crew_budget := 3

var _root: Node3D
var _citizens: Array[Node3D] = []
var _fauna: Array[Node3D] = []
var _crew_ships: Array[Node3D] = []
var _current_island := -1
var _time := 0.0
var _player: Node3D
var _merchant: Node3D
var _treasure: Node3D
var _wreck: Node3D
var _pickup_scan := 0.0
var _crew_attack_cooldowns: Dictionary = {}
var _crew_relations_ready := false
var _rebuild_serial := 0

func _ready() -> void:
    add_to_group("world_life")
    _root = Node3D.new()
    _root.name = "MondeVivantMobile"
    add_child(_root)
    _player = get_tree().get_first_node_in_group("player") as Node3D
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _process(delta: float) -> void:
    _time += delta
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D
    if not _crew_relations_ready:
        _initialize_crew_relations()
    if Input.is_action_just_pressed("interact"):
        _try_merchant_interaction()
    _animate_citizens(delta)
    _animate_fauna(delta)
    _animate_crews(delta)
    _update_crew_attack_cooldowns(delta)
    _pickup_scan += delta
    if _pickup_scan >= 0.20:
        _pickup_scan = 0.0
        _update_maritime_pickups()

func _initialize_crew_relations() -> void:
    if bool(GameState.get_quest_value("crew_relations_initialized", false)):
        _crew_relations_ready = true
        return
    var all_neutral := true
    for spec in CREWS:
        if int(GameState.crew_reputation.get(str(spec["id"]), 0)) != 0:
            all_neutral = false
            break
    if all_neutral:
        GameState.adjust_crew_reputation("equipage_1", 40)
        GameState.adjust_crew_reputation("equipage_3", -40)
    GameState.set_quest_value("crew_relations_initialized", true)
    GameState.quick_save()
    _crew_relations_ready = true

func _on_island_changed(island_id: int) -> void:
    var resolved := clampi(island_id, 1, WorldCatalog.island_count())
    if resolved == _current_island:
        return
    _current_island = resolved
    _rebuild_serial += 1
    _deferred_rebuild.call_deferred(_rebuild_serial)

func _deferred_rebuild(serial: int) -> void:
    await get_tree().physics_frame
    if serial != _rebuild_serial:
        return
    _rebuild_local_life()

func _rebuild_local_life() -> void:
    if _root == null:
        return
    for child in _root.get_children():
        child.queue_free()
    _citizens.clear()
    _fauna.clear()
    _crew_ships.clear()
    _crew_attack_cooldowns.clear()
    _merchant = null
    _treasure = null
    _wreck = null

    if _current_island == 11:
        return

    var center := _island_center(_current_island)
    var info := WorldCatalog.island(_current_island - 1)
    var island_size: Vector2 = info["size"]
    _spawn_citizens(center, island_size)
    _spawn_fauna(center, island_size)
    _spawn_maritime_events(center, island_size)
    _spawn_crews(center, island_size)

func _spawn_citizens(center: Vector3, island_size: Vector2) -> void:
    var count := clampi(active_citizen_budget, 0, 14)
    for i in range(count):
        var path := MERCHANT_MODEL if i == 0 else CIVILIAN_MODEL
        var citizen := Node3D.new()
        citizen.name = "Marchand" if i == 0 else "Habitant_%02d" % i
        _root.add_child(citizen)
        var candidate := center + Vector3(
            sin(float(i) * 2.31) * island_size.x * 0.14,
            6.0,
            cos(float(i) * 1.77) * island_size.y * 0.13
        )
        citizen.global_position = _snap_to_ground(candidate, 0.08)
        citizen.set_meta("home", citizen.global_position)
        citizen.set_meta("phase", float(i) * 0.73)
        citizen.set_meta("radius", 8.0 + float(i % 4) * 4.5)
        var visual := _instantiate_asset(path)
        if visual != null:
            citizen.add_child(visual)
            _normalize_model(visual, 1.75 if i > 0 else 1.95)
        else:
            citizen.add_child(_humanoid_fallback(Color("536b78") if i > 0 else Color("b58a42")))
        _citizens.append(citizen)
        if i == 0:
            _merchant = citizen

func _spawn_fauna(center: Vector3, island_size: Vector2) -> void:
    var count := clampi(active_fauna_budget, 0, 8)
    for i in range(count):
        var animal := Node3D.new()
        animal.name = "Faune_%02d" % i
        _root.add_child(animal)
        var candidate := center + Vector3(
            cos(float(i) * 1.91) * island_size.x * 0.22,
            4.5,
            sin(float(i) * 2.17) * island_size.y * 0.20
        )
        animal.global_position = _snap_to_ground(candidate, 0.05)
        animal.set_meta("home", animal.global_position)
        animal.set_meta("phase", float(i) * 1.21)
        animal.set_meta("radius", 10.0 + float(i % 3) * 5.0)
        animal.add_child(_animal_fallback(i))
        _fauna.append(animal)

func _spawn_maritime_events(center: Vector3, island_size: Vector2) -> void:
    var wreck_key := "wreck_salvaged_%02d" % _current_island
    if not bool(GameState.get_quest_value(wreck_key, false)):
        var wreck := _instantiate_asset(WRECK_MODEL)
        if wreck != null:
            wreck.name = "ÉpaveExplorable"
            _root.add_child(wreck)
            wreck.global_position = center + Vector3(island_size.x * 0.36, -1.1, island_size.y * 0.58)
            wreck.rotation.y = 0.55
            _wreck = wreck

    var treasure_key := "floating_treasure_%02d" % _current_island
    if not bool(GameState.get_quest_value(treasure_key, false)):
        var treasure := _instantiate_asset(TREASURE_MODEL)
        if treasure != null:
            treasure.name = "TrésorFlottant"
            _root.add_child(treasure)
            treasure.global_position = center + Vector3(-island_size.x * 0.42, -0.8, island_size.y * 0.56)
            treasure.scale *= Vector3.ONE * 1.15
            _treasure = treasure

func _spawn_crews(center: Vector3, island_size: Vector2) -> void:
    var count := mini(active_crew_budget, CREWS.size())
    for i in range(count):
        var spec: Dictionary = CREWS[i]
        var ship_root := Node3D.new()
        ship_root.name = "ÉquipageLibre_%d" % (i + 1)
        _root.add_child(ship_root)
        var radius := maxf(island_size.x, island_size.y) * (0.63 + float(i) * 0.08)
        var angle := float(i) * TAU / 3.0 + 0.45
        ship_root.global_position = center + Vector3(cos(angle) * radius, -0.62, sin(angle) * radius)
        ship_root.set_meta("crew_id", str(spec["id"]))
        ship_root.set_meta("crew_name", str(spec["name"]))
        ship_root.set_meta("center", center)
        ship_root.set_meta("radius", radius)
        ship_root.set_meta("phase", angle)

        var ship := _instantiate_asset(str(spec["ship"]))
        if ship != null:
            ship.name = "Navire"
            ship_root.add_child(ship)
            _normalize_model(ship, 11.0 if i < 2 else 6.0)

        var captain := _instantiate_asset(str(spec["captain"]))
        if captain != null:
            captain.name = "Capitaine"
            ship_root.add_child(captain)
            _normalize_model(captain, 1.85)
            captain.position = Vector3(0.0, 2.1, 0.4)

        _crew_ships.append(ship_root)
        _crew_attack_cooldowns[str(spec["id"])] = 0.0

func _try_merchant_interaction() -> bool:
    if _merchant == null or not is_instance_valid(_merchant) or _player == null or not is_instance_valid(_player):
        return false
    if _player.global_position.distance_to(_merchant.global_position) > 4.5:
        return false
    if GameState.boat_level >= 5:
        _notify("MARCHAND • Ton navire est déjà au niveau maximum 5.")
        return true
    var cost := 450 * GameState.boat_level
    if GameState.coins < cost:
        _notify("MARCHAND • Amélioration niveau %d : %d pièces nécessaires." % [GameState.boat_level + 1, cost])
        return true
    if GameState.upgrade_boat():
        _notify("NAVIRE AMÉLIORÉ • niveau %d/5 • vitesse et accélération augmentées" % GameState.boat_level)
        return true
    return false

func _animate_citizens(_delta: float) -> void:
    for i in range(_citizens.size()):
        var citizen := _citizens[i]
        if not is_instance_valid(citizen):
            continue
        var home: Vector3 = citizen.get_meta("home", citizen.global_position)
        var phase := float(citizen.get_meta("phase", 0.0))
        var radius := float(citizen.get_meta("radius", 10.0))
        var angle := _time * (0.08 + float(i % 3) * 0.018) + phase
        var target := home + Vector3(cos(angle) * radius, 0.0, sin(angle * 0.83) * radius)
        var direction := target - citizen.global_position
        direction.y = 0.0
        if direction.length_squared() > 0.05:
            citizen.global_position += direction.normalized() * minf(direction.length(), 1.4 * get_process_delta_time())
            citizen.rotation.y = lerp_angle(citizen.rotation.y, atan2(-direction.x, -direction.z), 0.08)

func _animate_fauna(_delta: float) -> void:
    for i in range(_fauna.size()):
        var animal := _fauna[i]
        if not is_instance_valid(animal):
            continue
        var home: Vector3 = animal.get_meta("home", animal.global_position)
        var phase := float(animal.get_meta("phase", 0.0))
        var radius := float(animal.get_meta("radius", 12.0))
        var angle := _time * (0.14 + float(i % 2) * 0.04) + phase
        var target := home + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        var direction := target - animal.global_position
        direction.y = 0.0
        if direction.length_squared() > 0.05:
            animal.global_position += direction.normalized() * minf(direction.length(), 1.8 * get_process_delta_time())
            animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-direction.x, -direction.z), 0.10)

func _animate_crews(delta: float) -> void:
    var active_boat: Node = get_tree().get_first_node_in_group("active_controller")
    var player_is_sailing: bool = active_boat is BoatController and (active_boat as BoatController).is_boarded()
    for i in range(_crew_ships.size()):
        var ship := _crew_ships[i]
        if not is_instance_valid(ship):
            continue
        var crew_id := str(ship.get_meta("crew_id", ""))
        var relation := GameState.crew_relation(crew_id)
        var center: Vector3 = ship.get_meta("center", ship.global_position)
        var radius := float(ship.get_meta("radius", 900.0))
        var phase := float(ship.get_meta("phase", 0.0))
        var target := center
        var movement_speed := 7.0

        if player_is_sailing and _player != null and is_instance_valid(_player):
            var distance_to_player := ship.global_position.distance_to(_player.global_position)
            if relation == "hostile" and distance_to_player <= 520.0:
                target = _player.global_position
                target.y = -0.62
                movement_speed = 10.5
                if distance_to_player <= 32.0 and float(_crew_attack_cooldowns.get(crew_id, 0.0)) <= 0.0:
                    _crew_attack_cooldowns[crew_id] = 2.4
                    if _player.has_method("receive_damage"):
                        _player.receive_damage(7.0 + float(_current_island) * 0.65)
                    _notify("CANON ENNEMI • %s attaque ton navire" % str(ship.get_meta("crew_name", "Équipage hostile")))
            elif relation == "allie" and distance_to_player <= 360.0:
                var escort_offset := Vector3(28.0 + float(i) * 8.0, 0.0, 22.0)
                if active_boat is Node3D:
                    escort_offset = (active_boat as Node3D).global_transform.basis * escort_offset
                target = _player.global_position + escort_offset
                target.y = -0.62
                movement_speed = 8.5
            else:
                var angle := _time * (0.018 + float(i) * 0.004) + phase
                target = center + Vector3(cos(angle) * radius, -0.62, sin(angle) * radius)
        else:
            var angle := _time * (0.018 + float(i) * 0.004) + phase
            target = center + Vector3(cos(angle) * radius, -0.62, sin(angle) * radius)

        var direction := target - ship.global_position
        direction.y = 0.0
        if direction.length_squared() > 0.05:
            var step := minf(direction.length(), movement_speed * delta)
            ship.global_position += direction.normalized() * step
            ship.global_position.y = -0.62 + sin(_time * 1.7 + float(i)) * 0.06
            ship.rotation.y = lerp_angle(ship.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 2.8))

func _update_crew_attack_cooldowns(delta: float) -> void:
    for key in _crew_attack_cooldowns.keys():
        _crew_attack_cooldowns[key] = maxf(0.0, float(_crew_attack_cooldowns[key]) - delta)

func _update_maritime_pickups() -> void:
    if _current_island == 11 or _player == null or not is_instance_valid(_player):
        return
    if _treasure != null and is_instance_valid(_treasure) and _player.global_position.distance_to(_treasure.global_position) <= 5.5:
        var treasure_key := "floating_treasure_%02d" % _current_island
        GameState.set_quest_value(treasure_key, true)
        GameState.add_coins(110 + _current_island * 20)
        GameState.add_xp(90 + _current_island * 12)
        GameState.add_item("coffre", 1)
        GameState.quick_save()
        _treasure.queue_free()
        _treasure = null
        _notify("TRÉSOR TROUVÉ • coffre + pièces + XP")

    if _wreck != null and is_instance_valid(_wreck) and _player.global_position.distance_to(_wreck.global_position) <= 7.0:
        var wreck_key := "wreck_salvaged_%02d" % _current_island
        GameState.set_quest_value(wreck_key, true)
        GameState.add_coins(55 + _current_island * 12)
        GameState.add_xp(60 + _current_island * 9)
        GameState.add_item("materiau_bateau", 2)
        GameState.quick_save()
        _wreck.queue_free()
        _wreck = null
        _notify("ÉPAVE FOUILLÉE • matériaux de bateau récupérés")

func _snap_to_ground(world_position: Vector3, offset: float) -> Vector3:
    if get_world_3d() == null:
        return world_position
    var from := Vector3(world_position.x, 140.0, world_position.z)
    var to := Vector3(world_position.x, -80.0, world_position.z)
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.has("position"):
        var result: Vector3 = hit["position"]
        result.y += offset
        return result
    return world_position

func _notify(text: String) -> void:
    var world := get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("_notify"):
        world.call("_notify", text)

func _island_center(island_id: int) -> Vector3:
    var positions := WorldCatalog.world_positions()
    if positions.is_empty():
        return Vector3.ZERO
    return positions[clampi(island_id - 1, 0, positions.size() - 1)]

func _instantiate_asset(path: String) -> Node3D:
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if resource is PackedScene:
        var node: Node = (resource as PackedScene).instantiate()
        if node is Node3D:
            return node as Node3D
        node.queue_free()
    return null

func _normalize_model(root: Node3D, target_height: float) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return
    var min_y := INF
    var max_y := -INF
    var inverse := root.global_transform.affine_inverse()
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var box := mesh_instance.get_aabb()
        var transform := inverse * mesh_instance.global_transform
        for endpoint in range(8):
            var point: Vector3 = transform * box.get_endpoint(endpoint)
            min_y = minf(min_y, point.y)
            max_y = maxf(max_y, point.y)
    var height := max_y - min_y
    if height <= 0.01:
        return
    var factor := clampf(target_height / height, 0.015, 24.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= min_y * factor

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _humanoid_fallback(color: Color) -> Node3D:
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.28
    capsule.height = 1.25
    body.mesh = capsule
    body.position.y = 0.78
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    body.material_override = material
    root.add_child(body)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    head.mesh = sphere
    head.position.y = 1.55
    head.material_override = material
    root.add_child(head)
    return root

func _animal_fallback(index: int) -> Node3D:
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.22 + float(index % 3) * 0.05
    capsule.height = 0.72 + float(index % 2) * 0.18
    body.mesh = capsule
    body.rotation.z = PI * 0.5
    body.position.y = 0.45
    var material := StandardMaterial3D.new()
    material.albedo_color = [Color("795548"), Color("736357"), Color("9a7b4f")][index % 3]
    body.material_override = material
    root.add_child(body)
    return root
