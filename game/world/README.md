# game/world/

**What lives here:** the ground world and the generator that makes it from noise maps.

A world is made once, when a game starts, from one seed. It is round with an uneven edge. Its cells go into the village grid, and its trees, rocks and bushes are placed by the bands of the noise.

## The files

| File | What it is |
| --- | --- |
| `ground_recipe.tres` | The saved numbers of the ground world: the band table and the amounts. Open it in the Godot Inspector to change one |
| `world_seed.gd` | `WorldSeed`: picks the seed of a new game and words the console line |
| `sim/world_generator.gd` | `WorldGenerator`: makes the world. Start reading here |
| `sim/ground_world.gd` | `GroundWorld`: what the generator decided. It hangs on the village as the part `world` |
| `sim/world_recipe.gd` | `WorldRecipe`: the script of `ground_recipe.tres`, with the default numbers |
| `sim/world_band.gd` | `WorldBand`: one row of the band table |
| `view/ground_layer.gd`, `view/ground.gdshader` | The ground picture: one rectangle, drawn by a shader |
| `view/world_things_layer.gd` | Puts the trees, rocks and bushes into the sprite batch |

## Using it

```gdscript
var village := Game.new_village(world_seed)            # or Village.new(seed) in a test
var world := WorldGenerator.generate(village, 100000)   # about 100,000 cells
world.start_cell                                        # where the Town Hall goes (#69)
world.is_kept_clear(cell)                               # regrowth has to ask this (#66)
GroundWorld.of(village)                                 # the same world, from anywhere
```

## How a world is made

Six steps, in `WorldGenerator`:

1. **Shape.** A circle whose edge moves in and out with a noise. The noise is read once per direction, so the world is one piece with no holes and no islands. The radius is set so that the uneven shape still has the number of cells that was asked for. 100,000 asked gives 99,995 to 100,012 (seeds 1 to 5).
2. **Bands.** A second noise gives every cell a value. The cells are cut by how dark they are: the darkest quarter is the dark band, the rest is the light band.
3. **Grid.** Every cell goes into the village grid. The ground kind of a cell is its band: 1 is dark, 2 is light.
4. **Start.** The start cell is the lightest spot of the noise near the middle of the world. The cells of the start building and the ring round them are kept clear.
5. **Things.** Trees, rocks and bushes are placed band by band.
6. **Finish.** The `GroundWorld` is hung on the village.

## The band table

The band table is the `bands` list in `ground_recipe.tres`, from the darkest band to the lightest.

| Band | Share of the cells | Kinds that may stand there | Colour |
| --- | --- | --- | --- |
| `dark` | 25% | big tree, big rock | the jam game's dark green |
| `light` | the rest, 75% | tree, rock, bush | the jam game's light green |

- A band is a share of the cells, not a fixed noise value. So every world has room for its big trees and rocks, whatever the seed and the size.
- A thing only stands where every cell of its footprint is on a band that allows its kind.
- The ground is drawn in one flat colour, the jam game's base green. The band colours are for a debug view.
- Adding a band is one more row. A kind that may stand in two bands is split by the size of those bands.

## The amounts

`amounts` in `ground_recipe.tres` holds the jam map's targets, counted on its 2,091 cells: 60 trees, 60 rocks, 34 big trees, 15 bushes, 36 big rocks. A bigger world gets more of each, so every kind keeps its share. A world of 100,008 cells holds 2,870 trees, 2,870 rocks, 1,626 big trees, 717 bushes and 1,722 big rocks.

A band that is full ends the placing early. `world.placed` and `world.wanted` say how many of each kind stand and how many were wanted. Nothing is retried later.

## The seed

- `WorldSeed.pick(fixed_seed)` gives the fixed seed, or a new random one from 1 to 2,147,483,647 when the fixed seed is 0.
- The fixed seed is the dev setting `world_seed` in `game/core/dev_settings.tres`. It is 0, so every new game gets a new world.
- The game scene prints `World seed: <number>` to the console, as the jam game did.
- One seed drives everything. The band noise takes the seed, the edge noise takes the seed plus one, and every roll of the placing comes from `village.rng`.
- Choosing the start cell rolls nothing. The same ground gives the same start cell.

## The start

- The start cell is the first cell of the start building. The Town Hall of the jam game takes 2 cells in one row.
- It is the lightest spot of the noise within a third of the radius from the middle. That is the middle of a light area.
- Its own cells and the ring one step round them must all be on the light band. When no spot near the middle fits, the whole world is searched. When nothing fits at all, the world starts on its middle cell.
- Those 10 cells are kept clear. `world.keep_clear` lists them and `world.is_kept_clear(cell)` asks for one. They are not reserved in the grid, so a building may stand there, as in the jam game.

## The picture

- `GroundLayer` draws the ground behind the batch. Its shader finds the cell under each pixel with the same maths as `GridLayout.cell_under`. So a pixel is ground exactly where a click finds a cell.
- `ground_layer.show_bands = true` draws each band in its own colour.
- `WorldThingsLayer` puts every tree, rock and bush into the batch once, under the number the village grid knows it by.
- Both are picture layers of the village. The list of layers is in `game/village/view/village_layers.gd`.

## Limits

- The rows of trees, rocks and bushes in `GroundWorld` are the world as it was made. Nothing chops or regrows yet. The nature part (#66) takes the rows over, and has to ask `is_kept_clear` before it plants.
- The ground picture reads the grid once, at the start. A ground kind that changes later is not drawn again.
- A world is one piece because of how the edge is made. Lakes and islands would need another shape step.
- Two machines can differ in the last digit of a noise value, so a cell on the very edge or on a band border may differ between Windows and macOS for the same seed. On one machine the same seed always gives the same world.

## See it

- The game scene: open `game/game.tscn` in Godot and press F6.
- The whole world, with a map of where each kind stands: `game/dev/worldgen/world_look.tscn`. See [its page](../dev/worldgen/README.md).

## Tests

`tests/`: `test_world_shape.gd`, `test_world_bands.gd`, `test_world_start.gd`, `test_world_things.gd`, `test_world_recipe.gd`, `test_ground_layer.gd`. `world_test_kit.gd` is what they share. Run them with `bash .github/ci/run_tests.sh --only=game/world`.

Built by: #48. The rules for this folder are in [game/README.md](../README.md).
