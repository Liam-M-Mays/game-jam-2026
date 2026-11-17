extends GameTest
## Free builders carry loose drops to the piles, from #125: a builder with no job takes the drop
## nearest to it to a pile with room, and a player's job takes it off that trip.

const MEEPLE_SCENE := preload("res://assets/Scenes/Meeple/meeple.tscn")
const PILE_SCENE := preload("res://assets/Scenes/Buildings/wood_pile.tscn")

## A grid with no cells, so meeples and drops need no world.
class EmptyGrid extends Grid:
	func _ready() -> void:
		grid_size = 0

	func _exit_tree() -> void:
		_clear_drops()

## A job at a fixed spot that never ends.
class SpotJob extends Job:
	var at : Vector2

	func _init(spot : Vector2) -> void:
		at = spot

	func place() -> Vector2:
		return at

	func update(_worker : Meeple, _delta : float) -> bool:
		return false

var _world : Node2D
var _grid : Grid
var _look : MeepleLook
var _pile : Storage
var _meeples : Array[Meeple] = []


## The runner starts tests from its own `_ready`, so the tree takes new nodes only after a frame.
func _set_up() -> void:
	await tree.process_frame
	JobSystem.reset()
	JobSystem.workers.clear()
	Inventory.reset()
	_world = Node2D.new()
	tree.root.add_child(_world)
	_grid = EmptyGrid.new()
	_world.add_child(_grid)
	_look = MEEPLE_SCENE.instantiate()
	_pile = PILE_SCENE.instantiate()
	_pile.grid = _grid
	_pile.position = Vector2(100, 0)
	_world.add_child(_pile)
	_pile.add_to_group(Storage.GROUP)


func after_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	for meeple in _meeples:
		meeple.free_item()
	_meeples.clear()
	_look.free()
	_world.free()
	Inventory.reset()


func _builder_at(spot : Vector2) -> Meeple:
	var meeple := Meeple.new(_grid, _look, spot)
	_meeples.append(meeple)
	JobSystem.add_worker(meeple)
	return meeple


func _wood_at(spot : Vector2) -> ResourceDrop:
	return _grid.add_drop(ResourceDrop.scene_of("wood"), spot)


func test_a_free_builder_carries_the_nearest_drop_to_a_pile() -> void:
	await _set_up()
	var builder := _builder_at(Vector2.ZERO)
	var near := _wood_at(Vector2(30, 0))
	var far := _wood_at(Vector2(-200, 0))
	builder.tick(1.0)
	check(builder.job is StoreJob, "the builder with no job started a store trip")
	check(near.claimed and not far.claimed, "it went for the drop nearest to it")
	check(builder.is_free(), "a builder on a store trip is still free for the player's jobs")
	for i in range(400):
		builder.tick(0.05)
		if _pile.held() > 0:
			break
	check_eq(_pile.held(), 1, "the drop was stored in the pile")


func test_a_player_job_takes_a_builder_off_its_store_trip() -> void:
	await _set_up()
	var builder := _builder_at(Vector2.ZERO)
	var drop := _wood_at(Vector2(30, 0))
	builder.tick(1.0)
	check(builder.job is StoreJob, "the builder started a store trip")
	var job := SpotJob.new(Vector2(50, 0))
	JobSystem.add(job)
	JobSystem.match_jobs()
	check(builder.job == job, "the player's job took the builder")
	check(not drop.claimed, "the drop is loose again for the next builder")
	check_eq(Inventory.available("wood"), 1, "the drop counts as loose wood again")


func test_no_trip_when_the_piles_are_full() -> void:
	await _set_up()
	for i in range(_pile.capacity()):
		_pile.store(_wood_at(Vector2.ZERO))
	var builder := _builder_at(Vector2.ZERO)
	_wood_at(Vector2(30, 0))
	builder.tick(1.0)
	check(builder.job == null, "with no room in any pile the builder stays free")
