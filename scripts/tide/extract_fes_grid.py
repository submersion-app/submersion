#!/usr/bin/env python3
"""Extract Submersion's bundled FES2022 tide grid from FES2022b NetCDF files.

Writes assets/data/tide/fes/ (manifest, 1-degree global layer, 0.1-degree
coastal tiles) and the accuracy fixture
test/features/tides/data/fixtures/fes_native_vectors.json in one pass.

Needs about 3 GB of RAM and a venv with numpy and netCDF4:
    python3.14 -m venv ~/.venvs/submersion-tide
    ~/.venvs/submersion-tide/bin/pip install numpy netCDF4

Usage (from the repo root):
    ~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py \\
        --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated
    ~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py \\
        --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated --verify
"""

import argparse
import datetime
import json
import math
import random
import shutil
import sys
from pathlib import Path

import netCDF4 as nc
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fes_grid_format as fmt  # noqa: E402

OUT = Path("assets/data/tide/fes")
VECTORS_OUT = Path("test/features/tides/data/fixtures/fes_native_vectors.json")
NATIVE = 30  # native cells per degree
LAT_MIN, LAT_MAX = -80, 80
COASTAL_STEP = 3  # native cells per coastal cell: 0.1 degree
GLOBAL_STEP = 30  # native cells per global cell: 1 degree
BAND_STEPS = 8  # 4-neighbour native steps from non-ocean: about 30 km
TILE = 100
LAKE = 3  # FES2022B mask class for lakes: zero amplitudes, not tide data

FILE_NAMES = {
    "M2": "m2", "S2": "s2", "N2": "n2", "K2": "k2", "2N2": "2n2",
    "Mu2": "mu2", "Nu2": "nu2", "L2": "l2", "T2": "t2", "Eps2": "eps2",
    "La2": "lambda2", "R2": "r2", "K1": "k1", "O1": "o1", "P1": "p1",
    "Q1": "q1", "J1": "j1", "Mf": "mf", "Mm": "mm", "Ssa": "ssa", "Sa": "sa",
    "Msqm": "msqm", "Mtm": "mtm", "M4": "m4", "MS4": "ms4",
}

# Public dive sites for the accuracy fixture (lat, lon).
VECTOR_SITES = [
    ("Bonaire", 12.10, -68.29), ("Cozumel", 20.35, -87.03),
    ("Escambron", 18.47, -66.09), ("Vieques", 18.10, -65.47),
    ("Koh Tao", 10.10, 99.84), ("Tulamben", -8.27, 115.59),
    ("Komodo", -8.55, 119.55), ("Gili", -8.35, 116.04),
    ("Raja Ampat", -0.55, 130.55), ("Cornwall", 50.07, -5.70),
    ("Nanaimo", 49.17, -123.94), ("Monterey", 36.62, -121.90),
    ("Cairns", -16.75, 145.98), ("Sharm el Sheikh", 27.85, 34.32),
    ("Malta", 36.05, 14.19), ("Roatan", 16.33, -86.53),
    ("Grand Cayman", 19.35, -81.38), ("Tenerife", 28.05, -16.73),
    ("Sipadan", 4.11, 118.63), ("Galapagos", -0.75, -90.30),
    ("Blue Hole", 17.32, -87.53), ("Maldives", 4.18, 73.52),
    ("Fiji Beqa", -18.40, 178.10), ("Lembeh", 1.45, 125.23),
    ("Anilao", 13.76, 120.92), ("Chuuk", 7.42, 151.78),
    ("Scapa Flow", 58.90, -3.20), ("Poor Knights", -35.47, 174.73),
    ("Ningaloo", -22.00, 113.90), ("Palau", 7.13, 134.22),
    ("Hurghada", 27.25, 33.83),
]


def lat_indices(step, count):
    return (LAT_MIN + 90) * NATIVE + np.arange(count) * step


def lon_indices(step, count):
    # Layer column j is centred on -180 + j*step/30 degrees; native starts at 0.
    return (180 * NATIVE + np.arange(count) * step) % (360 * NATIVE)


