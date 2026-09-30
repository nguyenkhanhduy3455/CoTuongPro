class_name NetworkManagerAutoload
extends Node

signal connected_to_server()
signal connection_closed()
signal connection_error(message: String)

signal queue_joined(queue_size: int)
signal queue_cancelled()
signal room_created(room_code: String, is_custom: bool)
signal room_joined(room_code: String, role: String)
signal spectator_joined(data: Dictionary)
signal match_found(data: Dictionary)
signal move_applied(data: Dictionary)
signal match_over(data: Dictionary)
signal opponent_status(data: Dictionary)
signal draw_offered(data: Dictionary)
signal draw_resolved(data: Dictionary)
signal reconnected(data: Dictionary)
signal error_received(message: String, code: String)

var socket := WebSocketPeer.new()
var is_connected: bool = false
var active_match_id: String = ""
var auto_reconnect: bool = true
var reconnect_timer: float = 0.0

var _candidate_urls: Array[String] = []
var _candidate_index: int = 0
var _connecting_timeout: float = 0.0

func _ready() -> void:
	pass

func _get_candidate_urls(custom_url: String = "") -> Array[String]:
	var list: Array[String] = []
	if not custom_url.is_empty():
		list.append(custom_url)
	elif not GameConfig.server_url.is_empty() and not GameConfig.server_url.contains("127.0.0.1") and not GameConfig.server_url.contains("localhost"):
		list.append(GameConfig.server_url)

	if OS.get_name() == "Android":
		if not list.has("ws://10.0.2.2:8080/ws"):
			list.append("ws://10.0.2.2:8080/ws")
		if not list.has("ws://192.168.1.15:8080/ws"):
			list.append("ws://192.168.1.15:8080/ws")
		if not list.has("ws://127.0.0.1:8080/ws"):
			list.append("ws://127.0.0.1:8080/ws")
	else:
		if not list.has("ws://127.0.0.1:8080/ws"):
			list.append("ws://127.0.0.1:8080/ws")
		if not list.has("ws://192.168.1.15:8080/ws"):
			list.append("ws://192.168.1.15:8080/ws")

	return list

