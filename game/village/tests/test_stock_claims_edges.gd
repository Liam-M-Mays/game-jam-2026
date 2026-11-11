extends GameTest
## Checks the edges of reservations and claims: a reserved or claimed drop
## that is taken off the ground, a site that ends, a drop that is claimed
## already, a tie between a drop and a pile, and what the snapshot holds.

const TICKS_PER_SECOND := 20
const SITE := 601
const OTHER_SITE := 602
const LATE_SITE := 609
const HAUL := 701
const OTHER_HAUL := 702
const THIRD_HAUL := 703
const WOOD_PILE := 503
const STONE_PILE := 504
## Three spots on three cells of one row, 70 art pixels apart.
const LEFT := Vector2(31.0, 10.0)
const MIDDLE := Vector2(101.0, 10.0)
const RIGHT := Vector2(171.0, 10.0)

var _village: Village
var _stock: VillageStock
var _claims: StockClaims
var _drops: GridDrops
var _wood: int
var _stone: int
var _heard: Array[int] = []
var _reserved_when_heard: Array[int] = []
var _available_when_heard: Array[int] = []


## A village with a block of cells and a stock from the data files.
func before_each() -> void:
	_village = Village.new(63, TICKS_PER_SECOND)
	for cell in GridLayout.block(Vector2i(0, 0), Vector2i(40, 20)):
		_village.grid.add_cell(cell)
	_stock = VillageStock.new(ResourceKind.load_all())
	_village.add_part(Village.STOCK, _stock)
	_claims = _stock.claims
	_drops = _village.grid.drops
	_wood = _stock.number_of(&"wood")
	_stone = _stock.number_of(&"stone")


func test_a_reserved_drop_taken_off_the_ground_takes_its_reservation_along() -> void:
	var drop := _stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	_stock.changed.connect(_hear)
	# The drop leaves the world without the stock being asked. In the jam game
	# the reservation stayed, and the hauler crashed on the missing drop.
	check(_drops.remove(drop), "the ground lets it go")
	check_eq(_heard, [_wood] as Array[int], "the stock tells it once")
	# The claims hear the ground before the stock tells it, so a listener of
	# the stock already reads the settled numbers.
	check_eq(_reserved_when_heard, [0] as Array[int], "settled when the listener is told")
	check_eq(_available_when_heard, [0] as Array[int], "and not below zero at that moment")
	check_eq(_claims.reserved_by(SITE, _wood), 0, "the reservation went with the drop")
	check_eq(_claims.available(_wood), 0, "and nothing is below zero")
	check(not _claims.claim_closest(HAUL, SITE, _wood, LEFT), "there is no unit to claim")
	check(not _claims.has(HAUL), "the hauler holds nothing")
	check(not _claims.pick_up(HAUL), "nothing to pick up")
	check(not _claims.hand_over(HAUL), "nothing to hand over")
	check(not _claims.release(HAUL, LEFT), "nothing to release")
	check_eq(_stock.count(_wood), 0)
	_stock.drop(_wood, LEFT)
	check_eq(_claims.available(_wood), 1, "the next drop is free")
	check(_claims.reserve(OTHER_SITE, _wood), "any site can have it")


func test_the_newest_site_loses_its_reservation_first() -> void:
	for spot: Vector2 in [LEFT, MIDDLE, RIGHT]:
		_stock.drop(_wood, spot)
	_stock.drop(_stone, LEFT)
	_claims.reserve(OTHER_SITE, _wood, 2)
	_claims.reserve(SITE, _wood, 1)
	_claims.reserve(OTHER_SITE, _stone, 1)
	# Site 602 has the higher id, so it is the newer one. The old take call
	# takes the drop of one cell.
	check_eq(_drops.take(GridLayout.cell_under(LEFT), _wood, 1), 1)
	check_eq(_claims.reserved_by(OTHER_SITE, _wood), 1, "the newer site lost one")
	check_eq(_claims.reserved_by(SITE, _wood), 1, "the older site keeps its own")
	check_eq(_claims.reserved_by(OTHER_SITE, _stone), 1, "another kind is not touched")
	check_eq(_claims.available(_wood), 0)
	check_eq(_drops.take(GridLayout.cell_under(MIDDLE), _wood, 1), 1)
	check_eq(_claims.reserved_by(OTHER_SITE, _wood), 0)
	check_eq(_claims.reserved_by(SITE, _wood), 1)
	check_eq(_drops.take(GridLayout.cell_under(RIGHT), _wood, 1), 1)
	check_eq(_claims.reserved_by(SITE, _wood), 0, "the last drop took the last reservation")
	check_eq(_claims.available(_wood), 0)


