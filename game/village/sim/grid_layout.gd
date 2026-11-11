class_name GridLayout
extends Object
## The maths of the slanted grid. It is the layout of the jam game.
##
## A cell is a pair of whole numbers: x along a row, y down the rows. Each row
## is shifted sideways from the row above, so the grid leans like the 3/4 art.
## Positions are in art pixels. The jam game multiplied by 10 for its cell
## scale and by 0.1 for the giant's back, which cancel out.
## Nothing here holds data: every function is static.

## How far apart two cells of one row are, in art pixels.
const CELL_WIDTH := 7
## How far apart two rows are, in art pixels.
const ROW_HEIGHT := 5
## How far a row is shifted sideways from the row above, in art pixels.
const ROW_SHIFT := 5
## Where the middle of a cell's art sits, seen from the cell's position.
## A point is looked up against this middle.
const CELL_MIDDLE := Vector2(-0.5, 0.0)
## The six cells that touch a cell.
const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
]
## The smallest width and depth a footprint can have.
const MIN_FOOTPRINT := 1
## The largest width and depth a footprint can have.
const MAX_FOOTPRINT := 4
## The answer when there is no cell.
const NO_CELL := Vector2i(-2147483648, -2147483648)

static var _offsets_within: Dictionary[int, Array] = {}


## Where [param cell] sits, in art pixels.
static func position_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_WIDTH + cell.y * ROW_SHIFT, cell.y * ROW_HEIGHT)


## The cell whose middle is nearest to [param point] in the slanted grid.
## It does not check that the cell exists: [method VillageGrid.cell_at] does.
## A point exactly between two cells goes to the cell on the right, or to the
## row below, on both sides of zero. The jam game rounded such a point away
## from zero, which is the same for every cell it had: its cells started at 0.
static func cell_under(point: Vector2) -> Vector2i:
	var from_middle := point - CELL_MIDDLE
	var y := floori(from_middle.y / ROW_HEIGHT + 0.5)
	var x := floori((from_middle.x - ROW_SHIFT * y) / CELL_WIDTH + 0.5)
	return Vector2i(x, y)


## How many steps apart two cells are, counted the hex way.
static func distance(from: Vector2i, to: Vector2i) -> int:
	return steps_of(to - from)


## How many steps long [param offset] is, counted the hex way.
static func steps_of(offset: Vector2i) -> int:
	@warning_ignore("integer_division")
	return (absi(offset.x) + absi(offset.y) + absi(offset.x + offset.y)) / 2


## True when a footprint may be [param width] cells wide and [param depth] rows deep.
static func is_footprint(width: int, depth: int) -> bool:
	return (
		width >= MIN_FOOTPRINT
		and width <= MAX_FOOTPRINT
		and depth >= MIN_FOOTPRINT
		and depth <= MAX_FOOTPRINT
	)


## The cells of a footprint: from [param anchor] to the right for
## [param width], and down the rows for [param depth]. The anchor comes first.
static func footprint(anchor: Vector2i, width: int = 1, depth: int = 1) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in depth:
		for i in width:
			cells.append(anchor + Vector2i(i, row))
	return cells


## Every offset that is at most [param steps] steps long, the zero offset too.
## The list is worked out once per step count and then shared, so it cannot
## be changed. Copy it with [code]duplicate()[/code] to change it.
static func offsets_within(steps: int) -> Array[Vector2i]:
	if _offsets_within.has(steps):
		return _offsets_within[steps]
	var offsets: Array[Vector2i] = []
	for dx in range(-steps, steps + 1):
		for dy in range(-steps, steps + 1):
			var offset := Vector2i(dx, dy)
			if steps_of(offset) <= steps:
				offsets.append(offset)
	offsets.make_read_only()
	_offsets_within[steps] = offsets
	return offsets


## The cells of a block that starts at [param origin] and is [param size] cells big.
static func block(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(origin + Vector2i(x, y))
	return cells
