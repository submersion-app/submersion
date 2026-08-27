#!/usr/bin/env bash
# Generates appcast-beta.xml for the Sparkle/WinSparkle beta channel.
#
# Usage: ./scripts/generate_appcast_beta.sh <version> <build_number> <date> \
#          <macos_dmg_url> <windows_url> <release_notes_html_file> [stable_appcast_path]
#
# Same arguments and env contract as generate_appcast.sh
# (SPARKLE_EDDSA_SIGNATURE, SPARKLE_DMG_LENGTH), plus an optional path to the
# CURRENT stable appcast.xml. The output is a superset feed: the beta item
# first, then every <item> from the stable appcast, so a device switched
# back to the stable channel still walks forward onto the next stable.

set -euo pipefail

STABLE_APPCAST="${7:-}"

# Reuse the canonical generator for the beta item and the feed skeleton.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BETA_FEED=$("$SCRIPT_DIR/generate_appcast.sh" "$1" "$2" "$3" "$4" "$5" "$6")

if [ -z "$STABLE_APPCAST" ] || [ ! -s "$STABLE_APPCAST" ]; then
  printf '%s\n' "$BETA_FEED"
  exit 0
fi

# Splice the stable feed's <item> blocks in front of the closing </channel>.
STABLE_ITEMS=$(sed -n '/<item>/,/<\/item>/p' "$STABLE_APPCAST")
printf '%s\n' "$BETA_FEED" | while IFS= read -r line; do
  if [[ "$line" == *"</channel>"* ]]; then
    printf '%s\n' "$STABLE_ITEMS"
  fi
  printf '%s\n' "$line"
done
