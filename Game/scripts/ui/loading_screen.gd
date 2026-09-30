class_name LoadingScreen
extends Control

@onready var status_label: Label = $BottomContainer/StatusLabel
@onready var progress_bar: ProgressBar = $BottomContainer/ProgressBar
@onready var version_label: Label = $BottomContainer/VersionLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

var target_progress: float = 0.0
var current_progress: float = 0.0
var stage: int = 0

const STAGES: Array[Dictionary] = [
	{"progress": 25.0, "status": "Đang khởi tạo bàn cờ & kỳ phổ..."},
	{"progress": 60.0, "status": "Đang nạp âm thanh & hiệu ứng chiến trận..."},
	{"progress": 85.0, "status": "Đang đồng bộ cấu hình kỳ thủ..."},
	{"progress": 100.0, "status": "Sẵn sàng nhập cuộc!"}
]

func _ready() -> void:
	version_label.text = "Phiên bản: 1.0.0"
	progress_bar.value = 0.0
	status_label.text = "Đang chuẩn bị tài nguyên trò chơi..."
	_start_loading_sequence()

func _start_loading_sequence() -> void:
	var tween := create_tween()
	# Step 1: 0 -> 25% (0.4s)
	tween.tween_callback(func(): status_label.text = STAGES[0]["status"])
	tween.tween_property(progress_bar, "value", STAGES[0]["progress"], 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Step 2: 25 -> 60% (0.5s)
	tween.tween_callback(func(): status_label.text = STAGES[1]["status"])
	tween.tween_property(progress_bar, "value", STAGES[1]["progress"], 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Step 3: 60 -> 85% (0.4s)
	tween.tween_callback(func(): status_label.text = STAGES[2]["status"])
	tween.tween_property(progress_bar, "value", STAGES[2]["progress"], 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Step 4: 85 -> 100% (0.4s)
	tween.tween_callback(func(): status_label.text = STAGES[3]["status"])
	tween.tween_property(progress_bar, "value", STAGES[3]["progress"], 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Small delay at 100% then transition
	tween.tween_interval(0.25)
	tween.tween_callback(_transition_to_main_game)

func _transition_to_main_game() -> void:
	fade_overlay.visible = true
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, 0.35)
	fade_tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
