# MacDive ZSAMPLES Profile Decoding — Phase 1 Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reverse-engineer MacDive's proprietary `ZDIVE.ZSAMPLES` binary format well enough to produce a written specification that a future implementer can code against, or prove that the format is not decodable within the timebox and pivot to the ZRAWDATA/libdivecomputer fallback.

**Architecture:** Throwaway Python scripts in `scripts/reverse_engineering/zsamples/` that (a) extract paired `ZSAMPLES` blobs and UDDF ground-truth profiles from the sample data, (b) probe for compression wrappers, (c) score candidate decoders against the UDDF truth. No production code touched in this plan — Phase 2 (if go) covers that in a separate follow-up plan produced by Task 9.

**Tech Stack:** Python 3.11+, `pyliblzfse` (optional; falls back to `compression_tool` CLI on macOS), `lz4`, `zstandard`, `lxml`, `sqlite3` (stdlib).

**Dependencies:** PR #256 (`feature/macdive-sqlite`) open on GitHub. This work branches from that branch, not `main`, so the format spec and Phase 2 plan can land as a stacked PR.

**Sample data (already in repo):**
- `scripts/sample_data/MacDive.sqlite` — 540 dives, 350 with non-null `ZSAMPLES`.
- `scripts/sample_data/Apr 4 no iPad sync.uddf` — 540 dives in UDDF, matched to the SQLite set by UUID (`ZDIVE.ZUUID` ↔ UDDF `@id`).
- `scripts/sample_data/Apr 4 no iPad Mini sync.xml` — MacDive native XML, same 540 dives; secondary cross-reference source if UDDF has gaps.

**Scope note:** This is the Phase 1 plan from spec `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md`. Phase 2 (the Dart decoder implementation) is not planned here because its task content depends on what Phase 1 reveals about the format. Task 9 produces the Phase 2 plan once the format spec exists.

---

## File Structure

| File | Role | New / Modified |
|---|---|---|
| `scripts/reverse_engineering/zsamples/README.md` | Orientation for anyone reading the spike later. | Created |
| `scripts/reverse_engineering/zsamples/requirements.txt` | Python dependencies for the spike. | Created |
| `scripts/reverse_engineering/zsamples/.gitignore` | Excludes `corpus/` (contains user dive data, do not commit). | Created |
| `scripts/reverse_engineering/zsamples/extract_corpus.py` | Reads `MacDive.sqlite` + UDDF, emits paired `<uuid>.zsamples.bin` + `<uuid>.uddf.json` fixtures under `corpus/`. | Created |
| `scripts/reverse_engineering/zsamples/blob_inspect.py` | Pretty-prints a blob: hex dump, field-type guesses at every offset, entropy-per-window. Named `blob_inspect` to avoid shadowing Python's stdlib `inspect`. | Created |
| `scripts/reverse_engineering/zsamples/compression_probe.py` | Attempts gzip / zlib / lzma / bz2 / lz4 / zstd / LZFSE / LZVN / Apple Archive at offsets 0..64. | Created |
| `scripts/reverse_engineering/zsamples/differ.py` | Given a hypothesis callable and a fixture pair, returns a score dict vs the UDDF ground truth. | Created |
| `scripts/reverse_engineering/zsamples/batch_score.py` | Runs a hypothesis across the whole corpus, emits a score histogram + per-dive CSV. | Created |
| `scripts/reverse_engineering/zsamples/test_zsamples_spike.py` | Pytest tests for all of the above. | Created |
| `scripts/reverse_engineering/zsamples/hypotheses/__init__.py` | Package for candidate decoder hypotheses (one file per hypothesis). | Created |
| `scripts/reverse_engineering/zsamples/hypotheses/h1_compression_wrapper.py` | Hypothesis 1: ZSAMPLES is a compressed wrapper around a simple record stream. | Created |
| `scripts/reverse_engineering/zsamples/hypotheses/h2_fixed_width.py` | Hypothesis 2: fixed-width sample records after the 8-byte header. | Created |
| `scripts/reverse_engineering/zsamples/hypotheses/h3_tlv_stream.py` | Hypothesis 3: typed record stream (TLV). | Created |
| `scripts/reverse_engineering/zsamples/hypotheses/h4_vendor_frames.py` | Hypothesis 4: container of vendor-specific dive-computer frames. | Created |
| `docs/import-formats/macdive-zsamples.md` | The output of Phase 1: the written format spec. Either describes the cracked format in full, or documents the investigation and the no-go decision. | Created |
| `docs/superpowers/plans/2026-04-21-macdive-sqlite-import.md` | Append a tail link to the new Phase 1 plan and the resulting Phase 2 plan (or no-go doc). | Modified |
| `docs/superpowers/plans/2026-04-23-macdive-zsamples-phase-2-decoder.md` OR `docs/superpowers/specs/2026-04-23-macdive-zsamples-nogo.md` | Task 9's output. Written once the spike concludes. | Created (Task 9) |

---

## Task 1: Branch and worktree setup

**Files:**
- No files created in this task.

- [ ] **Step 1: From the main working tree, create a worktree on a new branch based on `feature/macdive-sqlite`**

Run:
```bash
git fetch origin
git worktree add -b feature/macdive-zsamples-phase-1 .worktrees/macdive-zsamples-phase-1 origin/feature/macdive-sqlite
```

Expected: a new directory `.worktrees/macdive-zsamples-phase-1/` exists and is on branch `feature/macdive-zsamples-phase-1` with `feature/macdive-sqlite`'s tip as its initial HEAD.

- [ ] **Step 2: Initialize submodules and Flutter deps in the worktree**

Run:
```bash
cd .worktrees/macdive-zsamples-phase-1
git submodule update --init --recursive
flutter pub get
```

Expected: submodules populate (libdivecomputer is large, this is fine), `flutter pub get` completes without errors.

- [ ] **Step 3: Verify the sample data is present in the worktree**

Run:
```bash
ls scripts/sample_data/MacDive.sqlite "scripts/sample_data/Apr 4 no iPad sync.uddf"
```

Expected: both files listed.

- [ ] **Step 4: No commit — this is a setup-only task**

---

