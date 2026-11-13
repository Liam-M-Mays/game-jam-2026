extends GameTest
## From #141: a meeple that works while the village has no food may die of it.
## The chance is VillageRules.death_chance_per_action. With food, working never kills.

const MEEPLE_SCENE := preload("res://assets/Scenes/Meeple/meeple.tscn")
const ACTIONS := 50

## A job that does one action every frame and never ends, like chopping a tree that never falls.
class ActionJob extends Job:
	func update(worker : Meeple, _delta : float) -> bool:
		worker.did_work()
		return false

var _grid : Grid
var _look : MeepleLook
var _meeple : Meeple
var _chance_before : float


func before_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	Inventory.reset()
	_chance_before = Population.rules.death_chance_per_action
	Population.rules.death_chance_per_action = 1.0
	_grid = Grid.new()
	_look = MEEPLE_SCENE.instantiate()
	_meeple = Meeple.new(_grid, _look, Vector2.ZERO)
	JobSystem.add_worker(_meeple)
	_meeple.take_job(ActionJob.new())


func after_each() -> void:
	Population.rules.death_chance_per_action = _chance_before
	JobSystem.reset()
	JobSystem.workers.clear()
	Inventory.reset()
	_meeple.free_item()
	_look.free()
	_grid.free()


func test_working_with_no_food_kills_at_chance_one() -> void:
	Inventory.spend("food", Inventory.count("food"))
	check_eq(Inventory.count("food"), 0, "the village has no food")
	_meeple.tick(0.1)
	check(not JobSystem.workers.has(_meeple), "the meeple died after one action with no food")
	check(not _meeple.is_free(), "a dead meeple takes no more jobs")


func test_working_with_food_never_kills() -> void:
	Inventory.add("food", 5)
	for i in range(ACTIONS):
		_meeple.tick(0.1)
	check(JobSystem.workers.has(_meeple), "the meeple is alive after %d actions with food" % ACTIONS)
