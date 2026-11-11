class_name BatchTestKit
extends RefCounted
## Helpers the sprite batch tests share: a grid and an atlas made in code, so
## no test needs the game's numbers or an art file, and a reader for the
## buffer that [BatchRows] assembles.

## The grid of the tests. The numbers are the tests' own: a cell is 70 wide,
## each row starts 50 further right and is 50 tall, and one art pixel is 10.
const STEP := 70.0
const SLANT := 50.0
const ROW_HEIGHT := 50.0
const MIDDLE := Vector2(-5.0, 0.0)
const ART_SCALE := 10.0

## A 4 by 4 solid sprite. With [constant SMALL_OFFSET] it is lower than one row.
const SMALL := &"small"
## A 6 by 30 sprite that is six rows tall. Its two left columns are see-through.
const TALL := &"tall"
## A 10 by 4 solid sprite that is wider than one cell.
const WIDE := &"wide"
## The offset that puts a small sprite on its cell like a jam rock.
const SMALL_OFFSET := Vector2(0.0, -1.0)
## The offset that stands a tall sprite on its cell.
const TALL_OFFSET := Vector2(-1.0, -14.0)


## Returns the cell maths of the test grid, with cell (0, 0) at [param origin].
static func cells(origin: Vector2 = Vector2.ZERO) -> BatchCells:
	return BatchCells.new(STEP, SLANT, ROW_HEIGHT, MIDDLE, origin)


## Returns a built atlas with the three test sprites.
static func atlas() -> SpriteAtlas:
	var made := SpriteAtlas.new()
	made.add_image(SMALL, _block(4, 4, Color.RED, 0))
	made.add_image(TALL, _block(6, 30, Color.GREEN, 2))
	made.add_image(WIDE, _block(10, 4, Color.BLUE, 0))
	made.build()
	return made


## Returns the sprites in [param buffer] as one dictionary each: "middle",
## "size", "tint", "sprite" and "numbers".
static func read(buffer: PackedFloat32Array) -> Array[Dictionary]:
	var sprites: Array[Dictionary] = []
	for at in range(0, buffer.size(), BatchRows.FLOATS):
		sprites.append({
			"middle": Vector2(buffer[at + 3], buffer[at + 7]),
			"size": Vector2(buffer[at], buffer[at + 5]),
			"tint": Color(buffer[at + 8], buffer[at + 9], buffer[at + 10], buffer[at + 11]),
			"sprite": int(buffer[at + 12]),
			"numbers": Vector4(buffer[at + 12], buffer[at + 13], buffer[at + 14], buffer[at + 15]),
		})
	return sprites


## Returns a view that is big enough to hold everything.
static func everything() -> Rect2:
	return Rect2(-1e6, -1e6, 2e6, 2e6)


static func _block(width: int, height: int, colour: Color, clear_columns: int) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in range(clear_columns, width):
			image.set_pixel(x, y, colour)
	return image
