class_name AIEngine
extends RefCounted

signal move_ready(move: XiangqiTypes.Move, score: int)

var is_thinking: bool = false
var thread: Thread = null

const INFINITY: int = 1000000

func start_calculation_threaded(
	board: XiangqiBoard,
	difficulty: XiangqiTypes.AIDifficulty,
	color: XiangqiTypes.PieceColor
) -> void:
	if is_thinking:
		return

	is_thinking = true
	var cloned_board := board.clone()

	if thread != null and thread.is_started():
		thread.wait_to_finish()

	thread = Thread.new()
	thread.start(_thread_work.bind(cloned_board, difficulty, color))

func _thread_work(
	board: XiangqiBoard,
	difficulty: XiangqiTypes.AIDifficulty,
	color: XiangqiTypes.PieceColor
) -> void:
	var result := calculate_best_move(board, difficulty, color)
	_on_calculation_finished.call_deferred(result["move"], result["score"])

func _on_calculation_finished(move: XiangqiTypes.Move, score: int) -> void:
	if thread != null and thread.is_started():
		thread.wait_to_finish()
	is_thinking = false
	move_ready.emit(move, score)

func calculate_best_move(
	board: XiangqiBoard,
	difficulty: XiangqiTypes.AIDifficulty,
	color: XiangqiTypes.PieceColor
) -> Dictionary:
	var legal_moves := board.generate_legal_moves(color)
	if legal_moves.is_empty():
		return {"move": null, "score": -INFINITY}

	match difficulty:
		XiangqiTypes.AIDifficulty.EASY:
			# Depth 1-2 with 25% randomized move
			if randf() < 0.25:
				var random_move = legal_moves[randi() % legal_moves.size()]
				return {"move": random_move, "score": 0}
			return _search_root(board, 2, color, false)

		XiangqiTypes.AIDifficulty.MEDIUM:
			# Depth 3-4 with standard Alpha-Beta
			return _search_root(board, 3, color, false)

		XiangqiTypes.AIDifficulty.HARD:
			# Depth 4-5 with Quiescence search
			return _search_root(board, 4, color, true)

	return {"move": legal_moves[0], "score": 0}

func _search_root(
	board: XiangqiBoard,
	depth: int,
	color: XiangqiTypes.PieceColor,
	use_quiescence: bool
) -> Dictionary:
	var legal_moves := board.generate_legal_moves(color)
	_order_moves(board, legal_moves)

	var best_move: XiangqiTypes.Move = legal_moves[0]
	var best_score: int = -INFINITY
	var alpha: int = -INFINITY
	var beta: int = INFINITY

	for move in legal_moves:
		var from_p := move.from
		var to_p := move.to
		var saved_from: XiangqiTypes.Piece = board.grid[from_p.y][from_p.x]
		var saved_to: XiangqiTypes.Piece = board.grid[to_p.y][to_p.x]

		# Make move
		board.grid[to_p.y][to_p.x] = saved_from
		board.grid[from_p.y][from_p.x] = null

		var next_color: XiangqiTypes.PieceColor = (
			XiangqiTypes.PieceColor.BLACK if color == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED
		)

		var score: int = -_minimax(board, depth - 1, -beta, -alpha, next_color, use_quiescence)

		# Undo move
		board.grid[from_p.y][from_p.x] = saved_from
		board.grid[to_p.y][to_p.x] = saved_to

		if score > best_score:
			best_score = score
			best_move = move

		alpha = maxi(alpha, best_score)
		if alpha >= beta:
			break

	return {"move": best_move, "score": best_score}

