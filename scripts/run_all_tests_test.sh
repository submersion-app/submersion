#!/bin/bash
#
# Tests for scripts/run_all_tests.sh.
#
# No Flutter toolchain is required: `flutter` is stubbed on PATH and records
# how it was called, so this runs in the CI script-tests job. The real
# scripts/bundle_tests.py builds the bundles.
#
# Usage: bash scripts/run_all_tests_test.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

failures=0

pass() { printf 'ok   - %s\n' "$1"; }
fail() {
    printf 'FAIL - %s\n' "$1"
    if [ -n "${2:-}" ]; then
        printf '       %s\n' "$2"
    fi
    failures=$((failures + 1))
}

# A repo with two runnable test files, the script under test, the real
# bundler, and a flutter stub. The stub records its working directory, its
# arguments and how many bundles existed while it ran. With FLUTTER_TEST_FAIL=1
# it fails the way a real run prints it: the entrypoint as an absolute path,
# then the test's name, which in a bundle starts with the file's path relative
# to test/. Echoes the temp dir.
make_fixture() {
    tmp="$(mktemp -d)"
    root="$tmp/repo"
    mkdir -p "$root/scripts" "$root/test" "$tmp/bin"

    for name in a b; do
        printf "import 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('%s', () {});\n}\n" \
            "$name" > "$root/test/${name}_test.dart"
    done
    cp "$REPO_ROOT/scripts/run_all_tests.sh" "$root/scripts/run_all_tests.sh"
    cp "$REPO_ROOT/scripts/bundle_tests.py" "$root/scripts/bundle_tests.py"

    cat > "$tmp/bin/flutter" <<'STUB'
#!/bin/bash
pwd -P > "$FLUTTER_CWD"
printf '%s\n' "$*" >> "$FLUTTER_ARGS"
find test/.bundles -name 'bundle_*.dart' 2>/dev/null | wc -l | tr -d ' ' \
    >> "$FLUTTER_BUNDLES"
if [ "${FLUTTER_TEST_FAIL:-0}" = "1" ]; then
    root="$(pwd -P)"
    echo "00:01 +1 -1: $root/test/.bundles/bundle_000_root.dart: b_test.dart fails on purpose [E]"
    echo "00:02 +1 -2: $root/test/a_test.dart: fails while running alone [E]"
    echo "00:02 +1 -2: $root/test/.bundles/bundle_000_root.dart: b_test.dart (tearDownAll)"
    echo "00:02 +1 -2: Some tests failed."
    exit 1
fi
exit 0
STUB
    chmod +x "$tmp/bin/flutter"

    printf '%s\n' "$tmp"
}

# Runs the fixture's script from $tmp (not the repo root, which the script must
# find for itself). Extra NAME=VALUE arguments before `--` go into its
# environment; the rest are passed to the script. Sets: run_status,
# run_output, flutter_args, flutter_cwd, bundles_during_run.
run_script() {
    tmp="$1"
    shift
    local -a env_args=()
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
        env_args+=("$1")
        shift
    done
    [ "${1:-}" = "--" ] && shift

    : > "$tmp/flutter_args"
    : > "$tmp/flutter_bundles"
    : > "$tmp/flutter_cwd"
    cd "$tmp" || exit 1
    run_output="$(env ${env_args[@]+"${env_args[@]}"} PATH="$tmp/bin:$PATH" \
        FLUTTER_ARGS="$tmp/flutter_args" FLUTTER_BUNDLES="$tmp/flutter_bundles" \
        FLUTTER_CWD="$tmp/flutter_cwd" \
        bash "$tmp/repo/scripts/run_all_tests.sh" "$@" 2>&1)"
    run_status=$?
    flutter_args="$(cat "$tmp/flutter_args")"
    flutter_cwd="$(cat "$tmp/flutter_cwd")"
    bundles_during_run="$(head -1 "$tmp/flutter_bundles")"
}

# --- Test 1: the suite runs as bundles, from the repo root -----------------

tmp="$(make_fixture)"
run_script "$tmp"

case "$flutter_args" in
    *'test/.bundles/bundle_'*)
        pass 'hands flutter test the generated bundles'
        ;;
    *)
        fail 'hands flutter test the generated bundles' "flutter was invoked as: $flutter_args"
        ;;
esac

case "$flutter_args" in
    'test --exclude-tags performance --concurrency='[0-9]*)
        pass 'excludes performance tests and sets a concurrency'
        ;;
    *)
        fail 'excludes performance tests and sets a concurrency' "flutter was invoked as: $flutter_args"
        ;;
esac

if [ "$flutter_cwd" = "$(cd "$tmp/repo" && pwd -P)" ]; then
    pass 'runs from the repo root wherever it is started'
else
    fail 'runs from the repo root wherever it is started' "flutter ran in '$flutter_cwd'"
fi

