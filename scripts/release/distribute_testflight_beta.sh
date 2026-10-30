#!/usr/bin/env bash
# Distributes an uploaded TestFlight beta to the Public Beta group. This is the
# "Distribute to Public Beta group" step of both TestFlight jobs in
# .github/workflows/beta.yml, kept here so distribute_testflight_beta_test.sh
# can drive it with a stub fastlane.
#
# Apple meters Public Beta review submissions: macOS refuses the seventh in any
# 24 hours with "Submission limit has been reached". That is not a failure. The
# build is uploaded and processed, and every beta submits its own build, so the
# next beta after the limit clears puts a newer one in front of Public Beta
# testers. Failing on it turned every busy merge day into a red macOS lane, a
# beta-failure alert and a manual re-run that hit the same limit (issue #3715).
# Any other error still fails the step.
#
# Usage: distribute_testflight_beta.sh <ios|macos>
# Run from that platform's directory, with APP_VERSION and BUILD_NUMBER set to
# the build to distribute.
set -euo pipefail

DISTRIBUTE_SLEEP="${DISTRIBUTE_SLEEP:-sleep}"
if [ -n "${DISTRIBUTE_FASTLANE:-}" ]; then
  FASTLANE_CMD=("$DISTRIBUTE_FASTLANE")
else
  FASTLANE_CMD=(bundle exec fastlane)
fi

if [ "$#" -ne 1 ] || { [ "$1" != ios ] && [ "$1" != macos ]; }; then
  echo "Usage: $0 <ios|macos>" >&2
  exit 2
fi
PLATFORM=$1
for var in APP_VERSION BUILD_NUMBER; do
  if [ -z "${!var:-}" ]; then
    echo "::error::$var is not set" >&2
    exit 1
  fi
done

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
RECOVER="cd $PLATFORM && bundle exec fastlane distribute_testflight_beta app_version:$APP_VERSION build_number:$BUILD_NUMBER"

for attempt in 1 2 3; do
  if "${FASTLANE_CMD[@]}" distribute_testflight_beta \
      app_version:"$APP_VERSION" build_number:"$BUILD_NUMBER" 2>&1 | tee "$LOG"; then
    exit 0
  fi
  # The limit counts submissions over the past day, so it does not clear in a
  # minute; retrying only waits for the same refusal.
  if grep -q "Submission limit has been reached" "$LOG"; then
    echo "::warning title=TestFlight submission limit::Apple refused the Public" \
      "Beta review submission because the daily submission limit is reached." \
      "Build $APP_VERSION ($BUILD_NUMBER) is uploaded and processed but was not" \
      "sent to Public Beta. The next beta after the limit clears goes to Public" \
      "Beta on its own; to send this build instead, run: $RECOVER"
    exit 0
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "::error::Distribution failed after 3 attempts. The binary is uploaded;" \
      "re-run this job, or run: $RECOVER"
    exit 1
  fi
  echo "Distribution attempt $attempt failed, retrying in 60s..."
  "$DISTRIBUTE_SLEEP" 60
done
