class_name GridDrops
extends RefCounted
## The drops that lie on the ground of a grid, as rows.
##
## A drop is one unit of a resource kind, lying where it fell. It is a row
## number, and the row stores its kind, its cell and the spot where it landed.
## Beside the rows, each cell keeps a count per kind, so "what lies on this
## cell" is one read. There is no cap, and a drop never moves.
## Reach it as [member VillageGrid.drops].
##
## A drop is loose until somebody claims it. A claimed drop still lies on its
## spot, but [method closest] no longer finds it, so two haulers never go for
## the same drop. This class is the ground itself: it does not know the
## resource kinds or the reservations. The stock of the village counts the
## drops and listens to this class: see [VillageStock].
## - Lay a drop with [method VillageStock.drop]. [method add] and
##   [method add_at] take any kind number, also one that should never lie on
##   the ground, such as food.
## - Claim a drop through [StockClaims]. A claim made here directly is not
##   known to the reservations.
## - A loose drop can be taken with [method remove] or [method take]. The
##   stock hears it and keeps its reservations right.
##
## A row number is used again after its drop is taken. So do not keep a row
## number for later: claim the drop, and ask by the claimer.

## A drop came to lie on the ground. [param drop] is its row.
signal added(drop: int, kind: int)
## A drop was taken off the ground. Its row is not used again before every
## listener has heard this, so a drop that a listener lays gets another row.
signal removed(drop: int, kind: int)

## The answer when there is no drop.
const NO_DROP := -1
## The id that means nobody claimed a drop.
const NOBODY := 0
## The kind of a row that holds no drop.
const NO_KIND := 0
## The highest kind number a row can store.
const MAX_KIND := 255
## How many loose drops of one cell [method closest] looks at, newest first.
## It keeps a lookup small next to a big heap. Two drops of one cell lie at
## most 8.61 art pixels apart, the corner to corner of a cell of 7 by 5, so
## the pick is never further away than the closest drop plus that.
const MOST_LOOKS_PER_CELL := 8

# A cell that [method closest] found is kept as one whole number, so that the
# cells can be sorted by how near they are: the near side of the cell, squared
# and cut into sixteenths, and behind it the place of the cell in the list.
# From a point more than 131,072 art pixels away, 50 times the width of the
# big world, the near side no longer fits and loses its top. The number is
# then too small, never too big: the cells are sorted badly and more drops
# are looked at, but the answer is still the closest drop.
const _KEY_STEPS := 16.0
const _KEY_SHIFT := 24
const _KEY_MASK := (1 << _KEY_SHIFT) - 1

## How many drops the last call of [method closest] looked at. The test that
## guards the cost of a lookup reads it.
var looked_at: int = 0
## How many cells the last call of [method closest] read to find those drops.
## Reading a cell is one array read: it is much cheaper than looking at a drop.
var cells_read: int = 0

var _chunks: Dictionary[Vector2i, GridChunk]
var _kinds := PackedByteArray()
var _cells := PackedInt32Array()
var _spots := PackedVector2Array()
var _claimers := PackedInt32Array()
var _next := PackedInt32Array()
var _prev := PackedInt32Array()
var _free_row := NO_DROP
var _totals: Dictionary[int, int] = {}
var _loose: Dictionary[int, int] = {}
var _has_keys := false
var _low_key := Vector2i.ZERO
var _high_key := Vector2i.ZERO
var _best := NO_DROP
var _best_distance := INF
var _reach := INF
var _found := PackedInt64Array()
var _found_heads := PackedInt32Array()


func _init(chunks: Dictionary[Vector2i, GridChunk]) -> void:
	_chunks = chunks


## Lays [param count] drops of [param kind] on [param cell], at the position
## of the cell. Returns false when the cell does not exist or the count is
## not above zero. To lay a drop on the spot where it landed, use
## [method add_at].
func add(cell: Vector2i, kind: int, count: int = 1) -> bool:
	if count <= 0 or _chunk_with(cell) == null or kind <= NO_KIND or kind > MAX_KIND:
		return false
	var spot := GridLayout.position_of(cell)
	for i in count:
		add_at(spot, kind)
	return true


