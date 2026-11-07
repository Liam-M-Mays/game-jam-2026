extends Area2D
class_name CellCursor

@export var enabled := true
@export_range(0.0, 1.0) var highlight_alpha := 0.5

var _lit : Array[Cell] = []

func _process(_delta : float) -> void:
	global_position = get_global_mouse_position()
	for cell in _lit:
		cell.highlight(0.0)
	_lit.clear()
	if not enabled:
		return
	for area in get_overlapping_areas():
		var cell := area.get_parent() as Cell
		if cell != null:
			cell.highlight(highlight_alpha)
			_lit.append(cell)
