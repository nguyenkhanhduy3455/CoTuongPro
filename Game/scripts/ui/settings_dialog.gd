class_name SettingsDialog
extends Control

@onready var name_input: LineEdit = $Panel/VBoxContainer/NameEdit
@onready var difficulty_option: OptionButton = $Panel/VBoxContainer/DifficultyOption
@onready var sound_check: CheckBox = $Panel/VBoxContainer/SoundCheck
@onready var save_button: Button = $Panel/VBoxContainer/HBoxContainer/SaveButton
@onready var close_button: Button = $Panel/VBoxContainer/HBoxContainer/CloseButton

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

func _load_current_values() -> void:
	name_input.text = GameConfig.player_name
	difficulty_option.selected = GameConfig.ai_difficulty
	sound_check.button_pressed = GameConfig.sound_enabled

func _on_save_pressed() -> void:
	GameConfig.player_name = name_input.text.strip_edges()
	GameConfig.ai_difficulty = difficulty_option.selected as XiangqiTypes.AIDifficulty
	GameConfig.cutscene_mode = XiangqiTypes.CutsceneMode.ALL
	GameConfig.sound_enabled = sound_check.button_pressed
	GameConfig.save_settings()
	visible = false
