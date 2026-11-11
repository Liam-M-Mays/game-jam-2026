class_name VillageGrid
extends RefCounted
## The grid of one village, as data in chunks.
##
## A cell stores its ground kind, what stands on it, who reserved it, and its
## loose drops. The layout is the slanted six-neighbour grid of the jam game:
## the maths is in [GridLayout]. Things and reservers are named by a number
## above zero, which [method Village.new_id] hands out.
##
## The grid answers four questions for other systems: [method cell_at],
## [method free_cells_at], [method empty_cells_near] and [method cells_at_offsets].

## The id that means no thing stands on a cell.
const NOTHING := 0
## The id that means nobody reserved a cell.
const NOBODY := 0
## The ground kind of a cell that does not exist.
const NO_GROUND := 0
## The ground kind a cell gets when none is named.
const PLAIN_GROUND := 1
## The highest ground kind a cell can store.
const MAX_GROUND := 255

## The loose drops that lie on the cells.
var drops: GridDrops

var _chunks: Dictionary[Vector2i, GridChunk] = {}
var _things: Dictionary[int, Rect2i] = {}
var _reserved_cells: Dictionary[int, Array] = {}
var _cell_total: int = 0
var _last_key := GridLayout.NO_CELL
var _last_chunk: GridChunk = null


func _init() -> void:
	drops = GridDrops.new(_chunks)


## Adds [param cell] to the grid with ground kind [param ground_kind], or
## changes the ground kind of a cell that is there. Returns false for a ground
## kind outside 1 to 255.
func add_cell(cell: Vector2i, ground_kind: int = PLAIN_GROUND) -> bool:
	if ground_kind <= NO_GROUND or ground_kind > MAX_GROUND:
		return false
	var key := GridChunk.key_of(cell)
	var chunk: GridChunk = _chunks.get(key)
	if chunk == null:
		chunk = GridChunk.new()
		_chunks[key] = chunk
		_last_key = key
		_last_chunk = chunk
	var index := GridChunk.index_of(cell)
	if chunk.ground[index] == NO_GROUND:
		_cell_total += 1
	chunk.ground[index] = ground_kind
	return true


## True when [param cell] exists.
func has_cell(cell: Vector2i) -> bool:
	return _chunk_with(cell) != null


## The ground kind of [param cell]. 0 when the cell does not exist.
func ground(cell: Vector2i) -> int:
	var chunk := _chunk_with(cell)
	return NO_GROUND if chunk == null else chunk.ground[GridChunk.index_of(cell)]


## How many cells the grid has.
func cell_count() -> int:
	return _cell_total


## The cell at [param point], which is in art pixels. A point off the map or
## over a missing cell gives [constant GridLayout.NO_CELL].
func cell_at(point: Vector2) -> Vector2i:
	var cell := GridLayout.cell_under(point)
	return cell if has_cell(cell) else GridLayout.NO_CELL


## The cells that touch [param cell] and exist. At most six.
func neighbours(cell: Vector2i) -> Array[Vector2i]:
	return cells_at_offsets(cell, GridLayout.NEIGHBOURS)


## The cells that sit at [param offsets] from [param origin] and exist, in the
## order of the offsets. A cell with something on it counts too.
func cells_at_offsets(origin: Vector2i, offsets: Array[Vector2i]) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for offset in offsets:
		if has_cell(origin + offset):
			found.append(origin + offset)
	return found


## The cells of a footprint that starts at [param anchor], when every one of
## them exists, is empty, and is not reserved by somebody other than
## [param on_behalf_of]. If one cell fails, the answer is empty.
func free_cells(
	anchor: Vector2i, width: int = 1, depth: int = 1, on_behalf_of: int = NOBODY
) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not GridLayout.is_footprint(width, depth):
		return none
	var cells := GridLayout.footprint(anchor, width, depth)
	for cell in cells:
		var chunk := _chunk_with(cell)
		if chunk == null:
			return none
		var index := GridChunk.index_of(cell)
		if chunk.occupant[index] != NOTHING:
			return none
		if chunk.reserved[index] != NOBODY and chunk.reserved[index] != on_behalf_of:
			return none
	return cells


## Like [method free_cells], with the anchor at [param point] in art pixels.
func free_cells_at(
	point: Vector2, width: int = 1, depth: int = 1, on_behalf_of: int = NOBODY
) -> Array[Vector2i]:
	return free_cells(GridLayout.cell_under(point), width, depth, on_behalf_of)


