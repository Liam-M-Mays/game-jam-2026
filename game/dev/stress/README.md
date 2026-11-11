# game/dev/stress/

**What lives here:** the scenes that measure and show the sprite batch and the meeples. Dev only. Nothing here goes into the export.

Built by #61 (the batch) and #64 (the meeples). More stress tests come with #74.

## The scenes

| Scene | What it does |
| --- | --- |
| `batch_demo.tscn` | A small village-sized scene to look at. Open it and press F6 |
| `stress.tscn` | Thousands of wandering meeples and 6,000 static things, all in view. Measures the frame time |
| `meeple_compare.tscn` | Draws six meeples with the jam game's scene and with the batch, and counts the pixels that differ |
| `meeple_stress.tscn` | 5,000 meeples wander on a flat grid of 100,000 cells, on the real simulation. Measures the frame time |
| `meeple_sim_compare.tscn` | Draws walking, carrying and dying meeples with the jam game's scene and with the new simulation, side by side |

All five need a window. They do not run in CI.

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

## The meeple stress scene

This is the run of issue #64: the real simulation, not a stand-in. A `Village` with a `VillageMeeples` part is ticked by the Game service, and a `MeepleView` draws it through the batch.

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/stress/meeple_stress.tscn" -- meeples=5000,5000,5000 quit=1
```

- That is three runs of 5,000 meeples. Each run builds a fresh village. It prints one `MEEPLE_STRESS_RESULT` line per run, and a table at the end.
- The grid is flat and has about 100,000 cells. All of it is in view, so every meeple is drawn. A meeple is only a few pixels tall from that far away.
- The meeples have nothing to do, so they wander by the jam game's rules: pause, stroll, pause.
- Before the measuring starts the village runs 400 ticks, which is 20 seconds of game time. A new meeple stands for up to 3.5 seconds first, so without this the run would measure a crowd that mostly stands.
- `cells=100000` sets the size of the grid. `seed=64` sets the seed. `speed=3` sets the game speed.
- `hangouts=300` adds huts. The meeples then stroll around the huts and change huts, as they do in a village.
- `shot=/full/path.png` saves a picture of the last run. `close_shot=/full/path.png` saves one from close up.
- `column_width=960` sets how wide the batch's mover columns are. See "Batch ms" below.

What the columns mean:

| Column | What it is |
| --- | --- |
| Ticks a second | How many ticks ran. 20 at game speed x1 |
| Walking | How many meeples walked, on average per tick. The others waited and cost nothing |
| Stepped a tick | How many meeple steps one tick ran |
| Ms a tick, Worst tick ms | How long one tick of the village took |
| Sim ms | The ticks, spread over all frames. Most frames run no tick |
| View ms | `MeepleView`: the glide of the walking meeples |
| Batch ms | The sprite batch: putting together what is on screen and sending it |
| Render ms | Godot's drawing time on the processor |

- **Batch ms is high in this scene on purpose.** The whole world is in view, so the batch looks at every mover column of every band in every frame: about 39,000 of them. From close up it looks at far fewer. Wider columns (`column_width=3840`) make it cheaper here.
- The same traps as for the batch stress scene apply. Read "How a frame rate is measured" below before trusting a number.

## The side-by-side look

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/stress/meeple_sim_compare.tscn" -- quit=1
```

- The lower half is the real thing: a village is ticked, and `MeepleView` draws it through the batch. The upper half is the jam game's meeple scene, posed by hand with the jam game's own formulas and Godot's own tween maths.
- It ends with exit code 0 when no pose clearly differs in more pixels than the script expects, and with 1 when one does.
- A normal run writes no file. `save=1` writes the side-by-side pictures. `update=1` also writes the jam half again as the reference.
- `pictures/meeple_sim_<pose>.png` is the side-by-side picture. `pictures/meeple_sim_<pose>_reference.png` is the jam half alone, so the check still works after the jam scene is gone.

