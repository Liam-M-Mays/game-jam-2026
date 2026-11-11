# addons/effects/

**What lives here:** the effects toolkit. One place for the outline and the effects of everything in a sprite batch: flash, shake, squash, wobble, pop, grow in, hover glow, selected outline, blueprint ghost, one-shot sprites and lit cells. No game script needs its own tween.

It knows nothing about the game's rules, and it holds no time, distance, colour or size of the game. So it can be tested alone. The shape of each effect is fixed here: see "Limits". It builds on the [sprite batch](../sprite_batch/README.md).

Built by #62. Design: the "Drawing" part of [docs/core-design.md](../../docs/core-design.md).

## The files

| File | What it is |
| --- | --- |
| `sprite_effects.gd` | `SpriteEffects`: the toolkit. Every effect is one call on it |
| `effect_lines.gd` | `EffectLines`: which sprite reads which line of the effect table. `SpriteEffects` extends it |
| `effect_state.gd` | `EffectState`: what is known about one sprite with an effect |
| `effect_table.gd` | `EffectTable`: the small texture of numbers the shader reads |
| `effect_curves.gd` | `EffectCurves`: the curve of each effect, for code with no window |
| `effect_shots.gd` | `EffectShots`: one-shot sprites, such as a spark or a dust cloud |
| `cell_highlights.gd` | `CellHighlights`: lit grid cells, in named layers |
| `effect_style.gd` | `EffectStyle`: the numbers of the effects. A game saves its own in a `.tres` file |
| `effects.gdshaderinc` | The shader part. A batch shader includes it |
| `effects_batch.gdshader` | A ready batch shader for plain sprites with effects |
| `tests/` | The tests. Run them with `bash .github/ci/run_tests.sh --only=addons/effects` |

## Using it

```gdscript
var effects := SpriteEffects.new(rows, style)    # rows: BatchRows, style: EffectStyle
effects.dress(batch)                             # the batch must use a shader with the effects

func _process(delta: float) -> void:
	effects.advance(delta, Game.speed, Game.paused)   # effects run on game time

var tree := SpriteEffects.thing(tree_id)         # a thing of the batch
var meeple := SpriteEffects.mover(meeple_index)  # a mover of the batch

effects.flash(tree)                  # white, fades
effects.reject(tree)                 # red flash and a shake
effects.squash(tree)
effects.wobble(tree)
effects.pop(building)
effects.grow_in(tree)
effects.hover(meeple, true)          # soft glow
effects.select(tree, true)           # solid outline, with a tint if you give one
effects.ghost(preview, true, blocked)                 # the sprite itself as a blueprint ghost
effects.ghost_under(site, next_stage_sprite, blocked) # the next stage as a ghost behind a site
effects.forget(tree)                 # when the sprite leaves the batch
```

- A tree, a building and a meeple are all called the same way.
- The numbers (how long, how far, which colour) come from the `EffectStyle` the game hands in. The toolkit has none of those. The shape of each effect is fixed in the toolkit.
- `squash`, `wobble` and `pop` take an amount of their own as a second value, for a kind that needs another one.
- `flash(target, colour, hold)` stays solid for `hold` seconds before it fades.

## The named slots

Timed effects run in five named slots: flash, shake, squash, wobble, pop.

- A new effect in a slot takes the place of the one running there. Grow in uses the squash slot.
- A flash, a shake and a squash start over. A pop or a wobble that takes over from a running one carries on from the size or the tilt the sprite has. So ten deliveries in a row swell a building once, and do not make it jump. The jam game does the same.
- Effects in different slots play at the same time.
- Squash and pop both change the size. Their sizes are multiplied.

## Game time

- `advance(seconds, speed, paused)` moves the effect clock by `seconds * speed`, and not at all while paused.
- So at x3 an effect takes a third of the time, and nothing moves while the game is paused. One-shots and outline pulses run on the same clock.
- The toolkit does not know the Game service. The view hands in the speed and the pause.

## How an effect reaches the shader

Inside the batch an effect is a value per sprite that the shader reads.

1. A sprite with an effect carries an **effect number**. It is the sprite's extra number in the batch: 32-bit, on a path of its own. The colour and the four shader numbers of a sprite are not used, so a meeple keeps all of them.
2. The effect number is a **line of the effect table**, a small texture. A line is 9 pixels of 4 numbers: what is hovered or selected, the colours, when each timed effect started and how long it runs. The layout is at the top of `effects.gdshaderinc`.
3. The shader works the effect out from that line and from the **effect clock**. No script runs per sprite per frame. A script only runs when an effect starts and when it ends.

- A sprite with no effect carries 0. The shader then changes nothing.
- Sprites that only have lasting values (hovered, selected, ghost), and the same ones, share one line. A thousand selected trees take one line.
- A sprite with a timed effect has a line of its own while the effect runs.
- A start time is written wrapped to 256 seconds, so the numbers stay small however late in the game.
- Squash, wobble and pop turn and stretch a sprite around the point it stands on, not around the middle of its picture.

## A batch shader with effects

`effects_batch.gdshader` is ready for plain sprites. A game shader, such as the meeple shader, includes the effects itself. The steps are at the top of `effects.gdshaderinc`:

