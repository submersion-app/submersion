#!/usr/bin/env bash
# Guards the App Review notes that deliver uploads with every store
# submission from fastlane/metadata/review_information/notes.txt.
#
# Why they exist: iOS 1.7.4 and 1.7.5 were both rejected under guideline
# 5.1.1(v) ("account deletion") because a reviewer took the first-launch
# "Create Your Profile" step for account creation, and nothing told them
# otherwise. Apple reads these notes before touching the build, so keeping
# them accurate and present is the durable fix.
#
# What is checked:
# - Both platform copies exist and are non-empty, so a submission never goes
#   up silent on one platform. deliver uploads only the files present, so a
#   missing file is a missing field, not an error.
# - The two copies are byte-identical. There is one app and one explanation.
# - The text fits Apple's 4000-character limit for the field.
# - The 2.3.10 sanitizer passes the text through unchanged, so no other
#   platform name can reach Apple through this field. Release notes are
#   sanitized in CI; this file is hand-written and committed, so the check
#   has to run here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SANITIZE="$SCRIPT_DIR/sanitize_apple_store_notes.py"
IOS="$ROOT/ios/fastlane/metadata/review_information/notes.txt"
MACOS="$ROOT/macos/fastlane/metadata/review_information/notes.txt"
APPLE_LIMIT=4000

fail() { echo "FAIL: $1"; exit 1; }

for f in "$IOS" "$MACOS"; do
  [ -s "$f" ] || fail "missing or empty: ${f#"$ROOT"/}"
done

cmp -s "$IOS" "$MACOS" \
  || fail "ios and macos review notes differ; keep them identical"

# Characters, not bytes: the limit is on text, and a multi-byte character
# still counts once.
chars=$(python3 -c 'import sys; print(len(sys.stdin.read()))' < "$IOS")
[ "$chars" -le "$APPLE_LIMIT" ] \
  || fail "review notes are $chars characters; Apple's limit is $APPLE_LIMIT"

sanitized=$("$SANITIZE" < "$IOS")
original=$(cat "$IOS")
[ "$sanitized" = "$original" ] \
  || fail "review notes name another platform or store (guideline 2.3.10); run: $SANITIZE --report < ${IOS#"$ROOT"/}"

echo "app_review_notes_test: OK ($chars characters)"