def load(fes_dir, name):
    ds = nc.Dataset(fes_dir / f"{FILE_NAMES[name]}_fes2022.nc")
    lat, lon = ds["lat"][:], ds["lon"][:]
    if len(lat) != 5401 or len(lon) != 10800 or lat[0] != -90 or lon[0] != 0:
        raise SystemExit(f"{name}: unexpected native grid")
    amp = np.ma.filled(ds["amplitude"][:].astype(np.float32), np.nan) / 100.0
    ph = np.ma.filled(ds["phase"][:].astype(np.float32), np.nan)
    ds.close()
    return amp, ph


def load_mask(fes_dir):
    return np.ma.filled(nc.Dataset(fes_dir / "mask_fes2022B.nc")["mask"][:], 2)


def coastal_band(mask):
    band = mask != 0  # extrapolated, land and lake cells seed the band
    for _ in range(BAND_STEPS):
        band = (band | np.roll(band, 1, 0) | np.roll(band, -1, 0)
                | np.roll(band, 1, 1) | np.roll(band, -1, 1))
    return band


def native_sample(amp, ph, lat, lon):
    """Complex bilinear interpolation on the native grid (the fixture oracle)."""
    y = (lat + 90) * NATIVE
    x = (lon % 360) * NATIVE
    r0, c0 = int(math.floor(y)), int(math.floor(x))
    fy, fx = y - r0, x - c0
    num, weights = 0j, 0.0
    for r, c, w in ((r0, c0, (1 - fy) * (1 - fx)), (r0, c0 + 1, (1 - fy) * fx),
                    (r0 + 1, c0, fy * (1 - fx)), (r0 + 1, c0 + 1, fy * fx)):
        a, p = amp[r, c % 10800], ph[r, c % 10800]
        if not (np.isfinite(a) and np.isfinite(p)):
            continue
        w = max(w, 1e-9)
        num += w * a * complex(math.cos(math.radians(p)), math.sin(math.radians(p)))
        weights += w
    if weights == 0:
        return None
    z = num / weights
    return {
        "amplitude": round(float(abs(z)), 6),
        "phase": round(float(math.degrees(math.atan2(z.imag, z.real)) % 360), 4),
    }


def extract(fes_dir):
    rows_c, cols_c = (LAT_MAX - LAT_MIN) * 10 + 1, 3600
    rows_g, cols_g = LAT_MAX - LAT_MIN + 1, 360
    li_c, lo_c = lat_indices(COASTAL_STEP, rows_c), lon_indices(COASTAL_STEP, cols_c)
    li_g, lo_g = lat_indices(GLOBAL_STEP, rows_g), lon_indices(GLOBAL_STEP, cols_g)
    count = len(fmt.CONSTITUENTS)

    amp_c = np.empty((rows_c, cols_c, count), np.float32)
    ph_c = np.empty_like(amp_c)
    amp_g = np.empty((rows_g, cols_g, count), np.float32)
    ph_g = np.empty_like(amp_g)
    vectors = {name: {} for name, _, _ in VECTOR_SITES}

    for k, name in enumerate(fmt.CONSTITUENTS):
        print(f"  {name}")
        amp, ph = load(fes_dir, name)
        amp_c[:, :, k] = amp[np.ix_(li_c, lo_c)]
        ph_c[:, :, k] = ph[np.ix_(li_c, lo_c)]
        amp_g[:, :, k] = amp[np.ix_(li_g, lo_g)]
        ph_g[:, :, k] = ph[np.ix_(li_g, lo_g)]
        for site, lat, lon in VECTOR_SITES:
            value = native_sample(amp, ph, lat, lon)
            if value is not None:
                vectors[site][name] = value
        del amp, ph

    mask = load_mask(fes_dir)
    # Lake cells hold zero amplitudes: storing them would chart a flat "tide"
    # on lakes and pull neighbouring coastal cells toward zero.
    present_c = (np.isfinite(amp_c[:, :, 0])
                 & coastal_band(mask)[np.ix_(li_c, lo_c)]
                 & (mask[np.ix_(li_c, lo_c)] != LAKE))
    amp_g[~np.isfinite(amp_g[:, :, 0]) | (mask[np.ix_(li_g, lo_g)] == LAKE)] = np.nan
    return amp_c, ph_c, present_c, amp_g, ph_g, vectors


