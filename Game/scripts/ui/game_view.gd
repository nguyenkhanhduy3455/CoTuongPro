class_name GameView
extends Control

enum GameMode {
	PVE,
	PVP_ONLINE
}

@export var mode: GameMode = GameMode.PVE

@onready var board_view: BoardView = $BoardContainer/BoardView
@onready var top_name_label: Label = $TopPlayerHUD/HBoxContainer/VBoxContainer/NameLabel
@onready var top_bank_label: Label = $TopPlayerHUD/HBoxContainer/TimeContainer/BankLabel
@onready var top_turn_label: Label = $TopPlayerHUD/HBoxContainer/TimeContainer/TurnLabel
@onready var top_status_label: Label = $TopPlayerHUD/HBoxContainer/VBoxContainer/StatusLabel
@onready var top_turn_progress: ProgressBar = $TopPlayerHUD/HBoxContainer/VBoxContainer/TurnProgressBar

@onready var bottom_name_label: Label = $BottomPlayerHUD/HBoxContainer/VBoxContainer/NameLabel
@onready var bottom_bank_label: Label = $BottomPlayerHUD/HBoxContainer/TimeContainer/BankLabel
@onready var bottom_turn_label: Label = $BottomPlayerHUD/HBoxContainer/TimeContainer/TurnLabel
@onready var bottom_status_label: Label = $BottomPlayerHUD/HBoxContainer/VBoxContainer/StatusLabel
@onready var bottom_turn_progress: ProgressBar = $BottomPlayerHUD/HBoxContainer/VBoxContainer/TurnProgressBar

var _fill_style_top: StyleBoxFlat = StyleBoxFlat.new()
var _fill_style_bottom: StyleBoxFlat = StyleBoxFlat.new()
var _bg_style_top: StyleBoxFlat = StyleBoxFlat.new()
var _bg_style_bottom: StyleBoxFlat = StyleBoxFlat.new()

@onready var resign_button: Button = $ActionBar/ResignButton
@onready var draw_button: Button = $ActionBar/DrawButton
@onready var game_over_dialog: Control = $GameOverDialog
@onready var game_over_title: Label = $GameOverDialog/Panel/VBoxContainer/TitleLabel
@onready var game_over_subtitle: Label = $GameOverDialog/Panel/VBoxContainer/SubtitleLabel

var board: XiangqiBoard = null
var ai_engine: AIEngine = null
var my_color: XiangqiTypes.PieceColor = XiangqiTypes.PieceColor.RED
var opponent_color: XiangqiTypes.PieceColor = XiangqiTypes.PieceColor.BLACK

var red_bank_seconds: float = 600.0
var black_bank_seconds: float = 600.0
var current_turn_seconds: float = 30.0
var is_game_active: bool = false
var online_match_id: String = ""

signal back_to_menu_requested()

func _ready() -> void:
	ai_engine = AIEngine.new()
	ai_engine.move_ready.connect(_on_ai_move_ready)

	board_view.move_attempted.connect(_on_player_move_attempted)
	resign_button.pressed.connect(_on_resign_pressed)
	draw_button.pressed.connect(_on_draw_pressed)

	$ActionBar/MenuButton.pressed.connect(func(): back_to_menu_requested.emit())
	$GameOverDialog/Panel/VBoxContainer/MenuButton.pressed.connect(func(): back_to_menu_requested.emit())
	$GameOverDialog/Panel/VBoxContainer/RematchButton.pressed.connect(_on_rematch_pressed)

	_setup_progress_bar_styles()
	_setup_network_signals()

func _process(delta: float) -> void:
	if not is_game_active or board == null:
		return

	# Update local turn countdown & bank
	current_turn_seconds = maxf(0.0, current_turn_seconds - delta)
	if board.turn == XiangqiTypes.PieceColor.RED:
		red_bank_seconds = maxf(0.0, red_bank_seconds - delta)
	else:
		black_bank_seconds = maxf(0.0, black_bank_seconds - delta)

	_update_hud_clocks()

	# Offline timeout check
	if mode == GameMode.PVE:
		if current_turn_seconds <= 0.0 or (board.turn == XiangqiTypes.PieceColor.RED and red_bank_seconds <= 0.0) or (board.turn == XiangqiTypes.PieceColor.BLACK and black_bank_seconds <= 0.0):
			var winner := XiangqiTypes.PieceColor.BLACK if board.turn == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED
			_end_game(winner, "Hết thời gian (Timeout)")

