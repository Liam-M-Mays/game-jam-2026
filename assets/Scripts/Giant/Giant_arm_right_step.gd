extends Node2D
 
@export var shift_distance := 12.0
@export var bob_height := 12.0
@export var bob_dip := 3.0
@export var lift_time := 1.4
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := 0
 
var base_pos: Vector2
var at_left := true
 
func _ready() -> void:
	base_pos = position
	base_pos.x += shift_distance
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	step_loop()
 
func step_loop() -> void:
	while is_inside_tree():
		var moving_left := not at_left
		var target_x := base_pos.x - shift_distance if moving_left else base_pos.x
		var target_y := base_pos.y - bob_height if moving_left else base_pos.y
		at_left = not at_left
 
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "position:y", target_y, lift_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(self, "position:x", target_x, lift_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		await get_tree().create_timer(hang_time).timeout
 
		t = create_tween()
		var dip_y := base_pos.y + bob_dip if moving_left else base_pos.y
		t.tween_property(self, "position:y", dip_y, slam_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await t.finished
 
		t = create_tween()
		t.tween_property(self, "position:y", base_pos.y, settle_time) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		await t.finished
		await get_tree().create_timer(pause_time).timeout
