extends GiantPart

@export var shift_distance := 12.0
@export var bob_height := 12.0
@export var bob_dip := 3.0
@export var starts_shifted := false

var _at_left := false

func _setup() -> void:
	_at_left = starts_shifted
	if starts_shifted:
		base_pos.x += shift_distance

func _step() -> void:
	_at_left = not _at_left
	var lift_to := base_pos - Vector2(shift_distance, bob_height) if _at_left else base_pos
	await _move(lift_to, lift_time, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
	await _wait(hang_time)
	await _move(Vector2(position.x, base_pos.y + (bob_dip if _at_left else 0.0)), slam_time, Tween.EASE_IN, Tween.TRANS_CUBIC)
	await _move(Vector2(position.x, base_pos.y), settle_time, Tween.EASE_OUT, Tween.TRANS_QUINT)
	await _wait(pause_time)
