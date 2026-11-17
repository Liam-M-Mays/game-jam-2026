extends Node2D
class_name CellCursor
## Lights the cells around the mouse while a building is being placed.

@export var enabled := true
@export_range(0.0, 1.0) var highlight_alpha := 0.5
@export var radius := 200.0

var grid : Grid

var _lit : Array[Cell] = []

func _process(_delta : float) -> void:
	for cell in _lit:
		cell.highlight(0.0)
	_lit.clear()
	if not enabled or grid == null:
		return
	_lit = grid.cells_near(get_global_mouse_position(), radius)
	for cell in _lit:
		cell.highlight(highlight_alpha)
