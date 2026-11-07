"""Binary format of Submersion's bundled FES2022 tide grid.

Shared by extract_fes_grid.py (real data) and
write_fes_grid_test_fixtures.py (synthetic fixtures), so the Dart reader is
tested against the exact bytes the extractor writes.

Decoded layout, all little-endian. This is what the Dart reader holds in
memory and indexes directly:
  cell:   per constituent, int16 amplitude (mm, -1 = no data) then
          uint16 phase (hundredths of a degree, Greenwich lag)
  tile:   "SFT1", uint16 version 1, int16 tile row, int16 tile col,
          uint16 rows, uint16 cols, uint16 constituent count (16 bytes),
          occupancy bitmap (row-major, LSB first, ceil(rows*cols/8) bytes),
          uint32 populated-cells-before-row per row, packed populated cells
  global: "SFG1", uint16 version 1, uint16 rows, uint16 cols,
          uint16 constituent count (12 bytes), then every cell row-major

Packed files, as bundled (issue #4245). Each one is read on its own and
unpacks to exactly the decoded bytes above:
  tile:   "SFT2", uint16 version 2, then the decoded header's other ten
          bytes, then a zlib stream of the bitmap followed by the planes
  global: "SFG2", uint16 version 2, uint16 rows, uint16 cols,
          uint16 constituent count, then a zlib stream of the planes
  planes: the populated cells (every cell for the global layer) split into
          one amplitude plane per constituent, then one phase plane per
          constituent. Each value is stored as the difference from the
          previous cell in its plane (the first from 0), amplitudes modulo
          65536 and phases modulo 36000, folded to the signed range and
          zigzag encoded into a uint16. All low bytes come first, then all
          high bytes.
The row counts are not stored: the unpacker recomputes them from the bitmap.
"""

import json
import struct
import zlib
from pathlib import Path

import numpy as np

FORMAT_NAME = "submersion-fes-grid"
FORMAT_VERSION = 2
DECODED_VERSION = 1
TILE_MAGIC = b"SFT1"
GLOBAL_MAGIC = b"SFG1"
PACKED_VERSION = 2
PACKED_TILE_MAGIC = b"SFT2"
PACKED_GLOBAL_MAGIC = b"SFG2"
PHASE_MODULUS = 36000
NO_DATA = -1

# Per-cell field order. Must be a subset of the Dart engine's
# constituentSpeeds keys (guarded by fes_grid_accuracy_test.dart).
CONSTITUENTS = [
    "M2", "S2", "N2", "K2", "2N2", "Mu2", "Nu2", "L2", "T2", "Eps2", "La2",
    "R2", "K1", "O1", "P1", "Q1", "J1", "Mf", "Mm", "Ssa", "Sa", "Msqm",
    "Mtm", "M4", "MS4",
]


def quantize(amplitude_m, phase_deg):
    """Float arrays (..., C) in metres and degrees to (int16 mm, uint16 cdeg).

    A non-finite amplitude or phase marks that constituent as no data.
    """
    amp = np.asarray(amplitude_m, dtype=np.float64)
    ph = np.asarray(phase_deg, dtype=np.float64)
    missing = ~np.isfinite(amp) | ~np.isfinite(ph)
    amp_mm = np.rint(np.nan_to_num(amp) * 1000.0)
    if np.any(amp_mm[~missing] > 32767) or np.any(amp_mm[~missing] < 0):
        raise ValueError("amplitude outside the int16 millimetre range")
    amp_mm = np.where(missing, NO_DATA, amp_mm).astype(np.int16)
    ph_cd = np.rint(np.mod(np.nan_to_num(ph), 360.0) * 100.0).astype(np.int64) % 36000
    ph_cd = np.where(missing, 0, ph_cd).astype(np.uint16)
    return amp_mm, ph_cd


def _encode_cells(amp_mm, ph_cd):
    n, c = amp_mm.shape
    out = np.empty((n, c, 2), dtype="<u2")
    out[:, :, 0] = amp_mm.astype("<i2").view("<u2")
    out[:, :, 1] = ph_cd.astype("<u2")
    return out.tobytes()


