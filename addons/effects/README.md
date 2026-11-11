# addons/effects/

**What lives here:** the effects toolkit. One place for the outline and the effects of everything in a sprite batch: flash, shake, squash, wobble, pop, grow in, hover glow, selected outline, blueprint ghost, one-shot sprites and lit cells. No game script needs its own tween.

It knows nothing about the game's rules or numbers, so it can be tested alone. It builds on the [sprite batch](../sprite_batch/README.md).

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
- The numbers (how long, how far, which colour) come from the `EffectStyle` the game hands in. The toolkit has none of its own.
- `squash`, `wobble` and `pop` take an amount of their own as a second value, for a kind that needs another one.
- `flash(target, colour, hold)` stays solid for `hold` seconds before it fades.

## The named slots

Timed effects run in five named slots: flash, shake, squash, wobble, pop.

- A new effect in a slot takes the place of the one running there. Grow in uses the squash slot.
- Effects in different slots play at the same time.
- Squash and pop both change the size. Their sizes are multiplied.

## Game time

- `advance(seconds, speed, paused)` moves the effect clock by `seconds * speed`, and not at all while paused.
- So at x3 an effect takes a third of the time, and nothing moves while the game is paused. One-shots and outline pulses run on the same clock.
- The toolkit does not know the Game service. The view hands in the speed and the pause.

## How an effect reaches the shader

Inside the batch an effect is a value per sprite that the shader reads.

1. A sprite with an effect carries an **effect number**. It is the sprite's extra number in the batch: 32-bit, on a path of its own. The colour and the four shader numbers of a sprite are not used, so a meeple keeps all of them.
2. The effect number is a **line of the effect table**, a small texture. A line is 8 pixels of 4 numbers: what is hovered or selected, the colours, when each timed effect started and how long it runs. The layout is at the top of `effects.gdshaderinc`.
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
```

- `frames` are sprite numbers of the atlas. They play once, on game time, and take themselves away.
- It plays at the middle of the thing's picture, moved by the offset in art pixels.
- It keeps playing when the thing is taken away.

## Lit cells

```gdscript
var lit := CellHighlights.new(rows, cell_sprite, cell_offset)
lit.show(&"hover", rows.thing_cells(thing_id), grey)
lit.show(&"cursor", CellHighlights.cells_in_circle(rows.cells, corners, mouse, radius), grey, 1)
lit.show(&"area", plot_cells, pale_yellow, 2)
lit.clear(&"hover")
```

- A cell is invisible until a layer lights it. A lit cell is the cell picture in a colour, drawn under everything.
- Showing a layer again replaces what it showed. Where two layers light one cell, the higher rank wins.
- The cell maths comes in from the batch (`BatchCells`), as for picking. The toolkit has no grid numbers.

## Tests and pictures

- `tests/`: the curves, the table, the lines, game time (x3 and pause), the named slots, one-shots and lit cells. All with no window.
- What the shader really draws is proven by pictures next to the jam game: [game/dev/effects_demo/](../../game/dev/effects_demo/README.md).

## Limits

- **The extra number rides in a spare place number of the sprite.** Godot calls those two numbers padding and hands them to the shader in the sprite's matrix. Checked on Godot 4.7.2 with the OpenGL renderer. If a later Godot stops doing that, no effect shows any more, and the comparison scene in `game/dev/effects_demo/` fails.
- The effect table holds 16,383 lines. When it is full, a new effect is not shown and one warning is logged.
- No effect may run longer than 64 seconds, a quarter of the effect clock.
- An effect that has just ended keeps its line until the next `advance`.
- Call `forget(target)` when a sprite leaves the batch. A timed effect ends by itself, but a lasting one (hovered, selected, ghost) stays in the toolkit's books, and a mover number that is used again would show it.
- The ghost behind a sprite must be a picture of the same size, such as the next frame of the same sheet.
- A pulse speed of the outline is rounded so that a whole number of pulses fits into 256 seconds.
- `EffectCurves` is a copy of the curves in the shader, for tests. A change to a curve has to be made in both. The comparison pictures catch a shader that differs.
- A long frame is not cut short for the effect clock, as it is for the simulation ticks. After a hitch an effect can be over at once.
