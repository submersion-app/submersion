#!/bin/bash
#
# Tests for scripts/run_all_tests.sh and scripts/test_concurrency.sh.
#
# No Flutter toolchain is required: `flutter` is stubbed on PATH and records
# how it was called, so this runs in the CI script-tests job. The real
# scripts/bundle_tests.py builds the bundles.
#
# Usage: bash scripts/run_all_tests_test.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REAL_PYTHON="$(command -v python3)"

failures=0

pass() { printf 'ok   - %s\n' "$1"; }
fail() {
    printf 'FAIL - %s\n' "$1"
    if [ -n "${2:-}" ]; then
        printf '       %s\n' "$2"
    fi
    failures=$((failures + 1))
}

# $1 = 'has' | 'lacks', $2 = haystack, $3 = needle, $4 = test name
assert_contains() {
    case "$2" in
        *"$3"*) got=has ;;
        *)      got=lacks ;;
    esac
    if [ "$got" = "$1" ]; then
        pass "$4"
    else
        fail "$4" "expected to $1 '$3' in: $2"
    fi
}

# A repo whose path contains a space, with two runnable test files, the
# scripts under test, the real bundler, and a flutter stub. The stub records
# each call's working directory and arguments and how many bundles existed
# while it ran. FLUTTER_TEST_FAIL picks a failure to print the way a real run
# does:
#   test     a test fails: in a bundle the name starts with the file's path
#            relative to test/; a file run alone is the entrypoint
#   windows  a file run alone fails, printed with a Windows path
#   compile  a file does not compile, which also stops another from loading
#   load     a bundle fails to load with no compile error printed
# Echoes the temp dir.
make_fixture() {
    tmp="$(mktemp -d)"
    root="$tmp/my repo"
    mkdir -p "$root/scripts" "$root/test" "$tmp/bin"

    for name in a b; do
        printf "import 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('%s', () {});\n}\n" \
            "$name" > "$root/test/${name}_test.dart"
    done
    for script in run_all_tests.sh test_concurrency.sh bundle_tests.py; do
        cp "$REPO_ROOT/scripts/$script" "$root/scripts/$script"
    done

    cat > "$tmp/bin/flutter" <<'STUB'
#!/bin/bash
pwd -P >> "$FLUTTER_CWD"
printf '%s\n' "$*" >> "$FLUTTER_ARGS"
find test/.bundles -name 'bundle_*.dart' 2>/dev/null | wc -l | tr -d ' ' \
    >> "$FLUTTER_BUNDLES"
root="$(pwd -P)"
bundle=""
for arg in "$@"; do
    case "$arg" in */bundle_*.dart) bundle="$root/$arg" ;; esac
done
case "${FLUTTER_TEST_FAIL:-}" in
    test)
        echo "00:01 +1 -1: $bundle: b_test.dart fails on purpose [E]"
        echo "00:02 +1 -2: $root/test/a_test.dart: fails while running alone [E]"
        echo "00:02 +1 -2: $bundle: b_test.dart (tearDownAll)"
        ;;
    windows)
        echo '00:02 +1 -1: C:\fake\repo\test\a_test.dart: fails on Windows [E]'
        ;;
    compile)
        echo "test/b_test.dart:5:23: Error: A value of type 'String' can't be assigned to a variable of type 'int'."
        echo "00:00 +0 -1: loading $bundle [E]"
        echo "00:00 +0 -2: loading $root/test/a_test.dart [E]"
        ;;
    load)
        echo "00:00 +0 -1: loading $bundle [E]"
        ;;
    *) exit 0 ;;
esac
echo "00:02 +1 -2: Some tests failed."
exit 1
STUB
    chmod +x "$tmp/bin/flutter"

    printf '%s\n' "$tmp"
}

# Runs the fixture's script from $tmp (not the repo root, which the script must
# find for itself). NAME=VALUE arguments before `--` go into its environment;
# the rest are passed to the script. Sets: run_status, run_output,
# flutter_args, flutter_calls, flutter_cwd, bundles_during_run.
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
        bash "$tmp/my repo/scripts/run_all_tests.sh" "$@" 2>&1)"
    run_status=$?
    flutter_args="$(cat "$tmp/flutter_args")"
    flutter_calls="$(grep -c . "$tmp/flutter_args")"
    flutter_cwd="$(head -1 "$tmp/flutter_cwd")"
    bundles_during_run="$(head -1 "$tmp/flutter_bundles")"
}

# The files listed under a heading of the script's failure report, sorted and
# space-separated. $1 = heading text.
listed_under() {
    printf '%s\n' "$run_output" | sed -n "/$1/,/^[^ ]/p" | grep -E '^ +test/' \
        | sed 's/^ *//' | sort | tr '\n' ' '
}

tmp="$(make_fixture)"
root="$tmp/my repo"

