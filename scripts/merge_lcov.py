#!/usr/bin/env python3
"""Merge several lcov.info reports into one, unioning per-line hit counts.

Why this exists: CI shards the Dart test suite BY FILE and each shard emits a
partial lcov. A file is often *compiled* (all lines hit=0) by many shards that
merely import it for navigation, while only one shard actually *executes* it.
Uploading those partial reports to Codecov under per-shard flags let the
all-zero reports win the cross-flag merge, so genuinely-tested widgets (e.g.
photo_viewer_page.dart's connector-video item) showed 0% patch coverage.

Merging here into a single authoritative report -- max(hits) per line across
all shards -- and doing ONE Codecov upload sidesteps Codecov's cross-flag
merge entirely.

Usage:
    python3 scripts/merge_lcov.py <output.info> <input1.info> [<input2.info> ...]

Flutter's lcov only uses SF/DA/LF/LH/end_of_record records, so that is all we
carry through; LF/LH are recomputed from the merged DA set.
"""

import sys


def _accumulate(path, files):
    current = None
    try:
        handle = open(path)
    except FileNotFoundError:
        sys.stderr.write(f"merge_lcov: skipping missing {path}\n")
        return
    with handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith("SF:"):
                current = line[3:]
                files.setdefault(current, {})
            elif line.startswith("DA:") and current is not None:
                parts = line[3:].split(",")
                lineno = int(parts[0])
                hits = int(parts[1]) if len(parts) > 1 else 0
                lines = files[current]
                lines[lineno] = max(lines.get(lineno, 0), hits)
            elif line == "end_of_record":
                current = None


def main(argv):
    if len(argv) < 3:
        sys.stderr.write(
            "usage: merge_lcov.py <output.info> <input.info> [<input.info> ...]\n"
        )
        return 2
    output = argv[1]
    files = {}
    for path in argv[2:]:
        _accumulate(path, files)

    records = 0
    with open(output, "w") as out:
        for source in sorted(files):
            lines = files[source]
            if not lines:
                continue
            out.write(f"SF:{source}\n")
            for lineno in sorted(lines):
                out.write(f"DA:{lineno},{lines[lineno]}\n")
            hit = sum(1 for h in lines.values() if h > 0)
            # LF (found) before LH (hit) is the conventional lcov field order.
            out.write(f"LF:{len(lines)}\n")
            out.write(f"LH:{hit}\n")
            out.write("end_of_record\n")
            records += 1

    sys.stderr.write(f"merge_lcov: wrote {records} file records to {output}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
