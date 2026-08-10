class_name GameplayStabilityDirectorV130
extends Node

# Correctifs de stabilité V1 30/100. Cette couche est volontairement additive :
# elle répare les états incohérents observés sur Android sans supprimer les
# systèmes V3/V5 existants.
const CHECK_INTERVAL := 0.35
const DUPLICATE_BOAT_RADIUS := 22.0
const TROPHY_NAME := "TropheeFinal"
const TROPHY_BEACON_NAME := "BaliseTropheeFinalV130"
# Quai : centre à +0,45*taille, longueur 38 m environ jusqu'à +35,5 m.
# Bateau : collision 12 m de long (demi-longueur 6 m). À +41,8 m, l'avant de
# coque reste à +35,8 m : ~30 cm d'eau séparent donc les deux collisions.
# Le décalage latéral de 3,4 m maintient aussi le centre du bateau à moins de
# 9 m du point d'embarquement du bout du quai, même avec l'écart vertical.
const DOCK_BOAT_FORWARD_OFFSET := 41.8
const DOCK_BOAT_SIDE_OFFSET := 3.4

var _accumulator := 0.0
var _player: CharacterBody3D

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("gameplay_stability_v1_30")
    _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if GameState.has_signal("island_changed"):
        GameState.island_changed.connect(_on_island_changed)
    _repair_all.call_deferred()

func _process(delta: float) -> void:
    if get_tree().paused:
        return
    _accumulator += delta
    if _accumulator < CHECK_INTERVAL:
        return
    _accumulator = 0.0
    _repair_all()

func _on_island_changed(_island_id: int) -> void:
    _repair_after_transition.call_deferred()

func _repair_after_transition() -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    _repair_all()

func _repair_all() -> void:
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    _repair_orphaned_player_controller()
    _repair_dock_boat_spawns()
    _deduplicate_overlapping_boats()
    _repair_final_trophy()

func _repair_orphaned_player_controller() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var active := get_tree().get_first_node_in_group("active_controller")
    if active != null and is_instance_valid(active):
        return

    # Un bateau/véhicule supprimé pendant une transition pouvait laisser le héros
    # avec sa physique et sa collision désactivées. Sur téléphone cela donnait
    # l'impression que le jeu était bloqué jusqu'au redémarrage de l'application.
    if not _player.is_physics_processing():
        _player.set_physics_process(true)
        _player.velocity = Vector3.ZERO
        var collision := _player.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if collision != null:
            collision.set_deferred("disabled", false)
        if _player.has_method("set_virtual_move"):
            _player.call("set_virtual_move", Vector2.ZERO)
        _notify("Contrôle du héros restauré automatiquement.")

func _repair_dock_boat_spawns() -> void:
    # L'ancien spawn centré à +39 m faisait chevaucher la coque (12 m) et le quai.
    # La position V1 30/100 garde un petit espace physique devant la coque tout en
    # restant réellement accessible depuis le dernier segment du quai.
    var island_id := clampi(GameState.current_island, 1, WorldCatalog.island_count())
    var info := WorldCatalog.island(island_id - 1)
    var size: Vector2 = info["size"]
    var legacy_z := size.y * 0.45 + 39.0
    var safe_z := size.y * 0.45 + DOCK_BOAT_FORWARD_OFFSET

    for candidate in get_tree().get_nodes_in_group("boat"):
        if not (candidate is BoatController) or not is_instance_valid(candidate):
            continue
        var boat := candidate as BoatController
        if boat.is_boarded() or bool(boat.get_meta("v130_dock_spawn_checked", false)):
            continue
        var parent := boat.get_parent()
        if parent == null or not str(parent.name).begins_with("Royaume_"):
            continue
        if absf(boat.position.z - legacy_z) <= 5.5 and absf(boat.position.x - 7.0) <= 4.5:
            boat.position.x = DOCK_BOAT_SIDE_OFFSET
            boat.position.z = safe_z
            boat.position.y = -0.55
            boat.velocity = Vector3.ZERO
            boat.boarding_radius = maxf(boat.boarding_radius, 9.0)
            boat.turn_speed = maxf(boat.turn_speed, 1.62)
        boat.set_meta("v130_dock_spawn_checked", true)

