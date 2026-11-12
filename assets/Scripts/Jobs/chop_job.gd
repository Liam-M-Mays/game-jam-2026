extends IdleJob
class_name ChopJob

var target : Harvestable
var _timer := 0.0

func _init(target_tree : Harvestable) -> void:
	target = target_tree
	target.claim(self)

func place() -> Vector2:
	return target.global_position

func start(worker : Meeple) -> void:
	worker.move_to(target.global_position, target.cells)

func update(worker : Meeple, delta : float) -> bool:
	if not is_instance_valid(site) or not is_instance_valid(target):
		abort(worker)
		return true
	if not worker.has_arrived():
		return false
	_timer += delta
	if _timer < target.wobble_interval:
		return false
	_timer -= target.wobble_interval
	if not target.harvest():
		return false
	Inventory.spend("food", target.food_cost)
	target = null
	return true

func abort(_worker : Meeple) -> void:
	_timer = 0.0
	if is_instance_valid(target):
		target.release(self)
	target = null
