# addons/sprite_batch/

**What lives here:** the sprite batch. It draws everything in a village in one go: one mesh, one image, one draw call. It knows nothing about the game's rules, so it can be tested alone.

Built by #61. Design: the "Drawing" part of [docs/core-design.md](../../docs/core-design.md).

## The files

| File | What it is |
| --- | --- |
| `sprite_atlas.gd` | `SpriteAtlas`: one image that holds every sprite, built from the art files when the game loads |
| `batch_cells.gd` | `BatchCells`: the cell maths. Where a cell is, and which cell a point is in. The game hands the numbers in |
| `batch_rows.gd` | `BatchRows`: the sprites, kept in drawing order. Also finds the thing under a point. Needs no window |
| `batch_store.gd` | `BatchStore`: what a `BatchRows` keeps, and the functions that look one sprite up: its extra number, its cells, and the decor layers. `BatchRows` extends it, so all of it is called on the rows |
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
- Movers are slotted in between two rows. A mover is in front of the row above it and behind the row below it.
- Between two rows the movers are kept in thin bands, one art pixel tall. A mover is in front of every mover in a band above it. So a lower mover is in front of a higher one, as when the jam game sorted them by height.
- Two movers in the same thin band are less than one art pixel apart in height. They are drawn first by column, left to right. Inside a column a mover is put in by height when it comes into the band or is placed: behind the lower ones, in front of the higher ones. So a pair that walks down or up together keeps the lower one in front, and a standing pair is drawn by height whichever was placed first.
- Nothing is sorted after that. Two movers in one band can be in the wrong order for a while when one of them changed height inside the band, or when they stand on two sides of a column line. The error is less than one art pixel deep.
- A row is only rebuilt when one of its own things is added, changed or removed. No script runs per thing per frame.

## Only what is on screen

- Just before each frame, `SpriteBatch` asks `BatchRows` for the sprites in view and sends those.
- A row that is off screen is left out. Inside a row, the things left and right of the screen are left out.
- Movers are also grouped in columns, 960 pixels wide. Columns off screen are left out.
- A row is still sent when one of its things is tall enough to reach the screen.
- A mover band is sent when a mover in it could reach the screen. A meeple is a bit taller than one row, so its bands reach a little more than one row below the screen.
- In a frame where no row changed, `move_movers` was not called and the camera did not move, nothing is sent. A change to a mover's look, place or count is sent too.
- In every other frame the sprites on screen are put together again and sent. Whole rows are copied as they are, so this costs little, but it does happen every frame while meeples move.

## Finding the thing under the mouse

No click areas. `BatchRows.pick(point)` does it with maths. Hover and click use the same call.

1. The thing whose picture is in front at that point wins. Only solid pixels count, so tall art has no invisible hit box. This is how a tall sprite is found where it sticks up over the row behind it.
2. Where no picture is hit, the point gives a cell, and the thing that stands on that cell wins.

