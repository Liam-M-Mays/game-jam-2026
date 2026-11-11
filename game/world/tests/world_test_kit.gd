class_name WorldTestKit
extends RefCounted
## What the world tests share: small worlds, and a walk over every cell.

## The world size the tests use, in cells. The real one is 100,000.
const CELLS := 2000
## The ground kind of the dark band of the saved band table.
const DARK := 1
## The ground kind of the light band of the saved band table.
const LIGHT := 2


## A village with a generated world of about [param cells] cells.
static func village(world_seed: int, cells: int = CELLS, recipe: WorldRecipe = null) -> Village:
	var made := Village.new(world_seed, 20)
	WorldGenerator.generate(made, cells, recipe)
	return made


## A copy of the saved recipe that a test may change.
static func recipe() -> WorldRecipe:
	return WorldRecipe.load_recipe().duplicate(true) as WorldRecipe


## Every cell of the world of [param made], row by row.
static func cells_of(made: Village) -> Array[Vector2i]:
	var bounds := GroundWorld.of(made).bounds
	var found: Array[Vector2i] = []
	var first_row := floori(bounds.position.y / GridLayout.ROW_HEIGHT) - 1
	var last_row := ceili(bounds.end.y / GridLayout.ROW_HEIGHT) + 1
	for y in range(first_row, last_row + 1):
		var shift := y * GridLayout.ROW_SHIFT
		var first := floori((bounds.position.x - shift) / GridLayout.CELL_WIDTH) - 2
		var last := ceili((bounds.end.x - shift) / GridLayout.CELL_WIDTH) + 2
		for x in range(first, last + 1):
			if made.grid.has_cell(Vector2i(x, y)):
				found.append(Vector2i(x, y))
	return found


## How many cells of [param made] have [param ground_kind].
static func count_ground(made: Village, ground_kind: int) -> int:
	var count := 0
	for cell in cells_of(made):
		if made.grid.ground(cell) == ground_kind:
			count += 1
	return count


## How many rows of [param world] are of the kind called [param kind_name].
static func count_rows(world: GroundWorld, kind_name: StringName) -> int:
	var count := 0
	for row in world.thing_count():
		if world.thing_kind(row).kind_name == kind_name:
			count += 1
	return count
