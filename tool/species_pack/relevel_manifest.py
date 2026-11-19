#!/usr/bin/env python3
"""Adds the measured naming levels to a published pack manifest.

The pack version and every file stay as published, so a device that has
the pack takes the new manifest in place without downloading (issue
#4721). Only `naming.precision` and `naming.levels` may change; anything
else needs a new pack version, and the tool refuses it.

    python3.14 tool/species_pack/relevel_manifest.py --in published.json --out manifest.json
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import manifest as pack_manifest  # noqa: E402


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--in", dest="published", required=True, help="the published manifest.json")
    parser.add_argument("--out", required=True, help="where to write the manifest with levels")
    args = parser.parse_args(argv)
    with open(args.published, encoding="utf-8") as fh:
        published = json.load(fh)
    try:
        out = pack_manifest.relevel(published)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    pack_manifest.write_manifest(args.out, out)
    levels = [level["id"] for level in out["naming"].get("levels", [])]
    print(f"wrote {args.out}: pack {out['packVersion']}, levels {levels or 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
