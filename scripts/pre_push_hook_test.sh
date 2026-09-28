#!/bin/bash
#
# Tests for hooks/pre-push.
#
# Both regressions covered here caused the same user-visible symptom -- a push
# rejected for reasons that had nothing to do with the change being pushed --
# and both are invisible to `bash -n`, so they need an executable test.
#
# No Flutter or Dart toolchain is required: `dart` and `flutter` are stubbed on
# PATH, and DRY_RUN=1 stops the hook before it would run a test suite. That
# keeps this runnable in the CI script-tests job, which has no Flutter.
#
# Usage: bash scripts/pre_push_hook_test.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SRC="$REPO_ROOT/hooks/pre-push"
ZERO="0000000000000000000000000000000000000000"

failures=0

pass() { printf 'ok   - %s\n' "$1"; }
fail() {
    printf 'FAIL - %s\n' "$1"
    if [ -n "${2:-}" ]; then
        printf '       %s\n' "$2"
    fi
    failures=$((failures + 1))
}

# Stub the toolchain so no Flutter or Dart install is needed.
#   flutter: records the directory it was called from -- the assertion target
#            for the wrong-tree regression (test 1).
#   dart:    records its argument list, so the format-scoping test can prove the
#            hook stopped passing '.' and started passing explicit paths.
write_stubs() {
    stub_tmp="$1"
    mkdir -p "$stub_tmp/bin"

    # flutter test also records its arguments and how many bundles existed
    # while it ran, and with FLUTTER_TEST_FAIL=1 fails the way a real run
    # prints it: the entrypoint as an absolute path, then the test's name. In
    # a bundle that name starts with the file's path relative to test/; a file
    # that ran on its own is the entrypoint itself.
    cat > "$stub_tmp/bin/flutter" <<'STUB'
#!/bin/bash
pwd -P >> "$CWD_LOG"
if [ "${1:-}" = "test" ] && [ -n "${FLUTTER_TEST_LOG:-}" ]; then
    printf '%s\n' "$*" >> "$FLUTTER_TEST_LOG"
    find test/.bundles -name 'bundle_*.dart' 2>/dev/null | wc -l | tr -d ' ' \
        >> "$FLUTTER_TEST_LOG.bundles"
    if [ "${FLUTTER_TEST_FAIL:-0}" = "1" ]; then
        root="$(pwd -P)"
        echo "00:01 +1 -1: $root/test/.bundles/bundle_000_root.dart: b_test.dart fails on purpose [E]"
        echo "00:02 +1 -2: $root/test/a_test.dart: fails while running alone [E]"
        echo "00:02 +1 -2: $root/test/.bundles/bundle_000_root.dart: b_test.dart (tearDownAll)"
        echo "00:02 +1 -2: Some tests failed."
        exit 1
    fi
fi
exit 0
STUB

    cat > "$stub_tmp/bin/dart" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$DART_LOG"
exit 0
STUB

    chmod +x "$stub_tmp/bin/flutter" "$stub_tmp/bin/dart"
}

# Build a repo whose layout mirrors the real one: a main checkout that owns
# hooks/, plus a linked worktree on its own branch. Echoes the temp dir.
#
# $1 is a lib file added on the worktree branch but with NO mirrored test, used
# by the silent-abort case; pass an empty string to skip it. Its name must sort
# AFTER 'sample' -- see the ordering note on test 2.
make_fixture() {
    orphan_lib="$1"

    tmp="$(mktemp -d)"
    main_tree="$tmp/main"

    mkdir -p "$main_tree"
    cd "$main_tree" || exit 1

    git init -q -b main .
    git config user.email 'test@example.com'
    git config user.name 'Test'
    git config commit.gpgsign false

    mkdir -p lib test hooks
    printf '// lib\n' > lib/sample.dart
    printf "import 'package:submersion/sample.dart';\n" > test/sample_test.dart
    git add -A
    git commit -q -m 'initial'

    # The hook lives in the MAIN checkout only. core.hooksPath is an absolute
    # path in the real repo, so every worktree executes this exact file.
    cp "$HOOK_SRC" "$main_tree/hooks/pre-push"
    chmod +x "$main_tree/hooks/pre-push"

    git worktree add -q "$tmp/wt" -b feature
    cd "$tmp/wt" || exit 1
    printf '// changed on the branch\n' >> lib/sample.dart
    if [ -n "$orphan_lib" ]; then
        printf '// no mirrored test exists for this file\n' > "lib/$orphan_lib.dart"
    fi
    git add -A
    git commit -q -m 'change on feature'

    write_stubs "$tmp"

    printf '%s\n' "$tmp"
}