def encode_tile(tile_row, tile_col, present, amp_mm, ph_cd):
    """present: bool (rows, cols). amp_mm, ph_cd: (rows, cols, C)."""
    rows, cols = present.shape
    count = amp_mm.shape[2]
    header = TILE_MAGIC + struct.pack(
        "<HhhHHH", DECODED_VERSION, tile_row, tile_col, rows, cols, count
    )
    bitmap = np.packbits(present.reshape(-1), bitorder="little").tobytes()
    per_row = present.sum(axis=1).astype(np.int64)
    before = np.concatenate([[0], np.cumsum(per_row)[:-1]]).astype("<u4").tobytes()
    return header + bitmap + before + _encode_cells(amp_mm[present], ph_cd[present])


def decode_tile(data):
    """Inverse of encode_tile: (tile_row, tile_col, present, amp_mm, ph_cd)."""
    if data[:4] != TILE_MAGIC:
        raise ValueError("not an FES tile")
    _, tile_row, tile_col, rows, cols, count = struct.unpack_from("<HhhHHH", data, 4)
    bitmap_len = (rows * cols + 7) // 8
    bits = np.frombuffer(data, dtype=np.uint8, count=bitmap_len, offset=16)
    present = np.unpackbits(bits, bitorder="little")[: rows * cols].astype(bool)
    present = present.reshape(rows, cols)
    cells_offset = 16 + bitmap_len + rows * 4
    n = int(present.sum())
    raw = np.frombuffer(data, dtype="<u2", count=n * count * 2, offset=cells_offset)
    raw = raw.reshape(n, count, 2)
    amp_mm = np.full((rows, cols, count), NO_DATA, dtype=np.int16)
    ph_cd = np.zeros((rows, cols, count), dtype=np.uint16)
    amp_mm[present] = raw[:, :, 0].view("<i2")
    ph_cd[present] = raw[:, :, 1]
    return tile_row, tile_col, present, amp_mm, ph_cd


def encode_global(amp_mm, ph_cd):
    """amp_mm, ph_cd: (rows, cols, C); a no-data cell has every amplitude -1."""
    rows, cols, count = amp_mm.shape
    header = GLOBAL_MAGIC + struct.pack("<HHHH", DECODED_VERSION, rows, cols, count)
    return header + _encode_cells(amp_mm.reshape(-1, count), ph_cd.reshape(-1, count))


