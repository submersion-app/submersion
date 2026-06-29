#!/usr/bin/env python3
"""Verify required native libraries are actually bundled in an Android APK/AAB.

Some native libraries are pulled in by Flutter/Gradle dependencies rather than
built from this repo's own sources, so a routine dependency bump can silently
drop one from the packaged app. The build still succeeds and every guard that
inspects the libraries that *are* present still passes -- the lib is simply
gone, and the app fails the instant it needs it on a real device.

This is issue #433: a "tier 2 constraint bump" moved ``sqlite3_flutter_libs``
from ``0.5.x`` to ``0.6.0+eol``. That ``+eol`` release is an empty tombstone
package (it removed all of its Android/desktop build scripts) intended only for
apps that have migrated to ``package:sqlite3`` 3.x, which bundles the SQLite
engine itself. Submersion is still on ``sqlite3`` 2.x, so nothing bundled
``libsqlite3.so`` anymore. The APK shipped without it and the app died at
startup with::

    Failed to load dynamic library '/data/data/app.submersion/lib/libsqlite3.so':
    dlopen failed: library "..." not found

The existing ``check_16kb_alignment`` guard did not catch this: a *missing*
library is not a *misaligned* library, so the alignment pass was clean. This is
the complementary check -- it asserts that each required library is present in
every ABI the archive ships, and fails (exit code 1) otherwise. It is
dependency-free (pure stdlib) so it runs identically in CI (Linux) and locally
(macOS).

Libraries whose silent absence is fatal at startup belong in ``REQUIRED_LIBS``.
Libraries whose absence only disables a feature (e.g. ``liblibdc_jni.so``, the
dive-computer bridge) or that would fail the build far earlier (the Flutter
engine libs) are intentionally not listed here.

Usage:
    check_native_libs_present.py <app.apk|app.aab> [more.apk ...]
"""

import sys
import zipfile

# Native libraries that MUST be bundled for every ABI. ``libsqlite3.so`` is the
# SQLite engine behind Drift; without it the database cannot open and the app is
# unusable from the first launch (issue #433). It is supplied by the Maven
# artifact ``eu.simonbinder:sqlite3-native-library`` that sqlite3_flutter_libs
# 0.5.x depends on -- and only while we remain on sqlite3 2.x. Keep this list in
# sync with pubspec.yaml's note pinning sqlite3_flutter_libs to 0.5.x.
REQUIRED_LIBS = ("libsqlite3.so",)


def abi_to_libs(zf):
    """Map each ABI to the set of ``.so`` basenames it ships.

    Handles both APK layout (``lib/<abi>/foo.so``) and AAB layout
    (``base/lib/<abi>/foo.so``). Only files sitting directly inside an
    ``lib/<abi>/`` directory are counted; native libs are never nested deeper.
    """
    abis = {}
    for name in zf.namelist():
        if not name.endswith(".so"):
            continue
        parts = name.split("/")
        try:
            i = parts.index("lib")
        except ValueError:
            continue
        # Expect exactly lib/<abi>/<file>.so -- <file> is the last component.
        if i + 2 != len(parts) - 1:
            continue
        abi, basename = parts[i + 1], parts[i + 2]
        abis.setdefault(abi, set()).add(basename)
    return abis


def check_archive(path):
    """Check one APK/AAB. Return ``(ok, lines)`` where ``lines`` is the report."""
    lines = []
    ok = True
    with zipfile.ZipFile(path) as zf:
        abis = abi_to_libs(zf)
        if not abis:
            # Fail closed: an archive with no native libs at all is not a build
            # we can vouch for (and would never run).
            return False, ["  FAIL  no native libraries (.so under lib/<abi>/) found"]
        for abi in sorted(abis):
            present = abis[abi]
            missing = [lib for lib in REQUIRED_LIBS if lib not in present]
            if missing:
                ok = False
                lines.append(
                    f"  FAIL  {abi}: missing {', '.join(missing)} "
                    f"(have: {', '.join(sorted(present))})"
                )
            else:
                lines.append(
                    f"  ok    {abi}: {', '.join(REQUIRED_LIBS)} present"
                )
    return ok, lines


def main(argv):
    paths = argv[1:]
    if not paths:
        print(__doc__)
        return 2

    all_ok = True
    for path in paths:
        print(f"Checking required native libraries: {path}")
        try:
            ok, lines = check_archive(path)
        except (OSError, zipfile.BadZipFile) as exc:
            print(f"  ERROR reading {path}: {exc}")
            all_ok = False
            continue
        for line in lines:
            print(line)
        if ok:
            print("  -> PASS: all required native libraries are bundled")
        else:
            print("  -> FAIL: a required native library is missing "
                  "(the app will fail to open its database; see issue #433)")
        all_ok = all_ok and ok

    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
