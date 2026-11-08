extends Node

const MENU_SCENE := "res://Main_Menu.tscn"
const GAME_SCENE := "res://assets/Scenes/Levels/game.tscn"
const MENU_MUSIC := preload("uid://ccekgjd0hy55i")
const GAMEPLAY_MUSIC := preload("res://assets/Audio/Music/gameplay.wav")
const SUCCESS_RIFF := preload("uid://bnv37hep82f8")
const UI_SOUNDS := preload("res://assets/Scripts/Audio/ui_sounds.gd")
const SUCCESS_RIFF_DB := -6.0
const MENU_DB := -12.0
const GAMEPLAY_DB := -20.0
const GAME_OVER_SECONDS := 4.0
const GAME_OVER_PITCH := 0.35

var _player := AudioStreamPlayer.new()
var _riff := AudioStreamPlayer.new()
var _scene : Node = null
var _level_db := 0.0
var _fade := 1.0
var _fade_tween : Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_riff.stream = SUCCESS_RIFF
	_riff.volume_db = SUCCESS_RIFF_DB
	add_child(_riff)
	add_child(UI_SOUNDS.new())

func _process(_delta : float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene != _scene:
		_scene = scene
		_start_for_scene(scene.scene_file_path)
	_player.volume_db = _level_db + _zoom_db() + linear_to_db(_fade)

func play_success_riff() -> void:
	_riff.play()

func fade_out_game_over(seconds := GAME_OVER_SECONDS) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		return
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	_fade_tween.tween_method(_apply_game_over, 0.0, 1.0, seconds)
	_fade_tween.tween_callback(_player.stop)

func _apply_game_over(amount : float) -> void:
	_fade = 1.0 - amount
	_player.pitch_scale = lerpf(1.0, GAME_OVER_PITCH, amount)

func _start_for_scene(path : String) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	_fade = 1.0
	_player.pitch_scale = 1.0
	match path:
		MENU_SCENE:
			_start_track(MENU_MUSIC, MENU_DB)
		GAME_SCENE:
			_start_track(GAMEPLAY_MUSIC, GAMEPLAY_DB)
		_:
			_player.stop()

func _start_track(stream : AudioStream, level_db : float) -> void:
	_player.stream = stream
	_level_db = level_db
	_player.play()

func _zoom_db() -> float:
	var camera := get_viewport().get_camera_2d() as CameraControls
	if camera == null or _player.stream != GAMEPLAY_MUSIC:
		return 0.0
	var amount := inverse_lerp(log(camera.min_zoom), log(VillageAudio.VILLAGE_ZOOM), log(camera.zoom.x))
	return linear_to_db(clampf(amount, 0.0, 1.0))