func _process(delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		_connecting_timeout = 0.0
		if not is_connected:
			is_connected = true
			var connected_url := _candidate_urls[_candidate_index] if _candidate_index < _candidate_urls.size() else "unknown"
			print("[NET] *** Connected successfully to Server endpoint: ", connected_url, " ***")
			connected_to_server.emit()
			if not active_match_id.is_empty():
				reconnect_session(GameConfig.player_id)

		while socket.get_available_packet_count() > 0:
			var raw := socket.get_packet().get_string_from_utf8()
			_handle_raw_message(raw)

	elif state == WebSocketPeer.STATE_CONNECTING:
		_connecting_timeout += delta
		if _connecting_timeout > 3.0:
			print("[NET] Connection timed out on candidate ", _candidate_index, " -> trying next")
			socket.close()
			_try_next_candidate()

	elif state == WebSocketPeer.STATE_CLOSED:
		_connecting_timeout = 0.0
		if is_connected:
			is_connected = false
			print("[NET] WebSocket connection closed. Code: ", socket.get_close_code(), " Reason: ", socket.get_close_reason())
			connection_closed.emit()
			if auto_reconnect and not active_match_id.is_empty():
				reconnect_timer = 2.0
		elif _candidate_urls.size() > 0 and _candidate_index < _candidate_urls.size() - 1:
			_try_next_candidate()

		if reconnect_timer > 0.0:
			reconnect_timer -= delta
			if reconnect_timer <= 0.0:
				connect_to_server()

func _try_next_candidate() -> void:
	_candidate_index += 1
	if _candidate_index < _candidate_urls.size():
		_connect_candidate(_candidate_index)
	else:
		print("[NET] All candidate URLs failed to connect.")
		connection_error.emit("Không thể kết nối đến server cờ tướng.")

func connect_to_server(custom_url: String = "") -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		is_connected = true
		connected_to_server.emit()
		return
	if socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		return

	_candidate_urls = _get_candidate_urls(custom_url)
	_candidate_index = 0
	_connect_candidate(0)

func _connect_candidate(idx: int) -> void:
	if idx >= _candidate_urls.size():
		return
	var base_url := _candidate_urls[idx]
	var uri := base_url + "?playerId=" + GameConfig.player_id + "&name=" + GameConfig.player_name.uri_encode()

	_connecting_timeout = 0.0
	socket.close()
	var err := socket.connect_to_url(uri)
	if err != OK:
		print("[NET] connect_to_url error for [", uri, "]: ", err)
		if idx < _candidate_urls.size() - 1:
			_try_next_candidate()
		else:
			connection_error.emit("Failed to connect: " + str(err))
	else:
		print("[NET] Initiating connection to [", idx, "]: ", uri)

func disconnect_from_server() -> void:
	auto_reconnect = false
	active_match_id = ""
	socket.close()
	is_connected = false

func send_action(action_dict: Dictionary) -> void:
	var state := socket.get_ready_state()
	print("[NET] Sending action: ", action_dict.get("action", ""), " (Socket state: ", state, ")")
	if state != WebSocketPeer.STATE_OPEN:
		print("[NET] WARN: Socket not in OPEN state (state=", state, "), cannot send action.")
		return
	var json_str := JSON.stringify(action_dict)
	socket.send_text(json_str)

# --- High-level Client Actions ---

func find_match(total_bank: int = 600, turn_limit: int = 30) -> void:
	send_action({
		"action": "QUEUE_FIND_MATCH",
		"name": GameConfig.player_name,
		"timeConfig": {
			"totalBankSeconds": total_bank,
			"turnLimitSeconds": turn_limit
		}
	})

func cancel_queue() -> void:
	send_action({ "action": "QUEUE_CANCEL" })

func create_custom_room(total_bank: int = 600, turn_limit: int = 30) -> void:
	send_action({
		"action": "ROOM_CREATE",
		"name": GameConfig.player_name,
		"timeConfig": {
			"totalBankSeconds": total_bank,
			"turnLimitSeconds": turn_limit
		}
	})

func join_custom_room(room_code: String) -> void:
	send_action({
		"action": "ROOM_JOIN",
		"roomCode": room_code.to_upper().strip_edges(),
		"name": GameConfig.player_name
	})

func send_move(match_id: String, from_pos: Vector2i, to_pos: Vector2i) -> void:
	send_action({
		"action": "MAKE_MOVE",
		"matchId": match_id,
		"from": [from_pos.x, from_pos.y],
		"to": [to_pos.x, to_pos.y]
	})

func resign(match_id: String) -> void:
	send_action({
		"action": "RESIGN",
		"matchId": match_id
	})

func offer_draw(match_id: String) -> void:
	send_action({
		"action": "OFFER_DRAW",
		"matchId": match_id
	})

func respond_draw(match_id: String, accepted: bool) -> void:
	send_action({
		"action": "RESPOND_DRAW",
		"matchId": match_id,
		"accepted": accepted
	})

func reconnect_session(player_id: String) -> void:
	send_action({
		"action": "RECONNECT",
		"playerId": player_id
	})

# --- Server Event Router ---

func _handle_raw_message(json_str: String) -> void:
	print("[NET] Received message from server: ", json_str)
	var parsed: Variant = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[NET] WARN: Message was not a JSON dictionary")
		return

	var dict: Dictionary = parsed
	var event_type: String = dict.get("event", "")
	var payload: Dictionary = dict.get("payload", {})

	match event_type:
		"QUEUE_JOINED":
			queue_joined.emit(payload.get("queueSize", 1))

		"QUEUE_CANCELLED":
			queue_cancelled.emit()

		"ROOM_CREATED":
			print("[NET] >>> ROOM_CREATED event received: roomCode=", payload.get("roomCode", ""))
			room_created.emit(payload.get("roomCode", ""), payload.get("isCustom", true))

		"ROOM_JOINED":
			print("[NET] >>> ROOM_JOINED event received: ", payload)
			room_joined.emit(payload.get("roomCode", ""), payload.get("role", "PLAYER"))

		"SPECTATOR_JOINED":
			spectator_joined.emit(payload)

		"MATCH_FOUND":
			active_match_id = payload.get("matchId", "")
			match_found.emit(payload)

		"MOVE_APPLIED":
			move_applied.emit(payload)

		"MATCH_OVER":
			active_match_id = ""
			match_over.emit(payload)

		"OPPONENT_STATUS":
			opponent_status.emit(payload)

		"DRAW_OFFERED":
			draw_offered.emit(payload)

		"DRAW_RESOLVED":
			draw_resolved.emit(payload)

		"RECONNECTED":
			active_match_id = payload.get("matchId", "")
			reconnected.emit(payload)

		"ERROR":
			print("[NET] Server error received: ", payload)
			error_received.emit(payload.get("message", "Unknown error"), payload.get("code", ""))
