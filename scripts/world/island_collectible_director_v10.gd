class_name IslandCollectibleDirectorV10
extends "res://scripts/world/island_collectible_director.gd"

const QUEST_DATA_PATH := "res://data/island_quests.json"
const INTERACTION_DISTANCE := 3.2

var _quests: Dictionary = {}
var _interactive_by_key: Dictionary = {}

func _ready() -> void:
    _quests = _load_quest_data()
    super._ready()
    if not GameState.progression_changed.is_connected(_on_progression_sync):
        GameState.progression_changed.connect(_on_progression_sync)

func _process(delta: float) -> void:
    super._process(delta)
    if Input.is_action_just_pressed("interact"):
        request_interaction()

func _rebuild(serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _rebuild_serial:
        return

    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _pickups.clear()
    _interactive_by_key.clear()

    _root = Node3D.new()
    _root.name = "CollectiblesV10_Ile_%02d" % _current_island
    add_child(_root)

    var info := WorldCatalog.island(_current_island - 1)
    var center := WorldCatalog.world_positions()[_current_island - 1]
    var island_size: Vector2 = info["size"]
    var rng := RandomNumberGenerator.new()
    rng.seed = 10007 + _current_island * 521

    # Les pièces gardent le ramassage automatique simple de la version précédente.
    for i in range(coin_count_per_island):
        var coin_key := "coin_%02d_%02d" % [_current_island, i]
        if bool(GameState.get_quest_value(coin_key, false)):
            continue
        var local := _pick_local_position(rng, island_size, i, coin_count_per_island)
        var world := _snap_to_ground(center + local, 0.55)
        _spawn_coin(coin_key, world, 5 + (i % 4) * 2, float(i) * 0.43)

    var quest := _current_quest()
    if not quest.is_empty():
        var required := maxi(1, int(quest.get("required", 1)))
        for i in range(required):
            var quest_key := "quest_obj_%02d_%02d" % [_current_island, i]
            if bool(GameState.get_quest_value(quest_key, false)):
                continue
            var angle := TAU * (float(i) / float(required)) + 0.31 * float(_current_island)
            var radial := 0.30 + 0.08 * float(i % 3)
            var local := Vector3(
                cos(angle) * island_size.x * 0.5 * radial,
                0.0,
                sin(angle) * island_size.y * 0.5 * radial
            )
            if absf(local.x) < 70.0 and local.z > island_size.y * 0.10:
                local.x += 92.0 if i % 2 == 0 else -92.0
            var world := _snap_to_ground(center + local, 0.72)
            _spawn_quest_object(quest_key, world, quest, float(i) * 0.81)

    # Les anciens cubes de "petit butin" deviennent de vrais coffres : ils ne
    # disparaissent plus au simple passage du joueur et exigent INTERAGIR.
    for i in range(loot_count_per_island):
        var chest_key := "chest_%02d_%02d" % [_current_island, i]
        if bool(GameState.get_quest_value(chest_key, false)):
            continue
        var angle := TAU * (float(i) / maxf(1.0, float(loot_count_per_island))) + 0.78
        var radial := 0.50 + 0.07 * float(i % 2)
        var local := Vector3(
            cos(angle) * island_size.x * 0.5 * radial,
            0.0,
            sin(angle) * island_size.y * 0.5 * radial
        )
        var world := _snap_to_ground(center + local, 0.46)
        _spawn_chest(chest_key, world, quest, i)

    _refresh_mission()

func request_interaction() -> bool:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D
    if _player == null:
        return false

    var nearest: Node3D = null
    var nearest_distance := INTERACTION_DISTANCE
    for pickup in _pickups:
        if pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        var kind := str(pickup.get_meta("kind", ""))
        if kind not in ["quest_item", "chest"]:
            continue
        var distance := _player.global_position.distance_to(pickup.global_position)
        if distance <= nearest_distance:
            nearest = pickup
            nearest_distance = distance

    if nearest == null:
        return false

    var key := str(nearest.get_meta("collect_key", ""))
    if key.is_empty():
        return false

    if NetworkManager.is_client() and NetworkManager.has_method("request_world_collectible"):
        NetworkManager.call("request_world_collectible", key)
        _notify("INTERACTION ENVOYÉE À L'HÔTE")
        return true

    _collect_interactive(nearest)
    return true

func host_process_remote_interaction(_peer_id: int, key: String, origin: Vector3) -> bool:
    if not NetworkManager.is_host() or not _interactive_by_key.has(key):
        return false
    var pickup = _interactive_by_key.get(key)
    if not pickup is Node3D or not is_instance_valid(pickup):
        return false
    var node := pickup as Node3D
    if origin.distance_to(node.global_position) > INTERACTION_DISTANCE + 0.45:
        return false
    _collect_interactive(node)
    return true

func _collect_nearby() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    for pickup in _pickups.duplicate():
        if pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        if str(pickup.get_meta("kind", "")) != "coin":
            continue
        if _player.global_position.distance_to(pickup.global_position) > 1.75:
            continue
        var key := str(pickup.get_meta("collect_key", ""))
        var value := int(pickup.get_meta("value", 1))
        if not key.is_empty():
            GameState.set_quest_value(key, true)
        GameState.add_coins(value)
        _pickups.erase(pickup)
        pickup.queue_free()
        _save_timer = 0.75

func _collect_interactive(pickup: Node3D) -> void:
    if pickup == null or not is_instance_valid(pickup):
        return
    var key := str(pickup.get_meta("collect_key", ""))
    if key.is_empty() or bool(GameState.get_quest_value(key, false)):
        return

    var kind := str(pickup.get_meta("kind", ""))
    GameState.set_quest_value(key, true)

    if kind == "quest_item":
        var item_id := str(pickup.get_meta("item_id", ""))
        if not item_id.is_empty() and GameState.add_item(item_id, 1):
            GameState.add_xp(10 + _current_island * 2)
            _notify("OBJET RÉCUPÉRÉ • %s" % GameState.item_display_name(item_id))
        _remove_interactive_pickup(pickup, false)
        _finish_quest_if_ready()
    elif kind == "chest":
        var coins_value := int(pickup.get_meta("coins", 20))
        var xp_value := int(pickup.get_meta("xp", 10))
        var chest_item := str(pickup.get_meta("item_id", ""))
        GameState.add_coins(coins_value)
        GameState.add_xp(xp_value)
        var item_text := ""
        if not chest_item.is_empty() and GameState.add_item(chest_item, 1):
            item_text = " • %s" % GameState.item_display_name(chest_item)
        _notify("COFFRE OUVERT • +%d pièces%s" % [coins_value, item_text])
        get_tree().call_group("hero_voice_director", "play_event", "coffre_trouve")
        _remove_interactive_pickup(pickup, true)

    _refresh_mission()
    _save_timer = 0.20

func _spawn_quest_object(key: String, world_position: Vector3, quest: Dictionary, phase: float) -> void:
    var pickup := Node3D.new()
    pickup.name = "ObjetQuete_%s" % key
    _root.add_child(pickup)
    pickup.global_position = world_position
    pickup.set_meta("collect_key", key)
    pickup.set_meta("kind", "quest_item")
    pickup.set_meta("item_id", str(quest.get("item_id", "")))
    pickup.set_meta("phase", phase)
    pickup.set_meta("base_y", world_position.y)

    var orb := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.28
    mesh.height = 0.56
    mesh.radial_segments = 12
    mesh.rings = 6
    orb.mesh = mesh
    var material := StandardMaterial3D.new()
    var hue := fmod(0.08 * float(_current_island) + 0.42, 1.0)
    material.albedo_color = Color.from_hsv(hue, 0.72, 0.96)
    material.metallic = 0.22
    material.roughness = 0.26
    material.emission_enabled = true
    material.emission = material.albedo_color.darkened(0.30)
    material.emission_energy_multiplier = 0.72
    orb.material_override = material
    pickup.add_child(orb)

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.34
    torus.outer_radius = 0.39
    torus.rings = 12
    torus.ring_segments = 6
    ring.mesh = torus
    ring.rotation.x = PI * 0.5
    ring.material_override = material
    pickup.add_child(ring)

    _pickups.append(pickup)
    _interactive_by_key[key] = pickup

func _spawn_chest(key: String, world_position: Vector3, quest: Dictionary, index: int) -> void:
    var chest := Node3D.new()
    chest.name = "Coffre_%s" % key
    _root.add_child(chest)
    chest.global_position = world_position
    chest.set_meta("collect_key", key)
    chest.set_meta("kind", "chest")
    chest.set_meta("coins", 22 + _current_island * 8 + index * 5)
    chest.set_meta("xp", 10 + _current_island * 3)
    chest.set_meta("item_id", str(quest.get("chest_item", "objet_rare_ile")))
    chest.set_meta("base_y", world_position.y)

    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color("6f3f1f")
    wood.roughness = 0.62
    var gold := StandardMaterial3D.new()
    gold.albedo_color = Color("d9a62e")
    gold.metallic = 0.68
    gold.roughness = 0.26

    var base := MeshInstance3D.new()
    var base_mesh := BoxMesh.new()
    base_mesh.size = Vector3(1.05, 0.56, 0.72)
    base.mesh = base_mesh
    base.position.y = 0.10
    base.material_override = wood
    chest.add_child(base)

    var band_left := MeshInstance3D.new()
    var band_mesh := BoxMesh.new()
    band_mesh.size = Vector3(0.12, 0.60, 0.76)
    band_left.mesh = band_mesh
    band_left.position = Vector3(-0.34, 0.10, 0.0)
    band_left.material_override = gold
    chest.add_child(band_left)
    var band_right := band_left.duplicate() as MeshInstance3D
    band_right.position.x = 0.34
    chest.add_child(band_right)

    var lid := Node3D.new()
    lid.name = "Lid"
    lid.position = Vector3(0.0, 0.38, 0.30)
    chest.add_child(lid)
    var lid_visual := MeshInstance3D.new()
    var lid_mesh := BoxMesh.new()
    lid_mesh.size = Vector3(1.08, 0.22, 0.72)
    lid_visual.mesh = lid_mesh
    lid_visual.position = Vector3(0.0, 0.0, -0.30)
    lid_visual.material_override = wood
    lid.add_child(lid_visual)

    var lock := MeshInstance3D.new()
    var lock_mesh := BoxMesh.new()
    lock_mesh.size = Vector3(0.18, 0.24, 0.10)
    lock.mesh = lock_mesh
    lock.position = Vector3(0.0, 0.20, -0.42)
    lock.material_override = gold
    chest.add_child(lock)

    _pickups.append(chest)
    _interactive_by_key[key] = chest

func _animate_pickups() -> void:
    for pickup in _pickups:
        if pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        var kind := str(pickup.get_meta("kind", ""))
        if kind == "chest":
            continue
        var phase := float(pickup.get_meta("phase", 0.0))
        var base_y := float(pickup.get_meta("base_y", pickup.global_position.y))
        var pos := pickup.global_position
        pos.y = base_y + sin(_time * 2.6 + phase) * 0.14
        pickup.global_position = pos
        pickup.rotation.y = fmod(_time * 1.65 + phase, TAU)

func _remove_interactive_pickup(pickup: Node3D, animate_chest: bool) -> void:
    var key := str(pickup.get_meta("collect_key", ""))
    _interactive_by_key.erase(key)
    _pickups.erase(pickup)
    if animate_chest:
        var lid := pickup.get_node_or_null("Lid") as Node3D
        if lid != null:
            var tween := create_tween()
            tween.tween_property(lid, "rotation:x", deg_to_rad(-72.0), 0.34)
            tween.tween_interval(1.1)
            tween.tween_callback(pickup.queue_free)
            return
    pickup.queue_free()

func _finish_quest_if_ready() -> void:
    var quest := _current_quest()
    if quest.is_empty():
        return
    var quest_id := str(quest.get("id", ""))
    var done_key := "quest_done_%s" % quest_id
    if bool(GameState.get_quest_value(done_key, false)):
        return
    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    if GameState.inventory_count(item_id) < required:
        return

    GameState.set_quest_value(done_key, true)
    GameState.add_coins(int(quest.get("reward_coins", 100)))
    GameState.add_xp(int(quest.get("reward_xp", 80)))
    var reward_item := str(quest.get("reward_item", ""))
    if not reward_item.is_empty():
        GameState.add_item(reward_item, 1)
    _notify("QUÊTE TERMINÉE • %s" % str(quest.get("title", "MISSION")))
    GameState.quick_save()

func _refresh_mission() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud == null or not hud.has_method("set_mission"):
        return
    var quest := _current_quest()
    if quest.is_empty():
        return
    var quest_id := str(quest.get("id", ""))
    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    var count := mini(required, GameState.inventory_count(item_id))
    if bool(GameState.get_quest_value("quest_done_%s" % quest_id, false)):
        hud.call("set_mission", str(quest.get("title", "QUÊTE")), "Terminée • explore les coffres et prépare le prochain royaume.")
    else:
        hud.call(
            "set_mission",
            str(quest.get("title", "QUÊTE")),
            "%s • %d/%d • approche puis INTERAGIR" % [str(quest.get("object_label", "Objet")), count, required]
        )

func _on_progression_sync() -> void:
    # En coop, le client reçoit l'état autoritaire de l'hôte. Retirer alors les
    # objets/coffres déjà pris évite qu'ils restent affichés sur le second téléphone.
    for pickup in _pickups.duplicate():
        if pickup == null or not is_instance_valid(pickup):
            continue
        var key := str(pickup.get_meta("collect_key", ""))
        if not key.is_empty() and bool(GameState.get_quest_value(key, false)):
            _interactive_by_key.erase(key)
            _pickups.erase(pickup)
            pickup.queue_free()
    _refresh_mission.call_deferred()

func _current_quest() -> Dictionary:
    var value = _quests.get(str(_current_island), {})
    return value if value is Dictionary else {}

func _load_quest_data() -> Dictionary:
    if not FileAccess.file_exists(QUEST_DATA_PATH):
        return {}
    var file := FileAccess.open(QUEST_DATA_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
