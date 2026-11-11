extends GameTest
## Checks reservations and claims: what can be promised to a building site,
## that two haulers never go for the same item, and what a haul does to the
## stock from the claim to the delivery.

const TICKS_PER_SECOND := 20
const SITE := 601
const OTHER_SITE := 602
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


func test_what_can_be_promised_is_what_is_unclaimed_minus_what_is_reserved() -> void:
	for spot: Vector2 in [LEFT, MIDDLE, RIGHT]:
		_stock.drop(_wood, spot)
	_stock.drop(_stone, LEFT)
	check_eq(_claims.available(_wood), 3)
	check(_claims.reserve(SITE, _wood, 2), "two of three can be reserved")
	check_eq(_claims.available(_wood), 1)
	check_eq(_claims.reserved_by(SITE, _wood), 2)
	check_eq(_claims.available(_stone), 1, "another kind is not touched")
	check_eq(_stock.count(_wood), 3, "a reserved unit still counts")


func test_a_site_cannot_reserve_more_than_is_available() -> void:
	_stock.drop(_wood, LEFT)
	_stock.drop(_wood, MIDDLE)
	check(not _claims.reserve(SITE, _wood, 3), "three of two is refused whole")
	check_eq(_claims.reserved_by(SITE, _wood), 0)
	check(_claims.reserve(SITE, _wood, 2), "two of two")
	check(not _claims.reserve(OTHER_SITE, _wood), "nothing is left for the other site")
	check(not _claims.reserve(0, _wood), "id 0 means nobody")
	check(not _claims.reserve(SITE, _wood, 0), "an amount of 0")
	check_eq(_claims.available(_wood), 0)


func test_dropping_a_haul_gives_the_reservation_back() -> void:
	_stock.drop(_wood, LEFT)
	_stock.drop(_wood, MIDDLE)
	_claims.reserve(SITE, _wood, 2)
	check_eq(_claims.unreserve(SITE, _wood), 1)
	check_eq(_claims.available(_wood), 1)
	check_eq(_claims.unreserve(OTHER_SITE, _wood), 0, "a site only gives back its own")
	check_eq(_claims.unreserve(SITE, _wood, 5), 1, "and never more than it has")
	check_eq(_claims.available(_wood), 2)
	check_eq(_claims.reserved_by(SITE, _wood), 0)


func test_a_hauler_claims_the_closest_unit_and_that_uses_one_reservation() -> void:
	var left := _stock.drop(_wood, LEFT)
	var right := _stock.drop(_wood, RIGHT)
	_claims.reserve(SITE, _wood, 2)
	check(_claims.claim_closest(HAUL, SITE, _wood, RIGHT + Vector2(9.0, 0.0)), "a claim")
	check_eq(_claims.drop_of(HAUL), right, "the drop next to the hauler")
	check_eq(_claims.spot_of(HAUL), RIGHT)
	check_eq(_drops.claimer_of(right), HAUL)
	check_eq(_claims.reserved_by(SITE, _wood), 1, "one reservation became the claim")
	check_eq(_claims.available(_wood), 0, "nothing more can be promised")
	check_eq(_stock.count(_wood), 2)
	check_eq(_drops.claimer_of(left), GridDrops.NOBODY)


func test_two_haulers_never_get_the_same_unit() -> void:
	var left := _stock.drop(_wood, LEFT)
	var middle := _stock.drop(_wood, MIDDLE)
	_claims.reserve(SITE, _wood, 2)
	# Both haulers stand on the same spot, next to the left drop.
	check(_claims.claim_closest(HAUL, SITE, _wood, LEFT), "the first hauler")
	check(_claims.claim_closest(OTHER_HAUL, SITE, _wood, LEFT), "the second hauler")
	check_eq(_claims.drop_of(HAUL), left)
	check_eq(_claims.drop_of(OTHER_HAUL), middle, "the second one gets the next drop")
	check(not _claims.claim_closest(THIRD_HAUL, SITE, _wood, LEFT), "no reservation is left")
	check(not _claims.has(THIRD_HAUL), "the third hauler holds nothing")


