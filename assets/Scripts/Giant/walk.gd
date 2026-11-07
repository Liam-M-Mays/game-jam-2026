extends Node2D
 
@export var drift_distance := 20.0
@export var right_time := 2.2
@export_range(0.05, 1.0) var left_move_fraction := 0.65
@export var lift_time := 1.4
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := 0.4
 
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
	var slam_end := lift_time + hang_time + slam_time
	var start_phase := fposmod(-slam_end, cycle)
	position.x = base_x + _profile(fposmod(_elapsed - slam_end, cycle), cycle) \
		- _profile(start_phase, cycle)
 
func _profile(tau: float, cycle: float) -> float:
	var move_total := (cycle - right_time) * left_move_fraction
	if tau < right_time:
		return drift_distance * _smooth(tau / right_time)
	tau -= right_time
	if tau < move_total:
		return drift_distance * (1.0 - _smooth(tau / move_total))
	return 0.0
 
func _smooth(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(u, 0.0, 1.0))
