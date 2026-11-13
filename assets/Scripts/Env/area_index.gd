extends RefCounted
class_name AreaIndex
## Keeps things in square buckets by their position in a grid's space, so a search for the best one
## looks near a spot first and stops as soon as nothing farther away can be better.
## Inventory keeps its drops in one per kind, and Grid its trees, rocks and bushes in one per kind.

var _size : float
var _buckets : Dictionary[Vector2i, Array] = {}
var _low := Vector2i.MAX
var _high := Vector2i.MIN

## `bucket_size` is the side of one bucket, in the grid's space.
func _init(bucket_size : float) -> void:
	_size = bucket_size

## Puts `item` in the bucket of `at`.
func add(item : Object, at : Vector2) -> void:
	var key := _key(at)
	_buckets.get_or_add(key, []).append(item)
	_low = _low.min(key)
	_high = _high.max(key)

## Takes `item` out of the bucket of `at`, the spot it was added at.
func remove(item : Object, at : Vector2) -> void:
	var key := _key(at)
	var list : Array = _buckets.get(key, [])
	var index := list.find(item)
	if index >= 0:
		list.remove_at(index)
	if list.is_empty():
		_buckets.erase(key)

## Moves `item` from the bucket of `from` to the bucket of `to`, when they differ.
func move(item : Object, from : Vector2, to : Vector2) -> void:
	if _key(from) != _key(to):
		remove(item, from)
		add(item, to)

## Empties every bucket.
func clear() -> void:
	_buckets.clear()
	_low = Vector2i.MAX
	_high = Vector2i.MIN

## The item with the lowest `score`, looking in rings of buckets around `from`. `score` takes an item and
## returns INF for one that does not count. `bound` takes a distance from `from` and returns the lowest
## score an item that far away could have. Only items scoring below `beat` count. Null when none does.
func best(from : Vector2, score : Callable, bound : Callable, beat := INF) -> Object:
	if _buckets.is_empty():
		return null
	var middle := _key(from)
	var last := maxi(maxi(absi(middle.x - _low.x), absi(middle.x - _high.x)), maxi(absi(middle.y - _low.y), absi(middle.y - _high.y)))
	var found : Object = null
	for ring in range(last + 1):
		if bound.call(maxi(ring - 1, 0) * _size) >= beat:
			break
		# A ring with more buckets than there are full ones: go through the full ones left instead.
		var keys : Array = _ring(middle, ring) if 8 * ring <= _buckets.size() else _buckets.keys()
		for key : Vector2i in keys:
			var steps := maxi(absi(key.x - middle.x), absi(key.y - middle.y))
			if steps < ring or steps > ring and bound.call((steps - 1) * _size) >= beat:
				continue
			for item : Object in _buckets.get(key, []):
				var value : float = score.call(item)
				if value < beat:
					beat = value
					found = item
		if 8 * ring > _buckets.size():
			break
	return found

func _key(at : Vector2) -> Vector2i:
	return Vector2i(floori(at.x / _size), floori(at.y / _size))

## The buckets exactly `ring` steps away from `middle`, counting diagonal steps as one.
func _ring(middle : Vector2i, ring : int) -> Array:
	if ring == 0:
		return [middle]
	var keys := []
	for x in range(-ring, ring + 1):
		keys.append(middle + Vector2i(x, -ring))
		keys.append(middle + Vector2i(x, ring))
	for y in range(-ring + 1, ring):
		keys.append(middle + Vector2i(-ring, y))
		keys.append(middle + Vector2i(ring, y))
	return keys
