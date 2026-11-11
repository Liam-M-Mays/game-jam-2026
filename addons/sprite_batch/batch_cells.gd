class_name BatchCells
extends RefCounted
## The cell maths the sprite batch works with.
##
## It answers two questions: where is a cell, and which cell is a point in.
## The numbers below are the slanted six-neighbour grid of the jam game
## ([code]assets/Scripts/Env/grid.gd[/code], [code]_cell_position[/code] and
## [code]_coords_at[/code]). All of them are in pixels at zoom 1.
##
## The batch only needs this class, not a real grid. To use another grid, set
## the numbers, or extend this class and override [method position_of] and
## [method cell_at]. Rows must stay level lines that are [member row_height]
## apart.

## How far one step along a row moves a cell. The jam cell is 7 art pixels wide.
var step_x: float = 70.0
## How far one step to the next row moves a cell sideways. This is the slant.
var slant_x: float = 50.0
## The distance between two rows. The jam cell is 5 art pixels tall.
var row_height: float = 50.0
## Where cell (0, 0) is.
var origin: Vector2 = Vector2.ZERO
## From a cell's position to the middle of the area that counts as that cell.
## The jam cell picture sits half an art pixel to the left.
var middle: Vector2 = Vector2(-5.0, 0.0)


## Returns where [param cell] is. Things on the cell stand on this point.
func position_of(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell.x * step_x + cell.y * slant_x, cell.y * row_height)


## Returns the cell that [param point] is in.
func cell_at(point: Vector2) -> Vector2i:
	var local := point - origin - middle
	var row := roundi(local.y / row_height)
	return Vector2i(roundi((local.x - row * slant_x) / step_x), row)


## Returns the grid row of [param cell]. Everything in one row is on one level line.
func row_of(cell: Vector2i) -> int:
	return cell.y


## Returns the height of the line that the things of [param row] stand on.
func row_y(row: int) -> float:
	return origin.y + row * row_height


## Returns the row whose band holds the height [param y]. The band of a row
## starts at its line and ends at the line of the next row. A mover in that
## band is drawn in front of the row and behind the next one.
func band_at(y: float) -> int:
	return floori((y - origin.y) / row_height)
