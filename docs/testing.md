# How to test the new game

**In one line:** a test is a small script in a `tests/` folder. One command runs all of them with no window, on your machine and in CI.

This covers the new game in `game/` and `addons/`. The old jam game has no tests.

## Run the tests

```bash
GODOT="/path/to/Godot" bash .github/ci/run_tests.sh
```

- It prints one line per test and ends with `OK` or `FAILED`.
- A failed test is named, with what it got and what it wanted.
- The full log is the file named on the `Log:` line.

Run only the test scripts whose path holds a text:

```bash
GODOT="/path/to/Godot" bash .github/ci/run_tests.sh --only=dev_settings
```

The Godot checks run the same tests as their last step, so CI runs them on every pull request.

## Add a test

1. Make a `tests/` folder next to the code you are testing, for example `game/village/tests/`.
2. Add a script whose name starts with `test_`, for example `test_grid.gd`.
3. Start it with `extends GameTest`.
4. Write one method per thing you want to prove. Its name starts with `test_` and says what should be true.
5. Open the project in Godot once, so it writes the `.uid` file. Commit both files.

The sample to copy is `game/core/tests/test_dev_settings.gd`:

```gdscript
extends GameTest
## Checks the saved dev settings.


func test_the_tick_rate_starts_at_twenty() -> void:
	check_eq(DevSettings.new().ticks_per_second, 20)
```

## The checks you can use

| Call | Passes when |
| --- | --- |
| `check(condition, "what was expected")` | `condition` is true |
| `check_eq(got, want)` | the two are equal and of the same type |
| `check_near(got, want, tolerance)` | two numbers are within `tolerance` of each other |
| `fail("why")` | never. Use it for a path the code should not reach |

- A failed check does not stop the test. Every failed check is reported.
- **A test that runs no check fails.** That also catches a test that stopped on a script error.
- Each test runs on a fresh copy of the script, so one test cannot leak into the next.
- `before_each()` and `after_each()` run around every test. Override them to build and free what the tests share.
- `tree` is the scene tree, for the few tests that need a node or have to wait a frame with `await tree.process_frame`.

## What makes a good test here

- **Test the simulation, not the picture.** Code in a `sim/` folder runs with no window, so a test can build a village, tick it and look at the result.
- **Use a seed.** Anything random takes a seed, and the test passes a fixed one.
- **Prove the number.** When an issue says "a tree breaks after 2 hits", the test hits it twice and checks.
- A look, such as "the meeple looks like the jam game", cannot be tested this way. It needs a picture, and a person to look at it.

## The simulation rule

The repo checks refuse a script in a `sim/` folder that names any of these:

`Camera2D`, `Input.`, `get_viewport`, `Sprite2D`, `create_tween`, or the audio service (`Audio.`, `AudioServer`, `AudioStreamPlayer`).

- The rule is called `sim-boundary`.
- A name inside a comment is allowed.
- The fix is to move that part into a `view/` file, or to send an event that the picture listens to. See [game/README.md](../game/README.md).

## The linter

`gdlint` checks the style of the new GDScript: names, line length, the order of a class. It is the third check on a pull request.

```bash
bash .github/ci/run_lint.sh
```

- Install it once: `pipx install "gdtoolkit==4.5.0"`, or `pip3 install "gdtoolkit==4.5.0"`.
- It only looks at `game/` and `addons/`. The old game is not linted.
- CI uses the version named in `.github/workflows/ci.yml`. Use the same one.
