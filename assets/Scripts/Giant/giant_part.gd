extends Node2D
class_name GiantPart


@export var lift_time := 1.4
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := 0.0

var base_pos : Vector2
var _elapsed := 0.0

func _ready() -> void:
	base_pos = position
	_setup()
	_elapsed = -start_delay

func _process(delta : float) -> void:
	_elapsed += delta
	if _elapsed < 0.0:
		return
	var cycle := lift_time + hang_time + slam_time + settle_time + pause_time
	if cycle <= 0.0:
		return
	var index := int(floor(_elapsed / cycle))
	position = _pose(index, _elapsed - index * cycle)

func _setup() -> void:
	pass

func _pose(_index : int, _t : float) -> Vector2:
	return base_pos

func _key(to : Vector2, duration : float, easing := Tween.EASE_IN_OUT, trans_y := Tween.TRANS_LINEAR, trans_x := trans_y) -> Dictionary:
	return {to = to, d = duration, ease = easing, ty = trans_y, tx = trans_x}

func _sample(from : Vector2, keys : Array, t : float) -> Vector2:
	for k in keys:
		var to : Vector2 = k.to
		var d : float = k.d
		if t < d:
			return Vector2(
				Tween.interpolate_value(from.x, to.x - from.x, t, d, k.tx, k.ease),
				Tween.interpolate_value(from.y, to.y - from.y, t, d, k.ty, k.ease))
		t -= d
		from = to
	return from
