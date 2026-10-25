@tool
extends EditorPlugin

# This editor-only bridge calls the project's official godot_mcp addon on
# localhost and maintains ONE outbound WSS session with the owner's MCP server.
# Token and server URL are saved only in res://.godot (ignored by Git).
const CONFIG_PATH := "res://.godot/chk_direct_mcp.json"
const DISCOVERY_PATH := "res://.godot/godot-mcp.json"
const RECONNECT_MS := 3000
const HEARTBEAT_MS := 20000

var _remote := WebSocketPeer.new()
var _local := WebSocketPeer.new()
var _remote_was_open := false
var _local_was_open := false
var _last_remote_attempt := 0
var _last_local_attempt := 0
var _last_heartbeat := 0
var _local_port := 9080
var _base_url := ""
var _editor_key := ""
var _panel: VBoxContainer
var _url_input: LineEdit
var _key_input: LineEdit
var _status_label: Label


func _enter_tree() -> void:
	_load_config()
	_build_panel()
	_local_port = _discover_local_port()
	set_process(true)
	_try_connect_local()
	_try_connect_remote()


func _exit_tree() -> void:
	set_process(false)
	if _panel != null:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_remote.close(1000, "Plugin disabled")
	if _local.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_local.close(1000, "Plugin disabled")


func _build_panel() -> void:
	_panel = VBoxContainer.new()
	_panel.name = "CHK Direct"
	var heading := Label.new()
	heading.text = "CHK Godot Direct MCP"
	_panel.add_child(heading)

	var explanation := Label.new()
	explanation.text = "HTTPS public et jeton Editeur du serveur separe. Aucun Supabase ou Render."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(explanation)

	_url_input = LineEdit.new()
	_url_input.placeholder_text = "https://votre-domaine-ou-tailnet"
	_url_input.text = _base_url
	_panel.add_child(_url_input)

	_key_input = LineEdit.new()
	_key_input.placeholder_text = "Jeton EDITEUR (pas le jeton ChatGPT)"
	_key_input.secret = true
	_key_input.text = _editor_key
	_panel.add_child(_key_input)

	var button := Button.new()
	button.text = "Enregistrer et connecter"
	button.pressed.connect(_save_and_connect)
	_panel.add_child(button)

	_status_label = Label.new()
	_status_label.text = "Etat: configuration requise"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_status_label)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _panel)


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_base_url = String(parsed.get("server_url", ""))
		_editor_key = String(parsed.get("editor_token", ""))


func _save_and_connect() -> void:
	var url := _url_input.text.strip_edges().trim_suffix("/")
	var key := _key_input.text.strip_edges()
	if not (url.begins_with("https://") or url.begins_with("wss://")):
		_status_label.text = "Erreur: HTTPS/WSS public obligatoire."
		return
	if key.length() < 48 or url.contains("@") or url.contains("?") or url.contains("#"):
		_status_label.text = "Erreur: jeton prive 48+ caracteres ou URL incorrecte."
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://.godot")):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot"))
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		_status_label.text = "Erreur: impossible d'enregistrer dans .godot"
		return
	file.store_string(JSON.stringify({"server_url": url, "editor_token": key}))
	file.close()
	_base_url = url
	_editor_key = key
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_remote.close(1000, "Settings updated")
	_remote = WebSocketPeer.new()
	_last_remote_attempt = 0
	_try_connect_remote()
	_status_label.text = "Configuration privee enregistree. Connexion en cours..."


