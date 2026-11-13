extends GameTest
## Piles keep a count per kind instead of drop nodes, from part 5a of #14. A haul that takes from a
## pile keeps the stock count the same until it delivers, and `Inventory.changed` fires once a frame.

const PILE_SCENE := preload("res://assets/Scenes/Buildings/wood_pile.tscn")

var _world : Node2D
var _pile : Storage


## The runner starts tests from its own `_ready`, so the tree takes new nodes only after a frame.
func _set_up() -> void:
	await tree.process_frame
	Inventory.reset()
	_world = Node2D.new()
	tree.root.add_child(_world)
	_pile = PILE_SCENE.instantiate()
	_world.add_child(_pile)
	_pile.add_to_group(Storage.GROUP)


func after_each() -> void:
	_world.free()
	Inventory.reset()


func _store_one() -> void:
	var drop := ResourceDrop.make("wood")
	_world.add_child(drop)
	_pile.store(drop)


func test_a_haul_from_a_pile_keeps_the_count_until_delivery() -> void:
	await _set_up()
	_store_one()
	_store_one()
	check_eq(_pile.held(), 2, "the pile holds both drops")
	check_eq(Inventory.count("wood"), 2, "stored drops count once, not as nodes and a number")
	check_eq(Inventory.all_drops().size(), 0, "no drop node is left for the stored drops")
	Inventory.reserve("wood", 1)
	check(Inventory.claim_closest("wood", Vector2.ZERO) == _pile, "the haul claims from the pile")
	check_eq(Inventory.available("wood"), 1, "one drop is left to claim")
	var carried := _pile.take()
	check_eq(_pile.held(), 1, "the pile gave one drop")
	check_eq(Inventory.count("wood"), 2, "the carried drop still counts")
	carried.consume()
	check_eq(Inventory.count("wood"), 1, "the delivered drop is gone")


func test_changed_fires_once_a_frame() -> void:
	await _set_up()
	await tree.process_frame
	var fired := [0]
	var count_it := func() -> void: fired[0] += 1
	Inventory.changed.connect(count_it)
	_store_one()
	_store_one()
	Inventory.add("food", 1)
	check_eq(fired[0], 0, "nothing fires before the frame ends")
	await tree.process_frame
	await tree.process_frame
	Inventory.changed.disconnect(count_it)
	check_eq(fired[0], 1, "three changes in one frame fire once")
