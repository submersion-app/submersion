#!/usr/bin/env bash
# Tests for distribute_testflight_beta.sh, the "Distribute to Public Beta
# group" step of both TestFlight jobs in .github/workflows/beta.yml.
#
# The property that matters: Apple's beta review submission limit is not a
# failure. Apple meters Public Beta submissions (about six a day for macOS), so
# a busy merge day used to turn every later macOS beta red, open a beta-failure
# alert and need a manual re-run (issue #3715). The build is uploaded either
# way; the next beta after the limit clears goes to Public Beta. Every other
# distribution error still fails the step.
#
# fastlane and sleep are exercised through stubs injected with
# DISTRIBUTE_FASTLANE= and DISTRIBUTE_SLEEP=, so this suite runs on Linux and
# never touches the network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTRIBUTE="$SCRIPT_DIR/distribute_testflight_beta.sh"
WORKFLOW="$SCRIPT_DIR/../../.github/workflows/beta.yml"

fail() { echo "FAIL: $1"; exit 1; }

STUBDIR=$(mktemp -d)
# The stubs find their outcome and record files through it.
export STUBDIR
trap 'rm -rf "$STUBDIR"' EXIT

# Copied from the failed macOS distribution of Beta v1.8.3.9072 (run
# 40256675930). fastlane prints Apple's message on its own line and again on
# the Spaceship::UnexpectedResponse that ends the lane.
LIMIT_ERROR='[!] Submission limit has been reached. - Submission limit has been reached. (Spaceship::UnexpectedResponse)'

# Each call takes the next line of the outcomes file: "ok" succeeds, "limit"
# fails the way Apple's submission limit does, and "fail" fails with an
# unrelated error. Running past the end of the file is a test bug.
cat > "$STUBDIR/fastlane" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "\$STUBDIR/calls"
n=\$(wc -l < "\$STUBDIR/calls")
outcome=\$(sed -n "\${n}p" "\$STUBDIR/outcomes")
echo "Distributing new build to testers"
case "\$outcome" in
  ok) echo "Successfully distributed build to External testers" ;;
  limit) echo "$LIMIT_ERROR" >&2; exit 1 ;;
  fail) echo "[!] Authentication credentials are missing or invalid." >&2; exit 1 ;;
  *) echo "stub: no outcome for call \$n" >&2; exit 99 ;;
esac
STUB
cat > "$STUBDIR/sleep" <<'STUB'
#!/usr/bin/env bash
echo "$1" >> "$STUBDIR/sleeps"
STUB
chmod +x "$STUBDIR/fastlane" "$STUBDIR/sleep"

# run PLATFORM OUTCOME...: runs the script with one stub outcome per fastlane
# call, leaving its exit code in STATUS and its combined output in OUT.
run() {
  local platform=$1
  shift
  printf '%s\n' "$@" > "$STUBDIR/outcomes"
  : > "$STUBDIR/calls"
  : > "$STUBDIR/sleeps"
  STATUS=0
  OUT=$(DISTRIBUTE_FASTLANE="$STUBDIR/fastlane" \
    DISTRIBUTE_SLEEP="$STUBDIR/sleep" \
    APP_VERSION=1.8.3 BUILD_NUMBER=9072 \
    "$DISTRIBUTE" "$platform" 2>&1) || STATUS=$?
}

calls() { wc -l < "$STUBDIR/calls" | tr -d ' '; }
sleeps() { tr '\n' ' ' < "$STUBDIR/sleeps" | sed 's/ $//'; }

# --- Happy path: one distribution, no waiting --------------------------------
run macos ok
[ "$STATUS" -eq 0 ] || fail "happy path exited $STATUS: $OUT"
[ "$(calls)" -eq 1 ] || fail "happy path: call count $(calls)"
[ -z "$(sleeps)" ] || fail "happy path slept: $(sleeps)"
grep -qx "distribute_testflight_beta app_version:1.8.3 build_number:9072" \
  "$STUBDIR/calls" || fail "fastlane command line: $(cat "$STUBDIR/calls")"

# --- The submission limit passes with a warning (issue #3715) ----------------
run macos limit
[ "$STATUS" -eq 0 ] || fail "the submission limit failed the step ($STATUS): $OUT"
[ "$(calls)" -eq 1 ] || fail "the submission limit was retried: $(calls) calls"
[ -z "$(sleeps)" ] || fail "the submission limit waited to retry: $(sleeps)"
echo "$OUT" | grep -q "^::warning title=TestFlight submission limit::" \
  || fail "the submission limit is not annotated as a warning: $OUT"
