extends VillagePart
## The demo's stand-in for nature, a building site and the meeples. It is not
## part of the game.
##
## It only calls the stock, the way the later parts will:
## - Things "break" and leave wood or stone on the ground.
## - A building site reserves units, and a haul claims the closest one, picks
##   it up and hands it over.
## - A storage worker carries loose drops to a pile.
## - A bush gives food, and the village eats.
## It sleeps on timers in between and takes its random numbers from the
## village, so the same seed plays the same film every time.

const DROP_SECONDS := 0.35
const SITE_SECONDS := 1.2
const STORE_SECONDS := 1.6
const BUSH_SECONDS := 2.0
const EAT_SECONDS := 1.5
## How far a drop lands from the thing that broke, in art pixels. The jam
## game's numbers are 30 to 80 screen pixels, at 10 screen pixels to one.
const LAND_NEAR := 3.0
const LAND_FAR := 8.0
## How many art pixels a second a stand-in hauler covers. The jam meeple
## walks 100 screen pixels a second.
const WALK_SPEED := 10.0
const BUSH_FOOD := 2
const EAT_FOOD := 1
const PILE_ROOM := 12
const MOST_HAULS := 6

## The building site that asks for wood and stone.
var site: int = 0
## Where the site stands, in art pixels.
var site_spot := Vector2.ZERO
## The piles: storage id, then where it stands.
var piles: Dictionary[int, Vector2] = {}
## The hauls on their way: haul id, then from, to, the two ticks of the walk,
## the kind, and whether the unit is carried yet.
var trips: Dictionary[int, Dictionary] = {}
## While false, nothing is hauled or stored, so drops only pile up.
var hauling: bool = true
## How many times a bush could not be picked because the food was full.
var bush_refused: int = 0
## What the last closest-drop lookup cost: drops looked at, cells read.
var last_lookup := Vector2i.ZERO
## How many loose drops of its kind lay on the ground for that lookup.
var last_lookup_loose: int = 0

var _cells: Array[Vector2i] = []
var _wood: int = 0
var _stone: int = 0
var _food: int = 0


func _init(cells: Array[Vector2i]) -> void:
	_cells = cells


## Places the site and the two piles, and sets the timers.
func start(village: Village) -> void:
	var stock: VillageStock = village.part(Village.STOCK)
	_wood = stock.number_of(&"wood")
	_stone = stock.number_of(&"stone")
	_food = stock.number_of(&"food")
	site = village.new_id()
	site_spot = GridLayout.position_of(Vector2i(0, 5))
	for entry: Array in [[_wood, Vector2i(-7, 2)], [_stone, Vector2i(5, -6)]]:
		var pile := village.new_id()
		var spot := GridLayout.position_of(entry[1])
		if stock.add_storage(pile, entry[0], PILE_ROOM, spot):
			piles[pile] = spot
	village.timers.wake_after(village.ticks_for(DROP_SECONDS), _break_something)
	village.timers.wake_after(village.ticks_for(SITE_SECONDS), _site_asks)
	village.timers.wake_after(village.ticks_for(STORE_SECONDS), _store_one)
	village.timers.wake_after(village.ticks_for(BUSH_SECONDS), _pick_bush)
	village.timers.wake_after(village.ticks_for(EAT_SECONDS), _eat)


## Forgets everything.
func close() -> void:
	trips.clear()
	piles.clear()
	_cells.clear()


## The demo state as plain data.
func snapshot() -> Dictionary:
	return {
		"site": site,
		"piles": piles.duplicate(),
		"trips": trips.duplicate(true),
		"hauling": hauling,
		"bush_refused": bush_refused,
	}


## Lays [param count] drops on random spots, half wood and half stone.
func burst(village: Village, count: int) -> void:
	var stock: VillageStock = village.part(Village.STOCK)
	for i in count:
		stock.drop(_wood if i % 2 == 0 else _stone, _random_spot(village))


