class_name WorldThingsLayer
extends VillageViewLayer
## Draws the trees, rocks and bushes the world generator placed.
##
## Each one goes into the batch once, at the start, under the same number the
## village grid knows it by. It reads the rows of [GroundWorld]. Things that
## are chopped or grow back later are the nature part's to draw (#66).

var _sprites := PackedInt32Array()


## Adds the sprite of every kind of tree, rock and bush to [param atlas].
func add_sprites(village: Village, atlas: SpriteAtlas) -> void:
	var world := GroundWorld.of(village)
	if world == null:
		return
	for kind in world.kinds:
		_sprites.append(atlas.add_texture(kind.kind_name, kind.sheet, kind.region))


## Puts every tree, rock and bush of [param village] into the batch.
func start(village: Village, view: VillageView) -> void:
	var world := GroundWorld.of(village)
	if world == null:
		return
	var one_cell: Array[Vector2i] = []
	for row in world.thing_count():
		var kind := world.thing_kind(row)
		var cell := world.thing_cell(row)
		var footprint := one_cell
		if kind.width > 1 or kind.depth > 1:
			footprint = GridLayout.footprint(cell, kind.width, kind.depth)
		var sprite := _sprites[world.thing_kinds[row]]
		view.rows.add_thing(world.thing_ids[row], cell, sprite, kind.offset, Color.WHITE, footprint)


## Lets go of the sprite numbers.
func close() -> void:
	_sprites = PackedInt32Array()