func _deduplicate_overlapping_boats() -> void:
    var active := get_tree().get_first_node_in_group("active_controller")
    if not (active is BoatController) or not is_instance_valid(active):
        return
    var active_boat := active as BoatController
    if not active_boat.is_boarded():
        return

    # Pendant un changement de royaume le bateau piloté est conservé. Le nouveau
    # royaume peut encore créer son bateau de quai : si les deux coïncident, on
    # supprime uniquement le bateau local non piloté, jamais celui du joueur.
    for candidate in get_tree().get_nodes_in_group("boat"):
        if candidate == active_boat or not (candidate is BoatController) or not is_instance_valid(candidate):
            continue
        var other := candidate as BoatController
        if other.is_boarded():
            continue
        if other.global_position.distance_to(active_boat.global_position) <= DUPLICATE_BOAT_RADIUS:
            other.queue_free()
            _notify("Bateau de quai en double supprimé automatiquement.")

func _repair_final_trophy() -> void:
    if GameState.current_island != 11 or GameState.final_reward_collected:
        return
    if not GameState.is_boss_defeated(11):
        return
    var world := get_tree().get_first_node_in_group("world_director")
    if world == null or not is_instance_valid(world):
        return

    var reward := world.find_child(TROPHY_NAME, true, false) as Node3D
    if reward == null and world.has_method("_ensure_final_reward"):
        world.call("_ensure_final_reward")
        reward = world.find_child(TROPHY_NAME, true, false) as Node3D
    if reward == null:
        return

    # L'ancien code fixait Y=7. Avec le relief V3, le trophée pouvait être sous
    # la colline ou flotter. On recalcule sa hauteur sur le vrai terrain actif.
    if world.has_method("_terrain_height_at"):
        var info := WorldCatalog.island(10)
        var ground_value = world.call("_terrain_height_at", info, reward.position.x, reward.position.z)
        if ground_value != null:
            reward.position.y = float(ground_value) + 0.35

    _ensure_trophy_beacon(reward)

func _ensure_trophy_beacon(reward: Node3D) -> void:
    var parent := reward.get_parent() as Node3D
    if parent == null:
        return
    var beacon := parent.get_node_or_null(TROPHY_BEACON_NAME) as Node3D
    if beacon == null:
        beacon = Node3D.new()
        beacon.name = TROPHY_BEACON_NAME
        parent.add_child(beacon)

        var column := MeshInstance3D.new()
        column.name = "ColonneLumineuse"
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = 0.42
        cylinder.bottom_radius = 0.42
        cylinder.height = 8.0
        cylinder.radial_segments = 12
        column.mesh = cylinder
        column.position.y = 4.0
        column.material_override = _emissive_material(Color("ffd447"), 2.2, 0.22)
        beacon.add_child(column)

        var ring := MeshInstance3D.new()
        ring.name = "AnneauTrophee"
        var torus := TorusMesh.new()
        torus.inner_radius = 2.3
        torus.outer_radius = 2.65
        torus.rings = 24
        torus.ring_segments = 8
        ring.mesh = torus
        ring.position.y = 1.4
        ring.material_override = _emissive_material(Color("fff0a0"), 2.8, 0.0)
        beacon.add_child(ring)

        var light := OmniLight3D.new()
        light.name = "LumiereTrophee"
        light.light_color = Color("ffd447")
        light.light_energy = 4.0
        light.omni_range = 18.0
        light.shadow_enabled = false
        light.position.y = 3.8
        beacon.add_child(light)

        var label := Label3D.new()
        label.name = "LabelTropheeFinal"
        label.text = "TROPHÉE FINAL"
        label.position = Vector3(0.0, 7.2, 0.0)
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        label.font_size = 42
        label.outline_size = 10
        label.modulate = Color("ffe477")
        label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
        beacon.add_child(label)

    beacon.position = reward.position

func _emissive_material(color: Color, emission_energy: float, alpha: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(color.r, color.g, color.b, alpha if alpha > 0.0 else 1.0)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = emission_energy
    if alpha > 0.0 and alpha < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

func _notify(message: String) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", message, 2.2)
