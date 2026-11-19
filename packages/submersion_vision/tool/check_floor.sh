#!/bin/sh
# Builds and runs floor_check.swift against this package's MemoryReading.swift:
# the memory floor for marine life identification on iPhone and iPad must
# let 8 GB devices in and keep 6 GB devices out. Needs only Foundation and
# Darwin, so it runs wherever swiftc does.
#
#   packages/submersion_vision/tool/check_floor.sh [OUT_DIR]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-${TMPDIR:-/tmp}/species_floor_check}
mkdir -p "$out"
swiftc -O -parse-as-library -o "$out/floor_check" \
  "$here/floor_check.swift" \
  "$here/../darwin/Classes/MemoryReading.swift"
"$out/floor_check"
