class_name PieceView
extends Node2D

var piece_data: XiangqiTypes.Piece = null
var grid_pos: Vector2i = Vector2i.ZERO
var is_selected: bool = false
var radius: float = 30.0
var piece_texture: Texture2D = null

static var texture_cache: Dictionary = {}

func _ready() -> void:
	queue_redraw()

static func get_piece_texture(piece: XiangqiTypes.Piece) -> Texture2D:
	if piece == null:
		return null
	var is_red := (piece.color == XiangqiTypes.PieceColor.RED)
	var prefix := "r_" if is_red else "b_"
	var type_name := ""
	match piece.type:
		XiangqiTypes.PieceType.KING:
			type_name = "king"
		XiangqiTypes.PieceType.ADVISOR:
			type_name = "advisor"
		XiangqiTypes.PieceType.ELEPHANT:
			type_name = "elephant"
		XiangqiTypes.PieceType.HORSE:
			type_name = "horse"
		XiangqiTypes.PieceType.ROOK:
			type_name = "rook"
		XiangqiTypes.PieceType.CANNON:
			type_name = "cannon"
		XiangqiTypes.PieceType.PAWN:
			type_name = "pawn"

	var key := prefix + type_name
	if texture_cache.has(key):
		return texture_cache[key]

	var path := "res://assets/sprites/pieces/" + key + ".png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		texture_cache[key] = tex
		return tex
	return null

func setup(p_data: XiangqiTypes.Piece, p_pos: Vector2i, p_radius: float = 30.0) -> void:
	piece_data = p_data
	grid_pos = p_pos
	radius = p_radius
	piece_texture = get_piece_texture(piece_data)
	queue_redraw()

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func animate_to_pixel(target_pixel: Vector2, duration: float = 0.2, on_finish: Callable = Callable()) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pixel, duration)
	if on_finish.is_valid():
		tween.finished.connect(on_finish)

func animate_capture_fade(on_finish: Callable = Callable()) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	if on_finish.is_valid():
		tween.finished.connect(on_finish)

func _draw() -> void:
	if piece_data == null:
		return

	if piece_texture == null:
		piece_texture = get_piece_texture(piece_data)

	if piece_texture != null:
		# Draw 3D Piece Texture with Selection Aura
		if is_selected:
			draw_circle(Vector2(0, 2), radius * 1.15, Color(1.0, 0.84, 0.0, 0.35))
			draw_arc(Vector2(0, 2), radius * 1.12, 0, TAU, 36, Color(1.0, 0.9, 0.2, 0.95), 3.5)

		var diameter: float = radius * 2.15
		var rect := Rect2(-diameter / 2.0, -diameter / 2.0, diameter, diameter)
		draw_texture_rect(piece_texture, rect, false)
	else:
		# Procedural fallback
		var is_red := piece_data.color == XiangqiTypes.PieceColor.RED
		var base_wood_color := Color("f5deb3")
		var border_color := Color("b8860b")
		var text_color := Color("c0392b") if is_red else Color("2c3e50")
		var ring_color := Color("e74c3c") if is_red else Color("34495e")

		draw_circle(Vector2(2, 4), radius, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, radius, base_wood_color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, border_color, 3.0)
		draw_arc(Vector2.ZERO, radius - 4.0, 0, TAU, 32, ring_color, 2.0)

		if is_selected:
			draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 32, Color(1, 0.84, 0, 0.9), 3.5)

		var symbol := piece_data.get_symbol()
		var font := ThemeDB.fallback_font
		var font_size: int = int(radius * 1.05)
		var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(-text_size.x / 2.0, text_size.y / 3.0)
		draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)