if [ "${bundles_during_run:-0}" -gt 0 ] && [ ! -e "$tmp/repo/test/.bundles" ]; then
    pass 'the bundles exist during the run and are removed after it'
else
    fail 'the bundles exist during the run and are removed after it' \
        "bundles during the run: '$bundles_during_run'; left behind: $(ls "$tmp/repo/test/.bundles" 2>&1)"
fi

if [ "$run_status" -eq 0 ]; then
    pass 'exits 0 when the tests pass'
else
    fail 'exits 0 when the tests pass' "exit $run_status: $run_output"
fi

# --- Test 2: concurrency and extra flutter test arguments -------------------

run_script "$tmp" TEST_CONCURRENCY=3 -- --coverage --reporter compact

case "$flutter_args" in
    *'--concurrency=3 --coverage --reporter compact test/'*)
        pass 'honours TEST_CONCURRENCY and passes extra arguments before the paths'
        ;;
    *)
        fail 'honours TEST_CONCURRENCY and passes extra arguments before the paths' \
            "flutter was invoked as: $flutter_args"
        ;;
esac

run_script "$tmp" TEST_CONCURRENCY=abc

case "$run_output" in
    *'invalid TEST_CONCURRENCY'*)
        case "$flutter_args" in
            *'--concurrency=abc'*)
                fail 'warns about an invalid TEST_CONCURRENCY and uses the default' \
                    "flutter was invoked as: $flutter_args"
                ;;
            *)
                pass 'warns about an invalid TEST_CONCURRENCY and uses the default'
                ;;
        esac
        ;;
    *)
        fail 'warns about an invalid TEST_CONCURRENCY and uses the default' "output: $run_output"
        ;;
esac

# --- Test 3: a failing run names the failing files ---------------------------

run_script "$tmp" FLUTTER_TEST_FAIL=1

if [ "$run_status" -ne 0 ]; then
    pass 'exits non-zero when a test fails'
else
    fail 'exits non-zero when a test fails' "exit 0: $run_output"
fi

failing_list="$(printf '%s\n' "$run_output" | sed -n '/Failing test files/,$p' \
    | grep -E '^ +test/' | sed 's/^ *//' | sort | tr '\n' ' ')"
if [ "$failing_list" = 'test/a_test.dart test/b_test.dart ' ]; then
    pass 'lists each failing test file once, relative to the repo'
else
    fail 'lists each failing test file once, relative to the repo' \
        "listed: '$failing_list'; output: $run_output"
fi

if [ ! -e "$tmp/repo/test/.bundles" ]; then
    pass 'the bundles are removed after a failing run too'
else
    fail 'the bundles are removed after a failing run too' \
        "left behind: $(ls "$tmp/repo/test/.bundles" 2>&1)"
fi

# --- Test 4: bundler output with Windows line endings ------------------------
#
# Under Git Bash a native Windows python3 prints CRLF, and a carriage return
# left on a path would make flutter test fail to open every bundle.

real_python="$(command -v python3)"
cat > "$tmp/bin/python3" <<STUB
#!/bin/bash
"$real_python" "\$@" | sed 's/\$/\r/'
exit "\${PIPESTATUS[0]}"
STUB
chmod +x "$tmp/bin/python3"
run_script "$tmp"

case "$flutter_args" in
    *$'\r'*)
        fail 'strips carriage returns from the bundler output' \
            "flutter was invoked with a carriage return: $(printf '%s' "$flutter_args" | od -c | head -3)"
        ;;
    *'test/.bundles/bundle_'*)
        pass 'strips carriage returns from the bundler output'
        ;;
    *)
        fail 'strips carriage returns from the bundler output' \
            "flutter was invoked as: $flutter_args"
        ;;
esac
rm "$tmp/bin/python3"

# --- Test 5: without a working python3 the files run one by one --------------
#
# Git Bash on Windows may have no python3. A bundler that cannot run must not
# stop the tests from running.

cat > "$tmp/bin/python3" <<'STUB'
#!/bin/bash
echo 'python3: not usable here' >&2
exit 127
STUB
chmod +x "$tmp/bin/python3"
run_script "$tmp"

if [ "$run_status" -eq 0 ] && [ -n "$flutter_args" ]; then
    pass 'still runs the suite when python3 cannot bundle'
else
    fail 'still runs the suite when python3 cannot bundle' \
        "exit $run_status; flutter test args: '$flutter_args'"
fi

case "$flutter_args" in
    *'bundle_'*)
        fail 'falls back to separate test files' "flutter was invoked as: $flutter_args"
        ;;
    *)
        pass 'falls back to separate test files'
        ;;
esac

rm -rf "$tmp"

# --- Summary ---------------------------------------------------------------

if [ "$failures" -eq 0 ]; then
    printf '\nAll run_all_tests.sh tests passed.\n'
    exit 0
fi

printf '\n%d run_all_tests.sh test(s) failed.\n' "$failures"
exit 1
