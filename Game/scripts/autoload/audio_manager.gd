class_name AudioManagerAutoload
extends Node

const SFX_MOVE = preload("res://assets/audio/move.wav")
const SFX_CAPTURE = preload("res://assets/audio/capture.wav")
const SFX_SELECT = preload("res://assets/audio/select.wav")

var players_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8
var current_player_idx: int = 0

func _ready() -> void:
	for i in range(POOL_SIZE):
		var asp := AudioStreamPlayer.new()
		asp.bus = "Master"
		asp.volume_db = 2.0  # Boosted for mobile clarity
		add_child(asp)
		players_pool.append(asp)

func play_move_sound() -> void:
	if not GameConfig.sound_enabled:
		return
	_play_stream(SFX_MOVE, 0.04)

func play_capture_sound() -> void:
	if not GameConfig.sound_enabled:
		return
	_play_stream(SFX_CAPTURE, 0.03)

func play_select_sound() -> void:
	if not GameConfig.sound_enabled:
		return
	_play_stream(SFX_SELECT, 0.02)

func _play_stream(stream: AudioStream, pitch_variance: float = 0.0) -> void:
	if stream == null or players_pool.is_empty():
		return

	# Find an idle player or cycle round-robin
	var chosen_player: AudioStreamPlayer = null
	for asp in players_pool:
		if not asp.playing:
			chosen_player = asp
			break

	if chosen_player == null:
		chosen_player = players_pool[current_player_idx]
		current_player_idx = (current_player_idx + 1) % players_pool.size()

	chosen_player.stream = stream
	if pitch_variance > 0.0:
		chosen_player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		chosen_player.pitch_scale = 1.0
	chosen_player.play()
