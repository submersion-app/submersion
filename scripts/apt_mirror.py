#!/usr/bin/env python3
"""Point a hosted runner's apt sources away from a regional EC2 Ubuntu mirror.

GitHub serves `ubuntu-24.04` from two runner fleets. The Azure fleet (image
versions like 20261111.370.1) fetches packages from azure.archive.ubuntu.com
at about 14 MB/s. The other fleet (20261111.127.1) lists
us-east-2.ec2.archive.ubuntu.com first, and from 2026-11-18 that mirror
served packages at about 75 kB/s. apt's `mirror+file:` method only moves on
from a mirror that fails outright, never from a slow one, so an install that
took 37 seconds took 16 to 38 minutes instead. That ran Web Smoke past its
40 minute limit, which kept CI/CD on main from succeeding, which stopped
every beta, and timed out the beta's own Linux build when one did start
(issue #4722).

Run this with sudo before the first apt install in a job. It rewrites any
`<region>.ec2.archive.ubuntu.com` URL in the mirror list and the source
files to azure.archive.ubuntu.com, which is a public mirror reachable from
either fleet, and leaves every other host alone. On an Azure runner it
changes nothing. Package signatures are still checked against the Ubuntu
archive keys, so the mirror choice cannot change what gets installed.

Usage: sudo python3 scripts/apt_mirror.py [root]
"""

import glob
import os
import re
import sys

AZURE = "http://azure.archive.ubuntu.com/ubuntu/"
_EC2 = re.compile(r"https?://[a-z0-9-]+\.ec2\.archive\.ubuntu\.com/ubuntu/?")
MIRROR_LIST = os.path.join("etc", "apt", "apt-mirrors.txt")
_SOURCE_GLOBS = (
    os.path.join("etc", "apt", "sources.list"),
    os.path.join("etc", "apt", "sources.list.d", "*.list"),
    os.path.join("etc", "apt", "sources.list.d", "*.sources"),
)


def rewrite(text):
    """Return text with every regional EC2 archive URL replaced by Azure's."""
    return _EC2.sub(AZURE, text)


def rewrite_mirror_list(text):
    """Rewrite a mirror list, keeping only the first entry for each URL.

    Each line is a URL, optionally followed by tab-separated metadata such as
    `priority:1`. An EC2 line that becomes the Azure URL keeps its own
    priority, and a later Azure line is dropped rather than listed twice.
    """
    seen, kept = set(), []
    for line in rewrite(text).splitlines(keepends=True):
        url = line.split("\t", 1)[0].strip()
        if url and url in seen:
            continue
        if url:
            seen.add(url)
        kept.append(line)
    return "".join(kept)


def _targets(root):
    paths = [os.path.join(root, MIRROR_LIST)]
    for pattern in _SOURCE_GLOBS:
        paths.extend(sorted(glob.glob(os.path.join(root, pattern))))
    return [p for p in paths if os.path.isfile(p)]


def main(root="/"):
    changed = []
    for path in _targets(root):
        with open(path, encoding="utf-8") as fh:
            before = fh.read()
        is_list = path.endswith(MIRROR_LIST)
        after = rewrite_mirror_list(before) if is_list else rewrite(before)
        if after == before:
            continue
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(after)
        changed.append(path)
        print(f"Rewrote {path}:")
        print(after, end="" if after.endswith("\n") else "\n")
    if not changed:
        print("apt sources name no regional EC2 mirror; left unchanged.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "/"))