func test_a_drop_taken_off_the_ground_only_costs_a_reservation_when_none_is_spare() -> void:
	_fill_pile(WOOD_PILE, _wood, MIDDLE, 1)
	var loose := _stock.drop(_wood, LEFT)
	var claimed := _stock.drop(_wood, RIGHT)
	_claims.reserve(SITE, _wood, 2)
	check(_claims.claim_closest(HAUL, SITE, _wood, RIGHT), "the hauler claims the right drop")
	check_eq(_claims.drop_of(HAUL), claimed)
	check_eq(_claims.available(_wood), 1, "one unit is spare")
	# A picked-up drop leaves the ground too. That costs no reservation.
	_claims.pick_up(HAUL)
	check_eq(_claims.reserved_by(SITE, _wood), 1)
	check_eq(_claims.available(_wood), 1)
	_drops.remove(loose)
	check_eq(_claims.reserved_by(SITE, _wood), 1, "the unit in the pile still covers it")
	check_eq(_claims.available(_wood), 0)
	check(_claims.claim_closest(OTHER_HAUL, SITE, _wood, LEFT), "and it can be claimed")
	check_eq(_claims.storage_of(OTHER_HAUL), WOOD_PILE)


func test_a_claimed_unit_is_not_taken_back_so_an_older_site_can_lose_first() -> void:
	var near := _stock.drop(_wood, LEFT)
	var far := _stock.drop(_wood, RIGHT)
	_claims.reserve(SITE, _wood)
	_claims.reserve(LATE_SITE, _wood)
	check(_claims.claim_closest(HAUL, LATE_SITE, _wood, LEFT), "the newer site has a hauler")
	check_eq(_claims.drop_of(HAUL), near)
	# Only the older site still holds a reservation. The claim of the newer
	# site is a unit in particular, and that is not taken back.
	check(_drops.remove(far), "the other drop leaves the ground")
	check_eq(_claims.reserved_by(SITE, _wood), 0, "the older site lost its reservation")
	check_eq(_claims.available(_wood), 0)
	check(_claims.has(HAUL), "the haul of the newer site holds its drop")
	check(_claims.pick_up(HAUL), "and still picks it up")
	check(_claims.hand_over(HAUL), "and delivers it")
	check_eq(_stock.count(_wood), 0)


func test_a_claimed_drop_that_was_taken_off_the_ground_cannot_be_picked_up() -> void:
	var drop := _stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	# The ground lets a claimed drop go for the id that claimed it.
	check(_drops.remove(drop, HAUL), "the drop is taken without the stock")
	check(_claims.has(HAUL), "the claim is found out at the next step")
	check(not _claims.pick_up(HAUL), "there is nothing to pick up")
	check(not _claims.has(HAUL), "the claim ended")
	check_eq(_claims.carried(_wood), 0, "nothing is carried")
	check(not _claims.hand_over(HAUL), "so nothing can be delivered")
	check_eq(_stock.count(_wood), 0)
	check_eq(_claims.reserved_by(SITE, _wood), 0, "the unit is gone, no reservation comes back")
	check_eq(_claims.available(_wood), 0)


func test_a_haul_does_not_pick_up_another_drop_that_got_its_row() -> void:
	var drop := _stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_drops.remove(drop, HAUL)
	var stone := _stock.drop(_stone, MIDDLE)
	check_eq(stone, drop, "the stone got the row of the wood")
	check(not _claims.pick_up(HAUL), "the haul does not pick up the stone")
	check(_drops.has(stone), "the stone still lies there")
	check_eq(_drops.loose(_stone), 1)
	check_eq(_stock.count(_stone), 1)
	check_eq(_claims.carried(_wood), 0, "no wood is carried")
	check_eq(_stock.count(_wood), 0)
	check(not _claims.has(HAUL), "the claim ended")


