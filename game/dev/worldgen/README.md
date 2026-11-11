# game/dev/worldgen/

**What lives here:** the tools to time the world generator and to look at a world. Dev only. Nothing here goes into the export.

Built by #48.

| Scene | What it does | Needs a window |
| --- | --- | --- |
| `worldgen_timing.tscn` | Times the making of a world, three runs | no |
| `world_look.tscn` | Shows a whole world, with a map of where each kind stands | yes |
| `nature_compare.tscn` | Draws the five kinds next to the jam game's scenes and counts the pixels that differ | yes |

## The timing

```bash
"/path/to/Godot" --headless --path . "res://game/dev/worldgen/worldgen_timing.tscn"
```

- It makes a world of the size in the dev settings (100,000 cells) three times, each from another seed.
- It prints one `WORLDGEN` line per run, with the time of each step, then the slowest run, then the time to build the picture.
- The bar of issue #48 is under 500 ms for 100,000 cells on an Apple M3.
- `-- cells=2000 runs=5 seed=7` changes the size, the number of runs and the first seed.

Apple M3, 2026-11-11, **taken while other sessions were running Godot on the same Mac, so the numbers are not final.** Times in milliseconds:

| Run | Seed | Cells | Things | Total | Shape | Bands | Grid | Start | Things |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | 100,008 | 9,805 | 210.6 | 47.9 | 25.1 | 44.2 | 11.3 | 82.2 |
| 2 | 2 | 100,012 | 9,805 | 208.9 | 47.8 | 24.7 | 44.0 | 10.8 | 81.7 |
| 3 | 3 | 100,010 | 9,805 | 209.0 | 47.5 | 24.9 | 44.1 | 11.2 | 81.4 |

- The load matters. With two other Godot runs at full load, an earlier and slower version of the generator took 434 to 513 ms where it took 314 ms a few minutes before.
- The last line of the output is the time to build the picture of one such world: the atlas, the ground map and 9,805 things put into the batch. It took 195.3 ms in the same run. That is not part of making the world, and it has no bar.

## Looking at a world

Open `world_look.tscn` in Godot and press F6.

| Key | What it does |
| --- | --- |
| N | The next world, from the next seed |
| B | The bands of the noise as colours, or the flat ground |
| M | The map: every thing as a dot in the colour of its kind |
| H | The whole world, or the start cell at the game's zoom |
| WASD, arrows, mouse wheel | Move and zoom |

From a terminal, to save a picture and close:

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/worldgen/world_look.tscn" -- seed=1 map=1 shot=res://game/dev/worldgen/pictures/world_map.png
```

Other switches: `cells=100000`, `bands=1`, `at=start`, `zoom=0.8`, `label=0`.

## The comparison with the jam game

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/worldgen/nature_compare.tscn" -- quit=1
```

- Each of the five kinds stands on two cells, once drawn by the jam game's own scene and once by the sprite batch from the data files in `game/nature/kinds/`.
- It prints how many pixels differ when one picture is laid over the other. Apple M3, 2026-11-11: 0 of 2,073,600. The jam scenes drew 23,168 pixels.
- It also takes a picture with nothing in it, to prove the window was drawn anew each time. A covered window keeps its old picture, and two old pictures never differ.
- It ends with exit code 0 when no pixel differs. `save=1` writes `pictures/nature_jam_vs_new.png`.
- It needs the jam game's scenes in `assets/Scenes/Resources/`. When the old game is removed (#36), this scene goes with it.

## The pictures

`pictures/` holds the pictures for pull requests. Godot does not import this folder.

| Picture | What it shows |
| --- | --- |
| `world_whole.png` | The whole world of seed 1, as the game draws it |
| `world_map.png` | The same world as a map: the two bands, and a dot for every thing |
| `world_map_seed_2.png` | The map of seed 2, to see that another seed gives another world |
| `world_start.png` | The start cell of seed 1 at the game's zoom, with the cells kept clear |
| `game_scene.png` | What `game/game.tscn` shows when it starts. This one drew seed 755830092 |
| `nature_jam_vs_new.png` | The five kinds, the jam game's scenes on the left and the new data files on the right |
