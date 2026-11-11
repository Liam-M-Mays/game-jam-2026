# Instructions for AI agents

Mighty Meeple is a Godot 4.7.2 game (GDScript, GL Compatibility renderer). Three people work on it, and humans review every change.

**You are on the branch `core-rewrite`.** The core of the game is being rewritten here. The plan is issue #57, and the design is `docs/core-design.md`. Read both before you start.

## Workflow rules

- All rework goes into `core-rewrite` through pull requests. Never commit to `core-rewrite` directly.
- Cut your work from `origin/core-rewrite`, on a branch named `feature/...`, `fix/...`, `art/...` or `chore/...`. Open the pull request with `--base core-rewrite`.
- `master` is frozen until the rework is done. Nothing from this branch goes there. The one exception is art that only touches `ART/`, which follows the rules in the copy of `CONTRIBUTING.md` on `master`.
- A pull request says "Part of #N". Do not write a closing keyword: GitHub ignores them on this branch. The issue is closed by hand after the merge.
- Do not merge pull requests and do not approve them. Liam reviews every one.
- A core pull request may be big. Parts are preferred. A big one comes with a short walkthrough, a demo scene and tests. Once the core works, one pull request does one thing again.
- Another agent or person may be using the same checkout. Use your own worktree or clone for branch work, and never stash, reset or switch branches in a checkout you did not create.
- Full rules: `CONTRIBUTING.md`.
- Issue types, parents and board states: `docs/workflow.md`.
- A `feature` is a suggestion until the team agrees on it. Do not assume what it means, do not create tasks for it, and do not move it to Backlog. A `fix` goes straight to Backlog.

## Before you open a pull request

- Run `python3 .github/ci/checks.py repo`.
- Run `GODOT="<path to Godot 4.7.2>" bash .github/ci/run_godot_checks.sh` when you changed scripts, scenes or resources.
- CI runs on a pull request, not on a push to your own branch. So run both checks yourself before every push.
- Read the diff of every `.tscn` and `.tres` you are committing. Revert any scene you did not mean to change.
- Commit the `.uid` and `.import` files Godot creates next to new scripts and assets.
- Fill in the pull request template. List every "done" line of the issue that the pull request claims, each with the test or the picture that proves it.

## Where code goes

- New code goes in `game/` and `addons/`. `game/` has one folder per feature. Each folder has a `README.md` that says what lives there.
- The old jam game is in `assets/` and the scripts in the project root. Leave it as it is. Issue #36 removes it at the end.
- The old global scripts stay quiet in new scenes. `OldGame.is_running()` in `assets/Scripts/Dev/old_game.gd` is the guard. New code must not call the old globals.
- Inside a feature folder, simulation code goes in a `sim/` folder and picture code in a `view/` folder.
    - A file in `sim/` holds data and rules. It must run with no window. It never touches a node, the camera, the mouse, a sprite, a tween or a sound.
    - A file in `view/` reads the simulation and draws it. It never changes simulation data. It sends a command.
- Dev settings such as the world size and the tick rate: the defaults are in `game/core/dev_settings.gd`, and a changed value is saved in `game/core/dev_settings.tres`.

## Project facts

- Main scene: `Main_Menu.tscn`. Game scene: `assets/Scenes/Levels/game.tscn`. Both are the old jam game.
- Autoloads, all from the old game: `JobSystem`, `Inventory`, `GameState`, `Population`, `DevSpeed`, `VillageAudio`, `Music`.
- Running Godot with `--script` does not load the autoloads, so most old scripts fail to compile that way. Use a scene, like `.github/ci/load_check.tscn` does.
- The first import of a fresh clone prints script errors. Import twice.
- Design of the new core, with the numbered decisions: `docs/core-design.md`.
- What the jam game does, line by line, and which issue owns each line: `docs/jam-game-list.md`.
- Diagrams of the old code: `docs/architecture.md`.

## Code conventions

- Use static types.
- Write a `##` doc comment on every class and every public function. Each system also gets one short page: the `README.md` of its folder.
- In code the big creature is `giant`, never `monster`.
- GDScript only for now. The game runs on Windows and macOS. There is no browser build.
- New files use `snake_case` names.
- Game files must not reference anything under `ART/`. Art the game uses belongs in `assets/` or `game/`. See `docs/art-folders.md`.
- Do not add entries to `.github/ci/known-problems.txt` to get a check to pass. Fix the problem, or ask.
