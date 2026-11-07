extends Node2D
## Horizontal drift only, no up/down movement. Timed to the same cycle as the step script:
## drifts RIGHT starting right after the slam finishes, then moves back LEFT during the
## first part of the leftward time and stays STILL for the rest, ending where it started.
## Every transition eases in and out, so nothing starts or stops abruptly.
## NOTE: values set in the Inspector override the defaults below.
 
@export var drift_distance := 20.0 ## Pixels it travels right each cycle (and back left again)
@export var right_time := 2.2      ## Seconds spent drifting right (starts when the slam finishes)
@export_range(0.05, 1.0) var left_move_fraction := 0.65 ## Share of the left time spent moving (rest is still)
@export var lift_time := 1.4       ## Match the step script's timings
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := 0.2     ## Match the step script's start delay
 
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
	var slam_end := lift_time + hang_time + slam_time   # when the right drift begins
	# Offset so the object is at its starting spot at the start of each lift
	var start_phase := fposmod(-slam_end, cycle)
	position.x = base_x + _profile(fposmod(_elapsed - slam_end, cycle), cycle) \
		- _profile(start_phase, cycle)
 
## Drift offset (0 to drift_distance) at a given time since the right drift began.
func _profile(tau: float, cycle: float) -> float:
	var move_total := (cycle - right_time) * left_move_fraction
	if tau < right_time:
		return drift_distance * _smooth(tau / right_time)               # drifting right
	tau -= right_time
	if tau < move_total:
		return drift_distance * (1.0 - _smooth(tau / move_total))       # moving back left
	return 0.0                                                          # standing still
 
## Ease in and out (zero speed at both ends).
func _smooth(u: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(u, 0.0, 1.0))
