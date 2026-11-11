class_name GridChunk
extends RefCounted
## One square piece of the grid: the data of 16 by 16 cells, as arrays.
##
## A cell stores its ground kind, what stands on it, who reserved it, and its
## loose drops. [VillageGrid] makes a chunk the first time a cell in it is
## added, so a round or a hand-shaped map only pays for the chunks it touches.

## How many cells a chunk is wide and tall.
const SIZE := 16
## How many cells a chunk holds.
const CELLS := SIZE * SIZE

## The ground kind of each cell. 0 means the cell does not exist.
var ground := PackedByteArray()
## The id of the thing that stands on each cell. 0 means nothing.
var occupant := PackedInt32Array()
## The id of who reserved each cell. 0 means nobody.
var reserved := PackedInt32Array()
## The loose drops of each cell that has any: cell index, then drop kind, then count.
var drops: Dictionary[int, Dictionary] = {}


func _init() -> void:
	ground.resize(CELLS)
	occupant.resize(CELLS)
	reserved.resize(CELLS)


## Which chunk [param cell] is in.
static func key_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / SIZE), floori(float(cell.y) / SIZE))


## Where [param cell] is inside the arrays of its chunk.
static func index_of(cell: Vector2i) -> int:
	return posmod(cell.y, SIZE) * SIZE + posmod(cell.x, SIZE)


## The chunk as plain data.
func snapshot() -> Dictionary:
	return {
		"ground": ground.duplicate(),
		"occupant": occupant.duplicate(),
		"reserved": reserved.duplicate(),
		"drops": drops.duplicate(true),
	}