## Task 2: Scaffold the spike directory

**Files:**
- Create: `scripts/reverse_engineering/zsamples/README.md`
- Create: `scripts/reverse_engineering/zsamples/requirements.txt`
- Create: `scripts/reverse_engineering/zsamples/.gitignore`

- [ ] **Step 1: Create the directory and `.gitignore`**

File `scripts/reverse_engineering/zsamples/.gitignore`:
```
corpus/
__pycache__/
*.pyc
.venv/
```

- [ ] **Step 2: Create `requirements.txt`**

File `scripts/reverse_engineering/zsamples/requirements.txt`:
```
pytest>=8.0
lxml>=5.0
lz4>=4.3
zstandard>=0.22
pyliblzfse>=0.4 ; platform_system == "Darwin"
```

The `pyliblzfse` marker restricts it to macOS where `liblzfse` is available via Homebrew (`brew install lzfse`). On Linux the `compression_probe.py` script must gracefully skip LZFSE.

- [ ] **Step 3: Create `README.md`**

File `scripts/reverse_engineering/zsamples/README.md`:
````markdown
# ZSAMPLES reverse-engineering spike

Throwaway tooling for decoding MacDive's proprietary `ZDIVE.ZSAMPLES`
binary profile format. Output is a written format spec at
`docs/import-formats/macdive-zsamples.md` (or a no-go note).

See `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md`
for the full investigation plan.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# On macOS for LZFSE:
brew install lzfse
```

## Workflow

1. `python extract_corpus.py` — builds `corpus/` from `scripts/sample_data/`.
2. `python blob_inspect.py corpus/<uuid>.zsamples.bin` — human exploration.
3. `python compression_probe.py corpus/<uuid>.zsamples.bin` — Hypothesis 1.
4. `python batch_score.py hypotheses.h2_fixed_width` — score a hypothesis.
5. Iterate hypotheses, commit findings to `docs/import-formats/macdive-zsamples.md`.

## Running tests

```bash
cd scripts/reverse_engineering/zsamples
pytest -v
```

## Do not commit `corpus/`

It contains real user dive data from the sample SQLite.
The directory is gitignored.
````

- [ ] **Step 4: Verify files exist**

Run:
```bash
ls -la scripts/reverse_engineering/zsamples/
```

Expected: three files listed (README.md, requirements.txt, .gitignore).

- [ ] **Step 5: Commit**

```bash
git add scripts/reverse_engineering/zsamples/
git commit -m "chore(zsamples): scaffold reverse-engineering spike directory"
```

---

## Task 3: Corpus extractor

**Files:**
- Create: `scripts/reverse_engineering/zsamples/extract_corpus.py`
- Create: `scripts/reverse_engineering/zsamples/test_zsamples_spike.py`

- [ ] **Step 1: Write the failing test**

File `scripts/reverse_engineering/zsamples/test_zsamples_spike.py`:
```python
"""Tests for the ZSAMPLES reverse-engineering spike tooling."""
from pathlib import Path
import json

import pytest

from extract_corpus import extract_corpus, UddfProfile


REPO_ROOT = Path(__file__).resolve().parents[3]
SAMPLE_DB = REPO_ROOT / "scripts/sample_data/MacDive.sqlite"
SAMPLE_UDDF = REPO_ROOT / "scripts/sample_data/Apr 4 no iPad sync.uddf"


def test_extract_corpus_produces_paired_fixtures(tmp_path):
    """Every dive with non-null ZSAMPLES and a UDDF counterpart yields a pair."""
    out_dir = tmp_path / "corpus"

    summary = extract_corpus(SAMPLE_DB, SAMPLE_UDDF, out_dir)

    assert summary.total_dives_sqlite == 540
    assert summary.dives_with_zsamples >= 300  # spec observed 350
    assert summary.paired_fixtures == summary.dives_with_zsamples_in_uddf
    assert summary.paired_fixtures > 0

    any_pair = next(iter(summary.uuids_paired))
    bin_path = out_dir / f"{any_pair}.zsamples.bin"
    json_path = out_dir / f"{any_pair}.uddf.json"
    assert bin_path.exists(), "ZSAMPLES blob file missing"
    assert json_path.exists(), "UDDF ground-truth JSON missing"

    with json_path.open() as f:
        profile = json.load(f)
    assert isinstance(profile["samples"], list)
    assert len(profile["samples"]) > 0
    assert "time_s" in profile["samples"][0]
    assert "depth_m" in profile["samples"][0]


def test_uddf_profile_parse_returns_monotonic_timestamps():
    """Sanity check: UDDF parser gives us ordered samples."""
    profile = UddfProfile.from_uddf_file(
        SAMPLE_UDDF,
        uuid_filter=None,  # parse any one dive
        first_only=True,
    )
    assert profile is not None
    times = [s["time_s"] for s in profile.samples]
    assert times == sorted(times), "Sample times should be monotonically non-decreasing"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
cd scripts/reverse_engineering/zsamples
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest test_zsamples_spike.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'extract_corpus'`.

- [ ] **Step 3: Implement the extractor**

File `scripts/reverse_engineering/zsamples/extract_corpus.py`:
```python
"""Extract paired (ZSAMPLES, UDDF ground-truth) fixtures from sample data.

Usage:
    python extract_corpus.py [--db PATH] [--uddf PATH] [--out DIR]

Output:
    corpus/<uuid>.zsamples.bin  — raw bytes from ZDIVE.ZSAMPLES
    corpus/<uuid>.uddf.json     — {"uuid": ..., "samples": [{"time_s": ..., "depth_m": ..., ...}]}
    corpus/manifest.json        — summary of pairings
"""
from __future__ import annotations

import argparse
import json
import sqlite3
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Iterable

from lxml import etree


UDDF_NS = {"u": "http://www.streit.cc/uddf/3.2/"}


