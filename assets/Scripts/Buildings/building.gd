extends resource
class_name building

const CLOUD = preload("res://assets/Scenes/cloud.tscn")

const QUEUED_COLOR := Color(0.4, 0.6, 1, 0.6)

@export var width := 1

func _ready() -> void:
	super()
	modulate = QUEUED_COLOR
	area.input_pickable = false

func start_build() -> void:
	JobSystem.add_build_job(self)

func finish_build() -> void:
	modulate = Color.WHITE
	area.input_pickable = true
	var cloud = CLOUD.instantiate()
	cloud.position = position + offset * _base_scale
	cloud.scale = _base_scale
	cloud.z_index = z_index+1
	get_parent().add_child(cloud)
	cloud.animation_finished.connect(cloud.queue_free)
	cloud.play("default")

func _on_left_click() -> void:
	pass
	
func _get_preview():
	pass