# Run the main checkout's hook with the worktree as the working directory,
# feeding it a ref line the way git does for a brand-new branch (all-zero
# remote sha). Sets: hook_status, hook_output, analyze_cwd.
# Extra NAME=VALUE arguments after $1 are exported into the hook's environment,
# which is how the escape-hatch tests drive RUN_ALL_AFFECTED.
run_hook() {
    tmp="$1"
    shift

    cd "$tmp/wt" || exit 1
    : > "$tmp/cwd.log"
    : > "$tmp/dart.log"
    : > "$tmp/flutter_test.log"
    : > "$tmp/flutter_test.log.bundles"

    printf 'refs/heads/feature %s refs/heads/feature %s\n' \
        "$(git rev-parse HEAD)" "$ZERO" > "$tmp/refline"

    hook_output="$(env "$@" PATH="$tmp/bin:$PATH" CWD_LOG="$tmp/cwd.log" \
        DART_LOG="$tmp/dart.log" FLUTTER_TEST_LOG="$tmp/flutter_test.log" \
        DRY_RUN=1 \
        /bin/bash "$tmp/main/hooks/pre-push" < "$tmp/refline" 2>&1)"
    hook_status=$?

    analyze_cwd="$(head -1 "$tmp/cwd.log" 2>/dev/null || true)"
    dart_args="$(cat "$tmp/dart.log" 2>/dev/null || true)"
    flutter_test_args="$(cat "$tmp/flutter_test.log" 2>/dev/null || true)"
    bundles_during_run="$(head -1 "$tmp/flutter_test.log.bundles" 2>/dev/null || true)"
}

# As run_hook, but the caller supplies the whole ref line. Used to simulate a
# push range git cannot resolve.
run_hook_refline() {
    tmp="$1"
    refline="$2"
    shift 2

    cd "$tmp/wt" || exit 1
    : > "$tmp/cwd.log"
    : > "$tmp/dart.log"

    printf '%s\n' "$refline" > "$tmp/refline"

    hook_output="$(env "$@" PATH="$tmp/bin:$PATH" CWD_LOG="$tmp/cwd.log" \
        DART_LOG="$tmp/dart.log" DRY_RUN=1 \
        /bin/bash "$tmp/main/hooks/pre-push" < "$tmp/refline" 2>&1)"
    hook_status=$?

    dart_args="$(cat "$tmp/dart.log" 2>/dev/null || true)"
}

# Assert that the DRY_RUN test list does (or does not) contain a path.
# $1 = 'has' | 'lacks', $2 = path, $3 = test name
assert_selected() {
    case "$hook_output" in
        *"$2"*) got=has ;;
        *)      got=lacks ;;
    esac
    if [ "$got" = "$1" ]; then
        pass "$3"
    else
        fail "$3" "expected to $1 '$2'; selection was:
$hook_output"
    fi
}

# --- Test 1: the checks must run against the tree being pushed --------------
#
# Regression: PROJECT_ROOT was derived from "$0", which with an absolute
# core.hooksPath always resolves into the main checkout. Every worktree push
# therefore formatted, analyzed and tested the main checkout instead.

tmp="$(make_fixture '')"
run_hook "$tmp"

want="$(cd "$tmp/wt" && pwd -P)"
notwant="$(cd "$tmp/main" && pwd -P)"

if [ "$analyze_cwd" = "$want" ]; then
    pass 'runs the checks in the worktree being pushed'
elif [ "$analyze_cwd" = "$notwant" ]; then
    fail 'runs the checks in the worktree being pushed' \
        "ran in the main checkout ($analyze_cwd) instead of the worktree"
else
    fail 'runs the checks in the worktree being pushed' \
        "expected '$want', flutter ran in '$analyze_cwd'"
fi

if [ "$hook_status" -eq 0 ]; then
    pass 'exits 0 for a clean push'
