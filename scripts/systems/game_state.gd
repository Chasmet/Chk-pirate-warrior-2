extends Node

signal hero_changed(hero_id: String)
signal island_changed(island_id: int)
signal inventory_changed(items: Dictionary)
signal progression_changed()
signal difficulty_changed(difficulty_id: String)
signal final_kingdom_unlocked()

const SAVE_PATH := "user://savegame_v2.json"
const HERO_ORDER := ["cheikh", "yvane", "nelvyn"]
const DIFFICULTIES := {
    "decouverte": {"enemy": 0.72, "damage": 0.62, "label": "DÉCOUVERTE"},
    "aventure": {"enemy": 1.0, "damage": 1.0, "label": "AVENTURE"},
    "legende": {"enemy": 1.38, "damage": 1.32, "label": "LÉGENDE"}
}

var selected_hero: String = "cheikh"
var current_island: int = 1
var inventory: Dictionary = {}
var max_slots: int = 30
var difficulty: String = "aventure"
var discovered_islands: Array = [1]
var defeated_bosses: Dictionary = {}
var quest_progress: Dictionary = {}
var crew_reputation: Dictionary = {"equipage_1": 0, "equipage_2": 0, "equipage_3": 0}
var coins: int = 250
var xp: int = 0
var level: int = 1
var boat_level: int = 1
var world_time: float = 0.25
var final_unlocked: bool = false
var final_reward_collected: bool = false
var exact_position: Array = []
var exact_rotation_y: float = 0.0
var exact_boat_mode: bool = false

var _heroes: Dictionary = {}
var _items: Dictionary = {}