## Lays one drop of [param kind] on the ground at [param spot], which is in
## art pixels. Returns its row, or [constant NO_DROP] when no cell is under
## the spot or the kind is not 1 to 255.
func add_at(spot: Vector2, kind: int) -> int:
	if kind <= NO_KIND or kind > MAX_KIND:
		return NO_DROP
	var cell := GridLayout.cell_under(spot)
	var chunk := _chunk_with(cell)
	if chunk == null:
		return NO_DROP
	var drop := _free_row
	if drop == NO_DROP:
		drop = _kinds.size()
		_kinds.append(kind)
		_cells.append(cell.x)
		_cells.append(cell.y)
		_spots.append(spot)
		_claimers.append(NOBODY)
		_next.append(NO_DROP)
		_prev.append(NO_DROP)
	else:
		_free_row = _next[drop]
		_kinds[drop] = kind
		_cells[drop * 2] = cell.x
		_cells[drop * 2 + 1] = cell.y
		_spots[drop] = spot
		_claimers[drop] = NOBODY
	if not chunk.drop_counts.has(kind):
		var counts := PackedInt32Array()
		counts.resize(GridChunk.CELLS)
		chunk.drop_counts[kind] = counts
		var heads := PackedInt32Array()
		heads.resize(GridChunk.CELLS)
		heads.fill(NO_DROP)
		chunk.loose_heads[kind] = heads
		chunk.loose_totals[kind] = 0
	var index := GridChunk.index_of(cell)
	chunk.drop_counts[kind][index] += 1
	_totals[kind] = _totals.get(kind, 0) + 1
	_link(drop, chunk, kind, index)
	_stretch_to(GridChunk.key_of(cell))
	added.emit(drop, kind)
	return drop


## Takes up to [param count] loose drops of [param kind] from [param cell],
## the newest first. Returns how many were really taken.
func take(cell: Vector2i, kind: int, count: int = 1) -> int:
	var chunk := _chunk_with(cell)
	if chunk == null or not chunk.loose_heads.has(kind):
		return 0
	var index := GridChunk.index_of(cell)
	var taken := 0
	while taken < count and chunk.loose_heads[kind][index] != NO_DROP:
		remove(chunk.loose_heads[kind][index])
		taken += 1
	return taken


## Takes [param drop] off the ground. A claimed drop is only taken when
## [param claimer] is the one who claimed it. Returns false when there is no
## such drop, or it is claimed by somebody else.
func remove(drop: int, claimer: int = NOBODY) -> bool:
	if not has(drop) or (_claimers[drop] != NOBODY and _claimers[drop] != claimer):
		return false
	var kind := _kinds[drop]
	var cell := cell_of(drop)
	var chunk: GridChunk = _chunks[GridChunk.key_of(cell)]
	var index := GridChunk.index_of(cell)
	if _claimers[drop] == NOBODY:
		_unlink(drop, chunk, kind, index)
	chunk.drop_counts[kind][index] -= 1
	_totals[kind] -= 1
	_kinds[drop] = NO_KIND
	_claimers[drop] = NOBODY
	_prev[drop] = NO_DROP
	_next[drop] = NO_DROP
	# The listeners hear it first. Only then is the row free to be used again.
	removed.emit(drop, kind)
	_next[drop] = _free_row
	_free_row = drop
	return true


## Claims the loose [param drop] for [param claimer], an id above zero. The
## drop stays on its spot, and [method closest] no longer finds it. Returns
## false when the drop is not there or is already claimed.
func claim(drop: int, claimer: int) -> bool:
	if claimer <= NOBODY or not has(drop) or _claimers[drop] != NOBODY:
		return false
	var cell := cell_of(drop)
	_unlink(drop, _chunks[GridChunk.key_of(cell)], _kinds[drop], GridChunk.index_of(cell))
	_claimers[drop] = claimer
	return true


## Makes the claimed [param drop] loose again. Returns false when the drop is
## not there or was not claimed.
func unclaim(drop: int) -> bool:
	if not has(drop) or _claimers[drop] == NOBODY:
		return false
	var cell := cell_of(drop)
	_claimers[drop] = NOBODY
	_link(drop, _chunks[GridChunk.key_of(cell)], _kinds[drop], GridChunk.index_of(cell))
	return true


