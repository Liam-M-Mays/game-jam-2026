# game/dev/effects_demo/

**What lives here:** the demo of the [effects toolkit](../../../addons/effects/README.md), and the scene that compares every effect with the jam game. Dev only. Nothing here goes into the export.

Built by #62.

## The scenes

| Scene | What it does |
| --- | --- |
| `effects_demo.tscn` | Every effect on trees, huts and meeples, on the keys. Open it and press F6 |
| `effects_compare.tscn` | Draws each effect with the jam game's own scenes and with the toolkit, at the same moment, and counts the pixels that differ |

Both need a window. They do not run in CI.

## The demo

Open `effects_demo.tscn` in Godot and press F6. The keys are also listed on screen.

Every effect key plays on all the actors at once: two trees, a finished hut, a building site, a standing meeple and a walking one.

| Key | What it does |
| --- | --- |
| H | A hit: squash, white flash and wobble |
| L | The last hit: squash, and it stays white |
| F | Flash |
| R | A refused action: red flash and a shake |
| Q, W, P | Squash, wobble, pop |
| G | Grow in from a flat sliver |
| O | Selected outline on and off |
| Y | The yellow outline of a paused building site |
| B | Blueprint ghost on and off |
| N | Ghost blocked (red) on and off |
| K | Sparks on the trees |
| C | Dust cloud over the huts |
| [ and ] | The stage of the building site. The next stage shows as a ghost behind it |
| M | Placing mode: the cells round the mouse light up, and a plot area shows in pale yellow with white under the mouse |
| Mouse | Hover glow on the actor under the mouse, and its cells light up |
| Z | Hover glow on every actor at once |
| Space | Pause. Nothing moves |
| 1, 2, 3, 4 | Game speed x1, x1.5, x2, x3. Effects get faster |

To look at it next to the jam game: run the jam game (`Main_Menu.tscn`, F5) in a second Godot window and do the same thing in both. Click a tree for the hit, click a claimed tree for the refusal, hover things, place a building.

A picture from a terminal:

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/effects_demo/effects_demo.tscn" -- shot=/full/path.png keys=H,O at=0.04
```

It presses those keys, waits that many seconds of game time, saves the picture and closes.

## The comparison

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/effects_demo/effects_compare.tscn" -- quit=1
```

- Each pose is built twice. Left: the jam game's own scenes and scripts (`tree.tscn`, `hut_build.tscn`, `cell.tscn`, the two effect scenes), with their real tweens stopped at the moment of the pose. Right: the same things in the sprite batch, with the toolkit.
- Each pose is a 640 by 360 picture at 8 screen pixels for one art pixel, the size the jam game's camera shows.
- `pictures/<pose>_reference.png` is the jam game's picture. It is the reference, so the toolkit can still be checked after the jam game is gone.
- Two pixels count as the same when no colour channel is more than 2 of 255 apart. The run also prints how many pixels are that slightly apart.
- It checks that the jam game's own picture still matches the saved reference. On another graphics card it may not. Then the line says so, and that is not the toolkit's fault.
- It ends with exit code 0 when every pose matches, and with 1 when one does not.
- A normal run writes no file. `save=1` writes the side-by-side pictures and the sheets. `update=1` also writes the reference pictures again from the jam game. `only=hover` runs only the poses whose name holds that text.

### The poses

All 45 poses differ in 0 pixels (Apple M3, 2026-11-11).

| Poses | What they show |
| --- | --- |
| `rest` | Nothing happens. The two draw the same picture to start with |
| `grow_in_start`, `_mid`, `_overshoot` | A tree grows in: a flat sliver at 0 s, then 0.15 s and 0.3 s |
| `hit_start`, `_early`, `_mid`, `_late` | A hit: squash, white flash and wobble at 0, 0.04, 0.1 and 0.19 s |
| `last_hit` | The hit that breaks a tree: squashed and solid white |
| `hover`, `hover_far`, `hover_close` | The hover glow and the lit cells at three zooms. The glow keeps its width on screen |
| `selected`, `selected_close`, `selected_and_hovered` | The solid outline, and the glow laid over it |
| `reject_start`, `_early`, `_mid`, `_late` | Red flash and shake on a tree and a hut at 0, 0.04, 0.1 and 0.2 s |
| `pop_top`, `pop_back` | A hut pops at 0.05 s and 0.1 s |
| `flash_on_new_stage` | A building site flashes when it gains a stage |
| `preview`, `preview_blocked`, `preview_reject` | The placement ghost in blue and in red, and refused |
| `site_empty`, `site`, `site_blocked` | A building site with the ghost of its next stage, in blue and in red |
| `site_hover`, `site_empty_hover`, `site_paused` | The outline wraps the built part and the ghost as one shape. The paused outline is yellow |
| `sparks_1`, `_2`, `_3`, `_over` | The spark burst where a tree broke. The tree in front of it covers it |
| `cloud_1`, `_2`, `_3_moved_down`, `_over` | The dust cloud over a hut, over everything. Once moved 10 art pixels down, as on the Town Hall |
| `cells_round_the_mouse` | The grey cells in a circle round the mouse |
| `cells_plot`, `cells_plot_under_preview` | Plot cells in pale yellow, and white under the preview |
| `hover_with_the_batch_moved`, `hit_with_the_batch_moved` | The same pictures with the batch node moved and drawn twice as big |
| `hit_with_a_high_effect_number` | The same picture when the tree's effect number is 5,001 |

- The comparison fails when a number is wrong. Tried on 2026-11-11: a squash of 0.2 in place of 0.15 (203 pixels), a glow that falls off in a straight line (3,363 pixels), and one wrong shake step (1,504 pixels).
- `pictures/sheet_1.png` to `sheet_8.png` show all poses, six to a sheet: the jam game left, the toolkit right.
- `pictures/demo_*.png` show the effects on meeples. The jam game has no effect on a meeple, so there is nothing to compare those with.

## The jam game's numbers

The toolkit holds no number of the game. They are here:

- `jam_effect_style.tres`: the saved numbers. Open it in the Godot Inspector to change one: how long a flash takes, the reject colour, the squash, the outline looks, the ghost colours, the cell colours.
- `jam_effects.gd`: `JamEffects`. It loads those numbers, adds the cell picture, the sparks and the cloud to an atlas, and holds the few numbers that are not in the style: the circle round the mouse, the paused outline colour, the break hold.
- `tests/test_jam_effects.gd` checks every number against the "Must keep" list of issue #62.

This is a stand-in, like `JamGrid`. The numbers need a home outside `game/dev/` once the first view of the real game uses them.

## The other files

- `art/spark.png`: a copy of the spark sheet from `ART/`, which game files may not use.
- `pictures/`: the pictures. Godot does not import this folder.
