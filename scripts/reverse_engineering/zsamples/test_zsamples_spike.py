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