else
    fail 'exits 0 for a clean push' "exit $hook_status: $hook_output"
fi

rm -rf "$tmp"

# --- Test 2: a missing mirrored test path must not abort the hook -----------
#
# Regression: the resolver ended with `[ -f "$t" ] && printf ...` as the last
# statement of a while loop inside $(...). A false test on the final iteration
# propagated 1 out through the substitution to the assignment, and set -e then
# killed the hook with no message -- git reported only "failed to push some
# refs". lib/X.dart -> test/X_test.dart is a guess, so missing paths are normal.
#
# ORDERING MATTERS. Candidates are piped through `sort -u`, and only the LAST
# iteration's exit status escapes the loop. The missing path must therefore sort
# after every existing one, hence the 'zzz_' prefix: named so it sorted before
# 'sample', the loop would end on the existing test/sample_test.dart, return 0,
# and this test would pass against the buggy hook while proving nothing.

tmp="$(make_fixture 'zzz_orphan')"
run_hook "$tmp"

if [ "$hook_status" -eq 0 ]; then
    pass 'survives a changed lib file whose mirrored test does not exist'
else
    fail 'survives a changed lib file whose mirrored test does not exist' \
        "hook exited $hook_status; output: $hook_output"
fi

case "$hook_output" in
    *DRY_RUN*)
        pass 'reaches the test-resolution stage instead of aborting early'
        ;;
    *)
        fail 'reaches the test-resolution stage instead of aborting early' \
            "output did not mention DRY_RUN: $hook_output"
        ;;
esac

rm -rf "$tmp"

# Build a repo with enough structure to exercise proximity ranking: two feature
# areas, a domain file in a third directory, and a generated l10n file with a
# large importer set. Echoes the temp dir. $1 is a space-separated list of lib
# paths to modify on the feature branch.
make_proximity_fixture() {
    to_change="$1"

    tmp="$(mktemp -d)"
    main_tree="$tmp/main"

    mkdir -p "$main_tree"
    cd "$main_tree" || exit 1

    git init -q -b main .
    git config user.email 'test@example.com'
    git config user.name 'Test'
    git config commit.gpgsign false

    mkdir -p lib/features/alpha/presentation/pages lib/features/alpha/domain \
             lib/features/beta/presentation/pages lib/l10n/arb hooks \
             test/features/alpha/presentation/pages \
             test/features/beta/presentation/pages test/features/gamma

    mkdir -p test/features/delta
    printf '// entrypoint\n' > lib/main.dart
    printf "import 'package:submersion/main.dart';\n" \
        > test/features/delta/main_importer_test.dart

    printf '// alpha page\n' > lib/features/alpha/presentation/pages/alpha_page.dart
    printf '// alpha entity\n' > lib/features/alpha/domain/alpha_entity.dart
    printf '// beta page\n'  > lib/features/beta/presentation/pages/beta_page.dart
    printf '// generated\n'  > lib/l10n/arb/app_localizations.dart

    # NEAR: shares features/alpha/presentation with the changed page, and is
    # also its mirrored unit test.
    printf "import 'package:submersion/features/alpha/presentation/pages/alpha_page.dart';\n" \
        > test/features/alpha/presentation/pages/alpha_page_test.dart

    # FAR + single hit: imports one changed file from another feature area.
    printf "import 'package:submersion/features/alpha/presentation/pages/alpha_page.dart';\n" \
        > test/features/beta/presentation/pages/beta_only_far_test.dart

    # FAR + multi hit: imports TWO changed files, so the orthogonal signal
    # should rescue it even though proximity would drop it.
    {
        printf "import 'package:submersion/features/alpha/presentation/pages/alpha_page.dart';\n"
        printf "import 'package:submersion/features/alpha/domain/alpha_entity.dart';\n"
    } > test/features/beta/presentation/pages/beta_multi_hit_test.dart

    # 60 importers of the generated l10n file, so a 40-file sample is a strict
    # subset and "sampled" is distinguishable from "all".
    for i in $(seq 1 60); do
        printf "import 'package:submersion/l10n/arb/app_localizations.dart';\n" \
            > "test/features/gamma/l10n_${i}_test.dart"
    done

    git add -A
    git commit -q -m 'initial'

    cp "$HOOK_SRC" "$main_tree/hooks/pre-push"
    chmod +x "$main_tree/hooks/pre-push"

    git worktree add -q "$tmp/wt" -b feature
    cd "$tmp/wt" || exit 1
    for f in $to_change; do
        printf '// changed on the branch\n' >> "$f"
    done
    git add -A
    git commit -q -m 'change on feature'

    write_stubs "$tmp"

    printf '%s\n' "$tmp"
}

