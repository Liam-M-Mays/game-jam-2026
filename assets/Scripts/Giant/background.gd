extends Node2D
## Attach to any Node2D / Sprite2D. Moves it to the left at a constant speed.

@export var speed := -100.0   ## Pixels per second

func _process(delta: float) -> void:
	position.x -= speed * delta
