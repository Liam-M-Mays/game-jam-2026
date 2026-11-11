class_name JamGrid
extends RefCounted
## The jam game's grid and art numbers, in one place.
##
## The sprite batch has no grid numbers of its own. The dev scenes and the
## tests build their batch from the numbers here. This is a stand-in: the
## real grid is the village grid of part #60. A later part joins the batch to
## that grid, and then this file goes.
##
## The numbers are from the jam game's grid script: a cell's place is
## ((x * 7 + y * 5), y * 5) in art pixels, and art is drawn at 10 times size.

## How many pixels one art pixel takes at zoom 1.
const ART_SCALE := 10.0
## How wide a cell is, in art pixels.
const CELL_WIDTH := 7.0
## How much further right each row starts than the row above it, in art pixels.
const CELL_SLANT := 5.0
## How tall a cell is, in art pixels.
const CELL_HEIGHT := 5.0
## From a cell's position to the middle of the cell, in art pixels. The jam
## cell picture sits half an art pixel to the left.
const CELL_MIDDLE := Vector2(-0.5, 0.0)


## Returns the cell maths of the jam grid, with cell (0, 0) at [param origin].
static func cells(origin: Vector2 = Vector2.ZERO) -> BatchCells:
	return BatchCells.new(
		CELL_WIDTH * ART_SCALE,
		CELL_SLANT * ART_SCALE,
		CELL_HEIGHT * ART_SCALE,
		CELL_MIDDLE * ART_SCALE,
		origin
	)


## Returns empty batch rows on the jam grid. [param world] is the area in
## pixels that holds every cell and every mover.
static func rows(atlas: SpriteAtlas, world: Rect2, origin: Vector2 = Vector2.ZERO) -> BatchRows:
	return BatchRows.new(cells(origin), atlas, world, ART_SCALE)
