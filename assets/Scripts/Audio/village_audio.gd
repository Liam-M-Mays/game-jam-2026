extends Node

const MASTER_VOLUME := 1.5
const VILLAGE_SFX_BOOST_DB := 4.0
const VOICE_COUNT := 6
const VILLAGE_ZOOM := 6.0
const SILENT_ZOOM := 2.2
const ZOOM_FADE_DB := -30.0
const OFFSCREEN_DB := -20.0
const PANNING := 3.0
const AMBIENCE_DB := -55.0
const AMBIENCE_ON_SECONDS := Vector2(8.0, 14.0)
const AMBIENCE_OFF_SECONDS := Vector2(18.0, 25.0)
const AMBIENCE_FADE_SECONDS := 3.0
const AMBIENCE := preload("res://assets/Audio/Village/birds_loop.wav")

class Voice extends AudioStreamPlayer2D:
	var base_db := 0.0

const LIBRARY := {
	&"axe": {"db": -24.0, "gap": 0.2, "sounds": [
		preload("res://assets/Audio/Village/axe_1.wav"),
		preload("res://assets/Audio/Village/axe_2.wav"),
		preload("res://assets/Audio/Village/axe_3.wav"),
		preload("res://assets/Audio/Village/axe_4.wav"),
	]},
	&"pickaxe": {"db": -26.0, "gap": 0.2, "sounds": [
		preload("res://assets/Audio/Village/pickaxe_1.wav"),
		preload("res://assets/Audio/Village/pickaxe_2.wav"),
		preload("res://assets/Audio/Village/pickaxe_3.wav"),
		preload("res://assets/Audio/Village/pickaxe_4.wav"),
	]},
	&"grass": {"db": -26.0, "gap": 0.3, "sounds": [
		preload("res://assets/Audio/Village/grass_1.wav"),
		preload("res://assets/Audio/Village/grass_2.wav"),
	]},
	&"hammer": {"db": -26.0, "gap": 0.25, "sounds": [
		preload("res://assets/Audio/Village/hammer_1.wav"),
		preload("res://assets/Audio/Village/hammer_2.wav"),
		preload("res://assets/Audio/Village/hammer_3.wav"),
	]},
	&"log": {"db": -30.0, "gap": 0.6, "sounds": [
		preload("res://assets/Audio/Village/log_1.wav"),
		preload("res://assets/Audio/Village/log_2.wav"),
		preload("res://assets/Audio/Village/log_3.wav"),
	]},
	&"hurt": {"db": -20.0, "gap": 1.0, "sounds": [
		preload("res://assets/Audio/Village/hurt_1.wav"),
		preload("res://assets/Audio/Village/hurt_2.wav"),
		preload("res://assets/Audio/Village/hurt_3.wav"),
	]},
}

var _voices : Array[Voice] = []
var _last_played := {}
var _ambience := AudioStreamPlayer.new()
var _ambience_on := false
var _ambience_timer := 4.0
var _ambience_level := 0.0

func _ready() -> void:
	AudioServer.set_bus_volume_linear(0, MASTER_VOLUME)
	_ambience.stream = AMBIENCE
	add_child(_ambience)
	for i in VOICE_COUNT:
		var voice := Voice.new()
		voice.max_distance = 1000000.0
		voice.attenuation = 0.0
		voice.panning_strength = PANNING
		add_child(voice)
		_voices.append(voice)

func _process(delta : float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		_ambience.stop()
		return
	_update_ambience(camera, delta)
	for voice in _voices:
		if voice.playing:
			voice.volume_db = voice.base_db + _placement_db(camera, voice.global_position)

func _update_ambience(camera : Camera2D, delta : float) -> void:
	_ambience_timer -= delta
	if _ambience_timer <= 0.0:
		_ambience_on = not _ambience_on
		var span := AMBIENCE_ON_SECONDS if _ambience_on else AMBIENCE_OFF_SECONDS
		_ambience_timer = randf_range(span.x, span.y)
	_ambience_level = move_toward(_ambience_level, 1.0 if _ambience_on else 0.0, delta / AMBIENCE_FADE_SECONDS)
	_ambience.volume_db = AMBIENCE_DB + ZOOM_FADE_DB * _farness(camera) + linear_to_db(maxf(_ambience_level, 0.001))
	if not _ambience.playing:
		_ambience.play()

func play(sound_name : StringName, at : Vector2) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not LIBRARY.has(sound_name):
		return
	if _farness(camera) >= 1.0 or _spread(camera, at) >= 1.0:
		return
	var sound : Dictionary = LIBRARY[sound_name]
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_played.get(sound_name, -INF) < sound.gap:
		return
	var voice := _free_voice()
	if voice == null:
		return
	_last_played[sound_name] = now
	voice.stream = sound.sounds.pick_random()
	voice.global_position = at
	voice.pitch_scale = randf_range(0.94, 1.06)
	voice.base_db = sound.db + VILLAGE_SFX_BOOST_DB
	voice.volume_db = voice.base_db + _placement_db(camera, at)
	voice.play()

func _free_voice() -> Voice:
	for voice in _voices:
		if not voice.playing:
			return voice
	return null

func _placement_db(camera : Camera2D, at : Vector2) -> float:
	return ZOOM_FADE_DB * _farness(camera) + OFFSCREEN_DB * _spread(camera, at)

func _spread(camera : Camera2D, at : Vector2) -> float:
	return ((at - camera.get_screen_center_position()) * camera.zoom).length() / get_viewport().get_visible_rect().size.x

func _farness(camera : Camera2D) -> float:
	var zoom := clampf(camera.zoom.x, SILENT_ZOOM, VILLAGE_ZOOM)
	return inverse_lerp(log(VILLAGE_ZOOM), log(SILENT_ZOOM), log(zoom))
