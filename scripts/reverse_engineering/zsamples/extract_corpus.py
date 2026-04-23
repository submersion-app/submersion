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
        if first_only and uuid_filter is not None:
            raise ValueError("uuid_filter is ignored when first_only=True; pass uuid_filter=None")
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
