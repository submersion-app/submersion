#!/bin/bash
#
# Compiles the browser workers with dart2js and stages them, with
# sqlite3.wasm, where the browser tests can load them.
#
# The workers are Dart programs compiled apart from the Flutter app:
# web/drift_worker.dart runs SQLite for drift and web/compute_worker.dart
# runs the sync crypto, hashing and base streaming. `flutter build web`
# copies everything in web/ into the bundle, so the compiled .js files land
# next to main.dart.js. `flutter test --platform chrome` serves the test/
# directory, so the same files are copied to test/web/assets/ (git-ignored).
#
# Usage: scripts/web/compile_workers.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

for worker in drift_worker compute_worker; do
    if [ -f "web/$worker.dart" ]; then
        dart compile js -O4 -o "web/$worker.js" "web/$worker.dart"
    else
        echo "compile_workers: web/$worker.dart not present yet, skipped"
    fi
done

mkdir -p test/web/assets
for artifact in web/drift_worker.js web/compute_worker.js web/sqlite3.wasm; do
    if [ -f "$artifact" ]; then
        cp "$artifact" test/web/assets/
    fi
done
echo "staged $(ls test/web/assets | wc -l | tr -d ' ') file(s) in test/web/assets"
