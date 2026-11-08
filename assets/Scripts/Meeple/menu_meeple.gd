extends Sprite2D
class_name MenuMeeple

const OFFSCREEN := 80.0

var fall_speed := 300.0
var spin := 0.0

func _ready() -> void:
	self_modulate = Color.from_hsv(randf(), 0.8, 0.9)

func _process(delta : float) -> void:
	position.y += fall_speed * delta
	rotation += spin * delta
	if position.y > get_viewport_rect().size.y + OFFSCREEN:
		queue_free()
