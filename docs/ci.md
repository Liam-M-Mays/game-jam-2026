# How the automatic checks work

**In one line:** every pull request runs two checks, and both have to be green before it can merge.

They also run on `master` after each merge, so a broken master shows up as a red mark on the commit.

## Repo checks (a few seconds)

Looks at files and references. It does not need Godot.

| Rule | What it catches | How to fix it |
| --- | --- | --- |
| `missing-sidecar` | A script without its `.uid` file, or an asset without its `.import` file. Files in `ART/` are skipped, so art can be uploaded without opening Godot | Open the project in Godot once and commit the file it creates |
| `orphan-sidecar` | A `.uid` or `.import` file whose source file is gone | Delete it |
| `broken-ref` | A scene, resource or script that points at a `res://` path that does not exist | Fix the path or remove the reference |
| `cache-ref` | A file that points into `res://.godot/`, Godot's private cache | Point it at the source file |
| `art-boundary` | A game file that uses something under `ART/` | Move the file into `assets/`, see [art-folders.md](art-folders.md) |
| `conflict-marker` | Leftover `<<<<<<<` or `>>>>>>>` lines from a merge | Resolve the conflict properly |
| `large-file` | A file over 20 MB (it warns from 5 MB) | Compress it, or talk to the team about Git LFS |
| `codeowners` | `.github/CODEOWNERS` is missing or has no `*` line | Restore it |

## Godot checks (a few minutes)

Runs the real engine, with no window, in five steps:

1. **Import twice.** The first pass builds Godot's class cache and is allowed to print errors. The second pass has to be clean.
2. **Load everything.** Every script, scene, resource and shader is loaded, and every scene is instantiated. A script that does not compile or a scene with a missing piece fails here.
3. **Boot the entry scenes.** The scenes listed in `.github/ci/entry-scenes.txt` run for a few seconds: the main menu, the giant (`game.tscn`) and the ground world (`ground.tscn`). Any script error fails the check.
4. **Run the tests.** `assets/Scripts/Dev/test_runner/run_tests.tscn` runs every `test_*.gd` file under `assets/` that extends `GameTest`. A failing test fails the check. See [Tests](#tests) below.
5. **Read the logs.** `checks.py` turns Godot's log files into a pass or a fail. The logs are attached to the run as `godot-logs`.

## The known-problems list

Master had some problems on the day CI was added. They are written down in `.github/ci/known-problems.txt` so the checks could start green.

- A problem **on the list** is tolerated.
- A **new** problem fails the check.
- A problem that is on the list but **no longer happens** also fails the check, and tells you which line to delete. That way the list can only get shorter.

Do not add lines to get a pull request through. If something truly has to wait, say so in the pull request and let the reviewer decide.

## Run them yourself

```bash
python3 .github/ci/checks.py repo
```

```bash
GODOT="/path/to/Godot" bash .github/ci/run_godot_checks.sh
```

## What the checks do not catch

They catch broken files. They do **not** catch a game that loads fine but plays wrong.

- A button that was hidden by accident still loads without errors.
- A balance change, a wrong sprite or a job that never finishes all pass.

So a human still plays the change before approving. A few rule tests cover rules that can break without an error (see [Tests](#tests)), but they do not play the game.

## Tests

A test is a file named `test_<rule>.gd` in a `tests/` folder next to the code it tests, for example `assets/Scripts/Jobs/tests/test_job_matching.gd`. It extends `GameTest` (`assets/Scripts/Dev/test_runner/game_test.gd`), and every method whose name starts with `test_` is one test.

Run all of them, or only the files whose path holds a text:

```bash
GODOT="/path/to/Godot" bash .github/ci/run_tests.sh
```

```bash
GODOT="/path/to/Godot" bash .github/ci/run_tests.sh --only=job_matching
```

## Other automation

| Workflow | What it does |
| --- | --- |
| `labeler.yml` | Adds `area/...` labels to a pull request from the files it touches, so a reviewer sees at a glance whether scenes are involved |
| `art-lane.yml` | Lets art-only pull requests merge themselves. Switched off until the art folders are split, see [art-folders.md](art-folders.md) |

## Changing the setup

| To change | Edit |
| --- | --- |
| The Godot version CI uses | `GODOT_VERSION` in `.github/workflows/ci.yml` |
| Which scenes get booted | `.github/ci/entry-scenes.txt` |
| The rules themselves | `.github/ci/checks.py` |
| Who can merge what | GitHub, **Settings, Rules, Rulesets** (repo owner only) |
