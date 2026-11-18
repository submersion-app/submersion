#!/bin/sh
# Builds and runs merge_check.swift against the app's own
# VisionPipeline.swift: the pipeline must merge two detectors' boxes exactly
# as tool/species_pack/boxes.py does. macOS only (Core ML).
#
#   tool/species_pack/vision_cli/check_merge.sh [OUT_DIR]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
out=${1:-${TMPDIR:-/tmp}/species_merge_check}
mkdir -p "$out"
swiftc -O -parse-as-library -o "$out/merge_check" \
  "$here/merge_check.swift" "$here/FlutterShim.swift" \
  "$repo/packages/submersion_vision/darwin/Classes/VisionPipeline.swift"
"$out/merge_check"
