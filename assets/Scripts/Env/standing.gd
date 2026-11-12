extends RefCounted
class_name Standing
## A tree or rock on the grid, as plain data held by its cells.
## While it is still, the StandingRow of its row draws it. While it is hovered, hit, chosen or
## growing, Grid gives it its real scene in `node`, so the outline, wobble and flash work as before.

var kind : Grid.Spawnable
var cells : Array[Cell] = []
var position : Vector2
var wobbles := 0
var node : Harvestable = null

func is_free() -> bool:
	if node != null:
		return node.is_free()
	return wobbles < kind.template.wobbles_to_break
