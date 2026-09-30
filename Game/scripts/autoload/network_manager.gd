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

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			is_connected = false
			connection_closed.emit()
			if auto_reconnect and not active_match_id.is_empty():
				reconnect_timer = 2.0 # Try reconnect in 2 seconds

		if reconnect_timer > 0.0:
			reconnect_timer -= delta
			if reconnect_timer <= 0.0:
				connect_to_server()
		return

	socket.poll()
	var state := socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			connected_to_server.emit()
			# If reconnecting an active match, send RECONNECT
			if not active_match_id.is_empty():
				reconnect_session(GameConfig.player_id)

		while socket.get_available_packet_count() > 0:
			var raw := socket.get_packet().get_string_from_utf8()
			_handle_raw_message(raw)

	elif state == WebSocketPeer.STATE_CLOSING:
		pass

func connect_to_server(custom_url: String = "") -> void:
	var url := custom_url if not custom_url.is_empty() else GameConfig.server_url
	var uri := url + "?playerId=" + GameConfig.player_id + "&name=" + GameConfig.player_name.uri_encode()

	socket.close()
	var err := socket.connect_to_url(uri)
	if err != OK:
		connection_error.emit("Failed to initiate connection: " + str(err))

func disconnect_from_server() -> void:
	auto_reconnect = false
	active_match_id = ""
	socket.close()
	is_connected = false

func send_action(action_dict: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
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
	var parsed: Variant = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
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
			room_created.emit(payload.get("roomCode", ""), payload.get("isCustom", true))

		"ROOM_JOINED":
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
			error_received.emit(payload.get("message", "Unknown error"), payload.get("code", ""))
