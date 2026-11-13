extends RefCounted
class_name Cell
## One spot on the grid, as plain data. The grid's CellLayer draws it while it is lit.

const HIGHLIGHT_COLOR := Color(0.4, 0.4, 0.4)

var position : Vector2
## A GridObject, or the Standing of a tree, rock or bush.
var occupant : Object = null
## The barn that keeps this cell for its farms and silos, a building being moved that keeps its old spot, or null.
var kept_for : Object = null

var _layer : CellLayer

func _init(at : Vector2, layer : CellLayer) -> void:
	position = at
	_layer = layer

## Lights the cell with `color`. An alpha of 0 turns the light off.
func highlight(alpha : float, color := HIGHLIGHT_COLOR) -> void:
	_layer.set_lit(self, Color(color, alpha))