@dataclass
class UddfProfile:
    uuid: str
    samples: list[dict]

    @classmethod
    def from_uddf_file(
        cls,
        path: Path,
        uuid_filter: set[str] | None,
        first_only: bool = False,
    ) -> "UddfProfile | dict[str, UddfProfile] | None":
        """Parse a UDDF file and return profiles keyed by dive id.

        If `first_only` is True, return the first profile found (test use).
        """
        results: dict[str, UddfProfile] = {}
        # UDDF files can be large; use iterparse for memory efficiency.
        context = etree.iterparse(str(path), events=("end",), tag=f"{{{UDDF_NS['u']}}}dive")
        for _, dive_el in context:
            dive_id = dive_el.get("id", "")
            if uuid_filter is not None and dive_id not in uuid_filter and not first_only:
                dive_el.clear()
                continue

            samples: list[dict] = []
            for wp in dive_el.iterfind(".//u:waypoint", UDDF_NS):
                sample = _waypoint_to_sample(wp)
                if sample is not None:
                    samples.append(sample)

            if samples:
                profile = cls(uuid=dive_id, samples=samples)
                if first_only:
                    dive_el.clear()
                    return profile
                results[dive_id] = profile

            dive_el.clear()

        if first_only:
            return None
        return results


def _waypoint_to_sample(wp) -> dict | None:
    """Convert a single <waypoint> element to a sample dict."""
    # UDDF waypoint children: <divetime>sec</divetime>, <depth>m</depth>,
    # <temperature>K</temperature>, <tankpressure>Pa</tankpressure>, etc.
    time_el = wp.find("u:divetime", UDDF_NS)
    depth_el = wp.find("u:depth", UDDF_NS)
    if time_el is None or depth_el is None:
        return None
    sample: dict = {
        "time_s": int(float(time_el.text)),
        "depth_m": float(depth_el.text),
    }
    temp_el = wp.find("u:temperature", UDDF_NS)
    if temp_el is not None:
        # UDDF temperature is in Kelvin.
        sample["temperature_c"] = float(temp_el.text) - 273.15
    pressure_el = wp.find("u:tankpressure", UDDF_NS)
    if pressure_el is not None:
        # UDDF pressure in Pa -> bar.
        sample["pressure_bar"] = float(pressure_el.text) / 1e5
    return sample


@dataclass
class CorpusSummary:
    total_dives_sqlite: int = 0
    dives_with_zsamples: int = 0
    dives_with_zsamples_in_uddf: int = 0
    paired_fixtures: int = 0
    uuids_paired: list[str] = field(default_factory=list)


def extract_corpus(db_path: Path, uddf_path: Path, out_dir: Path) -> CorpusSummary:
    out_dir.mkdir(parents=True, exist_ok=True)
    summary = CorpusSummary()

    # Parse UDDF once, keyed by uuid.
    uddf_profiles = UddfProfile.from_uddf_file(uddf_path, uuid_filter=None)
    assert isinstance(uddf_profiles, dict)

    # Read SQLite.
    with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as conn:
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM ZDIVE")
        summary.total_dives_sqlite = cur.fetchone()[0]

        cur.execute("SELECT ZUUID, ZSAMPLES FROM ZDIVE WHERE ZSAMPLES IS NOT NULL")
        for uuid, blob in cur.fetchall():
            summary.dives_with_zsamples += 1
            if uuid in uddf_profiles:
                summary.dives_with_zsamples_in_uddf += 1
                (out_dir / f"{uuid}.zsamples.bin").write_bytes(blob)
                json_payload = {
                    "uuid": uuid,
                    "samples": uddf_profiles[uuid].samples,
                }
                with (out_dir / f"{uuid}.uddf.json").open("w") as f:
                    json.dump(json_payload, f, indent=2)
                summary.paired_fixtures += 1
                summary.uuids_paired.append(uuid)

    manifest = out_dir / "manifest.json"
    with manifest.open("w") as f:
        json.dump(asdict(summary), f, indent=2)

    return summary


def main() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=repo_root / "scripts/sample_data/MacDive.sqlite")
    parser.add_argument("--uddf", type=Path, default=repo_root / "scripts/sample_data/Apr 4 no iPad sync.uddf")
    parser.add_argument("--out", type=Path, default=Path(__file__).parent / "corpus")
    args = parser.parse_args()

    summary = extract_corpus(args.db, args.uddf, args.out)
    print(json.dumps(asdict(summary), indent=2, default=str))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
pytest test_zsamples_spike.py -v
```

Expected: both tests PASS. If UDDF namespace lookup differs from what's in the file, adjust `UDDF_NS` — check the actual xmlns in `Apr 4 no iPad sync.uddf` via `head -c 300`.

- [ ] **Step 5: Run the extractor on the sample data and eyeball the output**

Run:
```bash
python extract_corpus.py
ls corpus/ | head -5
cat corpus/manifest.json
```

Expected: `corpus/` contains many `.zsamples.bin` + `.uddf.json` pairs plus `manifest.json`. Manifest reports `paired_fixtures` in the low-to-mid hundreds.

- [ ] **Step 6: Commit**

```bash
git add scripts/reverse_engineering/zsamples/extract_corpus.py \
        scripts/reverse_engineering/zsamples/test_zsamples_spike.py
git commit -m "feat(zsamples): corpus extractor pairing ZSAMPLES with UDDF ground truth"
```

Note: `corpus/` contents are gitignored.

---

## Task 4: Inspector script

**Files:**
- Create: `scripts/reverse_engineering/zsamples/blob_inspect.py` (named this way to avoid shadowing Python's stdlib `inspect` module)
- Modify: `scripts/reverse_engineering/zsamples/test_zsamples_spike.py` (append)

- [ ] **Step 1: Write the failing tests (append to existing test file)**

Append to `test_zsamples_spike.py`:
```python
from blob_inspect import (
    shannon_entropy,
    find_repeating_stride,
    hex_dump_line,
    interpret_offset,
)


def test_shannon_entropy_uniform_bytes_is_max():
    data = bytes(range(256))
    assert abs(shannon_entropy(data) - 8.0) < 0.01


def test_shannon_entropy_zeros_is_zero():
    assert shannon_entropy(b"\x00" * 1024) == 0.0


def test_find_repeating_stride_detects_period():
    data = (b"\x01\x02\x03\x04" * 100)
    stride = find_repeating_stride(data, min_stride=2, max_stride=8)
    assert stride == 4


