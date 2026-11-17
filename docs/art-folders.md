# The two art folders

**The rule:** art the game uses lives in `assets/`. Everything else lives in `ART/`: source files, work in progress, unused art, store-page art.

**Why:** if nothing in the game points at `ART/`, a change there cannot break the game. That lets art-only pull requests skip review and merge by themselves.

## Where it stands today

The split is not finished yet.

- 28 of the 50 files in `ART/` are used by scenes, so `ART/` is still a game folder and changes there get a normal review.
- CI already blocks **new** references from game files into `ART/`. The existing ones are listed in `.github/ci/known-problems.txt`.
- Godot still imports `ART/`, so it writes a `.import` file next to each image there when someone opens the project. CI does not ask for those files in `ART/`, so art can be uploaded on GitHub without opening Godot.

## Finishing the split

This is one pull request. It moves files and changes paths, nothing else.

1. Move the 28 used files, each with its `.import` file, into `assets/Art/`. Keeping the `.import` file keeps the file's ID, so scenes keep working.
2. Update the `res://ART/...` paths in the scenes and resources that use them.
3. In `Main_Menu.tscn` and `assets/Art/UI/mainmenuatlas.tres`, replace the five references to `res://.godot/imported/...ctex` with the PNG itself. Those point into Godot's cache and break as soon as the PNG moves.
4. Add an empty file named `ART/.gdignore`, and delete the `.import` files left in `ART/`. From then on Godot ignores the folder.
5. In `.github/CODEOWNERS`, add a line that says only `/ART/` below the `*` line. A path with no owner needs no review.
6. Delete the fixed lines from `.github/ci/known-problems.txt`. CI lists them for you.

Then the repo owner changes two settings on GitHub:

- **Settings, Rules, Rulesets, "Protect master":** set required approvals to 0 and turn on "Require review from Code Owners". Every file except `ART/` has owners, so everything else still needs an approval.
- **Settings, General:** turn on "Allow auto-merge".

## After that: the art lane

The workflow `.github/workflows/art-lane.yml` switches itself on when `ART/.gdignore` exists on master. Adding art then works like this:

1. On GitHub, open the `ART/` folder and choose **Add file, Upload files**.
2. Drop the files in and choose **Create a new branch and start a pull request**.
3. Press **Create pull request**.

If the pull request only touches `ART/` and comes from a team member, it is labelled `art-only` and merges by itself once the checks pass. If it touches anything else, it waits for a normal review.

## The files in `ART/` today

### Used by the game (28)

| File | Used by |
| --- | --- |
| `ART/Backgrounds.png` | `ART/sky_sprites_mountains1.tres` |
| `ART/Farm_food_growing_ass_bih.png` | `assets/Scenes/Buildings/farm.tscn` |
| `ART/GAMEOVER_text.png` | `assets/hud.tscn` |
| `ART/George_Bush.png` | `assets/Scenes/Resources/george_bush.tscn` |
| `ART/Meeple_holding_shizz.png` | `assets/Res/rocks.tres`, `assets/Res/wood.tres` |
| `ART/Mighty_meeple_logo_andbutons.png` | `Main_Menu.tscn` |
| `ART/Silo_build.png` | `assets/Scenes/Buildings/silo.tscn` |
| `ART/Spark_Spritesheet.png` | `assets/Scenes/Effects/break.tscn` |
| `ART/Townhall_upgrades.png` | `assets/Scenes/Buildings/town_hall.tscn` |
| `ART/Windmill_build.png` | `assets/Scenes/Buildings/windmill.tscn` |
| `ART/barn_build.png` | `assets/Scenes/Buildings/barn.tscn` |
| `ART/build_button_thesequal.png` | `assets/Art/UI/buildbutton.tres`, `assets/hud.tscn` |
| `ART/erection_sheet.png` | `assets/Scenes/Buildings/statue.tscn` |
| `ART/green.tres` | `assets/Scenes/Levels/game.tscn`, `assets/Scenes/Test/Brady_Scene.tscn`, `assets/Scenes/Test/Mason Scene.tscn` and 1 more |
| `ART/lumberjack_build.png` | `assets/Scenes/Buildings/lumberjack.tscn` |
| `ART/minor_build.png` | `assets/Scenes/Buildings/miner.tscn` |
| `ART/new_big_ol_hut_diddy.png` | `assets/Scenes/Buildings/stone_hut.tscn` |
| `ART/new_hut_build.png` | `assets/Scenes/Buildings/small_hut.tscn` |
| `ART/questionmark.png` | `assets/Scenes/Buildings/statue.tscn` |
| `ART/retry_button_thesequal.png` | `assets/Art/UI/retrybutton.tres`, `assets/hud.tscn` |
| `ART/shi.png` | `Main_Menu.tscn`, `assets/hud.tscn` |
| `ART/sky_sprites_mountains1.tres` | `Main_Menu.tscn`, `assets/Scenes/Levels/game.tscn`, `assets/Scenes/Test/Brady_Scene.tscn` and 2 more |
| `ART/sky_sprites_mountains2.tres` | `Main_Menu.tscn`, `assets/Scenes/Levels/game.tscn`, `assets/Scenes/Test/Brady_Scene.tscn` and 2 more |
| `ART/sky_sprites_sky.tres` | `Main_Menu.tscn`, `assets/Scenes/Levels/game.tscn`, `assets/Scenes/Test/Brady_Scene.tscn` and 2 more |
| `ART/sky_sprites_trees1.tres` | `Main_Menu.tscn`, `assets/Scenes/Levels/game.tscn`, `assets/Scenes/Test/Brady_Scene.tscn` and 2 more |
| `ART/sky_sprites_trees2.tres` | `Main_Menu.tscn`, `assets/Scenes/Levels/game.tscn`, `assets/Scenes/Test/Brady_Scene.tscn` and 2 more |
| `ART/stone_pile_sheet.png` | `assets/Scenes/Buildings/stone_pile.tscn` |
| `ART/wood_pile_sheet.png` | `assets/Scenes/Buildings/wood_pile.tscn` |

### Not used by anything (22)

- `ART/Erection.png`
- `ART/Itchpageart.png`
- `ART/Meeple_holding_moreshizz.png` (the meeple scene stopped using it in the rework)
- `ART/Mighty_meeple_logo.png`
- `ART/Mighty_meeple_logo_shadow.png`
- `ART/Other_UI_Stuff.aseprite`
- `ART/Other_UI_Stuff.png`
- `ART/Stone_house_build.png`
- `ART/big_gay_rocks.png`
- `ART/build_stone_storage.png`
- `ART/build_wood_storage.png`
- `ART/fuh_u_n_yo_big_ass_dih_liam.png`
- `ART/notif_sprite.png`
- `ART/questionmark.gif`
- `ART/shi.aseprite`
- `ART/fence.png`
- `ART/paths.png`
- `ART/sheep_pig.png`
- `ART/Aseprite files/big_stone_guy.aseprite`
- `ART/Aseprite files/mighty_meeple_logo.aseprite`
- `ART/Aseprite files/statue_build.aseprite`
- `ART/Aseprite files/storage_build.aseprite`
