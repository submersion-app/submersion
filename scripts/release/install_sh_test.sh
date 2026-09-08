#!/usr/bin/env bash
# Tests for the tarball installer's pure functions.
#
# Run: bash scripts/release/install_sh_test.sh
#
# The installer's job is to turn "error while loading shared libraries:
# libwebkit2gtk-4.1.so.0" into "sudo apt install libwebkit2gtk-4.1-0". These
# tests cover the mapping and the command construction, which is where that
# translation lives.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/linux_tarball_extras/install.sh"
FAILURES=0

assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "FAIL: $3"
    echo "  expected: $2"
    echo "  actual:   $1"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok: $3"
  fi
}

# Sourcing with SUBMERSION_INSTALL_SH_TEST set defines the functions without
# running the installer.
SUBMERSION_INSTALL_SH_TEST=1
export SUBMERSION_INSTALL_SH_TEST
# shellcheck source=/dev/null
. "$INSTALLER"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cat > "$WORKDIR/deps.json" <<'JSON'
{
  "_comment": "test fixture",
  "libgtk-3.so.0": {"apt": "libgtk-3-0", "rpm": "libgtk-3.so.0()(64bit)", "dnf": "gtk3", "pacman": "gtk3", "zypper": "libgtk-3-0"},
  "libwebkit2gtk-4.1.so.0": {"apt": "libwebkit2gtk-4.1-0", "rpm": "x", "dnf": "webkit2gtk4.1", "pacman": "webkit2gtk-4.1", "zypper": "libwebkit2gtk-4_1-0"}
}
JSON

assert_eq "$(map_soname "$WORKDIR/deps.json" "libgtk-3.so.0" apt)" \
  "libgtk-3-0" "maps a soname to its apt package"

assert_eq "$(map_soname "$WORKDIR/deps.json" "libgtk-3.so.0" pacman)" \
  "gtk3" "maps a soname to its pacman package"

assert_eq "$(map_soname "$WORKDIR/deps.json" "libunknown.so.9" apt)" \
  "" "returns empty for an unmapped soname rather than guessing"

assert_eq "$(install_command_for apt "libgtk-3-0 libwebkit2gtk-4.1-0")" \
  "sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0" "builds the apt command"

assert_eq "$(install_command_for dnf "gtk3")" \
  "sudo dnf install gtk3" "builds the dnf command"

assert_eq "$(install_command_for pacman "gtk3")" \
  "sudo pacman -S --needed gtk3" "builds the pacman command"

assert_eq "$(install_command_for zypper "gtk3")" \
  "sudo zypper install gtk3" "builds the zypper command"

assert_eq "$(install_command_for unknown "gtk3")" \
  "" "returns empty for an unrecognized package manager"

# The preflight reads the column named after the detected package manager.
# The rpm column is deliberately not one of them: it holds soname provides
# like libgtk-3.so.0()(64bit), which fpm needs and a human cannot type.
assert_eq "$(map_soname "$WORKDIR/deps.json" "libgtk-3.so.0" dnf)" \
  "gtk3" "maps a soname to a human-readable dnf package name"

# detect_manager probes PATH, so a temporary directory of stub executables
# stands in for a distro.
stub_path() {
  local dir="$WORKDIR/bin-$1"
  mkdir -p "$dir"
  shift
  for name in "$@"; do
    printf '#!/bin/sh\n' > "$dir/$name"
    chmod +x "$dir/$name"
  done
  echo "$dir"
}

opensuse="$(stub_path opensuse zypper dnf)"
assert_eq "$(PATH="$opensuse" detect_manager)" "zypper" \
  "prefers zypper over dnf when both exist (openSUSE)"

fedora="$(stub_path fedora dnf)"
assert_eq "$(PATH="$fedora" detect_manager)" "dnf" \
  "detects dnf on a host without zypper (Fedora)"

debian="$(stub_path debian apt)"
assert_eq "$(PATH="$debian" detect_manager)" "apt" \
  "detects apt on a Debian-family host"

arch="$(stub_path arch pacman)"
assert_eq "$(PATH="$arch" detect_manager)" "pacman" \
  "detects pacman on an Arch host"

# preflight_targets decides what gets checked. When it returns nothing useful
# the installer must say so rather than reporting that every library resolves,
# which is what the previous lib/*.so* glob did when it failed to expand.
bundle="$WORKDIR/bundle"
mkdir -p "$bundle/lib"
: > "$bundle/submersion"
: > "$bundle/lib/libsqlcipher.so"
: > "$bundle/lib/libpdfium.so.1"
: > "$bundle/lib/notes.txt"

assert_eq "$(preflight_targets "$bundle" | wc -l | tr -d ' ')" "3" \
  "collects the binary and both shared libraries"

assert_eq "$(preflight_targets "$bundle" | grep -c 'notes.txt')" "0" \
  "ignores non-library files in lib/"

nolib="$WORKDIR/nolib"
mkdir -p "$nolib"
: > "$nolib/submersion"
assert_eq "$(preflight_targets "$nolib" | wc -l | tr -d ' ')" "1" \
  "returns just the binary when lib/ is absent"

empty="$WORKDIR/empty"
mkdir -p "$empty"
assert_eq "$(preflight_targets "$empty")" "" \
  "returns nothing when there is no binary, so preflight can report it"

# An excluded soname must not be reported as a missing library. libjni.so
# links libjvm.so, so ldd reports it missing on any machine without a JRE,
# which would otherwise alarm nearly every tarball user about a library the
# app never loads.
cat > "$WORKDIR/deps-excl.json" <<'JSON'
{
  "libgtk-3.so.0": {"apt": "libgtk-3-0", "rpm": "x", "dnf": "gtk3", "pacman": "gtk3", "zypper": "libgtk-3-0"},
  "libjvm.so": {"exclude": "bundled but never loaded on Linux"}
}
JSON

assert_eq "$(printf 'libjvm.so\n' | drop_excluded "$WORKDIR/deps-excl.json")" "" \
  "drops an excluded soname from the missing list"

assert_eq "$(printf 'libgtk-3.so.0\n' | drop_excluded "$WORKDIR/deps-excl.json")" \
  "libgtk-3.so.0" "keeps a genuinely missing library"

assert_eq "$(printf 'libgtk-3.so.0\nlibjvm.so\n' | drop_excluded "$WORKDIR/deps-excl.json")" \
  "libgtk-3.so.0" "keeps the real one and drops the excluded one together"

assert_eq "$(printf 'libgtk-3.so.0\n' | drop_excluded "$WORKDIR/missing.json")" \
  "libgtk-3.so.0" "keeps everything when the map is unreadable"

# Several sonames map to one package, so the suggested command must not
# repeat it.
assert_eq "$(printf 'libglib2.0-0 libglib2.0-0 libgtk-3-0 libglib2.0-0' | dedupe_words)" \
  "libglib2.0-0 libgtk-3-0" "collapses repeated package names"

assert_eq "$(printf ' libgtk-3-0  libgtk-3-0 ' | dedupe_words)" \
  "libgtk-3-0" "tolerates leading, trailing, and repeated spaces"

assert_eq "$(printf '' | dedupe_words)" "" "returns empty for empty input"

assert_eq "$(printf 'zlib1g libgtk-3-0' | dedupe_words)" \
  "libgtk-3-0 zlib1g" "sorts so the command is stable between runs"

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "all tests passed"
