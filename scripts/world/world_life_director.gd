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
    _animate_citizens(delta)
    _animate_fauna(delta)
    _animate_crews(delta)

func _on_island_changed(island_id: int) -> void:
    var resolved := clampi(island_id, 1, WorldCatalog.island_count())
    if resolved == _current_island:
        return
    _current_island = resolved
    _rebuild_local_life()

func _rebuild_local_life() -> void:
    if _root == null:
        return
    for child in _root.get_children():
        child.queue_free()
    _citizens.clear()
    _fauna.clear()
    _crew_ships.clear()

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
        citizen.global_position = center + Vector3(
            sin(float(i) * 2.31) * island_size.x * 0.14,
            6.0,
            cos(float(i) * 1.77) * island_size.y * 0.13
        )
        citizen.set_meta("home", citizen.global_position)
        citizen.set_meta("phase", float(i) * 0.73)
        citizen.set_meta("radius", 8.0 + float(i % 4) * 4.5)
        var visual := _instantiate_asset(path)
        if visual != null:
            citizen.add_child(visual)
            _normalize_model(visual, 1.75 if i > 0 else 1.95)
        else:
            citizen.add_child(_humanoid_fallback(Color("536b78") if i > 0 else Color("b58a42")))
        _root.add_child(citizen)
        _citizens.append(citizen)

func _spawn_fauna(center: Vector3, island_size: Vector2) -> void:
    var count := clampi(active_fauna_budget, 0, 8)
    for i in range(count):
        var animal := Node3D.new()
        animal.name = "Faune_%02d" % i
        animal.global_position = center + Vector3(
            cos(float(i) * 1.91) * island_size.x * 0.22,
            4.5,
            sin(float(i) * 2.17) * island_size.y * 0.20
        )
        animal.set_meta("home", animal.global_position)
        animal.set_meta("phase", float(i) * 1.21)
        animal.set_meta("radius", 10.0 + float(i % 3) * 5.0)
        animal.add_child(_animal_fallback(i))
        _root.add_child(animal)
        _fauna.append(animal)

func _spawn_maritime_events(center: Vector3, island_size: Vector2) -> void:
    var wreck := _instantiate_asset(WRECK_MODEL)
    if wreck != null:
        wreck.name = "ÉpaveExplorable"
        wreck.global_position = center + Vector3(island_size.x * 0.36, -1.1, island_size.y * 0.58)
        wreck.rotation.y = 0.55
        _root.add_child(wreck)

    var treasure := _instantiate_asset(TREASURE_MODEL)
    if treasure != null:
        treasure.name = "TrésorFlottant"
        treasure.global_position = center + Vector3(-island_size.x * 0.42, -0.8, island_size.y * 0.56)
        treasure.scale *= Vector3.ONE * 1.15
        _root.add_child(treasure)

func _spawn_crews(center: Vector3, island_size: Vector2) -> void:
    var count := mini(active_crew_budget, CREWS.size())
    for i in range(count):
        var spec: Dictionary = CREWS[i]
        var ship_root := Node3D.new()
        ship_root.name = "ÉquipageLibre_%d" % (i + 1)
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

        _root.add_child(ship_root)
        _crew_ships.append(ship_root)

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

func _animate_crews(_delta: float) -> void:
    for i in range(_crew_ships.size()):
        var ship := _crew_ships[i]
        if not is_instance_valid(ship):
            continue
        var center: Vector3 = ship.get_meta("center", ship.global_position)
        var radius := float(ship.get_meta("radius", 900.0))
        var phase := float(ship.get_meta("phase", 0.0))
        var speed := 0.018 + float(i) * 0.004
        var angle := _time * speed + phase
        var target := center + Vector3(cos(angle) * radius, -0.62, sin(angle) * radius)
        var direction := target - ship.global_position
        direction.y = 0.0
        ship.global_position = ship.global_position.lerp(target, minf(1.0, get_process_delta_time() * 0.8))
        if direction.length_squared() > 0.01:
            ship.rotation.y = lerp_angle(ship.rotation.y, atan2(-direction.x, -direction.z), 0.05)
        ship.position.y += sin(_time * 1.7 + float(i)) * 0.0015

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
