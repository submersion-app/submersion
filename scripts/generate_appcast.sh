#!/usr/bin/env bash
# Generates appcast.xml for Sparkle/WinSparkle auto-updates.
#
# Usage: ./scripts/generate_appcast.sh <version> <date> <macos_dmg_url> <windows_zip_url>
#
# Requires: SPARKLE_EDDSA_SIGNATURE env var (EdDSA signature of macOS DMG)

set -euo pipefail

VERSION="${1:?Usage: generate_appcast.sh <version> <date> <macos_url> <windows_url>}"
DATE="${2}"
MACOS_URL="${3}"
WINDOWS_URL="${4}"
EDDSA_SIG="${SPARKLE_EDDSA_SIGNATURE:-}"

cat <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/ericgriffin/submersion/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <pubDate>${DATE}</pubDate>
      <enclosure
        url="${MACOS_URL}"
        sparkle:edSignature="${EDDSA_SIG}"
        type="application/octet-stream"
        sparkle:os="macos"
      />
    </item>
  </channel>
</rss>
APPCAST
