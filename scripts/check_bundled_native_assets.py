#!/usr/bin/env python3
"""Verify a desktop app bundle actually contains the native assets it declares.

Dart build hooks (``hook/build.dart``) hand Flutter a set of "code assets":
prebuilt or freshly compiled dynamic libraries that the packaging step is meant
to copy next to the executable. Flutter records what it promised in
``data/flutter_assets/NativeAssetsManifest.json``. Nothing checks that the
promise was kept: the manifest is written by the Dart side, while the copying is
done by the platform's own packaging rules, and the two can disagree without any
build step failing.

This is issue #1129. ``windows/CMakeLists.txt`` wrapped its native-asset install
rule in ``if(EXISTS "${NATIVE_ASSETS_DIR}")``. CMake evaluates that at
*configure* time, but the directory is produced later, during the build, by the
``flutter_assemble`` target. On a clean tree the test was always false, so the
install rule was never generated and every native asset was silently dropped:

    Invalid argument(s): Couldn't resolve native function 'sqlite3_initialize'
    in 'package:sqlite3/src/ffi/libsqlite3.g.dart' : Failed to load dynamic
    library 'sqlcipher.dll': The specified module could not be found.
    (error code: 126)

Windows builds passed CI throughout, because CI builds the app but never
launches it. ``pdfium.dll`` was dropped by the same rule and had been missing
since PDF attachments shipped in v1.7.3, unnoticed only because it fails lazily
when a PDF is opened rather than at startup.

This guard is the complementary check to ``check_native_libs_present.py`` (which
covers Android archives): it reads the manifest out of a built bundle and
asserts that every library the manifest declares is really on disk, and that the
database engine is declared at all. Dependency-free (pure stdlib) so it runs
identically on the Windows and Linux runners.

Windows and Linux only for now. macOS packages native assets through Xcode
rather than CMake, was verified by launching the bundled .app during the
sqlite3 3.x migration, and nests the same tree inside ``Contents/Frameworks``,
which ``MANIFEST_RELPATH`` below does not yet account for.

Usage:
    check_bundled_native_assets.py <bundle-root> [more-bundles ...]

    Windows: build\\windows\\x64\\runner\\Release
    Linux:   build/linux/x64/release/bundle
"""

import json
import os
import sys

# Relative location of the manifest inside a desktop bundle. Identical on
# Windows and Linux (see the macOS note in the module docstring).
MANIFEST_RELPATH = os.path.join("data", "flutter_assets", "NativeAssetsManifest.json")

# Directories, relative to the bundle root, where a bundled library may sit.
# Windows puts them beside the .exe; Linux puts them in lib/ and finds them
# through the runner's $ORIGIN/lib rpath.
SEARCH_DIRS = ("", "lib")

# Link modes that mean "this library is shipped inside the bundle". Anything
# else ("system", "process", "executable") resolves through the OS loader or
# the host process and has no file for us to look for.
BUNDLED_LINK_MODES = ("absolute", "relative")

# The SQLCipher build of SQLite, supplied by package:sqlite3's build hook (see
# the `hooks:` section of pubspec.yaml). Its absence is fatal at startup: the
# app cannot open its database and never reaches the first screen. Asserting the
# id is present stops a bundle that is internally consistent but has quietly
# lost the engine (a pubspec hook define dropped in a dependency bump, say)
# from passing on file-presence alone.
REQUIRED_ASSET_ID = "package:sqlite3/src/ffi/libsqlite3.g.dart"


def bundled_libraries(manifest):
    """Return ``[(asset_id, filename), ...]`` for assets shipped in the bundle.

    Entries are ``[link_mode]`` or ``[link_mode, path]``. A path that is
    absolute or contains directory separators points outside the bundle (a
    system library), so only bare filenames are ours to verify.
    """
    found = []
    for assets in manifest.get("native-assets", {}).values():
        for asset_id, entry in assets.items():
            if not isinstance(entry, list) or len(entry) < 2:
                continue
            link_mode, path = entry[0], entry[1]
            if link_mode not in BUNDLED_LINK_MODES:
                continue
            if os.path.isabs(path) or "/" in path or "\\" in path:
                continue
            found.append((asset_id, path))
    return found


def declared_asset_ids(manifest):
    """Every asset id in the manifest, across all targets."""
    ids = set()
    for assets in manifest.get("native-assets", {}).values():
        ids.update(assets)
    return ids


def locate(root, filename):
    """Return the bundle-relative path of ``filename``, or None if absent."""
    for subdir in SEARCH_DIRS:
        candidate = os.path.join(root, subdir, filename)
        if os.path.isfile(candidate):
            return os.path.join(subdir, filename) if subdir else filename
    return None


def check_bundle(root):
    """Check one bundle. Return ``(ok, lines)`` where ``lines`` is the report."""
    manifest_path = os.path.join(root, MANIFEST_RELPATH)
    try:
        with open(manifest_path) as fh:
            manifest = json.load(fh)
    except (OSError, ValueError) as exc:
        # Fail closed: without the manifest we cannot vouch for the bundle.
        return False, [f"  FAIL  cannot read {MANIFEST_RELPATH}: {exc}"]

    lines = []
    ok = True

    if REQUIRED_ASSET_ID not in declared_asset_ids(manifest):
        ok = False
        lines.append(
            f"  FAIL  manifest does not declare {REQUIRED_ASSET_ID} "
            "(the SQLCipher engine); the app cannot open its database"
        )

    libraries = bundled_libraries(manifest)
    if not libraries:
        ok = False
        lines.append("  FAIL  manifest declares no bundled native libraries")

    for asset_id, filename in sorted(libraries, key=lambda pair: pair[1]):
        location = locate(root, filename)
        if location is None:
            ok = False
            lines.append(
                f"  FAIL  {filename} declared by {asset_id} is missing from the bundle"
            )
        else:
            lines.append(f"  ok    {location} ({asset_id})")

    return ok, lines


def main(argv):
    roots = argv[1:]
    if not roots:
        print(__doc__)
        return 2

    all_ok = True
    for root in roots:
        print(f"Checking bundled native assets: {root}")
        ok, lines = check_bundle(root)
        for line in lines:
            print(line)
        if ok:
            print("  -> PASS: every declared native asset is bundled")
        else:
            print(
                "  -> FAIL: a declared native asset is missing from the bundle "
                "(the app will fail to load it at runtime; see issue #1129)"
            )
        all_ok = all_ok and ok

    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
