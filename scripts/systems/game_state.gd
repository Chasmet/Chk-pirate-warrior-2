extends Node

signal hero_changed(hero_id: String)
signal island_changed(island_id: int)
signal inventory_changed(items: Dictionary)

var selected_hero: String = "cheikh"
var current_island: int = 1
var inventory: Dictionary = {}
var max_slots: int = 30

var _heroes: Dictionary = {}
var _items: Dictionary = {}
const HERO_ORDER := ["cheikh", "yvane", "nelvyn"]

func _ready() -> void:
    _ensure_input_actions()
    _heroes = _load_json("res://data/heroes.json")
    _items = _load_json("res://data/items.json")
    _apply_hero_capacity()

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("switch_hero"):
        cycle_hero()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_warning("Fichier absent: %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

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

func set_island(island_id: int) -> void:
    current_island = clampi(island_id, 1, 11)
    island_changed.emit(current_island)

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

func quick_save() -> void:
    var data := {
        "hero": selected_hero,
        "island": current_island,
        "inventory": inventory
    }
    var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "  "))

func load_save() -> bool:
    if not FileAccess.file_exists("user://savegame.json"):
        return false
    var file := FileAccess.open("user://savegame.json", FileAccess.READ)
    var data = JSON.parse_string(file.get_as_text())
    if not data is Dictionary:
        return false
    selected_hero = str(data.get("hero", "cheikh"))
    current_island = int(data.get("island", 1))
    inventory = data.get("inventory", {})
    _apply_hero_capacity()
    hero_changed.emit(selected_hero)
    island_changed.emit(current_island)
    inventory_changed.emit(inventory.duplicate(true))
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
