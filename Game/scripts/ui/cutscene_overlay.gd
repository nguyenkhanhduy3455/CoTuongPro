class_name CutsceneOverlay
extends Control

signal cutscene_finished()

@onready var fallback_panel: Control = $FallbackPanel
@onready var title_label: Label = $FallbackPanel/TitleLabel
@onready var subtitle_label: Label = $FallbackPanel/SubtitleLabel
@onready var flash_rect: ColorRect = $FlashRect

var active_video_count: int = 0
var current_tween: Tween = null

const VIDEO_PATH_PREFIX: String = "res://assets/videos/"

enum LayoutShape {
	SQUARE,
	HORIZONTAL_RECT,
	VERTICAL_RECT
}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hide static template nodes in scene if present
	if has_node("VideoContainer"):
		get_node("VideoContainer").visible = false
	CutsceneManager.register_overlay(self)

func play_cutscene(clip_name: String, arg2: Variant = null, arg3: Variant = null) -> void:
	var target_pos := Vector2i(-1, -1)
	var callback := Callable()

	if arg2 is Vector2i:
		target_pos = arg2
		if arg3 is Callable:
			callback = arg3
	elif arg2 is Callable:
		callback = arg2

	if callback.is_valid():
		callback.call()

	var ogv_path := VIDEO_PATH_PREFIX + clip_name + ".ogv"
	if ResourceLoader.exists(ogv_path):
		# If a video is already playing, force the new concurrent cutscene to be SQUARE right at the piece
		var force_square: bool = (active_video_count > 0)
		_spawn_video_instance(ogv_path, target_pos, force_square)
	else:
		_play_procedural_fallback(clip_name)

func _get_board_rect() -> Rect2:
	var boards := get_tree().get_nodes_in_group("board_view")
	if boards.size() > 0:
		var bv = boards[0]
		if bv.has_method("get_board_global_rect") and bv.is_inside_tree() and bv.is_visible_in_tree():
			return bv.get_board_global_rect()

	var screen_sz := get_viewport_rect().size
	if screen_sz.x <= 0 or screen_sz.y <= 0:
		screen_sz = Vector2(720.0, 1280.0)

	var bw := minf(screen_sz.x - 20.0, 680.0)
	var bh := bw * (9.0 / 8.0)
	var bx := (screen_sz.x - bw) / 2.0
	var by := (screen_sz.y - bh) / 2.0
	return Rect2(Vector2(bx, by), Vector2(bw, bh))

func _layout_video_container(container: Control, player: VideoStreamPlayer, target_pos: Vector2i, force_square: bool) -> void:
	var board_rect := _get_board_rect()
	var bx: float = board_rect.position.x
	var by: float = board_rect.position.y
	var bw: float = board_rect.size.x
	var bh: float = board_rect.size.y

	# Calculate screen pixel coordinate of the captured piece
	var target_pixel := Vector2(bx + bw / 2.0, by + bh / 2.0)
	var boards := get_tree().get_nodes_in_group("board_view")
	if boards.size() > 0 and target_pos.x >= 0 and target_pos.y >= 0:
		var bv = boards[0]
		if bv.has_method("get_square_global_pos") and bv.is_inside_tree():
			target_pixel = bv.get_square_global_pos(target_pos)

	var chosen_shape: LayoutShape = LayoutShape.SQUARE
	if not force_square:
		var shape_choices := [
			LayoutShape.SQUARE,
			LayoutShape.HORIZONTAL_RECT,
			LayoutShape.VERTICAL_RECT
		]
		chosen_shape = shape_choices[randi() % shape_choices.size()]

	var cw: float = 0.0
	var ch: float = 0.0
	var pos := Vector2.ZERO

	match chosen_shape:
		LayoutShape.SQUARE:
			# Square centered right at the captured piece position
			var sq := clampf(minf(bw, bh) * 0.45, 220.0, 300.0)
			cw = sq
			ch = sq
			pos.x = clampf(target_pixel.x - sq / 2.0, bx, bx + bw - sq)
			pos.y = clampf(target_pixel.y - sq / 2.0, by, by + bh - sq)

		LayoutShape.HORIZONTAL_RECT:
			# Horizontal rectangle spanning the board width, containing the captured piece's row
			cw = bw
			ch = clampf(bh * 0.32, 180.0, 260.0)
			pos.x = bx
			pos.y = clampf(target_pixel.y - ch / 2.0, by, by + bh - ch)

		LayoutShape.VERTICAL_RECT:
			# Vertical rectangle spanning the board height, containing the captured piece's column
			cw = clampf(bw * 0.46, 220.0, 320.0)
			ch = bh
			pos.x = clampf(target_pixel.x - cw / 2.0, bx, bx + bw - cw)
			pos.y = by

	# Center-crop math for 16:9 video into container (cw, ch) without squishing or stretching
	var scale_factor: float = maxf(cw / 16.0, ch / 9.0)
	var vw: float = 16.0 * scale_factor
	var vh: float = 9.0 * scale_factor
	var vx: float = (cw - vw) / 2.0
	var vy: float = (ch - vh) / 2.0

	container.position = pos
	container.size = Vector2(cw, ch)

	player.position = Vector2(vx, vy)
	player.size = Vector2(vw, vh)