## The loose drop of [param kind] that lies closest to [param point], or
## [constant NO_DROP] when there is none. It only looks at the drops on the
## cells around the point, not at every drop: [member looked_at] says how many.
## On a cell with more than [constant MOST_LOOKS_PER_CELL] loose drops of the
## kind, it looks at the newest ones only. When two drops are at the very
## same distance it gives one of them: no rule says which.
##
## It works in two steps. First it reads the cells around the point and keeps
## the ones that hold a loose drop and can hold the closest one. No drop is
## looked at for that: the far side of a cell says how far its drops can be at
## most. Then it looks at the drops, nearest cell first, and stops at the
## first cell that is too far away to hold a closer drop.
func closest(kind: int, point: Vector2) -> int:
	looked_at = 0
	cells_read = 0
	_best = NO_DROP
	_best_distance = INF
	if _loose.get(kind, 0) <= 0:
		return NO_DROP
	_reach = INF
	_found.clear()
	_found_heads.clear()
	var home_row := floori((point.y - GridLayout.CELL_MIDDLE.y) / GridLayout.ROW_HEIGHT + 0.5)
	var home_band := floori(float(home_row) / GridChunk.SIZE)
	var step := 0
	var below := true
	var above := true
	while below or above:
		if below:
			below = _search_band(kind, point, home_band + step, 1)
		if above and step > 0:
			above = _search_band(kind, point, home_band - step, -1)
		step += 1
	_found.sort()
	for key in _found:
		if (key >> _KEY_SHIFT) / _KEY_STEPS >= _best_distance:
			break
		_look(_found_heads[key & _KEY_MASK], point)
	return _best


## True when [param drop] is the row of a drop that lies on the ground.
func has(drop: int) -> bool:
	return drop >= 0 and drop < _kinds.size() and _kinds[drop] != NO_KIND


## The kind of [param drop]. 0 when there is no such drop.
func kind_of(drop: int) -> int:
	return _kinds[drop] if has(drop) else NO_KIND


## The spot where [param drop] landed, in art pixels. Only ask for a drop
## that is there.
func spot_of(drop: int) -> Vector2:
	return _spots[drop] if has(drop) else Vector2.ZERO


## The cell [param drop] lies on. Only ask for a drop that is there.
func cell_of(drop: int) -> Vector2i:
	if not has(drop):
		return GridLayout.NO_CELL
	return Vector2i(_cells[drop * 2], _cells[drop * 2 + 1])


## The id of who claimed [param drop]. 0 when it is loose or not there.
func claimer_of(drop: int) -> int:
	return _claimers[drop] if has(drop) else NOBODY


## How many drops of [param kind] lie on [param cell], claimed or not.
func count_at(cell: Vector2i, kind: int) -> int:
	var chunk := _chunk_with(cell)
	if chunk == null or not chunk.drop_counts.has(kind):
		return 0
	return chunk.drop_counts[kind][GridChunk.index_of(cell)]


## True when at least one drop lies on [param cell], claimed or not.
func has_any(cell: Vector2i) -> bool:
	var chunk := _chunk_with(cell)
	if chunk == null:
		return false
	var index := GridChunk.index_of(cell)
	for kind: int in chunk.drop_counts:
		if chunk.drop_counts[kind][index] > 0:
			return true
	return false


## Every drop on [param cell]: drop kind, then count. Empty when there is none.
func at(cell: Vector2i) -> Dictionary:
	var found := {}
	var chunk := _chunk_with(cell)
	if chunk == null:
		return found
	var index := GridChunk.index_of(cell)
	var kinds := chunk.drop_counts.keys()
	kinds.sort()
	for kind: int in kinds:
		if chunk.drop_counts[kind][index] > 0:
			found[kind] = chunk.drop_counts[kind][index]
	return found


## How many drops of [param kind] lie on the ground, claimed or not.
func total(kind: int) -> int:
	return _totals.get(kind, 0)


## How many loose drops of [param kind] lie on the ground.
func loose(kind: int) -> int:
	return _loose.get(kind, 0)


## True when a drop can lie at [param spot]: a cell is under it.
func is_ground(spot: Vector2) -> bool:
	return _chunk_with(GridLayout.cell_under(spot)) != null


## One more than the highest row number that was ever used. To walk every
## drop, go from 0 to this and ask [method has].
func size() -> int:
	return _kinds.size()


