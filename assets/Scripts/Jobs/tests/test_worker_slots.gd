extends GameTest
## Worker slots, from #7: a worker never takes the player's jobs, the dev rule fills an open slot
## with the nearest builder but keeps one builder, and a dead worker is replaced.

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


func test_worker_skips_player_jobs_and_one_builder_stays() -> void:
	var far := _meeple_at(Vector2(0, 0))
	var near := _meeple_at(Vector2(90, 0))
	JobSystem.open_slot(_building)
	JobSystem.match_jobs()
	check(near.workplace == _building, "the nearest builder took the slot")
	JobSystem.open_slot(_building)
	JobSystem.match_jobs()
	check(far.workplace == null, "the last builder stayed a builder")
	var job := SpotJob.new(Vector2(90, 0))
	JobSystem.add(job)
	JobSystem.match_jobs()
	check(near.job == null, "the worker did not take the player's job")
	check(far.job == job, "the builder took the player's job")


func test_dead_worker_is_replaced_by_the_nearest_builder() -> void:
	_meeple_at(Vector2(0, 0))
	var worker := _meeple_at(Vector2(90, 0))
	var next := _meeple_at(Vector2(150, 0))
	JobSystem.open_slot(_building)
	JobSystem.match_jobs()
	check(worker.workplace == _building, "the nearest builder took the slot")
	worker.die()
	JobSystem.match_jobs()
	check(next.workplace == _building, "the nearest builder replaced the dead worker")
	check_eq(_building.workers.size(), 1, "the building has one worker again")
