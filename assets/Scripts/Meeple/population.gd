extends Node

const TICK := 4.0
const DEATH_CHANCE := 0.25

var huts : Array[Hut] = []

var _timer := 0.0

func _ready() -> void:
	Inventory.shortage.connect(_on_shortage)

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
	_timer += delta
	if _timer < TICK:
		return
	_timer -= TICK
	if Inventory.count("food") > 0 and JobSystem.workers.size() < capacity():
		huts.pick_random().spawn_meeple()

func _on_shortage(kind : String, missing : int) -> void:
	if kind != "food":
		return
	for i in missing:
		_starve()

func _starve() -> void:
	if JobSystem.workers.is_empty() or randf() >= DEATH_CHANCE:
		return
	var victim : Meeple = JobSystem.workers.pick_random()
	victim.die()
	print("A meeple starved")
	if JobSystem.workers.is_empty():
		print("you ded")
