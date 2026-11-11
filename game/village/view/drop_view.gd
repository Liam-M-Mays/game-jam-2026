class_name DropView
extends RefCounted
## Draws the drops that lie on the ground of a village with the sprite batch,
## each on the spot where it lies.
##
## A drop is a thing in the batch, in the grid row of its cell. This class
## only reads the simulation: it follows [signal GridDrops.added] and
## [signal GridDrops.removed].
## [codeblock]
## var sprites := DropView.add_sprites(atlas, kinds)   # before atlas.build()
## var view := DropView.new(rows, sprites)
## view.watch(village.grid.drops)
## [/codeblock]
## The batch names a thing by a number. The things on the grid use the ids of
## the village, which start at 1. A drop uses a number below zero, so the two
## never clash: see [method thing_of].

## The thing number of the drop in row 0. -1 means "no thing" in the batch.
const FIRST_THING := -2

var _rows: BatchRows
var _sprites: Dictionary[int, int]
var _drops: GridDrops = null


## [param rows] are the rows of the village's batch. [param sprites] is what
## [method add_sprites] gave back.
func _init(rows: BatchRows, sprites: Dictionary[int, int]) -> void:
	_rows = rows
	_sprites = sprites


## Adds the picture of every item kind in [param kinds] to [param atlas], and
## returns the sprite number of each kind number. Call it before the atlas is
## built.
static func add_sprites(atlas: SpriteAtlas, kinds: Array[ResourceKind]) -> Dictionary[int, int]:
	var sprites: Dictionary[int, int] = {}
	for kind in kinds:
		if kind.is_item and kind.sprite_file != "":
			var sprite_name := StringName("drop_%s" % kind.id)
			sprites[kind.number] = atlas.add_file(sprite_name, kind.sprite_file, kind.sprite_region)
	return sprites


## The number the batch knows the drop in row [param drop] by.
static func thing_of(drop: int) -> int:
	return FIRST_THING - drop


## The row of the drop the batch knows as [param thing], or
## [constant GridDrops.NO_DROP] when the thing is not a drop.
static func drop_of(thing: int) -> int:
	return FIRST_THING - thing if thing <= FIRST_THING else GridDrops.NO_DROP


## Draws every drop that lies on [param drops] now, and follows the ones that
## come and go from here on.
func watch(drops: GridDrops) -> void:
	stop()
	_drops = drops
	for drop in drops.size():
		if drops.has(drop):
			_show(drop, drops.kind_of(drop))
	drops.added.connect(_show)
	drops.removed.connect(_hide)


## Takes every drop out of the batch and stops following the ground.
func stop() -> void:
	if _drops == null:
		return
	_drops.added.disconnect(_show)
	_drops.removed.disconnect(_hide)
	for drop in _drops.size():
		_rows.remove_thing(thing_of(drop))
	_drops = null


## Puts the sprite of a drop into the batch, with its middle on the spot of
## the drop.
func _show(drop: int, kind: int) -> void:
	if not _sprites.has(kind):
		return
	var cell := _drops.cell_of(drop)
	var scale := _rows.pixel_scale
	var spot := _rows.cells.origin + _drops.spot_of(drop) * scale
	var from_cell := (spot - _rows.cells.position_of(cell)) / scale
	_rows.add_thing(thing_of(drop), cell, _sprites[kind], from_cell)


func _hide(drop: int, _kind: int) -> void:
	_rows.remove_thing(thing_of(drop))