def test_find_repeating_stride_returns_none_for_random():
    import os
    stride = find_repeating_stride(os.urandom(1024), min_stride=2, max_stride=16)
    assert stride is None


def test_interpret_offset_decodes_little_endian_uint32():
    # 0x12345678 little-endian at offset 0 of this buffer:
    data = bytes([0x78, 0x56, 0x34, 0x12, 0, 0, 0, 0])
    interp = interpret_offset(data, 0)
    assert interp["u32_le"] == 0x12345678


def test_hex_dump_line_formats_16_bytes():
    line = hex_dump_line(bytes(range(16)), offset=0)
    assert "00 01 02 03" in line
    assert "0c 0d 0e 0f" in line
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
pytest test_zsamples_spike.py -v -k "entropy or stride or interpret or hex_dump"
```

Expected: FAIL with `ModuleNotFoundError: No module named 'blob_inspect'`.

- [ ] **Step 3: Implement `blob_inspect.py`**

File `scripts/reverse_engineering/zsamples/blob_inspect.py`:
```python
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
    """Return the smallest stride S in [min_stride, max_stride] where byte[i]
    and byte[i+S] are equal for most i; or None if no strong periodicity."""
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
    if offset + 8 <= len(data):
        out["u64_le"] = struct.unpack_from("<Q", data, offset)[0]
        out["f64_le"] = struct.unpack_from("<d", data, offset)[0]
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
pytest test_zsamples_spike.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Smoke-test against a real fixture**

Run:
```bash
python blob_inspect.py corpus/$(ls corpus/ | grep '\.zsamples\.bin$' | head -1)
```

Expected: prints entropy, stride (maybe), 16 lines of hex, 16 lines of offset interpretations. Record the entropy value — high entropy (>7.5) is a strong signal for compression or encryption.

- [ ] **Step 6: Commit**

```bash
git add scripts/reverse_engineering/zsamples/blob_inspect.py \
        scripts/reverse_engineering/zsamples/test_zsamples_spike.py
git commit -m "feat(zsamples): blob inspector with entropy, stride, offset interpretation"
```

---

## Task 5: Compression probe

**Files:**
- Create: `scripts/reverse_engineering/zsamples/compression_probe.py`
- Modify: `scripts/reverse_engineering/zsamples/test_zsamples_spike.py` (append)

- [ ] **Step 1: Write the failing tests**

Append to `test_zsamples_spike.py`:
```python
import gzip
import lzma
import zlib

from compression_probe import (
    Codec,
    try_all,
    CODECS,
)


def test_codecs_list_includes_standard_codecs():
    names = {c.name for c in CODECS}
    assert {"zlib", "gzip", "lzma", "bz2", "lz4", "zstd"}.issubset(names)


def test_try_all_detects_gzip_wrapped_payload():
    payload = b"hello world" * 50
    blob = gzip.compress(payload)
    hits = try_all(blob, offsets=[0])
    assert any(h.codec.name == "gzip" and h.offset == 0 and h.decompressed == payload for h in hits)


def test_try_all_detects_zlib_at_offset():
    payload = b"timestamped depth data\n" * 20
    blob = b"\x04\x00\x00\x00" + zlib.compress(payload)
    hits = try_all(blob, offsets=[0, 4])
    assert any(h.codec.name == "zlib" and h.offset == 4 and h.decompressed == payload for h in hits)


def test_try_all_returns_no_hits_for_random():
    import os
    blob = os.urandom(2048)
    hits = try_all(blob, offsets=list(range(0, 32)))
    # It's statistically possible for a random blob to decompress under some codec,
    # but vanishingly unlikely to produce >512 bytes.
    assert all(len(h.decompressed) < 512 for h in hits)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
pytest test_zsamples_spike.py -v -k "codec or try_all or compression"
```

Expected: FAIL with `ModuleNotFoundError: No module named 'compression_probe'`.

- [ ] **Step 3: Implement `compression_probe.py`**

File `scripts/reverse_engineering/zsamples/compression_probe.py`:
```python
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
import json
import lzma
import shutil
import subprocess
import sys
import tempfile
import zlib
from dataclasses import dataclass, field
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
    with tempfile.NamedTemporaryFile(delete=False) as src, tempfile.NamedTemporaryFile(delete=False) as dst:
        src.write(data)
        src.flush()
        # compression_tool syntax: -decode -i in -o out -encoding lzfse
        result = subprocess.run(
            [tool, "-decode", "-i", src.name, "-o", dst.name, "-encoding", "lzfse"],
            capture_output=True,
        )
        if result.returncode != 0:
            raise RuntimeError(f"compression_tool failed: {result.stderr!r}")
        return Path(dst.name).read_bytes()


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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
pytest test_zsamples_spike.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/reverse_engineering/zsamples/compression_probe.py \
        scripts/reverse_engineering/zsamples/test_zsamples_spike.py
git commit -m "feat(zsamples): compression probe across codecs and offsets"
```

---

## Task 6: Differ — score a decoded profile against UDDF truth

**Files:**
- Create: `scripts/reverse_engineering/zsamples/differ.py`
- Modify: `scripts/reverse_engineering/zsamples/test_zsamples_spike.py` (append)

- [ ] **Step 1: Write the failing tests**

Append to `test_zsamples_spike.py`:
```python
from differ import Score, score_decode


def test_score_perfect_match():
    truth = [
        {"time_s": 0, "depth_m": 0.0, "temperature_c": 25.0},
        {"time_s": 10, "depth_m": 5.0, "temperature_c": 24.0},
        {"time_s": 20, "depth_m": 10.0, "temperature_c": 23.5},
    ]
    decoded = [dict(s) for s in truth]
    score = score_decode(decoded, truth)
    assert score.sample_count_match == 1.0
    assert score.timestamp_rmse == 0.0
    assert score.depth_rmse == 0.0
    assert score.pct_samples_within_tolerance == 1.0


def test_score_penalizes_missing_samples():
    truth = [{"time_s": i * 10, "depth_m": float(i), "temperature_c": 25.0} for i in range(100)]
    decoded = truth[:50]  # only half the samples
    score = score_decode(decoded, truth)
    assert score.sample_count_match == 0.5
    assert score.pct_samples_within_tolerance < 0.6


def test_score_tolerances_depth_and_temp():
    truth = [{"time_s": 0, "depth_m": 10.0, "temperature_c": 20.0}]
    # Within tolerance: +0.05m depth, +0.3C temp
    decoded_ok = [{"time_s": 0, "depth_m": 10.05, "temperature_c": 20.3}]
    # Outside tolerance: +0.3m depth
    decoded_bad = [{"time_s": 0, "depth_m": 10.3, "temperature_c": 20.0}]

    assert score_decode(decoded_ok, truth).pct_samples_within_tolerance == 1.0
    assert score_decode(decoded_bad, truth).pct_samples_within_tolerance == 0.0
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
pytest test_zsamples_spike.py -v -k "score"
```

