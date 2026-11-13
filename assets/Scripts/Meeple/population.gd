extends Node

signal all_meeples_died

## The food and growth numbers, shared with Inventory and the food bar. A variable, not a constant:
## GDScript would copy a constant resource's numbers into the code when it compiles.
var rules : VillageRules = preload("res://assets/Res/village_rules.tres")

var huts : Array[Hut] = []

var _grow_wait := 0.0

func _ready() -> void:
	_grow_wait = randf_range(rules.grow_min_delay, rules.grow_max_delay)

func capacity() -> int:
	var total := 0
	for hut in huts:
		total += hut.meeple_capacity
	return total

func add_hut(hut : Hut) -> void:
	huts.append(hut)

func remove_hut(hut : Hut) -> void:
	huts.erase(hut)

func _process(delta : float) -> void:
	_update_growth(delta)

## A meeple just did some work. With no food in the village, it may die of it.
func after_work(meeple : Meeple) -> void:
	if Inventory.count("food") > 0 or randf() >= rules.death_chance_per_action:
		return
	meeple.die()
	if JobSystem.workers.is_empty():
		all_meeples_died.emit()

func _can_grow() -> bool:
	return GameState.hunger > rules.grow_above and Inventory.count("food") > 0 and JobSystem.workers.size() < capacity()

func _update_growth(delta : float) -> void:
	if not _can_grow():
		return
	_grow_wait -= delta
	if _grow_wait > 0.0:
		return
	_grow_wait = randf_range(rules.grow_min_delay, rules.grow_max_delay)
	huts.pick_random().spawn_meeple()
