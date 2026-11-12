#!/usr/bin/env bash
# Runs the tests of the game with no window. Works locally and in CI:
#   GODOT="/path/to/Godot" bash .github/ci/run_tests.sh
# Run only the test scripts whose path holds a text:
#   GODOT="/path/to/Godot" bash .github/ci/run_tests.sh --only=job_matching
# A test is a test_*.gd file under assets/ that extends GameTest (assets/Scripts/Dev/test_runner/).
set -uo pipefail

GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LOGS="${GODOT_LOGS:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/godot-logs}"

mkdir -p "$LOGS"
cd "$ROOT" || exit 2

run() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 600 "$@"
  else
    "$@"
  fi
}

if [ ! -d "$ROOT/.godot" ]; then
  echo "First run in this folder: importing the project twice so Godot knows every class."
  run "$GODOT" --headless --path "$ROOT" --import >"$LOGS/import-first.log" 2>&1
  run "$GODOT" --headless --path "$ROOT" --import >"$LOGS/import.log" 2>&1
fi

run "$GODOT" --headless --path "$ROOT" res://assets/Scripts/Dev/test_runner/run_tests.tscn -- "$@" >"$LOGS/tests.log" 2>&1
echo "$?" >"$LOGS/tests.exit"
grep -E "^TEST (PASS|FAIL)|^TESTS DONE" "$LOGS/tests.log"
echo "Log: $LOGS/tests.log"

python3 "$HERE/checks.py" tests "$LOGS"
