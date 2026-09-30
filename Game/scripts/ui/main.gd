class_name MainController
extends Control

@onready var main_menu: MainMenu = $MainMenu
@onready var game_view: GameView = $GameView
@onready var matchmaking_lobby: MatchmakingLobby = $MatchmakingLobby
@onready var settings_dialog: SettingsDialog = $SettingsDialog
@onready var cutscene_overlay: CutsceneOverlay = $CutsceneOverlay

# Unified Custom Room Dialog
@onready var custom_room_dialog: Control = $CustomRoomDialog
@onready var room_pin_display: Label = $CustomRoomDialog/Panel/VBoxContainer/SectionHost/HBox/RoomPinDisplay
@onready var create_or_copy_button: Button = $CustomRoomDialog/Panel/VBoxContainer/SectionHost/HBox/CreateOrCopyButton
@onready var host_status_label: Label = $CustomRoomDialog/Panel/VBoxContainer/SectionHost/HostStatusLabel
@onready var room_code_input: LineEdit = $CustomRoomDialog/Panel/VBoxContainer/SectionJoin/HBox/RoomCodeInput
@onready var join_room_button: Button = $CustomRoomDialog/Panel/VBoxContainer/SectionJoin/HBox/JoinButton
@onready var close_room_dialog_button: Button = $CustomRoomDialog/Panel/VBoxContainer/BottomHBox/CloseButton

var current_created_room_pin: String = ""

func _ready() -> void:
	_show_main_menu()

	main_menu.play_pve_requested.connect(_on_play_pve)
	main_menu.play_online_queue_requested.connect(_on_play_online_queue)
	main_menu.custom_room_requested.connect(_on_open_custom_room_dialog)
	main_menu.settings_requested.connect(func(): settings_dialog.visible = true)
	main_menu.exit_requested.connect(_on_exit_game)

	matchmaking_lobby.cancel_requested.connect(_on_cancel_lobby)
	game_view.back_to_menu_requested.connect(_show_main_menu)

	create_or_copy_button.pressed.connect(_on_create_or_copy_pin)
	join_room_button.pressed.connect(_on_join_room_confirmed)
	close_room_dialog_button.pressed.connect(_on_close_custom_room_dialog)
	room_code_input.text_submitted.connect(func(_text: String): _on_join_room_confirmed())

	_setup_network_handlers()

func _show_main_menu() -> void:
	main_menu.visible = true
	game_view.visible = false
	matchmaking_lobby.visible = false
	settings_dialog.visible = false
	custom_room_dialog.visible = false

func _on_exit_game() -> void:
	print("[MAIN] User requested exit")
	get_tree().quit()

func _on_play_pve() -> void:
	main_menu.visible = false
	matchmaking_lobby.visible = false
	game_view.visible = true
	game_view.start_pve_game(XiangqiTypes.PieceColor.RED)

func _on_play_online_queue() -> void:
	NetworkManager.connect_to_server()
	main_menu.visible = false
	matchmaking_lobby.show_queue_mode(1)

func _on_open_custom_room_dialog() -> void:
	custom_room_dialog.visible = true
	current_created_room_pin = ""
	room_pin_display.text = "------"
	create_or_copy_button.text = "🎲 Tạo Mã"
	host_status_label.text = "Bấm 'Tạo Mã' để lấy PIN gửi đối thủ"
	room_code_input.text = ""
	
	# Auto-focus input field
	get_tree().create_timer(0.05).timeout.connect(func():
		room_code_input.grab_focus()
	)

func _on_create_or_copy_pin() -> void:
	if current_created_room_pin != "":
		# Already created -> Copy PIN to clipboard
		DisplayServer.clipboard_set(current_created_room_pin)
		host_status_label.text = "📋 Đã sao chép mã [" + current_created_room_pin + "] vào bộ nhớ tạm!"
		return

	# Request room creation from server
	host_status_label.text = "⏳ Đang tạo phòng..."
	if NetworkManager.is_connected:
		NetworkManager.create_custom_room()
	else:
		NetworkManager.connect_to_server()
		NetworkManager.connected_to_server.connect(func():
			NetworkManager.create_custom_room()
		, CONNECT_ONE_SHOT)

func _on_join_room_confirmed() -> void:
	var code := room_code_input.text.strip_edges().to_upper()
	if code.length() >= 4:
		print("[MAIN] User joining room: ", code)
		custom_room_dialog.visible = false
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

func _on_close_custom_room_dialog() -> void:
	if current_created_room_pin != "":
		NetworkManager.cancel_queue()
		current_created_room_pin = ""
	custom_room_dialog.visible = false

func _on_cancel_lobby() -> void:
	print("[MAIN] User cancelled lobby")
	NetworkManager.cancel_queue()
	current_created_room_pin = ""
	_show_main_menu()

func _setup_network_handlers() -> void:
	NetworkManager.queue_joined.connect(func(size: int):
		matchmaking_lobby.show_queue_mode(size)
	)

	NetworkManager.room_created.connect(func(code: String, is_custom: bool):
		if is_custom and custom_room_dialog.visible:
			current_created_room_pin = code
			room_pin_display.text = code
			create_or_copy_button.text = "📋 Sao Chép"
			host_status_label.text = "✅ Đã tạo! Đang chờ bạn bè kết nối..."
			DisplayServer.clipboard_set(code)
		else:
			main_menu.visible = false
			matchmaking_lobby.show_created_room(code)
	)

	NetworkManager.match_found.connect(func(data: Dictionary):
		custom_room_dialog.visible = false
		matchmaking_lobby.visible = false
		main_menu.visible = false
		game_view.visible = true
		game_view.start_pvp_online_game(data)
	)

	NetworkManager.reconnected.connect(func(data: Dictionary):
		custom_room_dialog.visible = false
		matchmaking_lobby.visible = false
		main_menu.visible = false
		game_view.visible = true
		game_view.start_pvp_online_game(data)
	)
