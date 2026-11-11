#!/usr/bin/env bash
# Lints the GDScript of the new game with gdlint. Works locally and in CI:
#   bash .github/ci/run_lint.sh
# It needs gdtoolkit. Install the version CI uses (see GDTOOLKIT_VERSION in .github/workflows/ci.yml):
#   pipx install "gdtoolkit==4.5.0"      or      pip3 install "gdtoolkit==4.5.0"
# The old jam game in assets/ and the root scripts is not linted. Issue #36 removes it.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 2

if ! command -v gdlint >/dev/null 2>&1; then
  echo "gdlint is not installed. Install it with: pipx install \"gdtoolkit==4.5.0\""
  exit 2
fi

gdlint game addons
