class_name BoardView
extends Control

signal move_attempted(from_pos: Vector2i, to_pos: Vector2i)

@export var board_color: Color = Color("d4a373") # Wooden board background
@export var line_color: Color = Color("5c3a21")  # Dark wood lines
@export var river_color: Color = Color("e9edc9") # River tint

var board_model: XiangqiBoard = null
var is_flipped: bool = false # True when playing as Black (Black at bottom)
var player_color: XiangqiTypes.PieceColor = XiangqiTypes.PieceColor.RED
var is_interactable: bool = true

var selected_pos: Vector2i = Vector2i(-1, -1)
var legal_moves: Array[XiangqiTypes.Move] = []
var last_move: XiangqiTypes.Move = null
var in_check_pos: Vector2i = Vector2i(-1, -1)

# Dynamic sizing for responsive layouts
var cell_size: float = 64.0
var board_offset: Vector2 = Vector2.ZERO
var piece_radius: float = 28.0

var piece_views: Dictionary = {} # Vector2i -> PieceView
var piece_view_scene: PackedScene = null

var board_texture: Texture2D = null

func _ready() -> void:
	add_to_group("board_view")
	if ResourceLoader.exists("res://assets/sprites/board_wood.png"):
		board_texture = load("res://assets/sprites/board_wood.png") as Texture2D
	custom_minimum_size = Vector2(600, 700)
	resized.connect(_on_resized)
	_on_resized()

func get_board_global_rect() -> Rect2:
	var total_w: float = cell_size * 8.0
	var total_h: float = cell_size * 9.0
	var pad_x: float = total_w * (55.0 / 1010.0)
	var pad_y: float = total_h * (55.0 / 1150.0)
	var local_board_rect := Rect2(board_offset - Vector2(pad_x, pad_y), Vector2(total_w + pad_x * 2.0, total_h + pad_y * 2.0))
	var global_pos := global_position + local_board_rect.position
	return Rect2(global_pos, local_board_rect.size)

func get_square_global_pos(pos: Vector2i) -> Vector2:
	return global_position + grid_to_pixel(pos)

func setup_board(model: XiangqiBoard, p_color: XiangqiTypes.PieceColor = XiangqiTypes.PieceColor.RED) -> void:
	board_model = model
	player_color = p_color
	is_flipped = (player_color == XiangqiTypes.PieceColor.BLACK)
	selected_pos = Vector2i(-1, -1)
	legal_moves.clear()
	last_move = null
	in_check_pos = Vector2i(-1, -1)
	rebuild_all_pieces()
	queue_redraw()

func _on_resized() -> void:
	var available_w: float = size.x - 40.0
	var available_h: float = size.y - 40.0

	var max_cell_w: float = available_w / 8.0
	var max_cell_h: float = available_h / 9.0

	cell_size = minf(max_cell_w, max_cell_h)
	piece_radius = cell_size * 0.44

	var total_w: float = cell_size * 8.0
	var total_h: float = cell_size * 9.0
	board_offset = Vector2((size.x - total_w) / 2.0, (size.y - total_h) / 2.0)

	reposition_all_pieces_instant()
	queue_redraw()

func grid_to_pixel(pos: Vector2i) -> Vector2:
	var visual_x: float = float(pos.x if not is_flipped else (8 - pos.x))
	# Internal y=0 is Red (bottom), y=9 is Black (top)
	# Screen Y=0 is top, screen Y=max is bottom
	var visual_y: float = float((9 - pos.y) if not is_flipped else pos.y)
	return board_offset + Vector2(visual_x * cell_size, visual_y * cell_size)

func pixel_to_grid(pixel: Vector2) -> Vector2i:
	var local: Vector2 = pixel - board_offset
	var gx: int = int(round(local.x / cell_size))
	var gy: int = int(round(local.y / cell_size))

	if gx < 0 or gx > 8 or gy < 0 or gy > 9:
		return Vector2i(-1, -1)

	var actual_x: int = gx if not is_flipped else (8 - gx)
	var actual_y: int = (9 - gy) if not is_flipped else gy
	return Vector2i(actual_x, actual_y)

