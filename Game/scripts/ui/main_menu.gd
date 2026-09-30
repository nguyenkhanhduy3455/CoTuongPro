class_name MainMenu
extends Control

signal play_pve_requested()
signal play_online_queue_requested()
signal custom_room_requested()
signal settings_requested()
signal exit_requested()

@onready var pve_button: Button = $VBoxContainer/HBoxRow1/PVEButton
@onready var online_queue_button: Button = $VBoxContainer/HBoxRow1/OnlineQueueButton
@onready var custom_room_button: Button = $VBoxContainer/CustomRoomButton
@onready var settings_button: TextureButton = $TopRightBar/SettingsButton
@onready var exit_button: TextureButton = $TopRightBar/ExitButton

func _ready() -> void:
	pve_button.pressed.connect(func(): play_pve_requested.emit())
	online_queue_button.pressed.connect(func(): play_online_queue_requested.emit())
	custom_room_button.pressed.connect(func(): custom_room_requested.emit())
	settings_button.pressed.connect(func(): settings_requested.emit())
	exit_button.pressed.connect(func(): exit_requested.emit())
