#!/bin/bash
#
# Runs the whole test suite the quickest local way: as bundles, the generated
# entrypoints that each import up to 40 test files and run them in one isolate
# (scripts/bundle_tests.py, issue #2500). Bundles also carry the runtime check
# that a test puts back any process-wide state it changed.
#
# Measured on an 18-core Mac at --concurrency=16 (issue #2512): 10m11s as
# separate files, 3m30s as CI's 120-file bundles, 2m52s at 40 files per bundle,
# which spread more evenly over 16 workers.
#
# Usage:
#   scripts/run_all_tests.sh [flutter test options...]
#   scripts/run_all_tests.sh --coverage
#   TEST_CONCURRENCY=8 scripts/run_all_tests.sh
#   TEST_FILES_FROM=selection.txt scripts/run_all_tests.sh
#
# TEST_FILES_FROM names a file listing test paths, one per line: only those
# run, bundled, with the same failure report. The pre-push hook hands a large
# selection over like this (issue #4117). A bundle runs its files one after
# another, so a selection's bundles are sized to give every worker one: at most
# files / concurrency each, and never over the 40 used for the suite. Measured
# at -j 16, 86 files took 62-67s as 19 bundles but about 180s as 4 bundles of
# 40, which left 12 workers idle. The hook's header has the comparison with
# separate files. The list must name existing files under test/, by paths relative
# to the repository root; an empty list is refused rather than silently running
# the whole suite. Give the list file itself as an absolute path, since the
# script changes to the repository root first.
#
# Runs from the repository root wherever it is started, in one flutter test
# call, so an option such as --coverage covers the whole suite. Performance
# tests are excluded, as in the pre-push hook. It takes options only: to run
# particular files, use `flutter test <paths>`. Exits non-zero if any test
# fails, after naming the files that failed, did not compile or could not load.
#
# Where the command line has a length limit (Git Bash on Windows, 8,191
# characters), the bundles are rebuilt with more files each until their paths
# fit, and the suite runs unbundled if no size fits; RUN_ALL_TESTS_ARG_LIMIT
# overrides the limit in characters. Without a working python3 the test files
# run one by one, a selection in as many calls as the command line needs. The
# bundles go in a directory of this run's own under
# test/.bundles (git-ignored), removed however the run ends.
#
# `RUN_ALL_TESTS=1 git push` runs this script.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 1
# The same directory as flutter test may print it: with symlinks resolved
# (/var is /private/var on macOS), and in Windows form under Git Bash.
REPO_ROOT_REAL="$(pwd -P)"
REPO_ROOT_WIN="$(cygpath -m "$REPO_ROOT" 2>/dev/null || true)"

# shellcheck source=test_concurrency.sh
. "$REPO_ROOT/scripts/test_concurrency.sh"
CONCURRENCY="$(resolve_test_concurrency)"

for arg in "$@"; do
    case "$arg" in
        -*) continue ;;
        *.dart) ;;
        test|test/*) [ -d "$arg" ] || continue ;;
        *) continue ;;
    esac
    echo "scripts/run_all_tests.sh runs the whole suite and takes flutter test options only;" >&2
    echo "'$arg' is a test path. To run particular files: flutter test <paths>" >&2
    exit 2
done

# The explicit selection, when TEST_FILES_FROM is set; empty for the suite.
SELECTED=()
if [ -n "${TEST_FILES_FROM:-}" ]; then
    if [ ! -f "$TEST_FILES_FROM" ]; then
        echo "TEST_FILES_FROM: no such file: $TEST_FILES_FROM" >&2
        exit 2
    fi
    refused=""
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [ -n "$line" ] || continue
        if [ -f "$line" ] && [ "${line#test/}" != "$line" ] \
            && [ "${line#*/../}" = "$line" ]; then
            SELECTED+=("$line")
        else
            refused="${refused}  ${line}
"
        fi
    done < "$TEST_FILES_FROM"
    if [ -n "$refused" ]; then
        echo "TEST_FILES_FROM must name existing files under test/; these are not:" >&2
        printf '%s' "$refused" >&2
        exit 2
    fi
    if [ "${#SELECTED[@]}" -eq 0 ]; then
        echo "TEST_FILES_FROM lists no test files: $TEST_FILES_FROM" >&2
        exit 2
    fi
fi