func rebuild_all_pieces() -> void:
	for pv in piece_views.values():
		if is_instance_valid(pv):
			pv.queue_free()
	piece_views.clear()

	if board_model == null:
		return

	for y in range(XiangqiConstants.BOARD_ROWS):
		for x in range(XiangqiConstants.BOARD_COLS):
			var pos := Vector2i(x, y)
			var p: XiangqiTypes.Piece = board_model.get_piece(pos)
			if p != null:
				_spawn_piece_view(pos, p)

func _spawn_piece_view(pos: Vector2i, piece: XiangqiTypes.Piece) -> PieceView:
	var pv := PieceView.new()
	add_child(pv)
	pv.setup(piece, pos, piece_radius)
	pv.position = grid_to_pixel(pos)
	piece_views[pos] = pv
	return pv

func reposition_all_pieces_instant() -> void:
	for pos in piece_views.keys():
		var pv: PieceView = piece_views[pos]
		if is_instance_valid(pv):
			pv.radius = piece_radius
			pv.position = grid_to_pixel(pos)
			pv.queue_redraw()

func apply_move_visual(from_pos: Vector2i, to_pos: Vector2i, captured: XiangqiTypes.Piece, on_finish: Callable = Callable()) -> void:
	last_move = XiangqiTypes.Move.new(from_pos, to_pos)

	if captured != null:
		AudioManager.play_capture_sound()
	else:
		AudioManager.play_move_sound()

	if piece_views.has(to_pos):
		var target_pv: PieceView = piece_views[to_pos]
		piece_views.erase(to_pos)
		target_pv.animate_capture_fade(func():
			target_pv.queue_free()
		)

	if piece_views.has(from_pos):
		var mover_pv: PieceView = piece_views[from_pos]
		piece_views.erase(from_pos)
		piece_views[to_pos] = mover_pv
		mover_pv.grid_pos = to_pos
		mover_pv.animate_to_pixel(grid_to_pixel(to_pos), 0.22, on_finish)
	else:
		if on_finish.is_valid():
			on_finish.call()

	clear_selection()
	queue_redraw()

func update_check_highlight(in_check: bool, turn_color: XiangqiTypes.PieceColor) -> void:
	if in_check and board_model != null:
		in_check_pos = board_model.find_king(turn_color)
	else:
		in_check_pos = Vector2i(-1, -1)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not is_interactable or board_model == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_board_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_board_tap(event.position)

func _handle_board_tap(pixel_pos: Vector2) -> void:
	var clicked_grid := pixel_to_grid(pixel_pos)
	if clicked_grid.x == -1:
		clear_selection()
		return

	# If a piece is already selected, check if clicked square is a legal destination
	if selected_pos.x != -1:
		for m in legal_moves:
			if m.to == clicked_grid:
				move_attempted.emit(selected_pos, clicked_grid)
				clear_selection()
				return

	# Otherwise, select piece if it belongs to current player
	var piece := board_model.get_piece(clicked_grid)
	if piece != null and piece.color == board_model.turn and piece.color == player_color:
		_select_square(clicked_grid)
	else:
		clear_selection()

func _select_square(pos: Vector2i) -> void:
	selected_pos = pos
	legal_moves.clear()

	var all_legal := board_model.generate_legal_moves(player_color)
	for m in all_legal:
		if m.from == pos:
			legal_moves.append(m)

	for p in piece_views.keys():
		piece_views[p].set_selected(p == pos)

	AudioManager.play_select_sound()
	queue_redraw()

func clear_selection() -> void:
	selected_pos = Vector2i(-1, -1)
	legal_moves.clear()
	for p in piece_views.keys():
		if is_instance_valid(piece_views[p]):
			piece_views[p].set_selected(false)
	queue_redraw()

