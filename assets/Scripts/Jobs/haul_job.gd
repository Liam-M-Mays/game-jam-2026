extends Job
class_name HaulJob

var site : Building
var kind : String
var _drop : ResourceDrop
var _pile : Storage
var _carrying := false
var _partner : HaulJob

func _init(target_site : Building, target_kind : String) -> void:
	site = target_site
	kind = target_kind
	var source := Inventory.claim_closest(kind, site.global_position)
	_pile = source as Storage
	_drop = source as ResourceDrop

func place() -> Vector2:
	if _pile != null:
		return _pile.global_position
	return _drop.global_position

func start(_worker : Meeple) -> void:
	if _pile != null:
		_partner = JobSystem.take_partner(self)

## True when `other` can be carried in the same trip: same site, same kind, from the same pile.
func pairs_with(other : HaulJob) -> bool:
	return other.site == site and other.kind == kind and other._pile == _pile

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
	if _pile != null:
		_pile.unclaim()
	else:
		Inventory.set_claimed(_drop, false)
	_pile = null
	_drop = null

func update(worker : Meeple, _delta : float) -> bool:
	if not _carrying:
		var stop : Array[Cell] = []
		if _pile != null:
			stop = _pile.cells
		worker.move_to(place(), stop)
		if not worker.has_arrived():
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

func _pick_up() -> void:
	_carrying = true
	if _pile != null:
		_drop = _pile.take()
		_pile = null
	_drop.hide()

func _deliver() -> void:
	_drop.consume()
	_drop = null
	_carrying = false
	site.deliver(kind)
