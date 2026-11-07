extends Node2D
## Attach to the giant's arm (Node2D / Sprite2D).
## Same step cycle as the body and head. No rotation.
## Mimics the shoulder shifting as the giant walks: on one step the arm rises and
## slides left, lands, and stays there. On the next step it rises and slides back.
 
@export var shift_distance := 12.0  ## Pixels the arm moves left of its starting spot
@export var bob_height := 12.0      ## Subtle up/down rise (set to 30 to match the body exactly)
@export var bob_dip := 3.0          ## Small dip below rest on the slam
@export var lift_time := 1.4        ## Match the body's timings
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := 0      ## Optional lag so the arm trails the body
 
var base_pos: Vector2
var at_left := false   ## which shoulder position the arm is currently in
 
func _ready() -> void:
	base_pos = position
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	step_loop()
 
func step_loop() -> void:
	while is_inside_tree():
		# This step's destination: left of start, or back at start
		var moving_left := not at_left
		var target_x := base_pos.x - shift_distance if moving_left else base_pos.x
		var target_y := base_pos.y - bob_height if moving_left else base_pos.y
		at_left = not at_left
 
		# Up: arm slides to the new x position (rises only on the step left, not the step right)
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "position:y", target_y, lift_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(self, "position:x", target_x, lift_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		await get_tree().create_timer(hang_time).timeout
 
		# Down: body slams, arm stays at its new x
		t = create_tween()
		var dip_y := base_pos.y + bob_dip if moving_left else base_pos.y
		t.tween_property(self, "position:y", dip_y, slam_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await t.finished
 
		# Settle: body recovers, arm stays at its new x
		t = create_tween()
		t.tween_property(self, "position:y", base_pos.y, settle_time) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		await t.finished
		await get_tree().create_timer(pause_time).timeout
