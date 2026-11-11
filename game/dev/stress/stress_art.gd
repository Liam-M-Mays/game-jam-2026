class_name StressArt
extends RefCounted
## The static sprites the stress scene and the batch demo draw.
##
## The regions and offsets are the jam game's, from [code]assets/Res/[/code]
## and the scenes in [code]assets/Scenes/[/code]. This is dev art only: the
## real game gets its sprites from each feature's own folder.

## The jam game's sheet with trees, rocks and the first hut.
const STARTER := "res://assets/Art/Environment/Starter_sprites.png"
## A copy of the Town Hall sheet. The original is in ART/, which game files may not use.
const TOWN_HALL := "res://game/dev/stress/art/town_hall.png"
## The sheet that also holds the wood and stone drops.
const HOLDING := "res://game/meeples/art/meeple_holding.png"

## Each kind of static thing: its art file, the part of the file, and the
## offset from the cell to the middle of the sprite in art pixels.
const KINDS: Dictionary[StringName, Dictionary] = {
	&"tree": {"file": STARTER, "region": Rect2i(37, 2, 6, 8), "offset": Vector2(0, -3)},
	&"big_tree": {"file": STARTER, "region": Rect2i(18, 0, 10, 12), "offset": Vector2(3, -5)},
	&"rock": {"file": STARTER, "region": Rect2i(54, 6, 4, 4), "offset": Vector2(0, -1)},
	&"big_rock": {"file": STARTER, "region": Rect2i(67, 5, 10, 6), "offset": Vector2(3, -2)},
	&"hut": {"file": STARTER, "region": Rect2i(82, 1, 12, 10), "offset": Vector2(0, -3)},
	&"town_hall": {"file": TOWN_HALL, "region": Rect2i(64, 0, 16, 32), "offset": Vector2(3, -13)},
	&"wood": {"file": HOLDING, "region": Rect2i(1, 3, 3, 1), "offset": Vector2.ZERO},
	&"stone": {"file": HOLDING, "region": Rect2i(5, 3, 2, 1), "offset": Vector2.ZERO},
}

## The sprite number of each kind, filled by [method add_to].
var sprites: Dictionary[StringName, int] = {}


## Adds every kind to [param atlas]. Call it before the atlas is built.
func add_to(atlas: SpriteAtlas) -> void:
	for kind: StringName in KINDS:
		var entry := KINDS[kind]
		sprites[kind] = atlas.add_file(kind, entry["file"], entry["region"])


## Returns the offset of [param kind], from the cell to the middle of its sprite.
func offset_of(kind: StringName) -> Vector2:
	return KINDS[kind]["offset"]
