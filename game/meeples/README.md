# game/meeples/

**What lives here:** meeples as rows of data, the rules that move them, and the meeple shader.

- `view/meeple_look.gd`: `MeepleLook`, how a meeple is drawn. It holds the jam game's numbers: the body and head pictures, what the head shows for each load, the shirt colour, and the bounce and tilt.
- `view/meeple_batch.gdshader`: the shader that draws a village batch. It draws plain sprites, and it draws a meeple: body colour, head, what it carries, bounce and tilt.
- `art/`: the meeple art, copied from the jam game. `meeple.png` is the body and the bare head. `meeple_holding.png` and `meeple_holding_more.png` are the heads with a load.
- `tests/`: the tests of the numbers. The look itself is proven by a picture: see [game/dev/stress/README.md](../dev/stress/README.md).
- The rules that move meeples are not here yet.

## Drawing a meeple

A meeple is a mover in the [sprite batch](../../addons/sprite_batch/README.md).

```gdscript
var look := MeepleLook.new()
look.add_to(atlas)          # before atlas.build()
look.shape(rows)            # tells the rows how big a meeple is
batch.setup(rows, MeepleLook.SHADER)
look.dress(batch)

var frame := MeepleLook.head_frame(&"wood", 2)
rows.place_mover(index, position, MeepleLook.shirt_colour(randf()), look.numbers(frame, phase, false))
```

- The position of a meeple is the middle of its body, as in the jam game.
- `phase` is where the meeple's bounce starts. Give each meeple a random one from 0 to `MeepleLook.PHASE_RANGE`, so a crowd does not move as one.
- When a meeple starts or stops walking: `rows.set_mover_number(index, 3, MeepleLook.WALKING)` or `MeepleLook.STANDING`.
- When its load changes: `rows.look_mover(index, colour, look.numbers(frame, phase, walking))`.

Built by: #61 (the look) and #64 (the rules). The rules for this folder are in [game/README.md](../README.md).
