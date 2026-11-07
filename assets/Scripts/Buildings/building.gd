extends GridObject
class_name Building

const BUILD_EFFECT := preload("res://assets/Scenes/cloud.tscn")

@export var costs : Dictionary[String, int] = {}

var _delivered := 0

func _ready() -> void:
	super()
	area.input_pickable = false

func show_as_preview() -> void:
	frame = hframes - 1

func can_start() -> bool:
	for kind in costs:
		if Inventory.available(kind) < costs[kind]:
			return false
	return JobSystem.has_room(_total_cost())

func start_build() -> void:
	if _total_cost() == 0:
		complete()
		return
	for kind in costs:
		Inventory.reserve(kind, costs[kind])
		for i in range(costs[kind]):
			JobSystem.add(HaulJob.new(self, kind))

func deliver() -> void:
	_delivered += 1
	frame = floori(float(hframes - 1) * _delivered / _total_cost())
	if _delivered == _total_cost():
		complete()

func complete() -> void:
	frame = hframes - 1
	area.input_pickable = true
	spawn_effect(BUILD_EFFECT, 1)

func _total_cost() -> int:
	var total := 0
	for kind in costs:
		total += costs[kind]
	return total
