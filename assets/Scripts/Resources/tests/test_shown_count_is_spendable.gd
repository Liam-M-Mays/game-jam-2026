extends GameTest
## The wood the HUD shows is what placing checks, from #127: drops a site claimed are not in it, and a
## drop a builder carries to a pile is, because a site can claim it from that pile.

const MEEPLE_SCENE := preload("res://assets/Scenes/Meeple/meeple.tscn")
const PILE_SCENE := preload("res://assets/Scenes/Buildings/wood_pile.tscn")
const HUD_SCRIPT := preload("res://HUD.gd")

## A grid with no cells, so meeples and drops need no world.
class EmptyGrid extends Grid:
	func _ready() -> void:
		grid_size = 0

	func _exit_tree() -> void:
		_clear_drops()

## A job that never ends.
class StayJob extends Job:
	func update(_worker : Meeple, _delta : float) -> bool:
		return false

var _world : Node2D
var _grid : Grid
var _look : MeepleLook
var _pile : Storage
var _site : Building
var _builder : Meeple


## The runner starts tests from its own `_ready`, so the tree takes new nodes only after a frame.
## A pile at x 100 holding one wood, four loose wood far off at x 500, a site at x 0, and a builder
## who carries one of the far drops to the pile.
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
	_pile.store(_wood_at(Vector2(100, 0)))
	for i in 4:
		_wood_at(Vector2(500, i * 10))
	# Any building can stand for the site: the hauls only walk to it.
	_site = PILE_SCENE.instantiate()
	_site.grid = _grid
	_world.add_child(_site)
	_builder = Meeple.new(_grid, _look, Vector2(500, 0))
	JobSystem.add_worker(_builder)
	_builder.take_job(Storage.find_trip(_builder))


func after_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	_builder.free_item()
	_look.free()
	_world.free()
	Inventory.reset()


func _wood_at(spot : Vector2) -> ResourceDrop:
	return _grid.add_drop(ResourceDrop.scene_of("wood"), spot)


## The site asks for one wood, the way a building site does.
func _haul() -> HaulJob:
	Inventory.reserve("wood", 1)
	var haul := HaulJob.new(_site, "wood")
	JobSystem.add(haul)
	return haul


## The "have" part of the HUD's wood counter.
func _shown_wood() -> int:
	var hud : CanvasLayer = HUD_SCRIPT.new()
	hud.wood_label = Label.new()
	hud._refresh_counters()
	var shown := int(hud.wood_label.text.get_slice("/", 0))
	hud.wood_label.free()
	hud.free()
	return shown


func _can_place(wood : int) -> bool:
	var building := Building.new()
	var cost : Dictionary[String, int] = {"wood": wood}
	building.min_to_start = cost
	var can := building.can_afford()
	building.free()
	return can


func test_the_shown_wood_is_what_placing_checks() -> void:
	await _set_up()
	check(_builder.job is StoreJob, "the builder carries a drop to the pile")
	_haul()
	_haul()
	check_eq(Inventory.count("wood"), 5, "five wood exist")
	check_eq(_shown_wood(), 3, "the HUD leaves out the two the site claimed and keeps the one on its way to the pile")
	check(_can_place(3), "a building that costs what the HUD shows can be placed")
	check(not _can_place(4), "one more than the HUD shows cannot")
	for i in 3:
		_haul()
	check_eq(_shown_wood(), 0, "every wood the HUD showed could be claimed")
	check(_can_place(0) and not _can_place(1), "placing agrees at zero")


func test_a_haul_waiting_on_a_dropped_trip_takes_the_drop() -> void:
	await _set_up()
	var first := _haul()
	var second := _haul()
	check(first.takes_from(_pile) and second.takes_from(_pile), "both hauls claimed from the pile: its one wood and the one on its way")
	_builder.take_job(StayJob.new())
	check_eq(_pile.unclaimed(), 0, "the pile owes no more than it will get")
	check(first.takes_from(_pile) != second.takes_from(_pile), "one haul now takes the dropped wood from the ground")
	check_eq(_shown_wood(), 3, "the HUD still shows the three loose wood nobody claimed")
