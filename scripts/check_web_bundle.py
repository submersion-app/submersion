#!/usr/bin/env python3
"""Checks a built web bundle before it is zipped, served or shipped.

`scripts/build_web.sh` ends with this check, and the release job zips what
passes it. It fails when a file the browser app needs is missing (the
workers, the SQLite module, the hosting files the guide refers to), when
`sqlite3.wasm` is not the build the lock pins (a module from another
release fails in the browser with an obscure import error), when a service
worker was generated (a self-hoster who replaces the files would keep
serving last release's bundle from the browser's cache; the build passes
`--pwa-strategy=none` for that reason), or when the worker sources and the
compiler sidecars `flutter build web` copies out of `web/` made it in.
When the bundle carries the sample logbook (`demo/demo.json`), every file
the index names must be there, the gzipped database inflating byte for
byte to what the index says.

Usage: check_web_bundle.py [BUNDLE_DIR] [LOCK]
Prints OK or FAIL lines; exits 1 on any failure.
"""

import fnmatch
import gzip
import hashlib
import json
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)
DEFAULT_BUNDLE = os.path.join(_REPO, "build", "web")
DEFAULT_LOCK = os.path.join(_REPO, "scripts", "web", "sqlite3_wasm.lock")

# Every file the bundle must hold, relative to its root.
REQUIRED = (
    "index.html",
    "flutter_bootstrap.js",
    "main.dart.js",
    "sqlite3.wasm",
    "drift_worker.js",
    "compute_worker.js",
    "media_stream_worker.js",
    "version.json",
    "_headers",
    "nginx.conf",
    "Caddyfile",
    "Dockerfile",
    "HOSTING.md",
)

# Files that must not be there at all.
FORBIDDEN = {
    "flutter_service_worker.js": "a service worker caches the bundle, so a "
    "replaced deployment keeps serving the old one",
}

# Name patterns that must not appear anywhere in the bundle: the worker
# sources and the sidecars `dart compile js` writes beside them.
FORBIDDEN_PATTERNS = ("*.dart", "*.map", "*.deps")


def _lock_sha256(lock_path):
    with open(lock_path, encoding="utf-8") as handle:
        for line in handle:
            key, sep, value = line.strip().partition("=")
            if sep and key == "sha256":
                return value
    return None


def _file_sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


SAMPLE_INDEX = os.path.join("demo", "demo.json")


def check_sample_logbook(bundle_dir):
    """Failures for the sample logbook the bundle ships, if it ships one."""
    index_path = os.path.join(bundle_dir, SAMPLE_INDEX)
    if not os.path.isfile(index_path):
        return []
    demo = os.path.dirname(index_path)
    try:
        with open(index_path, encoding="utf-8") as handle:
            index = json.load(handle)
        database = index["database"]
        photos = index["photos"]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return [f"{SAMPLE_INDEX} cannot be read: {exc}"]
    failures = []
    db_path = os.path.join(demo, database["path"])
    if not os.path.isfile(db_path):
        failures.append(f"demo/{database['path']} is missing")
    else:
        try:
            with gzip.open(db_path, "rb") as handle:
                inflated = handle.read()
        except OSError:
            inflated = None
        if (
            inflated is None
            or len(inflated) != database["size"]
            or hashlib.sha256(inflated).hexdigest() != database["sha256"]
        ):
            failures.append(
                f"demo/{database['path']} is not the file the index names"
            )
    for photo in photos:
        if not os.path.isfile(os.path.join(demo, photo)):
            failures.append(f"demo/{photo} is missing")
    return failures


def check_bundle(bundle_dir, lock_path):
    """Returns the list of failures, empty when the bundle is complete."""
    failures = []
    for name in REQUIRED:
        if not os.path.isfile(os.path.join(bundle_dir, name)):
            failures.append(f"missing {name}")
    for name, why in FORBIDDEN.items():
        if os.path.isfile(os.path.join(bundle_dir, name)):
            failures.append(f"{name} must not ship: {why}")
    for root, _, files in os.walk(bundle_dir):
        for file_name in sorted(files):
            if any(fnmatch.fnmatch(file_name, p) for p in FORBIDDEN_PATTERNS):
                relative = os.path.relpath(os.path.join(root, file_name), bundle_dir)
                failures.append(
                    f"{relative} must not ship: a worker source or a compiler sidecar"
                )
    wasm = os.path.join(bundle_dir, "sqlite3.wasm")
    if os.path.isfile(wasm):
        expected = _lock_sha256(lock_path)
        actual = _file_sha256(wasm)
        if actual != expected:
            failures.append(
                f"sqlite3.wasm sha256 {actual} is not the build the lock pins "
                f"({expected}); run scripts/web/fetch_sqlite3_wasm.sh"
            )
    return failures


def main(argv=None):
    args = sys.argv[1:] if argv is None else list(argv)
    bundle_dir = args[0] if args else DEFAULT_BUNDLE
    lock_path = args[1] if len(args) > 1 else DEFAULT_LOCK
    failures = check_bundle(bundle_dir, lock_path) + check_sample_logbook(bundle_dir)
    for failure in failures:
        print(f"FAIL: {failure}")
    if failures:
        return 1
    print(f"OK: {bundle_dir} holds a complete web bundle")
    return 0


if __name__ == "__main__":
    sys.exit(main())
