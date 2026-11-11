extends GameTest
## Checks the stock as a part of a village: the same seed and commands give
## the same village, and a closed village lets go of its stock.

const TICKS_PER_SECOND := 20
const TICKS := 600
const MAP := Vector2i(24, 24)
const SITE := 601
const PILE := 501
const SILO := 502


## A stand-in for nature and haulers. It wakes on a timer and does one
## random thing to the stock, with the random numbers of the village.
class Work:
	extends VillagePart
	var steps: int = 0
	var _next_haul: int = 700

	## Adds a pile and a silo, and goes to sleep for the first time.
	func start(village: Village) -> void:
		var stock: VillageStock = village.part(Village.STOCK)
		stock.add_storage(PILE, stock.number_of(&"wood"), 30, Vector2(60.0, 40.0))
		stock.add_storage(SILO, stock.number_of(&"food"), 20, Vector2(90.0, 40.0))
		village.timers.wake_after(1, _wake)

	## How often it woke, and the last haul id it used.
	func snapshot() -> Dictionary:
		return {"steps": steps, "next_haul": _next_haul}

	func _wake(village: Village) -> void:
		steps += 1
		var stock: VillageStock = village.part(Village.STOCK)
		var claims := stock.claims
		var rng := village.rng
		var kind := rng.randi_range(1, 2)
		var cell := Vector2i(rng.randi_range(0, MAP.x - 1), rng.randi_range(0, MAP.y - 1))
		var spot := GridLayout.position_of(cell) + Vector2(rng.randf_range(-3.0, 3.0), 0.0)
		var haul := 700 + rng.randi_range(0, 9)
		match rng.randi_range(0, 7):
			0, 1:
				stock.drop(kind, spot)
			2:
				stock.add(stock.number_of(&"food"), rng.randi_range(1, 4))
				stock.spend(stock.number_of(&"food"), rng.randi_range(1, 4))
			3:
				claims.reserve(SITE, kind)
			4:
				claims.claim_closest(haul, SITE, kind, spot)
			5:
				claims.claim_for_storage(haul, PILE, village.grid.drops.closest(1, spot))
			6:
				claims.pick_up(haul)
				claims.release(700 + rng.randi_range(0, 9), spot)
			7:
				claims.hand_over(haul)
		village.timers.wake_after(rng.randi_range(1, 4), _wake)


## A command that lays a drop on a spot.
class LayDrop:
	extends VillageCommand
	var kind: int
	var spot: Vector2

	func _init(start_kind: int, start_spot: Vector2) -> void:
		kind = start_kind
		spot = start_spot

	## Lays the drop through the stock. Refused when no cell is under the spot.
	func apply(village: Village) -> bool:
		var stock: VillageStock = village.part(Village.STOCK)
		return stock.drop(kind, spot) != GridDrops.NO_DROP


func test_the_same_seed_and_commands_give_the_same_village() -> void:
	var first := _run(77, false)
	var second := _run(77, false)
	check_eq(first.snapshot(), second.snapshot())
	check_eq(first.state_hash(), second.state_hash())
	var stock: VillageStock = first.part(Village.STOCK)
	check_eq(stock.count(1), 42, "the wood this seed makes")
	check(first.grid.drops.total(1) > 20, "and most of it lies on the ground as rows")


func test_another_seed_or_one_more_command_gives_another_village() -> void:
	var first := _run(77, false)
	var other_seed := _run(78, false)
	var one_more := _run(77, true)
	check(first.snapshot() != other_seed.snapshot(), "another seed")
	check(first.state_hash() != other_seed.state_hash(), "another seed, another number")
	check(first.snapshot() != one_more.snapshot(), "one more drop")
	check(first.state_hash() != one_more.state_hash(), "one more drop, another number")


func test_the_stock_and_the_drops_are_in_the_snapshot_of_the_village() -> void:
	var village := _run(77, false)
	var stock: VillageStock = village.part(Village.STOCK)
	var snapshot := village.snapshot()
	var in_stock: Dictionary = snapshot["parts"][Village.STOCK]
	check_eq(in_stock["banked"], {3: stock.count(3)})
	check_eq(in_stock["storages"]["stored"][PILE], stock.storages.stored_in(PILE))
	check_eq(in_stock["claims"]["carried"].get(1, 0), stock.claims.carried(1))
	var rows: Dictionary = snapshot["grid"]["drops"]
	check_eq(rows["kinds"].size(), village.grid.drops.size())
	check_eq(rows["totals"].get(1, 0), village.grid.drops.total(1))
	# One change to the stock alone changes the snapshot and the number.
	var before := village.state_hash()
	stock.spend(3, 1)
	stock.add(3, 1)
	check_eq(village.state_hash(), before, "spending 1 and adding 1 is the same stock")
	stock.claims.reserve(SITE, 1)
	check(village.state_hash() != before, "a reservation shows in the state")


