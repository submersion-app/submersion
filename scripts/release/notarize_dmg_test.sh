#!/usr/bin/env bash
# Tests for notarize_dmg.sh, the Notarize DMG step of the macOS build.
#
# The property that matters: once Apple has accepted the DMG, a failed staple
# is retried on its own, without uploading the DMG again. Beta 8943, 8970,
# 8975 and 8977 all failed that way (issue #3488): notarization came back
# Accepted, then `stapler staple` lost its connection to CloudKit while
# fetching the ticket (Error 68) and nothing retried it.
#
# xcrun and sleep are exercised through stubs injected with XCRUN= and
# NOTARIZE_SLEEP=, so this suite runs on Linux and never touches the network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTARIZE="$SCRIPT_DIR/notarize_dmg.sh"

fail() { echo "FAIL: $1"; exit 1; }

STUBDIR=$(mktemp -d)
# The stubs find their budget and record files through it.
export STUBDIR
trap 'rm -rf "$STUBDIR"' EXIT

DMG="$STUBDIR/Submersion-v1.0.0.1-macOS.dmg"
touch "$DMG"

# The stub fails each subcommand as many times as its budget file says, then
# succeeds. A staple failure exits 68, the code stapler gave in every run.
cat > "$STUBDIR/xcrun" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUBDIR/calls"
case "$1 $2" in
  "notarytool submit") budget="$STUBDIR/submit_fails"; code=1 ;;
  "stapler staple") budget="$STUBDIR/staple_fails"; code=68 ;;
  *) echo "unexpected xcrun call: $*" >&2; exit 99 ;;
esac
left=$(cat "$budget")
if [ "$left" -gt 0 ]; then
  echo $((left - 1)) > "$budget"
  echo "stub: $1 $2 failed" >&2
  exit "$code"
fi
STUB
cat > "$STUBDIR/sleep" <<'STUB'
#!/usr/bin/env bash
echo "$1" >> "$STUBDIR/sleeps"
STUB
chmod +x "$STUBDIR/xcrun" "$STUBDIR/sleep"

# run SUBMIT_FAILS STAPLE_FAILS: runs the script, leaving its exit code in
# STATUS, its combined output in OUT, and the stub's records in the files.
run() {
  echo "$1" > "$STUBDIR/submit_fails"
  echo "$2" > "$STUBDIR/staple_fails"
  : > "$STUBDIR/calls"
  : > "$STUBDIR/sleeps"
  STATUS=0
  OUT=$(XCRUN="$STUBDIR/xcrun" \
    NOTARIZE_SLEEP="$STUBDIR/sleep" \
    APPLE_ID=diver@example.com APPLE_APP_PASSWORD=app-pw APPLE_TEAM_ID=TEAM42 \
    "$NOTARIZE" "$DMG" 2>&1) || STATUS=$?
}

count() { grep -c "^$1" "$STUBDIR/calls" || true; }
sleeps() { tr '\n' ' ' < "$STUBDIR/sleeps" | sed 's/ $//'; }

# --- Happy path: one submit, one staple, no waiting --------------------------
run 0 0
[ "$STATUS" -eq 0 ] || fail "happy path exited $STATUS: $OUT"
[ "$(count 'notarytool submit')" -eq 1 ] || fail "happy path: submit count"
[ "$(count 'stapler staple')" -eq 1 ] || fail "happy path: staple count"
[ -z "$(sleeps)" ] || fail "happy path slept: $(sleeps)"

# The submit carries the credentials and waits for Apple's verdict, and both
# commands act on the DMG named on the command line.
grep -qx "notarytool submit $DMG --apple-id diver@example.com --password app-pw --team-id TEAM42 --wait" \
  "$STUBDIR/calls" || fail "submit command line: $(cat "$STUBDIR/calls")"
grep -qx "stapler staple $DMG" "$STUBDIR/calls" \
  || fail "staple command line: $(cat "$STUBDIR/calls")"

# --- A staple blip is retried without uploading again (issue #3488) ----------
run 0 2
[ "$STATUS" -eq 0 ] || fail "staple retry exited $STATUS: $OUT"
[ "$(count 'notarytool submit')" -eq 1 ] \
  || fail "a staple failure re-submitted the DMG"
[ "$(count 'stapler staple')" -eq 3 ] || fail "staple retry: staple count"
[ "$(sleeps)" = "15 30" ] || fail "staple backoff: got '$(sleeps)'"
echo "$OUT" | grep -q "::warning::Stapling attempt 1/5 failed" \
  || fail "staple retry is not annotated: $OUT"

# --- A staple that never succeeds fails the step, after every attempt --------
run 0 99
[ "$STATUS" -ne 0 ] || fail "persistent staple failure exited 0"
[ "$(count 'notarytool submit')" -eq 1 ] \
  || fail "persistent staple failure re-submitted the DMG"
[ "$(count 'stapler staple')" -eq 5 ] || fail "persistent staple: staple count"
[ "$(sleeps)" = "15 30 45 60" ] || fail "persistent staple backoff: '$(sleeps)'"
echo "$OUT" | grep -q "::error::Stapling failed after 5 attempts" \
  || fail "persistent staple failure has no error annotation: $OUT"

# --- A failed submit is still retried, as before -----------------------------
run 1 0
[ "$STATUS" -eq 0 ] || fail "submit retry exited $STATUS: $OUT"
[ "$(count 'notarytool submit')" -eq 2 ] || fail "submit retry: submit count"
[ "$(count 'stapler staple')" -eq 1 ] || fail "submit retry: staple count"
[ "$(sleeps)" = "30" ] || fail "submit backoff: got '$(sleeps)'"

# --- A submit that never succeeds fails before stapling ----------------------
run 99 0
[ "$STATUS" -ne 0 ] || fail "persistent submit failure exited 0"
[ "$(count 'notarytool submit')" -eq 3 ] || fail "persistent submit: count"
[ "$(count 'stapler staple')" -eq 0 ] || fail "stapled a DMG Apple never accepted"
echo "$OUT" | grep -q "::error::Notarization failed after 3 attempts" \
  || fail "persistent submit failure has no error annotation: $OUT"

# --- Usage errors ------------------------------------------------------------
# Each is rejected before xcrun runs. A non-zero exit alone would not show
# that: a failing stub submit also exits non-zero.
usage_run() {
  : > "$STUBDIR/calls"
  STATUS=0
  OUT=$(XCRUN="$STUBDIR/xcrun" NOTARIZE_SLEEP="$STUBDIR/sleep" "$@" 2>&1) \
    || STATUS=$?
  [ ! -s "$STUBDIR/calls" ] || fail "xcrun ran despite a usage error: $OUT"
}

usage_run env APPLE_ID=a APPLE_APP_PASSWORD=b APPLE_TEAM_ID=c "$NOTARIZE"
[ "$STATUS" -eq 2 ] || fail "no DMG argument exited $STATUS"

usage_run env APPLE_ID='' APPLE_APP_PASSWORD=b APPLE_TEAM_ID=c "$NOTARIZE" "$DMG"
[ "$STATUS" -ne 0 ] || fail "an empty APPLE_ID was accepted"

usage_run env APPLE_ID=a APPLE_APP_PASSWORD=b APPLE_TEAM_ID=c \
  "$NOTARIZE" "$STUBDIR/missing.dmg"
[ "$STATUS" -ne 0 ] || fail "a missing DMG was accepted"

echo "notarize_dmg_test: all passed"
