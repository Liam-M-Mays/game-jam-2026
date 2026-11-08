extends Job
class_name HarvestJob

var target : Harvestable
var _timer := 0.0

func _init(target_harvestable : Harvestable) -> void:
	target = target_harvestable

func start(worker : Meeple) -> void:
	worker.move_to(target.global_position, target.cells)

func update(worker : Meeple, delta : float) -> bool:
	if cancelled:
		worker.stop()
		return true
	if not worker.has_arrived():
		return false
	_timer += delta
	if _timer < target.wobble_interval:
		return false
	_timer -= target.wobble_interval
	if not target.harvest():
		#Inventory.spend("food", target.food_cost)
		return false
	Inventory.spend("food", target.food_cost)
	return true

func abort(_worker : Meeple) -> void:
	_timer = 0.0
