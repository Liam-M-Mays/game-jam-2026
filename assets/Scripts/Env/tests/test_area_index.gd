extends GameTest
## AreaIndex only looks near a spot, from part 5c of #14. It must still find what a check of every
## item finds: the nearest tree for a lumberjack, and the drop with the shortest total trip for a pile
## worker. Drops move, are claimed and are taken away, so the test does that too.

const SIZE := 140.0
const SPREAD := 3000.0


## A thing with a position, as a drop or a tree has.
class Thing extends RefCounted:
	var position : Vector2
	var taken := false


var _rng := RandomNumberGenerator.new()
var _things : Array[Thing] = []
var _area : AreaIndex


func before_each() -> void:
	_rng.seed = 5
	_area = AreaIndex.new(SIZE)
	_things.clear()
	# A crowd in one corner and a few far away, as a village with stray drops looks.
	for i in 400:
		var thing := Thing.new()
		var spread := SPREAD * (0.15 if i < 340 else 1.0)
		thing.position = Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		thing.taken = _rng.randf() < 0.3
		_things.append(thing)
		_area.add(thing, thing.position)


func _spot() -> Vector2:
	return Vector2(_rng.randf_range(-SPREAD, SPREAD), _rng.randf_range(-SPREAD, SPREAD))


func _nearest_by_checking_all(from : Vector2) -> float:
	var best := INF
	for thing in _things:
		if not thing.taken:
			best = minf(best, from.distance_squared_to(thing.position))
	return best


func _shortest_trip_by_checking_all(from : Vector2, to : Vector2) -> float:
	var best := INF
	for thing in _things:
		if not thing.taken:
			best = minf(best, from.distance_to(thing.position) + thing.position.distance_to(to))
	return best


func _nearest(from : Vector2) -> Thing:
	return _area.best(from, func(thing : Thing) -> float:
		return INF if thing.taken else from.distance_squared_to(thing.position),
		func(away : float) -> float: return away * away)


func _shortest_trip(from : Vector2, to : Vector2) -> Thing:
	var straight := from.distance_to(to)
	return _area.best(from, func(thing : Thing) -> float:
		return INF if thing.taken else from.distance_to(thing.position) + thing.position.distance_to(to),
		func(away : float) -> float: return maxf(away, 2.0 * away - straight))


func _check_searches(label : String) -> void:
	for i in 200:
		var from := _spot()
		var to := _spot() if i % 2 == 0 else from + Vector2(_rng.randf_range(-200, 200), _rng.randf_range(-200, 200))
		var near := _nearest(from)
		check_near(from.distance_squared_to(near.position), _nearest_by_checking_all(from), 0.01, "%s: nearest from %s" % [label, from])
		var trip := _shortest_trip(from, to)
		var length := from.distance_to(trip.position) + trip.position.distance_to(to)
		check_near(length, _shortest_trip_by_checking_all(from, to), 0.01, "%s: shortest trip from %s to %s" % [label, from, to])


func test_finds_what_checking_every_item_finds() -> void:
	_check_searches("placed")


func test_still_finds_it_after_things_move_and_go() -> void:
	for thing in _things.slice(0, 150):
		var to := _spot()
		_area.move(thing, thing.position, to)
		thing.position = to
	for thing in _things.slice(150, 250):
		_area.remove(thing, thing.position)
	_things = _things.slice(0, 150) + _things.slice(250)
	_check_searches("moved")


func test_finds_nothing_when_everything_is_taken() -> void:
	for thing in _things:
		thing.taken = true
	check(_nearest(Vector2.ZERO) == null, "no free thing, no answer")
