class_name GameConfigAutoload
extends Node

const SETTINGS_FILE: String = "user://settings.cfg"

var player_id: String = ""
var player_name: String = "KyThu"
var server_url: String = "ws://127.0.0.1:8080/ws"

var ai_difficulty: XiangqiTypes.AIDifficulty = XiangqiTypes.AIDifficulty.MEDIUM
var cutscene_mode: XiangqiTypes.CutsceneMode = XiangqiTypes.CutsceneMode.ALL
var sound_enabled: bool = true
var bgm_enabled: bool = true

func _ready() -> void:
	load_settings()
	if player_id.is_empty():
		player_id = "p_" + str(Time.get_unix_time_from_system()).md5_text().substr(0, 8)
		save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "id", player_id)
	config.set_value("player", "name", player_name)
	config.set_value("network", "server_url", server_url)
	config.set_value("gameplay", "ai_difficulty", ai_difficulty)
	config.set_value("gameplay", "cutscene_mode", cutscene_mode)
	config.set_value("audio", "sound_enabled", sound_enabled)
	config.set_value("audio", "bgm_enabled", bgm_enabled)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE)
	if err != OK:
		return

	player_id = config.get_value("player", "id", "")
	player_name = config.get_value("player", "name", "KyThu")
	server_url = config.get_value("network", "server_url", "ws://127.0.0.1:8080/ws")
	ai_difficulty = config.get_value("gameplay", "ai_difficulty", XiangqiTypes.AIDifficulty.MEDIUM)
	cutscene_mode = config.get_value("gameplay", "cutscene_mode", XiangqiTypes.CutsceneMode.ALL)
	sound_enabled = config.get_value("audio", "sound_enabled", true)
	bgm_enabled = config.get_value("audio", "bgm_enabled", true)
