#!/usr/bin/env bash
# Tests for generate_appcast_beta.sh: superset ordering, standalone fallback,
# and signature passthrough (macOS and Windows EdDSA).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export SPARKLE_EDDSA_SIGNATURE="sig-beta"
export SPARKLE_DMG_LENGTH="1234"
export SPARKLE_WINDOWS_EDDSA_SIGNATURE="win-sig-beta"
export SPARKLE_WINDOWS_EXE_LENGTH="4321"
echo "<p>beta notes</p>" > "$TMP/notes.html"

fail() { echo "FAIL: $1"; exit 1; }

# The canonical generator emits TWO items per release: a macOS item whose
# <sparkle:version> is the build number, and a Windows item whose
# <sparkle:version> is the full 4-segment version.

# Case 1: no stable appcast -> the beta feed's own two items only.
OUT=$("$SCRIPT_DIR/generate_appcast_beta.sh" 1.8.0 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
  https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html")
echo "$OUT" | grep -q "<sparkle:version>5601</sparkle:version>" || fail "beta item missing sparkle:version"
[ "$(echo "$OUT" | grep -c '<item>')" -eq 2 ] || fail "expected exactly 2 items without stable feed"
echo "$OUT" | grep -q 'sparkle:edSignature="win-sig-beta"' || fail "windows enclosure missing EdDSA signature"
echo "$OUT" | grep -q 'length="4321"' || fail "windows enclosure missing length"

# Case 2: with a stable appcast -> beta items first, stable items appended, valid XML.
SPARKLE_EDDSA_SIGNATURE="sig-stable" SPARKLE_DMG_LENGTH="999" \
  SPARKLE_WINDOWS_EDDSA_SIGNATURE="win-sig-stable" SPARKLE_WINDOWS_EXE_LENGTH="888" \
  "$SCRIPT_DIR/generate_appcast.sh" 1.7.0.117 117 "Sun, 27 Jul 2026 00:00:00 +0000" \
  https://example.com/stable.dmg https://example.com/stable.exe "$TMP/notes.html" > "$TMP/stable.xml"
OUT=$("$SCRIPT_DIR/generate_appcast_beta.sh" 1.8.0 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
  https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html" "$TMP/stable.xml")
[ "$(echo "$OUT" | grep -c '<item>')" -eq 4 ] || fail "expected 4 items in superset feed"
BETA_LINE=$(echo "$OUT" | grep -n "<sparkle:version>5601</sparkle:version>" | head -1 | cut -d: -f1)
STABLE_LINE=$(echo "$OUT" | grep -n "<sparkle:version>117</sparkle:version>" | head -1 | cut -d: -f1)
[ "$BETA_LINE" -lt "$STABLE_LINE" ] || fail "beta item must precede stable item"
echo "$OUT" | grep -q "sig-beta" || fail "beta signature missing"
echo "$OUT" | grep -q "sig-stable" || fail "stable signature not preserved"
echo "$OUT" | grep -q "win-sig-beta" || fail "beta windows signature missing"
echo "$OUT" | grep -q "win-sig-stable" || fail "stable windows signature not preserved"
echo "$OUT" | python3 -c "import sys,xml.dom.minidom; xml.dom.minidom.parseString(sys.stdin.read())" \
  || fail "output is not well-formed XML"

# Case 3: a missing Windows signature is a hard error so a CI wiring mistake
# cannot silently publish an appcast entry that up-to-date clients reject.
if OUT=$(env -u SPARKLE_WINDOWS_EDDSA_SIGNATURE -u SPARKLE_WINDOWS_EXE_LENGTH \
    "$SCRIPT_DIR/generate_appcast.sh" 1.8.0 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
    https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html" 2>/dev/null); then
  fail "expected failure when Windows signature env vars are missing"
fi

# Case 3b: the macOS signature is equally mandatory; an empty edSignature or
# length="0" enclosure would be rejected by Sparkle clients.
if OUT=$(env -u SPARKLE_EDDSA_SIGNATURE -u SPARKLE_DMG_LENGTH \
    "$SCRIPT_DIR/generate_appcast.sh" 1.8.0 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
    https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html" 2>/dev/null); then
  fail "expected failure when macOS signature env vars are missing"
fi

# Case 3c: a zero-byte Windows length is as fatal as a missing one; keyed
# WinSparkle clients reject an enclosure whose length does not match the
# installer, so length="0" can only be a CI wiring mistake.
if OUT=$(SPARKLE_WINDOWS_EXE_LENGTH=0 \
    "$SCRIPT_DIR/generate_appcast.sh" 1.8.0 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
    https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html" 2>/dev/null); then
  fail "expected failure when Windows length is 0"
fi

# Case 3d: the unsigned escape hatch only covers builds with no Windows
# signing at all; if one of the two vars is present the wiring is broken,
# and silently emitting an unsigned enclosure would strand keyed clients.
if OUT=$(env -u SPARKLE_WINDOWS_EXE_LENGTH SPARKLE_ALLOW_UNSIGNED_WINDOWS=1 \
    "$SCRIPT_DIR/generate_appcast.sh" 1.8.0 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
    https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html" 2>/dev/null); then
  fail "expected failure when only one Windows signing var is set despite allow-unsigned"
fi

# Case 4: SPARKLE_ALLOW_UNSIGNED_WINDOWS=1 restores the legacy unsigned
# enclosure (needed to promote betas built before Windows signing existed).
OUT=$(env -u SPARKLE_WINDOWS_EDDSA_SIGNATURE -u SPARKLE_WINDOWS_EXE_LENGTH \
  SPARKLE_ALLOW_UNSIGNED_WINDOWS=1 \
  "$SCRIPT_DIR/generate_appcast.sh" 1.8.0 5601 "Mon, 28 Jul 2026 00:00:00 +0000" \
  https://example.com/beta.dmg https://example.com/beta.exe "$TMP/notes.html") \
  || fail "allow-unsigned fallback should succeed"
[ "$(echo "$OUT" | grep -c 'sparkle:edSignature')" -eq 1 ] \
  || fail "unsigned fallback must sign only the macOS enclosure"
echo "$OUT" | python3 -c "import sys,xml.dom.minidom; xml.dom.minidom.parseString(sys.stdin.read())" \
  || fail "unsigned fallback output is not well-formed XML"

echo "PASS: generate_appcast_beta_test"
