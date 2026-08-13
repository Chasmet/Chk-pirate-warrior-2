class_name StoryQuestDirectorV11_1
extends "res://scripts/world/island_collectible_director_v10.gd"

const QUEST_NPC_DISTANCE := 3.6
const GUIDE_REFRESH_SECONDS := 0.25

var _guide_timer := 0.0
var _npc_node: Node3D
var _cave_node: Node3D
var _cave_world_position := Vector3.ZERO

func _process(delta: float) -> void:
    super._process(delta)
    _guide_timer += delta
    if _guide_timer >= GUIDE_REFRESH_SECONDS:
        _guide_timer = 0.0
        _refresh_mission()

func _rebuild(serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _rebuild_serial:
        return

    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _pickups.clear()
    _interactive_by_key.clear()
    _npc_node = null
    _cave_node = null

    _root = Node3D.new()
    _root.name = "StoryQuestV11_1_Ile_%02d" % _current_island
    add_child(_root)

    var info := WorldCatalog.island(_current_island - 1)
    var center := WorldCatalog.world_positions()[_current_island - 1]
    var island_size: Vector2 = info["size"]
    var rng := RandomNumberGenerator.new()
    rng.seed = 11011 + _current_island * 631

    # Pièces d'exploration : elles restent indépendantes de la quête scénarisée.
    for i in range(coin_count_per_island):
        var coin_key := "coin_%02d_%02d" % [_current_island, i]
        if bool(GameState.get_quest_value(coin_key, false)):
            continue
        var local := _pick_local_position(rng, island_size, i, coin_count_per_island)
        var coin_world := _snap_to_ground(center + local, 0.55)
        _spawn_coin(coin_key, coin_world, 5 + (i % 4) * 2, float(i) * 0.43)

    var quest := _current_quest()
    if not quest.is_empty():
        var npc_local := Vector3(-island_size.x * 0.11, 0.0, island_size.y * 0.12)
        var npc_world := _snap_to_ground(center + npc_local, 0.0)
        _spawn_quest_npc(npc_world, quest)

        var cave_local := Vector3(island_size.x * 0.28, 0.0, -island_size.y * 0.06)
        _cave_world_position = _snap_to_ground(center + cave_local, 0.0)
        _spawn_story_cave(_cave_world_position, quest)

        var quest_id := str(quest.get("id", ""))
        var accepted := bool(GameState.get_quest_value("quest_accepted_%s" % quest_id, false))
        var done := bool(GameState.get_quest_value("quest_done_%s" % quest_id, false))
        if accepted and not done:
            _spawn_story_objectives(quest)

    # Les coffres restent des objectifs secondaires à ouvrir avec INTERAGIR.
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
        var chest_world := _snap_to_ground(center + local, 0.46)
        _spawn_chest(chest_key, chest_world, quest, i)

    _refresh_mission()

func request_interaction() -> bool:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D
    if _player == null:
        return false

    var nearest: Node3D = null
    var nearest_distance := QUEST_NPC_DISTANCE
    for pickup in _pickups:
        if pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        var kind := str(pickup.get_meta("kind", ""))
        if kind not in ["quest_npc", "quest_item", "chest"]:
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
        if str(nearest.get_meta("kind", "")) == "quest_npc":
            _show_dialogue_for_current_stage(false)
        NetworkManager.call("request_world_collectible", key)
        return true

    _collect_interactive(nearest)
    return true

func _collect_interactive(pickup: Node3D) -> void:
    if pickup == null or not is_instance_valid(pickup):
        return
    var kind := str(pickup.get_meta("kind", ""))
    if kind == "quest_npc":
        _interact_with_quest_npc()
        return
    super._collect_interactive(pickup)

func _interact_with_quest_npc() -> void:
    var quest := _current_quest()
    if quest.is_empty():
        return
    var quest_id := str(quest.get("id", ""))
    var accepted_key := "quest_accepted_%s" % quest_id
    var done_key := "quest_done_%s" % quest_id
    var accepted := bool(GameState.get_quest_value(accepted_key, false))
    var done := bool(GameState.get_quest_value(done_key, false))

    if done:
        _show_quest_dialogue(
            str(quest.get("npc_name", "Habitant")),
            str(quest.get("dialogue_done", "Merci encore pour ton aide.")),
            "QUÊTE TERMINÉE • %s" % str(quest.get("title", "MISSION"))
        )
        return

    if not accepted:
        GameState.set_quest_value(accepted_key, true)
        _show_quest_dialogue(
            str(quest.get("npc_name", "Habitant")),
            str(quest.get("dialogue_intro", quest.get("description", "J'ai besoin de ton aide."))),
            "OBJECTIF : %s ×%d • %s" % [
                str(quest.get("object_label", "Objet")),
                maxi(1, int(quest.get("required", 1))),
                str(quest.get("location_name", "zone indiquée"))
            ]
        )
        _rebuild_serial += 1
        _rebuild.call_deferred(_rebuild_serial)
        GameState.quick_save()
        return

    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    var count := GameState.inventory_count(item_id)
    if count < required:
        _show_quest_dialogue(
            str(quest.get("npc_name", "Habitant")),
            str(quest.get("dialogue_active", "Continue ta recherche.")),
            "%s • %d/%d • %s" % [
                str(quest.get("object_label", "Objet")),
                count,
                required,
                str(quest.get("location_hint", "Suis l'indication de mission."))
            ]
        )
        return

    var return_text := str(quest.get("dialogue_return", "Tu as tout trouvé."))
    if not item_id.is_empty():
        GameState.remove_item(item_id, required)
    GameState.set_quest_value(done_key, true)
    GameState.add_coins(int(quest.get("reward_coins", 100)))
    GameState.add_xp(int(quest.get("reward_xp", 100)))
    var reward_item := str(quest.get("reward_item", ""))
    if not reward_item.is_empty():
        GameState.add_item(reward_item, 1)
    var reward_name := GameState.item_display_name(reward_item) if not reward_item.is_empty() else "Récompense"
    _show_quest_dialogue(
        str(quest.get("npc_name", "Habitant")),
        "%s\n\n%s" % [return_text, str(quest.get("dialogue_done", "Mission accomplie."))],
        "QUÊTE TERMINÉE • +%d pièces • +%d XP • %s" % [
            int(quest.get("reward_coins", 100)),
            int(quest.get("reward_xp", 100)),
            reward_name
        ]
    )
    _notify("QUÊTE TERMINÉE • %s" % str(quest.get("title", "MISSION")))
    GameState.quick_save()
    _rebuild_serial += 1
    _rebuild.call_deferred(_rebuild_serial)

func _finish_quest_if_ready() -> void:
    # V11.1 : récupérer les objets ne termine plus automatiquement la quête.
    # Le joueur doit revenir parler au PNJ et lui remettre réellement les objets.
    var quest := _current_quest()
    if quest.is_empty():
        return
    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    if GameState.inventory_count(item_id) >= required:
        _notify("OBJECTIF COMPLET • RETOURNE VOIR %s" % str(quest.get("npc_name", "LE PNJ")))
    _refresh_mission()

func _spawn_quest_npc(world_position: Vector3, quest: Dictionary) -> void:
    var npc := Node3D.new()
    npc.name = "PNJ_%s" % str(quest.get("id", "quete"))
    _root.add_child(npc)
    npc.global_position = world_position
    npc.set_meta("collect_key", "quest_npc_%02d" % _current_island)
    npc.set_meta("kind", "quest_npc")
    npc.set_meta("base_y", world_position.y)
    _npc_node = npc

    var hue := fmod(0.12 + float(_current_island) * 0.073, 1.0)
    var cloth_color := Color.from_hsv(hue, 0.58, 0.82)
    var cloth := StandardMaterial3D.new()
    cloth.albedo_color = cloth_color
    cloth.roughness = 0.58

    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.42
    body_mesh.height = 1.35
    body.mesh = body_mesh
    body.position.y = 0.92
    body.material_override = cloth
    npc.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.30
    head_mesh.height = 0.60
    head.mesh = head_mesh
    head.position.y = 1.86
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color("b98764")
    skin.roughness = 0.72
    head.material_override = skin
    npc.add_child(head)

    var marker := MeshInstance3D.new()
    var marker_mesh := SphereMesh.new()
    marker_mesh.radius = 0.13
    marker_mesh.height = 0.26
    marker.mesh = marker_mesh
    marker.position.y = 2.63
    var marker_material := StandardMaterial3D.new()
    marker_material.albedo_color = Color("ffd758")
    marker_material.emission_enabled = true
    marker_material.emission = Color("ffd758")
    marker_material.emission_energy_multiplier = 2.2
    marker.material_override = marker_material
    npc.add_child(marker)

    var label := Label3D.new()
    label.text = "!  %s\n%s" % [str(quest.get("npc_name", "PNJ")), str(quest.get("npc_role", "Mission"))]
    label.position = Vector3(0.0, 2.95, 0.0)
    label.font_size = 34
    label.outline_size = 8
    label.modulate = Color("ffe69a")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    npc.add_child(label)

    _pickups.append(npc)
    _interactive_by_key[str(npc.get_meta("collect_key"))] = npc

func _spawn_story_cave(world_position: Vector3, quest: Dictionary) -> void:
    var cave := Node3D.new()
    cave.name = "Grotte_%02d" % _current_island
    _root.add_child(cave)
    cave.global_position = world_position
    _cave_node = cave

    var rock := StandardMaterial3D.new()
    rock.albedo_color = Color("25262a") if _current_island != 9 else Color("2b1714")
    rock.roughness = 0.90
    var glow := StandardMaterial3D.new()
    glow.albedo_color = _quest_glow_color()
    glow.emission_enabled = true
    glow.emission = glow.albedo_color
    glow.emission_energy_multiplier = 1.8

    # Couloir ouvert : deux murs, un plafond et un fond. Aucun collider ajouté,
    # pour éviter qu'un décor procédural bloque le joueur sur Android.
    for side in [-1.0, 1.0]:
        var wall := MeshInstance3D.new()
        var wall_mesh := BoxMesh.new()
        wall_mesh.size = Vector3(1.5, 4.2, 13.0)
        wall.mesh = wall_mesh
        wall.position = Vector3(3.6 * side, 1.65, 5.5)
        wall.material_override = rock
        cave.add_child(wall)

    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(8.4, 1.2, 13.0)
    roof.mesh = roof_mesh
    roof.position = Vector3(0.0, 3.65, 5.5)
    roof.material_override = rock
    cave.add_child(roof)

    var back := MeshInstance3D.new()
    var back_mesh := BoxMesh.new()
    back_mesh.size = Vector3(8.4, 4.5, 1.0)
    back.mesh = back_mesh
    back.position = Vector3(0.0, 1.6, 12.0)
    back.material_override = rock
    cave.add_child(back)

    for i in range(4):
        var crystal := MeshInstance3D.new()
        var crystal_mesh := CylinderMesh.new()
        crystal_mesh.top_radius = 0.08
        crystal_mesh.bottom_radius = 0.26
        crystal_mesh.height = 1.0 + 0.25 * float(i % 2)
        crystal_mesh.radial_segments = 6
        crystal.mesh = crystal_mesh
        crystal.position = Vector3(-2.4 + float(i) * 1.6, 0.55, 8.0 + float(i % 2) * 1.8)
        crystal.rotation_degrees.z = -12.0 + float(i) * 8.0
        crystal.material_override = glow
        cave.add_child(crystal)

    var label := Label3D.new()
    label.text = str(quest.get("location_name", "GROTTE DE MISSION")).to_upper()
    label.position = Vector3(0.0, 4.65, -0.2)
    label.font_size = 38
    label.outline_size = 9
    label.modulate = Color("dcecff")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    cave.add_child(label)

    var entrance := MeshInstance3D.new()
    var entrance_mesh := TorusMesh.new()
    entrance_mesh.inner_radius = 2.45
    entrance_mesh.outer_radius = 2.62
    entrance_mesh.rings = 18
    entrance_mesh.ring_segments = 8
    entrance.mesh = entrance_mesh
    entrance.rotation_degrees.x = 90.0
    entrance.position = Vector3(0.0, 1.65, 0.0)
    entrance.material_override = glow
    cave.add_child(entrance)

func _spawn_story_objectives(quest: Dictionary) -> void:
    var required := maxi(1, int(quest.get("required", 1)))
    for i in range(required):
        var quest_key := "quest_obj_%02d_%02d" % [_current_island, i]
        if bool(GameState.get_quest_value(quest_key, false)):
            continue
        # Les objets se trouvent réellement dans ou juste devant la grotte.
        var row := int(i / 3)
        var col := i % 3
        var offset := Vector3((float(col) - 1.0) * 2.0, 0.0, 3.8 + float(row) * 3.0 + float(col) * 1.15)
        var objective_world := _snap_to_ground(_cave_world_position + offset, 0.72)
        _spawn_quest_object(quest_key, objective_world, quest, float(i) * 0.81)

func _animate_pickups() -> void:
    for pickup in _pickups:
        if pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
            continue
        var kind := str(pickup.get_meta("kind", ""))
        if kind in ["chest", "quest_npc"]:
            continue
        var phase := float(pickup.get_meta("phase", 0.0))
        var base_y := float(pickup.get_meta("base_y", pickup.global_position.y))
        var pos := pickup.global_position
        pos.y = base_y + sin(_time * 2.6 + phase) * 0.14
        pickup.global_position = pos
        pickup.rotation.y = fmod(_time * 1.65 + phase, TAU)

func _refresh_mission() -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud == null or not hud.has_method("set_mission"):
        return
    var quest := _current_quest()
    if quest.is_empty():
        return

    var quest_id := str(quest.get("id", ""))
    var accepted := bool(GameState.get_quest_value("quest_accepted_%s" % quest_id, false))
    var done := bool(GameState.get_quest_value("quest_done_%s" % quest_id, false))
    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    var count := mini(required, GameState.inventory_count(item_id))
    var npc_name := str(quest.get("npc_name", "PNJ"))

    if done:
        hud.call("set_mission", str(quest.get("title", "QUÊTE")), "TERMINÉE • %s t'a remis la récompense. Explore les coffres ou poursuis le royaume." % npc_name)
        return

    if not accepted:
        var npc_distance := _distance_to(_npc_node)
        hud.call(
            "set_mission",
            str(quest.get("title", "NOUVELLE QUÊTE")),
            "PARLE À %s • %s • approche puis INTERAGIR" % [npc_name, _distance_text(npc_distance)]
        )
        return

    if count >= required:
        var return_distance := _distance_to(_npc_node)
        hud.call(
            "set_mission",
            str(quest.get("title", "QUÊTE")),
            "OBJETS TROUVÉS %d/%d • RETOURNE VOIR %s • %s" % [count, required, npc_name, _distance_text(return_distance)]
        )
        return

    var target := _nearest_kind("quest_item")
    var target_distance := _distance_to(target) if target != null else _distance_to(_cave_node)
    hud.call(
        "set_mission",
        str(quest.get("title", "QUÊTE")),
        "%s %d/%d • %s • prochain objectif %s" % [
            str(quest.get("object_label", "Objet")),
            count,
            required,
            str(quest.get("location_name", "ZONE DE MISSION")),
            _distance_text(target_distance)
        ]
    )

func _nearest_kind(kind: String) -> Node3D:
    if _player == null or not is_instance_valid(_player):
        return null
    var best: Node3D = null
    var best_distance := INF
    for pickup in _pickups:
        if pickup == null or not is_instance_valid(pickup):
            continue
        if str(pickup.get_meta("kind", "")) != kind:
            continue
        var d := _player.global_position.distance_to(pickup.global_position)
        if d < best_distance:
            best_distance = d
            best = pickup
    return best

func _distance_to(node: Node3D) -> float:
    if node == null or not is_instance_valid(node) or _player == null or not is_instance_valid(_player):
        return -1.0
    return _player.global_position.distance_to(node.global_position)

func _distance_text(distance: float) -> String:
    if distance < 0.0:
        return "distance inconnue"
    return "%d m" % maxi(0, roundi(distance))

func _quest_glow_color() -> Color:
    match _current_island:
        1: return Color("68c8ff")
        2: return Color("ffd46a")
        3: return Color("ff9d4d")
        4: return Color("bd79ff")
        5: return Color("50e5ff")
        6: return Color("68e890")
        7: return Color("e9b54c")
        8: return Color("9fe8ff")
        9: return Color("ff4d35")
        10: return Color("89d66f")
        11: return Color("b15cff")
        _: return Color("ffffff")

func _show_dialogue_for_current_stage(_authoritative: bool) -> void:
    var quest := _current_quest()
    if quest.is_empty():
        return
    var quest_id := str(quest.get("id", ""))
    var accepted := bool(GameState.get_quest_value("quest_accepted_%s" % quest_id, false))
    var done := bool(GameState.get_quest_value("quest_done_%s" % quest_id, false))
    var item_id := str(quest.get("item_id", ""))
    var required := maxi(1, int(quest.get("required", 1)))
    var count := GameState.inventory_count(item_id)
    var body := str(quest.get("dialogue_intro", "J'ai besoin de ton aide."))
    var objective := str(quest.get("location_hint", "Suis la mission."))
    if done:
        body = str(quest.get("dialogue_done", "Merci encore."))
        objective = "QUÊTE TERMINÉE"
    elif accepted and count >= required:
        body = str(quest.get("dialogue_return", "Tu as tout trouvé."))
        objective = "REMISE DES OBJETS À L'HÔTE"
    elif accepted:
        body = str(quest.get("dialogue_active", "Continue ta recherche."))
        objective = "%s • %d/%d" % [str(quest.get("object_label", "Objet")), count, required]
    _show_quest_dialogue(str(quest.get("npc_name", "Habitant")), body, objective)

func _show_quest_dialogue(speaker: String, body: String, objective: String) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_quest_dialogue"):
        hud.call("show_quest_dialogue", speaker, body, objective)
    elif hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", "%s : %s" % [speaker, body], 6.0)
