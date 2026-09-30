class_name MatchmakingLobby
extends Control

signal cancel_requested()

@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var spinner: TextureProgressBar = $Panel/VBoxContainer/Spinner
@onready var pin_display: VBoxContainer = $Panel/VBoxContainer/PINDisplay
@onready var pin_label: Label = $Panel/VBoxContainer/PINDisplay/PINLabel
@onready var cancel_button: Button = $Panel/VBoxContainer/CancelButton

var is_spinning: bool = false

func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)

func _process(delta: float) -> void:
	if is_spinning and spinner != null:
		spinner.radial_initial_angle = wrapf(spinner.radial_initial_angle + delta * 240.0, 0.0, 360.0)

func show_queue_mode(queue_size: int = 1) -> void:
	visible = true
	is_spinning = true
	pin_display.visible = false
	status_label.text = "🔍 Đang tìm đối thủ... (" + str(queue_size) + " người trong hàng)"

func show_created_room(room_code: String) -> void:
	visible = true
	is_spinning = false
	pin_display.visible = true
	pin_label.text = room_code
	status_label.text = "Mã phòng 6 ký tự. Hãy chia sẻ mã này:"

func _on_cancel_pressed() -> void:
	is_spinning = false
	visible = false
	cancel_requested.emit()
