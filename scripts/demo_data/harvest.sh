#!/usr/bin/env bash
# Step 1 of building the demo-mode sample logbook (issue #3708).
#
#   scripts/demo_data/harvest.sh <out_dir> <source_path>...
#
# Reads real dive logs (files, folders or zips, in any format the app can
# import, and Submersion databases) and writes only their anonymous dive
# shapes to <out_dir>, which must be outside the repository: shapes.jsonl.gz,
# salted hashes of the sources' text for the privacy check, and the salt.
# Nothing written here is ever committed. See tool/demo_data/README.md.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <out_dir> <source_path>..." >&2
  exit 2
fi

repo="$(cd "$(dirname "$0")/../.." && pwd)"
out="$1"
shift
list="$(mktemp)"
trap 'rm -f "$list"' EXIT
for source in "$@"; do
  printf '%s\n' "$(cd "$(dirname "$source")" && pwd)/$(basename "$source")" >> "$list"
done

cd "$repo"
DEMO_HARVEST_OUT="$out" \
DEMO_HARVEST_SOURCES="$list" \
DEMO_HARVEST_REPO="$repo" \
  flutter test tool/demo_data/harvest_test.dart --reporter expanded
