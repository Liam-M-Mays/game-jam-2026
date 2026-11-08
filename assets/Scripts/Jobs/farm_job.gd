extends IdleJob
class_name FarmJob

var _timer := 0.0

func start(worker : Meeple) -> void:
	worker.move_to(site.global_position, site.cells)

func update(worker : Meeple, delta : float) -> bool:
	if cancelled:
		worker.stop()
		return true
	var farm := site as Farm
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
