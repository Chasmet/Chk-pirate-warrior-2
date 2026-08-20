class_name ArchipelagoDirectorV3Endgame
extends "res://scripts/world/archipelago_director_v3.gd"

const ISLAND_11_ID := 11
const ISLAND_11_INDEX := 10
const FIRST_BOSS_KEY := "island_11_boss_sorciere_defeated"
const FIRST_BOSS_PATH := "res://assets/royaumes/11_royaume_trouble_final/boss sorcière.glb"
const FIRST_BOSS_NAME := "Sorcière gardienne"
const FIRST_BOSS_ARCHETYPE := "boss_ranged"

func _spawn_population_and_enemies(info: Dictionary) -> void:
    var island_id := int(info.get("id", 0))
    if island_id != ISLAND_11_ID:
        super._spawn_population_and_enemies(info)
        return

    # Île 11 : la fin ne doit jamais commencer directement par la grande sorcière.
    # On impose une séquence de deux boss : Sorcière gardienne, puis Grande Sorcière.
    if GameState.is_boss_defeated(ISLAND_11_ID):
        return
    _spawn_island_11_current_boss(info)

func _spawn_current_boss() -> void:
    if _current_index != ISLAND_11_INDEX:
        super._spawn_current_boss()
        return
    if _island_root == null or not is_instance_valid(_island_root):
        return
    if GameState.is_boss_defeated(ISLAND_11_ID):
        return
    _spawn_island_11_current_boss(WorldCatalog.island(_current_index))

func _spawn_island_11_current_boss(info: Dictionary) -> void:
    if _has_live_boss():
        _boss_spawned_for_island = _current_index
        return

    var first_boss_done := bool(GameState.get_quest_value(FIRST_BOSS_KEY, false))
    if not first_boss_done:
        if ResourceLoader.exists(FIRST_BOSS_PATH):
            var size: Vector2 = info.get("size", Vector2(3000.0, 2300.0))
            var difficulty := (1.12 + float(ISLAND_11_ID) * 0.15) * GameState.difficulty_enemy_multiplier()
            _spawn_enemy(
                FIRST_BOSS_PATH,
                Vector3(0.0, 12.0, -size.y * 0.12),
                true,
                difficulty,
                FIRST_BOSS_NAME,
                FIRST_BOSS_ARCHETYPE,
                110
            )
            _boss_spawned_for_island = _current_index
            _notify("SORCIÈRE GARDIENNE • PREMIER BOSS DE L’ÎLE 11")
            return

        # Sécurité : un asset manquant ne doit pas bloquer définitivement la fin du jeu.
        push_warning("Île 11 : asset du premier boss introuvable, passage au boss final")
        GameState.set_quest_value(FIRST_BOSS_KEY, true)
        GameState.quick_save()

    _boss_spawned_for_island = -1
    _spawn_boss(info, GameState.difficulty_enemy_multiplier())

func on_boss_defeated(enemy: Node) -> void:
    var island_id := _current_index + 1
    if island_id == ISLAND_11_ID and _is_first_island_11_boss(enemy):
        if not bool(GameState.get_quest_value(FIRST_BOSS_KEY, false)):
            GameState.set_quest_value(FIRST_BOSS_KEY, true)
            GameState.add_xp(700)
            GameState.add_coins(320)
            GameState.quick_save()
        _boss_spawned_for_island = -1
        _notify("SORCIÈRE GARDIENNE VAINCUE • LA GRANDE SORCIÈRE ARRIVE")
        # WorldEnemy appelle ce callback avant son queue_free(). Un simple
        # call_deferred pouvait donc revoir le premier boss encore dans l'arbre,
        # considérer qu'un boss était vivant et ne jamais créer le boss final.
        call_deferred("_spawn_island_11_final_after_cleanup")
        return

    # Seule la défaite de la Grande Sorcière passe ici : le parent marque alors
    # réellement l’île 11 comme terminée. L’écran trophée peut ensuite apparaître.
    super.on_boss_defeated(enemy)

func _spawn_island_11_final_after_cleanup() -> void:
    await get_tree().process_frame
    if not is_inside_tree() or _current_index != ISLAND_11_INDEX:
        return
    if GameState.is_boss_defeated(ISLAND_11_ID):
        return
    _boss_spawned_for_island = -1
    _spawn_current_boss()

func _is_first_island_11_boss(enemy: Node) -> bool:
    if enemy == null or not is_instance_valid(enemy):
        return false
    return str(enemy.get("model_path")) == FIRST_BOSS_PATH

func _spawn_hierarchy_enemy(index: int, rank: int) -> void:
    # Les commandants des îles 1 à 10 utilisaient une difficulté fixe et
    # ignoraient le choix DÉCOUVERTE / AVENTURE / LÉGENDE. On applique le même
    # multiplicateur que pour les soldats et les grands boss.
    if index < 0 or index >= WorldCatalog.island_count() or _has_live_boss():
        return
    var info := WorldCatalog.island(index)
    var island_id := int(info["id"])
    var key := _commandant_key(island_id, rank)
    if int(GameState.get_quest_value(key, 0)) == 1:
        return
    var path := _hierarchy_asset(info, rank)
    if not ResourceLoader.exists(path):
        _notify("GLB du commandant %d indisponible pour l’île %02d" % [rank, island_id])
        return
    var size: Vector2 = info["size"]
    var name := "Commandant 1" if rank == 1 else "Commandant 2"
    var archetype := "boss_duelist" if rank == 1 else "boss_guard"
    var difficulty := (1.25 + float(island_id) * 0.14) * GameState.difficulty_enemy_multiplier()
    _spawn_enemy(
        path,
        Vector3(0.0, 12.0, -size.y * (0.10 if rank == 1 else 0.05)),
        false,
        difficulty,
        name,
        archetype,
        20 + rank
    )