Expected: FAIL with `ModuleNotFoundError: No module named 'differ'`.

- [ ] **Step 3: Implement `differ.py`**

File `scripts/reverse_engineering/zsamples/differ.py`:
```python
"""Score a decoded profile against UDDF ground truth.

A decoded profile is a list[dict] with keys {time_s, depth_m, temperature_c?,
pressure_bar?, ppo2_bar?, ndl_s?}. The truth profile has the same shape.

Tolerances (from the spec):
    timestamp: exact match required (rounded to seconds)
    depth:     +/- 0.1 m
    temperature: +/- 0.5 C
"""
from __future__ import annotations

import math
from dataclasses import dataclass


DEPTH_TOLERANCE_M = 0.1
TEMP_TOLERANCE_C = 0.5


@dataclass
class Score:
    sample_count_match: float        # len(decoded) / len(truth), clamped [0, 1]
    timestamp_rmse: float            # seconds
    depth_rmse: float                # meters
    temperature_rmse: float          # celsius
    pct_samples_within_tolerance: float  # [0, 1]
    matched_samples: int
    truth_samples: int
    decoded_samples: int

    @property
    def overall(self) -> float:
        """Single scalar in [0, 1]; higher = better. Used for hypothesis ranking."""
        if self.truth_samples == 0:
            return 0.0
        return (
            0.5 * self.pct_samples_within_tolerance
            + 0.5 * min(1.0, self.sample_count_match)
        )


def score_decode(decoded: list[dict], truth: list[dict]) -> Score:
    truth_by_time = {s["time_s"]: s for s in truth}
    decoded_by_time = {s["time_s"]: s for s in decoded}

    matched_samples = 0
    depth_squared_err = 0.0
    temp_squared_err = 0.0
    temp_count = 0
    timestamps_matched = 0

    for t, truth_sample in truth_by_time.items():
        decoded_sample = decoded_by_time.get(t)
        if decoded_sample is None:
            continue
        timestamps_matched += 1

        depth_err = decoded_sample.get("depth_m", 0.0) - truth_sample.get("depth_m", 0.0)
        depth_squared_err += depth_err * depth_err

        if "temperature_c" in decoded_sample and "temperature_c" in truth_sample:
            temp_err = decoded_sample["temperature_c"] - truth_sample["temperature_c"]
            temp_squared_err += temp_err * temp_err
            temp_count += 1

        if abs(depth_err) <= DEPTH_TOLERANCE_M:
            temp_ok = (
                "temperature_c" not in truth_sample
                or "temperature_c" not in decoded_sample
                or abs(decoded_sample["temperature_c"] - truth_sample["temperature_c"]) <= TEMP_TOLERANCE_C
            )
            if temp_ok:
                matched_samples += 1

    truth_n = max(1, len(truth))
    return Score(
        sample_count_match=min(1.0, len(decoded) / truth_n) if truth_n else 0.0,
        timestamp_rmse=0.0,  # we match by exact time; non-matches excluded
        depth_rmse=math.sqrt(depth_squared_err / max(1, timestamps_matched)),
        temperature_rmse=math.sqrt(temp_squared_err / max(1, temp_count)) if temp_count else 0.0,
        pct_samples_within_tolerance=matched_samples / max(1, len(truth)),
        matched_samples=matched_samples,
        truth_samples=len(truth),
        decoded_samples=len(decoded),
    )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
pytest test_zsamples_spike.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/reverse_engineering/zsamples/differ.py \
        scripts/reverse_engineering/zsamples/test_zsamples_spike.py
git commit -m "feat(zsamples): differ scoring decoded profiles against UDDF truth"
```

---

## Task 7: Batch scorer and hypothesis skeleton

**Files:**
- Create: `scripts/reverse_engineering/zsamples/batch_score.py`
- Create: `scripts/reverse_engineering/zsamples/hypotheses/__init__.py`
- Create: `scripts/reverse_engineering/zsamples/hypotheses/h0_noop.py` (used only to verify the harness end-to-end)
- Modify: `scripts/reverse_engineering/zsamples/test_zsamples_spike.py` (append)

- [ ] **Step 1: Write the failing tests**

Append to `test_zsamples_spike.py`:
```python
from batch_score import BatchResult, run_batch
from hypotheses.h0_noop import decode as h0_decode


def test_batch_runs_noop_hypothesis_and_returns_histogram(tmp_path):
    # Seed the tmp corpus with one minimal fixture.
    blob = b"\x04\x00\x00\x00\x00\x00\x00\x00"
    (tmp_path / "abc.zsamples.bin").write_bytes(blob)
    import json
    with (tmp_path / "abc.uddf.json").open("w") as f:
        json.dump({"uuid": "abc", "samples": [{"time_s": 0, "depth_m": 0.0}]}, f)

    result = run_batch(corpus_dir=tmp_path, hypothesis=h0_decode)

    assert result.fixtures_tried == 1
    assert 0.0 <= result.aggregate_overall <= 1.0
    assert len(result.per_fixture_scores) == 1
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
pytest test_zsamples_spike.py -v -k "batch"
```

Expected: FAIL with `ModuleNotFoundError: No module named 'batch_score'`.

- [ ] **Step 3: Implement the hypothesis package and the no-op baseline**

