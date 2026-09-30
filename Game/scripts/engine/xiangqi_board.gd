class_name XiangqiBoard
extends RefCounted

var grid: Array[Array] = []
var turn: XiangqiTypes.PieceColor = XiangqiTypes.PieceColor.RED
var move_history: Array[XiangqiTypes.DetailedMove] = []

func _init() -> void:
	_init_empty_grid()
	setup_initial_position()

func _init_empty_grid() -> void:
	grid.clear()
	for y in range(XiangqiConstants.BOARD_ROWS):
		var row: Array = []
		for x in range(XiangqiConstants.BOARD_COLS):
			row.append(null)
		grid.append(row)

func clear() -> void:
	for y in range(XiangqiConstants.BOARD_ROWS):
		for x in range(XiangqiConstants.BOARD_COLS):
			grid[y][x] = null
	turn = XiangqiTypes.PieceColor.RED
	move_history.clear()

func setup_initial_position() -> void:
	load_fen(XiangqiConstants.INITIAL_FEN)

func get_piece(pos: Vector2i) -> XiangqiTypes.Piece:
	if not XiangqiConstants.is_inside_board(pos):
		return null
	return grid[pos.y][pos.x]

func set_piece(pos: Vector2i, piece: XiangqiTypes.Piece) -> void:
	if not XiangqiConstants.is_inside_board(pos):
		return
	grid[pos.y][pos.x] = piece

func clone() -> XiangqiBoard:
	var cloned := XiangqiBoard.new()
	cloned.clear()
	for y in range(XiangqiConstants.BOARD_ROWS):
		for x in range(XiangqiConstants.BOARD_COLS):
			var p: XiangqiTypes.Piece = grid[y][x]
			if p != null:
				cloned.grid[y][x] = p.duplicate_piece()
	cloned.turn = turn
	for m in move_history:
		cloned.move_history.append(m)
	return cloned

func find_king(color: XiangqiTypes.PieceColor) -> Vector2i:
	for y in range(XiangqiConstants.BOARD_ROWS):
		for x in range(XiangqiConstants.BOARD_COLS):
			var p: XiangqiTypes.Piece = grid[y][x]
			if p != null and p.type == XiangqiTypes.PieceType.KING and p.color == color:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func are_kings_facing() -> bool:
	var red_king := find_king(XiangqiTypes.PieceColor.RED)
	var black_king := find_king(XiangqiTypes.PieceColor.BLACK)

	if red_king.x == -1 or black_king.x == -1:
		return false
	if red_king.x != black_king.x:
		return false

	var col: int = red_king.x
	var min_y: int = mini(red_king.y, black_king.y)
	var max_y: int = maxi(red_king.y, black_king.y)

	for y in range(min_y + 1, max_y):
		if grid[y][col] != null:
			return false
	return true

func count_intervening_pieces(from_pos: Vector2i, to_pos: Vector2i) -> int:
	var count: int = 0
	if from_pos.x == to_pos.x:
		var step: int = 1 if from_pos.y < to_pos.y else -1
		var y: int = from_pos.y + step
		while y != to_pos.y:
			if grid[y][from_pos.x] != null:
				count += 1
			y += step
	elif from_pos.y == to_pos.y:
		var step: int = 1 if from_pos.x < to_pos.x else -1
		var x: int = from_pos.x + step
		while x != to_pos.x:
			if grid[from_pos.y][x] != null:
				count += 1
			x += step
	return count

