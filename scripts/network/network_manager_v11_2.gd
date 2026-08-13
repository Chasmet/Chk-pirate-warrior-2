class_name NetworkManagerV11_2
extends "res://scripts/network/network_manager_v10.gd"

signal host_migration_started(candidate_name: String)
signal host_migration_completed(new_host_name: String)

var _migration_active := false

func migration_active() -> bool:
    return _migration_active
