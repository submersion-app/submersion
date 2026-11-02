#!/bin/bash
#
# Runs the browser suite under test/web, one directory per Chrome.
#
# One Chrome loading every file of test/web loses its connection after
# about nine suites ("Connection closed before test suite loaded"), with
# --concurrency=1 too, while each directory passes on its own; so each
# directory gets its own `flutter test --platform chrome` run. Every run
# writes a JSON report, and unless --allow-skips is given the reports are
# checked for skipped tests afterwards: the store tests skip without their
# MINIO_* defines, so a CI run that lost them must not pass on nothing.
#
# Usage:
#   scripts/web/test_web.sh [--allow-skips] [flutter test options...]
#
# scripts/web/compile_workers.sh must have staged the workers and
# sqlite3.wasm first. WEB_TEST_REPORT_DIR names where the reports go
# (default: a fresh temporary directory, printed at the end).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

ALLOW_SKIPS=0
if [ "${1:-}" = "--allow-skips" ]; then
  ALLOW_SKIPS=1
  shift
fi

REPORT_DIR="${WEB_TEST_REPORT_DIR:-$(mktemp -d)}"
mkdir -p "$REPORT_DIR"

for dir in test/web/*/; do
  name="$(basename "$dir")"
  echo "== Browser suite: $dir =="
  flutter test --platform chrome "$dir" \
    --file-reporter "json:$REPORT_DIR/web-$name.json" "$@"
done

echo "Reports in $REPORT_DIR"
if [ "$ALLOW_SKIPS" -eq 0 ]; then
  python3 scripts/check_no_skipped_tests.py "$REPORT_DIR"/web-*.json
fi
