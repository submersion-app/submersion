#!/usr/bin/env python3
"""Build the canonical Linux install tree from a Flutter bundle.

Both the .deb and the .rpm are emitted from this one tree, so the two packages
are provably the same binary rather than two builds that happen to agree.

The bundle is copied verbatim into /usr/lib/submersion because the runner
resolves its native assets through an $ORIGIN/lib rpath (linux/CMakeLists.txt);
preserving the relative layout is what lets the packaged copy launch at all.

Usage:
    stage_linux_package.py <bundle-root> <staging-dir> \\
        --version 1.7.7.7180 --install-method deb
"""

import argparse
import datetime
import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MASTER_ICON = os.path.join(REPO_ROOT, "assets", "icon", "icon.png")
DESCRIPTOR_C = os.path.join(
    REPO_ROOT,
    "packages",
    "libdivecomputer_plugin",
    "third_party",
    "libdivecomputer",
    "src",
    "descriptor.c",
)
GEN_UDEV = os.path.join(REPO_ROOT, "scripts", "gen_udev_rules.py")

ICON_SIZES = (16, 32, 48, 64, 128, 256, 512)
INSTALL_METHODS = ("deb", "rpm")

DESKTOP_ENTRY = """[Desktop Entry]
Type=Application
Name=Submersion
GenericName=Dive Log
Comment=An open-source dive logging application for scuba divers.
Exec=submersion %U
Icon=app.submersion
Terminal=false
Categories=Science;Education;Utility;
Keywords=dive;diving;scuba;divelog;logbook;
StartupWMClass=submersion
"""

WRAPPER = """#!/bin/sh
# Submersion launcher. The real binary lives beside its data/ and lib/
# directories because it resolves native assets through an $ORIGIN/lib rpath.
exec /usr/lib/submersion/submersion "$@"
"""

METAINFO = """<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>app.submersion</id>
  <name>Submersion</name>
  <summary>Dive logging for scuba divers</summary>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-3.0</project_license>
  <description>
    <p>
      Submersion is an open-source dive logging application. It downloads dives
      from dive computers, tracks gear and dive sites, and shows decompression
      and gas analytics.
    </p>
  </description>
  <launchable type="desktop-id">app.submersion.desktop</launchable>
  <url type="homepage">https://submersion.app</url>
  <url type="bugtracker">https://github.com/submersion-app/submersion/issues</url>
  <releases>
    <release version="{version}" date="{date}"/>
  </releases>
</component>
"""


def build_date():
    """The date stamped into the AppStream metadata.

    Honours SOURCE_DATE_EPOCH, the reproducible-builds convention, so two
    builds of the same commit produce byte-identical packages. Without it the
    metadata carries the wall-clock date, and a rebuild of an old tag would
    differ from the package that shipped.

    Read as UTC deliberately: interpreted in local time, two builders in
    different timezones would stamp different dates from one commit, which is
    exactly what the convention exists to prevent.
    """
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    if not epoch:
        return datetime.date.today().isoformat()
    try:
        seconds = int(epoch)
    except ValueError:
        sys.exit(
            "stage_linux_package: SOURCE_DATE_EPOCH is not an integer: %r. "
            "Ignoring it would silently make a build that meant to be "
            "reproducible stop being so." % epoch
        )
    return (
        datetime.datetime.fromtimestamp(seconds, datetime.timezone.utc)
        .date()
        .isoformat()
    )


def _write(path, text, mode=0o644):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.chmod(path, mode)


def _stage_icons(staging):
    """Write the icon at every hicolor size.

    Pillow is available through scripts/requirements.txt, the same dependency
    generate_icon.py uses. Without it the master icon is copied unscaled rather
    than failing: a correctly sized set is better, but a complete set at the
    wrong resolution still gives the user a working menu entry.
    """
    try:
        from PIL import Image
    except ImportError:
        Image = None

    for size in ICON_SIZES:
        target = os.path.join(
            staging,
            "usr/share/icons/hicolor/%dx%d/apps/app.submersion.png" % (size, size),
        )
        os.makedirs(os.path.dirname(target), exist_ok=True)
        if Image is None:
            shutil.copyfile(MASTER_ICON, target)
            continue
        with Image.open(MASTER_ICON) as image:
            image.convert("RGBA").resize((size, size), Image.LANCZOS).save(target)


def _stage_udev_rules(staging):
    target = os.path.join(
        staging, "usr/lib/udev/rules.d/60-submersion-divecomputers.rules"
    )
    rules = subprocess.run(
        [sys.executable, GEN_UDEV, DESCRIPTOR_C],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    _write(target, rules)


def build_tree(bundle_root, staging, version, install_method, date=None):
    """Create the full install tree under `staging`."""
    if install_method not in INSTALL_METHODS:
        sys.exit(
            "stage_linux_package: unknown install method %r (expected one of %s)"
            % (install_method, ", ".join(INSTALL_METHODS))
        )

    app_dir = os.path.join(staging, "usr/lib/submersion")
    if os.path.exists(staging):
        shutil.rmtree(staging)
    shutil.copytree(bundle_root, app_dir)

    _write(os.path.join(staging, "usr/bin/submersion"), WRAPPER, mode=0o755)
    _write(
        os.path.join(staging, "usr/share/applications/app.submersion.desktop"),
        DESKTOP_ENTRY,
    )
    _write(
        os.path.join(staging, "usr/share/metainfo/app.submersion.metainfo.xml"),
        METAINFO.format(version=version, date=date or build_date()),
    )
    _write(os.path.join(app_dir, "INSTALL_METHOD"), install_method + "\n")
    _stage_icons(staging)
    _stage_udev_rules(staging)
    return staging


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle_root")
    parser.add_argument("staging")
    parser.add_argument("--version", required=True)
    parser.add_argument("--install-method", required=True, choices=INSTALL_METHODS)
    args = parser.parse_args(argv)
    build_tree(args.bundle_root, args.staging, args.version, args.install_method)
    return 0


if __name__ == "__main__":
    sys.exit(main())
