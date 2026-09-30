class_name MainController
extends Control

@onready var main_menu: MainMenu = $MainMenu
@onready var game_view: GameView = $GameView
@onready var matchmaking_lobby: MatchmakingLobby = $MatchmakingLobby
@onready var settings_dialog: SettingsDialog = $SettingsDialog
@onready var cutscene_overlay: CutsceneOverlay = $CutsceneOverlay
@onready var join_room_dialog: ConfirmationDialog = $JoinRoomDialog
@onready var room_code_input: LineEdit = $JoinRoomDialog/RoomCodeInput

func _ready() -> void:
	_show_main_menu()

	main_menu.play_pve_requested.connect(_on_play_pve)
	main_menu.play_online_queue_requested.connect(_on_play_online_queue)
	main_menu.create_room_requested.connect(_on_create_room)
	main_menu.join_room_requested.connect(_on_open_join_modal)
	main_menu.settings_requested.connect(func(): settings_dialog.visible = true)

	matchmaking_lobby.cancel_requested.connect(_on_cancel_lobby)
	game_view.back_to_menu_requested.connect(_show_main_menu)

	join_room_dialog.confirmed.connect(_on_join_room_confirmed)

	_setup_network_handlers()

func _show_main_menu() -> void:
	main_menu.visible = true
	game_view.visible = false
	matchmaking_lobby.visible = false
	settings_dialog.visible = false

func _on_play_pve() -> void:
	main_menu.visible = false
	matchmaking_lobby.visible = false
	game_view.visible = true
	game_view.start_pve_game(XiangqiTypes.PieceColor.RED)

func _on_play_online_queue() -> void:
	NetworkManager.connect_to_server()
	main_menu.visible = false
	matchmaking_lobby.show_queue_mode(1)

func _on_create_room() -> void:
	print("[MAIN] User clicked 'Tạo phòng riêng'")
	main_menu.visible = false
	matchmaking_lobby.visible = true
	matchmaking_lobby.show_queue_mode(1)

	if NetworkManager.is_connected:
		print("[MAIN] Socket already open, sending ROOM_CREATE")
		NetworkManager.create_custom_room()
	else:
		print("[MAIN] Socket connecting, waiting for connected_to_server signal...")
		NetworkManager.connect_to_server()
		NetworkManager.connected_to_server.connect(func():
			print("[MAIN] Connection established! Sending ROOM_CREATE...")
			NetworkManager.create_custom_room()
		, CONNECT_ONE_SHOT)

func _on_open_join_modal() -> void:
	room_code_input.text = ""
	join_room_dialog.popup_centered()

func _on_join_room_confirmed() -> void:
	var code := room_code_input.text.strip_edges().to_upper()
	if code.length() >= 4:
		print("[MAIN] User joining room: ", code)
		main_menu.visible = false
		matchmaking_lobby.visible = true
		matchmaking_lobby.show_queue_mode(1)

		if NetworkManager.is_connected:
			NetworkManager.join_custom_room(code)
		else:
			NetworkManager.connect_to_server()
			NetworkManager.connected_to_server.connect(func():
				NetworkManager.join_custom_room(code)
			, CONNECT_ONE_SHOT)

func _on_cancel_lobby() -> void:
	print("[MAIN] User cancelled lobby")
	NetworkManager.cancel_queue()
	_show_main_menu()

func _setup_network_handlers() -> void:
	NetworkManager.queue_joined.connect(func(size: int):
		matchmaking_lobby.show_queue_mode(size)
	)

	NetworkManager.room_created.connect(func(code: String, _is_custom: bool):
		main_menu.visible = false
		matchmaking_lobby.show_created_room(code)
	)

	NetworkManager.match_found.connect(func(data: Dictionary):
		matchmaking_lobby.visible = false
		main_menu.visible = false
		game_view.visible = true
		game_view.start_pvp_online_game(data)
	)

	NetworkManager.reconnected.connect(func(data: Dictionary):
		matchmaking_lobby.visible = false
		main_menu.visible = false
		game_view.visible = true
		game_view.start_pvp_online_game(data)
	)
