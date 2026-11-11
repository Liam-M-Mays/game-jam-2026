class_name GroundWorld
extends VillagePart
## The ground world of a village, as [WorldGenerator] made it.
##
## It hangs on its village under [constant PART]. It holds what the generator
## decided: the size, the start cell, the cells kept clear round the start,
## and one row per tree, rock and bush it placed. The cells themselves, with
## their band as the ground kind, are in the village grid.
##
## The rows are the world as it was made. Nothing here chops or regrows: the
## nature part (#66) does that, and takes the rows over.

## The name this part hangs under on its village.
const PART := &"world"

## The band table and the numbers this world was made from.
var recipe: WorldRecipe
## The kinds of tree, rock and bush of this world. A row stores a kind as its
## place in this list.
var kinds: Array[NatureKind] = []
## How many cells were asked for.
var asked_cells: int = 0
## How many cells the world really has. The world is round, so this differs a
## little from what was asked.
var cells: int = 0
## The radius of the world before the edge was made uneven, in art pixels.
var radius: float = 0.0
## The area that holds the middle of every cell, in art pixels.
var bounds := Rect2()
## The first cell of the start building. The Town Hall goes here (#69).
var start_cell := Vector2i.ZERO
## The cells kept clear of trees, rocks and bushes for the whole game: the
## cells of the start building and the ring round them.
var keep_clear: Array[Vector2i] = []
## The id of each tree, rock and bush, as the grid knows it.
var thing_ids := PackedInt32Array()
## The kind of each one, as its place in [member kinds].
var thing_kinds := PackedByteArray()
## The first cell of each one: x, then y. Two numbers per row.
var thing_cells := PackedInt32Array()
## How many of each kind the world should hold, by kind name.
var wanted: Dictionary[StringName, int] = {}
## How many of each kind were placed, by kind name.
var placed: Dictionary[StringName, int] = {}

var _clear: Dictionary[Vector2i, bool] = {}


## The world of [param village], or null when it has none.
static func of(village: Village) -> GroundWorld:
	return village.part(PART) as GroundWorld


## How many trees, rocks and bushes the generator placed.
func thing_count() -> int:
	return thing_ids.size()


## The first cell of the thing in row [param row].
func thing_cell(row: int) -> Vector2i:
	return Vector2i(thing_cells[row * 2], thing_cells[row * 2 + 1])


## The kind of the thing in row [param row].
func thing_kind(row: int) -> NatureKind:
	return kinds[thing_kinds[row]]


## The cells of the start building, the first cell first.
func start_cells() -> Array[Vector2i]:
	return GridLayout.footprint(start_cell, recipe.start_width, recipe.start_depth)


## Marks [param cell] as kept clear. The generator calls this.
func add_keep_clear(cell: Vector2i) -> void:
	if not _clear.has(cell):
		_clear[cell] = true
		keep_clear.append(cell)


## True when [param cell] is kept clear of trees, rocks and bushes. Regrowth
## has to ask this before it plants anything.
func is_kept_clear(cell: Vector2i) -> bool:
	return _clear.has(cell)


## Lets go of everything. The village calls this when it closes.
func close() -> void:
	recipe = null
	kinds = []
	keep_clear = []
	_clear = {}
	thing_ids = PackedInt32Array()
	thing_kinds = PackedByteArray()
	thing_cells = PackedInt32Array()
	wanted = {}
	placed = {}


## The world as plain data. Two worlds with the same snapshot are the same.
func snapshot() -> Dictionary:
	return {
		"asked_cells": asked_cells,
		"cells": cells,
		"radius": radius,
		"bounds": bounds,
		"start_cell": start_cell,
		"keep_clear": keep_clear.duplicate(),
		"thing_ids": thing_ids.duplicate(),
		"thing_kinds": thing_kinds.duplicate(),
		"thing_cells": thing_cells.duplicate(),
		"wanted": wanted.duplicate(),
		"placed": placed.duplicate(),
	}