File `scripts/reverse_engineering/zsamples/hypotheses/__init__.py`:
```python
"""Candidate decoder hypotheses. Each module exports `decode(blob: bytes) -> list[dict]`."""
```

File `scripts/reverse_engineering/zsamples/hypotheses/h0_noop.py`:
```python
"""Baseline hypothesis that returns no samples. Used to validate the harness."""
from __future__ import annotations


def decode(blob: bytes) -> list[dict]:
    return []
```

- [ ] **Step 4: Implement `batch_score.py`**

File `scripts/reverse_engineering/zsamples/batch_score.py`:
```python
"""Run a decoder hypothesis across the whole corpus and aggregate scores.

Usage:
    python batch_score.py hypotheses.h2_fixed_width
    python batch_score.py hypotheses.h2_fixed_width --corpus corpus --csv out.csv
"""
from __future__ import annotations

import argparse
import csv
import importlib
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from differ import Score, score_decode


HypothesisFn = Callable[[bytes], list[dict]]


@dataclass
class BatchResult:
    fixtures_tried: int
    aggregate_overall: float
    per_fixture_scores: dict[str, Score] = field(default_factory=dict)

    def histogram(self, buckets: int = 10) -> dict[str, int]:
        counts = [0] * buckets
        for s in self.per_fixture_scores.values():
            idx = min(buckets - 1, int(s.overall * buckets))
            counts[idx] += 1
        return {f"[{i / buckets:.1f}, {(i + 1) / buckets:.1f})": counts[i] for i in range(buckets)}


def run_batch(corpus_dir: Path, hypothesis: HypothesisFn) -> BatchResult:
    scores: dict[str, Score] = {}
    for bin_path in sorted(corpus_dir.glob("*.zsamples.bin")):
        uuid = bin_path.stem.replace(".zsamples", "")
        json_path = corpus_dir / f"{uuid}.uddf.json"
        if not json_path.exists():
            continue
        with json_path.open() as f:
            truth = json.load(f)["samples"]
        try:
            decoded = hypothesis(bin_path.read_bytes())
        except Exception:
            decoded = []
        scores[uuid] = score_decode(decoded, truth)

    if not scores:
        return BatchResult(fixtures_tried=0, aggregate_overall=0.0, per_fixture_scores={})

    agg = sum(s.overall for s in scores.values()) / len(scores)
    return BatchResult(fixtures_tried=len(scores), aggregate_overall=agg, per_fixture_scores=scores)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("hypothesis", help="dotted path, e.g. hypotheses.h2_fixed_width")
    p.add_argument("--corpus", type=Path, default=Path(__file__).parent / "corpus")
    p.add_argument("--csv", type=Path)
    args = p.parse_args()

    module = importlib.import_module(args.hypothesis)
    result = run_batch(args.corpus, module.decode)

    print(f"fixtures: {result.fixtures_tried}")
    print(f"aggregate overall: {result.aggregate_overall:.3f}")
    print("histogram:")
    for bucket, count in result.histogram().items():
        bar = "#" * min(count, 60)
        print(f"  {bucket}  {count:4d}  {bar}")

    if args.csv:
        with args.csv.open("w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["uuid", "overall", "pct_within_tolerance", "matched", "truth", "decoded"])
            for uuid, s in result.per_fixture_scores.items():
                w.writerow([uuid, f"{s.overall:.4f}", f"{s.pct_samples_within_tolerance:.4f}",
                            s.matched_samples, s.truth_samples, s.decoded_samples])


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```bash
pytest test_zsamples_spike.py -v
```

Expected: all tests PASS.

- [ ] **Step 6: Smoke-test against the real corpus**

Run:
```bash
python batch_score.py hypotheses.h0_noop
```

Expected: aggregate overall close to 0.0 (noop decoder matches nothing); fixtures count matches the pairing count from Task 3.

- [ ] **Step 7: Commit**

```bash
git add scripts/reverse_engineering/zsamples/batch_score.py \
        scripts/reverse_engineering/zsamples/hypotheses/ \
        scripts/reverse_engineering/zsamples/test_zsamples_spike.py