Step 2 is a stand-in. It reads the batch's own list of what was added on which cell, and the newest thing on a cell wins. What stands on a cell is the village grid's question (part #60). Once the two are joined, a view calls `pick_sprite(point)` for step 1 and asks the grid for step 2.

`SpriteBatch.thing_at_screen(position)` does the same from a screen position.

## Using it

```gdscript
var atlas := SpriteAtlas.new()
var tree := atlas.add_file(&"tree", "res://path/to/sheet.png", Rect2i(37, 2, 6, 8))
atlas.build()

# The grid numbers come from the game: step, slant, row height, cell middle, origin.
# The numbers in this example are sample values, not the game's grid.
var cells := BatchCells.new(70.0, 50.0, 50.0, Vector2(-5.0, 0.0), Vector2.ZERO)
var rows := BatchRows.new(cells, atlas, world_rect, 10.0)
rows.add_thing(thing_id, Vector2i(4, 7), tree, Vector2(0, -3))

var batch := SpriteBatch.new()
batch.setup(rows)
add_child(batch)
```

- `world_rect` is the area in pixels that holds every cell and every mover. The `10.0` is how many pixels one art pixel takes at zoom 1.
- The offset of a thing is in art pixels, from the cell to the middle of the sprite, like the offset of a `Sprite2D`.
- A thing is known by the caller's own number. The batch gives that number back from `pick`.
- Movers: `shape_movers` once, `resize_movers`, `place_mover` for each new one, then `move_movers(positions)` in every frame in which a mover moved.
- Each sprite carries a colour and four numbers for the shader. The first number is the sprite. The fourth picks how it is drawn: 0 is a plain sprite.
- Each sprite also carries one extra number. See "The extra number" below.
- A sprite name belongs to one picture. Adding the same name from another file or region is refused with an error.

## The extra number

Every sprite has one more number, next to its colour and its four shader numbers.

- `rows.set_thing_extra(id, value)` and `rows.set_mover_extra(index, value)` set it. It starts at 0.
- It is 32-bit, so whole numbers stay exact up to 16 million. The colour and the four shader numbers are only 16-bit.
- It has a path of its own. It takes nothing from the colour or the four numbers, so a meeple keeps all four.
- A shader reads it with `batch_extra(MODEL_MATRIX)` in `vertex()`.
- `change_thing`, `place_mover`, `look_mover` and `move_movers` keep it.
- The batch itself does not use it. The [effects toolkit](../effects/README.md) keeps its effect number there.
- How it works: a sprite's place is 8 numbers, and Godot uses 6 of them to place a flat sprite. The third one moves nothing on screen and carries the extra number. See "Limits".

## Decor

A decor sprite is only drawn. It is never found by `pick`, and it stands on no cell.

```gdscript
var id := rows.add_decor(cell, sprite, offset, tint, BatchRows.UNDER)
rows.tint_decor(id, Color(0.4, 0.4, 0.4, 0.5))
rows.remove_decor(id)
```

| Layer | Where it is drawn | Used for |
| --- | --- | --- |
| `BatchRows.UNDER` | Under everything | A lit cell |
| `BatchRows.FRONT` | In front of every thing of its own row, behind the movers below that row and behind the next row | A one-shot sprite |
| `BatchRows.OVER` | Over everything | A dust cloud |

- The place is given like the place of a thing: a cell and an offset in art pixels.
- Inside a layer a newer decor sprite is in front of an older one.
- `add_decor` hands out the number. Decor numbers are counted apart from thing numbers.
- Decor under and over everything is always sent, on screen or not. Keep it to a few sprites.
- A row is sent while one of its things or one of its front decor sprites reaches into the screen.
- The effects toolkit can also put a one-shot in the order by the height of its own middle (`EffectShots.BY_HEIGHT`). It uses the front layer of the row that the middle falls in. `nearest_row(row)` gives that row, or the first or last row of the batch when the middle is outside them all.

## The grid

The batch has no grid numbers of its own. `BatchCells` is all it knows about the grid, and the game hands the numbers in when it makes one.

- The numbers cannot be changed afterwards. The batch works the places of its sprites out once. A write to one of them, or to `cells`, `atlas` or `pixel_scale` of a `BatchRows`, logs an error and changes nothing.
- A village is moved by moving its `SpriteBatch` node. The view and the mouse position follow the node.
- Each `BatchRows` needs cell maths that never changes. Do not share one `BatchCells` between two villages that could need different numbers.
- A point exactly between two cells goes to the cell on the right, or to the cell below, on both sides of zero. That is the rule of the village grid of part #60.
- For another kind of grid, extend `BatchCells` and override `position_of` and `cell_at`. Rows must stay level lines that are `row_height` apart.
- For now the jam game's numbers are in `game/dev/stress/jam_grid.gd`, for the dev scenes and tests. A later part joins the batch to the village grid of part #60.

## Limits

- An atlas holds at most 2,048 sprites.
- The colour and the four shader numbers of a sprite are 16-bit on Godot's OpenGL renderer: about 3 digits, and whole numbers are only exact up to 2,048. (Godot packs them as half floats in `drivers/gles3/storage/mesh_storage.cpp`.) Store small values in them, such as a 0 to 1 progress, never a clock time. The 8 place numbers are 32-bit.
- Every mover has the same box size. Other kinds of mover, such as animals, need a second size later.
- A mover outside the world area is still drawn. It is kept with the band and the column at the edge, so it is not left out as tightly.
- When two things share a cell, such as two drops, the cell finds the newest one. Each is still found by its own picture.
- The number of a thing must fit in 32 bits, and it cannot be -1.
- Two movers closer than one art pixel in height are put in order once, when one comes into the band. They are not sorted again while they stay in it. A view that wants a meeple put in by height again when it stops can call `place_mover` for it.
- `batch_clock` is the clock of the meeple bounce. `MeepleLook` makes it start again every 1.508 seconds, which is one full bounce. So everything in the village shader that reads `batch_clock` must also repeat every 1.508 seconds, or it jumps. The effects toolkit has a clock of its own, `effects_clock`, which runs on game time.
- The extra number rides in a place number that Godot calls padding. Godot hands it to the shader in the third column of the sprite's matrix. Checked on Godot 4.7.2 with the OpenGL renderer. If a later Godot stops handing it on, every extra number reads as 0. The effects comparison in `game/dev/effects_demo/` shows that, but it needs a window and CI does not run it. Run it by hand after every Godot upgrade.
- A sprite is left out by its plain box. What a shader draws outside that box, such as an outline, is not counted. Sideways the batch keeps a margin as wide as its widest thing. Up and down it does not.
- A mover takes no extra number before it is placed. `is_mover_placed(index)` says whether it was.
- A class may have 20 public functions at most (the linter's rule), and `BatchRows` has 20. A new batch function goes into `BatchStore`.
- Making a `BatchRows` for the 100,000 cell world takes 1.5 ms and 1.4 MB (Apple M3). The table of mover buckets covers the whole world. A bucket itself is only made when its first mover comes.