func _process(_delta: float) -> void:
	_remote.poll()
	_local.poll()
	var remote_open := _remote.get_ready_state() == WebSocketPeer.STATE_OPEN
	var local_open := _local.get_ready_state() == WebSocketPeer.STATE_OPEN

	if remote_open and not _remote_was_open:
		_send_hello()
	if not remote_open and _remote_was_open:
		_status_label.text = "Deconnecte du serveur public; reconnexion..."
	if local_open and not _local_was_open:
		_status_label.text = "Godot MCP local connecte."
	_remote_was_open = remote_open
	_local_was_open = local_open

	_drain_remote()
	_drain_local()
	var tick := Time.get_ticks_msec()
	if _remote.get_ready_state() == WebSocketPeer.STATE_CLOSED and tick - _last_remote_attempt >= RECONNECT_MS:
		_try_connect_remote()
	if _local.get_ready_state() == WebSocketPeer.STATE_CLOSED and tick - _last_local_attempt >= RECONNECT_MS:
		_local_port = _discover_local_port()
		_try_connect_local()
	if remote_open and tick - _last_heartbeat >= HEARTBEAT_MS:
		_last_heartbeat = tick
		_send_remote({"type": "heartbeat", "at": Time.get_unix_time_from_system()})
	if remote_open and local_open:
		_status_label.text = "CONNECTE: ChatGPT peut piloter cet editeur Godot."
	elif remote_open:
		_status_label.text = "Relais public connecte; en attente de Godot MCP local."


func _try_connect_remote() -> void:
	if _base_url.is_empty() or _editor_key.length() < 48:
		return
	if _remote.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return
	_last_remote_attempt = Time.get_ticks_msec()
	var ws_url := _base_url.replace("https://", "wss://").trim_suffix("/")
	_remote = WebSocketPeer.new()
	_remote.inbound_buffer_size = 2 * 1024 * 1024
	_remote.outbound_buffer_size = 2 * 1024 * 1024
	var result := _remote.connect_to_url(ws_url + "/relay/godot/" + _editor_key)
	if result != OK:
		_status_label.text = "Connexion HTTPS impossible: " + error_string(result)


func _try_connect_local() -> void:
	if _local.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		return
	_last_local_attempt = Time.get_ticks_msec()
	_local = WebSocketPeer.new()
	_local.inbound_buffer_size = 2 * 1024 * 1024
	_local.outbound_buffer_size = 2 * 1024 * 1024
	var result := _local.connect_to_url("ws://127.0.0.1:%d" % _local_port)
	if result != OK:
		_status_label.text = "Godot MCP local indisponible: " + error_string(result)


func _discover_local_port() -> int:
	if not FileAccess.file_exists(DISCOVERY_PATH):
		return 9080
	var file := FileAccess.open(DISCOVERY_PATH, FileAccess.READ)
	if file == null:
		return 9080
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		var port := int(data.get("port", 9080))
		if port >= 1 and port <= 65535:
			return port
	return 9080


func _drain_remote() -> void:
	if _remote.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	while _remote.get_available_packet_count() > 0:
		var message: Variant = JSON.parse_string(_remote.get_packet().get_string_from_utf8())
		if not message is Dictionary or String(message.get("type", "")) != "request":
			continue
		var payload: Variant = message.get("payload")
		if not payload is Dictionary:
			continue
		if _local.get_ready_state() != WebSocketPeer.STATE_OPEN:
			_send_remote({
				"type": "response",
				"payload": {
					"jsonrpc": "2.0", "id": payload.get("id"),
					"error": {"code": -32001, "message": "Godot MCP officiel hors ligne"}
				}
			})
			continue
		_local.send_text(JSON.stringify(payload))


func _drain_local() -> void:
	if _local.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	while _local.get_available_packet_count() > 0:
		var message: Variant = JSON.parse_string(_local.get_packet().get_string_from_utf8())
		if message is Dictionary:
			_send_remote({"type": "response", "payload": message})


func _send_hello() -> void:
	var version := Engine.get_version_info()
	_send_remote({
		"type": "hello",
		"metadata": {
			"project": ProjectSettings.get_setting("application/config/name", "Godot"),
			"godot_version": "%s.%s.%s" % [version.get("major", 0), version.get("minor", 0), version.get("patch", 0)],
			"platform": OS.get_name(),
			"model": OS.get_model_name()
		}
	})


func _send_remote(value: Dictionary) -> void:
	if _remote.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_remote.send_text(JSON.stringify(value))
