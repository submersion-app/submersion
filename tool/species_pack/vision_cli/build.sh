#!/bin/sh
# Builds the accuracy scorer's command-line tool from the app's own
# VisionPipeline.swift, so the scorer measures exactly what ships.
#
#   tool/species_pack/vision_cli/build.sh build/species_accuracy_work/species_vision
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
out=${1:?usage: build.sh OUT}
mkdir -p "$(dirname "$out")"
swiftc -O -o "$out" \
  "$here/main.swift" \
  "$here/FlutterShim.swift" \
  "$repo/packages/submersion_vision/darwin/Classes/VisionPipeline.swift"
