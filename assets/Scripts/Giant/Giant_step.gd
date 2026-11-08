extends GiantPart

const SLAM_DEPTH := 8.0

@export var step_height := 7.0
@export var sway := 0.0

func _pose(_index : int, t : float) -> Vector2:
	var lifted := base_pos + Vector2(sway * 0.4, -step_height)
	return _sample(base_pos, [
		_key(lifted, lift_time, Tween.EASE_IN_OUT, Tween.TRANS_QUAD, Tween.TRANS_SINE),
		_key(lifted, hang_time),
		_key(base_pos + Vector2(sway, SLAM_DEPTH), slam_time, Tween.EASE_IN, Tween.TRANS_CUBIC),
		_key(base_pos, settle_time, Tween.EASE_OUT, Tween.TRANS_QUINT, Tween.TRANS_QUART),
		_key(base_pos, pause_time),
	], t)
