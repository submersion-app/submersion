#!/bin/bash
#
# Runs the whole test suite the quickest local way: as bundles, the generated
# entrypoints that each import up to 40 test files and run them in one isolate
# (scripts/bundle_tests.py, issue #2500). Bundles also carry the runtime check
# that a test puts back any process-wide state it changed.
#
# Measured on an 18-core Mac at --concurrency=16 (issue #2512): 10m11s as
# separate files, 3m30s as CI's 120-file bundles, 2m52s at 40 files per bundle,
# which spread more evenly over 16 workers. The bundles are passed in calls of
# 100, which keeps each command line within Windows' limit (3m18s in all).
#
# Usage:
#   scripts/run_all_tests.sh [flutter test options...]
#   scripts/run_all_tests.sh --coverage
#   TEST_CONCURRENCY=8 scripts/run_all_tests.sh
#
# Runs from the repository root wherever it is started. Performance tests are
# excluded, as in the pre-push hook. Exits non-zero if any test fails, after
# listing the failing test files so one can be rerun with `flutter test
# <path>`. Without a working python3 the test files run one by one. The bundles
# go in test/.bundles (git-ignored) and are removed however the run ends.
# `RUN_ALL_TESTS=1 git push` runs this script.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 1
# The same directory with symlinks resolved (/var is /private/var on macOS);
# flutter test may print either form.
REPO_ROOT_REAL="$(pwd -P)"

BUNDLE_DIR="test/.bundles"
MAX_FILES=40
BATCH_SIZE=100

# The parallel test-isolate count: the core count, at most 16. Measured in the
# pre-push hook, 16 is the knee on a machine with 6 performance cores.
default_concurrency() {
    local n
    n=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 6)
    case "$n" in
        ''|*[!0-9]*) n=6 ;;
    esac
    if [ "$n" -gt 16 ]; then n=16; fi
    if [ "$n" -lt 2 ]; then n=2; fi
    printf '%s' "$n"
}

CONCURRENCY="$(default_concurrency)"
case "${TEST_CONCURRENCY:-}" in
    '') ;;
    *[!0-9]*|0)
        echo "Ignoring invalid TEST_CONCURRENCY='${TEST_CONCURRENCY}'; using ${CONCURRENCY}." >&2
        ;;
    *) CONCURRENCY="$TEST_CONCURRENCY" ;;
esac

LOG="$(mktemp)"
trap 'rm -rf "$BUNDLE_DIR"; rm -f "$LOG"' EXIT

run_flutter() {
    flutter test --exclude-tags performance --concurrency="$CONCURRENCY" "$@"
}

# Runs the entrypoints in calls of BATCH_SIZE, all of them even after one
# fails, and returns non-zero if any did.
run_entrypoints() {
    local failed=0 i=0
    while [ "$i" -lt "${#ENTRYPOINTS[@]}" ]; do
        run_flutter ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} \
            "${ENTRYPOINTS[@]:$i:$BATCH_SIZE}" || failed=1
        i=$((i + BATCH_SIZE))
    done
    return "$failed"
}

# Lists the test files behind the failures in a run's output. flutter test
# prints a failure as "<time> <counts>: <entrypoint>: <test name> [E]", with the
# entrypoint as an absolute path. A bundle runs each file in a group named after
# its path relative to test/, so for a bundle the file begins the test's name;
# a file that ran on its own is the entrypoint.
report_failing_files() {
    local files
    files="$(grep -aE '\[E\]' "$1" | sed -E 's/^[0-9:]+ [^:]*: //' \
        | awk -v root="$REPO_ROOT/" -v real="$REPO_ROOT_REAL/" '
            match($0, /bundle_[0-9]+[^ :]*\.dart: /) {
                split(substr($0, RSTART + RLENGTH), words, " ")
                if (words[1] ~ /_test\.dart$/) print "test/" words[1]
                next
            }
            match($0, /^[^ ]*_test\.dart: /) {
                file = substr($0, 1, RLENGTH - 2)
                if (index(file, root) == 1) file = substr(file, length(root) + 1)
                else if (index(file, real) == 1) file = substr(file, length(real) + 1)
                print file
            }' | sort -u || true)"
    if [ -n "$files" ]; then
        echo "Failing test files (rerun one with: flutter test <path>):"
        printf '%s\n' "$files" | sed 's/^/  /'
    fi
}

EXTRA_ARGS=("$@")
ENTRYPOINTS=()
rm -rf "$BUNDLE_DIR"
bundle_list="$(python3 scripts/bundle_tests.py --total-shards 1 \
    --max-files "$MAX_FILES" --out "$BUNDLE_DIR" 2>/dev/null || true)"
if [ -n "$bundle_list" ]; then
    while IFS= read -r line; do
        ENTRYPOINTS+=("$line")
    done <<< "$bundle_list"
    echo "Running the suite as ${#ENTRYPOINTS[@]} bundled entrypoints (concurrency $CONCURRENCY)."
else
    echo "python3 could not bundle the suite; running the test files one by one (concurrency $CONCURRENCY)."
fi

if [ "${#ENTRYPOINTS[@]}" -gt 0 ]; then
    run_entrypoints 2>&1 | tee "$LOG"
else
    run_flutter ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} 2>&1 | tee "$LOG"
fi
status=${PIPESTATUS[0]}

if [ "$status" -ne 0 ]; then
    echo ""
    report_failing_files "$LOG"
fi
exit "$status"
