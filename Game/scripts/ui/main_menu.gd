class_name MainMenu
extends Control

signal play_pve_requested()
signal play_online_queue_requested()
signal create_room_requested()
signal join_room_requested()
signal settings_requested()

@onready var pve_button: Button = $VBoxContainer/PVEButton
@onready var online_queue_button: Button = $VBoxContainer/OnlineQueueButton
@onready var create_room_button: Button = $VBoxContainer/CreateRoomButton
@onready var join_room_button: Button = $VBoxContainer/JoinRoomButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

func _ready() -> void:
	pve_button.pressed.connect(func(): play_pve_requested.emit())
	online_queue_button.pressed.connect(func(): play_online_queue_requested.emit())
	create_room_button.pressed.connect(func(): create_room_requested.emit())
	join_room_button.pressed.connect(func(): join_room_requested.emit())
	settings_button.pressed.connect(func(): settings_requested.emit())
