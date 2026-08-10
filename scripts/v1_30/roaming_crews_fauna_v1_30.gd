class_name RoamingCrewsFaunaV130
extends Node3D

# Équipages libres à terre + vraie faune GLB. Cette couche complète WorldLifeDirector :
# les navires libres restent en mer, tandis qu'une escouade de chaque équipage peut
# désormais être rencontrée en exploration sur les royaumes 1 à 10.
const CREW_CAPTAINS := [
    {
        "name": "Équipage du Chapeau de Paille",
        "captain": "res://assets/equipages_libres/equipage_ami_ou_ennemi_01/Luffy capitaine équipage chapeau de paille.glb",
        "color": Color("d8b344")
    },
    {
        "name": "Équipage Roux",
        "captain": "res://assets/equipages_libres/equipage_ami_ou_ennemi_02/shamks capitaine équipage libre 1 .glb",
        "color": Color("a6413e")
    }
]

const CREW_MEMBER_MODELS := [
    "res://assets/vrac/Adventurer by Quaternius - 5EGWBMpuXq.glb",
    "res://assets/vrac/solad 1 anime.glb",
    "res://assets/vrac/solad 2 anime .glb",
    "res://assets/vrac/guerrier_solitaire_anime_compresse.glb"
]

const PARROT_MODEL := "res://assets/vrac/Perroquet.glb"
const FOX_MODEL := "res://assets/vrac/Renard_anime.glb"

@export var shore_party_count := 2
@export var land_animal_count := 4
@export var flying_animal_count := 4

var _root: Node3D
var _crew_walkers: Array[Node3D] = []
var _land_animals: Array[Node3D] = []
var _flying_animals: Array[Node3D] = []
var _world: Node
var _island_info: Dictionary = {}
var _current_island := -1
var _serial := 0
var _time := 0.0

func _ready() -> void:
    add_to_group("roaming_crews_fauna_v1_30")
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _process(delta: float) -> void:
    _time += delta
    _animate_crew_walkers(delta)
    _animate_land_animals(delta)
    _animate_flying_animals(delta)

func _on_island_changed(island_id: int) -> void:
    _current_island = clampi(island_id, 1, WorldCatalog.island_count())
    _serial += 1
    _rebuild.call_deferred(_current_island, _serial)

