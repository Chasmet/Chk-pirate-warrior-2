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

func _ready() -> void:
    _heroes = _load_json("res://data/heroes.json")
    _items = _load_json("res://data/items.json")
    _apply_hero_capacity()

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