func is_pseudo_legal_move(move: XiangqiTypes.Move) -> Dictionary:
	var from_p := move.from
	var to_p := move.to

	if not XiangqiConstants.is_inside_board(from_p) or not XiangqiConstants.is_inside_board(to_p):
		return {"valid": false, "reason": "Outside board"}
	if from_p == to_p:
		return {"valid": false, "reason": "Origin and target are the same"}

	var piece: XiangqiTypes.Piece = grid[from_p.y][from_p.x]
	if piece == null:
		return {"valid": false, "reason": "No piece at source"}

	var dest_piece: XiangqiTypes.Piece = grid[to_p.y][to_p.x]
	if dest_piece != null and dest_piece.color == piece.color:
		return {"valid": false, "reason": "Cannot capture friendly piece"}

	var dx: int = to_p.x - from_p.x
	var dy: int = to_p.y - from_p.y
	var abs_dx: int = absi(dx)
	var abs_dy: int = absi(dy)

	match piece.type:
		XiangqiTypes.PieceType.KING:
			if (abs_dx == 1 and abs_dy == 0) or (abs_dx == 0 and abs_dy == 1):
				if not XiangqiConstants.is_in_palace(to_p, piece.color):
					return {"valid": false, "reason": "King must stay in palace"}
				return {"valid": true}
			return {"valid": false, "reason": "Invalid King geometry"}

		XiangqiTypes.PieceType.ADVISOR:
			if abs_dx == 1 and abs_dy == 1:
				if not XiangqiConstants.is_in_palace(to_p, piece.color):
					return {"valid": false, "reason": "Advisor must stay in palace"}
				return {"valid": true}
			return {"valid": false, "reason": "Invalid Advisor geometry"}

		XiangqiTypes.PieceType.ELEPHANT:
			if abs_dx == 2 and abs_dy == 2:
				if piece.color == XiangqiTypes.PieceColor.RED and to_p.y > XiangqiConstants.RED_RIVER_Y_MAX:
					return {"valid": false, "reason": "Red Elephant cannot cross river"}
				if piece.color == XiangqiTypes.PieceColor.BLACK and to_p.y < XiangqiConstants.BLACK_RIVER_Y_MIN:
					return {"valid": false, "reason": "Black Elephant cannot cross river"}
				var eye_x: int = from_p.x + dx / 2
				var eye_y: int = from_p.y + dy / 2
				if grid[eye_y][eye_x] != null:
					return {"valid": false, "reason": "Elephant eye is blocked (cản tượng)"}
				return {"valid": true}
			return {"valid": false, "reason": "Invalid Elephant geometry"}

		XiangqiTypes.PieceType.HORSE:
			if (abs_dx == 1 and abs_dy == 2) or (abs_dx == 2 and abs_dy == 1):
				var foot_x: int = from_p.x
				var foot_y: int = from_p.y
				if abs_dy == 2:
					foot_y = from_p.y + dy / 2
				else:
					foot_x = from_p.x + dx / 2
				if grid[foot_y][foot_x] != null:
					return {"valid": false, "reason": "Horse foot is blocked (cản chân mã)"}
				return {"valid": true}
			return {"valid": false, "reason": "Invalid Horse geometry"}

		XiangqiTypes.PieceType.ROOK:
			if from_p.x == to_p.x or from_p.y == to_p.y:
				if count_intervening_pieces(from_p, to_p) == 0:
					return {"valid": true}
				return {"valid": false, "reason": "Rook path is blocked"}
			return {"valid": false, "reason": "Rook must move orthogonally"}

		XiangqiTypes.PieceType.CANNON:
			if from_p.x == to_p.x or from_p.y == to_p.y:
				var screens: int = count_intervening_pieces(from_p, to_p)
				if dest_piece == null:
					if screens == 0:
						return {"valid": true}
					return {"valid": false, "reason": "Cannon path is blocked"}
				else:
					if screens == 1:
						return {"valid": true}
					return {"valid": false, "reason": "Cannon needs exactly 1 screen to capture"}
			return {"valid": false, "reason": "Cannon must move orthogonally"}

		XiangqiTypes.PieceType.PAWN:
			var forward_step: int = 1 if piece.color == XiangqiTypes.PieceColor.RED else -1
			var crossed: bool = XiangqiConstants.has_crossed_river(from_p.y, piece.color)

			if dx == 0 and dy == forward_step:
				return {"valid": true}
			if crossed and abs_dx == 1 and dy == 0:
				return {"valid": true}
			return {"valid": false, "reason": "Invalid Pawn geometry"}

	return {"valid": false, "reason": "Unknown piece"}

func is_king_in_check(color: XiangqiTypes.PieceColor) -> bool:
	var king_pos := find_king(color)
	if king_pos.x == -1:
		return true

	if are_kings_facing():
		return true

	var opponent_color: XiangqiTypes.PieceColor = (
		XiangqiTypes.PieceColor.BLACK if color == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED
	)

	for y in range(XiangqiConstants.BOARD_ROWS):
		for x in range(XiangqiConstants.BOARD_COLS):
			var piece: XiangqiTypes.Piece = grid[y][x]
			if piece != null and piece.color == opponent_color:
				var res := is_pseudo_legal_move(XiangqiTypes.Move.new(Vector2i(x, y), king_pos))
				if res["valid"]:
					return true
	return false

