# Instructions for AI agents

Mighty Meeple is a Godot 4.7.2 game (GDScript, GL Compatibility renderer). Three people work on it, and humans review every change.

**`master` is the reworked game.** The jam game was fixed in place so it can hold thousands of meeples (the rework, `docs/rework-plan.md` and #57), and it became `master` on 2026-11-17. The jam build as it was is kept on the branch `jam-v1`. Keep changes small: the earlier attempt (branch `core-rewrite`) was rejected for being too big.

## Workflow rules

- All work goes into `master` through pull requests. Never commit to `master` directly.
- Cut your work from `origin/master`, on a branch named `feature/...`, `fix/...`, `art/...` or `chore/...`.
- In your own worktree, name the local branch `wt/<short-name>` and push with `git push origin HEAD:<type>/<short-name>`. Liam tests a pull request by switching his own folder to its branch, and git refuses that while a worktree holds the same name.
- `jam-v1`, `rework` and `core-rewrite` are archives. Do not build on them and do not merge from them.
- A pull request names its issue: "Closes #N" when it finishes it, "Part of #N" when it does one piece.
- Do not merge pull requests and do not approve them. Liam reviews every one.
- One pull request does one thing. Keep it as simple as the change allows. There is no line limit.
- Another agent or person may be using the same checkout. Use your own worktree or clone for branch work, and never stash, reset or switch branches in a checkout you did not create.
- Full rules: `CONTRIBUTING.md`.
- Issue types, parents and board states: `docs/workflow.md`.
- A `feature` is a suggestion until the team agrees on it. Do not assume what it means, do not create tasks for it, and do not move it to Backlog. A `fix` goes straight to Backlog.

## How to build a change

- Change the code where it is. No parallel game, no new top-level folder, no `sim/` and `view/` split.
- Anything a person would tweak stays a node in a scene: the camera, the ground, the HUD, buildings. Only things there are thousands of become data: meeples, cells, trees, rocks, bushes, and drops, both loose and stored.
- Godot's y-sort stays. A meeple as data is drawn as one canvas item under `Grid`, so it sorts with the building nodes.
- Keep the look. A meeple, tree or building looks and moves as it does now, unless its issue says otherwise.
- Do not add tools, plugins, overlays or stress scenes that the change does not need.

## Tests

- Write a test only for a rule that can break without anyone seeing it, for example "a job goes to the nearest idle meeple". Most changes need 0 to 3.
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

- Main scene: `Main_Menu.tscn`. Game scenes: `assets/Scenes/Levels/game.tscn` (on the giant) and `assets/Scenes/Levels/ground.tscn` (the round ground world). The main menu opens either one. Play every change in both.
- `assets/Scenes/game.tscn`, `assets/Scenes/main.tscn` and `assets/Scenes/Levels/main.tscn` are old jam scenes. The game never opens them, and the first two do not load. Do not edit them by mistake.
- Autoloads: `Settings`, `SceneFader`, `InputMode`, `JobSystem`, `Inventory`, `GameState`, `Population`, `VillageAudio`, `Music`. Settings are saved to `user://settings.cfg`.
- Running Godot with `--script` does not load the autoloads, so most scripts fail to compile that way. Use a scene, like `.github/ci/load_check.tscn` does.
- The first import of a fresh clone prints script errors. Import twice.
- Architecture diagrams: `docs/architecture.md`. Update them in the same pull request when you change the structure.

## Code conventions

- Use static types. Match the style of the file you are editing.
- Write a `##` doc comment on every new class and every new public function.
- In code the big creature is `giant`, never `monster`.
- Game files must not reference anything under `ART/`. Art the game uses belongs in `assets/`. See `docs/art-folders.md`.
- Do not add entries to `.github/ci/known-problems.txt` to get a check to pass. Fix the problem, or ask.
