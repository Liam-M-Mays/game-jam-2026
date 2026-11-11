class_name WanderCrowd
extends RefCounted
## A crowd of meeples that wander about, for the stress scene and the batch demo.
##
## It stands in for the real meeple simulation, which comes later. Each meeple
## walks to a spot nearby, waits a moment and picks the next spot. The crowd
## is plain arrays, and it draws itself through the sprite batch.

## How fast a meeple walks, in pixels a second. The jam meeple's speed.
const WALK_SPEED := 100.0
## The head frames a meeple can get, and the share of each.
const LOADS: Dictionary[int, float] = {0: 0.6, 2: 0.15, 4: 0.1, 3: 0.1, 5: 0.05}

## Where each meeple is.
var spots := PackedVector2Array()

var _area: Rect2
var _rows: BatchRows
var _look: MeepleLook
var _rng := RandomNumberGenerator.new()
var _targets := PackedVector2Array()
var _pauses := PackedFloat32Array()
var _walking := PackedByteArray()


## The meeples stay inside [param area] and are drawn through [param rows].
func _init(area: Rect2, rows: BatchRows, look: MeepleLook, random_seed: int = 12345) -> void:
	_area = area
	_rows = rows
	_look = look
	_rng.seed = random_seed


## Returns how many meeples there are.
func count() -> int:
	return spots.size()


## Adds meeples at random places until there are [param wanted] of them.
func grow_to(wanted: int) -> void:
	var before := spots.size()
	spots.resize(wanted)
	_targets.resize(wanted)
	_pauses.resize(wanted)
	_walking.resize(wanted)
	_rows.resize_movers(wanted)
	for index in range(before, wanted):
		var spot := _area.position + Vector2(_rng.randf(), _rng.randf()) * _area.size
		spots[index] = spot
		_targets[index] = spot
		_pauses[index] = _rng.randf_range(0.0, 1.0)
		_walking[index] = 0
		var phase := _rng.randf_range(0.0, MeepleLook.PHASE_RANGE)
		var numbers := _look.numbers(_pick_load(), phase, false)
		_rows.place_mover(index, spot, MeepleLook.shirt_colour(_rng.randf()), numbers)


## Moves every meeple by [param delta] seconds and tells the batch where they are.
func step(delta: float) -> void:
	_wander(delta)
	_rows.move_movers(spots)


## Only the wandering, without telling the batch. The stress scene times the
## two halves apart.
func wander_only(delta: float) -> void:
	_wander(delta)


func _wander(delta: float) -> void:
	var stride := WALK_SPEED * delta
	for index in spots.size():
		if _walking[index] == 1:
			var spot := spots[index]
			var way := _targets[index] - spot
			var distance := way.length()
			if distance <= stride:
				spots[index] = _targets[index]
				_walking[index] = 0
				_pauses[index] = _rng.randf_range(0.3, 1.5)
				_rows.set_mover_number(index, 3, MeepleLook.STANDING)
			else:
				spots[index] = spot + way * (stride / distance)
		else:
			var wait := _pauses[index] - delta
			if wait <= 0.0:
				var turn := Vector2.from_angle(_rng.randf() * TAU)
				var next := spots[index] + turn * _rng.randf_range(100.0, 400.0)
				_targets[index] = next.clamp(_area.position, _area.end)
				_walking[index] = 1
				_rows.set_mover_number(index, 3, MeepleLook.WALKING)
			else:
				_pauses[index] = wait


func _pick_load() -> int:
	var roll := _rng.randf()
	for frame: int in LOADS:
		roll -= LOADS[frame]
		if roll < 0.0:
			return frame
	return MeepleLook.EMPTY_HANDED