func _break_something(village: Village) -> void:
	var stock: VillageStock = village.part(Village.STOCK)
	var rng := village.rng
	var from := _random_spot(village)
	var kind := _wood if rng.randf() < 0.6 else _stone
	for i in rng.randi_range(1, 2):
		var reach := rng.randf_range(LAND_NEAR, LAND_FAR)
		var landing := from + Vector2.from_angle(rng.randf() * TAU) * reach
		# A drop only lands on a cell. If there is none, it stays where the thing stood.
		if stock.drop(kind, landing) == GridDrops.NO_DROP:
			stock.drop(kind, from)
	village.timers.wake_after(village.ticks_for(DROP_SECONDS), _break_something)


## The site asks for one unit, and a free haul goes for the closest one.
func _site_asks(village: Village) -> void:
	village.timers.wake_after(village.ticks_for(SITE_SECONDS), _site_asks)
	if not hauling or trips.size() >= MOST_HAULS:
		return
	var stock: VillageStock = village.part(Village.STOCK)
	var kind := _wood if village.rng.randf() < 0.5 else _stone
	if not stock.claims.reserve(site, kind):
		return
	var haul := village.new_id()
	var hauler_stands := _random_spot(village)
	var loose := village.grid.drops.loose(kind)
	if not stock.claims.claim_closest(haul, site, kind, hauler_stands):
		stock.claims.unreserve(site, kind)
		return
	last_lookup = Vector2i(village.grid.drops.looked_at, village.grid.drops.cells_read)
	last_lookup_loose = loose
	_walk(village, haul, hauler_stands, stock.claims.spot_of(haul), kind, site_spot)


## The storage worker of a pile carries the closest loose drop to it.
func _store_one(village: Village) -> void:
	village.timers.wake_after(village.ticks_for(STORE_SECONDS), _store_one)
	if not hauling or trips.size() >= MOST_HAULS:
		return
	var stock: VillageStock = village.part(Village.STOCK)
	for pile: int in piles:
		var kind := stock.storages.kind_of(pile)
		var drop := village.grid.drops.closest(kind, piles[pile])
		var haul := village.new_id()
		if stock.claims.claim_for_storage(haul, pile, drop):
			_walk(village, haul, piles[pile], stock.claims.spot_of(haul), kind, piles[pile])
			return


## Starts the walk to the claimed unit. [param target] is where it goes after.
func _walk(
	village: Village, haul: int, from: Vector2, to: Vector2, kind: int, target: Vector2
) -> void:
	var ticks := village.ticks_for(from.distance_to(to) / WALK_SPEED)
	trips[haul] = {
		"from": from, "to": to, "start": village.now, "end": village.now + ticks,
		"kind": kind, "carried": false, "target": target,
	}
	village.timers.wake_after(ticks, _arrive.bind(haul))


func _arrive(village: Village, haul: int) -> void:
	var stock: VillageStock = village.part(Village.STOCK)
	var trip: Dictionary = trips[haul]
	if trip["carried"]:
		stock.claims.hand_over(haul)
		trips.erase(haul)
		return
	stock.claims.pick_up(haul)
	var target: Vector2 = trip["target"]
	var ticks := village.ticks_for(trip["to"].distance_to(target) / WALK_SPEED)
	trip["from"] = trip["to"]
	trip["to"] = target
	trip["start"] = village.now
	trip["end"] = village.now + ticks
	trip["carried"] = true
	village.timers.wake_after(ticks, _arrive.bind(haul))


func _pick_bush(village: Village) -> void:
	var stock: VillageStock = village.part(Village.STOCK)
	# Being full blocks picking, as in the jam game.
	if stock.is_full(_food):
		bush_refused += 1
	else:
		stock.add(_food, BUSH_FOOD)
	village.timers.wake_after(village.ticks_for(BUSH_SECONDS), _pick_bush)


func _eat(village: Village) -> void:
	var stock: VillageStock = village.part(Village.STOCK)
	stock.spend(_food, EAT_FOOD)
	village.timers.wake_after(village.ticks_for(EAT_SECONDS), _eat)


func _random_spot(village: Village) -> Vector2:
	var rng := village.rng
	var cell := _cells[rng.randi_range(0, _cells.size() - 1)]
	var middle := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
	return middle + Vector2(rng.randf_range(-3.4, 3.4), rng.randf_range(-2.4, 2.4))
