extends Job
class_name MineJob

var res : resource
var _timer := 0.0

func _init(target_res : resource) -> void:
	res = target_res

func start(worker : Meeple) -> void:
	worker.move_to(res.global_position)

func update(worker : Meeple, delta : float) -> bool:
	if not worker.has_arrived():
		return false
	_timer += delta
	if _timer < res.wobble_interval:
		return false
	_timer -= res.wobble_interval
	return res.mine()