func _rebuild(island_id: int, serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial:
        return
    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _crew_walkers.clear()
    _land_animals.clear()
    _flying_animals.clear()
    if island_id == 11:
        return

    _world = get_tree().get_first_node_in_group("world_director")
    _island_info = WorldCatalog.island(island_id - 1)
    _root = Node3D.new()
    _root.name = "EquipagesEtFauneV130_%02d" % island_id
    _root.global_position = WorldCatalog.world_positions()[island_id - 1]
    add_child(_root)

    _spawn_shore_parties(island_id)
    _spawn_real_fauna(island_id)

func _spawn_shore_parties(island_id: int) -> void:
    var size: Vector2 = _island_info["size"]
    var count := clampi(shore_party_count, 0, CREW_CAPTAINS.size())
    for party_index in range(count):
        var spec: Dictionary = CREW_CAPTAINS[(party_index + island_id - 1) % CREW_CAPTAINS.size()]
        var side := -1.0 if party_index == 0 else 1.0
        var home_x := side * size.x * 0.18
        var home_z := size.y * (0.08 - float(party_index) * 0.12)
        var party := Node3D.new()
        party.name = "EscouadeLibre_%02d" % (party_index + 1)
        party.position = _ground_local(Vector3(home_x, 0.0, home_z))
        _root.add_child(party)

        var captain := _spawn_walker(
            party,
            "Capitaine",
            str(spec["captain"]),
            Vector3.ZERO,
            1.88,
            str(spec["name"]),
            spec["color"],
            7.5 + float(party_index) * 2.0,
            0.65 + float(party_index) * 0.08
        )
        if captain != null:
            captain.set_meta("party_origin", party.position)

        for member_index in range(3):
            var member_path := str(CREW_MEMBER_MODELS[(member_index + party_index + island_id) % CREW_MEMBER_MODELS.size()])
            var offset := Vector3(-3.2 + float(member_index) * 3.2, 0.0, 2.0 + float(member_index % 2) * 2.1)
            var walker := _spawn_walker(
                party,
                "Matelot_%02d" % (member_index + 1),
                member_path,
                offset,
                1.72,
                "MATELOT • %s" % str(spec["name"]),
                Color("d8e1e5"),
                5.0 + float(member_index),
                0.72 + float(member_index) * 0.05
            )
            if walker != null:
                walker.set_meta("party_origin", party.position)

func _spawn_walker(parent: Node3D, node_name: String, model_path: String, offset: Vector3, target_height: float, label_text: String, label_color: Color, radius: float, speed: float) -> Node3D:
    var walker := Node3D.new()
    walker.name = node_name
    walker.position = offset
    walker.set_meta("home", offset)
    walker.set_meta("phase", float(_crew_walkers.size()) * 0.83)
    walker.set_meta("radius", radius)
    walker.set_meta("speed", speed)
    parent.add_child(walker)

    var visual := _instantiate_asset(model_path)
    if visual != null:
        walker.add_child(visual)
        _normalize_model(visual, target_height)
    else:
        walker.add_child(_fallback_humanoid(label_color))

    var label := Label3D.new()
    label.name = "Role"
    label.text = label_text
    label.position = Vector3(0.0, 2.35, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.font_size = 22
    label.outline_size = 7
    label.modulate = label_color
    label.outline_modulate = Color(0, 0, 0, 0.93)
    walker.add_child(label)
    _crew_walkers.append(walker)
    return walker

func _spawn_real_fauna(island_id: int) -> void:
    var size: Vector2 = _island_info["size"]

    for i in range(clampi(land_animal_count, 0, 7)):
        var angle := TAU * float(i) / float(maxi(1, land_animal_count)) + float(island_id) * 0.41
        var radius := minf(size.x, size.y) * (0.16 + float(i % 2) * 0.055)
        var local := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius - size.y * 0.03)
        local = _ground_local(local)
        var animal := Node3D.new()
        animal.name = "RenardLibre_%02d" % i
        animal.position = local
        animal.set_meta("home", local)
        animal.set_meta("phase", float(i) * 1.13)
        animal.set_meta("radius", 7.0 + float(i % 3) * 2.5)
        animal.set_meta("speed", 0.82 + float(i % 2) * 0.18)
        _root.add_child(animal)
        var visual := _instantiate_asset(FOX_MODEL)
        if visual != null:
            animal.add_child(visual)
            _normalize_model(visual, 0.82)
        else:
            animal.add_child(_fallback_animal(Color("b66d42"), false))
        _land_animals.append(animal)

    for i in range(clampi(flying_animal_count, 0, 7)):
        var angle := TAU * float(i) / float(maxi(1, flying_animal_count)) + 0.8
        var radius := minf(size.x, size.y) * (0.11 + float(i % 2) * 0.04)
        var local := Vector3(cos(angle) * radius, 10.0 + float(i % 3) * 2.0, sin(angle) * radius)
        var bird := Node3D.new()
        bird.name = "PerroquetLibre_%02d" % i
        bird.position = local
        bird.set_meta("center", Vector3(0.0, 8.5 + float(i % 3) * 2.0, 0.0))
        bird.set_meta("phase", angle)
        bird.set_meta("radius", radius)
        bird.set_meta("speed", 0.25 + float(i % 3) * 0.035)
        _root.add_child(bird)
        var visual := _instantiate_asset(PARROT_MODEL)
        if visual != null:
            bird.add_child(visual)
            _normalize_model(visual, 0.62)
        else:
            bird.add_child(_fallback_animal(Color("4fbf79"), true))
        _flying_animals.append(bird)

func _animate_crew_walkers(delta: float) -> void:
    for index in range(_crew_walkers.size()):
        var walker := _crew_walkers[index]
        if walker == null or not is_instance_valid(walker):
            continue
        var home: Vector3 = walker.get_meta("home", walker.position)
        var phase := float(walker.get_meta("phase", 0.0))
        var radius := float(walker.get_meta("radius", 6.0))
        var speed := float(walker.get_meta("speed", 0.7))
        var angle := _time * 0.13 * speed + phase
        var desired := home + Vector3(cos(angle) * radius, 0.0, sin(angle * 0.84) * radius)
        desired = _ground_local_from_parent(walker.get_parent() as Node3D, desired)
        _move_node_toward(walker, desired, speed * 2.1, delta)

func _animate_land_animals(delta: float) -> void:
    for index in range(_land_animals.size()):
        var animal := _land_animals[index]
        if animal == null or not is_instance_valid(animal):
            continue
        var home: Vector3 = animal.get_meta("home", animal.position)
        var phase := float(animal.get_meta("phase", 0.0))
        var radius := float(animal.get_meta("radius", 8.0))
        var speed := float(animal.get_meta("speed", 0.9))
        var angle := _time * 0.19 * speed + phase
        var desired := home + Vector3(cos(angle) * radius, 0.0, sin(angle * 0.91) * radius)
        desired = _ground_local(desired)
        _move_node_toward(animal, desired, speed * 2.2, delta)

func _animate_flying_animals(_delta: float) -> void:
    for bird in _flying_animals:
        if bird == null or not is_instance_valid(bird):
            continue
        var center: Vector3 = bird.get_meta("center", Vector3(0, 10, 0))
        var phase := float(bird.get_meta("phase", 0.0))
        var radius := float(bird.get_meta("radius", 30.0))
        var speed := float(bird.get_meta("speed", 0.28))
        var angle := _time * speed + phase
        var new_position := center + Vector3(cos(angle) * radius, sin(_time * 1.5 + phase) * 1.7, sin(angle) * radius)
        var direction := new_position - bird.position
        bird.position = new_position
        if direction.length_squared() > 0.001:
            bird.rotation.y = atan2(-direction.x, -direction.z)

func _move_node_toward(node: Node3D, target: Vector3, speed: float, delta: float) -> void:
    var direction := target - node.position
    direction.y = 0.0
    if direction.length_squared() <= 0.02:
        node.position.y = target.y
        return
    node.position += direction.normalized() * minf(direction.length(), speed * delta)
    node.position.y = lerpf(node.position.y, target.y, minf(1.0, delta * 6.0))
    node.rotation.y = lerp_angle(node.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 6.5))

