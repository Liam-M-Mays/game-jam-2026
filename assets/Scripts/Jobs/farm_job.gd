extends Job
class_name FarmJob
## The barn's worker harvests one of the barn's ripe farms.

var farm : Farm
var _timer := 0.0

func _init(target_farm : Farm) -> void:
	farm = target_farm

func goes_to(building : Building) -> bool:
	return farm == building

func start(worker : Meeple) -> void:
	worker.move_to(farm.global_position, farm.cells)

func update(worker : Meeple, delta : float) -> bool:
	if not is_instance_valid(farm) or not farm.can_harvest_now():
		return true
	if not worker.has_arrived():
		return false
	_timer += delta
	if _timer < farm.harvest_time:
		return false
	farm.harvest_crop()
	return true

func abort(_worker : Meeple) -> void:
	_timer = 0.0
