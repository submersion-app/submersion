#!/usr/bin/env python3
"""Group test files into bundles that share one isolate, for the CI test job.

`flutter test` compiles and loads every test file as its own entrypoint, and
with --coverage it collects a hit map per file, so CI time grows with the
number of test files rather than the number of tests. A bundle is a generated
entrypoint that imports many test files and calls each one's main() inside a
group named after the file. The files compile once and share an isolate
(issue #2500).

Usage:
    python3 scripts/bundle_tests.py --shard 0 --total-shards 6
    python3 scripts/bundle_tests.py --containing test/core/utils/foo_test.dart
    python3 scripts/bundle_tests.py --files test/a_test.dart test/b_test.dart

Writes the bundles it selects into --out and prints, one per line, the paths
to hand to `flutter test`: bundles first, then the test files that have to run
as their own entrypoint.

Run from the repository root. Standard library only.
"""

import argparse
import os
import posixpath
import re
import sys

DEFAULT_MAX_FILES = 120
DEFAULT_OUT = "test/.bundles"
TEST_ROOT = "test"
DEFAULTS_HELPER = "test/helpers/global_test_defaults.dart"
PROBE_NAME = "bundle_probe.dart"

_RUN_ALONE_MARKER = re.compile(r"^\s*//\s*test-bundle:\s*run-alone\b", re.M)
_LIBRARY_ANNOTATION = re.compile(
    r"^@(Tags|TestOn|Timeout|Skip|Retry|OnPlatform)\s*\(", re.M
)
_GOLDEN = re.compile(r"\bmatchesGoldenFile\s*\(")
_MAIN = re.compile(r"^\s*(?:[\w<>?]+\s+)?main\s*\(([^)]*)\)\s*(async\b)?", re.M)
_TEST_CASE = re.compile(r"^\s*(?:test|testWidgets)\s*\(", re.M)


def to_posix(path):
    """path with forward slashes, whatever the host separator is."""
    return os.path.normpath(path).replace(os.sep, "/")


