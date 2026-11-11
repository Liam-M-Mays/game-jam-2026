# The rework plan

**The short version:** we keep the jam game and fix it in place. We do not rewrite it. Meeples, cells, trees and drops stop being one node each, so the game can hold thousands of meeples. Then the village moves to a generated ground world, and the open fixes and playtest points go in. Every pull request is small enough to review in about 20 minutes.

Issue #57 tracks the parts. This page says how we work.

## Why the plan changed (2026-11-11)

- The first attempt (branch `core-rewrite`) re-built the whole game next to the old one.
- It reached about 5,000 lines of code, more than the whole jam game (about 3,700), and it could not play the game yet. Its four open pull requests were 3,500 to 6,000 lines each.
- The jam game is simple and mostly works. It needs fixes, and it needs to stop making a node for every meeple, cell, tree and drop.
- `core-rewrite` stays on GitHub as an archive. Nothing from it is merged into this rework. A part may copy a small piece from it, for example the test runner, and says so.

## What done means

Liam's list from 2026-11-10, kept as it was:

- The same game as the jam build, on a generated ground world.
- The city building stays very similar.
- Roles replace idle jobs.
- The open fixes are in.
- The playtest points that do not transform the game are in.
- All assets and the giant scene stay in the project.
- The village also runs on the giant's back, as it does today. **Required before the switch** (#76).

The bar: **5,000 meeples at 60 frames a second** on Liam's Mac, on the ground world (#61).

Not part of this: giants walking by, second villages, a world map, animals, roads, new ores, an ending after the statue, baby meeples, seasons, rivers, enemies, a settings menu, lighting, saving.

## Liam's earlier answers still count