func _ready() -> void:
    _ensure_input_actions()
    _heroes = _load_json("res://data/heroes.json")
    _items = _load_json("res://data/items.json")
    _apply_hero_capacity()

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("switch_hero"):
        cycle_hero()
    if Input.is_action_just_pressed("quick_save"):
        quick_save()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_warning("Fichier absent: %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

func new_game(hero_id: String = selected_hero, difficulty_id: String = difficulty) -> void:
    selected_hero = hero_id if HERO_ORDER.has(hero_id) else "cheikh"
    difficulty = difficulty_id if DIFFICULTIES.has(difficulty_id) else "aventure"
    current_island = 1
    inventory.clear()
    discovered_islands = [1]
    defeated_bosses.clear()
    quest_progress.clear()
    crew_reputation = {"equipage_1": 0, "equipage_2": 0, "equipage_3": 0}
    coins = 250
    xp = 0
    level = 1
    boat_level = 1
    world_time = 0.25
    final_unlocked = false
    final_reward_collected = false
    exact_position.clear()
    exact_rotation_y = 0.0
    exact_boat_mode = false
    _apply_hero_capacity()
    hero_changed.emit(selected_hero)
    island_changed.emit(current_island)
    inventory_changed.emit(inventory.duplicate(true))
    difficulty_changed.emit(difficulty)
    progression_changed.emit()

func set_hero(hero_id: String) -> void:
    if not _heroes.has(hero_id):
        return
    selected_hero = hero_id
    _apply_hero_capacity()
    hero_changed.emit(hero_id)

func cycle_hero() -> void:
    var index := HERO_ORDER.find(selected_hero)
    index = (index + 1) % HERO_ORDER.size()
    set_hero(HERO_ORDER[index])

func set_difficulty(value: String) -> void:
    difficulty = value if DIFFICULTIES.has(value) else "aventure"
    difficulty_changed.emit(difficulty)

func difficulty_enemy_multiplier() -> float:
    return float(DIFFICULTIES.get(difficulty, DIFFICULTIES["aventure"])["enemy"])

func difficulty_damage_multiplier() -> float:
    return float(DIFFICULTIES.get(difficulty, DIFFICULTIES["aventure"])["damage"])

func difficulty_label() -> String:
    return str(DIFFICULTIES.get(difficulty, DIFFICULTIES["aventure"])["label"])

func set_island(island_id: int) -> void:
    current_island = clampi(island_id, 1, 11)
    discover_island(current_island)
    island_changed.emit(current_island)

func discover_island(island_id: int) -> void:
    var resolved := clampi(island_id, 1, 11)
    if not discovered_islands.has(resolved):
        discovered_islands.append(resolved)
        discovered_islands.sort()
        progression_changed.emit()

func mark_boss_defeated(island_id: int) -> void:
    var resolved := clampi(island_id, 1, 11)
    defeated_bosses[str(resolved)] = true
    if not final_unlocked and _first_ten_bosses_defeated():
        final_unlocked = true
        final_kingdom_unlocked.emit()
    progression_changed.emit()
    quick_save()

func is_boss_defeated(island_id: int) -> bool:
    return bool(defeated_bosses.get(str(clampi(island_id, 1, 11)), false))

func _first_ten_bosses_defeated() -> bool:
    for island_id in range(1, 11):
        if not is_boss_defeated(island_id):
            return false
    return true

func can_enter_island(island_id: int) -> bool:
    if island_id != 11:
        return true
    return final_unlocked or _first_ten_bosses_defeated()

func defeated_main_boss_count() -> int:
    var result := 0
    for island_id in range(1, 11):
        if is_boss_defeated(island_id):
            result += 1
    return result

func set_quest_value(key: String, value: Variant) -> void:
    quest_progress[key] = value
    progression_changed.emit()

func get_quest_value(key: String, fallback: Variant = null) -> Variant:
    return quest_progress.get(key, fallback)

func adjust_crew_reputation(crew_id: String, amount: int) -> void:
    if not crew_reputation.has(crew_id):
        crew_reputation[crew_id] = 0
    crew_reputation[crew_id] = clampi(int(crew_reputation[crew_id]) + amount, -100, 100)
    progression_changed.emit()

func crew_relation(crew_id: String) -> String:
    var value := int(crew_reputation.get(crew_id, 0))
    if value >= 30:
        return "allie"
    if value <= -30:
        return "hostile"
    return "neutre"

func add_xp(amount: int) -> void:
    xp = maxi(0, xp + amount)
    level = clampi(1 + int(sqrt(float(xp) / 120.0)), 1, 50)
    progression_changed.emit()

func add_coins(amount: int) -> void:
    coins = maxi(0, coins + amount)
    progression_changed.emit()

func upgrade_boat() -> bool:
    var cost := 450 * boat_level
    if boat_level >= 5 or coins < cost:
        return false
    coins -= cost
    boat_level += 1
    progression_changed.emit()
    quick_save()
    return true

func get_hero_data(hero_id: String = selected_hero) -> Dictionary:
    return _heroes.get(hero_id, {})

func add_item(item_id: String, amount: int = 1) -> bool:
    if amount <= 0 or not _items.has(item_id):
        return false
    var current := int(inventory.get(item_id, 0))
    var stack_max := int(_items[item_id].get("stack", 1))
    inventory[item_id] = mini(current + amount, stack_max)
    inventory_changed.emit(inventory.duplicate(true))
    return true

func remove_item(item_id: String, amount: int = 1) -> bool:
    if not inventory.has(item_id) or amount <= 0:
        return false
    var left := int(inventory[item_id]) - amount
    if left <= 0:
        inventory.erase(item_id)
    else:
        inventory[item_id] = left
    inventory_changed.emit(inventory.duplicate(true))
    return true

func has_item(item_id: String, amount: int = 1) -> bool:
    return int(inventory.get(item_id, 0)) >= amount

func set_exact_snapshot(position: Vector3, rotation_y: float, boat_mode: bool) -> void:
    exact_position = [position.x, position.y, position.z]
    exact_rotation_y = rotation_y
    exact_boat_mode = boat_mode

func exact_position_vector() -> Vector3:
    if exact_position.size() < 3:
        return Vector3.INF
    return Vector3(float(exact_position[0]), float(exact_position[1]), float(exact_position[2]))

func quick_save() -> void:
    var data := {
        "save_version": 2,
        "hero": selected_hero,
        "island": current_island,
        "inventory": inventory,
        "difficulty": difficulty,
        "discovered_islands": discovered_islands,
        "defeated_bosses": defeated_bosses,
        "quest_progress": quest_progress,
        "crew_reputation": crew_reputation,
        "coins": coins,
        "xp": xp,
        "level": level,
        "boat_level": boat_level,
        "world_time": world_time,
        "final_unlocked": final_unlocked,
        "final_reward_collected": final_reward_collected,
        "exact_position": exact_position,
        "exact_rotation_y": exact_rotation_y,
        "exact_boat_mode": exact_boat_mode
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data, "  "))

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists("user://savegame.json")

