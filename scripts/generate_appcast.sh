#!/usr/bin/env bash
# Generates appcast.xml for Sparkle/WinSparkle auto-updates.
#
# Usage: ./scripts/generate_appcast.sh <version> <build_number> <date> <macos_dmg_url> <windows_url> <release_notes_url>
#
# Arguments:
#   version           - Marketing version string (e.g. "1.1.3")
#   build_number      - Build number (e.g. "40"), used as sparkle:version for macOS (CFBundleVersion)
#   date              - RFC 2822 date string for pubDate
#   macos_dmg_url     - Download URL for macOS DMG
#   windows_url       - Download URL for Windows installer
#   release_notes_url - URL to a simple HTML page with release notes
#
# Requires:
#   SPARKLE_EDDSA_SIGNATURE env var (EdDSA signature of macOS DMG)
#   SPARKLE_DMG_LENGTH env var (byte length of macOS DMG)

set -euo pipefail

VERSION="${1:?Usage: generate_appcast.sh <version> <build_number> <date> <macos_url> <windows_url> <release_notes_url>}"
BUILD_NUMBER="${2:?Missing build_number argument}"
DATE="${3}"
MACOS_URL="${4}"
WINDOWS_URL="${5}"
RELEASE_NOTES_URL="${6}"
EDDSA_SIG="${SPARKLE_EDDSA_SIGNATURE:-}"
DMG_LENGTH="${SPARKLE_DMG_LENGTH:-0}"

cat <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version ${VERSION}.${BUILD_NUMBER}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}.${BUILD_NUMBER}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>${RELEASE_NOTES_URL}</sparkle:releaseNotesLink>
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
      <sparkle:releaseNotesLink>${RELEASE_NOTES_URL}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_URL}"
        type="application/octet-stream"
        sparkle:os="windows"
      />
    </item>
  </channel>
</rss>
APPCAST
