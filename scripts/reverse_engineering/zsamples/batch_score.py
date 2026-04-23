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