## The empty cells within [param steps] steps of [param thing], counted from
## each of its cells. A reserved cell with nothing on it counts as empty.
func empty_cells_near(thing: int, steps: int = 1) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var offsets := GridLayout.offsets_within(steps)
	for cell in thing_cells(thing):
		for offset in offsets:
			var near := cell + offset
			if seen.has(near):
				continue
			seen[near] = true
			if has_cell(near) and occupant(near) == NOTHING:
				found.append(near)
	return found


## Stands [param thing] on the footprint that starts at [param anchor], and
## marks every cell of it as taken. Returns false, and changes nothing, when
## the id is not above zero, the thing already stands somewhere, or
## [method free_cells] refuses the footprint.
func place(
	thing: int, anchor: Vector2i, width: int = 1, depth: int = 1, on_behalf_of: int = NOBODY
) -> bool:
	if thing <= NOTHING or _things.has(thing):
		return false
	var cells := free_cells(anchor, width, depth, on_behalf_of)
	if cells.is_empty():
		return false
	for cell in cells:
		_chunk_with(cell).occupant[GridChunk.index_of(cell)] = thing
	_things[thing] = Rect2i(anchor, Vector2i(width, depth))
	return true


## Takes [param thing] off the grid and forgets it. Returns the cells it
## freed, which is empty when the thing was not on the grid.
func remove(thing: int) -> Array[Vector2i]:
	var cells := thing_cells(thing)
	for cell in cells:
		_chunk_with(cell).occupant[GridChunk.index_of(cell)] = NOTHING
	_things.erase(thing)
	return cells


## The id of the thing that stands on [param cell]. 0 when nothing does.
func occupant(cell: Vector2i) -> int:
	var chunk := _chunk_with(cell)
	return NOTHING if chunk == null else chunk.occupant[GridChunk.index_of(cell)]


## The cells [param thing] stands on, the anchor first. Empty when it is not
## on the grid.
func thing_cells(thing: int) -> Array[Vector2i]:
	if not _things.has(thing):
		var none: Array[Vector2i] = []
		return none
	var spot: Rect2i = _things[thing]
	return GridLayout.footprint(spot.position, spot.size.x, spot.size.y)


## Where [param thing] stands, in art pixels: the position of its anchor cell.
## Only ask for a thing that is on the grid.
func thing_position(thing: int) -> Vector2:
	var spot: Rect2i = _things.get(thing, Rect2i())
	return GridLayout.position_of(spot.position)


## Reserves [param cells] for [param reserver]. Every cell has to exist and
## must not be reserved by somebody else. Returns false, and changes nothing,
## when one cell fails.
func reserve(cells: Array[Vector2i], reserver: int) -> bool:
	if reserver <= NOBODY:
		return false
	for cell in cells:
		var by := reserved_by(cell)
		if not has_cell(cell) or (by != NOBODY and by != reserver):
			return false
	var mine: Array = _reserved_cells.get(reserver, [])
	for cell in cells:
		if reserved_by(cell) == NOBODY:
			_chunk_with(cell).reserved[GridChunk.index_of(cell)] = reserver
			mine.append(cell)
	_reserved_cells[reserver] = mine
	return true


## Gives back every cell [param reserver] has reserved. Returns how many.
func release(reserver: int) -> int:
	var mine: Array = _reserved_cells.get(reserver, [])
	for cell: Vector2i in mine:
		_chunk_with(cell).reserved[GridChunk.index_of(cell)] = NOBODY
	_reserved_cells.erase(reserver)
	return mine.size()


## The id of who reserved [param cell]. 0 when nobody did.
func reserved_by(cell: Vector2i) -> int:
	var chunk := _chunk_with(cell)
	return NOBODY if chunk == null else chunk.reserved[GridChunk.index_of(cell)]


## The grid as plain data. Two grids with the same snapshot are the same.
func snapshot() -> Dictionary:
	var keys: Array[Vector2i] = []
	keys.assign(_chunks.keys())
	keys.sort()
	var chunks := {}
	for key in keys:
		chunks[key] = _chunks[key].snapshot()
	return {
		"cells": _cell_total,
		"chunks": chunks,
		"things": _things.duplicate(),
		"reserved": _reserved_cells.duplicate(true),
	}


func _chunk_with(cell: Vector2i) -> GridChunk:
	var key := GridChunk.key_of(cell)
	if key != _last_key:
		_last_key = key
		_last_chunk = _chunks.get(key)
	if _last_chunk == null or _last_chunk.ground[GridChunk.index_of(cell)] == NO_GROUND:
		return null
	return _last_chunk
