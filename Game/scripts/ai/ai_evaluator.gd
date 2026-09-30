class_name AIEvaluator
extends RefCounted

# Base piece values (centi-pawns)
const VAL_KING: int = 10000
const VAL_ROOK: int = 900
const VAL_CANNON: int = 450
const VAL_HORSE: int = 400
const VAL_ELEPHANT: int = 200
const VAL_ADVISOR: int = 200
const VAL_PAWN_BASE: int = 100
const VAL_PAWN_CROSSED: int = 200

# Positional Piece-Square Tables (PST) for Red (y: 0..9, bottom to top)
# For Black, positions are mirrored along Y (y_black = 9 - y_red)

# Pawn PST: increases value after river (y >= 5) and towards opponent palace
const PST_PAWN_RED: Array = [
	[ 0,  0,  0,  0,  0,  0,  0,  0,  0], # y=0
	[ 0,  0,  0,  0,  0,  0,  0,  0,  0], # y=1
	[ 0,  0,  0,  0,  0,  0,  0,  0,  0], # y=2
	[ 0,  0,  0,  5,  5,  5,  0,  0,  0], # y=3 (initial)
	[ 0,  0,  0, 10, 10, 10,  0,  0,  0], # y=4 (pre-river)
	[15, 20, 25, 35, 40, 35, 25, 20, 15], # y=5 (crossed river)
	[20, 30, 45, 60, 70, 60, 45, 30, 20], # y=6
	[30, 45, 60, 80, 90, 80, 60, 45, 30], # y=7
	[35, 50, 70, 90,100, 90, 70, 50, 35], # y=8 (deep palace)
	[10, 20, 30, 40, 50, 40, 30, 20, 10], # y=9 (bottom rank)
]

# Horse PST: central files and crossing river are favored
const PST_HORSE_RED: Array = [
	[ 0, -5,  5,  5,  5,  5,  5, -5,  0], # y=0
	[-5,  5, 10, 15, 10, 15, 10,  5, -5], # y=1
	[ 0, 10, 15, 20, 20, 20, 15, 10,  0], # y=2
	[ 5, 15, 25, 30, 30, 30, 25, 15,  5], # y=3
	[10, 20, 30, 35, 40, 35, 30, 20, 10], # y=4
	[15, 25, 35, 40, 45, 40, 35, 25, 15], # y=5
	[20, 30, 40, 45, 50, 45, 40, 30, 20], # y=6
	[15, 25, 35, 40, 40, 40, 35, 25, 15], # y=7
	[ 5, 15, 25, 30, 30, 30, 25, 15,  5], # y=8
	[ 0,  5, 10, 15, 15, 15, 10,  5,  0], # y=9
]

# Cannon PST: Central cannon (x=4) & open files favored
const PST_CANNON_RED: Array = [
	[ 0,  0,  5,  5, 10,  5,  5,  0,  0], # y=0
	[ 0,  5, 10, 15, 20, 15, 10,  5,  0], # y=1
	[ 5, 10, 15, 25, 30, 25, 15, 10,  5], # y=2
	[ 0,  5, 10, 15, 25, 15, 10,  5,  0], # y=3
	[ 0,  5, 10, 15, 25, 15, 10,  5,  0], # y=4
	[ 5, 10, 15, 20, 25, 20, 15, 10,  5], # y=5
	[ 5, 10, 20, 25, 30, 25, 20, 10,  5], # y=6
	[10, 15, 25, 30, 35, 30, 25, 15, 10], # y=7
	[ 5, 10, 15, 20, 25, 20, 15, 10,  5], # y=8
	[ 0,  5, 10, 15, 20, 15, 10,  5,  0], # y=9
]

# Rook PST: 7th/8th rank penetrations and central files
const PST_ROOK_RED: Array = [
	[ 0,  5, 10, 15, 15, 15, 10,  5,  0], # y=0
	[ 5, 10, 15, 20, 20, 20, 15, 10,  5], # y=1
	[ 5, 10, 15, 20, 20, 20, 15, 10,  5], # y=2
	[ 5, 10, 15, 20, 20, 20, 15, 10,  5], # y=3
	[10, 15, 20, 25, 25, 25, 20, 15, 10], # y=4
	[15, 20, 25, 30, 30, 30, 25, 20, 15], # y=5
	[20, 25, 30, 35, 35, 35, 30, 25, 20], # y=6
	[25, 30, 35, 40, 40, 40, 35, 30, 25], # y=7
	[30, 35, 40, 45, 45, 45, 40, 35, 30], # y=8
	[20, 25, 30, 35, 35, 35, 30, 25, 20], # y=9
]

static func evaluate_board(board: XiangqiBoard, for_color: XiangqiTypes.PieceColor) -> int:
	var red_score: int = 0
	var black_score: int = 0

	for y in range(XiangqiConstants.BOARD_ROWS):
		for x in range(XiangqiConstants.BOARD_COLS):
			var piece: XiangqiTypes.Piece = board.grid[y][x]
			if piece == null:
				continue

			var val := get_piece_value(piece, Vector2i(x, y))
			if piece.color == XiangqiTypes.PieceColor.RED:
				red_score += val
			else:
				black_score += val

	var total := red_score - black_score
	return total if for_color == XiangqiTypes.PieceColor.RED else -total

static func get_piece_value(piece: XiangqiTypes.Piece, pos: Vector2i) -> int:
	var base_val: int = 0
	var pos_bonus: int = 0
	var is_red: bool = piece.color == XiangqiTypes.PieceColor.RED
	var eval_y: int = pos.y if is_red else (9 - pos.y)

	match piece.type:
		XiangqiTypes.PieceType.KING:
			base_val = VAL_KING
		XiangqiTypes.PieceType.ADVISOR:
			base_val = VAL_ADVISOR
			pos_bonus = 10 if pos.x == 4 else 5
		XiangqiTypes.PieceType.ELEPHANT:
			base_val = VAL_ELEPHANT
			pos_bonus = 10 if pos.x == 4 else 5
		XiangqiTypes.PieceType.HORSE:
			base_val = VAL_HORSE
			pos_bonus = PST_HORSE_RED[eval_y][pos.x]
		XiangqiTypes.PieceType.ROOK:
			base_val = VAL_ROOK
			pos_bonus = PST_ROOK_RED[eval_y][pos.x]
		XiangqiTypes.PieceType.CANNON:
			base_val = VAL_CANNON
			pos_bonus = PST_CANNON_RED[eval_y][pos.x]
		XiangqiTypes.PieceType.PAWN:
			var crossed := XiangqiConstants.has_crossed_river(pos.y, piece.color)
			base_val = VAL_PAWN_CROSSED if crossed else VAL_PAWN_BASE
			pos_bonus = PST_PAWN_RED[eval_y][pos.x]

	return base_val + pos_bonus
