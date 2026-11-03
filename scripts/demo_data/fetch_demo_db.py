#!/usr/bin/env python3
"""Download the demo-mode sample logbook for the store screenshots.

    python3 scripts/demo_data/fetch_demo_db.py <out_dir>

Reads the manifest of the `demo-data` release (issue #3708), picks the newest
package this checkout can open (its schema no newer than the app's
`currentSchemaVersion`; the app migrates an older one), checks its SHA-256
against the manifest, and extracts `submersion_demo.db` and `photos/` into
<out_dir>. Pass that directory to the screenshot test as DEMO_PACKAGE_DIR.

With --web-index it gzips the database, a third of the size for a visitor
to download, and writes `demo.json` beside it: the web build ships the
sample logbook inside the site, since a page cannot read GitHub release
files (issue #4121), and the site finds it through that index.

Exits non-zero with a message when no compatible package is published.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

MANIFEST_URL = (
    "https://github.com/submersion-app/submersion/releases/download/"
    "demo-data/demo-manifest.json"
)
DATABASE_NAME = "submersion_demo.db"
WEB_INDEX_NAME = "demo.json"
_PHOTO_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")
_REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SCHEMA = re.compile(r"static\s+const\s+int\s+currentSchemaVersion\s*=\s*(\d+)\s*;")


def current_schema(database_dart: str) -> int:
    """The app's schema version, from the text of lib/core/database/database.dart."""
    match = _SCHEMA.search(database_dart)
    if match is None:
        raise ValueError("currentSchemaVersion not found in database.dart")
    return int(match.group(1))


def pick_package(manifest: dict, schema: int) -> dict:
    """The newest package whose schema is not above [schema]."""
    usable = [
        p for p in manifest.get("packages", []) if int(p["schemaVersion"]) <= schema
    ]
    if not usable:
        raise ValueError(
            f"the demo-data release has no package for schema {schema} or older; "
            "build and publish one (tool/demo_data/README.md)"
        )
    return max(usable, key=lambda p: int(p["schemaVersion"]))


def verify(data: bytes, sha256: str) -> None:
    actual = hashlib.sha256(data).hexdigest()
    if actual != sha256.lower():
        raise ValueError(f"checksum mismatch: expected {sha256}, got {actual}")


def extract(data: bytes, out_dir: str) -> None:
    """Writes the package into [out_dir], refusing any entry outside it."""
    root = os.path.realpath(out_dir)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        names = z.namelist()
        if DATABASE_NAME not in names:
            raise ValueError(f"the package has no {DATABASE_NAME}")
        for name in names:
            target = os.path.realpath(os.path.join(root, name))
            if os.path.commonpath([root, target]) != root:
                raise ValueError(f"refusing an entry outside {out_dir}: {name}")
        for name in names:
            if name.endswith("/"):
                continue
            target = os.path.join(root, name)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "wb") as f:
                f.write(z.read(name))


def web_index(out_dir: str, package: dict) -> dict:
    """Gzips the database in [out_dir] and returns what a web bundle serves
    there, for the site to find: the database with its own size and hash,
    which the site checks once it has inflated it, and the photos."""
    raw_path = os.path.join(out_dir, DATABASE_NAME)
    with open(raw_path, "rb") as f:
        database = f.read()
    packed = gzip.compress(database, compresslevel=9, mtime=0)
    packed_name = DATABASE_NAME + ".gz"
    with open(os.path.join(out_dir, packed_name), "wb") as f:
        f.write(packed)
    os.remove(raw_path)
    photos_dir = os.path.join(out_dir, "photos")
    photos = (
        sorted(
            name
            for name in os.listdir(photos_dir)
            if name.lower().endswith(_PHOTO_EXTENSIONS)
        )
        if os.path.isdir(photos_dir)
        else []
    )
    return {
        "formatVersion": 1,
        "schemaVersion": int(package["schemaVersion"]),
        "generatedAt": package["generatedAt"],
        "database": {
            "path": packed_name,
            "size": len(database),
            "sha256": hashlib.sha256(database).hexdigest(),
            "compressedSize": len(packed),
        },
        "photos": [f"photos/{name}" for name in photos],
    }


def _download(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("out_dir")
    parser.add_argument("--manifest-url", default=MANIFEST_URL)
    parser.add_argument(
        "--web-index",
        action="store_true",
        help=f"also write {WEB_INDEX_NAME} for a web bundle",
    )
    parser.add_argument(
        "--database-dart",
        default=os.path.join(_REPO, "lib", "core", "database", "database.dart"),
    )
    args = parser.parse_args(argv)
    try:
        with open(args.database_dart, encoding="utf-8") as f:
            schema = current_schema(f.read())
        package = pick_package(json.loads(_download(args.manifest_url)), schema)
        data = _download(package["url"])
        verify(data, package["sha256"])
        os.makedirs(args.out_dir, exist_ok=True)
        extract(data, args.out_dir)
        if args.web_index:
            with open(
                os.path.join(args.out_dir, WEB_INDEX_NAME), "w", encoding="utf-8"
            ) as f:
                json.dump(web_index(args.out_dir, package), f, indent=2)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as e:
        print(f"fetch_demo_db: {e}", file=sys.stderr)
        return 1
    print(
        f"demo logbook (schema {package['schemaVersion']}, app schema {schema}) "
        f"extracted to {args.out_dir}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
