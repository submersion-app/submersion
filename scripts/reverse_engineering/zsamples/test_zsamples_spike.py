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


def test_from_uddf_file_rejects_uuid_filter_with_first_only():
    """Guard against the silent wrong-answer bug noted in code review."""
    with pytest.raises(ValueError, match="uuid_filter is ignored"):
        UddfProfile.from_uddf_file(
            SAMPLE_UDDF,
            uuid_filter={"some-uuid"},
            first_only=True,
        )


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


def test_interpret_offset_includes_all_endians_at_each_width():
    """All widths should have both LE and BE interpretations when bytes are available."""
    data = bytes([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    interp = interpret_offset(data, 0)
    assert "u16_le" in interp and "u16_be" in interp
    assert "u32_le" in interp and "u32_be" in interp
    assert "f32_le" in interp and "f32_be" in interp
    assert "u64_le" in interp and "u64_be" in interp
    assert "f64_le" in interp and "f64_be" in interp
    # Spot-check one pair: u32 big-endian is 0x01020304, little-endian is 0x04030201.
    assert interp["u32_be"] == 0x01020304
    assert interp["u32_le"] == 0x04030201


def test_hex_dump_line_formats_16_bytes():
    line = hex_dump_line(bytes(range(16)), offset=0)
    assert "00 01 02 03" in line
    assert "0c 0d 0e 0f" in line


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
    # Standard codecs present by exact name:
    assert {"zlib", "gzip", "lzma", "bz2", "zstd"}.issubset(names)
    # lz4 has two variants (frame, block); at least one must be present.
    assert any(name.startswith("lz4") for name in names)


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


def test_score_depth_rmse_is_nan_when_no_timestamps_overlap():
    """A completely-failed decoder should produce NaN depth_rmse, not 0.0 (which masks failure)."""
    import math
    truth = [{"time_s": 0, "depth_m": 10.0}, {"time_s": 10, "depth_m": 20.0}]
    decoded = [{"time_s": 999, "depth_m": 5.0}]  # no timestamp overlap
    score = score_decode(decoded, truth)
    assert math.isnan(score.depth_rmse), f"expected NaN, got {score.depth_rmse}"
    assert score.matched_samples == 0
    assert score.pct_samples_within_tolerance == 0.0


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
