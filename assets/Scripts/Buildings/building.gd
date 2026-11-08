extends GridObject
class_name Building

signal completed

const BUILD_EFFECT := preload("res://assets/Scenes/Effects/cloud.tscn")

@export var costs : Dictionary[String, int] = {}
## Tick on if the sheet runs finished -> empty (left to right) instead of empty -> finished.
@export var reverse_frames := false

var _delivered := 0

func _ready() -> void:
	super()
	area.input_pickable = false

func show_as_preview() -> void:
	_set_stage(hframes - 1)

## 0 = empty plot, hframes - 1 = finished, regardless of sheet direction.
func _set_stage(stage : int) -> void:
	frame = hframes - 1 - stage if reverse_frames else stage

func total_cost() -> int:
	var total := 0
	for kind in costs:
		total += costs[kind]
	return total

func can_afford() -> bool:
	for kind in costs:
		if Inventory.available(kind) < costs[kind]:
			return false
	return true

func can_start() -> bool:
	return can_afford() and JobSystem.has_room(total_cost())

func start_construction() -> void:
	_set_stage(0)
	if total_cost() == 0:
		complete()
		return
	for kind in costs:
		Inventory.reserve(kind, costs[kind])
		for i in range(costs[kind]):
			JobSystem.add(HaulJob.new(self, kind))

func deliver() -> void:
	_delivered += 1
	_set_stage(floori(float(hframes - 1) * _delivered / total_cost()))
	if _delivered == total_cost():
		complete()

func complete() -> void:
	_set_stage(hframes - 1)
	area.input_pickable = true
	spawn_effect(BUILD_EFFECT, 1)
	completed.emit()
