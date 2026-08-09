class_name EnemyRecoveryService
extends Node

const SOLDIERS_REQUIRED := 6

@export var manual_cooldown := 1.5
@export var automatic_recovery_delay := 4.0

var _cooldown := 0.0
var _missing_objective_time := 0.0

func _ready() -> void:
    add_to_group("enemy_recovery")

func _process(delta: float) -> void:
    _cooldown = maxf(0.0, _cooldown - delta)
    if _objective_is_complete():
        _missing_objective_time = 0.0
        return
    if _has_live_objective_enemy():
        _missing_objective_time = 0.0
        return
    var active := get_tree().get_first_node_in_group("active_controller")
    if active != null:
        _missing_objective_time = 0.0
        return
    _missing_objective_time += delta
    if _missing_objective_time >= automatic_recovery_delay and _cooldown <= 0.0:
        _missing_objective_time = 0.0
        _recover_objective(false)

func request_recovery() -> bool:
    if _cooldown > 0.0:
        _notify("RÉCUPÉRATION • attends une seconde avant de réessayer")
        return false
    return _recover_objective(true)

func _recover_objective(manual: bool) -> bool:
    var world := get_tree().get_first_node_in_group("world_director")
    var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
    if world == null or player == null or not is_instance_valid(player):
        return false

    var island_id := clampi(GameState.current_island, 1, WorldCatalog.island_count())
    if GameState.is_boss_defeated(island_id):
        if manual:
            _notify("RÉCUPÉRATION • ce royaume est déjà libéré")
        return false

    _cooldown = manual_cooldown
    var progress := clampi(int(GameState.get_quest_value(_soldier_key(island_id), 0)), 0, SOLDIERS_REQUIRED)
    var boss_phase := island_id == 11 or progress >= SOLDIERS_REQUIRED
    var live := _live_enemies_for_current_island(world, boss_phase)

    if not live.is_empty():
        var nearest := _nearest_enemy(live, player.global_position)
        if nearest != null:
            _reposition_enemy(world, nearest, player, boss_phase)
            _notify("ENNEMI RÉCUPÉRÉ • cible replacée devant toi")
            return true

    if boss_phase:
        if world.has_method("_spawn_current_boss"):
            world.call("_spawn_current_boss")
            _notify("BOSS RÉCUPÉRÉ • apparition forcée")
            return true
        return false

    return _spawn_missing_forces(world, player, island_id, progress)

func _spawn_missing_forces(world: Node, player: CharacterBody3D, island_id: int, progress: int) -> bool:
    if not world.has_method("current_island_data") or not world.has_method("_spawn_enemy"):
        return false
    var info: Dictionary = world.call("current_island_data")
    var soldier_paths: Array = info.get("soldiers", [])
    if soldier_paths.is_empty():
        _notify("RÉCUPÉRATION • aucun modèle ennemi disponible")
        return false

    var soldier_names: Array = info.get("soldier_names", [])
    var soldier_archetypes: Array = info.get("soldier_archetypes", [])
    var island_root := world.get("_island_root") as Node3D
    if island_root == null or not is_instance_valid(island_root):
        return false

    var remaining := SOLDIERS_REQUIRED - progress
    var count := mini(3, maxi(1, remaining))
    var base_difficulty := (0.8 + float(island_id) * 0.12) * GameState.difficulty_enemy_multiplier()
    var forward := -player.global_transform.basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.01:
        forward = Vector3.FORWARD
    forward = forward.normalized()
    var right := forward.cross(Vector3.UP).normalized()

    for i in range(count):
        var variant := (progress + i) % soldier_paths.size()
        var path := str(soldier_paths[variant])
        var display_name := str(soldier_names[variant % soldier_names.size()]) if not soldier_names.is_empty() else "Force locale"
        var archetype := str(soldier_archetypes[variant % soldier_archetypes.size()]) if not soldier_archetypes.is_empty() else "melee"
        var world_target := player.global_position + forward * (11.0 + float(i) * 2.5) + right * (float(i) - float(count - 1) * 0.5) * 4.0
        var local_target := island_root.to_local(world_target)
        world.call("_spawn_enemy", path, local_target, false, base_difficulty, display_name, archetype, variant)

    _notify("FORCES RÉCUPÉRÉES • %d ennemi(s) réapparu(s)" % count)
    return true

func _live_enemies_for_current_island(world: Node, want_boss: bool) -> Array[Node3D]:
    var result: Array[Node3D] = []
    var island_root := world.get("_island_root") as Node3D
    if island_root == null or not is_instance_valid(island_root):
        return result
    for node in get_tree().get_nodes_in_group("enemy"):
        if not (node is Node3D) or not is_instance_valid(node):
            continue
        var enemy := node as Node3D
        if not island_root.is_ancestor_of(enemy):
            continue
        if bool(enemy.get("boss")) == want_boss:
            result.append(enemy)
    return result

func _has_live_objective_enemy() -> bool:
    var world := get_tree().get_first_node_in_group("world_director")
    if world == null:
        return true
    var island_id := clampi(GameState.current_island, 1, WorldCatalog.island_count())
    if GameState.is_boss_defeated(island_id):
        return true
    var progress := clampi(int(GameState.get_quest_value(_soldier_key(island_id), 0)), 0, SOLDIERS_REQUIRED)
    return not _live_enemies_for_current_island(world, island_id == 11 or progress >= SOLDIERS_REQUIRED).is_empty()

func _objective_is_complete() -> bool:
    return GameState.is_boss_defeated(clampi(GameState.current_island, 1, WorldCatalog.island_count()))

func _nearest_enemy(enemies: Array[Node3D], origin: Vector3) -> Node3D:
    var nearest: Node3D
    var best := INF
    for enemy in enemies:
        var d := enemy.global_position.distance_squared_to(origin)
        if d < best:
            best = d
            nearest = enemy
    return nearest

func _reposition_enemy(world: Node, enemy: Node3D, player: CharacterBody3D, boss_phase: bool) -> void:
    var island_root := world.get("_island_root") as Node3D
    if island_root == null or not is_instance_valid(island_root):
        return
    var forward := -player.global_transform.basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.01:
        forward = Vector3.FORWARD
    forward = forward.normalized()
    var world_target := player.global_position + forward * (14.0 if boss_phase else 10.0)
    var local_target := island_root.to_local(world_target)
    if world.has_method("_terrain_height_at") and world.has_method("current_island_data"):
        var info: Dictionary = world.call("current_island_data")
        local_target.y = float(world.call("_terrain_height_at", info, local_target.x, local_target.z)) + (0.22 if boss_phase else 0.12)
    enemy.position = local_target
    if enemy is CharacterBody3D:
        (enemy as CharacterBody3D).velocity = Vector3.ZERO

func _soldier_key(island_id: int) -> String:
    return "island_%02d_forces" % island_id

func _notify(text: String) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", text, 2.8)
        return
    var world := get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("_notify"):
        world.call("_notify", text)
