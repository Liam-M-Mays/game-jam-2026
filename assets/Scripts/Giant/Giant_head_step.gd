extends Node2D
## Attach to the giant's head (Node2D / Sprite2D).
## Same heavy step cycle as the body, with the head only ever swaying to the right.

@export var step_height := 3.0   ## Pixels to rise (match the body)
@export var sway := 6.0          ## Max pixels to the right the head drifts
@export var lift_time := 1.4      ## Match the body's timings
@export var hang_time := 0.6
@export var slam_time := 0.5
@export var settle_time := 0.8
@export var pause_time := 1.0
@export var start_delay := .25    ## Optional lag so the head trails the body

var base_pos: Vector2

func _ready() -> void:
	base_pos = position
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	step_loop()

func step_loop() -> void:
	while is_inside_tree():
		# Slow lift, head eases slightly right
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "position:y", base_pos.y - step_height, lift_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(self, "position:x", base_pos.x + sway * 0.4, lift_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		await get_tree().create_timer(hang_time).timeout

		# Fast slam, head lurches right on impact
		t = create_tween().set_parallel(true)
		t.tween_property(self, "position:y", base_pos.y + 8.0, slam_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(self, "position:x", base_pos.x + sway, slam_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await t.finished

		# Settle: heavy recovery, head drifts back to center without going behind it
		t = create_tween().set_parallel(true)
		t.tween_property(self, "position:y", base_pos.y, settle_time) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position:x", base_pos.x, settle_time) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		await t.finished
		await get_tree().create_timer(pause_time).timeout
