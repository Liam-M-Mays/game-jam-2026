class_name MeepleLook
extends RefCounted
## How a meeple is drawn in the sprite batch.
##
## Every number here is the jam game's, from
## [code]assets/Scenes/Meeple/meeple.tscn[/code] and
## [code]assets/Scripts/Meeple/meeple_movement.gd[/code]. The shader that uses
## them is [code]meeple_batch.gdshader[/code], next to this file.
##
## Use it like this: [method add_to] before the atlas is built,
## [method shape] on the rows, [method dress] on the batch, and then
## [method numbers] for each meeple that is placed.

## The shader that draws a village batch: plain sprites and meeples.
const SHADER := preload("res://game/meeples/view/meeple_batch.gdshader")
## Where the meeple art is.
const ART := "res://game/meeples/art/"
## The body is the 1 by 2 pixel shirt.
const BODY := {"file": "meeple.png", "region": Rect2i(1, 2, 1, 2)}
## The head pictures, by the head frame number of the jam game.
## Frame 1 is in the jam scene but nothing ever shows it.
const HEADS: Array[Dictionary] = [
	{"file": "meeple.png", "region": Rect2i(0, 0, 3, 2)},
	{"file": "meeple_holding.png", "region": Rect2i(1, 4, 3, 2)},
	{"file": "meeple_holding.png", "region": Rect2i(1, 3, 3, 3)},
	{"file": "meeple_holding.png", "region": Rect2i(1, 2, 3, 4)},
	{"file": "meeple_holding_more.png", "region": Rect2i(5, 2, 3, 4)},
	{"file": "meeple_holding_more.png", "region": Rect2i(9, 2, 3, 4)},
]
## The head frame of a meeple that carries nothing.
const EMPTY_HANDED := 0
## The head frame for one piece of a resource.
const CARRY_FRAMES: Dictionary[StringName, int] = {&"wood": 2, &"stone": 4}
## The head frame for two or more pieces of a resource.
const DOUBLE_CARRY_FRAMES: Dictionary[StringName, int] = {&"wood": 3, &"stone": 5}
## How far the head is lifted for one piece, in art pixels.
const CARRY_LIFT := 0.5
## How far the head is lifted for two or more pieces, in art pixels.
const DOUBLE_CARRY_LIFT := 1.0
## The head keeps this off-white. Only the body takes the shirt colour.
const HEAD_TINT := Color(0.9054981, 0.91442734, 0.909581)
## The saturation of a shirt colour.
const SHIRT_SATURATION := 0.8
## The brightness of a shirt colour.
const SHIRT_VALUE := 0.9
## The box one meeple is painted into, in art pixels.
const BOX := Vector2(3.0, 6.0)
## From the meeple's position, the middle of its body, to the middle of the
## box, in art pixels.
const BOX_OFFSET := Vector2(0.0, -2.0)
## How far bounce and tilt move the picture out of its box, in art pixels.
const BOX_SLACK := 1.0
## The fourth shader number of a meeple that stands.
const STANDING := 1.0
## The fourth shader number of a meeple that walks.
const WALKING := 2.0
## The fourth shader number of a meeple that is dying. Its second number is
## then how far it has tipped over, and no longer its bounce start.
const DYING := 3.0
## A dying meeple tips over around its feet: this far below the middle of its
## body, in art pixels.
const FEET_BELOW := 1.0
## The jam game counts its bounce time in milliseconds divided by 60. This
## turns seconds into that time.
const CLOCK_RATE := 1000.0 / 60.0
## How much taller and shorter a walking meeple gets: 0.1 is 10 percent each
## way. A standing meeple breathes with half of it.
const STRETCH := 0.1
## How fast the stretch goes, in bounce time.
const STRETCH_SPEED := 0.25
## How far a walking meeple rocks to each side, in degrees. A standing one does not rock.
const WOBBLE_DEGREES := 10.0
## How fast the rocking goes, in bounce time.
const WOBBLE_SPEED := 1.5
## Bounce starts are picked from 0 to this. It is one full stretch cycle.
const PHASE_RANGE := TAU / STRETCH_SPEED
## The batch clock starts again after this many seconds: one full stretch,
## which is six full rocks. So no meeple jumps when it does, and the shader
## only ever counts with small numbers, which keeps the bounce exact.
const CLOCK_WRAP := TAU / (CLOCK_RATE * STRETCH_SPEED)