BUNDLE_ROOT="test/.bundles"
BUNDLE_DIR="$BUNDLE_ROOT/run_all_tests.$$"
FIRST_MAX_FILES=40
LAST_MAX_FILES=640
# A selection gets one bundle per worker at least; see TEST_FILES_FROM above.
if [ "${#SELECTED[@]}" -gt 0 ]; then
    per_worker=$(( (${#SELECTED[@]} + CONCURRENCY - 1) / CONCURRENCY ))
    if [ "$per_worker" -lt "$FIRST_MAX_FILES" ]; then
        FIRST_MAX_FILES="$per_worker"
    fi
fi

LOG="$(mktemp)"
# Removes only this run's bundles, then test/.bundles if nothing else is in it.
trap 'rm -rf "$BUNDLE_DIR"; rmdir "$BUNDLE_ROOT" 2>/dev/null; rm -f "$LOG"' EXIT

# The command-line length limit in characters, or 0 for none worth checking.
arg_limit() {
    case "${RUN_ALL_TESTS_ARG_LIMIT:-}" in
        '') ;;
        *[!0-9]*) ;;
        *) printf '%s' "$((10#$RUN_ALL_TESTS_ARG_LIMIT))"; return ;;
    esac
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) printf '8000' ;;
        *) printf '0' ;;
    esac
}

# Fills ENTRYPOINTS with the bundler's output for max_files per bundle, or
# leaves it empty if python3 is missing or the bundler fails.
bundle_suite() {
    local list line
    ENTRYPOINTS=()
    rm -rf "$BUNDLE_DIR"
    local -a subset=()
    if [ "${#SELECTED[@]}" -gt 0 ]; then
        subset=(--subset "$TEST_FILES_FROM")
    fi
    list="$(python3 scripts/bundle_tests.py --total-shards 1 \
        --max-files "$1" --out "$BUNDLE_DIR" ${subset[@]+"${subset[@]}"} 2>/dev/null || true)"
    [ -n "$list" ] || return 0
    # A native Windows python3 under Git Bash ends each line with CRLF.
    while IFS= read -r line; do
        ENTRYPOINTS+=("${line%$'\r'}")
    done <<< "$list"
}

