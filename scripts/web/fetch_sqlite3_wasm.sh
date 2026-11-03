#!/bin/bash
#
# Fetches the sqlite3.wasm build pinned in scripts/web/sqlite3_wasm.lock into
# web/sqlite3.wasm, where `flutter build web` copies it into the bundle and
# scripts/web/compile_workers.sh stages it for the browser tests.
#
# The lock pins URL and sha256, so a changed upstream asset, a truncated
# download or a release that does not match package:sqlite3 fails here rather
# than in the browser. A present file with the right hash is left alone.
#
# Usage: scripts/web/fetch_sqlite3_wasm.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$REPO_ROOT/scripts/web/sqlite3_wasm.lock"
OUT="$REPO_ROOT/web/sqlite3.wasm"

URL="$(grep '^url=' "$LOCK" | cut -d= -f2-)"
SHA="$(grep '^sha256=' "$LOCK" | cut -d= -f2-)"
if [ -z "$URL" ] || [ -z "$SHA" ]; then
    echo "fetch_sqlite3_wasm: $LOCK must set url= and sha256=" >&2
    exit 1
fi

hash_of() {
    shasum -a 256 "$1" | awk '{print $1}'
}

if [ -f "$OUT" ] && [ "$(hash_of "$OUT")" = "$SHA" ]; then
    echo "sqlite3.wasm present and verified ($(wc -c < "$OUT" | tr -d ' ') bytes)"
    exit 0
fi

TMP="$OUT.download"
trap 'rm -f "$TMP"' EXIT
curl -fsSL --retry 3 -o "$TMP" "$URL"
ACTUAL="$(hash_of "$TMP")"
if [ "$ACTUAL" != "$SHA" ]; then
    echo "fetch_sqlite3_wasm: hash mismatch for $URL" >&2
    echo "  expected $SHA" >&2
    echo "  got      $ACTUAL" >&2
    exit 1
fi
mv "$TMP" "$OUT"
trap - EXIT
echo "fetched sqlite3.wasm ($(wc -c < "$OUT" | tr -d ' ') bytes)"
