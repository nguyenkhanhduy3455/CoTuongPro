class_name SettingsDialog
extends Control

@onready var name_input: LineEdit = $Panel/VBoxContainer/NameEdit
@onready var server_input: LineEdit = $Panel/VBoxContainer/ServerEdit
@onready var difficulty_option: OptionButton = $Panel/VBoxContainer/DifficultyOption
@onready var cutscene_option: OptionButton = $Panel/VBoxContainer/CutsceneOption
@onready var sound_check: CheckBox = $Panel/VBoxContainer/SoundCheck
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

func _ready() -> void:
	_populate_options()
	_load_current_values()

	save_button.pressed.connect(_on_save_pressed)
	close_button.pressed.connect(func(): visible = false)

func _populate_options() -> void:
	difficulty_option.clear()
	difficulty_option.add_item("Dễ (Easy)", XiangqiTypes.AIDifficulty.EASY)
	difficulty_option.add_item("Trung bình (Medium)", XiangqiTypes.AIDifficulty.MEDIUM)
	difficulty_option.add_item("Khó (Hard)", XiangqiTypes.AIDifficulty.HARD)

	cutscene_option.clear()
	cutscene_option.add_item("Bật tất cả cutscene (All)", XiangqiTypes.CutsceneMode.ALL)
	cutscene_option.add_item("Chỉ nước cờ then chốt (Decisive Only)", XiangqiTypes.CutsceneMode.DECISIVE_ONLY)
	cutscene_option.add_item("Tắt cutscene (Disabled)", XiangqiTypes.CutsceneMode.DISABLED)

func _load_current_values() -> void:
	name_input.text = GameConfig.player_name
	server_input.text = GameConfig.server_url
	difficulty_option.selected = GameConfig.ai_difficulty
	cutscene_option.selected = GameConfig.cutscene_mode
	sound_check.button_pressed = GameConfig.sound_enabled

func _on_save_pressed() -> void:
	GameConfig.player_name = name_input.text.strip_edges()
	GameConfig.server_url = server_input.text.strip_edges()
	GameConfig.ai_difficulty = difficulty_option.selected as XiangqiTypes.AIDifficulty
	GameConfig.cutscene_mode = cutscene_option.selected as XiangqiTypes.CutsceneMode
	GameConfig.sound_enabled = sound_check.button_pressed
	GameConfig.save_settings()
	visible = false
