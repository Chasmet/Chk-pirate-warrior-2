@tool
extends Node

const REMOTE_URL := "wss://chk-pirate-godot-mcp.onrender.com/relay/godot"
const RECONNECT_MS := 3000
const HEARTBEAT_MS := 20000

var _remote := WebSocketPeer.new()
var _remote_was_open := false
var _last_remote_attempt := 0
var _last_heartbeat := 0
var _router: Node = null
var _editor_proxy: EditorPlugin = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_editor_proxy = preload("res://cloud-godot/cloud_editor_proxy.gd").new()
	_editor_proxy.name = "GoddoCloudEditorProxy"
	add_child(_editor_proxy)

	_router = preload("res://addons/godot_mcp/command_router.gd").new()
	_router.name = "GoddoCloudCommandRouter"
	_router.editor_plugin = _editor_proxy
	add_child(_router)

	print("[Goddo Cloud MCP] Direct router booted.")
	_try_connect_remote(true)


func _process(_delta: float) -> void:
	_remote.poll()
	_handle_state_change()
	_drain_remote()

	var now := Time.get_ticks_msec()
	if _remote.get_ready_state() == WebSocketPeer.STATE_CLOSED and now - _last_remote_attempt >= RECONNECT_MS:
		_try_connect_remote(false)
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN and now - _last_heartbeat >= HEARTBEAT_MS:
		_last_heartbeat = now
		_send_remote({"type": "heartbeat", "at": Time.get_unix_time_from_system()})


func _try_connect_remote(immediate: bool) -> void:
	if not immediate and _remote.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return
	_remote = WebSocketPeer.new()
	_remote.inbound_buffer_size = 16 * 1024 * 1024
	_remote.outbound_buffer_size = 16 * 1024 * 1024
	_last_remote_attempt = Time.get_ticks_msec()
	var err := _remote.connect_to_url(REMOTE_URL)
	if err != OK:
		print("[Goddo Cloud MCP] Relay connect error: %s" % error_string(err))


func _handle_state_change() -> void:
	var open := _remote.get_ready_state() == WebSocketPeer.STATE_OPEN
	if open and not _remote_was_open:
		print("[Goddo Cloud MCP] Connected to ChatGPT relay.")
		_send_hello()
	elif not open and _remote_was_open:
		print("[Goddo Cloud MCP] Relay disconnected; reconnecting.")
	_remote_was_open = open


func _drain_remote() -> void:
	if _remote.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	while _remote.get_available_packet_count() > 0:
		var text := _remote.get_packet().get_string_from_utf8()
		var msg: Variant = JSON.parse_string(text)
		if not msg is Dictionary:
			continue
		var kind := String(msg.get("type", ""))
		if kind == "ping":
			_send_remote({"type": "heartbeat", "at": Time.get_unix_time_from_system()})
			continue
		if kind != "request":
			continue
		var payload: Variant = msg.get("payload")
		if payload is Dictionary:
			_execute_request.call_deferred(payload)


func _execute_request(payload: Dictionary) -> void:
	var id: Variant = payload.get("id")
	var method := String(payload.get("method", ""))
	var raw_params: Variant = payload.get("params", {})
	var params: Dictionary = raw_params if raw_params is Dictionary else {}
	var response: Dictionary = {"jsonrpc": "2.0", "id": id}

	if method.is_empty():
		response["error"] = {"code": -32600, "message": "Missing method"}
	elif _router == null:
		response["error"] = {"code": -32603, "message": "Cloud command router not ready"}
	else:
		var routed: Dictionary = await _router.execute(method, params)
		if routed.has("error"):
			response["error"] = routed["error"]
		else:
			response["result"] = routed.get("result", {})

	_send_remote({"type": "response", "payload": response})


func _send_hello() -> void:
	var version := Engine.get_version_info()
	_send_remote({
		"type": "hello",
		"metadata": {
			"project": ProjectSettings.get_setting("application/config/name", "Projet Godot"),
			"project_path": ProjectSettings.globalize_path("res://"),
			"godot_version": "%s.%s.%s" % [version.get("major", 0), version.get("minor", 0), version.get("patch", 0)],
			"platform": "Linux Cloud",
			"model": "Render / Goddo Internet",
			"local_mcp_port": 0,
			"mode": "cloud-direct-router"
		}
	})


func _send_remote(value: Dictionary) -> void:
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_remote.send_text(JSON.stringify(value))
