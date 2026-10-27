#!/usr/bin/env bash
# Step 1b of building the demo-mode sample logbook (issue #3708), macOS only.
#
#   scripts/demo_data/harvest_in_app.sh <harvest_dir> <source_path>...
#
# Harvests sources whose profiles only the running app can decode (Shearwater
# Cloud databases) inside the macOS app, with the salt harvest.sh wrote to
# <harvest_dir>, and merges the shapes and hashes into <harvest_dir>.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <harvest_dir> <source_path>..." >&2
  exit 2
fi

repo="$(cd "$(dirname "$0")/../.." && pwd)"
harvest="$(cd "$1" && pwd)"
shift
salt="$(tr -d '[:space:]' < "$harvest/salt.txt")"
stage="$HOME/Library/Containers/app.submersion/Data/demo_harvest"
rm -rf "$stage"
mkdir -p "$stage/in"
trap 'rm -rf "$stage"' EXIT
for source in "$@"; do
  cp -R "$source" "$stage/in/"
done

cd "$repo"
flutter test integration_test/darwin_demo_harvest_test.dart -d macos \
  --dart-define=DEMO_HARVEST_SALT="$salt"

python3 - "$stage/out" "$harvest" <<'PY'
import gzip, json, sys
src, dst = sys.argv[1], sys.argv[2]
def shapes(path):
    with gzip.open(path, 'rt') as f:
        return [l for l in f.read().splitlines() if l.strip()]
have = shapes(f'{dst}/shapes.jsonl.gz')
ids = {json.loads(l)['id'] for l in have}
new = [l for l in shapes(f'{src}/shapes.jsonl.gz') if json.loads(l)['id'] not in ids]
with gzip.open(f'{dst}/shapes.jsonl.gz', 'wt') as f:
    f.write('\n'.join(have + new) + '\n')
hashes = set(open(f'{dst}/source_strings.txt').read().split()) | set(open(f'{src}/source_strings.txt').read().split())
open(f'{dst}/source_strings.txt', 'w').write('\n'.join(sorted(hashes)) + '\n')
print(f'merged {len(new)} new shapes into {dst}')
PY
