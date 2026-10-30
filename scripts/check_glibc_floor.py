#!/usr/bin/env python3
"""Fail if a Linux bundle needs a newer glibc than the app promises to support.

The runner a Linux build runs on sets the glibc floor of everything it
produces: the app binary, libsqlcipher.so and the plugin libraries all record
the glibc symbol versions they were linked against, and the loader refuses to
start them on a system whose glibc is older:

    ./submersion: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.43'
    not found (required by ./lib/libsqlcipher.so)

No build step fails when that floor rises. This is issue #3523: GitHub moved
the ubuntu-latest runner label from Ubuntu 24.04 (glibc 2.39) to Ubuntu 26.04
(glibc 2.43), and a release built there would have stopped launching on Ubuntu
24.04 LTS, Debian 13 and the other distributions docs/user/installation.md
lists. The package install checks could not catch it either, because they test
in a container matching the runner's own release.

This reads the version needs section (`readelf -V`) of every ELF file in the
bundle and fails if any of them needs a GLIBC_ version newer than the limit.
The default limit is the floor docs/user/installation.md states; raise both
together, deliberately, or not at all.

Only GLIBC_ requirements are checked. GLIBCXX_ (libstdc++) is versioned
separately; it rises with the compiler rather than with glibc.

Usage:
    check_glibc_floor.py [--max 2.38] <bundle-root> [more-bundles ...]

    Linux: build/linux/x64/release/bundle

Needs readelf (binutils) on PATH.
"""

import argparse
import os
import re
import subprocess
import sys

# The glibc version docs/user/installation.md tells users they need. The test
# suite fails if the two disagree, so neither can move without the other.
DEFAULT_MAX_GLIBC = "2.38"

# A dotted numeric version, as --max accepts and GLIBC_ requirements carry.
_VERSION_RE = re.compile(r"^\d+(?:\.\d+)+$")

ELF_MAGIC = b"\x7fELF"

# One requirement inside the version needs section, for example
#   0x0010:   Name: GLIBC_2.38  Flags: none  Version: 5
# GLIBCXX_ and GLIBC_PRIVATE do not match: the version must be numeric.
_NEEDED_GLIBC_RE = re.compile(r"\bName: GLIBC_(\d+(?:\.\d+)+)\b")

# readelf -V prints up to three sections, each introduced by a header such as
#   Version needs section '.gnu.version_r' contains 3 entries:
# The definition and symbol sections can name GLIBC_ versions too, but only the
# needs section lists what the loader will demand.
_SECTION_HEADER_RE = re.compile(r"^Version (\w+) section ")


def parse_version(text):
    """``"2.38"`` -> ``(2, 38)``, so versions compare numerically."""
    return tuple(int(part) for part in text.split("."))


def glibc_version_arg(text):
    """argparse type for --max: reject anything parse_version cannot read."""
    if not _VERSION_RE.match(text):
        raise argparse.ArgumentTypeError(
            "expected a version such as 2.38, got %r" % text
        )
    return text


def required_glibc_versions(readelf_output):
    """GLIBC versions named in the version needs section of `readelf -V`."""
    versions = set()
    in_needs = False
    for line in readelf_output.splitlines():
        header = _SECTION_HEADER_RE.match(line)
        if header:
            in_needs = header.group(1) == "needs"
            continue
        if in_needs:
            versions.update(_NEEDED_GLIBC_RE.findall(line))
    return versions


def read_version_info(path, readelf="readelf"):
    """`readelf -V -W` output for one file.

    Run in the C locale: binutils translates its section headers, and the
    parser above only understands the English ones.
    """
    try:
        return subprocess.run(
            [readelf, "-V", "-W", path],
            check=True,
            capture_output=True,
            text=True,
            env=dict(os.environ, LC_ALL="C"),
        ).stdout
    except FileNotFoundError:
        sys.exit(
            "check_glibc_floor: %s not found. Install binutils on the runner."
            % readelf
        )
    except subprocess.CalledProcessError as error:
        sys.exit("check_glibc_floor: readelf failed on %s: %s" % (path, error))


def is_elf(path):
    try:
        with open(path, "rb") as fh:
            return fh.read(len(ELF_MAGIC)) == ELF_MAGIC
    except OSError:
        return False


def elf_files(root):
    """Bundle-relative paths of every ELF file under ``root``, sorted."""
    found = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            path = os.path.join(dirpath, name)
            if not os.path.islink(path) and is_elf(path):
                found.append(os.path.relpath(path, root))
    return sorted(found)


def check_bundle(root, max_version, reader=read_version_info):
    """Check one bundle. Return ``(ok, lines)`` where ``lines`` is the report."""
    limit = parse_version(max_version)
    files = elf_files(root)
    if not files:
        return False, ["  FAIL  no ELF files found in the bundle"]

    ok = True
    lines = []
    highests = []
    for rel in files:
        versions = required_glibc_versions(reader(os.path.join(root, rel)))
        if not versions:
            lines.append("  ok    %s needs no GLIBC version" % rel)
            continue
        highest = max(versions, key=parse_version)
        highests.append(highest)
        if parse_version(highest) > limit:
            ok = False
            lines.append(
                "  FAIL  %s needs GLIBC_%s, newer than %s" % (rel, highest, max_version)
            )
        else:
            lines.append("  ok    %s needs GLIBC_%s" % (rel, highest))

    if not highests:
        return False, lines + [
            "  FAIL  no GLIBC version requirement found in any ELF file; "
            "the readelf output was not understood"
        ]

    floor = max(highests, key=parse_version)
    lines.append("  bundle needs glibc %s (limit %s)" % (floor, max_version))
    return ok, lines


def main(argv, reader=read_version_info):
    parser = argparse.ArgumentParser(
        prog=os.path.basename(argv[0]),
        description="Fail if a Linux bundle needs a newer glibc than allowed.",
    )
    parser.add_argument(
        "--max",
        default=DEFAULT_MAX_GLIBC,
        type=glibc_version_arg,
        help="highest GLIBC version the bundle may need (default %(default)s)",
    )
    parser.add_argument("bundles", nargs="+", metavar="bundle-root")
    args = parser.parse_args(argv[1:])

    all_ok = True
    for root in args.bundles:
        print("Checking glibc floor: %s" % root)
        ok, lines = check_bundle(root, args.max, reader=reader)
        for line in lines:
            print(line)
        if ok:
            print("  -> PASS: runs on glibc %s and newer" % args.max)
        else:
            print(
                "  -> FAIL: the bundle would not start on glibc %s, the floor "
                "docs/user/installation.md promises. Build on an older runner, "
                "or raise the floor in the docs and this check together "
                "(see issue #3523)." % args.max
            )
        all_ok = all_ok and ok

    return 0 if all_ok else 1


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv))
