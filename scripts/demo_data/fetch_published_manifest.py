#!/usr/bin/env python3
"""Fetch the published demo manifest into a build's output folder.

    python3 scripts/demo_data/fetch_published_manifest.py <out_dir>

`pack.sh` runs this first. The build merges its package into the
`demo-manifest.json` it finds in <out_dir>, and publishing replaces the
release's copy with the result, so the build must start from what is
published now or the packages older apps need are lost.

A local copy is always replaced. Only a 404 (nothing published yet) lets a
build start empty; any other failure exits non-zero and stops the build.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

from fetch_demo_db import MANIFEST_URL

MANIFEST_NAME = "demo-manifest.json"


def fetch(url: str) -> bytes | None:
    """The manifest at [url], or None when nothing is published there."""
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise


def _checked(data: bytes) -> bytes:
    """[data], once it reads as a manifest; raises ValueError otherwise."""
    manifest = json.loads(data)
    if not isinstance(manifest, dict) or not isinstance(
        manifest.get("packages"), list
    ):
        raise ValueError("no package list")
    return data


def main(argv: list[str], fetcher=fetch, now=time.time) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <out_dir>", file=sys.stderr)
        return 2
    path = os.path.join(argv[1], MANIFEST_NAME)
    try:
        # The query asks past the download cache, which serves the previous
        # copy for a while after a publish.
        data = fetcher(f"{MANIFEST_URL}?t={int(now())}")
        if data is not None:
            data = _checked(data)
    except (OSError, ValueError) as exc:
        print(f"cannot read the published manifest: {exc}", file=sys.stderr)
        return 1

    if data is None:
        if os.path.exists(path):
            os.remove(path)
        print("nothing published yet; starting a new manifest", file=sys.stderr)
        return 0
    with open(path, "wb") as f:
        f.write(data)
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
