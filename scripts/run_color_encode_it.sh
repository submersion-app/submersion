#!/usr/bin/env bash
# Colour-encode integration check (issue #3521) on macOS or Windows.
#
#   1. tool/color_encode_it/prepare_test.dart synthesizes input clips with
#      ffmpeg into the app's temp folder (the sandboxed macOS app may not
#      run ffmpeg itself),
#   2. integration_test/<platform>_color_encode_test.dart encodes them in
#      the real app,
#   3. tool/color_encode_it/verify_test.dart checks the outputs with ffprobe
#      and the reference colour formula.
#
# Needs ffmpeg and ffprobe with libx264 and libx265 on PATH.
set -euo pipefail

case "$(uname -s)" in
  Darwin) platform=darwin; device=macos ;;
  MINGW* | MSYS* | CYGWIN*) platform=windows; device=windows ;;
  *) echo "run_color_encode_it.sh runs on macOS or Windows" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."
flutter test tool/color_encode_it/prepare_test.dart
flutter test "integration_test/${platform}_color_encode_test.dart" -d "$device"
flutter test tool/color_encode_it/verify_test.dart