# --- Test 3: proximity ranking ---------------------------------------------
#
# A fan-out of every test importing a changed lib file makes half of all pushes
# run 378+ files, dominated by generated-l10n importers. Selection is now tiered:
# changed tests and mirrored tests always run, plus importers in the same feature
# area, plus importers hit by two or more changed files. Distant single-hit
# importers are left to CI.

tmp="$(make_proximity_fixture \
    'lib/features/alpha/presentation/pages/alpha_page.dart lib/features/alpha/domain/alpha_entity.dart')"
run_hook "$tmp"

assert_selected has 'test/features/alpha/presentation/pages/alpha_page_test.dart' \
    'keeps the mirrored test for a changed lib file'
assert_selected has 'test/features/beta/presentation/pages/beta_multi_hit_test.dart' \
    'keeps a distant test that imports two or more changed files'
assert_selected lacks 'test/features/beta/presentation/pages/beta_only_far_test.dart' \
    'drops a distant test that imports only one changed file'

# --- Test 4: the format check is scoped to the changed files ----------------
#
# `dart format --set-exit-if-changed .` walks the whole repo for 20s on every
# push. The hook already knows which files changed; formatting only those is
# effectively free, and CI still formats everything.

case "$dart_args" in
    *'lib/features/alpha/presentation/pages/alpha_page.dart'*)
        pass 'passes the changed dart files to the format check'
        ;;
    *)
        fail 'passes the changed dart files to the format check' \
            "dart was invoked as: $dart_args"
        ;;
esac

case "$dart_args" in
    *'--set-exit-if-changed .'|*'--set-exit-if-changed .'*)
        fail 'does not format the entire repository' \
            "dart was invoked as: $dart_args"
        ;;
    *)
        pass 'does not format the entire repository'
        ;;
esac

# --- Test 5: RUN_ALL_AFFECTED restores the full fan-out ---------------------

run_hook "$tmp" RUN_ALL_AFFECTED=1
assert_selected has 'test/features/beta/presentation/pages/beta_only_far_test.dart' \
    'RUN_ALL_AFFECTED=1 restores distant single-hit importers'

rm -rf "$tmp"

# --- Test 6: an l10n-only change runs a bounded sample ----------------------
#
# lib/l10n/arb/app_localizations.dart is generated and imported by 378 real test
# files, so regenerating it used to trigger a 378-file run for what is usually a
# string edit. A removed key is a compile error `flutter analyze` already
# catches; a changed string VALUE can still break a find.text assertion, so keep
# a bounded, deterministic sample rather than dropping the tier entirely.

tmp="$(make_proximity_fixture 'lib/l10n/arb/app_localizations.dart')"
run_hook "$tmp"

selected_l10n="$(printf '%s\n' "$hook_output" | grep -c 'test/features/gamma/l10n_' || true)"
if [ "$selected_l10n" -eq 40 ]; then
    pass 'samples exactly 40 l10n importers instead of all 60'
else
    fail 'samples exactly 40 l10n importers instead of all 60' \
        "selected $selected_l10n of 60"
fi

# The sample must be stable for a given commit, or a re-push would silently
# test a different set and a flake would be impossible to reproduce.
first_sample="$(printf '%s\n' "$hook_output" | grep 'test/features/gamma/l10n_' | sort)"
run_hook "$tmp"
second_sample="$(printf '%s\n' "$hook_output" | grep 'test/features/gamma/l10n_' | sort)"
if [ "$first_sample" = "$second_sample" ]; then
    pass 'the l10n sample is deterministic for a given commit'
else
    fail 'the l10n sample is deterministic for a given commit' 'sample changed between runs'
fi

rm -rf "$tmp"

