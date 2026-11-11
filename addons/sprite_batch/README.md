# addons/sprite_batch/

**What lives here:** the sprite batch. It draws everything in a village in one go: one mesh, one image, one draw call. It knows nothing about the game's rules, so it can be tested alone.

Built by #61. Design: the "Drawing" part of [docs/core-design.md](../../docs/core-design.md).

## The files

| File | What it is |
| --- | --- |
| `sprite_atlas.gd` | `SpriteAtlas`: one image that holds every sprite, built from the art files when the game loads |
| `batch_cells.gd` | `BatchCells`: the cell maths. Where a cell is, and which cell a point is in. The numbers are the jam game's slanted grid |
| `batch_rows.gd` | `BatchRows`: the sprites, kept in drawing order. Also finds the thing under a point. Needs no window |
| `sprite_batch.gd` | `SpriteBatch`: the node that draws a `BatchRows` |
| `sprite_batch.gdshader` | The plain shader: a picture from the atlas, times a colour |
| `sprite_batch.gdshaderinc` | What every batch shader shares. A game shader includes it. The meeple shader is in `game/meeples/view/` |
| `tests/` | The tests. Run them with `bash .github/ci/run_tests.sh --only=sprite_batch` |

## Two kinds of sprite

- A **thing** stands still on a cell: a tree, a rock, a building, a drop.
- A **mover** walks around: a meeple.

## The drawing order

Nothing is sorted. The order comes from where a sprite is kept.

- Things are grouped by grid row. Rows are drawn back to front, so things lower on screen are in front.
- Inside one row a thing is drawn behind everything to its left. A new thing is put in at its place.
- Movers are slotted into the band between two rows. A mover is in front of the row above it and behind the row below it. Movers inside one band are in no set order.
- A row is only rebuilt when one of its own things is added, changed or removed. Things that stand still cost no script time per frame.

## Only what is on screen

- Just before each frame, `SpriteBatch` asks `BatchRows` for the sprites in view and sends those.
- A row that is off screen is left out. Inside a row, the things left and right of the screen are left out.
- Movers are also grouped in columns, 960 pixels wide. Columns off screen are left out.
- A row is still sent when one of its things is tall enough to reach the screen.
- A mover band is sent when a mover in it could reach the screen. A meeple is a bit taller than one row, so this can be one band more below the screen.
- When nothing changed and the camera did not move, nothing is sent.

## Finding the thing under the mouse

No click areas. `BatchRows.pick(point)` does it with maths. Hover and click use the same call.

1. The thing whose picture is in front at that point wins. Only solid pixels count, so tall art has no invisible hit box. This is how a tall sprite is found where it sticks up over the row behind it.
2. Where no picture is hit, the point gives a cell, and the thing that stands on that cell wins.

`SpriteBatch.thing_at_screen(position)` does the same from a screen position.

## Using it

```gdscript
var atlas := SpriteAtlas.new()
var tree := atlas.add_file(&"tree", "res://path/to/sheet.png", Rect2i(37, 2, 6, 8))
atlas.build()

var rows := BatchRows.new(BatchCells.new(), atlas, world_rect)
rows.add_thing(thing_id, Vector2i(4, 7), tree, Vector2(0, -3))

var batch := SpriteBatch.new()
batch.setup(rows)
add_child(batch)
```

- `world_rect` is the area in pixels that holds every cell and every mover.
- The offset of a thing is in art pixels, from the cell to the middle of the sprite, like the offset of a `Sprite2D`.
- A thing is known by the caller's own number. The batch gives that number back from `pick`.
- Movers: `shape_movers` once, `resize_movers`, `place_mover` for each new one, then `move_movers(positions)` once a frame.
- Each sprite carries a colour and four numbers for the shader. The first number is the sprite. The fourth picks how it is drawn: 0 is a plain sprite.

## Another grid

`BatchCells` is the only thing the batch knows about the grid. To use another grid, set its numbers, or extend it and override `position_of` and `cell_at`. Rows must stay level lines that are `row_height` apart.

## Limits

- An atlas holds at most 2,048 sprites.
- Every mover has the same box size. Other kinds of mover, such as animals, need a second size later.
- A mover outside the world area is still drawn. It is kept with the row and the column at the edge, so it is not left out as tightly.
- When two things share a cell, such as two drops, the cell finds the newest one. Each is still found by its own picture.
- The number of a thing must fit in 32 bits.
