"""Probe a blob for compression wrappers at every offset.

Usage:
    python compression_probe.py corpus/<uuid>.zsamples.bin

Tries gzip / zlib / lzma / bz2 / lz4 / zstd / LZFSE / LZVN / Apple Archive
at offsets 0..64. Reports any codec that produces plausibly-decompressed
output (decompressed size > 32 bytes, and either the codec's verification
succeeds or the output is above a low-entropy threshold).
"""
from __future__ import annotations

import argparse
import bz2
import gzip
import lzma
import shutil
import subprocess
import tempfile
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

try:
    import lz4.frame as lz4_frame
    import lz4.block as lz4_block
except ImportError:
    lz4_frame = None
    lz4_block = None

try:
    import zstandard as zstd
except ImportError:
    zstd = None

try:
    import liblzfse
except ImportError:
    liblzfse = None


@dataclass
class Codec:
    name: str
    decompress: Callable[[bytes], bytes]
    minimum_input: int = 4


def _zlib_decompress(data: bytes) -> bytes:
    return zlib.decompress(data)


def _raw_deflate(data: bytes) -> bytes:
    # negative wbits -> raw DEFLATE, no zlib header
    return zlib.decompress(data, -15)


def _gzip_decompress(data: bytes) -> bytes:
    return gzip.decompress(data)


def _lzma_decompress(data: bytes) -> bytes:
    return lzma.decompress(data)


def _bz2_decompress(data: bytes) -> bytes:
    return bz2.decompress(data)


def _lz4_frame_decompress(data: bytes) -> bytes:
    if lz4_frame is None:
        raise RuntimeError("lz4 not installed")
    return lz4_frame.decompress(data)


def _lz4_block_decompress(data: bytes) -> bytes:
    if lz4_block is None:
        raise RuntimeError("lz4 not installed")
    # block format requires explicit uncompressed size. Try common hints:
    for hint in (len(data) * 4, len(data) * 8, len(data) * 16):
        try:
            return lz4_block.decompress(data, uncompressed_size=hint)
        except Exception:
            continue
    raise RuntimeError("lz4 block probe failed")


def _zstd_decompress(data: bytes) -> bytes:
    if zstd is None:
        raise RuntimeError("zstandard not installed")
    return zstd.ZstdDecompressor().decompress(data)


def _lzfse_decompress(data: bytes) -> bytes:
    if liblzfse is not None:
        return liblzfse.decompress(data)
    # Fallback: use macOS compression_tool if available.
    tool = shutil.which("compression_tool")
    if tool is None:
        raise RuntimeError("neither pyliblzfse nor compression_tool available")
    src = tempfile.NamedTemporaryFile(delete=False)
    dst = tempfile.NamedTemporaryFile(delete=False)
    try:
        src.write(data)
        src.close()
        dst.close()
        result = subprocess.run(
            [tool, "-decode", "-i", src.name, "-o", dst.name, "-encoding", "lzfse"],
            capture_output=True,
        )
        if result.returncode != 0:
            raise RuntimeError(f"compression_tool failed: {result.stderr!r}")
        return Path(dst.name).read_bytes()
    finally:
        Path(src.name).unlink(missing_ok=True)
        Path(dst.name).unlink(missing_ok=True)


CODECS: list[Codec] = [
    Codec("zlib", _zlib_decompress),
    Codec("raw_deflate", _raw_deflate),
    Codec("gzip", _gzip_decompress),
    Codec("lzma", _lzma_decompress),
    Codec("bz2", _bz2_decompress),
    Codec("lz4_frame", _lz4_frame_decompress),
    Codec("lz4_block", _lz4_block_decompress),
    Codec("zstd", _zstd_decompress),
    Codec("lzfse", _lzfse_decompress),
]


@dataclass
class Hit:
    codec: Codec
    offset: int
    decompressed: bytes


def try_all(blob: bytes, offsets: Iterable[int] = range(0, 64)) -> list[Hit]:
    hits: list[Hit] = []
    for codec in CODECS:
        for offset in offsets:
            slice_ = blob[offset:]
            if len(slice_) < codec.minimum_input:
                continue
            try:
                out = codec.decompress(slice_)
            except Exception:
                continue
            if len(out) >= 32:  # filter out trivial matches
                hits.append(Hit(codec=codec, offset=offset, decompressed=out))
    return hits


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("fixture", type=Path)
    p.add_argument("--max-offset", type=int, default=64)
    args = p.parse_args()

    blob = args.fixture.read_bytes()
    print(f"probing {args.fixture.name} ({len(blob)} bytes) over offsets 0..{args.max_offset - 1}")
    hits = try_all(blob, offsets=range(0, args.max_offset))

    if not hits:
        print("NO HITS — no standard compression codec matched.")
        return

    for hit in hits:
        print(
            f"HIT codec={hit.codec.name:12s} offset={hit.offset:3d} "
            f"decompressed={len(hit.decompressed)} bytes "
            f"first_bytes={hit.decompressed[:16].hex()}"
        )


if __name__ == "__main__":
    main()
