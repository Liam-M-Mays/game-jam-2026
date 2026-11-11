# How the automatic checks work

**In one line:** every pull request runs three checks, and all of them have to be green before it can merge.

They also run on `master` and on `core-rewrite` after each merge, so a broken branch shows up as a red mark on the commit.

They do not run when you push to your own branch. Run both yourself before every push.

## Repo checks (a few seconds)

Looks at files and references. It does not need Godot.

| Rule | What it catches | How to fix it |
| --- | --- | --- |
| `missing-sidecar` | A script without its `.uid` file, or an asset without its `.import` file. Files in `ART/` are skipped, so art can be uploaded without opening Godot | Open the project in Godot once and commit the file it creates |
| `orphan-sidecar` | A `.uid` or `.import` file whose source file is gone | Delete it |
| `broken-ref` | A scene, resource or script that points at a `res://` path that does not exist | Fix the path or remove the reference |
| `cache-ref` | A file that points into `res://.godot/`, Godot's private cache | Point it at the source file |
| `art-boundary` | A game file that uses something under `ART/` | Move the file into `assets/`, see [art-folders.md](art-folders.md) |
| `sim-boundary` | A script in a `sim/` folder that names the camera, the mouse or keyboard, the viewport, a sprite, a tween or the audio service | Move that part into a `view/` file, or send an event. See [testing.md](testing.md#the-simulation-rule) |
| `conflict-marker` | Leftover `<<<<<<<` or `>>>>>>>` lines from a merge | Resolve the conflict properly |
| `large-file` | A file over 20 MB (it warns from 5 MB) | Compress it, or talk to the team about Git LFS |
| `codeowners` | `.github/CODEOWNERS` is missing or has no `*` line | Restore it |

## Godot checks (a few minutes)

Runs the real engine, with no window, in five steps:

1. **Import twice.** The first pass builds Godot's class cache and is allowed to print errors. The second pass has to be clean.
2. **Load everything.** Every script, scene, resource and shader is loaded, and every scene is instantiated. A script that does not compile or a scene with a missing piece fails here.
3. **Boot the entry scenes.** The scenes listed in `.github/ci/entry-scenes.txt` run for a few seconds. Any script error fails the check.
4. **Run the tests.** Every test script of the new game runs. A failed test fails the check and is named. See [testing.md](testing.md).
5. **Read the logs.** `checks.py` turns Godot's log files into a pass or a fail. The logs are attached to the run as `godot-logs`.

## Lint (a few seconds)

Runs `gdlint` over the GDScript in `game/` and `addons/`. It checks names, line length and the order of a class. The old jam game is not linted. See [testing.md](testing.md#the-linter).

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

```bash
bash .github/ci/run_lint.sh
```

Only the tests, which is quicker while you work:

```bash
GODOT="/path/to/Godot" bash .github/ci/run_tests.sh
```

## What the checks do not catch

They catch broken files. They do **not** catch a game that loads fine but plays wrong.

- A button that was hidden by accident still loads without errors.
- A balance change, a wrong sprite or a job that never finishes all pass.

So a human still plays the change before approving. The tests of the new game prove its rules, not how it feels.

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