func start_pve_game(p_color: XiangqiTypes.PieceColor = XiangqiTypes.PieceColor.RED) -> void:
	mode = GameMode.PVE
	my_color = p_color
	opponent_color = XiangqiTypes.PieceColor.BLACK if my_color == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED
	online_match_id = ""

	board = XiangqiBoard.new()
	board_view.setup_board(board, my_color)
	game_over_dialog.visible = false

	red_bank_seconds = 600.0
	black_bank_seconds = 600.0
	current_turn_seconds = 30.0
	is_game_active = true

	top_name_label.text = "Máy AI (" + _get_difficulty_name() + ")"
	bottom_name_label.text = GameConfig.player_name
	_update_hud_clocks()

	if board.turn != my_color:
		_trigger_ai_move()

func start_pvp_online_game(match_data: Dictionary) -> void:
	mode = GameMode.PVP_ONLINE
	online_match_id = match_data.get("matchId", "")
	var role_str: String = match_data.get("role", "RED")
	my_color = XiangqiTypes.PieceColor.RED if role_str == "RED" else XiangqiTypes.PieceColor.BLACK
	opponent_color = XiangqiTypes.PieceColor.BLACK if my_color == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED

	board = XiangqiBoard.new()
	var fen: String = match_data.get("fen", "")
	if not fen.is_empty():
		board.load_fen(fen)

	board_view.setup_board(board, my_color)
	game_over_dialog.visible = false

	var time_cfg: Dictionary = match_data.get("timeConfig", {})
	red_bank_seconds = float(time_cfg.get("totalBankSeconds", 600))
	black_bank_seconds = float(time_cfg.get("totalBankSeconds", 600))
	current_turn_seconds = float(time_cfg.get("turnLimitSeconds", 30))
	is_game_active = true

	top_name_label.text = match_data.get("opponentName", "Đối thủ")
	bottom_name_label.text = GameConfig.player_name
	_update_hud_clocks()

func _setup_network_signals() -> void:
	NetworkManager.move_applied.connect(_on_network_move_applied)
	NetworkManager.match_over.connect(_on_network_match_over)
	NetworkManager.opponent_status.connect(_on_network_opponent_status)
	NetworkManager.draw_offered.connect(_on_network_draw_offered)

