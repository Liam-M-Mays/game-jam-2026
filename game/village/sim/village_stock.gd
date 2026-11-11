class_name VillageStock
extends VillagePart
## The stock of one village: what it has of each resource kind.
##
## Each village has its own stock. Hang it on the village like this:
## [codeblock]
## village.add_part(Village.STOCK, VillageStock.new(ResourceKind.load_all()))
## [/codeblock]
## The kinds come from data files: see [ResourceKind]. A kind is named by its
## number here. [method number_of] turns a name such as [code]wood[/code]
## into the number.
##
## Where the units of a kind are:
## - A banked kind, such as food, is one number with a cap.
## - An item kind, such as wood, is never a number in the bank. Each unit
##   lies on the ground ([member VillageGrid.drops]), sits in a storage
##   ([member storages]) or is carried ([member claims]).
## [method count] adds all of that up.
##
## The stock tells every change with [signal changed]. A part keeps no
## pointer to its village, so the stock only holds on to the ground of the
## grid, and lets go of it in [method close].

## A number of [param kind] changed: how much there is, how much is free, or
## its cap. A listener runs at once, on every change.
signal changed(kind: int)

## The number that means no kind.
const NO_KIND := 0

## The storage buildings of the village, as counts. Null once the stock is closed.
var storages: StockStorages:
	get:
		return _storages
## The reservations and claims of the village. Null once the stock is closed.
var claims: StockClaims:
	get:
		return _claims

var _storages: StockStorages = null
var _claims: StockClaims = null
var _drops: GridDrops = null
var _kinds: Dictionary[int, ResourceKind] = {}
var _numbers: Dictionary[StringName, int] = {}
var _banked: Dictionary[int, int] = {}


## Makes a stock that knows [param kinds]. A kind with a number or a name
## that is taken, or a number outside 1 to 255, is left out with an error.
func _init(kinds: Array[ResourceKind]) -> void:
	for data in kinds:
		var in_range := (
			data != null
			and data.number >= ResourceKind.MIN_NUMBER
			and data.number <= ResourceKind.MAX_NUMBER
		)
		if not in_range or _kinds.has(data.number) or _numbers.has(data.id):
			var its_name := "null" if data == null else "'%s' (number %d)" % [data.id, data.number]
			push_error("VillageStock: the resource kind %s cannot be used" % its_name)
			continue
		_kinds[data.number] = data
		_numbers[data.id] = data.number


## Runs when the stock is hung on [param village]. Every banked kind gets its
## starting amount, and nothing is reserved.
func start(village: Village) -> void:
	if _drops != null:
		push_error("VillageStock: this stock already hangs on a village")
		return
	_drops = village.grid.drops
	_storages = StockStorages.new()
	_claims = StockClaims.new(_drops, _storages)
	for number: int in _kinds:
		if not _kinds[number].is_item:
			_banked[number] = _kinds[number].start_amount
	_drops.added.connect(_on_ground_changed)
	_drops.removed.connect(_on_ground_changed)
	_claims.changed.connect(_on_claims_changed)


## Lets go of the ground, the storages, the promises and everyone who
## listens. A closed stock counts nothing and takes nothing.
func close() -> void:
	if _drops == null:
		return
	_drops.added.disconnect(_on_ground_changed)
	_drops.removed.disconnect(_on_ground_changed)
	_claims.changed.disconnect(_on_claims_changed)
	_claims.close()
	_storages.clear()
	_claims = null
	_storages = null
	_drops = null
	_banked.clear()
	for connection in changed.get_connections():
		changed.disconnect(connection["callable"])


## The stock as plain data. The drops on the ground are in the snapshot of
## the grid.
func snapshot() -> Dictionary:
	if _drops == null:
		return {}
	return {
		"banked": _banked.duplicate(),
		"storages": _storages.snapshot(),
		"claims": _claims.snapshot(),
	}


## The number of the kind named [param id], such as [code]wood[/code].
## [constant NO_KIND] when no kind has that name.
func number_of(id: StringName) -> int:
	return _numbers.get(id, NO_KIND)


## The data file of [param kind], or null when no kind has that number.
func data_of(kind: int) -> ResourceKind:
	return _kinds.get(kind)


## The numbers of all kinds, lowest first.
func kind_numbers() -> PackedInt32Array:
	var numbers := PackedInt32Array(_kinds.keys())
	numbers.sort()
	return numbers


## How much of [param kind] the village has: the banked amount, plus every
## unit that lies on the ground, sits in a storage or is carried. A drop
## counts from the moment it appears.
func count(kind: int) -> int:
	if _drops == null:
		return 0
	var units := _drops.total(kind) + _storages.stored_total(kind) + _claims.carried(kind)
	return _banked.get(kind, 0) + units


## Adds [param amount] to the banked [param kind]. What does not fit under
## the cap is lost. Returns how much was really added. An item kind is never
## banked, so it gets 0.
func add(kind: int, amount: int) -> int:
	var data := data_of(kind)
	if _drops == null or data == null or data.is_item or amount <= 0:
		return 0
	var have: int = _banked[kind]
	var added := mini(amount, maxi(cap(kind) - have, 0))
	if added <= 0:
		return 0
	_banked[kind] = have + added
	changed.emit(kind)
	return added


## Takes [param amount] from the banked [param kind]. Spending more than
## there is empties it to zero: the stock never goes below zero. Returns how
## much was really taken.
func spend(kind: int, amount: int) -> int:
	var spent := mini(amount, _banked.get(kind, 0))
	if spent <= 0:
		return 0
	_banked[kind] -= spent
	changed.emit(kind)
	return spent


## The cap of [param kind]: its base cap plus the capacity of every storage
## of that kind. For food that is the food cap. For an item kind it is the
## room in the piles, and the ground has no cap.
func cap(kind: int) -> int:
	var data := data_of(kind)
	if _drops == null or data == null:
		return 0
	return data.base_cap + _storages.capacity_total(kind)


## True when a banked [param kind] is at or above its cap. An item kind is
## never full.
func is_full(kind: int) -> bool:
	var data := data_of(kind)
	if _drops == null or data == null or data.is_item:
		return false
	return count(kind) >= cap(kind)


## Lays one unit of the item [param kind] on the ground at [param spot], in
## art pixels. It counts in the stock at once. Returns the row of the drop,
## or [constant GridDrops.NO_DROP] when the kind is not an item kind or no
## cell is under the spot.
func drop(kind: int, spot: Vector2) -> int:
	var data := data_of(kind)
	if _drops == null or data == null or not data.is_item:
		return GridDrops.NO_DROP
	return _drops.add_at(spot, kind)


## Adds a storage building for [param kind] to the stock, under the id of
## the building. It holds up to [param capacity] and stands at [param spot],
## in art pixels. A storage of a banked kind, such as a silo, raises the cap
## of the kind. Returns false when the id is taken, the kind is not known, or
## no cell is under the spot.
func add_storage(storage: int, kind: int, capacity: int, spot: Vector2) -> bool:
	if _drops == null or data_of(kind) == null or not _drops.is_ground(spot):
		return false
	if not _storages.add(storage, kind, capacity, spot):
		return false
	changed.emit(kind)
	return true


func _on_ground_changed(_drop: int, kind: int) -> void:
	changed.emit(kind)


func _on_claims_changed(kind: int) -> void:
	changed.emit(kind)
