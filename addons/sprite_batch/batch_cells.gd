class_name BatchCells
extends RefCounted
## The cell maths the sprite batch works with.
##
## It answers two questions: where is a cell, and which cell is a point in.
## The batch has no grid numbers of its own. The game hands them in when it
## makes this object, and they cannot be changed afterwards: the batch works
## the places of its sprites out once, from these numbers.
##
## The grid is slanted: every row starts a bit further right than the row
## above it. All numbers are in pixels at zoom 1.
##
## A game with another kind of grid extends this class and overrides
## [method position_of] and [method cell_at]. Rows must stay level lines that
## are [member row_height] apart.

## How far one step along a row moves a cell.
var step_x: float:
	get:
		return _step_x
## How far one step to the next row moves a cell sideways. This is the slant.
var slant_x: float:
	get:
		return _slant_x
## The distance between two rows.
var row_height: float:
	get:
		return _row_height
## From a cell's position to the middle of the area that counts as that cell.
var middle: Vector2:
	get:
		return _middle
## Where cell (0, 0) is.
var origin: Vector2:
	get:
		return _origin

var _step_x: float
var _slant_x: float
var _row_height: float
var _middle: Vector2
var _origin: Vector2


## All five numbers are needed. See the members of the same names.
func _init(
		step: float, slant: float, height: float, cell_middle: Vector2, cell_origin: Vector2
) -> void:
	_step_x = step
	_slant_x = slant
	_row_height = height
	_middle = cell_middle
	_origin = cell_origin


## Returns where [param cell] is. Things on the cell stand on this point.
func position_of(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell.x * _step_x + cell.y * _slant_x, cell.y * _row_height)


## Returns the cell that [param point] is in. A point exactly between two
## cells goes to the cell on the right, or to the cell below.
func cell_at(point: Vector2) -> Vector2i:
	var local := point - _origin - _middle
	var row := floori(local.y / _row_height + 0.5)
	return Vector2i(floori((local.x - row * _slant_x) / _step_x + 0.5), row)


## Returns the grid row of [param cell]. Everything in one row is on one level line.
func row_of(cell: Vector2i) -> int:
	return cell.y


## Returns the height of the line that the things of [param row] stand on.
func row_y(row: int) -> float:
	return _origin.y + row * _row_height


## Returns the row whose band holds the height [param y]. The band of a row
## starts at its line and ends at the line of the next row. A mover in that
## band is drawn in front of the row and behind the next one.
func band_at(y: float) -> int:
	return floori((y - _origin.y) / _row_height)