## The rows as plain data. The counts per cell are in the snapshot of each chunk.
func snapshot() -> Dictionary:
	return {
		"kinds": _kinds.duplicate(),
		"cells": _cells.duplicate(),
		"spots": _spots.duplicate(),
		"claimers": _claimers.duplicate(),
		"next": _next.duplicate(),
		"prev": _prev.duplicate(),
		"free_row": _free_row,
		"totals": _totals.duplicate(),
		"loose": _loose.duplicate(),
	}


## Puts a drop at the front of the loose drops of its cell.
func _link(drop: int, chunk: GridChunk, kind: int, index: int) -> void:
	var head := chunk.loose_heads[kind][index]
	_prev[drop] = NO_DROP
	_next[drop] = head
	if head != NO_DROP:
		_prev[head] = drop
	chunk.loose_heads[kind][index] = drop
	chunk.loose_totals[kind] += 1
	_loose[kind] = _loose.get(kind, 0) + 1


## Takes a drop out of the loose drops of its cell.
func _unlink(drop: int, chunk: GridChunk, kind: int, index: int) -> void:
	var before := _prev[drop]
	var after := _next[drop]
	if before == NO_DROP:
		chunk.loose_heads[kind][index] = after
	else:
		_next[before] = after
	if after != NO_DROP:
		_prev[after] = before
	chunk.loose_totals[kind] -= 1
	_loose[kind] -= 1


## Keeps the block of chunks that ever held a drop. A lookup never walks
## outside it.
func _stretch_to(key: Vector2i) -> void:
	if not _has_keys:
		_has_keys = true
		_low_key = key
		_high_key = key
		return
	_low_key = Vector2i(mini(_low_key.x, key.x), mini(_low_key.y, key.y))
	_high_key = Vector2i(maxi(_high_key.x, key.x), maxi(_high_key.y, key.y))


## Reads one band of chunks: the chunks that share 16 rows. It starts at the
## chunk under the point and walks left and right, as far as a chunk can still
## hold the closest drop. Returns false when no band further that way can
## hold it, so the caller stops going that way.
func _search_band(kind: int, point: Vector2, band: int, way: int) -> bool:
	if (way > 0 and band > _high_key.y) or (way < 0 and band < _low_key.y):
		return false
	if band < _low_key.y or band > _high_key.y:
		return true
	var first_row := band * GridChunk.SIZE
	var top := first_row * GridLayout.ROW_HEIGHT + GridLayout.CELL_MIDDLE.y
	top -= GridLayout.ROW_HEIGHT * 0.5
	var bottom := top + GridChunk.SIZE * GridLayout.ROW_HEIGHT
	var down := maxf(maxf(top - point.y, point.y - bottom), 0.0)
	if down * down >= _reach:
		return false
	# A chunk leans like the grid, so its box is wider than its 16 cells.
	var chunk_step := float(GridChunk.SIZE * GridLayout.CELL_WIDTH)
	var chunk_width := chunk_step + (GridChunk.SIZE - 1) * GridLayout.ROW_SHIFT
	var left_of_first := first_row * GridLayout.ROW_SHIFT + GridLayout.CELL_MIDDLE.x
	left_of_first -= GridLayout.CELL_WIDTH * 0.5
	var start := floori((point.x - left_of_first) / chunk_step)
	var column := mini(start, _high_key.x)
	while column >= _low_key.x:
		var across := maxf(point.x - (left_of_first + column * chunk_step + chunk_width), 0.0)
		if across * across + down * down >= _reach:
			break
		_search_chunk(kind, point, Vector2i(column, band))
		column -= 1
	column = maxi(start + 1, _low_key.x)
	while column <= _high_key.x:
		var across := maxf(left_of_first + column * chunk_step - point.x, 0.0)
		if across * across + down * down >= _reach:
			break
		_search_chunk(kind, point, Vector2i(column, band))
		column += 1
	return true