func generate_pseudo_legal_moves(color: XiangqiTypes.PieceColor) -> Array[XiangqiTypes.Move]:
	var moves: Array[XiangqiTypes.Move] = []
	for from_y in range(XiangqiConstants.BOARD_ROWS):
		for from_x in range(XiangqiConstants.BOARD_COLS):
			var piece: XiangqiTypes.Piece = grid[from_y][from_x]
			if piece == null or piece.color != color:
				continue

			var from_p := Vector2i(from_x, from_y)

			match piece.type:
				XiangqiTypes.PieceType.KING:
					var offsets := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
					for off in offsets:
						var to_p: Vector2i = from_p + off
						var m := XiangqiTypes.Move.new(from_p, to_p)
						if is_pseudo_legal_move(m)["valid"]:
							moves.append(m)

				XiangqiTypes.PieceType.ADVISOR:
					var offsets := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
					for off in offsets:
						var to_p: Vector2i = from_p + off
						var m := XiangqiTypes.Move.new(from_p, to_p)
						if is_pseudo_legal_move(m)["valid"]:
							moves.append(m)

				XiangqiTypes.PieceType.ELEPHANT:
					var offsets := [Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(-2, -2)]
					for off in offsets:
						var to_p: Vector2i = from_p + off
						var m := XiangqiTypes.Move.new(from_p, to_p)
						if is_pseudo_legal_move(m)["valid"]:
							moves.append(m)

				XiangqiTypes.PieceType.HORSE:
					var offsets := [
						Vector2i(1, 2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(-1, -2),
						Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-2, -1)
					]
					for off in offsets:
						var to_p: Vector2i = from_p + off
						var m := XiangqiTypes.Move.new(from_p, to_p)
						if is_pseudo_legal_move(m)["valid"]:
							moves.append(m)

				XiangqiTypes.PieceType.ROOK, XiangqiTypes.PieceType.CANNON:
					var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
					for d in dirs:
						var next_p: Vector2i = from_p + d
						while XiangqiConstants.is_inside_board(next_p):
							var m := XiangqiTypes.Move.new(from_p, next_p)
							if is_pseudo_legal_move(m)["valid"]:
								moves.append(m)
							if piece.type == XiangqiTypes.PieceType.ROOK and grid[next_p.y][next_p.x] != null:
								break
							next_p += d

				XiangqiTypes.PieceType.PAWN:
					var forward: int = 1 if piece.color == XiangqiTypes.PieceColor.RED else -1
					var offsets := [Vector2i(0, forward), Vector2i(1, 0), Vector2i(-1, 0)]
					for off in offsets:
						var to_p: Vector2i = from_p + off
						var m := XiangqiTypes.Move.new(from_p, to_p)
						if is_pseudo_legal_move(m)["valid"]:
							moves.append(m)

	return moves

func generate_legal_moves(color: XiangqiTypes.PieceColor) -> Array[XiangqiTypes.Move]:
	var pseudo_moves := generate_pseudo_legal_moves(color)
	var legal_moves: Array[XiangqiTypes.Move] = []

	for move in pseudo_moves:
		var from_p := move.from
		var to_p := move.to

		var saved_from: XiangqiTypes.Piece = grid[from_p.y][from_p.x]
		var saved_to: XiangqiTypes.Piece = grid[to_p.y][to_p.x]

		# Speculative move
		grid[to_p.y][to_p.x] = saved_from
		grid[from_p.y][from_p.x] = null

		var in_check: bool = is_king_in_check(color)

		# Rollback
		grid[from_p.y][from_p.x] = saved_from
		grid[to_p.y][to_p.x] = saved_to

		if not in_check:
			legal_moves.append(move)

	return legal_moves

func make_move(move: XiangqiTypes.Move) -> XiangqiTypes.MoveResult:
	var result := XiangqiTypes.MoveResult.new()
	var from_p := move.from
	var to_p := move.to

	var piece := get_piece(from_p)
	if piece == null:
		result.valid = false
		result.error = "No piece at origin"
		return result

	if piece.color != turn:
		result.valid = false
		result.error = "Not your turn"
		return result

	var pseudo := is_pseudo_legal_move(move)
	if not pseudo["valid"]:
		result.valid = false
		result.error = pseudo.get("reason", "Invalid move")
		return result

	var was_in_check: bool = is_king_in_check(turn)
	var target_piece := get_piece(to_p)

	# Apply move speculatively
	grid[to_p.y][to_p.x] = piece
	grid[from_p.y][from_p.x] = null

	if is_king_in_check(turn):
		# Revert
		grid[from_p.y][from_p.x] = piece
		grid[to_p.y][to_p.x] = target_piece
		result.valid = false
		result.error = "Move leaves King in check"
		return result

	var uci := XiangqiConstants.move_to_uci(from_p, to_p)
	move_history.append(
		XiangqiTypes.DetailedMove.new(
			from_p,
			to_p,
			piece.duplicate_piece(),
			target_piece.duplicate_piece() if target_piece != null else null,
			uci
		)
	)

	var next_turn: XiangqiTypes.PieceColor = (
		XiangqiTypes.PieceColor.BLACK if turn == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED
	)
	turn = next_turn

	var is_check: bool = is_king_in_check(next_turn)
	var opponent_legal := generate_legal_moves(next_turn)

	var is_checkmate: bool = false
	var is_stalemate: bool = false

	if opponent_legal.is_empty():
		if is_check:
			is_checkmate = true
		else:
			is_stalemate = true

	var is_block_check: bool = was_in_check and not is_king_in_check(piece.color)

	result.valid = true
	result.captured = target_piece
	result.is_check = is_check
	result.is_checkmate = is_checkmate
	result.is_stalemate = is_stalemate
	result.is_block_check = is_block_check
	result.next_turn = next_turn
	result.uci = uci

	return result