| Pose | What it shows | Pixels that clearly differ, of 921,600 (Apple M3) |
| --- | --- | --- |
| `walk_carry` | 8 meeples walking, half way between two ticks, and 8 standing. Every load | 79 |
| `topple` | 0, 3, 6, 9, 10, 11, 12 and 20 ticks after death. Upper line died standing, lower line died walking | 56 |
| `fade` | 24, 27, 30, 33, 36, 38, 39 and 40 ticks after death | 0 |

- The walk and the topple differ in single pixels on tilted edges, as in the pixel comparison below.
- **Colours that are one or two steps of 255 apart count as the same.** About 2,400 pixels of the walk and of the topple are one step off: three whole shirts. The batch keeps the colour of a sprite as a 16-bit number, so a shirt can round the other way.
- What no picture here shows: two dying meeples that overlap can be drawn in another order than in the jam game. The jam game sorted a falling meeple by its middle, which moves as it falls. The batch keeps it where its feet are.
- The speeds and the timing are numbers, so tests prove them: see [game/meeples/README.md](../../meeples/README.md).

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
- The script holds the number of pixels each pose is expected to differ in. It prints both numbers, and "MORE THAN EXPECTED" for a pose that differs in more.
- It also checks that the jam scene's own picture still matches the saved reference. On another graphics card it may not. Then the pose line says "REFERENCE DOES NOT MATCH", and that is not the batch's fault.
- It ends with exit code 0 when both checks pass for every pose, and with 1 when one does not. The last line says which of the two failed.
- A normal run writes no file. `save=1` writes the batch pictures and the difference pictures. `update=1` also writes the reference pictures again from the jam scene.
- The jam meeple's script is taken off for the picture, because it needs the old globals. Its numbers are read from it, and its bounce formula is applied by hand.

| Pose | What it shows | Pixels that differ (Apple M3) |
| --- | --- | --- |
| `standing` | Standing still at clock 0 | 0 |
| `breathing` | Standing at 0.31 s, each meeple with its own bounce start | 0 |
| `walking` | Walking at 0.31 s | 15 |
| `walking_2` | Walking at 0.9 s | 7 |
| `walking_late` | Walking at 3,000.4 s, to check the bounce stays exact late in a game | 5 |
| `same_band` | Two overlapping pairs between the same two row lines | 0 |

- The walking poses differ in single pixels on tilted edges. The batch works the tilt out on the graphics card and the jam game on the processor, and the two round a tilted edge a tiny bit differently.
- `same_band` has one pair 35 pixels apart in height and one pair 4 pixels apart, which is less than one art pixel. In both pairs the lower meeple is put into the batch first. Both pairs match the jam game, because a meeple is put into its band by height.
- What no picture here shows: two meeples closer than one art pixel in height can be in the wrong order for a while after one of them changed height inside its band, or when they stand on two sides of a column line. See "Limits" in the [addon README](../../../addons/sprite_batch/README.md).
- The tests in `game/meeples/tests/` check the numbers and a copy of the bounce formula. Only these pictures prove what the shader really draws.

## The other files

- `jam_grid.gd`: `JamGrid`, the jam game's grid and art numbers in one place. The scenes here and the tests build their batch from it. It is a stand-in until a later part joins the batch to the village grid of part #60.
- `frame_meter.gd`: `FrameMeter`, the measuring rule.
- `wander_crowd.gd`: `WanderCrowd`, meeples that walk about at random. The batch stress scene and the batch demo still use it, so their numbers can be compared with the ones of #61. The real meeples are in `meeple_stress.tscn`.
- `stress_art.gd`: `StressArt`, the static sprites these scenes use, with the jam game's regions and offsets.
- `art/town_hall.png`: a copy of the Town Hall sheet from `ART/`, which game files may not use.
- `pictures/`: the pictures for pull requests. Godot does not import this folder.
- `tests/`: checks that `JamGrid` is the jam game's grid, and that art is drawn crisp at 10 times its size.
