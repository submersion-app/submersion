#!/usr/bin/env bash
# Generates appcast.xml for Sparkle/WinSparkle auto-updates.
#
# Usage: ./scripts/generate_appcast.sh <version> <build_number> <date> <macos_dmg_url> <windows_zip_url>
#
# Arguments:
#   version       - Marketing version string (e.g. "1.1.3")
#   build_number  - Build number (e.g. "40"), used as sparkle:version for comparison
#   date          - RFC 2822 date string for pubDate
#   macos_dmg_url - Download URL for macOS DMG
#   windows_zip_url - Download URL for Windows ZIP
#
# Requires: SPARKLE_EDDSA_SIGNATURE env var (EdDSA signature of macOS DMG)

set -euo pipefail

VERSION="${1:?Usage: generate_appcast.sh <version> <build_number> <date> <macos_url> <windows_url>}"
BUILD_NUMBER="${2:?Missing build_number argument}"
DATE="${3}"
MACOS_URL="${4}"
WINDOWS_URL="${5}"
EDDSA_SIG="${SPARKLE_EDDSA_SIGNATURE:-}"

cat <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${MACOS_URL}"
        sparkle:edSignature="${EDDSA_SIG}"
        type="application/octet-stream"
        sparkle:os="macos"
      />
      <enclosure
        url="${WINDOWS_URL}"
        type="application/octet-stream"
        sparkle:os="windows"
      />
    </item>
  </channel>
</rss>
APPCAST