## The sprite number of the body.
var body_sprite: int = SpriteAtlas.NO_SPRITE
## The sprite number of each head frame.
var head_sprites := PackedInt32Array()


## Returns the head frame for a meeple that carries [param amount] pieces of
## [param kind]: wood 2, two wood 3, stone 4, two stone 5, nothing 0.
static func head_frame(kind: StringName, amount: int) -> int:
	if amount <= 0:
		return EMPTY_HANDED
	if amount >= 2 and DOUBLE_CARRY_FRAMES.has(kind):
		return DOUBLE_CARRY_FRAMES[kind]
	return CARRY_FRAMES.get(kind, EMPTY_HANDED)


## Returns how far the head is lifted for [param frame], in art pixels.
static func head_lift(frame: int) -> float:
	if DOUBLE_CARRY_FRAMES.values().has(frame):
		return DOUBLE_CARRY_LIFT
	if CARRY_FRAMES.values().has(frame):
		return CARRY_LIFT
	return 0.0


## Returns the shirt colour for [param hue], 0 to 1. A new meeple gets a random hue.
static func shirt_colour(hue: float) -> Color:
	return Color.from_hsv(hue, SHIRT_SATURATION, SHIRT_VALUE)


## Returns the pose of a meeple at [param clock] seconds: x is how tall it is
## against its resting height, y is its tilt in degrees. [param phase] is
## where its bounce starts. The shader works out the same thing for every
## meeple on screen. This copy is here so a test can check the numbers.
static func pose(clock: float, phase: float, walking: bool) -> Vector2:
	var t := clock * CLOCK_RATE + phase
	var tall := 1.0 + sin(t * STRETCH_SPEED) * STRETCH * (1.0 if walking else 0.5)
	return Vector2(tall, sin(t * WOBBLE_SPEED) * WOBBLE_DEGREES if walking else 0.0)


## Adds the body and the head pictures to [param atlas]. Call it before the
## atlas is built.
func add_to(atlas: SpriteAtlas) -> void:
	body_sprite = atlas.add_file(&"meeple_body", ART + BODY["file"], BODY["region"])
	head_sprites.clear()
	for frame in HEADS.size():
		var head := HEADS[frame]
		var sprite_name := "meeple_head_%d" % frame
		head_sprites.append(atlas.add_file(sprite_name, ART + head["file"], head["region"]))


## Tells [param rows] how big a meeple is, so it knows when one is on screen.
func shape(rows: BatchRows) -> void:
	var scale := rows.pixel_scale
	rows.shape_movers(BOX * scale, BOX_OFFSET * scale, BOX_SLACK * scale)


## Gives [param batch] what the meeple shader needs. The batch must have been
## set up with [constant SHADER].
func dress(batch: SpriteBatch) -> void:
	batch.clock_wrap = CLOCK_WRAP
	var material := batch.material()
	material.set_shader_parameter(&"meeple_body", float(body_sprite))
	material.set_shader_parameter(&"meeple_head_tint", HEAD_TINT)
	material.set_shader_parameter(&"meeple_clock_rate", CLOCK_RATE)
	material.set_shader_parameter(&"meeple_stretch", STRETCH)
	material.set_shader_parameter(&"meeple_stretch_speed", STRETCH_SPEED)
	material.set_shader_parameter(&"meeple_wobble_degrees", WOBBLE_DEGREES)
	material.set_shader_parameter(&"meeple_wobble_speed", WOBBLE_SPEED)


## Returns the four shader numbers of one meeple: its head picture, where its
## bounce starts, how far its head is lifted, and whether it walks.
func numbers(frame: int, phase: float, walking: bool) -> Vector4:
	return Vector4(
		float(head_sprites[frame]), phase, head_lift(frame), WALKING if walking else STANDING
	)


## Returns the four shader numbers of a dying meeple: its head picture, how
## far it has tipped over in radians (above zero is to the right), how far its
## head is lifted, and the dying mark. It does not bounce. Its fade is the
## alpha of its colour.
func dying_numbers(frame: int, topple: float) -> Vector4:
	return Vector4(float(head_sprites[frame]), topple, head_lift(frame), DYING)