## Reads the rows of one chunk, from the row nearest to the point outwards,
## as far as a row can still hold the closest drop.
func _search_chunk(kind: int, point: Vector2, key: Vector2i) -> void:
	var chunk: GridChunk = _chunks.get(key)
	if chunk == null or chunk.loose_totals.get(kind, 0) <= 0:
		return
	var heads := chunk.loose_heads[kind]
	var first_cell := key * GridChunk.SIZE
	var home_row := floori((point.y - GridLayout.CELL_MIDDLE.y) / GridLayout.ROW_HEIGHT + 0.5)
	var near := clampi(home_row - first_cell.y, 0, GridChunk.SIZE - 1)
	var step := 0
	var below := true
	var above := true
	while below or above:
		if below:
			below = near + step < GridChunk.SIZE
			below = below and _search_row(heads, point, first_cell, near + step)
		if above and step > 0:
			above = near - step >= 0
			above = above and _search_row(heads, point, first_cell, near - step)
		step += 1


## Reads the cells of one row of a chunk, from the cell nearest to the point
## outwards, as far as a cell can still hold the closest drop. A cell with a
## loose drop is kept for the second step. Returns false when the whole row
## is too far away.
func _search_row(
	heads: PackedInt32Array, point: Vector2, first_cell: Vector2i, local_row: int
) -> bool:
	var row := first_cell.y + local_row
	var row_middle := row * GridLayout.ROW_HEIGHT + GridLayout.CELL_MIDDLE.y
	var off_row := absf(point.y - row_middle)
	var down := maxf(off_row - GridLayout.ROW_HEIGHT * 0.5, 0.0)
	if down * down >= _reach:
		return false
	var far_down := off_row + GridLayout.ROW_HEIGHT * 0.5
	# The middle of the first cell of this chunk in this row. It is a number
	# with a half in it, so it must not be kept as a whole number.
	var first_middle: float = first_cell.x * GridLayout.CELL_WIDTH + row * GridLayout.ROW_SHIFT
	first_middle += GridLayout.CELL_MIDDLE.x
	var from_first := (point.x - first_middle) / GridLayout.CELL_WIDTH
	var near := clampi(floori(from_first + 0.5), 0, GridChunk.SIZE - 1)
	var row_start := local_row * GridChunk.SIZE
	var half_cell := GridLayout.CELL_WIDTH * 0.5
	var column := near
	while column >= 0:
		var off := absf(point.x - (first_middle + column * GridLayout.CELL_WIDTH))
		var across := maxf(off - half_cell, 0.0)
		var near_side := across * across + down * down
		if near_side >= _reach:
			break
		if heads[row_start + column] != NO_DROP:
			var far_across := off + half_cell
			_keep(heads[row_start + column], near_side, far_across * far_across + far_down * far_down)
		column -= 1
	cells_read += near - column
	column = near + 1
	while column < GridChunk.SIZE:
		var off := absf(point.x - (first_middle + column * GridLayout.CELL_WIDTH))
		var across := maxf(off - half_cell, 0.0)
		var near_side := across * across + down * down
		if near_side >= _reach:
			break
		if heads[row_start + column] != NO_DROP:
			var far_across := off + half_cell
			_keep(heads[row_start + column], near_side, far_across * far_across + far_down * far_down)
		column += 1
	cells_read += column - near - 1
	return true


## Keeps a cell with a loose drop for the second step of [method closest].
## [param near_side] and [param far_side] are how far the nearest and the
## farthest corner of the cell are from the point, squared. Every drop of the
## cell lies between the two, so no cell beyond the far side has to be read.
func _keep(head: int, near_side: float, far_side: float) -> void:
	_found.append((int(near_side * _KEY_STEPS) << _KEY_SHIFT) | _found_heads.size())
	_found_heads.append(head)
	_reach = minf(_reach, far_side)


## Looks at the loose drops of one cell, newest first, and keeps the closest.
func _look(head: int, point: Vector2) -> void:
	var drop := head
	var looks := 0
	while drop != NO_DROP and looks < MOST_LOOKS_PER_CELL:
		var distance := point.distance_squared_to(_spots[drop])
		if distance < _best_distance:
			_best_distance = distance
			_best = drop
		drop = _next[drop]
		looks += 1
	looked_at += looks


func _chunk_with(cell: Vector2i) -> GridChunk:
	var chunk: GridChunk = _chunks.get(GridChunk.key_of(cell))
	if chunk == null or chunk.ground[GridChunk.index_of(cell)] == 0:
		return null
	return chunk
