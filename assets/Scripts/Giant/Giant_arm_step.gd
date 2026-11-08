extends GiantPart

@export var shift_distance := 12.0
@export var bob_height := 12.0
@export var bob_dip := 3.0
@export var starts_shifted := false

func _setup() -> void:
	if starts_shifted:
		base_pos.x += shift_distance

# The arm alternates each cycle: swing back (left + up), then return.
func _is_left(index : int) -> bool:
	return (index % 2 == 0) != starts_shifted

func _pose(index : int, t : float) -> Vector2:
	var at_left := _is_left(index)
	var left_x := base_pos.x - shift_distance
	var start := Vector2(left_x if _is_left(index - 1) else base_pos.x, base_pos.y)
	var lift_to := base_pos - Vector2(shift_distance, bob_height) if at_left else base_pos
	return _sample(start, [
		_key(lift_to, lift_time, Tween.EASE_IN_OUT, Tween.TRANS_QUAD),
		_key(lift_to, hang_time),
		_key(Vector2(lift_to.x, base_pos.y + (bob_dip if at_left else 0.0)), slam_time, Tween.EASE_IN, Tween.TRANS_CUBIC),
		_key(Vector2(lift_to.x, base_pos.y), settle_time, Tween.EASE_OUT, Tween.TRANS_QUINT),
		_key(Vector2(lift_to.x, base_pos.y), pause_time),
	], t)