func _ground_local(local: Vector3) -> Vector3:
    local.y = _ground_y(local.x, local.z) + 0.08
    return local

func _ground_local_from_parent(parent: Node3D, parent_local: Vector3) -> Vector3:
    if parent == null:
        return _ground_local(parent_local)
    var root_local := parent.position + parent_local
    root_local.y = _ground_y(root_local.x, root_local.z) + 0.08
    return root_local - parent.position

func _ground_y(x: float, z: float) -> float:
    if _world == null or not is_instance_valid(_world):
        _world = get_tree().get_first_node_in_group("world_director")
    if _world != null and _world.has_method("_terrain_height_at"):
        var result = _world.call("_terrain_height_at", _island_info, x, z)
        if result != null:
            return float(result)
    return 0.0

func _instantiate_asset(path: String) -> Node3D:
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var resource := load(path)
    if resource is PackedScene:
        var instance := (resource as PackedScene).instantiate()
        if instance is Node3D:
            return instance as Node3D
        instance.queue_free()
    return null

func _normalize_model(root: Node3D, target_height: float) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    if meshes.is_empty():
        return
    var inverse := root.global_transform.affine_inverse()
    var min_y := INF
    var max_y := -INF
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var box := mesh_instance.get_aabb()
        var transform := inverse * mesh_instance.global_transform
        for endpoint in range(8):
            var p: Vector3 = transform * box.get_endpoint(endpoint)
            min_y = minf(min_y, p.y)
            max_y = maxf(max_y, p.y)
    var height := max_y - min_y
    if height <= 0.001:
        return
    var factor := clampf(target_height / height, 0.015, 32.0)
    root.scale *= Vector3.ONE * factor
    root.position.y -= min_y * factor

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _fallback_humanoid(color: Color) -> Node3D:
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.30
    capsule.height = 1.38
    body.mesh = capsule
    body.position.y = 0.82
    body.material_override = _material(color)
    root.add_child(body)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    head.mesh = sphere
    head.position.y = 1.62
    head.material_override = _material(color.lightened(0.12))
    root.add_child(head)
    return root

func _fallback_animal(color: Color, flying: bool) -> Node3D:
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.22 if flying else 0.28
    capsule.height = 0.58 if flying else 0.82
    body.mesh = capsule
    body.rotation.z = PI * 0.5
    body.material_override = _material(color)
    root.add_child(body)
    return root

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.82
    return material
