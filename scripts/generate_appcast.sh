#!/usr/bin/env bash
# Generates appcast.xml for Sparkle/WinSparkle auto-updates.
#
# Usage: ./scripts/generate_appcast.sh <version> <build_number> <date> <macos_dmg_url> <windows_x64_url> <windows_arm64_url>
#
# Arguments:
#   version            - Marketing version string (e.g. "1.1.3")
#   build_number       - Build number (e.g. "40"), used as sparkle:version for macOS (CFBundleVersion)
#   date               - RFC 2822 date string for pubDate
#   macos_dmg_url      - Download URL for macOS DMG
#   windows_x64_url    - Download URL for Windows x64 installer
#   windows_arm64_url  - Download URL for Windows ARM64 installer
#
# Requires:
#   SPARKLE_EDDSA_SIGNATURE env var (EdDSA signature of macOS DMG)
#   SPARKLE_DMG_LENGTH env var (byte length of macOS DMG)

set -euo pipefail

VERSION="${1:?Usage: generate_appcast.sh <version> <build_number> <date> <macos_url> <windows_x64_url> <windows_arm64_url>}"
BUILD_NUMBER="${2:?Missing build_number argument}"
DATE="${3}"
MACOS_URL="${4}"
WINDOWS_X64_URL="${5}"
WINDOWS_ARM64_URL="${6}"
EDDSA_SIG="${SPARKLE_EDDSA_SIGNATURE:-}"
DMG_LENGTH="${SPARKLE_DMG_LENGTH:-0}"

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
        length="${DMG_LENGTH}"
        type="application/octet-stream"
        sparkle:os="macos"
      />
    </item>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}.${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_X64_URL}"
        type="application/octet-stream"
        sparkle:os="windows"
      />
    </item>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}.${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_X64_URL}"
        type="application/octet-stream"
        sparkle:os="windows-x64"
      />
    </item>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}.${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/submersion-app/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${WINDOWS_ARM64_URL}"
        type="application/octet-stream"
        sparkle:os="windows-arm64"
      />
    </item>
  </channel>
</rss>
APPCAST