func test_drops_never_expire_and_more_than_30_can_lie_around() -> void:
	# The jam game let 30 loose drops lie, and took a spare one away after 20 seconds.
	var village := Village.new(5, TICKS_PER_SECOND)
	for cell in GridLayout.block(Vector2i(0, 0), MAP):
		village.grid.add_cell(cell)
	var stock := VillageStock.new(ResourceKind.load_all())
	village.add_part(Village.STOCK, stock)
	var spots: Array[Vector2] = []
	for i in 40:
		spots.append(GridLayout.position_of(Vector2i(i % 20, i / 20)) + Vector2(1.5, -0.5))
		stock.drop(1, spots[i])
	for tick in village.ticks_for(60.0):
		village.tick()
	check_eq(village.now, 1200, "one minute went by")
	check_eq(stock.count(1), 40, "every drop still counts")
	check_eq(village.grid.drops.loose(1), 40, "and still lies loose on the ground")
	check_eq(village.timers.sleeping(), 0, "no timer waits to take one away")
	for i in 40:
		check_eq(village.grid.drops.spot_of(i), spots[i], "drop %d lies where it fell" % i)


func test_a_closed_village_lets_go_of_its_stock() -> void:
	var village := _run(77, false)
	var stock: VillageStock = village.part(Village.STOCK)
	var drops := village.grid.drops
	var claims := stock.claims
	var heard: Array[int] = []
	stock.changed.connect(heard.append)
	check_eq(drops.added.get_connections().size(), 1, "the stock listens to the ground")
	check_eq(drops.removed.get_connections().size(), 2, "and so do its claims")
	check(claims.reserved_by(SITE, 1) > 0, "the site holds reservations before the close")
	check(stock.count(1) > 0, "there is wood before the close")
	village.close()
	check_eq(village.part(Village.STOCK), null, "the village holds no stock")
	check_eq(drops.added.get_connections().size(), 0, "the stock no longer listens for drops")
	check_eq(drops.removed.get_connections().size(), 0, "nor for drops that are taken")
	# Somebody may still hold the claims. They let go of the ground too.
	check_eq(claims.available(1), 0, "closed claims promise nothing")
	check_eq(claims.reserved_by(SITE, 1), 0)
	check_eq(claims.snapshot()["reserved"], {})
	check(not claims.reserve(SITE, 1), "and take no reservation")
	check_eq(stock.changed.get_connections().size(), 0, "nobody listens to the stock")
	check_eq(stock.storages, null)
	check_eq(stock.claims, null)
	check_eq(stock.snapshot(), {})
	check_eq(stock.count(1), 0, "a closed stock counts nothing")
	check_eq(stock.count(3), 0)
	check_eq(stock.add(3, 5), 0, "and takes nothing")
	check_eq(stock.drop(1, Vector2(31.0, 10.0)), GridDrops.NO_DROP)
	check(not stock.add_storage(900, 1, 5, Vector2(31.0, 10.0)), "no storage either")
	drops.add_at(Vector2(31.0, 10.0), 1)
	check_eq(heard.size(), 0, "a drop on the old ground is not told any more")


func test_nothing_keeps_a_closed_village_or_its_stock_alive() -> void:
	var village := _run(77, false)
	var stock: VillageStock = village.part(Village.STOCK)
	var kept: Array[WeakRef] = [
		weakref(village), weakref(stock), weakref(stock.claims), weakref(stock.storages),
		weakref(village.grid), weakref(village.grid.drops),
	]
	village.close()
	stock = null
	village = null
	for index in kept.size():
		check_eq(kept[index].get_ref(), null, "object %d was let go" % index)


## Runs a village for [constant TICKS] ticks. The same commands are sent on
## the same ticks every time. [param one_more] sends one more at the end.
func _run(village_seed: int, one_more: bool) -> Village:
	var village := Village.new(village_seed, TICKS_PER_SECOND)
	for cell in GridLayout.block(Vector2i(0, 0), MAP):
		village.grid.add_cell(cell)
	village.add_part(Village.STOCK, VillageStock.new(ResourceKind.load_all()))
	village.add_part(&"work", Work.new())
	for tick in TICKS:
		if tick % 25 == 0:
			@warning_ignore("integer_division")
			var spot := GridLayout.position_of(Vector2i(tick / 25, 3))
			village.send(LayDrop.new(1 + (tick / 25) % 2, spot))
		village.tick()
	if one_more:
		village.send(LayDrop.new(2, GridLayout.position_of(Vector2i(5, 5))))
	return village
