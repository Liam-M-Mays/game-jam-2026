class_name CellHighlights
extends RefCounted
## Lights up grid cells in a sprite batch.
##
## A cell is invisible until something highlights it. A highlight is the
## cell picture in a colour: the alpha of the colour is its strength. The
## lit cells are drawn under everything else in the batch.
##
## Highlights are kept in named layers, such as "the cells under the hovered
## thing" and "the cells round the mouse". Showing a layer again replaces
## what it showed before. Where two layers light the same cell, the layer
## with the higher rank wins.
##
## The grid numbers are not known here. Where a cell is comes from the cell
## maths of the batch ([BatchCells]), which the game hands in.

var _rows: BatchRows
var _sprite: int
var _offset: Vector2
var _layers: Dictionary[StringName, Dictionary] = {}
var _lit: Dictionary[Vector2i, int] = {}
var _colours: Dictionary[Vector2i, Color] = {}


## [param batch_rows] is the batch the cells are drawn in. [param cell_sprite]
## is the picture of one cell, and [param cell_offset] goes from a cell's
## position to the middle of that picture, in art pixels.
func _init(batch_rows: BatchRows, cell_sprite: int, cell_offset: Vector2 = Vector2.ZERO) -> void:
	_rows = batch_rows
	_sprite = cell_sprite
	_offset = cell_offset


## Lights up [param cells] in [param colour] as the layer [param layer]. The
## cells the layer lit before go dark. A layer with a higher [param rank]
## wins a cell from a layer with a lower one.
func show(layer: StringName, cells: Array[Vector2i], colour: Color, rank: int = 0) -> void:
	var touched: Dictionary[Vector2i, bool] = {}
	if _layers.has(layer):
		for cell: Vector2i in _layers[layer]["cells"]:
			touched[cell] = true
	var now: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		now[cell] = true
		touched[cell] = true
	if now.is_empty():
		_layers.erase(layer)
	else:
		_layers[layer] = {"cells": now, "colour": colour, "rank": rank}
	for cell: Vector2i in touched:
		_update(cell)


## Makes every cell of the layer [param layer] go dark.
func clear(layer: StringName) -> void:
	show(layer, [], Color.WHITE)


## Makes every cell of every layer go dark.
func clear_all() -> void:
	for layer: StringName in _layers.keys():
		clear(layer)


## Returns the colour [param cell] is lit in. A dark cell is see-through
## black: its alpha is 0.
func colour_of(cell: Vector2i) -> Color:
	return _colours.get(cell, Color(0.0, 0.0, 0.0, 0.0))


## Returns how many cells are lit.
func lit_count() -> int:
	return _lit.size()


## Returns the cells whose outline touches the circle round [param centre]
## with [param radius], both in pixels at zoom 1. [param corners] is the
## outline of one cell, as points around the cell's position.
## The game uses it for the cells round the mouse while placing.
static func cells_in_circle(
		cell_maths: BatchCells, corners: PackedVector2Array, centre: Vector2, radius: float
) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if corners.is_empty() or radius < 0.0:
		return found
	var reach := 0.0
	for corner in corners:
		reach = maxf(reach, corner.length())
	var top := cell_maths.cell_at(centre - Vector2(0.0, radius + reach)).y - 1
	var bottom := cell_maths.cell_at(centre + Vector2(0.0, radius + reach)).y + 1
	for row in range(top, bottom + 1):
		var height := cell_maths.position_of(Vector2i(0, row)).y
		var left := cell_maths.cell_at(Vector2(centre.x - radius - reach, height)).x - 1
		var right := cell_maths.cell_at(Vector2(centre.x + radius + reach, height)).x + 1
		for column in range(left, right + 1):
			var cell := Vector2i(column, row)
			if _outline_touches(cell_maths.position_of(cell), corners, centre, radius):
				found.append(cell)
	return found


## True when the circle touches the outline that stands on [param at]: the
## centre is inside the outline, or closer to one of its sides than the radius.
static func _outline_touches(
		at: Vector2, corners: PackedVector2Array, centre: Vector2, radius: float
) -> bool:
	var point := centre - at
	if Geometry2D.is_point_in_polygon(point, corners):
		return true
	for index in corners.size():
		var from := corners[index]
		var to := corners[(index + 1) % corners.size()]
		var closest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if point.distance_to(closest) <= radius:
			return true
	return false


## Works out again which layer lights [param cell], and draws that.
func _update(cell: Vector2i) -> void:
	var best_rank := 0
	var found := false
	var colour := Color.WHITE
	for layer: StringName in _layers:
		var entry := _layers[layer]
		var cells: Dictionary = entry["cells"]
		var rank: int = entry["rank"]
		if cells.has(cell) and (not found or rank >= best_rank):
			found = true
			best_rank = rank
			colour = entry["colour"]
	if not found:
		if _lit.has(cell):
			_rows.remove_decor(_lit[cell])
			_lit.erase(cell)
			_colours.erase(cell)
		return
	if _colours.get(cell) == colour:
		return
	if _lit.has(cell):
		_rows.tint_decor(_lit[cell], colour)
	else:
		var decor := _rows.add_decor(cell, _sprite, _offset, colour, BatchRows.UNDER)
		if decor == BatchRows.NO_DECOR:
			return
		_lit[cell] = decor
	_colours[cell] = colour
