"""Exploratory inspector for ZSAMPLES blobs.

Run: python blob_inspect.py corpus/<uuid>.zsamples.bin
"""
from __future__ import annotations

import argparse
import math
import struct
from collections import Counter
from pathlib import Path


def shannon_entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = Counter(data)
    total = len(data)
    return -sum((c / total) * math.log2(c / total) for c in counts.values())


def find_repeating_stride(data: bytes, min_stride: int = 2, max_stride: int = 64) -> int | None:
    """Return the highest-scoring stride S in [min_stride, max_stride] where
    byte[i] and byte[i+S] are equal for >90% of positions; ties broken in
    favor of the smaller stride. Returns None if no stride exceeds 90%."""
    best_stride: int | None = None
    best_score = 0.0
    for stride in range(min_stride, max_stride + 1):
        if len(data) < stride * 4:
            break
        matches = sum(1 for i in range(len(data) - stride) if data[i] == data[i + stride])
        score = matches / (len(data) - stride)
        if score > 0.9 and score > best_score:
            best_score = score
            best_stride = stride
    return best_stride


def interpret_offset(data: bytes, offset: int) -> dict:
    """Return plausible numeric interpretations of 1/2/4/8 bytes at offset."""
    out: dict = {}
    if offset + 1 <= len(data):
        out["u8"] = data[offset]
    if offset + 2 <= len(data):
        out["u16_le"] = struct.unpack_from("<H", data, offset)[0]
        out["u16_be"] = struct.unpack_from(">H", data, offset)[0]
    if offset + 4 <= len(data):
        out["u32_le"] = struct.unpack_from("<I", data, offset)[0]
        out["u32_be"] = struct.unpack_from(">I", data, offset)[0]
        out["f32_le"] = struct.unpack_from("<f", data, offset)[0]
        out["f32_be"] = struct.unpack_from(">f", data, offset)[0]
    if offset + 8 <= len(data):
        out["u64_le"] = struct.unpack_from("<Q", data, offset)[0]
        out["u64_be"] = struct.unpack_from(">Q", data, offset)[0]
        out["f64_le"] = struct.unpack_from("<d", data, offset)[0]
        out["f64_be"] = struct.unpack_from(">d", data, offset)[0]
    return out


def hex_dump_line(data: bytes, offset: int) -> str:
    """Format a single 16-byte line of hex dump output."""
    chunk = data[offset : offset + 16]
    hex_part = " ".join(f"{b:02x}" for b in chunk)
    ascii_part = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
    return f"{offset:08x}  {hex_part:<47s}  {ascii_part}"


def dump(path: Path, limit: int = 256) -> None:
    data = path.read_bytes()
    print(f"=== {path.name} ({len(data)} bytes) ===")
    print(f"entropy: {shannon_entropy(data):.3f} bits/byte")

    stride = find_repeating_stride(data[8:])  # skip 8-byte header
    print(f"stride (post-header): {stride}")

    print("\n-- first {} bytes --".format(min(limit, len(data))))
    for off in range(0, min(limit, len(data)), 16):
        print(hex_dump_line(data, off))

    print("\n-- offset interpretations (first 16 bytes) --")
    for off in range(0, min(16, len(data))):
        print(f"  [{off:02d}]  {interpret_offset(data, off)}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("fixture", type=Path)
    p.add_argument("--limit", type=int, default=256)
    args = p.parse_args()
    dump(args.fixture, limit=args.limit)


if __name__ == "__main__":
    main()
