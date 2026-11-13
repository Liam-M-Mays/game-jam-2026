# Instructions for AI agents

Mighty Meeple is a Godot 4.7.2 game (GDScript, GL Compatibility renderer). Three people work on it, and humans review every change.

**You are on the branch `rework`.** The jam game is being fixed in place so it can hold thousands of meeples. The plan is `docs/rework-plan.md`, and the parts are the sub-issues of #57. Read both before you start. Keep it small: the last attempt (branch `core-rewrite`) was rejected for being too big.

## Workflow rules

- All work goes into `rework` through pull requests. Never commit to `rework` or `master` directly.
- Cut your work from `origin/rework`, on a branch named `feature/...`, `fix/...`, `art/...` or `chore/...`. Open the pull request with `--base rework`.
- In your own worktree, name the local branch `wt/<short-name>` and push with `git push origin HEAD:<type>/<short-name>`. Liam tests a pull request by switching his own folder to its branch, and git refuses that while a worktree holds the same name.
- `master` is frozen until the rework is done. The one exception is art that only touches `ART/`.
- `core-rewrite` is an archive. Do not build on it and do not merge from it.
- A pull request says "Part of #N". Do not write a closing keyword: GitHub ignores them on this branch. The issue is closed by hand after the merge.
- Do not merge pull requests and do not approve them. Liam reviews every one.
- One pull request does one part. Aim for under 300 lines of game code. Over 500, split it.
- Another agent or person may be using the same checkout. Use your own worktree or clone for branch work, and never stash, reset or switch branches in a checkout you did not create.
- Full rules: `CONTRIBUTING.md`.
- Issue types, parents and board states: `docs/workflow.md`.
- A `feature` is a suggestion until the team agrees on it. Do not assume what it means, do not create tasks for it, and do not move it to Backlog. A `fix` goes straight to Backlog.

## How to build a part

- Change the jam code where it is. No parallel game, no new top-level folder, no `sim/` and `view/` split.
- Anything a person would tweak stays a node in a scene: the camera, the ground, the HUD, buildings. Only things there are thousands of become data: meeples, cells, trees, rocks, bushes, stored drops.
- Godot's y-sort stays. A meeple as data is drawn as one canvas item under `Grid`, so it sorts with the building nodes.
- Keep the look. A meeple, tree or building looks and moves as it does now, unless its issue says otherwise.
- Do not add tools, plugins, overlays or stress scenes that the part does not need.

## Tests

- Write a test only for a rule that can break without anyone seeing it, for example "a job goes to the nearest idle meeple". Most parts need 0 to 3.
- No tests for timings, pictures or pixel counts.
- The main proof is playing the game. The pull request says how to see the change in a few steps, with a picture or a short clip for anything visual.

## Before you open a pull request

- Run `python3 .github/ci/checks.py repo`.
- Run `GODOT="<path to Godot 4.7.2>" bash .github/ci/run_godot_checks.sh` when you changed scripts, scenes or resources.
- CI runs on a pull request, not on a push to your own branch. Run both before every push.
- Play the change in the game yourself.
- Read the diff of every `.tscn` and `.tres` you are committing. Revert any scene you did not mean to change.
- Commit the `.uid` and `.import` files Godot creates next to new scripts and assets.
- Fill in the pull request template. Run `python3 .github/ci/pr_inventory.py` after your last commit and paste what it prints into the "Inventory" section. Run it again whenever you push more commits.

## Project facts

- Main scene: `Main_Menu.tscn`. Game scene: `assets/Scenes/Levels/game.tscn`.
- Autoloads: `JobSystem`, `Inventory`, `GameState`, `Population`, `VillageAudio`, `Music`.
- Running Godot with `--script` does not load the autoloads, so most scripts fail to compile that way. Use a scene, like `.github/ci/load_check.tscn` does.
- The first import of a fresh clone prints script errors. Import twice.
- Architecture diagrams: `docs/architecture.md`. Update them in the same pull request when you change the structure.

## Code conventions

- Use static types. Match the style of the file you are editing.
- Write a `##` doc comment on every new class and every new public function.
- In code the big creature is `giant`, never `monster`.
- Game files must not reference anything under `ART/`. Art the game uses belongs in `assets/`. See `docs/art-folders.md`.
- Do not add entries to `.github/ci/known-problems.txt` to get a check to pass. Fix the problem, or ask.