func _minimax(
	board: XiangqiBoard,
	depth: int,
	alpha: int,
	beta: int,
	color: XiangqiTypes.PieceColor,
	use_quiescence: bool
) -> int:
	if depth <= 0:
		if use_quiescence:
			return _quiescence(board, alpha, beta, color, 3)
		return AIEvaluator.evaluate_board(board, color)

	var legal_moves := board.generate_legal_moves(color)
	if legal_moves.is_empty():
		if board.is_king_in_check(color):
			return -INFINITY + (10 - depth) # Checkmated
		return -INFINITY # Stalemated (Loss in Xiangqi)

	_order_moves(board, legal_moves)

	var max_score: int = -INFINITY
	for move in legal_moves:
		var from_p := move.from
		var to_p := move.to
		var saved_from: XiangqiTypes.Piece = board.grid[from_p.y][from_p.x]
		var saved_to: XiangqiTypes.Piece = board.grid[to_p.y][to_p.x]

		board.grid[to_p.y][to_p.x] = saved_from
		board.grid[from_p.y][from_p.x] = null

		var next_color: XiangqiTypes.PieceColor = (
			XiangqiTypes.PieceColor.BLACK if color == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED
		)

		var score: int = -_minimax(board, depth - 1, -beta, -alpha, next_color, use_quiescence)

		board.grid[from_p.y][from_p.x] = saved_from
		board.grid[to_p.y][to_p.x] = saved_to

		max_score = maxi(max_score, score)
		alpha = maxi(alpha, score)
		if alpha >= beta:
			break

	return max_score

func _quiescence(
	board: XiangqiBoard,
	alpha: int,
	beta: int,
	color: XiangqiTypes.PieceColor,
	q_depth: int
) -> int:
	var stand_pat: int = AIEvaluator.evaluate_board(board, color)
	if q_depth <= 0:
		return stand_pat

	if stand_pat >= beta:
		return beta
	alpha = maxi(alpha, stand_pat)

	var capture_moves := _generate_capture_moves(board, color)
	_order_moves(board, capture_moves)

	for move in capture_moves:
		var from_p := move.from
		var to_p := move.to
		var saved_from: XiangqiTypes.Piece = board.grid[from_p.y][from_p.x]
		var saved_to: XiangqiTypes.Piece = board.grid[to_p.y][to_p.x]

		board.grid[to_p.y][to_p.x] = saved_from
		board.grid[from_p.y][from_p.x] = null

		# King safety check
		if board.is_king_in_check(color):
			board.grid[from_p.y][from_p.x] = saved_from
			board.grid[to_p.y][to_p.x] = saved_to
			continue

		var next_color: XiangqiTypes.PieceColor = (
			XiangqiTypes.PieceColor.BLACK if color == XiangqiTypes.PieceColor.RED else XiangqiTypes.PieceColor.RED
		)

		var score: int = -_quiescence(board, -beta, -alpha, next_color, q_depth - 1)

		board.grid[from_p.y][from_p.x] = saved_from
		board.grid[to_p.y][to_p.x] = saved_to

		if score >= beta:
			return beta
		alpha = maxi(alpha, score)

	return alpha

func _generate_capture_moves(
	board: XiangqiBoard,
	color: XiangqiTypes.PieceColor
) -> Array[XiangqiTypes.Move]:
	var pseudo := board.generate_pseudo_legal_moves(color)
	var captures: Array[XiangqiTypes.Move] = []
	for m in pseudo:
		var target: XiangqiTypes.Piece = board.grid[m.to.y][m.to.x]
		if target != null and target.color != color:
			captures.append(m)
	return captures

func _order_moves(board: XiangqiBoard, moves: Array[XiangqiTypes.Move]) -> void:
	# MVV-LVA move ordering (captures sorted by victim value - attacker value)
	moves.sort_custom(func(a: XiangqiTypes.Move, b: XiangqiTypes.Move) -> bool:
		var val_a := _get_move_sort_score(board, a)
		var val_b := _get_move_sort_score(board, b)
		return val_a > val_b
	)

func _get_move_sort_score(board: XiangqiBoard, move: XiangqiTypes.Move) -> int:
	var target: XiangqiTypes.Piece = board.grid[move.to.y][move.to.x]
	var attacker: XiangqiTypes.Piece = board.grid[move.from.y][move.from.x]
	if target != null and attacker != null:
		var victim_val := AIEvaluator.get_piece_value(target, move.to)
		var attacker_val := AIEvaluator.get_piece_value(attacker, move.from)
		return victim_val * 10 - attacker_val
	return 0
