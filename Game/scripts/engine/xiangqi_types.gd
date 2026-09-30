class_name XiangqiTypes
extends RefCounted

enum PieceColor {
	RED = 0,
	BLACK = 1
}

enum PieceType {
	KING = 0,     ## Tướng / Soái (帅/将)
	ADVISOR = 1,  ## Sĩ (仕/士)
	ELEPHANT = 2, ## Tượng (相/象)
	HORSE = 3,    ## Mã (傌/馬)
	ROOK = 4,     ## Xe (俥/車)
	CANNON = 5,   ## Pháo (炮/砲)
	PAWN = 6      ## Tốt / Binh (兵/卒)
}

enum GameStatus {
	PLAYING,
	CHECK,
	CHECKMATE,
	STALEMATE,
	RESIGNED,
	TIMEOUT,
	DRAW
}

enum AIDifficulty {
	EASY = 0,
	MEDIUM = 1,
	HARD = 2
}

enum CutsceneMode {
	ALL = 0,
	DECISIVE_ONLY = 1,
	DISABLED = 2
}

class Piece extends RefCounted:
	var type: PieceType
	var color: PieceColor

	func _init(p_type: PieceType = PieceType.KING, p_color: PieceColor = PieceColor.RED) -> void:
		type = p_type
		color = p_color

	func duplicate_piece() -> Piece:
		return Piece.new(type, color)

	func get_symbol() -> String:
		match color:
			PieceColor.RED:
				match type:
					PieceType.KING: return "帥"
					PieceType.ADVISOR: return "仕"
					PieceType.ELEPHANT: return "相"
					PieceType.HORSE: return "傌"
					PieceType.ROOK: return "俥"
					PieceType.CANNON: return "炮"
					PieceType.PAWN: return "兵"
			PieceColor.BLACK:
				match type:
					PieceType.KING: return "將"
					PieceType.ADVISOR: return "士"
					PieceType.ELEPHANT: return "象"
					PieceType.HORSE: return "馬"
					PieceType.ROOK: return "車"
					PieceType.CANNON: return "砲"
					PieceType.PAWN: return "卒"
		return "?"

	func get_name_en() -> String:
		match type:
			PieceType.KING: return "King"
			PieceType.ADVISOR: return "Advisor"
			PieceType.ELEPHANT: return "Elephant"
			PieceType.HORSE: return "Horse"
			PieceType.ROOK: return "Rook"
			PieceType.CANNON: return "Cannon"
			PieceType.PAWN: return "Pawn"
		return "Unknown"

	func get_name_vi() -> String:
		match type:
			PieceType.KING: return "Tướng"
			PieceType.ADVISOR: return "Sĩ"
			PieceType.ELEPHANT: return "Tượng"
			PieceType.HORSE: return "Mã"
			PieceType.ROOK: return "Xe"
			PieceType.CANNON: return "Pháo"
			PieceType.PAWN: return "Tốt"
		return "Quân"

class Move extends RefCounted:
	var from: Vector2i
	var to: Vector2i

	func _init(p_from: Vector2i = Vector2i.ZERO, p_to: Vector2i = Vector2i.ZERO) -> void:
		from = p_from
		to = p_to

class DetailedMove extends Move:
	var piece: Piece
	var captured: Piece = null
	var uci: String = ""

	func _init(p_from: Vector2i, p_to: Vector2i, p_piece: Piece, p_captured: Piece = null, p_uci: String = "") -> void:
		super(p_from, p_to)
		piece = p_piece
		captured = p_captured
		uci = p_uci

class MoveResult extends RefCounted:
	var valid: bool = false
	var error: String = ""
	var captured: Piece = null
	var is_check: bool = false
	var is_checkmate: bool = false
	var is_stalemate: bool = false
	var is_block_check: bool = false
	var next_turn: PieceColor = PieceColor.BLACK
	var uci: String = ""
