#!/usr/bin/env bash
# Generates appcast.xml for Sparkle/WinSparkle auto-updates.
#
# Usage: ./scripts/generate_appcast.sh <version> <build_number> <date> <macos_dmg_url> <windows_url> <release_notes_html_file>
#
# Arguments:
#   version                  - Marketing version string (e.g. "1.1.3")
#   build_number             - Build number (e.g. "40"), used as sparkle:version for macOS (CFBundleVersion)
#   date                     - RFC 2822 date string for pubDate
#   macos_dmg_url            - Download URL for macOS DMG
#   windows_url              - Download URL for Windows installer
#   release_notes_html_file  - Path to generated release-notes.html (inlined in appcast via CDATA)
#
# Requires:
#   SPARKLE_EDDSA_SIGNATURE env var (EdDSA signature of macOS DMG)
#   SPARKLE_DMG_LENGTH env var (byte length of macOS DMG)
#   SPARKLE_WINDOWS_EDDSA_SIGNATURE env var (EdDSA signature of Windows installer)
#   SPARKLE_WINDOWS_EXE_LENGTH env var (byte length of Windows installer)
#
# The Windows signature vars are mandatory: WinSparkle clients with an
# embedded EdDSA public key reject unsigned enclosures, so silently emitting
# one would break updates for every up-to-date install. Set
# SPARKLE_ALLOW_UNSIGNED_WINDOWS=1 to emit the legacy unsigned enclosure
# (only for promoting betas built before Windows signing existed).

set -euo pipefail

RAW_VERSION="${1:?Usage: generate_appcast.sh <version> <build_number> <date> <macos_url> <windows_url> <release_notes_html_file>}"
BUILD_NUMBER="${2:?Missing build_number argument}"
# Strip the build number from VERSION if the tag included it (e.g. v1.3.7.82
# → 1.3.7) so that appending .${BUILD_NUMBER} below always produces a clean
# 4-segment version (1.3.7.82) without duplication (1.3.7.82.82).
VERSION=$(echo "$RAW_VERSION" | cut -d. -f1-3)
DATE="${3}"
MACOS_URL="${4}"
WINDOWS_URL="${5}"
RELEASE_NOTES_FILE="${6:?Missing release_notes_html_file argument}"
EDDSA_SIG="${SPARKLE_EDDSA_SIGNATURE:-}"
DMG_LENGTH="${SPARKLE_DMG_LENGTH:-}"
WINDOWS_EDDSA_SIG="${SPARKLE_WINDOWS_EDDSA_SIGNATURE:-}"
WINDOWS_EXE_LENGTH="${SPARKLE_WINDOWS_EXE_LENGTH:-}"

if [ -z "$EDDSA_SIG" ] || [ -z "$DMG_LENGTH" ] || [ "$DMG_LENGTH" = "0" ]; then
  echo "Error: SPARKLE_EDDSA_SIGNATURE and SPARKLE_DMG_LENGTH are required" >&2
  exit 1
fi

if [ -z "$WINDOWS_EDDSA_SIG" ] || [ -z "$WINDOWS_EXE_LENGTH" ] || [ "$WINDOWS_EXE_LENGTH" = "0" ]; then
  if [ "${SPARKLE_ALLOW_UNSIGNED_WINDOWS:-}" != "1" ]; then
    echo "Error: SPARKLE_WINDOWS_EDDSA_SIGNATURE and SPARKLE_WINDOWS_EXE_LENGTH are required" >&2
    echo "(set SPARKLE_ALLOW_UNSIGNED_WINDOWS=1 only to promote a pre-signing beta)" >&2
    exit 1
  fi
  # The escape hatch covers builds with no Windows signing at all. If either
  # var is present the CI wiring is broken, and silently emitting an unsigned
  # enclosure would strand every keyed WinSparkle client.
  if [ -n "$WINDOWS_EDDSA_SIG" ] || [ -n "$WINDOWS_EXE_LENGTH" ]; then
    echo "Error: partial Windows signing vars; refusing the unsigned fallback" >&2
    exit 1
  fi
  WINDOWS_SIG_ATTRS=""
else
  WINDOWS_SIG_ATTRS="
        sparkle:edSignature=\"${WINDOWS_EDDSA_SIG}\"
        length=\"${WINDOWS_EXE_LENGTH}\""
fi

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
  echo "Error: release notes file not found: $RELEASE_NOTES_FILE" >&2
  exit 1
fi

RELEASE_NOTES_HTML=$(cat "$RELEASE_NOTES_FILE")

cat <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version ${VERSION}.${BUILD_NUMBER}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}.${BUILD_NUMBER}</sparkle:shortVersionString>
      <description><![CDATA[${RELEASE_NOTES_HTML}]]></description>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${MACOS_URL}"
        sparkle:edSignature="${EDDSA_SIG}"
        length="${DMG_LENGTH}"
        type="application/octet-stream"
        sparkle:os="macos"
      />
    </item>
    <item>
      <title>Version ${VERSION}.${BUILD_NUMBER}</title>
      <sparkle:version>${VERSION}.${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}.${BUILD_NUMBER}</sparkle:shortVersionString>
      <description><![CDATA[${RELEASE_NOTES_HTML}]]></description>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_URL}"${WINDOWS_SIG_ATTRS}
        type="application/octet-stream"
        sparkle:os="windows"
      />
    </item>
  </channel>
</rss>
APPCAST
