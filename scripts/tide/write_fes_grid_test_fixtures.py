#!/usr/bin/env python3
"""Write the synthetic FES grid fixtures used by the Dart decoding tests.

Values follow simple formulas so the Dart tests can state expectations
without re-implementing the encoder. Two constituents only: M2 and K1.

  coastal: latMin 10, lonMin -180, 0.5 degree, 5 rows x 720 cols, tiles 4x4
    present cells: (0,0) (0,1) (0,3) (1,1) (1,2) (3,0) (3,1) (3,2) (3,3)
                   (4,0) (0,719) (1,719) (4,719)
    row 2 is empty inside tile (0,0); tile row 1 is a single-row edge tile
    M2 amplitude = 1000 + 100*row + col mm
    M2 phase     = 180*(col % 2) degrees on row 3, else (37*row + 11*col) % 360
    K1 amplitude = 100 mm, except no data at (3,3)
    K1 phase     = 350 degrees on even cols, 10 on odd cols
  global: latMin 0, lonMin -180, 5 degree, 5 rows x 72 cols
    every cell present except (0,0)
    M2 amplitude = 2000 + 10*row + col mm, phase 90
    K1 amplitude = 50 mm, phase 0

Usage (from the repo root, in a venv with numpy):
    python3 scripts/tide/write_fes_grid_test_fixtures.py
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fes_grid_format as fmt  # noqa: E402

ROOT = Path("test/features/tides/data/fixtures/fes_grid")
NAMES = ["M2", "K1"]
PRESENT = [(0, 0), (0, 1), (0, 3), (1, 1), (1, 2), (3, 0), (3, 1), (3, 2),
           (3, 3), (4, 0), (0, 719), (1, 719), (4, 719)]
ROWS, COLS, TILE = 5, 720, 4


def coastal_values():
    amp = np.full((ROWS, COLS, 2), np.nan)
    ph = np.full((ROWS, COLS, 2), np.nan)
    for r, c in PRESENT:
        amp[r, c, 0] = (1000 + 100 * r + c) / 1000.0
        ph[r, c, 0] = 180.0 * (c % 2) if r == 3 else float((37 * r + 11 * c) % 360)
        if (r, c) != (3, 3):
            amp[r, c, 1] = 0.1
            ph[r, c, 1] = 350.0 if c % 2 == 0 else 10.0
    return amp, ph


def main() -> None:
    (ROOT / "coastal").mkdir(parents=True, exist_ok=True)
    for old in (ROOT / "coastal").glob("*.bin"):
        old.unlink()

    amp, ph = coastal_values()
    amp_mm, ph_cd = fmt.quantize(amp, ph)
    present = np.zeros((ROWS, COLS), dtype=bool)
    for r, c in PRESENT:
        present[r, c] = True

    tiles = []
    for tile_row in range((ROWS + TILE - 1) // TILE):
        for tile_col in range(COLS // TILE):
            rs = slice(tile_row * TILE, min((tile_row + 1) * TILE, ROWS))
            cs = slice(tile_col * TILE, (tile_col + 1) * TILE)
            if not present[rs, cs].any():
                continue
            data = fmt.encode_tile(tile_row, tile_col, present[rs, cs],
                                   amp_mm[rs, cs], ph_cd[rs, cs])
            (ROOT / "coastal" / f"tile_{tile_row}_{tile_col}.bin").write_bytes(data)
            tiles.append([tile_row, tile_col])

    g_amp = np.zeros((5, 72, 2))
    g_ph = np.zeros((5, 72, 2))
    for r in range(5):
        for c in range(72):
            g_amp[r, c] = [(2000 + 10 * r + c) / 1000.0, 0.05]
            g_ph[r, c] = [90.0, 0.0]
    g_amp[0, 0] = np.nan
    g_amp_mm, g_ph_cd = fmt.quantize(g_amp, g_ph)
    (ROOT / "global.bin").write_bytes(fmt.encode_global(g_amp_mm, g_ph_cd))

    fmt.write_manifest(
        ROOT,
        model="synthetic",
        extraction_date="2026-09-26",
        band_km=30,
        coastal={"latMin": 10.0, "lonMin": -180.0, "resolution": 0.5,
                 "rows": ROWS, "cols": COLS},
        tile_size=TILE,
        tiles=tiles,
        global_={"latMin": 0.0, "lonMin": -180.0, "resolution": 5.0,
                 "rows": 5, "cols": 72},
        constituents=NAMES,
    )
    print(f"Wrote {len(tiles)} tiles and global.bin to {ROOT}")


if __name__ == "__main__":
    main()