func _spawn_video_instance(video_path: String, target_pos: Vector2i, force_square: bool) -> void:
	var stream = load(video_path)
	if stream == null:
		_play_procedural_fallback(video_path.get_file().get_basename())
		return

	fallback_panel.visible = false
	if flash_rect != null:
		flash_rect.visible = false

	var container := Control.new()
	container.clip_contents = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	var player := VideoStreamPlayer.new()
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.modulate = Color(1.0, 1.0, 1.0, 0.5) # 50% opacity
	player.stream = stream
	container.add_child(player)

	_layout_video_container(container, player, target_pos, force_square)

	active_video_count += 1
	visible = true
	player.play()

	var timer := get_tree().create_timer(4.1)
	var state := {"cleaned": false}

	var cleanup_fn: Callable
	cleanup_fn = func():
		if state["cleaned"]:
			return
		state["cleaned"] = true
		if is_instance_valid(player):
			player.stop()
		if is_instance_valid(container):
			container.queue_free()
		active_video_count = maxi(0, active_video_count - 1)
		if active_video_count == 0:
			visible = false
			cutscene_finished.emit()

	player.finished.connect(cleanup_fn)
	timer.timeout.connect(cleanup_fn)

func _play_procedural_fallback(clip_name: String) -> void:
	fallback_panel.visible = true
	if flash_rect != null:
		flash_rect.visible = true
		flash_rect.modulate.a = 0.4

	var title := "⚔️ CHIẾN ĐẨU BẠO PHÁ"
	var subtitle := "Đòn tấn công uy lực sấm sét!"
	var flash_color := Color(1.0, 0.9, 0.4)

	match clip_name:
		"phao_an_tot_fast", "cannon_barrage":
			title = "💣 THẦN CƠ PHÁO KÍCH"
			subtitle = "Pháo gầm rung chuyển đất trời!"
			flash_color = Color(1.0, 0.4, 0.1)
		"ma_an_chot":
			title = "🐎 THẦN MÃ ĐẠP TỐT"
			subtitle = "Chiến mã tung vó bạt phong trảm tốt!"
			flash_color = Color(0.2, 0.9, 0.5)
		"xe_an_phao":
			title = "⚔️ XA THẦN PHÁ PHÁO"
			subtitle = "Chiến xa càn quét diệt trừ hỏa pháo!"
			flash_color = Color(1.0, 0.5, 0.2)
		"xe_an_ma", "cavalry_charge":
			title = "⚡ XA KỴ ĐỘT KÍCH"
			subtitle = "Xe xông trận trảm Mã định giang sơn!"
			flash_color = Color(0.3, 0.8, 1.0)
		"advisor_shield_defense":
			title = "🛡️ HỘ VỆ KIM THÀNH"
			subtitle = "Sĩ thân dũng cảm chặn đứng tử huyệt!"
			flash_color = Color(0.9, 0.8, 0.2)
		"general_threat_zoom":
			title = "🔥 CHIẾU TƯỚNG NGUY CẤP"
			subtitle = "Soái ấn lung lay, hiểm cảnh sinh tử!"
			flash_color = Color(1.0, 0.2, 0.2)
		"checkmate_dramatic":
			title = "👑 CHIẾU BÍ TUYỆT THẾ"
			subtitle = "Khắp trời dứt lối, ván cờ định đoạt!"
			flash_color = Color(1.0, 0.1, 0.1)

	title_label.text = title
	subtitle_label.text = subtitle
	if flash_rect != null:
		flash_rect.color = flash_color

	if current_tween != null and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween().set_parallel(true)
	if flash_rect != null:
		current_tween.tween_property(flash_rect, "modulate:a", 0.0, 0.3)

	fallback_panel.scale = Vector2(0.7, 0.7)
	fallback_panel.modulate.a = 0.0
	current_tween.tween_property(fallback_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(fallback_panel, "modulate:a", 0.6, 0.25)

	# Auto complete after 1.5 seconds
	get_tree().create_timer(1.5).timeout.connect(func():
		if active_video_count == 0:
			visible = false
			cutscene_finished.emit()
	)