# --- Test 7: a top-level lib file has no feature area -----------------------
#
# Proximity compares the first 3 path segments of a changed file's DIRECTORY.
# lib/main.dart has none, so `dirname` yields "." and the comparison can never
# match, which would silently drop every importer of the app entrypoint.
# Depth-0 changes therefore keep the whole importer set.

tmp="$(make_proximity_fixture 'lib/main.dart')"
run_hook "$tmp"

assert_selected has 'test/features/delta/main_importer_test.dart' \
    'keeps importers of a changed top-level lib file'

rm -rf "$tmp"

# --- Test 8: an unresolvable push range formats the whole project -----------
#
# Scoping the format check to the changed files is only safe when we actually
# KNOW what changed. A remote sha git cannot resolve (force-pushed away, partial
# clone, corrupt object) makes the diff fail; if the hook still treated the range
# as resolved it would format an empty list and report a pass having checked
# nothing. Reported by review on PR #1058.

tmp="$(make_proximity_fixture 'lib/features/alpha/presentation/pages/alpha_page.dart')"
cd "$tmp/wt" || exit 1
missing='deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'
run_hook_refline "$tmp" \
    "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $missing"

case "$dart_args" in
    *'--set-exit-if-changed .')
        pass 'formats the whole project when the push range cannot be resolved'
        ;;
    *)
        fail 'formats the whole project when the push range cannot be resolved' \
            "dart was invoked as: $dart_args"
        ;;
esac

rm -rf "$tmp"

# --- Test 9: bad env overrides warn instead of aborting the push ------------
#
# TEST_CONCURRENCY and L10N_SAMPLE are interpolated into `flutter test
# --concurrency=` and `head -n`. Under set -e a non-numeric value made those
# commands fail and killed the push with a cryptic error. Reported by review on
# PR #1058.

tmp="$(make_proximity_fixture 'lib/l10n/arb/app_localizations.dart')"
run_hook "$tmp" TEST_CONCURRENCY=abc L10N_SAMPLE=notanumber

if [ "$hook_status" -eq 0 ]; then
    pass 'survives non-numeric TEST_CONCURRENCY and L10N_SAMPLE'
else
    fail 'survives non-numeric TEST_CONCURRENCY and L10N_SAMPLE' \
        "hook exited $hook_status: $hook_output"
fi

case "$hook_output" in
    *'invalid TEST_CONCURRENCY'*)
        pass 'warns about an invalid TEST_CONCURRENCY'
        ;;
    *)
        fail 'warns about an invalid TEST_CONCURRENCY' "output: $hook_output"
        ;;
esac

case "$hook_output" in
    *'invalid L10N_SAMPLE'*)
        pass 'warns about an invalid L10N_SAMPLE'
        ;;
    *)
        fail 'warns about an invalid L10N_SAMPLE' "output: $hook_output"
        ;;
esac

# The bad sample size must fall back to the default, not to "everything".
selected_l10n="$(printf '%s\n' "$hook_output" | grep -c 'test/features/gamma/l10n_' || true)"
if [ "$selected_l10n" -eq 40 ]; then
    pass 'falls back to the default sample size of 40'
else
    fail 'falls back to the default sample size of 40' "selected $selected_l10n of 60"
fi

rm -rf "$tmp"

# Build a repo for the full-suite path: runnable test files and the real
# bundler, which the hook calls from the tree being pushed. Echoes the temp dir.
make_full_run_fixture() {
    tmp="$(mktemp -d)"
    main_tree="$tmp/main"

    mkdir -p "$main_tree"
    cd "$main_tree" || exit 1

    git init -q -b main .
    git config user.email 'test@example.com'
    git config user.name 'Test'
    git config commit.gpgsign false

    mkdir -p lib test hooks scripts
    printf '// lib\n' > lib/sample.dart
    for name in a b; do
        printf "import 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('%s', () {});\n}\n" \
            "$name" > "test/${name}_test.dart"
    done
    cp "$REPO_ROOT/scripts/bundle_tests.py" scripts/bundle_tests.py
    git add -A
    git commit -q -m 'initial'

    cp "$HOOK_SRC" "$main_tree/hooks/pre-push"
    chmod +x "$main_tree/hooks/pre-push"

    git worktree add -q "$tmp/wt" -b feature
    cd "$tmp/wt" || exit 1
    printf '// changed on the branch\n' >> lib/sample.dart
    git add -A
    git commit -q -m 'change on feature'

    write_stubs "$tmp"

    printf '%s\n' "$tmp"
}

