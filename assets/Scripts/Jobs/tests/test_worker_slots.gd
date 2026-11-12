extends GameTest
## Worker slots, from #7: the panel's add arrow takes the nearest builder, the remove arrow
## makes the worker a builder again, a worker never takes the player's jobs, and a dead worker is replaced.

const MEEPLE_SCENE := preload("res://assets/Scenes/Meeple/meeple.tscn")

## A job at a fixed spot that never ends.
class SpotJob extends Job:
	var at : Vector2

	func _init(spot : Vector2) -> void:
		at = spot

	func place() -> Vector2:
		return at

	func update(_worker : Meeple, _delta : float) -> bool:
		return false

var _grid : Grid
var _look : MeepleLook
var _building : Building
var _meeples : Array[Meeple] = []


func before_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	_grid = Grid.new()
	_look = MEEPLE_SCENE.instantiate()
	_building = Building.new()
	_building.worker_slots = 1
	_building.position = Vector2(100, 0)


func after_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	for meeple in _meeples:
		meeple.free_item()
	_look.free()
	_grid.free()
	_building.free()


func _meeple_at(spot : Vector2) -> Meeple:
	var meeple := Meeple.new(_grid, _look, spot)
	_meeples.append(meeple)
	JobSystem.add_worker(meeple)
	return meeple


func test_arrows_add_and_remove_a_worker() -> void:
	var far := _meeple_at(Vector2(0, 0))
	var near := _meeple_at(Vector2(90, 0))
	_building.add_worker_slot()
	_building.add_worker_slot()
	JobSystem.match_jobs()
	check(near.workplace == _building, "the nearest builder took the slot")
	check(far.workplace == null, "the add arrow stops at the building's cap")
	var job := SpotJob.new(Vector2(90, 0))
	JobSystem.add(job)
	JobSystem.match_jobs()
	check(near.job == null, "the worker did not take the player's job")
	check(far.job == job, "the builder took the player's job")
	_building.remove_worker_slot()
	JobSystem.match_jobs()
	check(near.workplace == null and _building.workers.is_empty(), "the remove arrow made the worker a builder again")
	check(near.is_free(), "the old worker is free for the player's jobs")


func test_dead_worker_is_replaced_by_the_nearest_builder() -> void:
	_meeple_at(Vector2(0, 0))
	var worker := _meeple_at(Vector2(90, 0))
	var next := _meeple_at(Vector2(150, 0))
	_building.add_worker_slot()
	JobSystem.match_jobs()
	check(worker.workplace == _building, "the nearest builder took the slot")
	worker.die()
	JobSystem.match_jobs()
	check(next.workplace == _building, "the nearest builder replaced the dead worker")
	check_eq(_building.workers.size(), 1, "the building has one worker again")
