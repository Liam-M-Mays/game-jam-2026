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
## True once its drop is out of its pile, the ground or an old building. It then only goes to its site: it is
## never given back, so the drop is never let loose and carried to a pile.
var _taken := false

## `claim` false makes an empty haul that claims nothing, for a save to fill in (see resume_saved).
func _init(target_site : Building, target_kind : String, from : Building = null, claim := true) -> void:
	site = target_site
	kind = target_kind
	if not claim:
		return
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
		_taken = _carrying
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
	return extra and not _taken

func carried() -> Array[ResourceDrop]:
	var drops : Array[ResourceDrop] = []
	for haul : HaulJob in [self, _partner]:
		if haul != null and haul._carrying and haul._drop != null:
			drops.append(haul._drop)
	return drops

## True once its drop is out of where it was claimed.
func picked_up() -> bool:
	return _taken

## What a save keeps of this haul, with buildings and loose drops as indexes. Empty when it cannot be put back.
func saved(index_of : Dictionary, drop_index : Dictionary) -> Dictionary:
	if not index_of.has(site):
		return {}
	var entry := {"type": "haul", "site": index_of[site], "kind": kind, "carrying": _carrying, "extra": extra, "count": 2 if _partner != null else 1}
	if _carrying:
		return entry
	if _from != null and index_of.has(_from):
		entry["from"] = index_of[_from]
	elif _pile != null and index_of.has(_pile):
		entry["pile"] = index_of[_pile]
	elif _drop != null and drop_index.has(_drop):
		entry["drop"] = drop_index[_drop]
		entry["count"] = 1
	else:
		return {}
	return entry

## Puts back a haul from a save on `worker`: carrying `count` drops of `kind` to `site`, or walking to take them
## from `old` (a building coming down for a move), `pile`, or the loose `drop`. False when that source is gone.
static func resume_saved(worker : Meeple, site : Building, kind : String, count : int, carrying : bool, extra_haul : bool, old : Building, pile : Storage, drop : ResourceDrop) -> bool:
	var jobs : Array[HaulJob] = []
	for i in range(count):
		var job := HaulJob.new(site, kind, null, false)
		job.extra = extra_haul
		if carrying:
			job._drop = worker.grid.add_drop(ResourceDrop.scene_of(kind), worker.position)
			Inventory.set_claimed(job._drop, true)
			job._drop.hide()
			job._carrying = true
			job._taken = true
		elif old != null and old.left_to_claim(kind) > 0:
			job._from = old
			old.promise(kind)
		elif pile != null and pile.spare() > 0:
			job._pile = pile
			pile.claim()
		elif drop != null and i == 0:
			job._drop = drop
			Inventory.set_claimed(drop, true)
		else:
			break
		jobs.append(job)
	if jobs.is_empty():
		return false
	site.add_incoming(kind, jobs.size())
	if jobs.size() > 1:
		jobs[0]._partner = jobs[1]
	JobSystem.resume(jobs[0], worker, jobs.slice(1))
	return true

## Starts a haul put back from a save, as it was: carrying straight to its site, or walking to its drop.
func resume(worker : Meeple) -> void:
	if _carrying:
		worker.carry(kind, 2 if _partner != null else 1)
		_aimed = site.position
		worker.move_to(site.global_position, site.cells)

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
		_aimed = site.position
		worker.move_to(site.global_position, site.cells)
		return false
	# Its site may be a new one: a moved farm or silo's copy took this haul over on the way.
	if site.position != _aimed:
		_aimed = site.position
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
	_taken = true
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