git commit -m "feat(zsamples): batch scorer and hypothesis module skeleton"
```

---

## Task 8: Investigate the format

**Files:**
- Create: `scripts/reverse_engineering/zsamples/hypotheses/h1_compression_wrapper.py`
- Create: `scripts/reverse_engineering/zsamples/hypotheses/h2_fixed_width.py`
- Create: `scripts/reverse_engineering/zsamples/hypotheses/h3_tlv_stream.py`
- Create: `scripts/reverse_engineering/zsamples/hypotheses/h4_vendor_frames.py`
- Create: `docs/import-formats/macdive-zsamples.md` (incrementally updated as the investigation proceeds)

This task is the actual spike. It's iterative research — the sub-steps are a checklist, not mechanical TDD steps. After each hypothesis is implemented it becomes testable via `batch_score.py`; the loop is implement-score-inspect-refine until one hypothesis crosses the 90% bar or the timebox expires.

- [ ] **Step 1: Extract the corpus**

Run:
```bash
python extract_corpus.py
cat corpus/manifest.json
```

Expected: `paired_fixtures` in the low-to-mid hundreds. If fewer than ~100 paired fixtures, something is wrong with the UUID join — debug before continuing.

- [ ] **Step 2: Human inspection of three fixtures**

Pick three fixtures: the smallest, the largest, and one in the median. Run:
```bash
python blob_inspect.py corpus/<uuid>.zsamples.bin --limit 128
```

Record observations in `docs/import-formats/macdive-zsamples.md`:
- Entropy per fixture.
- Repeating stride (if any, post-header).
- The second 4-byte header word — does it correlate with dive duration, sample interval, sample count, or something else?
- Any recognizable ASCII substrings, magic bytes, or null padding regions.

- [ ] **Step 3: Hypothesis 1 — compression wrapper**

Run the probe on multiple fixtures:
```bash
for f in $(ls corpus/*.zsamples.bin | head -5); do
  echo "=== $f ==="
  python compression_probe.py "$f" --max-offset 64
done
```

If ANY hit appears (decompressed length >32 bytes, reasonable output): write `hypotheses/h1_compression_wrapper.py` that applies the detected codec + offset and parses the decompressed body. Wire it into `batch_score.py`. Jump to Step 7.

If NO hits: record that in the format doc, continue to Step 4.

File `hypotheses/h1_compression_wrapper.py` (stub even on no-hit, so the module always exists):
```python
"""Hypothesis 1: ZSAMPLES is a wrapped compressed stream.

Populate `CODEC` and `OFFSET` after compression_probe.py hits a codec;
otherwise `decode()` returns [] and this hypothesis is a no-op."""
from __future__ import annotations

CODEC = None  # e.g. "lzfse"
OFFSET = None  # e.g. 8


def decode(blob: bytes) -> list[dict]:
    if CODEC is None or OFFSET is None:
        return []
    # Fill in once probe hits:
    raise NotImplementedError("probe did not identify a compression wrapper")
```

- [ ] **Step 4: Hypothesis 2 — fixed-width sample records**

Write `hypotheses/h2_fixed_width.py`. Starting skeleton:
```python
"""Hypothesis 2: after the 8-byte header, the body is a sequence of fixed-width
sample records. Each record encodes time/depth/temperature/etc. in known widths."""
from __future__ import annotations

import struct


HEADER_LEN = 8


def decode(blob: bytes) -> list[dict]:
    if len(blob) < HEADER_LEN:
        return []
    body = blob[HEADER_LEN:]

    # Try candidate strides by searching for the one that makes
    # depth values land in a sane range across the decode.
    for stride in (8, 12, 16, 20, 24):
        if len(body) % stride != 0:
            continue
        samples = _decode_with_stride(body, stride)
        if _looks_sane(samples):
            return samples
    return []


def _decode_with_stride(body: bytes, stride: int) -> list[dict]:
    """Attempt to parse with a given stride. Initial guess: LE uint16 time + LE int16 depth_cm + LE int16 temp_dC."""
    samples: list[dict] = []
    for i in range(0, len(body), stride):
        chunk = body[i : i + stride]
        if len(chunk) < 6:
            break
        time_s = struct.unpack_from("<H", chunk, 0)[0]
        depth_cm = struct.unpack_from("<h", chunk, 2)[0]
        temp_dC = struct.unpack_from("<h", chunk, 4)[0]
        samples.append({
            "time_s": time_s,
            "depth_m": depth_cm / 100.0,
            "temperature_c": temp_dC / 10.0,
        })
    return samples


def _looks_sane(samples: list[dict]) -> bool:
    if len(samples) < 2:
        return False
    depths = [s["depth_m"] for s in samples]
    times = [s["time_s"] for s in samples]
    return (
        0 <= max(depths) <= 200
        and all(d >= -1 for d in depths)
        and times == sorted(times)
    )
```

Run:
```bash
python batch_score.py hypotheses.h2_fixed_width --csv corpus/h2_scores.csv
```

Iterate: inspect high-scoring and low-scoring fixtures, adjust stride/field layout/endianness, re-score. Each meaningful iteration gets a commit:
```bash
git add scripts/reverse_engineering/zsamples/hypotheses/h2_fixed_width.py \
        docs/import-formats/macdive-zsamples.md
git commit -m "spike(zsamples): h2 iteration — <what changed, what score>"
```

Continue to Step 7 if aggregate overall crosses 0.9; to Step 5 otherwise.

- [ ] **Step 5: Hypothesis 3 — TLV stream**

Write `hypotheses/h3_tlv_stream.py`:
```python
"""Hypothesis 3: after the 8-byte header, the body is a typed record stream.
Each record is <tag:u8><len:u8><value:len bytes>. Some tags carry timestamps,
others depth, others events."""
from __future__ import annotations


HEADER_LEN = 8


def decode(blob: bytes) -> list[dict]:
    samples: list[dict] = []
    cursor: dict = {}
    pos = HEADER_LEN
    while pos + 2 <= len(blob):
        tag = blob[pos]
        length = blob[pos + 1]
        pos += 2
        if pos + length > len(blob):
            break
        value = blob[pos : pos + length]
        pos += length
        _apply_tag(cursor, tag, value, samples)
    if cursor:
        samples.append(dict(cursor))
    return samples


def _apply_tag(cursor: dict, tag: int, value: bytes, samples: list[dict]) -> None:
    # Placeholder: populate after inspection reveals the real tag schema.
    pass
```

Use `blob_inspect.py` to examine tag distributions: tabulate the first byte at each possible position, see whether tags cluster into a small vocabulary (signals TLV). Update `_apply_tag` as the schema emerges. Iterate, score, commit.

- [ ] **Step 6: Hypothesis 4 — vendor-framed container**

Write `hypotheses/h4_vendor_frames.py`:
```python
"""Hypothesis 4: ZSAMPLES wraps a dive-computer vendor's native frame format.
The second header byte is the vendor/protocol family ID; each family decodes
differently. Cross-reference libdivecomputer's per-vendor parsers for framing."""
from __future__ import annotations


def decode(blob: bytes) -> list[dict]:
    if len(blob) < 8:
        return []
    family = blob[4]
    # Dispatch by family to per-vendor sub-decoders.
    return _FAMILY_DECODERS.get(family, _noop)(blob[8:])


def _noop(body: bytes) -> list[dict]:
    return []


_FAMILY_DECODERS = {
    # 0x19: lambda body: _decode_family_19(body),
    # 0x9D: lambda body: _decode_family_9d(body),
}
```

Only attempt this hypothesis if #2 and #3 fail meaningfully. Iterate, score, commit.

- [ ] **Step 7: Document the cracked format (or the no-go)**

Fill in `docs/import-formats/macdive-zsamples.md`:

If a hypothesis scored ≥ 0.9, the document describes the format precisely:
- Exact header layout (offset/type/meaning for every byte).
- Exact sample record layout.
- Unit conventions (are values SI in the blob, or imperial like the rest of MacDive SQLite? Cross-reference `ZMETADATA.SystemOfUnits`).
- Known variants (header families) and how to dispatch.
- Edge cases: header-only blobs, truncated bodies, unusual field widths.
- The scored aggregate overall and histogram from `batch_score.py`.

If NO hypothesis crossed 0.9, the document records:
- All hypotheses attempted, their best scores, what they revealed.
- What's known about the format's structure (entropy, strides, etc.).
- Why the ZRAWDATA/libdivecomputer fallback is now the recommended path.

- [ ] **Step 8: Commit the format spec**

```bash
git add docs/import-formats/macdive-zsamples.md \
        scripts/reverse_engineering/zsamples/hypotheses/
git commit -m "docs(zsamples): format specification from Phase 1 spike"
```

---

## Task 9: Go/no-go decision and hand off to Phase 2

**Files:**
- Modify: `docs/superpowers/plans/2026-04-21-macdive-sqlite-import.md` (append tail link)
- Modify: `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md` (append decision outcome)
- Conditional: Create either the Phase 2 plan or the no-go spec.

- [ ] **Step 1: Record the go/no-go decision in the spec**

Append a `## Phase 1 outcome` section to `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md`:

```markdown
## Phase 1 outcome

**Decision:** [GO | NO-GO] — recorded YYYY-MM-DD.

**Best hypothesis:** [e.g. `h2_fixed_width`], scored [0.XX] aggregate overall across [N] fixtures.

**Format spec:** `docs/import-formats/macdive-zsamples.md`.

**Phase 2 plan:** `docs/superpowers/plans/2026-04-23-macdive-zsamples-phase-2-decoder.md` (GO only).

**No-go spec:** `docs/superpowers/specs/2026-04-23-macdive-zsamples-nogo.md` (NO-GO only).
```

- [ ] **Step 2: Append tail link to the parent plan**

Append to `docs/superpowers/plans/2026-04-21-macdive-sqlite-import.md`:

```markdown
## Continuation

- Phase 1 spike: `docs/superpowers/plans/2026-04-23-macdive-zsamples-phase-1-spike.md`
- Phase 2 decoder: `docs/superpowers/plans/2026-04-23-macdive-zsamples-phase-2-decoder.md` (written once Phase 1 completes GO)
```

- [ ] **Step 3 (GO only): Invoke writing-plans to produce the Phase 2 plan**

From the agent's perspective, invoke the `superpowers:writing-plans` skill with these arguments:
> Spec: `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md`.
> Format spec (the thing this plan produces): `docs/import-formats/macdive-zsamples.md`.
> Produce the Phase 2 implementation plan — the Dart decoder and its wiring. Reference the format spec for all byte-layout details. Output: `docs/superpowers/plans/2026-04-23-macdive-zsamples-phase-2-decoder.md`.

- [ ] **Step 3 (NO-GO only): Write the no-go spec**

Create `docs/superpowers/specs/2026-04-23-macdive-zsamples-nogo.md` summarizing:
- What was attempted.
- Why the ZSAMPLES format resisted decoding.
- The recommended pivot: ZRAWDATA decoded via `libdivecomputer`.
- Coverage estimate of the pivot (267/540 dives in the sample corpus, ~49%).

- [ ] **Step 4: Final commit**

```bash
git add docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md \
        docs/superpowers/plans/2026-04-21-macdive-sqlite-import.md
# Plus the Phase 2 plan or the no-go spec from Step 3.
git commit -m "docs(zsamples): Phase 1 decision recorded — [GO|NO-GO]"
```

- [ ] **Step 5: Open the PR against `feature/macdive-sqlite`**

Run:
```bash
git push -u origin feature/macdive-zsamples-phase-1
gh pr create --base feature/macdive-sqlite --title "MacDive ZSAMPLES Phase 1 spike" --body "$(cat <<'EOF'
## Summary

- Phase 1 spike tooling for decoding MacDive's `ZDIVE.ZSAMPLES` blob
  (`scripts/reverse_engineering/zsamples/`).
- Format spec at `docs/import-formats/macdive-zsamples.md`.
- Go/no-go decision recorded in the design spec.

Stacked on PR #256 (`feature/macdive-sqlite`).

## Test plan

- [ ] `pytest scripts/reverse_engineering/zsamples/` passes locally.
- [ ] Format spec is precise enough to implement the Dart decoder.
EOF
)"
```

Expected: PR URL printed; PR opened against `feature/macdive-sqlite`.

---

## Self-Review

Performed inline after writing this plan:

**Spec coverage:** Every Phase 1 deliverable in the spec maps to a task:
- "Scripts directory" → Task 2.
- "extract_corpus" → Task 3.
- "inspect" (renamed to `blob_inspect` to avoid stdlib shadowing) → Task 4.
- "compression_probe" → Task 5.
- "differ" → Task 6.
- "batch_score" → Task 7.
- "Ranked hypotheses H1–H4" → Task 8 steps 3–6.
- "Format spec document" → Task 8 step 7, Task 9 step 1.
- "Go/no-go decision recorded as commit to plan file" → Task 9 steps 1–4.
- "Phase 2 plan produced if GO" → Task 9 step 3 (GO branch).

Phase 2 tasks are intentionally not in this plan — they depend on Phase 1 findings. Task 9 step 3 (GO branch) re-invokes `writing-plans` to produce them.

**Placeholder scan:** No "TBD", "TODO", "implement later". Step 3 of Task 8 acknowledges that the body of `h1_compression_wrapper.py` depends on the probe result — this is not a placeholder, it's an explicit data-dependent branch with concrete instructions for both outcomes. Hypothesis 3 and 4 (`h3_tlv_stream`, `h4_vendor_frames`) contain `_apply_tag` / `_FAMILY_DECODERS` stubs — these are genuine research starting points where the schema is populated as inspection reveals it. Both come with concrete inspection-driven instructions.

**Type consistency:** `UddfProfile.samples` keys (`time_s`, `depth_m`, `temperature_c`, `pressure_bar`) used consistently across `extract_corpus`, `differ`, `batch_score`, and all hypotheses. `Score` dataclass fields used consistently. `BatchResult` / `CorpusSummary` shapes used consistently.

**File-structure consistency:** `blob_inspect.py` is named that way from the start — the File Structure table, Task 4, and all imports use the same module name, which avoids shadowing the stdlib `inspect` module.
