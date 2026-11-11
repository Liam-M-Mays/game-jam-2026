# game/dev/stock_demo/

**What lives here:** the demo for #63. One village with a stock. Drops lie where they fell, and the stock numbers change while you watch.

Dev only. Nothing here goes into the export.

## Run it

Open `stock_demo.tscn` in Godot and press F6.

| Key | What it does |
| --- | --- |
| Left click | Drops one wood at the mouse |
| Right click | Drops one stone at the mouse |
| B | Drops 1,000 at once, half wood and half stone |
| H | Turns hauling off and on. While it is off, drops only pile up and stay |
| Q | Adds a silo: the food cap goes up by 20 |
| F | Picks a bush: 2 food, if it fits under the cap |
| E | Eats 5 food |
| Space | Pause and go on |
| 1, 2, 3 | Game speed x1, x2, x3 |
| R | Start again with the same seed. The same film plays again |
| WASD or arrows, mouse wheel | Move and zoom |

## What you see

- **Brown and grey bits** are wood and stone on the ground. Each lies on the spot where it fell, not on the middle of its cell. They are drawn by the sprite batch.
- **The orange cell** is a building site. It reserves a unit, and a haul claims the closest one, picks it up and hands it over.
- **The two pale cells** are a wood pile and a stone pile. A storage worker carries loose drops to them. The text says how full each is.
- **A white ring** is on a unit that a haul has claimed. **A round dot** walks to its unit. **A square** carries it.
- **The text at the top** is the stock: have and room, what lies on the ground, what is claimed, in piles, carried and reserved, and what can still be promised. The last line says how many drops the last lookup looked at.
- Meeples, buildings and trees are not here yet. `demo_work.gd` stands in for them. It only calls the stock.

## The picture comparison

```bash
"/path/to/Godot" --path . --rendering-driver opengl3 --resolution 1920x1080 "res://game/dev/stock_demo/drop_compare.tscn" -- quit=1
```

It draws the same drops twice: left with the jam game's drop scenes, right with the sprite batch. Then it counts the pixels that differ. It needs a window.

| Picture | What it shows | Pixels that differ (Apple M3) |
| --- | --- | --- |
| `ground` | 12 drops on bare ground, on whole and on odd spots, two cells with two drops | 0 of 960,000 |
| `tree` | 6 drops around a tree: above it, below it, and two on its own cell | 800 of 960,000 |

- The 800 pixels are half an art pixel of the tree trunk. The wood on the tree's own cell lies a bit higher than the foot of the tree. The jam game sorts by height and draws the trunk over that wood. The batch keeps the things of one cell in the order they came, and draws the wood over the trunk.
- The script holds both numbers. It ends with exit code 1 when a picture differs in more.
- `save=1` writes the two pictures into `pictures/`.
- The jam side is the jam game's own `wood.tscn`, `rock.tscn` and `tree.tscn`, with the script taken off, because the scripts call the old globals.

## The files

- `stock_demo.gd` and `stock_demo.tscn`: the scene. It only reads the village and draws it. Every key and click sends a command.
- `demo_work.gd`: the stand-in for nature, a building site and the meeples. It is not part of the game.
- `drop_compare.gd` and `drop_compare.tscn`: the picture comparison.
- `pictures/`: the pictures for the pull request. Godot does not import this folder.

From a terminal, `-- shot=/full/path.png` saves a picture of the demo and closes it. `after=8` sets after how many seconds, `speed=3` the game speed, `burst=5000` drops that many at the start.

Built by: #63.
