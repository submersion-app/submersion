#!/usr/bin/env bash
# Install Submersion from the tarball into the current user's home.
#
# The .deb and .rpm packages are the better path on Debian, Ubuntu, Mint,
# Fedora, RHEL, and openSUSE. This exists for everything else, and for anyone
# who prefers not to install system packages.
#
# Usage: ./install.sh [--prefix DIR] [--no-udev]
set -euo pipefail

PREFIX="${HOME}/.local"
INSTALL_UDEV=1
UDEV_RULES_PATH="/usr/lib/udev/rules.d/60-submersion-divecomputers.rules"

map_soname() {
  # map_soname <deps.json> <soname> <column> -> package name, or empty
  python3 - "$1" "$2" "$3" <<'PY'
import json
import sys

path, soname, column = sys.argv[1:4]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)
entry = data.get(soname)
print(entry.get(column, "") if entry else "")
PY
}

drop_excluded() {
  # Filter sonames the map marks as deliberately not dependencies.
  #
  # libjni.so links libjvm.so, so ldd reports it missing on any machine
  # without a JRE, which is nearly all of them. Without this, every user
  # would be told a library is missing that they neither need nor can
  # usefully install: the jni plugin is bundled but never loaded on Linux.
  # The script is passed with -c rather than a heredoc: a heredoc would take
  # over stdin, leaving the piped soname list unreadable, and this function
  # would then drop every library rather than only the excluded ones.
  python3 -c '
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
except (OSError, ValueError):
    data = {}
for soname in sys.stdin.read().split():
    if not (data.get(soname) or {}).get("exclude"):
        print(soname)
' "$1"
}

dedupe_words() {
  # Collapse a whitespace-separated list to sorted, unique, space-joined words.
  #
  # Several sonames commonly map to one package: libglib-2.0.so.0,
  # libgobject-2.0.so.0, libgio-2.0.so.0 and libgmodule-2.0.so.0 all map to
  # libglib2.0-0, so a naive append prints it four times in the command handed
  # to the user.
  tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ *$//'
}

install_command_for() {
  # install_command_for <manager> <packages> -> the command the user runs
  case "$1" in
    apt) echo "sudo apt install $2" ;;
    dnf) echo "sudo dnf install $2" ;;
    pacman) echo "sudo pacman -S --needed $2" ;;
    zypper) echo "sudo zypper install $2" ;;
    *) echo "" ;;
  esac
}

detect_manager() {
  local manager
  # zypper before dnf: openSUSE can have dnf installed alongside zypper, but
  # zypper owns the package database there. Checking dnf first would hand an
  # openSUSE user the wrong command.
  for manager in apt zypper dnf pacman; do
    if command -v "$manager" > /dev/null 2>&1; then
      echo "$manager"
      return
    fi
  done
  echo ""
}

preflight_targets() {
  # One path per line: the binary plus every bundled shared library.
  #
  # Built explicitly rather than with a "$here"/lib/*.so* glob. An unmatched
  # glob passes its literal pattern to ldd, which then fails; because
  # preflight is called guarded by ||, set -e is suppressed and the failure
  # leaves `missing` empty, so the installer reports "All shared libraries
  # resolve" without having checked a single one.
  local here="$1"
  [ -f "$here/submersion" ] && echo "$here/submersion"
  if [ -d "$here/lib" ]; then
    find "$here/lib" -maxdepth 1 -type f -name '*.so*' 2>/dev/null | sort
  fi
}

preflight() {
  # Turns a loader error into the exact command that fixes it.
  local here="$1"
  local manager missing packages command package soname targets
  manager="$(detect_manager)"

  targets="$(preflight_targets "$here")"
  if [ -z "$targets" ]; then
    echo "No Submersion binary found here. Run install.sh from inside the"
    echo "unpacked tarball."
    return 1
  fi

  if ! command -v ldd > /dev/null 2>&1; then
    echo "ldd is not available, so shared libraries were not checked."
    return 0
  fi

  missing="$(
    printf '%s\n' "$targets" | while IFS= read -r target; do
      ldd "$target" 2>/dev/null | awk '/not found/ {print $1}' || true
    done | sort -u
  )"
  missing="$(printf '%s\n' "$missing" | drop_excluded "$here/deps.json")"

  if [ -z "$missing" ]; then
    echo "All shared libraries resolve."
    return 0
  fi

  echo "Missing shared libraries:"
  packages=""
  for soname in $missing; do
    echo "  $soname"
    if [ -n "$manager" ] && [ -f "$here/deps.json" ]; then
      package="$(map_soname "$here/deps.json" "$soname" "$manager")"
      [ -n "$package" ] && packages="$packages $package"
    fi
  done

  packages="$(printf '%s' "$packages" | dedupe_words)"

  if [ -n "$packages" ]; then
    command="$(install_command_for "$manager" "$packages")"
    if [ -n "$command" ]; then
      echo ""
      echo "Install them with:"
      echo "  $command"
    fi
  fi
  return 1
}

main() {
  local here app_dir
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  while [ $# -gt 0 ]; do
    case "$1" in
      --prefix) PREFIX="$2"; shift 2 ;;
      --no-udev) INSTALL_UDEV=0; shift ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done
  app_dir="${PREFIX}/opt/submersion"

  preflight "$here" \
    || echo "Continuing; the app may not launch until these are installed."

  mkdir -p "$app_dir" "${PREFIX}/bin" \
    "${PREFIX}/share/applications" \
    "${PREFIX}/share/icons/hicolor/256x256/apps"
  cp -a "$here/." "$app_dir/"
  rm -f "$app_dir/install.sh" "$app_dir/uninstall.sh"

  ln -sf "$app_dir/submersion" "${PREFIX}/bin/submersion"

  cat > "${PREFIX}/share/applications/app.submersion.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Submersion
GenericName=Dive Log
Comment=An open-source dive logging application for scuba divers.
Exec=${PREFIX}/bin/submersion %U
Icon=app.submersion
Terminal=false
Categories=Science;Education;Utility;
Keywords=dive;diving;scuba;divelog;logbook;
StartupWMClass=submersion
DESKTOP

  if [ -f "$app_dir/data/flutter_assets/assets/icon/icon.png" ]; then
    cp "$app_dir/data/flutter_assets/assets/icon/icon.png" \
      "${PREFIX}/share/icons/hicolor/256x256/apps/app.submersion.png"
  fi

  if [ "$INSTALL_UDEV" = "1" ] \
     && [ -f "$app_dir/60-submersion-divecomputers.rules" ]; then
    echo ""
    echo "Dive computers connected by USB need a udev rule to be reachable."
    echo "Install it with:"
    echo "  sudo cp $app_dir/60-submersion-divecomputers.rules $UDEV_RULES_PATH"
    echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
  fi

  echo ""
  echo "Installed to $app_dir"
  echo "Run it with: ${PREFIX}/bin/submersion"
  echo "Make sure ${PREFIX}/bin is on your PATH."
}

# Sourced by install_sh_test.sh to test the pure functions in isolation.
if [ -z "${SUBMERSION_INSTALL_SH_TEST:-}" ]; then
  main "$@"
fi
