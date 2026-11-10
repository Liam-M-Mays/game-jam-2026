#!/usr/bin/env bash
# Runs the Godot part of CI. Works locally too:
#   GODOT="/path/to/Godot" bash .github/ci/run_godot_checks.sh
set -uo pipefail

GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LOGS="${GODOT_LOGS:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/godot-logs}"

rm -rf "$LOGS"
mkdir -p "$LOGS"
cd "$ROOT" || exit 2

run() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 600 "$@"
  else
    "$@"
  fi
}

echo "Godot: $("$GODOT" --version 2>/dev/null | head -1)"
echo "Logs:  $LOGS"

echo "1/4 First import. Godot builds its class cache here, so errors in this pass are expected."
run "$GODOT" --headless --path "$ROOT" --import >"$LOGS/import-first.log" 2>&1

echo "2/4 Second import. This one has to be clean."
run "$GODOT" --headless --path "$ROOT" --import >"$LOGS/import.log" 2>&1

echo "3/4 Loading every script, scene, resource and shader."
run "$GODOT" --headless --path "$ROOT" res://.github/ci/load_check.tscn >"$LOGS/load.log" 2>&1

echo "4/4 Booting the entry scenes with no window."
while read -r name scene frames; do
  case "$name" in ""|\#*) continue ;; esac
  if [ "$scene" = "main" ]; then
    run "$GODOT" --headless --path "$ROOT" --quit-after "$frames" >"$LOGS/boot-$name.log" 2>&1
  else
    run "$GODOT" --headless --path "$ROOT" --quit-after "$frames" "$scene" >"$LOGS/boot-$name.log" 2>&1
  fi
  echo "$?" >"$LOGS/boot-$name.exit"
  echo "    $name: ran $frames frames, exit code $(cat "$LOGS/boot-$name.exit")"
done <"$HERE/entry-scenes.txt"

python3 "$HERE/checks.py" logs "$LOGS" "$@"
