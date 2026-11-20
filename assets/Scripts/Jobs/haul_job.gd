extends Job
class_name HaulJob

var site : Building
var kind : String
var _drop : ResourceDrop
var _pile : Storage
var _carrying := false
var _partner : HaulJob
## The meeple whose store trip this haul took over, until it starts. JobSystem gives it the haul.
var carrier : Meeple
## The old building of a moved one, which this haul takes its drop from. Null for other hauls, and
## once the drop is picked up.
var _from : Building
## Where the meeple was last sent for the drop, in the grid's space. It is sent again only when the
## drop or its pile moves.
var _aimed := Vector2.INF
## Asked for past the site's max_hauls, for builders who had nothing to do. Every other waiting haul comes first,
## and a newly placed site cancels it while no builder has taken it.
var extra := false

func _init(target_site : Building, target_kind : String, from : Building = null) -> void:
	site = target_site
	kind = target_kind
	if from != null:
		_from = from
		from.promise(kind)
		return
	var at := site.global_position
	var trip := JobSystem.nearest_store_trip(kind, at)
	var beat := INF if trip == null else at.distance_squared_to(trip.spot())
	var source := Inventory.claim_closest(kind, at, beat)
	if source == null and trip != null:
		carrier = trip.meeple
		_carrying = trip.carrying()
		_drop = trip.hand_over()
		return
	_pile = source as Storage
	_drop = source as ResourceDrop

func place() -> Vector2:
	if _from != null:
		return _from.global_position
	if _pile != null:
		return _pile.global_position
	return _drop.global_position

func start(worker : Meeple) -> void:
	carrier = null
	if _pile != null or _from != null:
		_partner = JobSystem.take_partner(self)
	elif _carrying:
		worker.move_to(site.global_position, site.cells)

## True while its meeple counts as free and any other job may take it: an extra haul not picked up yet.
func gives_way() -> bool:
	return extra and not _carrying

## True when `other` can be carried in the same trip: same site, same kind, from the same pile or old building.
func pairs_with(other : HaulJob) -> bool:
	return other.site == site and other.kind == kind and other._pile == _pile and other._from == _from

## True when this haul claimed a drop in `pile` and has not picked it up yet.
func takes_from(pile : Storage) -> bool:
	return _pile == pile

## Its pile was removed: it takes `drop`, one of the drops that spilled out, instead.
func take_spilled(drop : ResourceDrop) -> void:
	_pile = null
	_drop = drop
	Inventory.set_claimed(drop, true)

## Lets go of the drop this haul claimed. The building calls this when it drops a waiting haul.
func release_drop() -> void:
	if _from != null:
		_from.promise(kind, -1)
	elif _pile != null:
		_pile.unclaim()
	else:
		Inventory.set_claimed(_drop, false)
	_from = null
	_pile = null
	_drop = null

func update(worker : Meeple, _delta : float) -> bool:
	if not _carrying:
		var stand : Building = _from if _from != null else _pile
		var spot := stand.position if stand != null else _drop.position
		if spot != _aimed:
			_aimed = spot
			var stop : Array[Cell] = []
			if stand != null:
				stop = stand.cells
			worker.move_to(place(), stop)
		if not worker.has_arrived() or _waits_for_pile():
			return false
		_pick_up()
		if _partner != null:
			_partner._pick_up()
		worker.carry(kind, 2 if _partner != null else 1)
		worker.move_to(site.global_position, site.cells)
		return false
	if not worker.has_arrived():
		return false
	_deliver()
	if _partner != null:
		_partner._deliver()
		JobSystem.finish(_partner)
		_partner = null
	worker.carry()
	worker.did_work()
	return true

func abort(worker : Meeple) -> void:
	if _partner != null:
		var partner := _partner
		_partner = null
		JobSystem.requeue(partner, worker)
	if _carrying:
		_drop.global_position = worker.global_position
		_drop.show()
		worker.carry()
		_carrying = false

## True while the pile this haul or its partner claimed from holds fewer drops than they take:
## the rest are still being carried there.
func _waits_for_pile() -> bool:
	var need := 0
	var pile : Storage = null
	for haul : HaulJob in [self, _partner]:
		if haul != null and haul._pile != null:
			need += 1
			pile = haul._pile
	return pile != null and pile.held() < need

func _pick_up() -> void:
	_carrying = true
	if _from != null:
		_drop = _from.take_down(kind)
		_from = null
	elif _pile != null:
		_drop = _pile.take()
		_pile = null
	_drop.hide()

func _deliver() -> void:
	_drop.consume()
	_drop = null
	_carrying = false
	site.deliver(kind)
