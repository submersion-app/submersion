#!/usr/bin/env python3
"""The latitude and longitude grid the model pack's region table uses.

The app reads the same grid in
lib/features/species_id/domain/services/region_grid.dart. Both are checked
against testdata/region_vectors.json, which this module writes:

    python3 tool/species_pack/region_grid.py --write-vectors \
        tool/species_pack/testdata/region_vectors.json

Cells are numbered row by row from latitude -90 and longitude -180.
Latitude 90 falls in the last row. Longitude 180 is longitude -180.
Standard library only.
"""

import argparse
import json
import math
import sys


def columns(cell_degrees):
    return 360 // cell_degrees


def rows(cell_degrees):
    return 180 // cell_degrees


def cell_count(cell_degrees):
    return columns(cell_degrees) * rows(cell_degrees)


def cell_of(lat, lon, cell_degrees):
    """The cell holding a point. Out-of-range latitudes clamp to the poles."""
    n_rows = rows(cell_degrees)
    n_cols = columns(cell_degrees)
    row = math.floor((lat + 90) / cell_degrees)
    row = min(max(row, 0), n_rows - 1)
    col = math.floor((lon + 180) / cell_degrees) % n_cols
    return row * n_cols + col


def neighbourhood(cell, rings, cell_degrees):
    """The cell and every cell within `rings` steps. Longitude wraps;
    latitude stops at the poles."""
    n_rows = rows(cell_degrees)
    n_cols = columns(cell_degrees)
    row, col = divmod(cell, n_cols)
    out = set()
    for dr in range(-rings, rings + 1):
        r = row + dr
        if r < 0 or r >= n_rows:
            continue
        for dc in range(-rings, rings + 1):
            out.add(r * n_cols + (col + dc) % n_cols)
    return out


def row_bytes(cell_degrees):
    return (cell_count(cell_degrees) + 7) // 8


def pack_bits(rows_of_cells, cell_degrees):
    """One row per candidate, each `row_bytes` long; cell c is bit c % 8 of
    byte c // 8."""
    width = row_bytes(cell_degrees)
    out = bytearray(width * len(rows_of_cells))
    for index, cells in enumerate(rows_of_cells):
        base = index * width
        for c in cells:
            out[base + c // 8] |= 1 << (c % 8)
    return bytes(out)


def vectors():
    cd = 5
    points = [
        (0, 0),
        (-90, -180),
        (90, 180),
        (89.99, 179.99),
        (12.1, -68.3),
        (-33.9, 151.2),
        (-0.01, -0.01),
        (45, -180),
    ]
    interior = cell_of(12.1, -68.3, cd)
    seam = cell_of(12.1, -179.0, cd)
    top = cell_of(89.0, 10.0, cd)
    bottom_seam = cell_of(-89.0, 179.0, cd)
    rows_of_cells = [[0, 7, 8, interior], [], [cell_count(cd) - 1]]
    return {
        "cellDegrees": cd,
        "columns": columns(cd),
        "rows": rows(cd),
        "cellOf": [
            {"lat": lat, "lon": lon, "cell": cell_of(lat, lon, cd)}
            for lat, lon in points
        ],
        "neighbourhood": [
            {"cell": c, "rings": 1, "cells": sorted(neighbourhood(c, 1, cd))}
            for c in (interior, seam, top, bottom_seam)
        ],
        "packBits": {
            "rows": rows_of_cells,
            "hex": pack_bits(rows_of_cells, cd).hex(),
        },
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write-vectors", metavar="PATH", required=True)
    args = parser.parse_args(argv)
    with open(args.write_vectors, "w", encoding="utf-8") as fh:
        json.dump(vectors(), fh, indent=1)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
