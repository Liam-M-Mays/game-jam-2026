extends resource
class_name building

const QUEUED_COLOR := Color(0.4, 0.6, 1, 0.6)

@export var width := 1

func _ready() -> void:
	super()
	modulate = QUEUED_COLOR
	area.input_pickable = false

func finish_build() -> void:
	modulate = Color.WHITE
	area.input_pickable = true

func _on_left_click() -> void:
	pass
