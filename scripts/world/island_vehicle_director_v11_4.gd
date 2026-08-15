class_name IslandVehicleDirectorV11_4
extends "res://scripts/world/island_vehicle_director.gd"

const IslandVehicleV114Script = preload("res://scripts/player/island_vehicle_v11_4.gd")
const RideAssetVisualV114Script = preload("res://assets/cc0_rides/ride_asset_visual.gd")

func _rebuild_vehicles() -> void:
    if _vehicle_root == null:
        return
    for child in _vehicle_root.get_children():
        child.queue_free()

    var info := WorldCatalog.island(_current_island - 1)
    var center: Vector3 = WorldCatalog.world_positions()[_current_island - 1]
    var island_size: Vector2 = info["size"]
    var base_specs: Array = VEHICLES[_current_island - 1]
    var specs: Array = base_specs.duplicate(true)
    specs.append_array(_mobility_specs(_current_island))

    for i in range(specs.size()):
        var spec: Dictionary = specs[i].duplicate(true)
        var vehicle_id := "ile_%02d_vehicule_%02d" % [_current_island, i + 1]
        spec["network_vehicle_id"] = vehicle_id

        var vehicle := IslandVehicleV114Script.new() as IslandVehicleV11_4
        vehicle.name = "Vehicule_%02d_%02d" % [_current_island, i + 1]
        vehicle.configure(spec)
        vehicle.set_network_vehicle_id(vehicle_id)
        _vehicle_root.add_child(vehicle)

        var ride_style := str(spec.get("style", ""))
        if ride_style in ["4x4", "horse"]:
            var upgraded_visual := RideAssetVisualV114Script.new()
            upgraded_visual.name = "CC0RideVisual"
            vehicle.add_child(upgraded_visual)

        var slot: Vector2 = VEHICLE_SLOTS[mini(i, VEHICLE_SLOTS.size() - 1)]
        var candidate := center + Vector3(slot.x, 70.0, island_size.y * slot.y)
        vehicle.global_position = _snap_to_ground(candidate) + Vector3.UP * 0.18
        vehicle.rotation.y = PI + clampf(slot.x / 180.0, -0.20, 0.20)
