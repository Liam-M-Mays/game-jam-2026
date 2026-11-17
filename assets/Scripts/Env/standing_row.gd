extends Node2D
class_name StandingRow
## Draws the still trees, rocks and bushes of one grid row in one node.
## It sits at the row's y, so the grid's y-sort still puts it in front of and behind meeples and buildings.
## The look comes from each kind's scene: its texture, scale and offset, and a bush's fill stage.

var _items : Array[Standing] = []

## Starts drawing `item`.
func add(item : Standing) -> void:
	_items.append(item)
	queue_redraw()

## Stops drawing `item`.
func remove(item : Standing) -> void:
	if _items.has(item):
		_items.erase(item)
		queue_redraw()

func _draw() -> void:
	for item in _items:
		var look := item.kind.template
		var texture := look.texture_for(item)
		draw_set_transform(item.position - position, 0.0, look.scale)
		draw_texture(texture, look.offset - texture.get_size() / 2.0)