entrypoints_length() {
    local total=0 entry
    for entry in ${ENTRYPOINTS[@]+"${ENTRYPOINTS[@]}"}; do
        total=$((total + ${#entry} + 1))
    done
    printf '%s' "$total"
}

LIMIT="$(arg_limit)"
ENTRYPOINTS=()
max_files="$FIRST_MAX_FILES"
bundle_suite "$max_files"
while [ "${#ENTRYPOINTS[@]}" -gt 0 ] && [ "$LIMIT" -gt 0 ] \
    && [ "$(entrypoints_length)" -gt "$LIMIT" ]; do
    if [ "$max_files" -ge "$LAST_MAX_FILES" ]; then
        ENTRYPOINTS=()
        rm -rf "$BUNDLE_DIR"
        echo "The bundle paths exceed the ${LIMIT}-character command line even at $max_files files per bundle."
        break
    fi
    max_files=$((max_files * 2))
    bundle_suite "$max_files"
done

if [ "${#SELECTED[@]}" -gt 0 ]; then
    if [ "${#SELECTED[@]}" -eq 1 ]; then
        what="1 selected test file"
    else
        what="${#SELECTED[@]} selected test files"
    fi
    if [ "${#ENTRYPOINTS[@]}" -gt 0 ]; then
        echo "Running $what as ${#ENTRYPOINTS[@]} bundled entrypoint(s) of up to $max_files files (concurrency $CONCURRENCY)."
    else
        echo "Running $what one by one (concurrency $CONCURRENCY); python3 could not bundle them within the limits."
    fi
elif [ "${#ENTRYPOINTS[@]}" -gt 0 ]; then
    echo "Running the suite as ${#ENTRYPOINTS[@]} bundled entrypoints of up to $max_files files (concurrency $CONCURRENCY)."
else
    echo "Running the test files one by one (concurrency $CONCURRENCY); python3 could not bundle them within the limits."
fi

# Prints each path on stdin relative to the repo root when it lies inside it,
# whichever form flutter test printed it in, with forward slashes.
relative_paths() {
    awk -v root="$REPO_ROOT/" -v real="$REPO_ROOT_REAL/" -v win="$REPO_ROOT_WIN" '
        BEGIN { if (win != "") win = tolower(win) "/" }
        {
            sub(/\r$/, "")
            gsub(/\\/, "/")
            if (index($0, root) == 1) $0 = substr($0, length(root) + 1)
            else if (index($0, real) == 1) $0 = substr($0, length(real) + 1)
            else if (win != "" && index(tolower($0), win) == 1) $0 = substr($0, length(win) + 1)
            print
        }'
}

# Test files with a failing test. flutter test prints a failure as
# "<time> <counts>: <entrypoint>: <test name> [E]". A bundle runs each file in a
# group named after its path relative to test/, so for a bundle the file begins
# the test's name; a file that ran on its own is the entrypoint.
failing_test_files() {
    grep -a '\[E\]' "$1" | awk '
        { sub(/^[0-9:]+ [^:]*: /, "") }
        /^loading / { next }
        match($0, /bundle_[0-9]+[^ :]*\.dart: /) {
            split(substr($0, RSTART + RLENGTH), words, " ")
            if (words[1] ~ /_test\.dart$/) print "test/" words[1]
            next
        }
        {
            i = index($0, "_test.dart: ")
            if (i > 0) print substr($0, 1, i + 9)
        }' | relative_paths | sort -u
}

# Files the compiler rejected, from its "<path>:<line>:<column>: Error:" lines.
uncompiled_files() {
    sed -nE 's/^(.+\.dart):[0-9]+:[0-9]+: Error:.*/\1/p' "$1" | relative_paths | sort -u
}

# Entrypoints that failed to load ("loading <path> [E]"), with a bundle listed
# as the test files it runs, read from its group names.
unloaded_files() {
    local path
    sed -nE 's/^.* loading (.*) \[E\]\r?$/\1/p' "$1" | relative_paths | sort -u |
        while IFS= read -r path; do
            case "$path" in
                */bundle_*.dart)
                    if [ -f "$path" ]; then
                        sed -nE "s/^  group\('(.*_test\.dart)', \(\) \{$/test\/\1/p" "$path"
                    else
                        printf '%s\n' "$path"
                    fi
                    ;;
                *) printf '%s\n' "$path" ;;
            esac
        done | sort -u
}

# $1 = heading, $2 = newline-separated files; prints nothing for no files.
print_section() {
    [ -n "$2" ] || return 0
    echo "$1"
    printf '%s\n' "$2" | sed 's/^/  /'
}

report_failures() {
    local failed uncompiled unloaded
    failed="$(failing_test_files "$1")"
    uncompiled="$(uncompiled_files "$1")"
    print_section "Failing test files (rerun one with: flutter test <path>):" "$failed"
    print_section "Files that did not compile:" "$uncompiled"
    # A compile error stops its bundle loading and can stop others too, so the
    # load failures are only worth listing when no compile error explains them.
    if [ -z "$uncompiled" ]; then
        unloaded="$(unloaded_files "$1")"
        print_section "Could not load (rerun one with: flutter test <path>):" "$unloaded"
    fi
}

CALLER_OPTIONS=("$@")

# Runs flutter test on the targets "$@", adding to the log. Returns its status.
run_flutter() {
    flutter test --exclude-tags performance --concurrency="$CONCURRENCY" \
        ${CALLER_OPTIONS[@]+"${CALLER_OPTIONS[@]}"} "$@" 2>&1 | tee -a "$LOG"
    return "${PIPESTATUS[0]}"
}

# Runs the selected files in as many calls as the command-line limit needs,
# which is one where there is no limit. Later calls still run after a failure.
run_selected_files() {
    local -a batch=()
    local path length=0
    for path in "${SELECTED[@]}"; do
        if [ "$LIMIT" -gt 0 ] && [ "${#batch[@]}" -gt 0 ] \
            && [ $((length + ${#path} + 1)) -gt "$LIMIT" ]; then
            run_flutter "${batch[@]}" || status=$?
            batch=()
            length=0
        fi
        batch+=("$path")
        length=$((length + ${#path} + 1))
    done
    run_flutter "${batch[@]}" || status=$?
}

status=0
if [ "${#ENTRYPOINTS[@]}" -eq 0 ] && [ "${#SELECTED[@]}" -gt 0 ]; then
    run_selected_files
else
    run_flutter ${ENTRYPOINTS[@]+"${ENTRYPOINTS[@]}"} || status=$?
fi

if [ "$status" -ne 0 ]; then
    echo ""
    report_failures "$LOG"
fi
exit "$status"