func _draw() -> void:
	# 1. Background board wood
	var pad_x: float = cell_size * 8.0 * (55.0 / 1010.0)
	var pad_y: float = cell_size * 9.0 * (55.0 / 1150.0)
	var board_rect := Rect2(board_offset - Vector2(pad_x, pad_y), Vector2(cell_size * 8.0 + pad_x * 2.0, cell_size * 9.0 + pad_y * 2.0))

	if board_texture != null:
		draw_texture_rect(board_texture, board_rect, false)
	else:
		# Procedural fallback
		draw_rect(board_rect, board_color, true)
		draw_rect(board_rect, line_color, false, 4.0)

		var inner_rect := Rect2(board_offset, Vector2(cell_size * 8, cell_size * 9))
		draw_rect(inner_rect, line_color, false, 2.0)

		# Horizontal lines (10 lines)
		for y in range(10):
			var start := grid_to_pixel(Vector2i(0, y if not is_flipped else 9 - y))
			var end := grid_to_pixel(Vector2i(8, y if not is_flipped else 9 - y))
			draw_line(start, end, line_color, 2.0)

		# Vertical lines
		for x in range(9):
			if x == 0 or x == 8:
				var start := grid_to_pixel(Vector2i(x, 0 if not is_flipped else 9))
				var end := grid_to_pixel(Vector2i(x, 9 if not is_flipped else 0))
				draw_line(start, end, line_color, 2.0)
			else:
				var b_start := grid_to_pixel(Vector2i(x, 0))
				var b_end := grid_to_pixel(Vector2i(x, 4))
				draw_line(b_start, b_end, line_color, 2.0)
				var t_start := grid_to_pixel(Vector2i(x, 5))
				var t_end := grid_to_pixel(Vector2i(x, 9))
				draw_line(t_start, t_end, line_color, 2.0)

		# Palaces
		draw_line(grid_to_pixel(Vector2i(3, 0)), grid_to_pixel(Vector2i(5, 2)), line_color, 2.0)
		draw_line(grid_to_pixel(Vector2i(5, 0)), grid_to_pixel(Vector2i(3, 2)), line_color, 2.0)
		draw_line(grid_to_pixel(Vector2i(3, 7)), grid_to_pixel(Vector2i(5, 9)), line_color, 2.0)
		draw_line(grid_to_pixel(Vector2i(5, 7)), grid_to_pixel(Vector2i(3, 9)), line_color, 2.0)

	# 2. Last Move Indicators
	if last_move != null:
		var from_px := grid_to_pixel(last_move.from)
		var to_px := grid_to_pixel(last_move.to)
		var rect_s := cell_size * 0.88
		draw_rect(Rect2(from_px - Vector2(rect_s/2, rect_s/2), Vector2(rect_s, rect_s)), Color(0.2, 0.6, 1.0, 0.3), true)
		draw_rect(Rect2(to_px - Vector2(rect_s/2, rect_s/2), Vector2(rect_s, rect_s)), Color(0.2, 0.6, 1.0, 0.4), true)
		draw_rect(Rect2(to_px - Vector2(rect_s/2, rect_s/2), Vector2(rect_s, rect_s)), Color(0.2, 0.7, 1.0, 0.85), false, 2.5)

	# 3. Check Warning Highlight
	if in_check_pos.x != -1:
		var king_px := grid_to_pixel(in_check_pos)
		draw_circle(king_px, piece_radius + 6.0, Color(1.0, 0.1, 0.1, 0.38))
		draw_arc(king_px, piece_radius + 6.0, 0, TAU, 36, Color("e74c3c"), 3.5)

	# 4. Legal Move Dots & Capture Rings
	for m in legal_moves:
		var dest_px := grid_to_pixel(m.to)
		var target := board_model.get_piece(m.to) if board_model != null else null
		if target != null:
			# Capture indicator ring
			draw_circle(dest_px, piece_radius + 4.0, Color(0.9, 0.2, 0.2, 0.25))
			draw_arc(dest_px, piece_radius + 4.0, 0, TAU, 32, Color(0.95, 0.2, 0.2, 0.95), 3.5)
		else:
			# Move destination green dot
			draw_circle(dest_px, cell_size * 0.16, Color(0.15, 0.85, 0.35, 0.85))
			draw_arc(dest_px, cell_size * 0.16, 0, TAU, 24, Color(1.0, 1.0, 1.0, 0.7), 1.5)

