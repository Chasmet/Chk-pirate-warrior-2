extends "res://scripts/systems/game_state.gd"

# V10 garde le format de sauvegarde V2 : inventaire et quêtes restent donc
# compatibles avec les parties existantes. Les objets de quête/reliques ne
# consomment pas de place afin d'éviter de bloquer la campagne.

func _ready() -> void:
    super._ready()
    _sanitize_inventory()

func load_save() -> bool:
    var loaded := super.load_save()
    if loaded:
        _sanitize_inventory()
        inventory_changed.emit(inventory.duplicate(true))
    return loaded

func apply_multiplayer_snapshot(data: Dictionary) -> void:
    super.apply_multiplayer_snapshot(data)
    _sanitize_inventory()
    inventory_changed.emit(inventory.duplicate(true))

func item_data(item_id: String) -> Dictionary:
    var value = _items.get(item_id, {})
    return value if value is Dictionary else {}

func item_display_name(item_id: String) -> String:
    var data := item_data(item_id)
    return str(data.get("name", item_id.replace("_", " ").capitalize()))

func item_category(item_id: String) -> String:
    return str(item_data(item_id).get("category", "objet"))

func inventory_count(item_id: String) -> int:
    return maxi(0, int(inventory.get(item_id, 0)))

func item_slot_cost(item_id: String) -> int:
    var data := item_data(item_id)
    if bool(data.get("quest_item", false)) or bool(data.get("key_item", false)):
        return 0
    return maxi(0, int(data.get("slot_cost", 1)))

func inventory_used_slots() -> int:
    var used := 0
    for raw_id in inventory.keys():
        var item_id := str(raw_id)
        if inventory_count(item_id) <= 0:
            continue
        used += item_slot_cost(item_id)
    return used

func inventory_free_slots() -> int:
    return maxi(0, max_slots - inventory_used_slots())

func inventory_is_overloaded() -> bool:
    return inventory_used_slots() > max_slots

func can_add_item(item_id: String, amount: int = 1) -> bool:
    if amount <= 0 or not _items.has(item_id):
        return false
    var data := item_data(item_id)
    var current := inventory_count(item_id)
    var stack_max := maxi(1, int(data.get("stack", 1)))
    if current >= stack_max:
        return false
    if current > 0:
        return true
    return item_slot_cost(item_id) <= inventory_free_slots()

func add_item(item_id: String, amount: int = 1) -> bool:
    if not can_add_item(item_id, amount):
        return false
    var data := item_data(item_id)
    var current := inventory_count(item_id)
    var stack_max := maxi(1, int(data.get("stack", 1)))
    var new_amount := mini(current + amount, stack_max)
    if new_amount <= current:
        return false
    inventory[item_id] = new_amount
    inventory_changed.emit(inventory.duplicate(true))
    progression_changed.emit()
    return true

func remove_item(item_id: String, amount: int = 1) -> bool:
    var removed := super.remove_item(item_id, amount)
    if removed:
        progression_changed.emit()
    return removed

func _sanitize_inventory() -> void:
    var clean: Dictionary = {}
    for raw_id in inventory.keys():
        var item_id := str(raw_id)
        if not _items.has(item_id):
            continue
        var amount := maxi(0, int(inventory.get(raw_id, 0)))
        if amount <= 0:
            continue
        var stack_max := maxi(1, int(item_data(item_id).get("stack", 1)))
        clean[item_id] = mini(amount, stack_max)
    inventory = clean
