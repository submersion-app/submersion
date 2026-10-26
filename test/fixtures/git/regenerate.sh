#!/bin/bash
# Regenerates the pack fixtures for the pure-Dart Git pack reader tests.
#
# Stock git builds a small repository with two commits, then writes:
#   full.pack           every object, OFS_DELTA entries (--delta-base-offset)
#   full_ids.txt        the object ids full.pack holds, sorted
#   thin_refdelta.pack  only the second commit's new objects, as a thin pack
#                       with REF_DELTA entries against first-commit objects
#   thin_ids.txt        the object ids thin_refdelta.pack holds, sorted
#
# The files are committed; rerun this only to change what they contain.
set -euo pipefail

out="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

export GIT_AUTHOR_NAME='Test Diver' GIT_AUTHOR_EMAIL='diver@example.test'
export GIT_COMMITTER_NAME='Test Diver' GIT_COMMITTER_EMAIL='diver@example.test'
export GIT_AUTHOR_DATE='1700000000 +0000' GIT_COMMITTER_DATE='1700000000 +0000'
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

cd "$work"
git init -q -b main .
mkdir -p 'Submersion Sync'
for i in $(seq -w 1 40); do
  # About 2 KB of repetitive text per file, so the edits below delta well.
  for line in $(seq 1 60); do
    echo "dive $i line $line depth 18.5 m temperature 24 C" >> "Submersion Sync/file_$i.json"
  done
done
python3 -c "
import random
r = random.Random(1643)
open('Submersion Sync/blob.bin', 'wb').write(bytes(r.getrandbits(8) for _ in range(300000)))
"
git add -A
git commit -q -m 'first'

for i in $(seq -w 1 10); do
  echo "edited $i" >> "Submersion Sync/file_$i.json"
done
git add -A
GIT_AUTHOR_DATE='1700000100 +0000' GIT_COMMITTER_DATE='1700000100 +0000' \
  git commit -q -m 'second'

echo HEAD | git pack-objects --revs --stdout --delta-base-offset > "$out/full.pack"
git rev-list --objects HEAD | cut -d' ' -f1 | sort > "$out/full_ids.txt"

printf 'HEAD\n^HEAD~1\n' | git pack-objects --revs --thin --stdout > "$out/thin_refdelta.pack"
git rev-list --objects HEAD '^HEAD~1' | cut -d' ' -f1 | sort > "$out/thin_ids.txt"

echo "wrote fixtures to $out"
