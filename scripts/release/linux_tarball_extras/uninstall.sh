#!/usr/bin/env bash
# Remove a tarball installation of Submersion.
#
# Usage: ./uninstall.sh [--prefix DIR]
#
# Dive log data lives outside the install tree and is never touched here.
set -euo pipefail

PREFIX="${HOME}/.local"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

rm -rf "${PREFIX}/opt/submersion"
rm -f "${PREFIX}/bin/submersion"
rm -f "${PREFIX}/share/applications/app.submersion.desktop"
rm -f "${PREFIX}/share/icons/hicolor/256x256/apps/app.submersion.png"

echo "Removed Submersion from ${PREFIX}."
echo "Your dive log data was not touched."
echo ""
echo "If you installed the udev rules, remove them with:"
echo "  sudo rm -f /usr/lib/udev/rules.d/60-submersion-divecomputers.rules"
echo "  sudo udevadm control --reload-rules"