func test_a_claim_needs_a_reservation_and_a_hauler_holds_one_claim() -> void:
	_stock.drop(_wood, LEFT)
	_stock.drop(_wood, MIDDLE)
	check(not _claims.claim_closest(HAUL, SITE, _wood, LEFT), "the site reserved nothing")
	_claims.reserve(SITE, _wood, 2)
	check(not _claims.claim_closest(HAUL, OTHER_SITE, _wood, LEFT), "not on another site")
	check(not _claims.claim_closest(0, SITE, _wood, LEFT), "id 0 means nobody")
	check(_claims.claim_closest(HAUL, SITE, _wood, LEFT), "with a reservation")
	check(not _claims.claim_closest(HAUL, SITE, _wood, LEFT), "one claim for each hauler")
	check_eq(_claims.reserved_by(SITE, _wood), 1)


func test_a_hauler_with_no_unit_left_is_refused_and_nothing_breaks() -> void:
	var drop := _stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	# The drop leaves the world behind the back of the stock. Now the
	# reservation and the drops disagree, which crashed the jam game.
	_drops.remove(drop)
	check(not _claims.claim_closest(HAUL, SITE, _wood, LEFT), "there is no unit to claim")
	check(not _claims.has(HAUL), "the hauler holds nothing")
	check_eq(_claims.reserved_by(SITE, _wood), 1, "the reservation was not used up")
	check(not _claims.pick_up(HAUL), "nothing to pick up")
	check(not _claims.hand_over(HAUL), "nothing to hand over")
	check(not _claims.release(HAUL, LEFT), "nothing to release")
	check_eq(_stock.count(_wood), 0)


func test_the_closest_unit_can_sit_in_a_pile() -> void:
	_fill_pile(WOOD_PILE, _wood, MIDDLE, 2)
	var far_drop := _stock.drop(_wood, RIGHT)
	_claims.reserve(SITE, _wood, 3)
	check(_claims.claim_closest(HAUL, SITE, _wood, LEFT), "the pile is closer than the drop")
	check_eq(_claims.storage_of(HAUL), WOOD_PILE)
	check_eq(_claims.drop_of(HAUL), GridDrops.NO_DROP)
	check_eq(_claims.spot_of(HAUL), MIDDLE)
	check_eq(_stock.storages.free_in(WOOD_PILE), 1, "one unit of the pile is promised")
	check_eq(_stock.storages.stored_in(WOOD_PILE), 2, "it sits there until it is picked up")
	check(_claims.claim_closest(OTHER_HAUL, SITE, _wood, RIGHT), "the drop is closer here")
	check_eq(_claims.drop_of(OTHER_HAUL), far_drop)
	check(_claims.claim_closest(THIRD_HAUL, SITE, _wood, RIGHT), "the pile is all that is left")
	check_eq(_claims.storage_of(THIRD_HAUL), WOOD_PILE)
	check_eq(_stock.storages.free_in(WOOD_PILE), 0)
	check_eq(_claims.available(_wood), 0)


func test_a_picked_up_drop_leaves_its_cell_and_still_counts() -> void:
	var drop := _stock.drop(_wood, LEFT)
	var cell := _drops.cell_of(drop)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	check(_drops.has_any(cell), "the claimed drop lies there until it is picked up")
	check(_claims.pick_up(HAUL), "the hauler picks it up")
	check(_claims.is_carried(HAUL), "it is carried")
	check(not _drops.has_any(cell), "nothing is left on the cell")
	check_eq(_drops.total(_wood), 0)
	check_eq(_claims.carried(_wood), 1)
	check_eq(_stock.count(_wood), 1, "a carried unit still counts")
	check(not _claims.pick_up(HAUL), "it cannot be picked up twice")


func test_a_unit_picked_up_from_a_pile_leaves_the_pile() -> void:
	_fill_pile(WOOD_PILE, _wood, MIDDLE, 2)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	check(_claims.pick_up(HAUL), "the hauler takes it out of the pile")
	check_eq(_stock.storages.stored_in(WOOD_PILE), 1)
	check_eq(_stock.storages.free_in(WOOD_PILE), 1)
	check_eq(_claims.storage_of(HAUL), StockStorages.NO_STORAGE)
	check_eq(_stock.count(_wood), 2, "pile 1, carried 1")


