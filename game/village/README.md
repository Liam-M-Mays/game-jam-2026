# game/village/

**What lives here:** one village as an object that ticks: its grid, its timers, its random numbers, and the places where stock, jobs, meeples and buildings hang.

Nothing about a village lives in a global. Two villages run side by side, and a test runs one with no window.

## The files

The simulation is in `sim/`. The picture is in `view/`: see [The picture](#the-picture).

| File | What it is |
| --- | --- |
| `village.gd` | The `Village` object. Start reading here |
| `village_grid.gd` | The cells of a village, as data in chunks |
| `grid_layout.gd` | The maths of the slanted grid: positions, neighbours, distance, footprints |
| `grid_chunk.gd` | The arrays of 16 by 16 cells |
| `grid_drops.gd` | The loose drops on the cells, as counts |
| `village_part.gd` | The base of a part: stock, job board, meeples, buildings |
| `village_command.gd` | The base of a command |

## A village

```gdscript
var village := Game.new_village(1234)          # or Village.new(1234) in a test
village.grid.add_cell(Vector2i(0, 0))
village.add_part(Village.STOCK, my_stock)      # a VillagePart
village.send(my_command)                       # a VillageCommand
village.tick()                                 # Game does this for you
```

- **Tick:** one step. It wakes the timers that are due, then steps each part in the order the parts were hung.
- **Timers:** a timer that wakes is called with the village as its first argument. A part never binds its village into a timer.
- **Seed:** `village.rng` gives every random number of the village. The same seed and the same commands give the same village.
- **Parts:** the four names are `Village.STOCK`, `JOBS`, `MEEPLES` and `BUILDINGS`. They are empty until #63, #65, #64 and #67 hang something there.
- **Every part has a `snapshot()`.** A part without one would be left out when two villages are compared, so the base class logs an error.
- **Commands:** the picture never changes the village. It sends a command, which is done at once and says if it was refused.
- **Ids:** `village.new_id()` gives the number that names a thing on the grid.
- **Compare:** `village.snapshot()` is the whole village as plain data. `village.state_hash()` is one number for it: the same village gives the same number, but compare snapshots to be sure two villages differ.
- **Close:** `Game.remove_village()` closes a village. A closed village does not tick, takes no command, no part and no timer, and holds on to nothing.

## The grid

The layout is the one of the jam game.

- Cell (x, y) sits at (x*7 + y*5, y*5) art pixels. The jam game's cell scale of 10 and the giant's 0.1 cancel out.
- A point exactly between two cells goes to the cell on the right, or to the row below. That is the jam game's answer for every cell it had. It only differs on the outer edge of column 0 and row 0, where the jam game had no cell.
- Six neighbours: (1,0), (-1,0), (0,1), (0,-1), (1,-1), (-1,1). Distance is (|dx| + |dy| + |dx+dy|) / 2.
- A cell stores its ground kind, what stands on it, who reserved it, and its loose drops.
- A cell holds one thing at most. A footprint counts right for width and down for depth, 1 to 4 each. One missing or taken cell refuses the whole footprint.
- Cells can have any coordinates, below zero too. A chunk is only made where a cell is added, so a round map costs no more than its cells.
- `grid.add_cells(xs, ys, ground_kinds)` adds a whole world at once. It does what `add_cell` does for each cell, about twice as fast. Added by #48 for the world generator.

The four questions it answers:

| Question | Call |
| --- | --- |
| Which cell is at a point? | `grid.cell_at(point)` |
| Which cells are free for a footprint at a point? | `grid.free_cells_at(point, width, depth)` |
| Which empty cells lie within N steps of a thing? | `grid.empty_cells_near(thing, steps)` |
| Which cells sit at fixed offsets from a cell? | `grid.cells_at_offsets(cell, offsets)` |

Reserving: `grid.reserve(cells, reserver)` and `grid.release(reserver)`. A reserved cell is only free for its reserver.

Drops: `grid.drops.add(cell, kind, count)`, `grid.drops.take(cell, kind, count)`, `grid.drops.count_at(cell, kind)`, `grid.drops.has_any(cell)`, `grid.drops.at(cell)`. For now a stack of drops is a small dictionary per cell. Whether drops become rows in arrays is a question for #63.

## The picture

`view/` joins a village to the sprite batch. The picture only reads the village. A village with no picture runs the same.

| File | What it is |
| --- | --- |
| `view/village_view.gd` | `VillageView`: the node that shows one village. It builds one atlas and one batch |
| `view/village_view_layer.gd` | `VillageViewLayer`: the base of one part of the picture |
| `view/village_layers.gd` | `VillageLayers`: the list of layers. **A new view is added here** |

```gdscript
var view := VillageView.new()
add_child(view)
view.attach(village, world.bounds, VillageLayers.of(village))
```

- **Art pixels:** the village counts in art pixels. The picture draws them 10 times as big: `VillageView.ART_SCALE`. Use `VillageView.to_pixels()` and `to_art()`.
- **Cells:** `VillageView.batch_cells()` hands the numbers of `GridLayout` to the batch, so a cell is in the same place for both.
- **Ids:** a thing goes into the batch under the number the village grid knows it by.

### Adding a view

1. Write a class that extends `VillageViewLayer`, in the `view/` folder of your own feature.
2. Override what it needs:
    - `add_sprites(village, atlas)`: add your sprites before the atlas is built. Keep the sprite numbers.
    - `shader()`: return a batch shader when the plain one will not do. The first layer that names one decides.
    - `start(village, view)`: put your things into `view.rows`, or shape your movers there. Own nodes go in with `view.add_under(node)` or `view.add_over(node)`.
    - `update(village, view)`: runs every frame. Move your movers here.
    - `close()`: let go of everything.
3. Add one line to `VillageLayers.of()`. Make the layer only when the village has the part it draws.

A layer never changes the village. It sends a command with `village.send()`.

## See it run

Open `game/dev/village_demo/village_demo.tscn` in Godot and press F6. See [its page](../dev/village_demo/README.md).

## Tests

`tests/`: `test_village.gd`, `test_village_grid.gd`, `test_grid_layout.gd`, `test_grid_questions.gd`, `test_grid_reserve_and_drops.gd`, `test_grid_add_cells.gd`, and `test_village_view.gd` for the picture. Run them with `bash .github/ci/run_tests.sh --only=game/village`.

Built by: #60, #63 and #65. The picture: #48. The rules for this folder are in [game/README.md](../README.md).
