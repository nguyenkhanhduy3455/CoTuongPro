class_name XiangqiConstants
extends RefCounted

const BOARD_COLS: int = 9
const BOARD_ROWS: int = 10

const PALACE_X_MIN: int = 3
const PALACE_X_MAX: int = 5

const RED_PALACE_Y_MIN: int = 0
const RED_PALACE_Y_MAX: int = 2

const BLACK_PALACE_Y_MIN: int = 7
const BLACK_PALACE_Y_MAX: int = 9

const RED_RIVER_Y_MAX: int = 4
const BLACK_RIVER_Y_MIN: int = 5

const INITIAL_FEN: String = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"

const FILES: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]

static func is_inside_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_COLS and pos.y >= 0 and pos.y < BOARD_ROWS

static func is_in_palace(pos: Vector2i, color: XiangqiTypes.PieceColor) -> bool:
	if pos.x < PALACE_X_MIN or pos.x > PALACE_X_MAX:
		return false
	if color == XiangqiTypes.PieceColor.RED:
		return pos.y >= RED_PALACE_Y_MIN and pos.y <= RED_PALACE_Y_MAX
	else:
		return pos.y >= BLACK_PALACE_Y_MIN and pos.y <= BLACK_PALACE_Y_MAX

static func has_crossed_river(y: int, color: XiangqiTypes.PieceColor) -> bool:
	if color == XiangqiTypes.PieceColor.RED:
		return y > RED_RIVER_Y_MAX # y >= 5
	else:
		return y < BLACK_RIVER_Y_MIN # y <= 4

static func pos_to_uci(pos: Vector2i) -> String:
	if not is_inside_board(pos):
		return ""
	return FILES[pos.x] + str(pos.y)

static func uci_to_pos(uci_coord: String) -> Vector2i:
	if uci_coord.length() != 2:
		return Vector2i(-1, -1)
	var file_char: String = uci_coord.substr(0, 1).to_lower()
	var rank_char: String = uci_coord.substr(1, 1)

	var x: int = FILES.find(file_char)
	var y: int = rank_char.to_int()

	if x == -1 or not is_inside_board(Vector2i(x, y)):
		return Vector2i(-1, -1)
	return Vector2i(x, y)

static func move_to_uci(from_pos: Vector2i, to_pos: Vector2i) -> String:
	return pos_to_uci(from_pos) + pos_to_uci(to_pos)

static func uci_to_move(uci_str: String) -> XiangqiTypes.Move:
	if uci_str.length() != 4:
		return null
	var from_p := uci_to_pos(uci_str.substr(0, 2))
	var to_p := uci_to_pos(uci_str.substr(2, 2))
	if from_p.x == -1 or to_p.x == -1:
		return null
	return XiangqiTypes.Move.new(from_p, to_p)
