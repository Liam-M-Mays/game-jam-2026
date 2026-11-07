extends resource
class_name building

const CLOUD = preload("res://assets/Scenes/cloud.tscn")

const QUEUED_COLOR := Color(0.4, 0.6, 1, 0.6)

@export var width := 1
@export var wood_cost := 0
@export var stone_cost := 0

var _delivered := 0

func _ready() -> void:
	super()
	modulate = QUEUED_COLOR
	area.input_pickable = false

func total_cost() -> int:
	return wood_cost + stone_cost

func can_afford() -> bool:
	return Inventory.available("wood") >= wood_cost and Inventory.available("stone") >= stone_cost

func start_build() -> void:
	modulate = Color.WHITE
	if total_cost() == 0:
		frame = hframes - 1
		finish_build()
		return
	_queue_hauls("wood", wood_cost)
	_queue_hauls("stone", stone_cost)

func _queue_hauls(kind : String, amount : int) -> void:
	Inventory.reserve(kind, amount)
	for i in range(amount):
		JobSystem.add_haul_job(self, kind)

func deliver() -> void:
	_delivered += 1
	frame = floori(float(hframes - 1) * _delivered / total_cost())
	if _delivered == total_cost():
		finish_build()

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
