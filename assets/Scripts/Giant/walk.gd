extends Node2D

@export var drift_distance := 12.0
@export var lift_time := 1.4
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := 0.0

var base_x: float
var _elapsed: float

func _ready() -> void:
	base_x = position.x
	_elapsed = -start_delay

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.0:
		return
	var cycle := lift_time + hang_time + slam_time + settle_time + pause_time
	position.x = base_x + _profile(fposmod(_elapsed, cycle))

func _profile(tau: float) -> float:
	if tau < lift_time:
		return Tween.interpolate_value(0.0, -drift_distance, tau, lift_time, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tau -= lift_time + hang_time + slam_time
	if tau < 0.0:
		return -drift_distance
	return -drift_distance * (1.0 - _smooth(tau / (settle_time + pause_time)))

func _smooth(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(u, 0.0, 1.0))
