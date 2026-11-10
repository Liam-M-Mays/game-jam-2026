# Instructions for AI agents

Mighty Meeple is a Godot 4.7.2 game (GDScript, GL Compatibility renderer). Three people work on it, and humans review every change.

## Workflow rules

- Never commit to `master`. Work on a branch named `feature/...`, `fix/...`, `art/...` or `chore/...` and open a pull request.
- Do not merge pull requests and do not approve them. A human does that.
- One pull request does one thing. Do not mix a refactor with a feature.
- Another agent or person may be using the same checkout. Use your own worktree or clone for branch work, and never stash, reset or switch branches in a checkout you did not create.
- Full rules: `CONTRIBUTING.md`.
- Issue types, parents and board states: `docs/workflow.md`.
- A `feature` is a suggestion until the team agrees on it. Do not assume what it means, do not create tasks for it, and do not move it to Backlog. A `fix` goes straight to Backlog.

## Before you open a pull request

- Run `python3 .github/ci/checks.py repo`.
- Run `GODOT="<path to Godot 4.7.2>" bash .github/ci/run_godot_checks.sh` when you changed scripts, scenes or resources.
- Read the diff of every `.tscn` and `.tres` you are committing. Revert any scene you did not mean to change.
- Commit the `.uid` and `.import` files Godot creates next to new scripts and assets.
- Fill in the pull request template, including how a human can test the change in the game.

## Project facts

- Main scene: `Main_Menu.tscn`. Game scene: `assets/Scenes/Levels/game.tscn`.
- Autoloads: `JobSystem`, `Inventory`, `GameState`, `Population`, `DevSpeed`, `VillageAudio`, `Music`.
- Running Godot with `--script` does not load the autoloads, so most scripts fail to compile that way. Use a scene, like `.github/ci/load_check.tscn` does.
- The first import of a fresh clone prints script errors. Import twice.
- Architecture diagrams: `docs/architecture.md`. Update them in the same pull request when you change the structure.

## Code conventions

- Comments in GDScript are allowed. The earlier "no comments" rule was only there to save time during the game jam. How the code gets documented is being worked out in issue #22.
- Use static types. Match the style of the file you are editing.
- Game files must not reference anything under `ART/`. Art the game uses belongs in `assets/`. See `docs/art-folders.md`.
- Do not add entries to `.github/ci/known-problems.txt` to get a check to pass. Fix the problem, or ask.
