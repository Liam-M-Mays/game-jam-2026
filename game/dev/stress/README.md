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
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 res://game/dev/stress/stress.tscn -- meeples=5000,10000 statics=6000 quit=1
```

- It prints one `STRESS_RESULT` line per run, and a table at the end.
- `shot=/full/path.png` saves a picture of the last run.
- `churn=30` sets how many drops are taken away and put back every frame. 30 is the default.
- "Wander ms" is the scene's own stand-in for the simulation. "Batch ms" is the sprite batch.

## How a frame rate is measured

`frame_meter.gd` holds the rule of issue #57:

- A 1920x1080 window, vsync off, game speed x1.
- 1.5 seconds of warm-up, then 4 seconds measured.
- "Holds 60" means the average frame takes 16.6 ms or less.
- The window is pinned on top, and the run checks that every frame was really drawn.

**Trap:** a window that is covered, on another desktop, or behind a locked screen stops drawing and reports fake fast frames. The column "Every frame drawn" must say yes. A run that says NO does not count.

## The pixel comparison

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 res://game/dev/stress/meeple_compare.tscn -- quit=1
```

- Six meeples cover every carry state: nothing, wood, two wood, stone, two stone, nothing.
- Three poses, each at zoom 8 in a 1920x1080 picture: standing, breathing, and one fixed walk moment.
- It prints how many pixels differ, and saves the pictures in `pictures/`.
- `pictures/meeple_<pose>_reference.png` is the jam scene's picture. It is the reference, so the batch can still be checked after the jam scene is gone.
- `update=1` writes the reference pictures again from the jam scene.
- The jam meeple's script is taken off for the picture, because it needs the old globals. Its numbers are read from it, and its bounce formula is applied by hand.

## The other files

- `frame_meter.gd`: `FrameMeter`, the measuring rule.
- `wander_crowd.gd`: `WanderCrowd`, meeples that walk about at random.
- `stress_art.gd`: `StressArt`, the static sprites these scenes use, with the jam game's regions and offsets.
- `art/town_hall.png`: a copy of the Town Hall sheet from `ART/`, which game files may not use.
- `pictures/`: the pictures for pull requests. Godot does not import this folder.