func test_a_delivered_unit_leaves_the_stock() -> void:
	_stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	check(not _claims.hand_over(HAUL), "it has to be picked up first")
	_claims.pick_up(HAUL)
	check(_claims.hand_over(HAUL), "the site takes it")
	check_eq(_stock.count(_wood), 0)
	check_eq(_claims.carried(_wood), 0)
	check(not _claims.has(HAUL), "the claim is over")
	check_eq(_claims.reserved_by(SITE, _wood), 0)
	check_eq(_claims.available(_wood), 0)


func test_an_aborted_haul_unclaims_its_drop_and_restores_the_reservation() -> void:
	var drop := _stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	check(_claims.release(HAUL, MIDDLE), "the haul is aborted before the pick up")
	check_eq(_drops.claimer_of(drop), GridDrops.NOBODY, "the drop is unclaimed again")
	check_eq(_drops.spot_of(drop), LEFT, "it did not move")
	check_eq(_claims.reserved_by(SITE, _wood), 1, "the reservation is back")
	check_eq(_claims.available(_wood), 0, "so it still cannot be promised to another site")
	check(not _claims.has(HAUL), "the hauler holds nothing")
	check(_claims.claim_closest(OTHER_HAUL, SITE, _wood, LEFT), "another hauler can take it")
	check_eq(_claims.drop_of(OTHER_HAUL), drop)


func test_a_haul_aborted_while_carrying_puts_the_unit_down_where_it_stands() -> void:
	_fill_pile(WOOD_PILE, _wood, LEFT, 1)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_claims.pick_up(HAUL)
	check(_claims.release(HAUL, RIGHT), "the hauler is interrupted on the way")
	check_eq(_drops.total(_wood), 1, "the unit lies on the ground, though it came from a pile")
	var put_down := _drops.closest(_wood, RIGHT)
	check_eq(_drops.spot_of(put_down), RIGHT)
	check_eq(_stock.storages.stored_in(WOOD_PILE), 0)
	check_eq(_claims.carried(_wood), 0)
	check_eq(_stock.count(_wood), 1)
	check_eq(_claims.reserved_by(SITE, _wood), 1, "the reservation is back")
	check(_claims.claim_closest(OTHER_HAUL, SITE, _wood, LEFT), "it can be claimed again")
	check_eq(_claims.drop_of(OTHER_HAUL), put_down)


func test_a_unit_put_down_where_no_cell_is_lands_where_it_was_picked_up() -> void:
	_stock.drop(_wood, LEFT)
	_claims.reserve(SITE, _wood)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_claims.pick_up(HAUL)
	check(_claims.release(HAUL, Vector2(-900.0, -900.0)), "released off the map")
	check_eq(_drops.total(_wood), 1, "the unit is not lost")
	check_eq(_drops.spot_of(_drops.closest(_wood, LEFT)), LEFT)


func test_a_drop_on_its_way_to_a_pile_is_locked_until_it_lands() -> void:
	_stock.add_storage(WOOD_PILE, _wood, 4, RIGHT)
	var drop := _stock.drop(_wood, LEFT)
	check(_claims.claim_for_storage(HAUL, WOOD_PILE, drop), "the trip is chosen")
	check_eq(_stock.count(_wood), 1, "it still counts in the stock")
	check_eq(_claims.available(_wood), 0, "but it cannot be promised to a site")
	check(not _claims.reserve(SITE, _wood), "so a site cannot reserve it")
	_claims.pick_up(HAUL)
	check_eq(_stock.count(_wood), 1)
	check_eq(_claims.available(_wood), 0, "still locked during the walk")
	_stock.changed.connect(_hear)
	check(_claims.hand_over(HAUL), "it lands in the pile")
	check_eq(_heard, [_wood] as Array[int], "landing is told, so sites can ask again")
	check_eq(_stock.storages.stored_in(WOOD_PILE), 1)
	check_eq(_drops.total(_wood), 0)
	check_eq(_stock.count(_wood), 1)
	check_eq(_claims.available(_wood), 1, "now a site can have it")
	check(_claims.reserve(SITE, _wood), "and reserve it")


