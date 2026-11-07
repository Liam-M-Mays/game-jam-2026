extends GiantPart

const SLAM_DEPTH := 8.0

@export var step_height := 7.0
@export var sway := 0.0

func _step() -> void:
	await _move(base_pos + Vector2(sway * 0.4, -step_height), lift_time, Tween.EASE_IN_OUT, Tween.TRANS_QUAD, Tween.TRANS_SINE)
	await _wait(hang_time)
	await _move(base_pos + Vector2(sway, SLAM_DEPTH), slam_time, Tween.EASE_IN, Tween.TRANS_CUBIC)
	await _move(base_pos, settle_time, Tween.EASE_OUT, Tween.TRANS_QUINT, Tween.TRANS_QUART)
	await _wait(pause_time)
