#!/usr/bin/env python3
"""Checks that scripts/web/sqlite3_wasm.lock pins the sqlite3.wasm build that
matches the package:sqlite3 version in pubspec.lock.

The WebAssembly module and the Dart bindings are released together; a module
from another release fails at runtime in the browser with an obscure import
error. The lock names the release in its URL, so the two files must agree.

Usage: python3 scripts/web/check_sqlite3_wasm_lock.py [LOCK] [PUBSPEC_LOCK]
Prints OK or FAIL lines; exits 1 on any failure.
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
DEFAULT_LOCK = os.path.join(_HERE, "sqlite3_wasm.lock")
DEFAULT_PUBSPEC_LOCK = os.path.join(_REPO, "pubspec.lock")

_URL_VERSION = re.compile(r"/sqlite3-([0-9][^/]*)/sqlite3\.wasm$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _lock_fields(lock_path):
    fields = {}
    with open(lock_path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
    return fields


def lock_version(lock_path):
    """The sqlite3.dart release the lock's URL points at, or None."""
    url = _lock_fields(lock_path).get("url", "")
    match = _URL_VERSION.search(url)
    return match.group(1) if match else None


def lock_sha256(lock_path):
    """The pinned hash, or None when missing or malformed."""
    sha = _lock_fields(lock_path).get("sha256")
    return sha if sha and _SHA256.match(sha) else None


def pubspec_sqlite3_version(pubspec_lock_path):
    """The resolved version of package:sqlite3 in pubspec.lock, or None."""
    in_block = False
    with open(pubspec_lock_path, encoding="utf-8") as handle:
        for line in handle:
            if line.rstrip() == "  sqlite3:":
                in_block = True
                continue
            if in_block:
                if re.match(r"^  \S", line):
                    return None
                match = re.match(r'^    version: "([^"]+)"', line)
                if match:
                    return match.group(1)
    return None


def check(lock_path, pubspec_lock_path):
    """Returns a list of problems; empty when the lock matches."""
    problems = []
    locked = lock_version(lock_path)
    if locked is None:
        problems.append(
            "%s: url does not name a sqlite3-<version>/sqlite3.wasm release asset"
            % lock_path
        )
    if lock_sha256(lock_path) is None:
        problems.append("%s: sha256 is missing or not 64 hex digits" % lock_path)
    resolved = pubspec_sqlite3_version(pubspec_lock_path)
    if resolved is None:
        problems.append("%s: no sqlite3 package version found" % pubspec_lock_path)
    if locked is not None and resolved is not None and locked != resolved:
        problems.append(
            "sqlite3.wasm is pinned to release %s but pubspec.lock resolves "
            "package:sqlite3 %s; update scripts/web/sqlite3_wasm.lock (url and "
            "sha256) to the matching release" % (locked, resolved)
        )
    return problems


def main(argv):
    lock_path = argv[1] if len(argv) > 1 else DEFAULT_LOCK
    pubspec_lock_path = argv[2] if len(argv) > 2 else DEFAULT_PUBSPEC_LOCK
    problems = check(lock_path, pubspec_lock_path)
    if problems:
        for problem in problems:
            print("FAIL: %s" % problem)
        return 1
    print("OK: sqlite3.wasm lock matches package:sqlite3 %s" % lock_version(lock_path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