func load_save() -> bool:
    var path := SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else "user://savegame.json"
    if not FileAccess.file_exists(path):
        return false
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return false
    var data = JSON.parse_string(file.get_as_text())
    if not data is Dictionary:
        return false
    selected_hero = str(data.get("hero", "cheikh"))
    if not HERO_ORDER.has(selected_hero):
        selected_hero = "cheikh"
    current_island = clampi(int(data.get("island", 1)), 1, 11)
    inventory = data.get("inventory", {}) if data.get("inventory", {}) is Dictionary else {}
    difficulty = str(data.get("difficulty", "aventure"))
    if not DIFFICULTIES.has(difficulty):
        difficulty = "aventure"
    discovered_islands = data.get("discovered_islands", [1]) if data.get("discovered_islands", [1]) is Array else [1]
    defeated_bosses = data.get("defeated_bosses", {}) if data.get("defeated_bosses", {}) is Dictionary else {}
    quest_progress = data.get("quest_progress", {}) if data.get("quest_progress", {}) is Dictionary else {}
    crew_reputation = data.get("crew_reputation", {"equipage_1": 0, "equipage_2": 0, "equipage_3": 0}) if data.get("crew_reputation", {}) is Dictionary else {"equipage_1": 0, "equipage_2": 0, "equipage_3": 0}
    coins = maxi(0, int(data.get("coins", 250)))
    xp = maxi(0, int(data.get("xp", 0)))
    level = clampi(int(data.get("level", 1)), 1, 50)
    boat_level = clampi(int(data.get("boat_level", 1)), 1, 5)
    world_time = clampf(float(data.get("world_time", 0.25)), 0.0, 1.0)
    final_unlocked = bool(data.get("final_unlocked", false)) or _first_ten_bosses_defeated()
    final_reward_collected = bool(data.get("final_reward_collected", false))
    exact_position = data.get("exact_position", []) if data.get("exact_position", []) is Array else []
    exact_rotation_y = float(data.get("exact_rotation_y", 0.0))
    exact_boat_mode = bool(data.get("exact_boat_mode", false))
    discover_island(current_island)
    _apply_hero_capacity()
    hero_changed.emit(selected_hero)
    island_changed.emit(current_island)
    inventory_changed.emit(inventory.duplicate(true))
    difficulty_changed.emit(difficulty)
    progression_changed.emit()
    return true

func _apply_hero_capacity() -> void:
    var hero := get_hero_data()
    max_slots = int(hero.get("backpack_capacity", 24))

func _ensure_input_actions() -> void:
    var actions := [
        "move_left", "move_right", "move_forward", "move_back",
        "attack", "dodge", "ability_1", "ability_2", "interact",
        "embark", "open_inventory", "open_map", "quick_save",
        "pause_game", "switch_hero"
    ]
    for action in actions:
        if not InputMap.has_action(action):
            InputMap.add_action(action, 0.2)

    _bind_key_once("move_left", KEY_A)
    _bind_key_once("move_right", KEY_D)
    _bind_key_once("move_forward", KEY_W)
    _bind_key_once("move_back", KEY_S)
    _bind_key_once("attack", KEY_J)
    _bind_key_once("dodge", KEY_K)
    _bind_key_once("ability_1", KEY_L)
    _bind_key_once("ability_2", KEY_SEMICOLON)
    _bind_key_once("interact", KEY_E)
    _bind_key_once("embark", KEY_B)
    _bind_key_once("open_inventory", KEY_I)
    _bind_key_once("open_map", KEY_M)
    _bind_key_once("quick_save", KEY_F5)
    _bind_key_once("pause_game", KEY_P)
    _bind_key_once("switch_hero", KEY_H)

func _bind_key_once(action: StringName, keycode: Key) -> void:
    for event in InputMap.action_get_events(action):
        if event is InputEventKey and event.physical_keycode == keycode:
            return
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    InputMap.action_add_event(action, event)
