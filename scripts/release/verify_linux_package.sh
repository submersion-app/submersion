#!/usr/bin/env bash
# Install the Submersion package found in /p and assert it actually works.
#
# Runs INSIDE a clean debian:12 or fedora:latest container, invoked by
# .github/workflows/build-all.yml and .github/workflows/ci.yaml. Installing
# through the real package manager is the point: it proves every declared
# dependency is resolvable on a stock system, which the tar.gz could never
# demonstrate.
set -euxo pipefail

RULES=/usr/lib/udev/rules.d/60-submersion-divecomputers.rules

if command -v apt-get > /dev/null; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y /p/Submersion-*.deb
else
  dnf install -y /p/Submersion-*.rpm
fi

# The binary answers --version before GTK initializes, so this needs no
# display server.
/usr/bin/submersion --version

test -f /usr/share/applications/app.submersion.desktop
test -f /usr/share/metainfo/app.submersion.metainfo.xml
test -f "$RULES"
test -f /usr/share/icons/hicolor/256x256/apps/app.submersion.png

# A GROUP-based rule would silently fail on Fedora, which has no plugdev group.
grep -q "uaccess" "$RULES"
if grep -q "plugdev" "$RULES"; then
  echo "udev rules fell back to group-based access"
  exit 1
fi

# No unresolved shared libraries after a real dependency install.
#
# ldd's output is captured first rather than piped straight into grep. In an
# "if ldd ... | grep" form, ldd failing outright (wrong path, not executable,
# not an ELF file) makes grep find nothing, the condition false, and the check
# pass without having examined anything. Note that pipefail does not save this
# either: a failed pipeline in an if condition is simply false. Under set -e
# the assignment itself aborts, so an ldd that cannot run is a build failure.
LDD_OUTPUT=$(ldd /usr/lib/submersion/submersion)
if printf '%s\n' "$LDD_OUTPUT" | grep "not found"; then
  echo "unresolved shared libraries after install"
  exit 1
fi

echo "package verified"