echo "$OUT" | grep -q "1.8.3 (9072)" \
  || fail "the warning does not name the undistributed build: $OUT"
echo "$OUT" | grep -q "cd macos && bundle exec fastlane distribute_testflight_beta app_version:1.8.3 build_number:9072" \
  || fail "the warning has no recovery command for macOS: $OUT"
! echo "$OUT" | grep -q "^::error" \
  || fail "the submission limit still reported an error: $OUT"

# The iOS step runs the same script; its recovery command names its own lane.
run ios limit
[ "$STATUS" -eq 0 ] || fail "iOS submission limit exited $STATUS: $OUT"
echo "$OUT" | grep -q "cd ios && bundle exec fastlane distribute_testflight_beta" \
  || fail "the iOS warning has no recovery command for iOS: $OUT"

# --- The limit after a transient failure still passes ------------------------
run macos fail limit
[ "$STATUS" -eq 0 ] || fail "limit on the second attempt exited $STATUS: $OUT"
[ "$(calls)" -eq 2 ] || fail "limit on the second attempt: call count $(calls)"
[ "$(sleeps)" = "60" ] || fail "limit on the second attempt: sleeps '$(sleeps)'"

# --- A transient failure is still retried, as before -------------------------
run macos fail ok
[ "$STATUS" -eq 0 ] || fail "retry exited $STATUS: $OUT"
[ "$(calls)" -eq 2 ] || fail "retry: call count $(calls)"
[ "$(sleeps)" = "60" ] || fail "retry backoff: got '$(sleeps)'"

# --- Any other error still fails the step after every attempt ----------------
run macos fail fail fail
[ "$STATUS" -ne 0 ] || fail "a persistent distribution error exited 0"
[ "$(calls)" -eq 3 ] || fail "persistent failure: call count $(calls)"
[ "$(sleeps)" = "60 60" ] || fail "persistent failure backoff: '$(sleeps)'"
echo "$OUT" | grep -q "^::error::Distribution failed after 3 attempts" \
  || fail "a persistent failure has no error annotation: $OUT"
echo "$OUT" | grep -q "cd macos && bundle exec fastlane distribute_testflight_beta" \
  || fail "a persistent failure has no recovery command: $OUT"

# --- Usage errors ------------------------------------------------------------
# Each is rejected before fastlane runs. A non-zero exit alone would not show
# that: a failing stub distribution also exits non-zero.
usage_run() {
  : > "$STUBDIR/calls"
  STATUS=0
  OUT=$(DISTRIBUTE_FASTLANE="$STUBDIR/fastlane" DISTRIBUTE_SLEEP="$STUBDIR/sleep" "$@" 2>&1) \
    || STATUS=$?
  [ ! -s "$STUBDIR/calls" ] || fail "fastlane ran despite a usage error: $OUT"
}

usage_run env APP_VERSION=1.8.3 BUILD_NUMBER=9072 "$DISTRIBUTE"
[ "$STATUS" -eq 2 ] || fail "no platform argument exited $STATUS"

usage_run env APP_VERSION=1.8.3 BUILD_NUMBER=9072 "$DISTRIBUTE" android
[ "$STATUS" -eq 2 ] || fail "an unknown platform exited $STATUS"

usage_run env APP_VERSION='' BUILD_NUMBER=9072 "$DISTRIBUTE" macos
[ "$STATUS" -ne 0 ] || fail "an empty APP_VERSION was accepted"

usage_run env APP_VERSION=1.8.3 BUILD_NUMBER='' "$DISTRIBUTE" ios
[ "$STATUS" -ne 0 ] || fail "an empty BUILD_NUMBER was accepted"

# --- Both TestFlight jobs use this script ------------------------------------
# A job that kept its own inline copy would keep failing on the limit.
grep -q "distribute_testflight_beta.sh ios" "$WORKFLOW" \
  || fail "the iOS Distribute to Public Beta group step does not run this script"
grep -q "distribute_testflight_beta.sh macos" "$WORKFLOW" \
  || fail "the macOS Distribute to Public Beta group step does not run this script"
! grep -q "Submission limit has been reached" "$WORKFLOW" \
  || fail "beta.yml still handles the submission limit inline"

echo "distribute_testflight_beta_test: all passed"
