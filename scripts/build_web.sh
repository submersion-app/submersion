#!/bin/bash
#
# Builds the browser app into build/web.
#
# Fetches the pinned sqlite3.wasm, compiles the browser workers, then runs
# the Flutter web build, which copies everything in web/ into build/web. The
# bundle work adds the hosting files and the bundle check.
#
# Usage:
#   scripts/build_web.sh [flutter build web options...]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

scripts/web/fetch_sqlite3_wasm.sh
scripts/web/compile_workers.sh
flutter build web --release "$@"
