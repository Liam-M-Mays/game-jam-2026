# game/dev/village_demo/

**What lives here:** the demo for #60. Two villages tick side by side, and you can watch their state.

## Run it

Open `village_demo.tscn` in Godot and press F6.

| Key | What it does |
| --- | --- |
| Space | Pause and go on |
| 1, 2, 3 | Game speed x1, x2, x3 |
| V | Change the village in view. Both keep ticking |
| R | Start again with the same seeds. The same picture grows again |

## What you see

- Two slanted grids. Each is one `Village` object with its own grid, timers and random numbers.
- Coloured cells are things. A thing takes 1 to 3 cells across and 1 or 2 rows.
- The brown block is reserved. Nothing grows there.
- A yellow dot is wood lying on a cell.
- Under each grid: the seed, the tick, the counts, and one number that stands for the whole state.
- The console prints one line per village every second.

## The files

- `village_demo.gd` and `village_demo.tscn`: the scene. It only reads the villages and draws them.
- `demo_growth.gd`: a stand-in for nature that grows and clears things on timers. It is not part of the game.

Built by: #60.
