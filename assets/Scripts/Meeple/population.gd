extends Node

signal all_meeples_died

## The food and growth numbers, shared with Inventory and the food bar.
const RULES : VillageRules = preload("res://assets/Res/village_rules.tres")

var huts : Array[Hut] = []

var _timer := 0.0
var _grow_wait := 0.0

func _ready() -> void:
	_grow_wait = randf_range(RULES.grow_min_delay, RULES.grow_max_delay)

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
	_timer += delta
	if _timer < RULES.starve_tick:
		return
	_timer -= RULES.starve_tick
	if GameState.hunger < RULES.starve_below:
		_starve()

func _can_grow() -> bool:
	return GameState.hunger > RULES.grow_above and Inventory.count("food") > 0 and JobSystem.workers.size() < capacity()

func _update_growth(delta : float) -> void:
	if not _can_grow():
		return
	_grow_wait -= delta
	if _grow_wait > 0.0:
		return
	_grow_wait = randf_range(RULES.grow_min_delay, RULES.grow_max_delay)
	huts.pick_random().spawn_meeple()

func _starve() -> void:
	if JobSystem.workers.is_empty() or randf() >= RULES.death_chance:
		return
	var victim : Meeple = JobSystem.workers.pick_random()
	victim.die()
	print("A meeple starved")
	if JobSystem.workers.is_empty():
		print("you ded")
		all_meeples_died.emit()
