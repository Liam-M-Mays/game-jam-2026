extends Node2D
class_name StandingRow
## Draws the still trees and rocks of one grid row in one node.
## It sits at the row's y, so the grid's y-sort still puts it in front of and behind meeples and buildings.
## The look comes from each kind's scene: its texture, scale and offset.

var _items : Array[Standing] = []

func add(item : Standing) -> void:
	_items.append(item)
	queue_redraw()

func remove(item : Standing) -> void:
	if _items.has(item):
		_items.erase(item)
		queue_redraw()

func _draw() -> void:
	for item in _items:
		var look := item.kind.template
		draw_set_transform(item.position - position, 0.0, look.scale)
		draw_texture(look.texture, look.offset - look.texture.get_size() / 2.0)
