class_name JamEffects
extends RefCounted
## The jam game's effect numbers and effect art, in one place.
##
## The effects toolkit in [code]addons/effects/[/code] holds no number of the
## game. The demo, the comparison scene and the tests take the game's numbers
## from here. Most of them are saved in [code]jam_effect_style.tres[/code],
## next to this file: open it in the Inspector to change one.
##
## This is a stand-in, like [JamGrid]. The numbers need a home outside
## [code]game/dev/[/code] once the first view of the real game uses them.
##
## Where each number comes from in the jam game: grid_object.gd (flash,
## shake, hover cells), harvestable.gd (squash, wobble, grow in, break hold),
## building.gd (pop, ghost, paused outline), build_system.gd (plot cells),
## the shader globals in project.godot (outline looks), and the two scenes
## in assets/Scenes/Effects.

## The saved effect numbers of the jam game.
const STYLE_PATH := "res://game/dev/effects_demo/jam_effect_style.tres"
## The picture of one grid cell: a white outline.
const CELL_ART := "res://assets/Art/Environment/Grid_outline.png"
## From a cell's position to the middle of the cell picture, in art pixels.
const CELL_OFFSET := Vector2(-0.5, 0.0)
## The outline of one cell, as points around the cell's position, in art pixels.
const CELL_CORNERS: Array[Vector2] = [
	Vector2(4.0, 2.0), Vector2(4.0, 1.0), Vector2(1.0, -2.0),
	Vector2(-5.0, -2.0), Vector2(-5.0, -1.0), Vector2(-2.0, 2.0),
]
## How far round the mouse the cells light up while placing, in art pixels.
const CURSOR_RADIUS := 20.0
## Which highlight wins a cell: a higher rank wins.
const RANK_HOVER := 0
const RANK_CURSOR := 1
const RANK_AREA := 2
const RANK_AREA_HOVER := 3
## The spark burst where a tree, rock or bush breaks. A copy of the sheet in
## ART/, which game files may not use.
const SPARK_ART := "res://game/dev/effects_demo/art/spark.png"
## The size of one spark picture, in art pixels.
const SPARK_SIZE := Vector2i(13, 13)
## How many spark pictures there are, and how many are shown a second.
const SPARK_FRAMES := 3
const SPARK_RATE := 16.0
## The dust cloud over a building that was just finished.
const CLOUD_ART := "res://assets/Art/Environment/Cloud_Spritesheet.png"
## The size of one cloud picture, in art pixels.
const CLOUD_SIZE := Vector2i(18, 14)
## How many cloud pictures there are, and how many are shown a second.
const CLOUD_FRAMES := 3
const CLOUD_RATE := 10.0
## The outline colour of a building site the player has paused.
const PAUSED_OUTLINE := Color(1.0, 0.85, 0.1)
## A thing that breaks stays white for this many seconds before it is gone.
const BREAK_HOLD := 0.06

## The sprite number of the cell picture, filled by [method add_to].
var cell_sprite: int = SpriteAtlas.NO_SPRITE
## The sprite numbers of the spark pictures.
var spark_sprites := PackedInt32Array()
## The sprite numbers of the cloud pictures.
var cloud_sprites := PackedInt32Array()


## Returns the saved effect numbers of the jam game.
static func style() -> EffectStyle:
	return load(STYLE_PATH) as EffectStyle


## Returns the outline of one cell in pixels at zoom 1, for
## [method CellHighlights.cells_in_circle]. [param art_scale] is how many
## pixels one art pixel takes.
static func cell_corners(art_scale: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for corner in CELL_CORNERS:
		corners.append(corner * art_scale)
	return corners


## Adds the cell picture, the sparks and the cloud to [param atlas]. Call it
## before the atlas is built.
func add_to(atlas: SpriteAtlas) -> void:
	cell_sprite = atlas.add_file(&"cell_outline", CELL_ART)
	spark_sprites = _strip(atlas, "spark", SPARK_ART, SPARK_SIZE, SPARK_FRAMES)
	cloud_sprites = _strip(atlas, "cloud", CLOUD_ART, CLOUD_SIZE, CLOUD_FRAMES)


## Returns cell highlights that draw the jam game's cell picture in [param rows].
func cell_highlights(rows: BatchRows) -> CellHighlights:
	return CellHighlights.new(rows, cell_sprite, CELL_OFFSET)


## A hit that does not break the thing: it squashes, flashes white and wobbles.
func hit(effects: SpriteEffects, target: int) -> void:
	effects.squash(target)
	effects.flash(target)
	effects.wobble(target)


## The hit that breaks the thing: it squashes and stays white until the
## game takes it away, [constant BREAK_HOLD] seconds later.
func last_hit(effects: SpriteEffects, target: int) -> void:
	effects.squash(target)
	effects.flash(target, Color.WHITE, BREAK_HOLD)


## Plays the spark burst at the middle of the thing [param id], in front of
## its own row.
func sparks(effects: SpriteEffects, id: int) -> int:
	return effects.shots.play_on(id, spark_sprites, SPARK_RATE)


## Plays the dust cloud at the middle of the thing [param id], over
## everything. [param effect_offset] moves it, in art pixels: the jam Town
## Hall moves it 10 down.
func cloud(effects: SpriteEffects, id: int, effect_offset: Vector2 = Vector2.ZERO) -> int:
	return effects.shots.play_on(id, cloud_sprites, CLOUD_RATE, effect_offset, BatchStore.OVER)


func _strip(
		atlas: SpriteAtlas, sprite_name: String, path: String, size: Vector2i, count: int
) -> PackedInt32Array:
	var sprites := PackedInt32Array()
	for frame in count:
		var region := Rect2i(Vector2i(frame * size.x, 0), size)
		sprites.append(atlas.add_file("%s_%d" % [sprite_name, frame], path, region))
	return sprites
