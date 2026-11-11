# game/village/

**What lives here:** one village as an object that ticks: its grid, its timers, its random numbers, and the places where stock, jobs, meeples and buildings hang.

Nothing about a village lives in a global. Two villages run side by side, and a test runs one with no window.

## The files

All of it is simulation code, in `sim/`.

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
- **Seed:** `village.rng` gives every random number of the village. The same seed and the same commands give the same village.
- **Parts:** the four names are `Village.STOCK`, `JOBS`, `MEEPLES` and `BUILDINGS`. They are empty until #63, #65, #64 and #67 hang something there.
- **Commands:** the picture never changes the village. It sends a command, which is done at once and says if it was refused.
- **Ids:** `village.new_id()` gives the number that names a thing on the grid.
- **Compare:** `village.snapshot()` is the whole village as plain data, and `village.state_hash()` is one number for it.
- **Close:** `Game.remove_village()` closes a village. A closed village holds on to nothing.

## The grid

The layout is the one of the jam game, unchanged.

- Cell (x, y) sits at (x*7 + y*5, y*5) art pixels. The jam game's cell scale of 10 and the giant's 0.1 cancel out.
- Six neighbours: (1,0), (-1,0), (0,1), (0,-1), (1,-1), (-1,1). Distance is (|dx| + |dy| + |dx+dy|) / 2.
- A cell stores its ground kind, what stands on it, who reserved it, and its loose drops.
- A cell holds one thing at most. A footprint counts right for width and down for depth, 1 to 4 each. One missing or taken cell refuses the whole footprint.
- Cells can have any coordinates, below zero too. A chunk is only made where a cell is added, so a round map costs no more than its cells.

The four questions it answers:

| Question | Call |
| --- | --- |
| Which cell is at a point? | `grid.cell_at(point)` |
| Which cells are free for a footprint at a point? | `grid.free_cells_at(point, width, depth)` |
| Which empty cells lie within N steps of a thing? | `grid.empty_cells_near(thing, steps)` |
| Which cells sit at fixed offsets from a cell? | `grid.cells_at_offsets(cell, offsets)` |

Reserving: `grid.reserve(cells, reserver)` and `grid.release(reserver)`. A reserved cell is only free for its reserver.

Drops: `grid.drops.add(cell, kind, count)`, `grid.drops.take(cell, kind, count)`, `grid.drops.at(cell)`.

## See it run

Open `game/dev/village_demo/village_demo.tscn` in Godot and press F6. See [its page](../dev/village_demo/README.md).

## Tests

`tests/`: `test_village.gd`, `test_village_grid.gd`, `test_grid_layout.gd`, `test_grid_questions.gd`, `test_grid_reserve_and_drops.gd`. Run them with `bash .github/ci/run_tests.sh --only=game/village`.

Built by: #60, #63 and #65. The rules for this folder are in [game/README.md](../README.md).