func test_a_haul_does_not_pick_up_a_drop_of_another_kind_claimed_with_its_id() -> void:
	var drop := _stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_drops.remove(drop, HAUL)
	# The row is used again, and a raw ground call claims the stone with the
	# same id. The haul was for wood.
	var stone := _stock.drop(_stone, MIDDLE)
	check_eq(stone, drop, "the stone got the row of the wood")
	check(_drops.claim(stone, HAUL), "a claim the stock does not know")
	check(not _claims.pick_up(HAUL), "the haul does not pick up the stone")
	check(_drops.has(stone), "the stone still lies there")
	check_eq(_claims.carried(_wood), 0, "no wood is carried")
	check(not _claims.has(HAUL), "the claim ended")


func test_releasing_a_haul_whose_drop_was_taken_restores_nothing() -> void:
	_stock.add_storage(WOOD_PILE, _wood, 2, RIGHT)
	var first := _stock.drop(_wood, LEFT)
	var second := _stock.drop(_wood, MIDDLE)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_claims.claim_for_storage(OTHER_HAUL, WOOD_PILE, second)
	check_eq(_stock.storages.room_in(WOOD_PILE), 1, "a place is kept for the trip")
	_drops.remove(first, HAUL)
	_drops.remove(second, OTHER_HAUL)
	# The row of the first drop is used again, by a stone another trip claims.
	var stone := _stock.drop(_stone, LEFT)
	_stock.add_storage(STONE_PILE, _stone, 2, RIGHT)
	_claims.claim_for_storage(THIRD_HAUL, STONE_PILE, stone)
	check(not _claims.release(HAUL, LEFT), "the haul has nothing to give back")
	check(not _claims.has(HAUL), "its claim ended")
	check_eq(_claims.reserved_by(SITE, _wood), 0, "no reservation for a unit that is gone")
	check_eq(_claims.available(_wood), 0, "and nothing below zero")
	check_eq(_drops.claimer_of(stone), THIRD_HAUL, "the stone keeps its own claim")
	check(not _claims.release(OTHER_HAUL, LEFT), "the trip has nothing to give back")
	check_eq(_stock.storages.room_in(WOOD_PILE), 2, "its place in the pile is free again")
	check_eq(_drops.total(_wood), 0, "no wood was laid")


func test_a_claimed_drop_cannot_start_a_trip_to_a_pile_that_has_room() -> void:
	_stock.add_storage(WOOD_PILE, _wood, 4, RIGHT)
	var first := _stock.drop(_wood, LEFT)
	var second := _stock.drop(_wood, MIDDLE)
	_stock.drop(_wood, RIGHT)
	check(_claims.claim_for_storage(HAUL, WOOD_PILE, first), "the first trip")
	check_eq(_stock.storages.room_in(WOOD_PILE), 3, "the pile still has room")
	check(not _claims.claim_for_storage(OTHER_HAUL, WOOD_PILE, first), "a trip has that drop")
	_claims.reserve(SITE, _wood)
	check(_claims.claim_closest(THIRD_HAUL, SITE, _wood, MIDDLE), "a site haul claims the next")
	check_eq(_claims.drop_of(THIRD_HAUL), second)
	check(not _claims.claim_for_storage(OTHER_HAUL, WOOD_PILE, second), "a site haul has that drop")
	check(not _claims.has(OTHER_HAUL), "the refused hauler holds nothing")
	check_eq(_stock.storages.room_in(WOOD_PILE), 3, "and no place was taken for it")
	check_eq(_drops.claimer_of(first), HAUL)
	check_eq(_drops.claimer_of(second), THIRD_HAUL)
	_claims.pick_up(HAUL)
	_claims.hand_over(HAUL)
	check_eq(_stock.storages.stored_in(WOOD_PILE), 1)
	check_eq(_stock.count(_wood), 3, "three drops are still three units")


