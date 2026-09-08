#!/usr/bin/env python3
"""Derive a Linux package's runtime dependencies from a built bundle.

Hand-written dependency lists go stale silently. desktop_webview_window's CMake
falls back from webkit2gtk-4.1 to 4.0 when 4.1 is missing at build time
(desktop_webview_window/linux/CMakeLists.txt), which changes what the binary
needs without failing the build, so a declared list can be wrong in a way
nothing catches until a user's package manager installs the wrong library.

This reads DT_NEEDED out of the built artifacts instead, subtracts the
libraries shipped inside the package, and maps what remains through
scripts/data/linux_soname_map.json. An unmapped soname is a hard failure: the
alternative is a package that installs cleanly and then fails to launch, which
is the same shape as issue #1129 (see check_bundled_native_assets.py).

RPM dependencies are soname provides rather than package names, because Fedora
calls the package gtk3 while openSUSE calls it libgtk-3-0, and both provide
libgtk-3.so.0()(64bit).

Usage:
    linux_package_deps.py <bundle-root> --format {deb,rpm,json}
"""

import argparse
import json
import os
import re
import subprocess
import sys

DEFAULT_MAP = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "data", "linux_soname_map.json"
)

_NEEDED_RE = re.compile(r"\(NEEDED\).*\[(.+?)\]")

_FORMAT_COLUMN = {"deb": "apt", "rpm": "rpm"}


def load_map(path):
    """Load the soname map, dropping documentation keys."""
    with open(path, "r", encoding="utf-8") as handle:
        raw = json.load(handle)
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def bundled_sonames(bundle_root):
    """Names of the shared libraries shipped inside the bundle's lib/."""
    lib_dir = os.path.join(bundle_root, "lib")
    if not os.path.isdir(lib_dir):
        return set()
    return {name for name in os.listdir(lib_dir) if ".so" in name}


def read_needed(path):
    """DT_NEEDED entries of one ELF file, via readelf."""
    try:
        output = subprocess.run(
            ["readelf", "-d", path],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    except FileNotFoundError:
        sys.exit(
            "linux_package_deps: readelf not found. Install binutils in the "
            "build container."
        )
    except subprocess.CalledProcessError as error:
        sys.exit("linux_package_deps: readelf failed on %s: %s" % (path, error))
    return set(_NEEDED_RE.findall(output))


def collect_sonames(bundle_root):
    """Every DT_NEEDED entry across the bundle, minus what the bundle ships."""
    targets = [os.path.join(bundle_root, "submersion")]
    lib_dir = os.path.join(bundle_root, "lib")
    if os.path.isdir(lib_dir):
        targets.extend(
            os.path.join(lib_dir, name)
            for name in sorted(os.listdir(lib_dir))
            if ".so" in name
        )

    needed = set()
    for target in targets:
        if os.path.isfile(target):
            needed |= read_needed(target)
    return needed - bundled_sonames(bundle_root)


def map_sonames(sonames, soname_map, column):
    """Map sonames to dependency tokens, sorted and deduplicated.

    Exits rather than dropping anything it cannot map: a silently omitted
    dependency is a package that installs and then fails to launch.

    An entry carrying "exclude" is known and deliberately not a dependency.
    That is not the same as being absent: absent still fails the build. The
    case this exists for is libjvm.so, which libjni.so links but which is never
    loaded on Linux, and which would otherwise pull a JRE onto every machine.
    """
    unmapped = sorted(name for name in sonames if name not in soname_map)
    if unmapped:
        sys.exit(
            "linux_package_deps: unmapped soname(s): %s\n"
            "Add them to scripts/data/linux_soname_map.json. An unmapped "
            "library means the package would install without declaring "
            "something it needs. If a soname is reachable but never loaded, "
            "give it an \"exclude\" entry saying why." % ", ".join(unmapped)
        )
    return sorted(
        {
            soname_map[name][column]
            for name in sonames
            if not soname_map[name].get("exclude")
        }
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle_root")
    parser.add_argument("--format", choices=("deb", "rpm", "json"), required=True)
    parser.add_argument("--map", default=DEFAULT_MAP)
    args = parser.parse_args(argv)

    soname_map = load_map(args.map)
    sonames = collect_sonames(args.bundle_root)

    if args.format == "json":
        # Validate before emitting, so the json form fails on an unmapped
        # soname exactly as the package forms do.
        map_sonames(sonames, soname_map, "apt")
        json.dump(
            {name: soname_map[name] for name in sorted(sonames)},
            sys.stdout,
            indent=2,
            sort_keys=True,
        )
        sys.stdout.write("\n")
        return 0

    for token in map_sonames(sonames, soname_map, _FORMAT_COLUMN[args.format]):
        print(token)
    return 0


if __name__ == "__main__":
    sys.exit(main())
