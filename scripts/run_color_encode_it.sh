#!/usr/bin/env bash
# Colour-encode integration check (issue #3521) on macOS, Windows or an
# Android device or emulator.
#
#   scripts/run_color_encode_it.sh            # this desktop (macOS, Windows)
#   scripts/run_color_encode_it.sh android    # the one attached Android device
#
#   1. tool/color_encode_it/prepare_test.dart synthesizes input clips with
#      ffmpeg (the sandboxed macOS app may not run ffmpeg, and Android has
#      none),
#   2. integration_test/<platform>_color_encode_test.dart encodes them in
#      the real app,
#   3. tool/color_encode_it/verify_test.dart checks the outputs with ffprobe
#      and the reference colour formula.
#
# Needs ffmpeg and ffprobe with libx264 and libx265 on PATH; Android also
# needs adb (ANDROID_HOME, or the default SDK location).
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "android" ]]; then
  adb="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
  [[ -x "$adb" ]] || adb="$(command -v adb)"
  serial="$("$adb" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  [[ -n "$serial" ]] || { echo "no Android device attached" >&2; exit 2; }
  host_dir="$(mktemp -d)"
  staging="/data/local/tmp/color_it"
  app="app.submersion"
  test_file=integration_test/android_color_encode_test.dart
  COLOR_IT_DIR="$host_dir" flutter test tool/color_encode_it/prepare_test.dart
  "$adb" -s "$serial" shell rm -rf "$staging"
  "$adb" -s "$serial" push "$host_dir/in" "$staging/in"
  # flutter test reinstalls the app, which clears its cache folder, so the
  # inputs go in once the test is up and waiting for them. A marker left by
  # an earlier run would be seen before the reinstall; clear it first.
  "$adb" -s "$serial" shell run-as "$app" rm -rf cache/color_it 2>/dev/null || true
  flutter test "$test_file" -d "$serial" --no-uninstall &
  test_pid=$!
  until "$adb" -s "$serial" shell run-as "$app" ls cache/color_it/waiting \
    >/dev/null 2>&1; do
    kill -0 "$test_pid" 2>/dev/null || { wait "$test_pid"; exit 1; }
    sleep 1
  done
  "$adb" -s "$serial" shell run-as "$app" sh -c \
    "'cp -r $staging/in cache/color_it/ && touch cache/color_it/in/.ready'"
  in_app=0
  wait "$test_pid" || in_app=$?
  # Pulled and checked either way: the reports say what went wrong.
  "$adb" -s "$serial" exec-out run-as "$app" tar -c -C cache/color_it out |
    tar -x -C "$host_dir"
  COLOR_IT_DIR="$host_dir" flutter test tool/color_encode_it/verify_test.dart
  exit "$in_app"
fi

case "$(uname -s)" in
  Darwin) platform=darwin; device=macos ;;
  MINGW* | MSYS* | CYGWIN*) platform=windows; device=windows ;;
  *) echo "run_color_encode_it.sh runs on macOS, Windows or Android" >&2; exit 2 ;;
esac

flutter test tool/color_encode_it/prepare_test.dart
in_app=0
flutter test "integration_test/${platform}_color_encode_test.dart" -d "$device" ||
  in_app=$?
# Checked either way: the reports say what went wrong.
flutter test tool/color_encode_it/verify_test.dart
exit "$in_app"
