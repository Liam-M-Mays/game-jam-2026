class_name VillageView
extends Node2D
## The picture of one village: it joins a [Village] to a [SpriteBatch].
##
## Add it to the scene and call [method attach]. It builds one atlas and one
## batch, and hands them to its layers. A layer is one part of the picture:
## the ground, the trees, the drops, the meeples. The picture only reads the
## village. A village with no picture runs the same.
##
## Positions of the village are in art pixels. This node draws them
## [constant ART_SCALE] times as big: use [method to_pixels].

## How many pixels one art pixel takes at zoom 1. The jam game drew its art
## at 10 times its size too.
const ART_SCALE := 10.0
## Extra room round the cells for meeples and tall sprites, in art pixels.
const MARGIN := 16.0

## The village this picture shows, or null.
var village: Village
## The one image that holds every sprite of the village.
var atlas: SpriteAtlas
## The sprites of the village, in drawing order.
var rows: BatchRows
## The node that draws [member rows].
var batch: SpriteBatch

var _layers: Array[VillageViewLayer] = []


## The cell maths of the village grid, in the pixels the batch works in.
static func batch_cells() -> BatchCells:
	return BatchCells.new(
		GridLayout.CELL_WIDTH * ART_SCALE,
		GridLayout.ROW_SHIFT * ART_SCALE,
		GridLayout.ROW_HEIGHT * ART_SCALE,
		GridLayout.CELL_MIDDLE * ART_SCALE,
		Vector2.ZERO
	)


## Turns a position in art pixels into a position in this node's pixels.
static func to_pixels(art_point: Vector2) -> Vector2:
	return art_point * ART_SCALE


## Turns a position in this node's pixels into art pixels.
static func to_art(pixel_point: Vector2) -> Vector2:
	return pixel_point / ART_SCALE


func _process(_delta: float) -> void:
	for layer in _layers:
		layer.update(village, self)


func _exit_tree() -> void:
	detach()


## Starts showing [param new_village] with [param layers].
## [param bounds] is the area that holds every cell, in art pixels.
## Returns false, and does nothing, when the picture already shows a village.
func attach(new_village: Village, bounds: Rect2, layers: Array[VillageViewLayer]) -> bool:
	if village != null or new_village == null:
		return false
	village = new_village
	_layers = layers.duplicate()
	atlas = SpriteAtlas.new()
	var shader: Shader = null
	for layer in _layers:
		layer.add_sprites(village, atlas)
		if shader == null:
			shader = layer.shader()
	atlas.build()
	var area := Rect2(to_pixels(bounds.position), to_pixels(bounds.size))
	rows = BatchRows.new(batch_cells(), atlas, area.grow(MARGIN * ART_SCALE), ART_SCALE)
	batch = SpriteBatch.new()
	batch.setup(rows, shader)
	add_child(batch)
	for layer in _layers:
		layer.start(village, self)
	return true


## Takes the picture off its village and frees what it built. The village is
## not touched.
func detach() -> void:
	if village == null:
		return
	for index in range(_layers.size() - 1, -1, -1):
		_layers[index].close()
	_layers.clear()
	for child in get_children():
		child.queue_free()
	village = null
	batch = null
	rows = null
	atlas = null


## Adds [param node] behind the batch, such as the ground.
func add_under(node: Node) -> void:
	add_child(node)
	move_child(node, batch.get_index())


## Adds [param node] in front of the batch.
func add_over(node: Node) -> void:
	add_child(node)


## How many layers the picture has.
func layer_count() -> int:
	return _layers.size()