func test_a_pile_only_takes_what_fits_and_what_is_not_reserved() -> void:
	_stock.add_storage(WOOD_PILE, _wood, 1, RIGHT)
	_stock.add_storage(STONE_PILE, _stone, 4, RIGHT)
	var first := _stock.drop(_wood, LEFT)
	var second := _stock.drop(_wood, MIDDLE)
	var stone := _stock.drop(_stone, LEFT)
	check(not _claims.claim_for_storage(HAUL, STONE_PILE, first), "wood does not go on stone")
	check(not _claims.claim_for_storage(HAUL, 999, first), "there is no such pile")
	check(_claims.claim_for_storage(HAUL, WOOD_PILE, first), "the pile has room for one")
	check_eq(_stock.storages.room_in(WOOD_PILE), 0, "the unit on its way takes the place")
	check(not _claims.claim_for_storage(OTHER_HAUL, WOOD_PILE, second), "the pile is full")
	check(not _claims.claim_for_storage(OTHER_HAUL, WOOD_PILE, first), "and the drop is taken")
	_claims.reserve(SITE, _stone)
	check(not _claims.claim_for_storage(OTHER_HAUL, STONE_PILE, stone), "a reserved unit is left")
	check_eq(_drops.claimer_of(stone), GridDrops.NOBODY)
	check_eq(_drops.claimer_of(second), GridDrops.NOBODY)


func test_an_aborted_trip_to_a_pile_frees_the_drop_and_the_place() -> void:
	_stock.add_storage(WOOD_PILE, _wood, 1, RIGHT)
	var drop := _stock.drop(_wood, LEFT)
	_claims.claim_for_storage(HAUL, WOOD_PILE, drop)
	check(_claims.release(HAUL, MIDDLE), "aborted before the pick up")
	check_eq(_drops.claimer_of(drop), GridDrops.NOBODY)
	check_eq(_stock.storages.room_in(WOOD_PILE), 1)
	check_eq(_claims.available(_wood), 1)
	_claims.claim_for_storage(HAUL, WOOD_PILE, drop)
	_claims.pick_up(HAUL)
	check(_claims.release(HAUL, MIDDLE), "aborted while carrying")
	check_eq(_drops.spot_of(_drops.closest(_wood, MIDDLE)), MIDDLE)
	check_eq(_stock.storages.room_in(WOOD_PILE), 1)
	check_eq(_stock.storages.stored_in(WOOD_PILE), 0)
	check_eq(_stock.count(_wood), 1)
	check_eq(_claims.available(_wood), 1)


func test_every_step_of_a_haul_is_told_once() -> void:
	_stock.add_storage(WOOD_PILE, _wood, 4, RIGHT)
	_stock.drop(_wood, LEFT)
	_stock.drop(_wood, MIDDLE)
	_stock.changed.connect(_hear)
	_claims.reserve(SITE, _wood, 2)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_claims.pick_up(HAUL)
	_claims.hand_over(HAUL)
	check_eq(_heard.size(), 4, "reserve, claim, pick up, hand over")
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_claims.release(HAUL, LEFT)
	_claims.claim_closest(HAUL, SITE, _wood, LEFT)
	_claims.pick_up(HAUL)
	_claims.release(HAUL, LEFT)
	check_eq(_heard.size(), 9, "claim, release, claim, pick up, put down")
	_claims.unreserve(SITE, _wood)
	_claims.claim_for_storage(HAUL, WOOD_PILE, _drops.closest(_wood, LEFT))
	check_eq(_heard.size(), 11, "unreserve, a trip to the pile")
	_claims.unreserve(SITE, _wood)
	_claims.pick_up(OTHER_HAUL)
	_claims.release(OTHER_HAUL, LEFT)
	_claims.reserve(SITE, _wood, 9)
	check_eq(_heard.size(), 11, "a refused call is not told")
	check_eq(_heard.count(_wood), 11, "every one named wood")


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