Every "Decided by Liam" line in the issues still holds, unless the list "Changed on purpose" below names it. The answers that sat in issues that are now closed (#59 to #76) moved into the issues that still need them, mostly #89 (small decided changes).

## How it works, in one picture

```text
game.tscn (the jam scene, on the giant)       ground.tscn (new, part 8)
        └── Grid (y-sorted, the same grid.gd) ─────────┘
              ├── buildings      stay real scenes you can open
              ├── meeples        plain data, each drawn as one canvas item
              ├── loose drops    plain data, each drawn as one canvas item
              ├── trees, rocks   plain data, drawn one row at a time
              └── cells          plain data, no node and no Area2D each
```

- **Godot still sorts what is in front.** A canvas item under `Grid` with z index 1 sorts in front of and behind a building node by its y, like a node would. Checked on 2026-11-11.
- **The autoloads stay:** `JobSystem`, `Inventory`, `GameState`, `Population`. The HUD and the menus read counts from them and keep working.
- **Scenes stay the source.** A building, a tree, a meeple or a drop still has its scene. The game reads the look from it. Change the scene to change the look.
- **One thing at a time is a real node.** A tree that is hovered, hit or growing becomes its real scene for that moment, so the outline, wobble and flash work as today.
- **The numbers we have** (#14, Liam's Mac): 5,000 meeples as canvas items took 8.0 ms a frame. Godot's sort slowed down past about 16,000 sorted items: 5,000 meeples plus 20,000 single things took 23.4 ms. Drawing trees by row keeps the count far below that.

## The parts

Each line is one pull request into `rework`. "After" names the parts that must be merged first.

| # | Part | Issue | After | Rough size |
| --- | --- | --- | --- | --- |
| 1 | Setup: the `rework` branch, this plan, the rules | #57 | | docs |
| 2 | Meeples as data, drawn as canvas items. Bounce out of step, same walk speed | #90 | 1 | 250 to 350 |
| 3 | Jobs and idle meeples find the nearest. No job limit. The job signal fires once a frame | #91 | 2 | 150 to 200 |
| 4a | Roles: worker slots on buildings replace idle jobs | #7 | 3 | about 250 |
| 4b | Roles: the building panel with the arrows | #7 | 4a | about 150 |
| 5a | Stored drops become counts. The stock signal fires once a frame | #14 | 2 | 200 to 300 |
| 5b | Loose drops as data. Measure 5,000 meeples in the jam scene | #14 | 4a, 5a | about 150 |
| 6 | Cells as data: no node and no Area2D per cell | #92 | 2 | 150 to 200 |
| 7a | Trees and rocks as data, drawn by row | #93 | 6 | about 250 |
| 7b | Bushes as data | #93 | 7a | about 100 |
| 8a | The ground world: a round world, the jam's dark and light ground, trees by area, a menu entry | #48 | 7b | about 200 |
| 8b | The ground camera with trackpad, the HUD and the sound on the ground. Measure again | #48 | 8a | about 150 |
| 9 | Farm and silo do not enter build mode with no room | #8 | 1 | about 20 |
| 10 | Stone hut and statue sit on their cells | #40 | 1 | a few |
| 11 | Hammer sound when a building is placed | #45 | 1 | a few |
| 12 | Wood and stone show "have / room". Drops stop vanishing | #24 | 5b | about 80 |
| 13 | Job queue: a count and "clear all" | #29 | 3 | about 40 |
| 14 | Barns: plot area kept free, then farm placing | #9 | 6, 7a, 9 | 60 to 80 |
| 15a | Remove a building | #6 | 4a, 6 | about 150 |
| 15b | Move a building | #6 | 15a | about 100 |
| 16 | Small decided changes, a few per pull request | #89 | 1 | small each |
| 17 | Finish: Liam plays both scenes, exports, one pull request into `master` | #77 | all | none |

- The sizes are rough guesses of game code. Tests and scenes are not counted.
- Parts 9, 10, 11 and 16 can go any time. The others wait for the parts in "After" because they edit the same files.
- The fastest path to something Liam can test: 2, then 6, 7a, 7b, 8a and 8b. The ground world can be played before roles are done.

## Rules for every part

- **Small.** One line of the table, one pull request. Aim for under 300 lines of game code. Over 500, split it.
- **Change the jam code in place.** Edit `grid.gd`, `meeple_movement.gd` and the rest where they are. No parallel game, no new top-level folder, no `sim/` and `view/` split.
- **Scenes you can open.** Anything a person would tweak stays a node in a scene: the camera, the ground, the HUD, buildings. Only the things there are thousands of become data.
- **Both scenes keep working.** From part 8 on, every pull request is played in the ground scene and in the giant scene.
- **Tests only where a rule can break without anyone seeing it.** For example, "a job goes to the nearest idle meeple". Most parts need 0 to 3 tests. No tests for timings, pictures or pixel counts. Part 3 brings the small test runner over from `core-rewrite`.
- **The proof is playing it.** Every pull request says how to see the change in the game in a few steps, with a picture or a short clip for anything visual.
- **No new tools unless a part needs them.** No overlays, plugins, effects kits or stress scenes up front. A dev key that spawns meeples is fine.
- **Same look.** A meeple, tree, drop or building looks and moves as it does now, unless its issue says otherwise.
- **The issue's "In the rework" section is the brief.** Older text in an issue is background.

## Measuring 60 frames a second (parts 2, 5b and 8b)

- Liam's Mac (Apple M3), a 1920x1080 window, vsync off, game speed x1, not in Low Power Mode.
- Spawn the meeples with the dev key. Wait 1.5 seconds, then measure for 4 seconds.
- Pin the window on top and check that every frame was really drawn (`Engine.get_frames_drawn()`). A covered window on macOS reports fake fast frames.
- "Holds 60" means the average frame takes 16.6 ms or less. Write down the 95th-percentile frame and the worst frame too.
- Part 2 gives a first reading at 1,000 and 5,000 wandering meeples. Part 5b measures the jam scene with real work. Part 8b measures the ground world with all meeples in view. Paste each table into #14.
- If the ground world misses the bar, the fallback is our own draw order with the sprite batch kept on `core-rewrite` (`addons/sprite_batch/`). That is a new part, decided with Liam.

## Changed on purpose

These go against an earlier answer of Liam's. Each one needs his yes.

- **Godot's y-sort, not our own draw order.** Liam asked for our own order on 2026-11-10. The y-sort is far less code, and the numbers above say it holds the bar when trees are drawn by row. The fallback is above.
- **Meeples walk straight, as in the jam game.** Path-finding (#16) and its red flash for a target that cannot be reached wait until after the rework.
- **Tools come after the rework:** the effects toolkit (#62), the building editor (#33), the debug overlay (#31) and the preset village (#32).
- **No `gdlint` check.** #59 made it a third check. The jam code is not lint-clean, and the rework edits it in place.
- **The doc rule applies to new and changed code.** A `##` comment on every new class and public function. `docs/architecture.md` is the page per system, kept up to date.
- **The jam code stays.** #36 said the old jam code goes at the end. Now the jam code is the game. Its other answers (the app name, the template settings) moved to #89.
- **The branch is `rework`, not `core-rewrite`.** Liam sets its protection rule.

## Branches

- `master`: frozen until part 17. Only art into `ART/` lands there.
- `rework`: this work. It starts at `master` as it was on 2026-11-11. Pull requests only, base `rework`.
- `core-rewrite`: the first attempt, kept as an archive. No new work goes there.
- Part 17 lands as one pull request from `rework` into `master`.