# --- Test 10: RUN_ALL_TESTS=1 runs the suite as bundles ---------------------
#
# A full local run as separate files took 10m11s at -j 16; as bundles of up to
# 40 files it took 2m52s (issue #2512). The bundles are generated for the run
# and removed afterwards, so they never reach a commit or a later run.

tmp="$(make_full_run_fixture)"
run_hook "$tmp" RUN_ALL_TESTS=1

case "$flutter_test_args" in
    *'test/.bundles/bundle_'*)
        pass 'RUN_ALL_TESTS=1 hands flutter test the generated bundles'
        ;;
    *)
        fail 'RUN_ALL_TESTS=1 hands flutter test the generated bundles' \
            "flutter was invoked as: $flutter_test_args"
        ;;
esac

case "$flutter_test_args" in
    *'--exclude-tags performance'*'--concurrency='*)
        pass 'the bundled run keeps the tag filter and the concurrency'
        ;;
    *)
        fail 'the bundled run keeps the tag filter and the concurrency' \
            "flutter was invoked as: $flutter_test_args"
        ;;
esac

if [ "${bundles_during_run:-0}" -gt 0 ] && [ ! -e "$tmp/wt/test/.bundles" ]; then
    pass 'the bundles exist during the run and are removed after it'
else
    fail 'the bundles exist during the run and are removed after it' \
        "bundles during the run: '${bundles_during_run}'; left behind: $(ls "$tmp/wt/test/.bundles" 2>&1)"
fi

if [ "$hook_status" -eq 0 ]; then
    pass 'a passing bundled run lets the push through'
else
    fail 'a passing bundled run lets the push through' "exit $hook_status: $hook_output"
fi

# --- Test 11: a failing bundled run names the failing test files ------------

run_hook "$tmp" RUN_ALL_TESTS=1 FLUTTER_TEST_FAIL=1

if [ "$hook_status" -ne 0 ]; then
    pass 'a failing bundled run blocks the push'
else
    fail 'a failing bundled run blocks the push' "exit 0: $hook_output"
fi

failing_list="$(printf '%s\n' "$hook_output" | sed -n '/Failing test files/,$p' \
    | grep -E '^ +test/' | sed 's/^ *//' | sort | tr '\n' ' ')"
if [ "$failing_list" = 'test/a_test.dart test/b_test.dart ' ]; then
    pass 'a failing run lists each failing test file once, relative to the repo'
else
    fail 'a failing run lists each failing test file once, relative to the repo' \
        "listed: '$failing_list'; output: $hook_output"
fi

if [ ! -e "$tmp/wt/test/.bundles" ]; then
    pass 'the bundles are removed after a failing run too'
else
    fail 'the bundles are removed after a failing run too' \
        "left behind: $(ls "$tmp/wt/test/.bundles" 2>&1)"
fi

# --- Test 12: without a working python3 the full run is unbundled -----------
#
# The hook had no Python dependency before bundling, and Git Bash on Windows
# may have none. A bundler that cannot run must not block a push.

cat > "$tmp/bin/python3" <<'STUB'
#!/bin/bash
echo 'python3: not usable here' >&2
exit 127
STUB
chmod +x "$tmp/bin/python3"
run_hook "$tmp" RUN_ALL_TESTS=1

if [ "$hook_status" -eq 0 ] && [ -n "$flutter_test_args" ]; then
    pass 'RUN_ALL_TESTS=1 still runs when python3 cannot bundle'
else
    fail 'RUN_ALL_TESTS=1 still runs when python3 cannot bundle' \
        "exit $hook_status; flutter test args: '$flutter_test_args'"
fi

case "$flutter_test_args" in
    *'bundle_'*)
        fail 'falls back to separate test files' "flutter was invoked as: $flutter_test_args"
        ;;
    *)
        pass 'falls back to separate test files'
        ;;
esac

rm -rf "$tmp"

# --- Summary ---------------------------------------------------------------

if [ "$failures" -eq 0 ]; then
    printf '\nAll pre-push hook tests passed.\n'
    exit 0
fi

printf '\n%d pre-push hook test(s) failed.\n' "$failures"
exit 1