# --- Test 1: the suite runs as bundles, in one call, from the repo root -----

run_script "$tmp"

assert_contains has "$flutter_args" 'test/.bundles/' 'hands flutter test the generated bundles'
case "$flutter_args" in
    'test --exclude-tags performance --concurrency='[0-9]*)
        pass 'excludes performance tests and sets a concurrency'
        ;;
    *)
        fail 'excludes performance tests and sets a concurrency' "flutter was invoked as: $flutter_args"
        ;;
esac
if [ "$flutter_calls" -eq 1 ]; then
    pass 'runs the whole suite in a single flutter test call'
else
    fail 'runs the whole suite in a single flutter test call' "$flutter_calls calls: $flutter_args"
fi
if [ "$flutter_cwd" = "$(cd "$root" && pwd -P)" ]; then
    pass 'runs from the repo root wherever it is started, even with a space in its path'
else
    fail 'runs from the repo root wherever it is started, even with a space in its path' \
        "flutter ran in '$flutter_cwd'"
fi
if [ "${bundles_during_run:-0}" -gt 0 ] && [ ! -e "$root/test/.bundles" ]; then
    pass 'the bundles exist during the run and are removed after it'
else
    fail 'the bundles exist during the run and are removed after it' \
        "bundles during the run: '$bundles_during_run'; left behind: $(ls -R "$root/test/.bundles" 2>&1)"
fi
if [ "$run_status" -eq 0 ]; then
    pass 'exits 0 when the tests pass'
else
    fail 'exits 0 when the tests pass' "exit $run_status: $run_output"
fi

# --- Test 2: another run's bundles are left alone ----------------------------
#
# bundle_tests.py writes to test/.bundles by default, as the CI-reproduction
# commands in docs/developer/testing.md do, and two runs can overlap.

mkdir -p "$root/test/.bundles/other"
printf '// another run\n' > "$root/test/.bundles/other/bundle_000_root.dart"
run_script "$tmp"
if [ -f "$root/test/.bundles/other/bundle_000_root.dart" ] \
    && [ "$(ls "$root/test/.bundles")" = 'other' ]; then
    pass "leaves another run's bundles in place and removes only its own"
else
    fail "leaves another run's bundles in place and removes only its own" \
        "test/.bundles now holds: $(ls -R "$root/test/.bundles" 2>&1)"
fi
rm -rf "$root/test/.bundles"

# --- Test 3: options, coverage and concurrency --------------------------------

run_script "$tmp" TEST_CONCURRENCY=3 -- --coverage --reporter compact
assert_contains has "$flutter_args" '--concurrency=3 --coverage --reporter compact test/.bundles/' \
    'honours TEST_CONCURRENCY and passes options before the paths'
if [ "$flutter_calls" -eq 1 ]; then
    pass 'a --coverage run is one call, so one report covers every bundle'
else
    fail 'a --coverage run is one call, so one report covers every bundle' \
        "$flutter_calls calls: $flutter_args"
fi

for bad in abc 0 00 -2; do
    run_script "$tmp" "TEST_CONCURRENCY=$bad"
    case "$run_output" in
        *"invalid TEST_CONCURRENCY='$bad'"*)
            assert_contains lacks "$flutter_args" "--concurrency=$bad " \
                "rejects TEST_CONCURRENCY=$bad and uses the default"
            ;;
        *)
            fail "rejects TEST_CONCURRENCY=$bad and uses the default" "output: $run_output"
            ;;
    esac
done

run_script "$tmp" TEST_CONCURRENCY=08
assert_contains has "$flutter_args" '--concurrency=8 ' 'reads TEST_CONCURRENCY=08 as 8'

# --- Test 4: test paths are refused -------------------------------------------
#
# The script runs the whole suite; a path would run on top of it, not instead.

for path_arg in test/a_test.dart test; do
    run_script "$tmp" -- "$path_arg"
    if [ "$run_status" -eq 2 ] && [ "$flutter_calls" -eq 0 ]; then
        assert_contains has "$run_output" 'flutter test' \
            "refuses the path '$path_arg' and points to flutter test"
    else
        fail "refuses the path '$path_arg' and points to flutter test" \
            "exit $run_status, $flutter_calls flutter calls: $run_output"
    fi
done

# --- Test 5: a failing run names the failing files ----------------------------

run_script "$tmp" FLUTTER_TEST_FAIL=test
if [ "$run_status" -ne 0 ]; then
    pass 'exits non-zero when a test fails'
else
    fail 'exits non-zero when a test fails' "exit 0: $run_output"
fi
if [ "$(listed_under 'Failing test files')" = 'test/a_test.dart test/b_test.dart ' ]; then
    pass 'lists each failing test file once, relative to the repo'
else
    fail 'lists each failing test file once, relative to the repo' \
        "listed: '$(listed_under 'Failing test files')'; output: $run_output"