def _pack_planes(cells):
    """cells: uint16 (n, C, 2) in the decoded order -> shuffled plane bytes."""
    planes = np.concatenate([cells[:, :, 0].T, cells[:, :, 1].T]).astype(np.int64)
    count = cells.shape[1]
    if np.any(planes[count:] >= PHASE_MODULUS):
        raise ValueError("phase outside 0 to 359.99 degrees cannot be packed")
    delta = np.diff(planes, axis=1, prepend=0)
    amp = delta[:count] % 65536
    signed = np.concatenate([
        np.where(amp >= 32768, amp - 65536, amp),
        (delta[count:] + PHASE_MODULUS // 2) % PHASE_MODULUS - PHASE_MODULUS // 2,
    ])
    zigzag = ((signed << 1) ^ (signed >> 63)) & 0xFFFF
    return ((zigzag & 0xFF).astype(np.uint8).tobytes()
            + (zigzag >> 8).astype(np.uint8).tobytes())


def _unpack_planes(data, n, count):
    """Inverse of _pack_planes: uint16 (n, C, 2)."""
    size = 2 * count * n
    lo = np.frombuffer(data, dtype=np.uint8, count=size).astype(np.int64)
    hi = np.frombuffer(data, dtype=np.uint8, count=size, offset=size)
    zigzag = (lo | (hi.astype(np.int64) << 8)).reshape(2 * count, n)
    signed = (zigzag >> 1) ^ -(zigzag & 1)
    planes = np.cumsum(signed, axis=1)
    planes[:count] %= 65536
    planes[count:] %= PHASE_MODULUS
    cells = np.empty((n, count, 2), dtype="<u2")
    cells[:, :, 0] = planes[:count].T
    cells[:, :, 1] = planes[count:].T
    return cells


def _cells_view(data, offset, n, count):
    return np.frombuffer(data, dtype="<u2", count=n * count * 2,
                         offset=offset).reshape(n, count, 2)


def pack_tile(decoded):
    """Decoded tile bytes (encode_tile's output) to the packed tile."""
    if decoded[:4] != TILE_MAGIC:
        raise ValueError("not a decoded FES tile")
    _, _, _, rows, cols, count = struct.unpack_from("<HhhHHH", decoded, 4)
    bitmap_len = (rows * cols + 7) // 8
    bitmap = decoded[16:16 + bitmap_len]
    n = int(np.unpackbits(np.frombuffer(bitmap, np.uint8),
                          bitorder="little")[: rows * cols].sum())
    cells = _cells_view(decoded, 16 + bitmap_len + rows * 4, n, count)
    header = PACKED_TILE_MAGIC + struct.pack("<H", PACKED_VERSION) + decoded[6:16]
    return header + zlib.compress(bitmap + _pack_planes(cells), 9)


def unpack_tile(packed):
    """Inverse of pack_tile: the decoded tile bytes."""
    if packed[:4] != PACKED_TILE_MAGIC:
        raise ValueError("not a packed FES tile")
    tile_row, tile_col, rows, cols, count = struct.unpack_from("<hhHHH", packed, 6)
    body = zlib.decompress(packed[16:])
    bitmap_len = (rows * cols + 7) // 8
    bits = np.unpackbits(np.frombuffer(body, np.uint8, count=bitmap_len),
                         bitorder="little")[: rows * cols].astype(bool)
    present = bits.reshape(rows, cols)
    per_row = present.sum(axis=1).astype(np.int64)
    before = np.concatenate([[0], np.cumsum(per_row)[:-1]]).astype("<u4")
    cells = _unpack_planes(body[bitmap_len:], int(per_row.sum()), count)
    header = TILE_MAGIC + struct.pack("<HhhHHH", DECODED_VERSION, tile_row,
                                      tile_col, rows, cols, count)
    return header + body[:bitmap_len] + before.tobytes() + cells.tobytes()


def pack_global(decoded):
    """Decoded global layer bytes (encode_global's output) to the packed one."""
    if decoded[:4] != GLOBAL_MAGIC:
        raise ValueError("not a decoded FES global layer")
    _, rows, cols, count = struct.unpack_from("<HHHH", decoded, 4)
    cells = _cells_view(decoded, 12, rows * cols, count)
    header = PACKED_GLOBAL_MAGIC + struct.pack("<HHHH", PACKED_VERSION, rows,
                                               cols, count)
    return header + zlib.compress(_pack_planes(cells), 9)


def unpack_global(packed):
    """Inverse of pack_global: the decoded global layer bytes."""
    if packed[:4] != PACKED_GLOBAL_MAGIC:
        raise ValueError("not a packed FES global layer")
    _, rows, cols, count = struct.unpack_from("<HHHH", packed, 4)
    cells = _unpack_planes(zlib.decompress(packed[12:]), rows * cols, count)
    return (GLOBAL_MAGIC + struct.pack("<HHHH", DECODED_VERSION, rows, cols, count)
            + cells.tobytes())


def write_manifest(root: Path, *, model, extraction_date, band_km, coastal,
                   tile_size, tiles, global_, constituents=CONSTITUENTS):
    manifest = {
        "format": FORMAT_NAME,
        "version": FORMAT_VERSION,
        "model": model,
        "extractionDate": extraction_date,
        "bandKm": band_km,
        "constituents": list(constituents),
        "coastal": {**coastal, "tileSize": tile_size, "tiles": tiles},
        "global": global_,
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