def read_text(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def discover(root, out_dir):
    """Every *_test.dart under root, as sorted posix paths, skipping out_dir."""
    skip = to_posix(out_dir)
    found = []
    for directory, subdirs, names in os.walk(root):
        here = to_posix(directory)
        if here == skip or here.startswith(skip + "/"):
            subdirs[:] = []
            continue
        subdirs.sort()
        for name in names:
            if name.endswith("_test.dart"):
                found.append(here + "/" + name)
    return sorted(found)


def run_alone_reason(source):
    """Why a test file needs its own entrypoint, or None when it can share."""
    if _RUN_ALONE_MARKER.search(source):
        return "marked run-alone"
    if _LIBRARY_ANNOTATION.search(source):
        return "library-level test annotation"
    if _GOLDEN.search(source):
        return "golden file comparison"
    main = _MAIN.search(source)
    if main is None:
        return "no main() found"
    if main.group(1).strip():
        return "main() takes parameters"
    if main.group(2):
        return "main() is async"
    return None


def weight(source):
    """How much work a test file is: its declared test count, at least 1."""
    return max(1, len(_TEST_CASE.findall(source)))


def pack(directory, files, max_files):
    """Split files, all under directory, into ordered bundles.

    A directory that fits is one bundle. One that does not is split into its
    own files and its subdirectories, each packed the same way, and
    neighbouring pieces are merged while they still fit. Membership follows
    the directory tree, so adding a test file changes the bundle for its own
    directory and leaves the others alone.
    """
    if not files:
        return []
    if len(files) <= max_files:
        return [list(files)]
    prefix = directory + "/"
    direct = []
    children = {}
    for path in files:
        rest = path[len(prefix):]
        if "/" in rest:
            children.setdefault(rest.split("/", 1)[0], []).append(path)
        else:
            direct.append(path)
    pieces = [direct[i:i + max_files] for i in range(0, len(direct), max_files)]
    for child in sorted(children):
        pieces.extend(pack(prefix + child, children[child], max_files))
    merged = []
    for piece in pieces:
        if merged and len(merged[-1]) + len(piece) <= max_files:
            merged[-1] = merged[-1] + piece
        else:
            merged.append(list(piece))
    return merged


def bundle_name(index, files):
    """A file name that says where the bundle's tests live."""
    common = posixpath.commonpath([posixpath.dirname(f) for f in files])
    slug = re.sub(r"[^A-Za-z0-9]+", "_", common[len(TEST_ROOT):]).strip("_")
    return "bundle_%03d_%s.dart" % (index, slug or "root")


def build_units(files, read, max_files):
    """Every unit for the tree: bundles, then the files that run alone.

    A unit is a dict: 'name' (a bundle's file name, or the test file's path),
    'files' (the test files it runs), 'weight', and 'bundle' (True for a
    generated entrypoint).
    """
    sources = {path: read(path) for path in files}
    alone = [path for path in files if run_alone_reason(sources[path])]
    excluded = set(alone)
    shared = [path for path in files if path not in excluded]
    units = []
    for index, members in enumerate(pack(TEST_ROOT, shared, max_files)):
        units.append({
            "name": bundle_name(index, members),
            "files": members,
            "weight": sum(weight(sources[path]) for path in members),
            "bundle": True,
        })
    for path in alone:
        units.append({
            "name": path,
            "files": [path],
            "weight": weight(sources[path]),
            "bundle": False,
        })
    return units


def assign(units, total_shards):
    """Spread units over shards: heaviest first, each to the lightest shard."""
    shards = [[] for _ in range(total_shards)]
    loads = [0] * total_shards
    for unit in sorted(units, key=lambda u: (-u["weight"], u["name"])):
        target = min(range(total_shards), key=lambda i: (loads[i], i))
        shards[target].append(unit)
        loads[target] += unit["weight"]
    return shards


def dart_string(text):
    """text as a single-quoted Dart string literal."""
    escaped = text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return "'" + escaped + "'"


def render(files, out_dir):
    """The Dart source of a bundle that runs files, in order, in one isolate."""
    out = to_posix(out_dir)
    lines = [
        "// Generated by scripts/bundle_tests.py. Not checked in.",
        "import 'package:flutter_test/flutter_test.dart';",
        "",
        "import %s;" % dart_string(posixpath.relpath(DEFAULTS_HELPER, out)),
    ]
    for index, path in enumerate(files):
        relative = posixpath.relpath(path, out)
        lines.append("import %s as t%d;" % (dart_string(relative), index))
    lines += ["", "void main() {"]
    for index, path in enumerate(files):
        label = posixpath.relpath(path, TEST_ROOT)
        lines.append("  group(%s, () {" % dart_string(label))
        lines.append("    setUpAll(applyGlobalTestDefaults);")
        lines.append("    t%d.main();" % index)
        lines.append("  });")
    lines.append("}")
    return "\n".join(lines) + "\n"


def unit_path(unit, out_dir):
    """The path `flutter test` is given for unit."""
    if unit["bundle"]:
        return to_posix(out_dir) + "/" + unit["name"]
    return unit["name"]


def write_bundles(units, out_dir):
    """Write the bundles among units, replacing any left by an earlier run."""
    os.makedirs(out_dir, exist_ok=True)
    for name in os.listdir(out_dir):
        if name.startswith("bundle_") and name.endswith(".dart"):
            os.remove(os.path.join(out_dir, name))
    for unit in units:
        if not unit["bundle"]:
            continue
        target = os.path.join(out_dir, unit["name"])
        with open(target, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(render(unit["files"], out_dir))


def select(args, parser):
    """The units this invocation runs."""
    if args.files:
        files = [to_posix(path) for path in args.files]
        missing = [path for path in files if not os.path.isfile(path)]
        if missing:
            parser.error("no such test file: %s" % ", ".join(missing))
        return [{
            "name": PROBE_NAME,
            "files": files,
            "weight": len(files),
            "bundle": True,
        }]
    units = build_units(
        discover(TEST_ROOT, args.out), read_text, args.max_files
    )
    if args.containing:
        wanted = to_posix(args.containing)
        chosen = [unit for unit in units if wanted in unit["files"]]
        if not chosen:
            parser.error(
                "%s is not a test file under %s/" % (wanted, TEST_ROOT)
            )
        return chosen
    return assign(units, args.total_shards)[args.shard]


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Group test files into bundles that share one isolate."
    )
    parser.add_argument("--shard", type=int, default=0)
    parser.add_argument("--total-shards", type=int, default=1)
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--max-files", type=int, default=DEFAULT_MAX_FILES)
    parser.add_argument(
        "--containing",
        metavar="TEST_FILE",
        help="select only the unit that runs this test file",
    )
    parser.add_argument(
        "--files",
        nargs="+",
        metavar="TEST_FILE",
        help="bundle exactly these files, in this order",
    )
    args = parser.parse_args(argv)
    if args.total_shards < 1:
        parser.error("--total-shards must be at least 1")
    if not 0 <= args.shard < args.total_shards:
        parser.error("--shard must be from 0 to --total-shards minus 1")
    if args.max_files < 1:
        parser.error("--max-files must be at least 1")
    if args.files and args.containing:
        parser.error("--files and --containing cannot be combined")

    chosen = select(args, parser)
    write_bundles(chosen, args.out)
    ordered = sorted(chosen, key=lambda u: (not u["bundle"], u["name"]))
    for unit in ordered:
        print(unit_path(unit, args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
