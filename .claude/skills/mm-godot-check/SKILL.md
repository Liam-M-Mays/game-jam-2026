---
name: mm-godot-check
description: Run Mighty Meeple's repo checks, Godot checks, tests and linter the way CI does, and run a headless or rendered test scene without the usual traps. Use before opening a pull request, or when asked to test a change in the game.
---

# Check and test the game

**Goal:** know whether a change is safe, and say plainly what was and was not run.

## Steps

1. Find Godot 4.7.2, the standard build. If the editor is running, `ps -axo command | grep -i godot` shows its path. If you cannot find it, ask.
2. Run the repo checks. They take a second.

   ```bash
   python3 .github/ci/checks.py repo
   ```

3. If scripts, scenes or resources changed, run the Godot checks. They take from half a minute to a few minutes.

   ```bash
   GODOT="<path to Godot>" bash .github/ci/run_godot_checks.sh
   ```

4. If GDScript in `game/` or `addons/` changed, run the linter. It needs `gdlint` (`pipx install "gdtoolkit==4.5.0"`).

   ```bash
   bash .github/ci/run_lint.sh
   ```

5. The Godot checks run the tests of the new game as their last step. While you work, run only the tests. `docs/testing.md` says how to write one.

   ```bash
   GODOT="<path to Godot>" bash .github/ci/run_tests.sh
   ```

6. To try something the tests cannot cover, write a temporary scene and its script in a folder whose name starts with a dot, such as `res://.tmp_test/`. Godot's importer skips dot folders, but a scene in one still loads by its path. Run it with no window and send the output to a file:

   ```bash
   "<path to Godot>" --headless --path . --quit-after 300 res://.tmp_test/test.tscn > out.log 2>&1
   ```

7. To test anything visual, render for real, because a headless run draws nothing. Run the scene without `--headless` and with `--rendering-driver opengl3`. Have the scene save `get_viewport().get_texture().get_image()` as a PNG and then quit. Look at the picture yourself before you show it to anyone.
8. Delete the temporary folder. Run `git status` and make sure nothing from it is left.
9. Report what ran, what passed, and what was not checked.

## Traps

- **macOS has no `timeout` command.** `timeout 30 godot ...` fails with "command not found", which is easy to read as a pass. Use `--quit-after <frames>`.
- **`--script file.gd` does not load the autoloads.** A script that touches `Inventory`, `JobSystem` or another autoload fails to compile that way. Always run a scene.
- **The exit code is not a result.** Godot exits with 0 even when a script failed to compile. Read the log for `ERROR` and `SCRIPT ERROR` lines.
- **Send output to a file.** A pipe into `grep` hides the output when Godot hangs.
- **A script error does not quit the game.** Give every test scene a timer that calls `get_tree().quit()`, so a broken test cannot run forever.
- **A window in the background draws slowly, or not at all.** Keep a rendered test under 100 frames, and call `RenderingServer.force_draw(false)` before reading the viewport image.
- **The Godot editor may be open on the project.** When it saves, it writes back its own copy of an open scene and can undo an edit you made to the `.tscn` on disk. Search for your change again before you trust a test result.
- **The first import of a fresh clone prints "Could not resolve class" errors.** Import twice. The CI script does.
- **Never add a line to `.github/ci/known-problems.txt` to make a check pass.** Fix the problem, or ask.