func test_a_drop_and_a_pile_at_the_same_distance_the_drop_is_claimed() -> void:
	_fill_pile(WOOD_PILE, _wood, LEFT, 1)
	var drop := _stock.drop(_wood, RIGHT)
	_claims.reserve(SITE, _wood, 2)
	# The hauler stands 70 art pixels from the pile and 70 from the drop.
	check(_claims.claim_closest(HAUL, SITE, _wood, MIDDLE), "a claim")
	check_eq(_claims.drop_of(HAUL), drop, "the drop on the ground goes first")
	check_eq(_claims.storage_of(HAUL), StockStorages.NO_STORAGE)
	check_eq(_stock.storages.free_in(WOOD_PILE), 1, "the pile was not touched")


func test_a_site_that_ends_releases_its_hauls_first_and_then_unreserves() -> void:
	_stock.drop(_wood, LEFT)
	_stock.drop(_wood, MIDDLE)
	_claims.reserve(SITE, _wood, 2)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	check(_claims.release(HAUL, LEFT), "first the haul")
	check_eq(_claims.unreserve(SITE, _wood, 99), 2, "then everything is given back")
	check_eq(_claims.reserved_by(SITE, _wood), 0)
	check_eq(_claims.available(_wood), 2)
	check(_claims.reserve(OTHER_SITE, _wood, 2), "another site can have both")


func test_unreserving_before_the_haul_is_released_leaves_one_reservation() -> void:
	_stock.drop(_wood, LEFT)
	_stock.drop(_wood, MIDDLE)
	_claims.reserve(SITE, _wood, 2)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	# The wrong order. The claimed unit is not given back by unreserve, and the
	# release puts its reservation back, as the jam game did.
	check_eq(_claims.unreserve(SITE, _wood, 99), 1, "only the unit no hauler has claimed")
	check_eq(_claims.reserved_by(SITE, _wood), 0)
	check(_claims.release(HAUL, LEFT), "the haul is released afterwards")
	check_eq(_claims.reserved_by(SITE, _wood), 1, "the site has one reservation again")
	check_eq(_claims.available(_wood), 1)
	check(not _claims.reserve(OTHER_SITE, _wood, 2), "so another site cannot have both")
	check_eq(_claims.unreserve(SITE, _wood, 99), 1, "a second unreserve clears it")
	check(_claims.reserve(OTHER_SITE, _wood, 2), "now it can")


func test_the_snapshot_holds_every_promise() -> void:
	_fill_pile(WOOD_PILE, _wood, RIGHT, 1)
	var drop := _stock.drop(_wood, LEFT)
	_stock.drop(_stone, MIDDLE)
	_claims.reserve(SITE, _wood, 2)
	_claims.reserve(OTHER_SITE, _stone)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	var shot := _claims.snapshot()
	check_eq(shot.keys(), ["reserved", "claims", "spots", "carried"])
	check_eq(shot.get("reserved"), {SITE: {_wood: 1}, OTHER_SITE: {_stone: 1}})
	# The claim: kind, site, carried, drop, pile it comes from, pile it goes to.
	check_eq(shot.get("claims"), {HAUL: PackedInt32Array([_wood, SITE, 0, drop, 0, 0])})
	check_eq(shot.get("spots"), {HAUL: LEFT})
	check_eq(shot.get("carried"), {_wood: 0})
	_claims.pick_up(HAUL)
	shot = _claims.snapshot()
	check_eq(shot.get("claims"), {HAUL: PackedInt32Array([_wood, SITE, 1, GridDrops.NO_DROP, 0, 0])})
	check_eq(shot.get("carried"), {_wood: 1})
	# A snapshot is a copy: changing it does not change the claims.
	shot["claims"][HAUL][0] = 99
	shot["reserved"][SITE][_wood] = 99
	check_eq(_claims.reserved_by(SITE, _wood), 1)
	check(_claims.is_carried(HAUL), "the claim is as it was")


## Adds a pile and puts [param units] into it, each by a trip from the ground.
func _fill_pile(pile: int, kind: int, spot: Vector2, units: int) -> void:
	_stock.add_storage(pile, kind, units + 2, spot)
	for i in units:
		var drop := _stock.drop(kind, spot)
		_claims.claim_for_storage(900 + i, pile, drop)
		_claims.pick_up(900 + i)
		_claims.hand_over(900 + i)


func _hear(kind: int) -> void:
	_heard.append(kind)
	_reserved_when_heard.append(_claims.reserved_by(SITE, kind))
	_available_when_heard.append(_claims.available(kind))