func _on_player_move_attempted(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if not is_game_active or board == null:
		return

	if board.turn != my_color:
		return

	if mode == GameMode.PVE:
		var piece := board.get_piece(from_pos)
		var target := board.get_piece(to_pos)
		var res := board.make_move(XiangqiTypes.Move.new(from_pos, to_pos))
		if res.valid:
			current_turn_seconds = 30.0
			board_view.apply_move_visual(from_pos, to_pos, res.captured)
			board_view.update_check_highlight(res.is_check, res.next_turn)

			if res.is_checkmate:
				_end_game(my_color, "Chiếu bí đối phương (Checkmate)")
			elif res.is_stalemate:
				_end_game(my_color, "Đối phương hết nước đi (Stalemate)")
			else:
				_trigger_ai_move()

			CutsceneManager.trigger_move_cutscene(
				piece,
				target,
				res.is_check,
				res.is_checkmate,
				res.is_block_check,
				to_pos
			)

	elif mode == GameMode.PVP_ONLINE:
		# Send move to authoritative server
		NetworkManager.send_move(online_match_id, from_pos, to_pos)

func _trigger_ai_move() -> void:
	if not is_game_active or board == null or board.turn != opponent_color:
		return

	top_status_label.text = "Đang tính nước đi..."
	ai_engine.start_calculation_threaded(board, GameConfig.ai_difficulty, opponent_color)

func _on_ai_move_ready(move: XiangqiTypes.Move, _score: int) -> void:
	top_status_label.text = ""
	if not is_game_active or move == null or board == null:
		return

	var piece := board.get_piece(move.from)
	var target := board.get_piece(move.to)
	var res := board.make_move(move)

	if res.valid:
		current_turn_seconds = 30.0
		board_view.apply_move_visual(move.from, move.to, res.captured)
		board_view.update_check_highlight(res.is_check, res.next_turn)

		if res.is_checkmate:
			_end_game(opponent_color, "Máy AI chiếu bí (Checkmate)")
		elif res.is_stalemate:
			_end_game(opponent_color, "Bạn hết nước đi (Stalemate)")

		CutsceneManager.trigger_move_cutscene(
			piece,
			target,
			res.is_check,
			res.is_checkmate,
			res.is_block_check,
			move.to
		)

func _on_network_move_applied(data: Dictionary) -> void:
	if not is_game_active or board == null:
		return

	var from_arr: Array = data.get("from", [0, 0])
	var to_arr: Array = data.get("to", [0, 0])
	var from_p := Vector2i(int(from_arr[0]), int(from_arr[1]))
	var to_p := Vector2i(int(to_arr[0]), int(to_arr[1]))

	var is_check: bool = data.get("isCheck", false)
	var is_checkmate: bool = data.get("isCheckmate", false)
	var is_block_check: bool = data.get("isBlockCheck", false)
	var next_turn_str: String = data.get("nextTurn", "BLACK")

	var piece := board.get_piece(from_p)
	var target := board.get_piece(to_p)

	# Update board state
	board.set_piece(to_p, piece)
	board.set_piece(from_p, null)
	board.turn = XiangqiTypes.PieceColor.RED if next_turn_str == "RED" else XiangqiTypes.PieceColor.BLACK

	# Update Clocks
	var time_rem: Dictionary = data.get("timeRemaining", {})
	red_bank_seconds = float(time_rem.get("redTimeRemainingMs", 600000)) / 1000.0
	black_bank_seconds = float(time_rem.get("blackTimeRemainingMs", 600000)) / 1000.0
	current_turn_seconds = float(time_rem.get("currentTurnTimeRemainingMs", 30000)) / 1000.0

	board_view.apply_move_visual(from_p, to_p, target)
	board_view.update_check_highlight(is_check, board.turn)

	CutsceneManager.trigger_move_cutscene(
		piece,
		target,
		is_check,
		is_checkmate,
		is_block_check,
		to_p
	)

func _on_network_match_over(data: Dictionary) -> void:
	var winner_str: String = data.get("winner", "")
	var reason_str: String = data.get("reason", "")
	var winner := XiangqiTypes.PieceColor.RED if winner_str == "RED" else XiangqiTypes.PieceColor.BLACK

	var display_reason := reason_str
	match reason_str:
		"CHECKMATE": display_reason = "Chiếu bí (Checkmate)"
		"TIMEOUT": display_reason = "Hết thời gian (Timeout)"
		"RESIGN": display_reason = "Đầu hàng (Resignation)"
		"DISCONNECT_TIMEOUT": display_reason = "Mất kết nối quá 60s"
		"DRAW_AGREED": display_reason = "Hòa theo thỏa thuận"
		"STALEMATE": display_reason = "Hết nước đi (Stalemate)"

	_end_game(winner, display_reason, winner_str == "DRAW")

func _on_network_opponent_status(data: Dictionary) -> void:
	var status: String = data.get("status", "")
	if status == "DISCONNECTED":
		top_status_label.text = "⚠️ Mất kết nối (Chờ 60s...)"
	elif status == "RECONNECTED":
		top_status_label.text = "✅ Đã kết nối lại"
		get_tree().create_timer(3.0).timeout.connect(func(): top_status_label.text = "")

func _on_network_draw_offered(_data: Dictionary) -> void:
	# Show draw proposal prompt
	var confirm := ConfirmationDialog.new()
	confirm.title = "Cầu hòa"
	confirm.dialog_text = "Đối thủ xin hòa ván cờ, bạn có đồng ý?"
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(func():
		NetworkManager.respond_draw(online_match_id, true)
		confirm.queue_free()
	)
	confirm.canceled.connect(func():
		NetworkManager.respond_draw(online_match_id, false)
		confirm.queue_free()
	)

func _on_resign_pressed() -> void:
	if not is_game_active:
		return
	if mode == GameMode.PVE:
		_end_game(opponent_color, "Bạn đã đầu hàng")
	else:
		NetworkManager.resign(online_match_id)

func _on_draw_pressed() -> void:
	if not is_game_active:
		return
	if mode == GameMode.PVE:
		top_status_label.text = "Máy AI từ chối hòa!"
		get_tree().create_timer(2.0).timeout.connect(func(): top_status_label.text = "")
	else:
		NetworkManager.offer_draw(online_match_id)

func _on_rematch_pressed() -> void:
	if mode == GameMode.PVE:
		start_pve_game(my_color)
	else:
		back_to_menu_requested.emit()

func _end_game(winner: XiangqiTypes.PieceColor, reason: String, is_draw: bool = false) -> void:
	is_game_active = false
	game_over_dialog.visible = true

	if is_draw:
		game_over_title.text = "🤝 HÒA CỜ"
		game_over_title.modulate = Color("f1c40f")
	elif winner == my_color:
		game_over_title.text = "🏆 CHIẾN THẮNG!"
		game_over_title.modulate = Color("2ecc71")
	else:
		game_over_title.text = "💀 THẤT BẠI"
		game_over_title.modulate = Color("e74c3c")

	game_over_subtitle.text = reason

func _setup_progress_bar_styles() -> void:
	_fill_style_top.set_corner_radius_all(4)
	_fill_style_bottom.set_corner_radius_all(4)
	_bg_style_top.set_corner_radius_all(4)
	_bg_style_bottom.set_corner_radius_all(4)
	_bg_style_top.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	_bg_style_bottom.bg_color = Color(0.12, 0.14, 0.18, 0.9)

	top_turn_progress.add_theme_stylebox_override("fill", _fill_style_top)
	top_turn_progress.add_theme_stylebox_override("background", _bg_style_top)
	bottom_turn_progress.add_theme_stylebox_override("fill", _fill_style_bottom)
	bottom_turn_progress.add_theme_stylebox_override("background", _bg_style_bottom)

func _update_hud_clocks() -> void:
	var my_bank: float = red_bank_seconds if my_color == XiangqiTypes.PieceColor.RED else black_bank_seconds
	var opp_bank: float = black_bank_seconds if my_color == XiangqiTypes.PieceColor.RED else red_bank_seconds

	bottom_bank_label.text = _format_time(my_bank)
	top_bank_label.text = _format_time(opp_bank)

	var turn_str := "Lượt: " + str(int(ceil(current_turn_seconds))) + "s"
	var turn_color := Color("2ecc71") # Mặc định xanh lá
	if current_turn_seconds < 5.0:
		turn_color = Color("e74c3c") # Dưới 5s: Đỏ
	elif current_turn_seconds <= 10.0:
		turn_color = Color("f1c40f") # Dưới hoặc bằng 10s: Vàng

	var is_my_turn := (board != null and board.turn == my_color)
	if is_my_turn:
		bottom_turn_label.text = turn_str
		bottom_turn_label.add_theme_color_override("font_color", turn_color)
		top_turn_label.text = ""
	else:
		top_turn_label.text = turn_str
		top_turn_label.add_theme_color_override("font_color", turn_color)
		bottom_turn_label.text = ""

	_update_turn_progress(bottom_turn_progress, _fill_style_bottom, current_turn_seconds, is_my_turn)
	_update_turn_progress(top_turn_progress, _fill_style_top, current_turn_seconds, not is_my_turn)

func _update_turn_progress(p_bar: ProgressBar, fill_style: StyleBoxFlat, seconds_left: float, is_active: bool) -> void:
	if not is_active or not is_game_active:
		p_bar.visible = false
		p_bar.value = 0.0
		return

	p_bar.visible = true
	p_bar.max_value = 30.0
	p_bar.value = clampf(seconds_left, 0.0, 30.0)

	# Đổi màu theo yêu cầu: dưới 5s đỏ, còn <= 10s vàng, bình thường xanh
	if seconds_left < 5.0:
		fill_style.bg_color = Color("e74c3c") # Đỏ
	elif seconds_left <= 10.0:
		fill_style.bg_color = Color("f1c40f") # Vàng
	else:
		fill_style.bg_color = Color("2ecc71") # Xanh lá

func _format_time(seconds: float) -> String:
	var s: int = int(seconds)
	var m: int = s / 60
	s = s % 60
	return "%02d:%02d" % [m, s]

func _get_difficulty_name() -> String:
	match GameConfig.ai_difficulty:
		XiangqiTypes.AIDifficulty.EASY: return "Dễ"
		XiangqiTypes.AIDifficulty.MEDIUM: return "Trung bình"
		XiangqiTypes.AIDifficulty.HARD: return "Khó"
	return "Trung bình"