def write(amp_c, ph_c, present_c, amp_g, ph_g, vectors):
    shutil.rmtree(OUT / "coastal", ignore_errors=True)
    (OUT / "coastal").mkdir(parents=True)
    rows_c, cols_c = present_c.shape
    tiles = []
    for tile_row in range((rows_c + TILE - 1) // TILE):
        for tile_col in range(cols_c // TILE):
            rs = slice(tile_row * TILE, min((tile_row + 1) * TILE, rows_c))
            cs = slice(tile_col * TILE, (tile_col + 1) * TILE)
            if not present_c[rs, cs].any():
                continue
            # Quantize per tile to keep peak memory near the float32 arrays.
            amp_mm, ph_cd = fmt.quantize(amp_c[rs, cs], ph_c[rs, cs])
            data = fmt.encode_tile(tile_row, tile_col, present_c[rs, cs],
                                   amp_mm, ph_cd)
            (OUT / "coastal" / f"tile_{tile_row}_{tile_col}.bin").write_bytes(data)
            tiles.append([tile_row, tile_col])

    g_amp_mm, g_ph_cd = fmt.quantize(amp_g, ph_g)
    (OUT / "global.bin").write_bytes(fmt.encode_global(g_amp_mm, g_ph_cd))
    fmt.write_manifest(
        OUT, model="FES2022b",
        extraction_date=datetime.date.today().isoformat(), band_km=30,
        coastal={"latMin": float(LAT_MIN), "lonMin": -180.0, "resolution": 0.1,
                 "rows": rows_c, "cols": cols_c},
        tile_size=TILE, tiles=tiles,
        global_={"latMin": float(LAT_MIN), "lonMin": -180.0, "resolution": 1.0,
                 "rows": amp_g.shape[0], "cols": amp_g.shape[1]},
    )
    VECTORS_OUT.write_text(json.dumps({
        "source": "FES2022b native 1/30 degree, complex bilinear interpolation",
        "sites": [{"name": name, "lat": lat, "lon": lon, "constituents": vectors[name]}
                  for name, lat, lon in VECTOR_SITES],
    }, indent=1) + "\n")
    size = sum(f.stat().st_size for f in OUT.rglob("*.bin"))
    print(f"Wrote {len(tiles)} tiles, {int(present_c.sum())} coastal cells, "
          f"{size / 1e6:.1f} MB")


def verify(fes_dir):
    manifest = json.loads((OUT / "manifest.json").read_text())
    li_c = lat_indices(COASTAL_STEP, manifest["coastal"]["rows"])
    lo_c = lon_indices(COASTAL_STEP, manifest["coastal"]["cols"])
    rng = random.Random(1)
    picks = []
    for tile_row, tile_col in rng.sample(manifest["coastal"]["tiles"], 40):
        data = (OUT / "coastal" / f"tile_{tile_row}_{tile_col}.bin").read_bytes()
        _, _, present, amp_mm, ph_cd = fmt.decode_tile(data)
        rows, cols = np.nonzero(present)
        for i in rng.sample(range(len(rows)), min(50, len(rows))):
            r, c = int(rows[i]), int(cols[i])
            picks.append((tile_row * TILE + r, tile_col * TILE + c,
                          amp_mm[r, c], ph_cd[r, c]))
    worst_amp, worst_ph = 0.0, 0.0
    for k, name in enumerate(fmt.CONSTITUENTS):
        amp, ph = load(fes_dir, name)
        for row, col, stored_amp, stored_ph in picks:
            a, p = amp[li_c[row], lo_c[col]], ph[li_c[row], lo_c[col]]
            if not np.isfinite(a):
                if stored_amp[k] != fmt.NO_DATA:
                    raise SystemExit(f"{name} {row},{col}: data where source has none")
                continue
            worst_amp = max(worst_amp, abs(stored_amp[k] / 1000.0 - a))
            diff = abs((stored_ph[k] / 100.0 - p + 180) % 360 - 180)
            worst_ph = max(worst_ph, diff)
        del amp, ph
    print(f"Checked {len(picks)} cells: worst amplitude {worst_amp * 1000:.2f} mm, "
          f"worst phase {worst_ph:.4f} deg")
    if worst_amp > 0.001 or worst_ph > 0.01:
        raise SystemExit("verification failed: error above the quantization bound")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fes-dir", type=Path, required=True)
    parser.add_argument("--verify", action="store_true",
                        help="check written tiles against the NetCDF source")
    args = parser.parse_args()
    fes_dir = args.fes_dir.expanduser()
    if args.verify:
        verify(fes_dir)
        return
    print("Loading constituents")
    write(*extract(fes_dir))


if __name__ == "__main__":
    main()
