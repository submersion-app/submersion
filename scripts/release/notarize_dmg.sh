#!/usr/bin/env bash
# Notarizes a Developer ID DMG and staples the ticket to it. This is the
# Notarize DMG step of the macOS job in .github/workflows/build-all.yml, kept
# here so notarize_dmg_test.sh can drive it with a stub xcrun.
#
# Usage: notarize_dmg.sh <dmg>
# Needs APPLE_ID, APPLE_APP_PASSWORD and APPLE_TEAM_ID in the environment.
set -euo pipefail

XCRUN="${XCRUN:-xcrun}"
NOTARIZE_SLEEP="${NOTARIZE_SLEEP:-sleep}"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <dmg>" >&2
  exit 2
fi
DMG=$1
[ -f "$DMG" ] || { echo "::error::DMG not found: $DMG" >&2; exit 1; }
for var in APPLE_ID APPLE_APP_PASSWORD APPLE_TEAM_ID; do
  if [ -z "${!var:-}" ]; then
    echo "::error::$var is not set" >&2
    exit 1
  fi
done

for attempt in 1 2 3; do
  if "$XCRUN" notarytool submit "$DMG" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "::error::Notarization failed after 3 attempts"
    exit 1
  fi
  echo "Notarization attempt $attempt failed, retrying in 30s..."
  "$NOTARIZE_SLEEP" 30
done

# Stapling is retried on its own. By now Apple has accepted the DMG, and
# `stapler staple` only downloads the issued ticket from CloudKit and embeds
# it. That download dropping its connection (Error 68) failed Beta 8943, 8970,
# 8975 and 8977 (issue #3488); falling back to the submit loop would upload
# and notarize the DMG again just to retry a one-second fetch.
#
# The backoff doubles from 15s and holds at 120s, so the retries span about
# ten minutes. Beta 9107 (issue #3770) lost the connection on every attempt
# of the earlier three-minute budget; most blips still clear on the first
# quick retry.
STAPLE_ATTEMPTS=8
STAPLE_MAX_DELAY=120
delay=15
for ((attempt = 1; attempt <= STAPLE_ATTEMPTS; attempt++)); do
  if "$XCRUN" stapler staple "$DMG"; then
    exit 0
  fi
  if [ "$attempt" -eq "$STAPLE_ATTEMPTS" ]; then
    echo "::error::Stapling failed after $STAPLE_ATTEMPTS attempts." \
      "Check the notarytool status above: if it is Accepted, fetching the" \
      "ticket from CloudKit kept failing; otherwise there is no ticket."
    exit 1
  fi
  echo "::warning::Stapling attempt $attempt/$STAPLE_ATTEMPTS failed," \
    "retrying in ${delay}s..."
  "$NOTARIZE_SLEEP" "$delay"
  delay=$((delay * 2 > STAPLE_MAX_DELAY ? STAPLE_MAX_DELAY : delay * 2))
done
