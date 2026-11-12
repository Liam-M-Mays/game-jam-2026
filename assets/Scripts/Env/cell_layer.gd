extends Node2D
class_name CellLayer
## Draws every lit cell of a grid in one node, below the buildings and trees.
## The look comes from cell.tscn: its texture, scale and offset.

var _texture : Texture2D
var _scale : Vector2
var _corner : Vector2
var _lit := {}

func _init(look : Sprite2D) -> void:
	name = "CellLayer"
	_texture = look.texture
	_scale = look.scale
	_corner = look.offset - _texture.get_size() / 2.0

func set_lit(cell : Cell, color : Color) -> void:
	if color.a <= 0.0:
		if _lit.erase(cell):
			queue_redraw()
	elif not _lit.has(cell) or _lit[cell] != color:
		_lit[cell] = color
		queue_redraw()

func _draw() -> void:
	for cell : Cell in _lit:
		draw_set_transform(cell.position, 0.0, _scale)
		draw_texture(_texture, _corner, _lit[cell])
