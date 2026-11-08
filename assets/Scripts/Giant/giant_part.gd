extends Node2D
class_name GiantPart

@export var lift_time := 1.4
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := 0.0

var base_pos : Vector2

func _ready() -> void:
	base_pos = position
	_setup()
	await _wait(start_delay)
	while is_inside_tree():
		await _step()

func _setup() -> void:
	pass

func _step() -> void:
	await _wait(lift_time + hang_time + slam_time + settle_time + pause_time)

func _wait(seconds : float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout

func _move(to : Vector2, duration : float, easing : Tween.EaseType, trans_y : Tween.TransitionType, trans_x := trans_y) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", to.y, duration).set_trans(trans_y).set_ease(easing)
	tween.tween_property(self, "position:x", to.x, duration).set_trans(trans_x).set_ease(easing)
	await tween.finished
