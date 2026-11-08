extends Node

const VOICE_COUNT := 16
const SILENT_DB := -INF

class Voice extends AudioStreamPlayer2D:
	var trim_db := 0.0
	var is_stomp := false

@export var camera : CameraControls
@export var feet : Array[GiantPart]
@export var crumble_points : Array[Node2D]
@export var scatter := 40.0

@export_group("Sounds")
@export var stomp_sounds : Array[AudioStream] = [
	preload("res://assets/Audio/Giant/walk_1.wav"),
	preload("res://assets/Audio/Giant/walk_2.wav"),
	preload("res://assets/Audio/Giant/walk_3.wav"),
	preload("res://assets/Audio/Giant/walk_4.wav"),
	preload("res://assets/Audio/Giant/walk_5.wav"),
	preload("res://assets/Audio/Giant/walk_6.wav"),
	preload("res://assets/Audio/Giant/walk_7.wav"),
	preload("res://assets/Audio/Giant/walk_8.wav"),
]
@export var crumble_sounds : Array[AudioStream] = [
	preload("res://assets/Audio/Giant/crumble_1.wav"),
	preload("res://assets/Audio/Giant/crumble_2.wav"),
	preload("res://assets/Audio/Giant/crumble_3.wav"),
	preload("res://assets/Audio/Giant/crumble_4.wav"),
]

@export_group("Speed")
@export_range(0.25, 1.0, 0.01) var stomp_speed := 0.75
@export_range(0.25, 1.0, 0.01) var crumble_speed := 0.75

@export_group("Stomp Mix")
@export var village_zoom := 6.0
@export var stomp_village_db := -33.0
@export var stomp_far_db := -3.0

@export_group("Main Crumble Mix")
@export var crumble_village_db := -28.0
@export var crumble_peak_db := -5.0
@export var crumble_far_db := -16.0
@export_range(0.05, 0.95) var crumble_peak_at := 0.45
@export var crumble_offscreen_db := -8.0

@export_group("Crumble Timing")
@export var aftermath_trim_db := 0.0
@export var scattered_trim_db := -5.0
@export var lift_trim_db := -8.0
@export var scattered_count := 2

var _voices : Array[Voice] = []
var _last_stomp : AudioStream

func _ready() -> void:
	for i in VOICE_COUNT:
		var voice := Voice.new()
		voice.max_distance = 1000000.0
		voice.attenuation = 0.0
		add_child(voice)
		_voices.append(voice)
	for foot in feet:
		foot.lifted.connect(_on_foot_lifted.bind(foot))
		foot.landed.connect(_on_foot_landed.bind(foot))

func _process(_delta : float) -> void:
	var far := _farness()
	for voice in _voices:
		if voice.playing:
			voice.volume_db = _volume_for(voice, far)

func _on_foot_lifted(index : int, foot : GiantPart) -> void:
	if foot.lands_on(index):
		_crumble_later(randf_range(0.0, 0.5), foot, lift_trim_db)

func _on_foot_landed(index : int, foot : GiantPart) -> void:
	if not foot.lands_on(index):
		return
	_play(_next_stomp(), foot.global_position, 0.0, true, randf_range(0.92, 1.06) * stomp_speed)
	_crumble_later(randf_range(0.08, 0.2), foot, aftermath_trim_db)
	for i in scattered_count:
		_crumble_later(randf_range(0.3, 1.4), crumble_points.pick_random(), scattered_trim_db)

func _next_stomp() -> AudioStream:
	var options := stomp_sounds.filter(func(sound): return sound != _last_stomp)
	_last_stomp = stomp_sounds.pick_random() if options.is_empty() else options.pick_random()
	return _last_stomp

func _crumble_later(delay : float, source : Node2D, trim_db : float) -> void:
	get_tree().create_timer(delay, false).timeout.connect(_crumble.bind(source, trim_db))

func _crumble(source : Node2D, trim_db : float) -> void:
	var offset := Vector2(randf_range(-scatter, scatter), randf_range(-scatter, scatter))
	_play(crumble_sounds.pick_random(), source.global_position + offset, trim_db, false, randf_range(0.85, 1.15) * crumble_speed)

func _play(stream : AudioStream, at : Vector2, trim_db : float, is_stomp : bool, pitch : float) -> void:
	var voice := _free_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.global_position = at
	voice.pitch_scale = pitch
	voice.trim_db = trim_db
	voice.is_stomp = is_stomp
	voice.volume_db = _volume_for(voice, _farness())
	voice.play()

func _free_voice() -> Voice:
	for voice in _voices:
		if not voice.playing:
			return voice
	return null

func _farness() -> float:
	var zoom := clampf(camera.zoom.x, camera.min_zoom, village_zoom)
	return inverse_lerp(log(village_zoom), log(camera.min_zoom), log(zoom))

func _volume_for(voice : Voice, far : float) -> float:
	if far <= 0.0:
		return SILENT_DB
	if voice.is_stomp:
		return lerpf(stomp_village_db, stomp_far_db, far) + voice.trim_db
	return _crumble_db(voice.global_position, far) + voice.trim_db

func _crumble_db(at : Vector2, far : float) -> float:
	var level := lerpf(crumble_peak_db, crumble_far_db, (far - crumble_peak_at) / (1.0 - crumble_peak_at))
	if far < crumble_peak_at:
		level = lerpf(crumble_village_db, crumble_peak_db, far / crumble_peak_at)
	return level + lerpf(crumble_offscreen_db, 0.0, _on_screen(at))

func _on_screen(at : Vector2) -> float:
	var offset := (at - camera.get_screen_center_position()) * camera.zoom
	return clampf(1.0 - offset.length() / get_viewport().get_visible_rect().size.x, 0.0, 1.0)
