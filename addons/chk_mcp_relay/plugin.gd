@tool
extends EditorPlugin

const REMOTE_URL := "wss://chk-pirate-godot-mcp.onrender.com/relay/chk-pirate-warrior-2"
const DEFAULT_LOCAL_PORT := 9080
const RECONNECT_MS := 3000
const HEARTBEAT_MS := 20000
const DISCOVERY_PATH := "res://.godot/godot-mcp.json"

var _remote := WebSocketPeer.new()
var _local := WebSocketPeer.new()
var _remote_was_open := false
var _local_was_open := false
var _last_remote_attempt := 0
var _last_local_attempt := 0
var _last_heartbeat := 0
var _local_port := DEFAULT_LOCAL_PORT


func _enter_tree() -> void:
	set_process(true)
	_local_port = _discover_local_port()
	print("[CHK MCP] Phone relay enabled. Local Godot MCP port: %d" % _local_port)
	_try_connect_remote(true)
	_try_connect_local(true)


func _exit_tree() -> void:
	set_process(false)
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_remote.close(1000, "Plugin disabled")
	if _local.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_local.close(1000, "Plugin disabled")


func _process(_delta: float) -> void:
	_remote.poll()
	_local.poll()
	_handle_state_changes()
	_drain_remote()
	_drain_local()

	var now := Time.get_ticks_msec()
	if _remote.get_ready_state() == WebSocketPeer.STATE_CLOSED and now - _last_remote_attempt >= RECONNECT_MS:
		_try_connect_remote(false)
	if _local.get_ready_state() == WebSocketPeer.STATE_CLOSED and now - _last_local_attempt >= RECONNECT_MS:
		var discovered := _discover_local_port()
		if discovered != _local_port:
			_local_port = discovered
		_try_connect_local(false)
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN and now - _last_heartbeat >= HEARTBEAT_MS:
		_last_heartbeat = now
		_send_remote({"type": "heartbeat", "at": Time.get_unix_time_from_system()})


func _handle_state_changes() -> void:
	var remote_open := _remote.get_ready_state() == WebSocketPeer.STATE_OPEN
	if remote_open and not _remote_was_open:
		print("[CHK MCP] Connected to ChatGPT relay.")
		_send_hello()
	elif not remote_open and _remote_was_open:
		print("[CHK MCP] ChatGPT relay disconnected; reconnecting automatically.")
	_remote_was_open = remote_open

	var local_open := _local.get_ready_state() == WebSocketPeer.STATE_OPEN
	if local_open and not _local_was_open:
		print("[CHK MCP] Connected to official Godot MCP on 127.0.0.1:%d." % _local_port)
	elif not local_open and _local_was_open:
		print("[CHK MCP] Official Godot MCP local connection closed; reconnecting.")
	_local_was_open = local_open


func _try_connect_remote(immediate: bool) -> void:
	if not immediate and _remote.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return
	_remote = WebSocketPeer.new()
	_remote.inbound_buffer_size = 16 * 1024 * 1024
	_remote.outbound_buffer_size = 16 * 1024 * 1024
	_last_remote_attempt = Time.get_ticks_msec()
	var err := _remote.connect_to_url(REMOTE_URL)
	if err != OK:
		print("[CHK MCP] Remote relay connection error: %s" % error_string(err))


func _try_connect_local(immediate: bool) -> void:
	if not immediate and _local.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return
	_local = WebSocketPeer.new()
	_local.inbound_buffer_size = 16 * 1024 * 1024
	_local.outbound_buffer_size = 16 * 1024 * 1024
	_last_local_attempt = Time.get_ticks_msec()
	var url := "ws://127.0.0.1:%d" % _local_port
	var err := _local.connect_to_url(url)
	if err != OK:
		print("[CHK MCP] Local MCP connection error on %s: %s" % [url, error_string(err)])


func _discover_local_port() -> int:
	if not FileAccess.file_exists(DISCOVERY_PATH):
		return DEFAULT_LOCAL_PORT
	var file := FileAccess.open(DISCOVERY_PATH, FileAccess.READ)
	if file == null:
		return DEFAULT_LOCAL_PORT
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		var port := int(data.get("port", DEFAULT_LOCAL_PORT))
		if port > 0 and port <= 65535:
			return port
	return DEFAULT_LOCAL_PORT


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
		if not payload is Dictionary:
			continue
		if _local.get_ready_state() != WebSocketPeer.STATE_OPEN:
			_send_remote({
				"type": "response",
				"payload": {
					"jsonrpc": "2.0",
					"id": payload.get("id"),
					"error": {
						"code": -32001,
						"message": "Le plugin Godot MCP officiel n'est pas encore joignable en local."
					}
				}
			})
			continue
		_local.send_text(JSON.stringify(payload))


func _drain_local() -> void:
	if _local.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	while _local.get_available_packet_count() > 0:
		var text := _local.get_packet().get_string_from_utf8()
		var payload: Variant = JSON.parse_string(text)
		if not payload is Dictionary:
			continue
		_send_remote({"type": "response", "payload": payload})


func _send_hello() -> void:
	var version := Engine.get_version_info()
	_send_remote({
		"type": "hello",
		"metadata": {
			"project": ProjectSettings.get_setting("application/config/name", "CHK Pirate Warrior 2"),
			"project_path": ProjectSettings.globalize_path("res://"),
			"godot_version": "%s.%s.%s" % [version.get("major", 0), version.get("minor", 0), version.get("patch", 0)],
			"platform": OS.get_name(),
			"model": OS.get_model_name(),
			"local_mcp_port": _local_port
		}
	})


func _send_remote(value: Dictionary) -> void:
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_remote.send_text(JSON.stringify(value))
