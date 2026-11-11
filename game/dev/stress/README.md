# game/dev/stress/

**What lives here:** the scenes that measure and show the sprite batch. Dev only. Nothing here goes into the export.

Built by #61. More stress tests come with #74.

## The scenes

| Scene | What it does |
| --- | --- |
| `batch_demo.tscn` | A small village-sized scene to look at. Open it and press F6 |
| `stress.tscn` | Thousands of wandering meeples and 6,000 static things, all in view. Measures the frame time |
| `meeple_compare.tscn` | Draws six meeples with the jam game's scene and with the batch, and counts the pixels that differ |

All three need a window. They do not run in CI.

## The demo

Open `batch_demo.tscn` in Godot and press F6.

- WASD or the arrow keys move. The mouse wheel zooms.
- The thing under the mouse turns yellow, and its cell is outlined.
- Left click a thing to take it away. Left click an empty cell to plant a tree.
- M adds 500 meeples.

## The stress scene

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/stress/stress.tscn" -- meeples=5000,10000 statics=6000 quit=1
```

- It prints one `STRESS_RESULT` line per run, and a table at the end.
- `shot=/full/path.png` saves a picture of the last run.
- `churn=30` sets how many drops are taken away and put back every frame. 30 is the default.
- "Wander ms" is the scene's own stand-in for the simulation. "Batch ms" is the script time of the sprite batch. "Render ms" is Godot's drawing time on the processor. The rest of a frame is spent handing the picture to the screen.

## How a frame rate is measured

`frame_meter.gd` holds the rule of issue #57:

- A 1920x1080 window, vsync off, game speed x1.
- 1.5 seconds of warm-up, then 4 seconds measured.
- "Holds 60" means the average frame takes 16.6 ms or less.
- The window is pinned on top, and the run checks that every frame was really drawn.

The table has a column "Run counts". It is only yes when the window is 1920x1080, vsync reads as off and every frame was drawn. "Holds 60" is only yes for a run that counts.

**Trap:** a window that is covered, on another desktop, or behind a locked screen stops drawing and reports fake fast frames. A run that says NO under "Run counts" does not count. Opening the scene with F6 inside the editor's game tab does not count either: the window has another size there.

The scene also prints how often the screen refreshes. A frame time that sits exactly on a whole part of that (16.7 ms, 8.3 ms or 5.6 ms on a 60 Hz screen) can be the screen's pace and not the game's. Measure a few other meeple counts to see whether the time moves.

The scene prints a `STRESS_WARNING` when it could not place as many static things as asked (9,228 fit in view), or when no drops come and go.

## The pixel comparison

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/stress/meeple_compare.tscn" -- quit=1
```

- Six meeples cover every carry state: nothing, wood, two wood, stone, two stone, nothing.
- Each pose is a 1920x1080 picture at zoom 8. It is compared with the jam scene's picture of the same pose.
- `pictures/meeple_<pose>_reference.png` is the jam scene's picture. It is the reference, so the batch can still be checked after the jam scene is gone.
- The script holds the number of pixels each pose is expected to differ in. It ends with exit code 0 when no pose differs in more, and with 1 when one does. It prints both numbers.
- A normal run writes no file. `save=1` writes the batch pictures and the difference pictures. `update=1` also writes the reference pictures again from the jam scene.
- The jam meeple's script is taken off for the picture, because it needs the old globals. Its numbers are read from it, and its bounce formula is applied by hand.

| Pose | What it shows | Pixels that differ (Apple M3) |
| --- | --- | --- |
| `standing` | Standing still at clock 0 | 0 |
| `breathing` | Standing at 0.31 s, each meeple with its own bounce start | 0 |
| `walking` | Walking at 0.31 s | 15 |
| `walking_2` | Walking at 0.9 s | 7 |
| `walking_late` | Walking at 3,000.4 s, to check the bounce stays exact late in a game | 5 |
| `same_band` | Two overlapping pairs between the same two row lines | 12,800 |

- The walking poses differ in single pixels on tilted edges. The batch works the tilt out on the graphics card and the jam game on the processor, and the two round a tilted edge a tiny bit differently.
- `same_band` has one pair 35 pixels apart in height and one pair 4 pixels apart. The first pair matches the jam game. The second pair does not: the two are closer than one art pixel in height, and the batch draws such a pair in the order they came, not by height. The 12,800 pixels are one stone, 1 by 2 art pixels, at zoom 8.
- The tests in `game/meeples/tests/` check the numbers and a copy of the bounce formula. Only these pictures prove what the shader really draws.

## The other files

- `jam_grid.gd`: `JamGrid`, the jam game's grid and art numbers in one place. The scenes here and the tests build their batch from it. It is a stand-in until a later part joins the batch to the village grid of part #60.
- `frame_meter.gd`: `FrameMeter`, the measuring rule.
- `wander_crowd.gd`: `WanderCrowd`, meeples that walk about at random.
- `stress_art.gd`: `StressArt`, the static sprites these scenes use, with the jam game's regions and offsets.
- `art/town_hall.png`: a copy of the Town Hall sheet from `ART/`, which game files may not use.
- `pictures/`: the pictures for pull requests. Godot does not import this folder.
- `tests/`: checks that `JamGrid` is the jam game's grid, and that art is drawn crisp at 10 times its size.
