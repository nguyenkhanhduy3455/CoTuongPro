class_name CutsceneManagerAutoload
extends Node

signal cutscene_started(clip_name: String)
signal cutscene_finished()

var overlay_instance: Control = null

func register_overlay(overlay: Control) -> void:
	overlay_instance = overlay

func trigger_move_cutscene(
	piece: XiangqiTypes.Piece,
	captured: XiangqiTypes.Piece,
	is_check: bool,
	is_checkmate: bool,
	is_block_check: bool,
	target_pos: Vector2i = Vector2i(-1, -1),
	callback: Callable = Callable()
) -> void:
	# Immediately execute game callback so moves and interactions are not delayed
	if callback.is_valid():
		callback.call()

	if GameConfig.cutscene_mode == XiangqiTypes.CutsceneMode.DISABLED:
		return

	var clip_name := _determine_clip_name(piece, captured, is_check, is_checkmate, is_block_check)
	if clip_name.is_empty():
		return

	# In Decisive Only mode, only allow Checkmates or high-value captures (Rook/Cannon)
	if GameConfig.cutscene_mode == XiangqiTypes.CutsceneMode.DECISIVE_ONLY:
		var is_decisive: bool = (
			is_checkmate or
			(captured != null and (captured.type == XiangqiTypes.PieceType.ROOK or captured.type == XiangqiTypes.PieceType.CANNON))
		)
		if not is_decisive:
			return

	_play_cutscene(clip_name, target_pos, Callable())

func _determine_clip_name(
	piece: XiangqiTypes.Piece,
	captured: XiangqiTypes.Piece,
	is_check: bool,
	is_checkmate: bool,
	is_block_check: bool
) -> String:
	if is_checkmate:
		return "checkmate_dramatic"

	if is_block_check:
		return "advisor_shield_defense"

	if is_check:
		return "general_threat_zoom"

	if captured != null:
		# Specifically map Cannon capturing Pawn (Pháo ăn Tốt)
		if piece.type == XiangqiTypes.PieceType.CANNON and captured.type == XiangqiTypes.PieceType.PAWN:
			return "phao_an_tot_fast"
		# Specifically map Horse capturing Pawn (Mã ăn Chốt)
		elif piece.type == XiangqiTypes.PieceType.HORSE and captured.type == XiangqiTypes.PieceType.PAWN:
			return "ma_an_chot"
		# Specifically map Rook capturing Cannon (Xe ăn Pháo)
		elif piece.type == XiangqiTypes.PieceType.ROOK and captured.type == XiangqiTypes.PieceType.CANNON:
			return "xe_an_phao"
		# Specifically map Rook capturing Horse (Xe ăn Mã)
		elif piece.type == XiangqiTypes.PieceType.ROOK and captured.type == XiangqiTypes.PieceType.HORSE:
			return "xe_an_ma"
		elif piece.type == XiangqiTypes.PieceType.CANNON:
			return "phao_an_tot_fast"
		elif piece.type == XiangqiTypes.PieceType.ROOK:
			return "xe_an_phao"
		elif piece.type == XiangqiTypes.PieceType.HORSE:
			return "ma_an_chot"
		else:
			return "infantry_clash"

	return ""

func _play_cutscene(clip_name: String, target_pos: Vector2i, on_complete: Callable) -> void:
	if overlay_instance != null and overlay_instance.has_method("play_cutscene"):
		cutscene_started.emit(clip_name)
		overlay_instance.play_cutscene(clip_name, target_pos, func():
			cutscene_finished.emit()
			if on_complete.is_valid():
				on_complete.call()
		)
	else:
		if on_complete.is_valid():
			on_complete.call()
