#!/usr/bin/env bash
# Build the Linux .deb and .rpm from an already-built Flutter bundle.
#
# Shared by .github/workflows/build-all.yml (the release path) and
# .github/workflows/ci.yaml (per-PR coverage), so the two cannot drift.
#
# Both packages are emitted from staging trees produced by the same script,
# which is what makes them provably the same binary.
#
# Usage:
#   build_linux_packages.sh --bundle DIR --version V --deb PATH --rpm PATH
#                           [--staging-root DIR]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BUNDLE=""
VERSION=""
DEB_PATH=""
RPM_PATH=""
STAGING_ROOT="."

while [ $# -gt 0 ]; do
  case "$1" in
    --bundle) BUNDLE="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --deb) DEB_PATH="$2"; shift 2 ;;
    --rpm) RPM_PATH="$2"; shift 2 ;;
    --staging-root) STAGING_ROOT="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

require() {
  if [ -z "$2" ]; then
    echo "build_linux_packages: $1 is required" >&2
    exit 2
  fi
}

require --bundle "$BUNDLE"
require --version "$VERSION"
require --deb "$DEB_PATH"
require --rpm "$RPM_PATH"

echo "==> Staging package trees"
for method in deb rpm; do
  python3 "$REPO_ROOT/scripts/release/stage_linux_package.py" \
    "$BUNDLE" \
    "$STAGING_ROOT/staging-$method" \
    --version "$VERSION" \
    --install-method "$method"
done

echo "==> Deriving runtime dependencies"
python3 "$REPO_ROOT/scripts/linux_package_deps.py" \
  "$BUNDLE" --format deb > "$STAGING_ROOT/deps-deb.txt"
python3 "$REPO_ROOT/scripts/linux_package_deps.py" \
  "$BUNDLE" --format rpm > "$STAGING_ROOT/deps-rpm.txt"
echo "--- deb dependencies ---"; cat "$STAGING_ROOT/deps-deb.txt"
echo "--- rpm dependencies ---"; cat "$STAGING_ROOT/deps-rpm.txt"

common_args=(
  --name submersion
  --version "$VERSION"
  --license GPL-3.0
  --maintainer "Submersion <dev@submersion.app>"
  --url "https://submersion.app"
  --description "An open-source dive logging application for scuba divers."
  --input-type dir
)

# ffmpeg and gnome-keyring are weak dependencies on purpose. ffmpeg is absent
# from stock Fedora (it lives in RPM Fusion), so a hard requirement would make
# the package uninstallable there, and the app already degrades gracefully
# without it. gnome-keyring supplies the Secret Service that
# flutter_secure_storage_linux needs, which is present on GNOME and KDE but not
# on minimal window managers.
echo "==> Building $DEB_PATH"
deb_depends=()
while read -r dep; do
  [ -n "$dep" ] && deb_depends+=(--depends "$dep")
done < "$STAGING_ROOT/deps-deb.txt"
fpm "${common_args[@]}" \
  --output-type deb \
  --architecture amd64 \
  "${deb_depends[@]}" \
  --deb-recommends ffmpeg \
  --deb-recommends gnome-keyring \
  --package "$DEB_PATH" \
  -C "$STAGING_ROOT/staging-deb" usr

echo "==> Building $RPM_PATH"
rpm_depends=()
while read -r dep; do
  [ -n "$dep" ] && rpm_depends+=(--depends "$dep")
done < "$STAGING_ROOT/deps-rpm.txt"
fpm "${common_args[@]}" \
  --output-type rpm \
  --architecture x86_64 \
  "${rpm_depends[@]}" \
  --rpm-tag "Recommends: ffmpeg" \
  --rpm-tag "Recommends: gnome-keyring" \
  --package "$RPM_PATH" \
  -C "$STAGING_ROOT/staging-rpm" usr

echo "==> Done"