- write `effects_shape(local)`: how solid the sprite's own picture is at a point,
- include `effects.gdshaderinc`,
- one call in `vertex()` and one in `fragment()`.

The outline follows the picture of the sprite, is drawn outside the sprite's own box, and keeps its width in screen pixels at every zoom.

## One-shot sprites

```gdscript
effects.shots.play_on(thing_id, frames, 16.0)                               # in front of its own row
effects.shots.play_on(thing_id, frames, 10.0, Vector2(0, 10), BatchRows.OVER)   # over everything
effects.shots.play_on(thing_id, frames, 16.0, Vector2.ZERO, EffectShots.BY_HEIGHT)  # sorted by height
```

- `frames` are sprite numbers of the atlas. They play once, on game time, and take themselves away.
- It plays at the middle of the thing's picture, moved by the offset in art pixels.
- It keeps playing when the thing is taken away.
- `EffectShots.BY_HEIGHT` puts it in the drawing order by the height of its own middle, as a node in a parent that sorts by height would be. The middle of a tree's picture is above the line the tree stands on, so its sparks are behind the things of its own row and in front of the row above. The jam game draws its sparks this way. A middle above the first row of the batch, or below its last, is put on that row.

## Lit cells

```gdscript
var lit := CellHighlights.new(rows, cell_sprite, cell_offset)
lit.show(&"hover", rows.thing_cells(thing_id), grey)
lit.show(&"cursor", CellHighlights.cells_in_circle(rows.cells, corners, mouse, radius), grey, 1)
lit.show(&"area", plot_cells, pale_yellow, 2)
lit.clear(&"hover")
```

- A cell is invisible until a layer lights it. A lit cell is the cell picture in a colour, drawn under everything.
- Showing a layer again replaces what it showed. Where two layers light one cell, the higher rank wins. Give every layer a rank of its own.
- The cell maths comes in from the batch (`BatchCells`), as for picking. The toolkit has no grid numbers.

## Tests and pictures

- `tests/`: the curves, the table and its limit, the lines, game time (x3 and pause), the named slots, one-shots, lit cells, and the values the shader is sent. All with no window.
- A run with no window compiles a shader but draws nothing. So what the shader really draws is proven by pictures next to the jam game: [game/dev/effects_demo/](../../game/dev/effects_demo/README.md). That comparison needs a window. CI does not run it: a person does.

## Limits

- **The extra number rides in a spare place number of the sprite.** Godot calls those two numbers padding and hands them to the shader in the sprite's matrix. Checked on Godot 4.7.2 with the OpenGL renderer. If a later Godot stops doing that, no effect shows any more. Nothing in CI notices that. **Run the comparison scene in `game/dev/effects_demo/` by hand after every Godot upgrade.**
- **The shape of each effect is fixed in the toolkit, in two copies.** The style sets how long, how far and which colour. It does not set the shape: the five steps of a shake (out, across, half out, half across, back), the quarter, half, quarter of a wobble, the springy ease of a squash, the sine ease of a pop, the falloff of the glow, and the 16 directions and 48 pixel reach of the outline. They are the jam game's shapes. Why they are here: a shape is a sum in the shader, and a style can only hand in numbers. One copy is in `effects.gdshaderinc`, the other in `EffectCurves` for tests. A change has to be made in both. No test with no window can see the shader's copy: only the comparison pictures catch a shader that differs.
- The effect table holds 16,383 lines. When it is full, one warning is logged and a new timed effect is not shown. A sprite that is hovered or selected keeps the look it has, also when it asks for another one. A sprite that is short of a line gets one at the next `advance` after a line came free, also while the game is paused. `waiting_count()` says how many are short.
- No effect may run longer than 64 seconds, a quarter of the effect clock. Nothing checks this: only the hold of a flash is cut to it. Past 256 seconds the shader would start the effect again.
- An effect that has just ended keeps its line until the next `advance`.
- Call `forget(target)` when a sprite leaves the batch.
    - A thing number that is used again without it gets none of the old sprite's effects. The same holds for a mover number after `resize_movers`. The old state is dropped at the next call for that number, or when one of its timed effects ends. Until then `has_effect` still says true.
    - One case cannot be told apart: the old sprite was short of a line at a full table. Its state and a new sprite both carry 0. So the new sprite gets the old look when a line comes free.
    - A mover number that is handed to another meeple with `place_mover` keeps its effect number. The new meeple shows the old one's hover or selected outline until `forget`.
- A mover gets no effect before it is placed. The call is refused, as for a sprite that is not in the batch.
- **A sprite is left out by its plain box.** An outline, a squash or a shake reaches outside that box. So it vanishes when the box leaves the screen, not when the outline does. Sideways the batch keeps a margin as wide as its widest thing. Up and down it does not.
- A one-shot that is sorted by height is behind every mover of the band it falls in, also behind the ones that stand higher than its middle.
- Two cell layers with the same rank: which one wins a cell depends on the order of earlier calls. Give every layer a rank of its own.
- The ghost behind a sprite must be a picture of the same size, such as the next frame of the same sheet.
- A pulse speed of the outline is rounded so that a whole number of pulses fits into 256 seconds.
- A long frame is not cut short for the effect clock, as it is for the simulation ticks. After a hitch an effect can be over at once.
