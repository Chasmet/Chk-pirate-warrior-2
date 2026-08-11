@tool
extends Node

const BRIDGE_NAME := "GoddoCloudBridge"


func _enter_tree() -> void:
	call_deferred("_install_bridge")


func _install_bridge() -> void:
	var base := EditorInterface.get_base_control()
	if base == null:
		push_error("[Goddo Cloud MCP] Editor base control is unavailable.")
		return
	if base.get_node_or_null(BRIDGE_NAME) != null:
		return
	var bridge := preload("res://cloud-godot/cloud_bridge.gd").new()
	bridge.name = BRIDGE_NAME
	base.add_child(bridge)
	print("[Goddo Cloud MCP] Persistent bridge installed in editor tree.")
