#!/usr/bin/env bash
# Step 2 of building the demo-mode sample logbook (issue #3708).
#
#   scripts/demo_data/pack.sh <harvest_dir> <photos_dir> <out_dir> [seed]
#
# Builds the sample logbook from the shapes harvest.sh wrote, checks that it
# fills every part of the app and resembles no real dive, and writes the zip,
# its manifest entry and the merged demo-manifest.json to <out_dir>.
# Publishing is a separate, manual step; see tool/demo_data/README.md.
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <harvest_dir> <photos_dir> <out_dir> [seed]" >&2
  exit 2
fi

abs() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd)" "$(basename "$1")"); }
repo="$(cd "$(dirname "$0")/../.." && pwd)"
shapes="$(abs "$1")"
photos="$(abs "$2")"
mkdir -p "$3"
out="$(abs "$3")"

cd "$repo"
DEMO_PACK_SHAPES="$shapes" \
DEMO_PACK_PHOTOS="$photos" \
DEMO_PACK_OUT="$out" \
DEMO_PACK_SEED="${4:-1}" \
  flutter test tool/demo_data/pack_test.dart --reporter expanded
