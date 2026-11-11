# game/dev/test_runner/

**What lives here:** the test runner. It runs every test script of the new game with no window.

- `game_test.gd`: the base class of a test script, with `check`, `check_eq`, `check_near` and `fail`.
- `run_tests.gd` and `run_tests.tscn`: the scene that finds the test scripts and runs them.

Run it with `bash .github/ci/run_tests.sh`. How to write a test: [docs/testing.md](../../../docs/testing.md).