func get_game_status() -> XiangqiTypes.GameStatus:
	var in_check := is_king_in_check(turn)
	var legal := generate_legal_moves(turn)
	if legal.is_empty():
		return XiangqiTypes.GameStatus.CHECKMATE if in_check else XiangqiTypes.GameStatus.STALEMATE
	return XiangqiTypes.GameStatus.CHECK if in_check else XiangqiTypes.GameStatus.PLAYING

func load_fen(fen: String) -> void:
	clear()
	var parts := fen.strip_edges().split(" ")
	var board_part: String = parts[0]
	var turn_part: String = parts[1] if parts.size() > 1 else "w"

	var rows := board_part.split("/")
	if rows.size() != XiangqiConstants.BOARD_ROWS:
		return

	for r in range(XiangqiConstants.BOARD_ROWS):
		var y: int = 9 - r
		var row_str: String = rows[r]
		var x: int = 0
		for i in range(row_str.length()):
			var c: String = row_str.substr(i, 1)
			if c.is_valid_int():
				x += c.to_int()
			else:
				var piece := _create_piece_from_char(c)
				if piece != null and x < XiangqiConstants.BOARD_COLS:
					grid[y][x] = piece
					x += 1

	turn = XiangqiTypes.PieceColor.BLACK if turn_part.to_lower() == "b" else XiangqiTypes.PieceColor.RED

func _create_piece_from_char(c: String) -> XiangqiTypes.Piece:
	match c:
		"K": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.KING, XiangqiTypes.PieceColor.RED)
		"A": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.ADVISOR, XiangqiTypes.PieceColor.RED)
		"B", "E": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.ELEPHANT, XiangqiTypes.PieceColor.RED)
		"N", "H": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.HORSE, XiangqiTypes.PieceColor.RED)
		"R": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.ROOK, XiangqiTypes.PieceColor.RED)
		"C": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.CANNON, XiangqiTypes.PieceColor.RED)
		"P": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.PAWN, XiangqiTypes.PieceColor.RED)
		"k": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.KING, XiangqiTypes.PieceColor.BLACK)
		"a": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.ADVISOR, XiangqiTypes.PieceColor.BLACK)
		"b", "e": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.ELEPHANT, XiangqiTypes.PieceColor.BLACK)
		"n", "h": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.HORSE, XiangqiTypes.PieceColor.BLACK)
		"r": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.ROOK, XiangqiTypes.PieceColor.BLACK)
		"c": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.CANNON, XiangqiTypes.PieceColor.BLACK)
		"p": return XiangqiTypes.Piece.new(XiangqiTypes.PieceType.PAWN, XiangqiTypes.PieceColor.BLACK)
	return null

func to_fen() -> String:
	var row_strings: Array[String] = []
	for r in range(XiangqiConstants.BOARD_ROWS):
		var y: int = 9 - r
		var empty_count: int = 0
		var row_str: String = ""
		for x in range(XiangqiConstants.BOARD_COLS):
			var piece: XiangqiTypes.Piece = grid[y][x]
			if piece == null:
				empty_count += 1
			else:
				if empty_count > 0:
					row_str += str(empty_count)
					empty_count = 0
				row_str += _get_char_for_piece(piece)
		if empty_count > 0:
			row_str += str(empty_count)
		row_strings.append(row_str)

	var turn_str := "w" if turn == XiangqiTypes.PieceColor.RED else "b"
	return "/".join(row_strings) + " " + turn_str + " - - 0 1"

func _get_char_for_piece(piece: XiangqiTypes.Piece) -> String:
	var is_red := piece.color == XiangqiTypes.PieceColor.RED
	match piece.type:
		XiangqiTypes.PieceType.KING: return "K" if is_red else "k"
		XiangqiTypes.PieceType.ADVISOR: return "A" if is_red else "a"
		XiangqiTypes.PieceType.ELEPHANT: return "B" if is_red else "b"
		XiangqiTypes.PieceType.HORSE: return "N" if is_red else "n"
		XiangqiTypes.PieceType.ROOK: return "R" if is_red else "r"
		XiangqiTypes.PieceType.CANNON: return "C" if is_red else "c"
		XiangqiTypes.PieceType.PAWN: return "P" if is_red else "p"
	return "?"