fi
if [ ! -e "$root/test/.bundles" ]; then
    pass 'the bundles are removed after a failing run too'
else
    fail 'the bundles are removed after a failing run too' "left behind: $(ls -R "$root/test/.bundles" 2>&1)"
fi

# Under Git Bash the repo is /c/fake/repo, and flutter prints C:\fake\repo\...
cat > "$tmp/bin/cygpath" <<'STUB'
#!/bin/bash
echo 'C:/fake/repo'
STUB
chmod +x "$tmp/bin/cygpath"
run_script "$tmp" FLUTTER_TEST_FAIL=windows
if [ "$(listed_under 'Failing test files')" = 'test/a_test.dart ' ]; then
    pass 'lists a failure printed with a Windows path relative to the repo'
else
    fail 'lists a failure printed with a Windows path relative to the repo' \
        "listed: '$(listed_under 'Failing test files')'; output: $run_output"
fi
rm "$tmp/bin/cygpath"

# --- Test 6: a file that does not compile is named ----------------------------
#
# A compile error stops its whole bundle from loading, and can stop other
# files loading too. The compiler names the file; the load failures do not.

run_script "$tmp" FLUTTER_TEST_FAIL=compile
if [ "$(listed_under 'did not compile')" = 'test/b_test.dart ' ]; then
    pass 'names the file that did not compile'
else
    fail 'names the file that did not compile' \
        "listed: '$(listed_under 'did not compile')'; output: $run_output"
fi
assert_contains lacks "$run_output" 'Could not load' \
    'does not blame files that failed to load because of it'

run_script "$tmp" FLUTTER_TEST_FAIL=load
if [ "$(listed_under 'Could not load')" = 'test/a_test.dart test/b_test.dart ' ]; then
    pass 'a bundle that failed to load is listed as its test files'
else
    fail 'a bundle that failed to load is listed as its test files' \
        "listed: '$(listed_under 'Could not load')'; output: $run_output"
fi

# --- Test 7: a command-line limit rebundles or runs unbundled -----------------
#
# Windows' cmd.exe line limit (8,191 characters) is below the 182 entrypoints
# of 40-file bundles, so where a limit applies the script rebundles with more
# files per bundle until the list fits, still in one call.

cat > "$tmp/bin/python3" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >> "$tmp/python_args"
exec "$REAL_PYTHON" "\$@"
STUB
chmod +x "$tmp/bin/python3"

: > "$tmp/python_args"
run_script "$tmp" RUN_ALL_TESTS_ARG_LIMIT=100000
assert_contains lacks "$(cat "$tmp/python_args")" '--max-files 80' \
    'bundles once when the list fits the limit'

: > "$tmp/python_args"
run_script "$tmp" RUN_ALL_TESTS_ARG_LIMIT=10
assert_contains has "$(cat "$tmp/python_args")" '--max-files 640' \
    'tries larger bundles when the list is over the limit'
if [ "$flutter_calls" -eq 1 ] && [ "$run_status" -eq 0 ]; then
    assert_contains lacks "$flutter_args" 'bundle_' \
        'runs unbundled in one call when no bundle size fits'
else
    fail 'runs unbundled in one call when no bundle size fits' \
        "exit $run_status, $flutter_calls calls: $flutter_args"
fi
rm "$tmp/bin/python3"

# --- Test 8: bundler output with Windows line endings -------------------------
#
# Under Git Bash a native Windows python3 prints CRLF, and a carriage return
# left on a path would make flutter test fail to open every bundle.

cat > "$tmp/bin/python3" <<STUB
#!/bin/bash
"$REAL_PYTHON" "\$@" | sed 's/\$/\r/'
exit "\${PIPESTATUS[0]}"
STUB
chmod +x "$tmp/bin/python3"
run_script "$tmp"
case "$flutter_args" in
    *$'\r'*)
        fail 'strips carriage returns from the bundler output' 'flutter was invoked with a carriage return'
        ;;
    *'test/.bundles/'*)
        pass 'strips carriage returns from the bundler output'
        ;;
    *)
        fail 'strips carriage returns from the bundler output' "flutter was invoked as: $flutter_args"
        ;;
esac
rm "$tmp/bin/python3"

# --- Test 9: without a working python3 the files run one by one --------------
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
if [ "$run_status" -eq 0 ] && [ "$flutter_calls" -eq 1 ]; then
    assert_contains lacks "$flutter_args" 'bundle_' 'falls back to separate test files'
else
    fail 'falls back to separate test files' "exit $run_status; flutter test args: '$flutter_args'"
fi

rm -rf "$tmp"

# --- Summary ---------------------------------------------------------------

if [ "$failures" -eq 0 ]; then
    printf '\nAll run_all_tests.sh tests passed.\n'
    exit 0
fi

printf '\n%d run_all_tests.sh test(s) failed.\n' "$failures"
exit 1
