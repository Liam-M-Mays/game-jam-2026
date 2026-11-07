extends Node2D
## Attach to any Node2D / Sprite2D. Bobs up and down like a giant's heavy steps.
 
@export var step_height := 3.0   ## Pixels to rise
@export var lift_time := 1.4      ## Slow, strained rise
@export var hang_time := 0.6      ## Hold at the top
@export var slam_time := 0.5      ## Fast drop
@export var settle_time := 0.8    ## Slow recovery after impact
@export var pause_time := 1.0     ## Rest between steps
@export var start_delay := 0.2   ## Seconds to wait before the first step
 
var base_y: float
 
func _ready() -> void:
	base_y = position.y
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	step_loop()
 
func step_loop() -> void:
	while is_inside_tree():
		# Slow lift
		var t := create_tween()
		t.tween_property(self, "position:y", base_y - step_height, lift_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		await get_tree().create_timer(hang_time).timeout
 
		# Fast slam, dipping slightly below the starting height
		t = create_tween()
		t.tween_property(self, "position:y", base_y + 8.0, slam_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await t.finished
 
		# Heavy settle back to rest
		t = create_tween()
		t.tween_property(self, "position:y", base_y, settle_time) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		await t.finished
		await get_tree().create_timer(pause_time).timeout
