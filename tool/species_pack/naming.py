#!/usr/bin/env python3
"""The app's species naming, for the pack tools: a copy of
lib/features/species_id/domain/services/species_namer.dart that returns the
scores instead of a verdict, so the accuracy scorer can try every bar.

The two must not drift. This module writes testdata/naming_vectors.json:

    python3 tool/species_pack/naming.py --write-vectors \
        tool/species_pack/testdata/naming_vectors.json

and test/features/species_id/domain/species_namer_vectors_test.dart checks
the Dart namer against the same file. Arithmetic follows the Dart code step
for step (same order of sums), so the two agree to rounding.

Standard library only, so its test runs in CI without the model tooling.
"""

import argparse
import json
import math
import os
import sys
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import region_grid  # noqa: E402


@dataclass(frozen=True)
class Naming:
    """What one crop was named as, before any bar is applied."""

    # The top share over every candidate, before place is considered.
    open_score: float
    # (candidate index, share among the allowed candidates), best first.
    ranked: tuple
    # Whether candidates were limited to species recorded near the photo.
    location_limited: bool


def unit(vector):
    """`vector` scaled to unit length, or None when nothing can be read from
    it: empty, zero, or not finite."""
    if not vector:
        return None
    squares = 0.0
    for v in vector:
        if not math.isfinite(v):
            return None
        squares += v * v
    if squares <= 0:
        return None
    norm = math.sqrt(squares)
    return [v / norm for v in vector]


def logits(unit_vector, text_rows, scale):
    """Each candidate's dot product with the crop, times `scale`."""
    out = []
    for row in text_rows:
        dot = 0.0
        for a, b in zip(unit_vector, row):
            dot += a * b
        out.append(dot * scale)
    return out


def allowed_for(cell, bits, candidate_count, *, cell_degrees, rings, min_allowed, overrides=None):
    """The candidates recorded near `cell`, or None when there is no cell or
    too few are allowed to limit by. `overrides` (candidate index to allowed)
    are applied before the count."""
    if cell is None or cell < 0 or cell >= region_grid.cell_count(cell_degrees):
        return None
    cells = region_grid.neighbourhood(cell, rings, cell_degrees)
    mask = region_grid.allowed_mask(bits, candidate_count, cells, cell_degrees)
    for index, allowed in (overrides or {}).items():
        mask[index] = allowed
    count = sum(1 for allowed in mask if allowed)
    if count == 0 or count < min_allowed:
        return None
    return mask


def name(logit_row, allowed, top_k):
    """Names one crop from its logits. `allowed` is a mask from
    `allowed_for`, or None for no location. None when nothing can be read."""
    if not logit_row:
        return None
    max_logit = -math.inf
    for logit in logit_row:
        if math.isnan(logit):
            return None
        if logit > max_logit:
            max_logit = logit
    if not math.isfinite(max_logit):
        return None

    open_sum = 0.0
    for logit in logit_row:
        open_sum += math.exp(logit - max_logit)
    open_score = 1 / open_sum

    if allowed is None:
        # Every candidate is allowed: the same sum as the open score's.
        allowed_max, total = max_logit, open_sum
    else:
        allowed_max = -math.inf
        for i, logit in enumerate(logit_row):
            if allowed[i] and logit > allowed_max:
                allowed_max = logit
        total = 0.0
        for i, logit in enumerate(logit_row):
            if allowed[i]:
                total += math.exp(logit - allowed_max)

    # The Dart insertion loop: a candidate moves ahead only of strictly
    # lower logits, so ties keep the lower index first.
    best = []
    for i, logit in enumerate(logit_row):
        if allowed is not None and not allowed[i]:
            continue
        if len(best) == top_k and logit <= logit_row[best[-1]]:
            continue
        at = len(best)
        while at > 0 and logit_row[best[at - 1]] < logit:
            at -= 1
        best.insert(at, i)
        if len(best) > top_k:
            best.pop()

    ranked = tuple((i, math.exp(logit_row[i] - allowed_max) / total) for i in best)
    return Naming(open_score=open_score, ranked=ranked, location_limited=allowed is not None)


def suggestable(naming, shorter_side, *, min_crop_side, min_open_score, suggest_score, suggest_score_no_location):
    """Whether the app would suggest this crop's top candidate."""
    bar = suggest_score if naming.location_limited else suggest_score_no_location
    return (
        shorter_side >= min_crop_side
        and naming.open_score >= min_open_score
        and len(naming.ranked) > 0
        and naming.ranked[0][1] >= bar
    )


def vectors():
    """Small cases with every expected value computed here. Inputs are
    multiples of 1/16, which float32 holds exactly, so the Dart side reads
    the same numbers."""
    cd = 30
    config = {
        "minCropSide": 64,
        "minOpenScore": 0.65,
        "suggestScore": 0.5,
        "confidentScore": 0.7,
        "suggestScoreNoLocation": 0.7,
        "minAllowedCandidates": 2,
        "topK": 3,
    }
    text = [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
        [0.5, 0.5, 0.5, 0.5],
        [0.75, 0.625, 0, 0],
    ]
    reef = region_grid.cell_of(12, -68, cd)
    beside = region_grid.cell_of(12, -38, cd)
    thin = region_grid.cell_of(-60, 100, cd)
    recorded = [[reef], [reef], [reef], [], [beside], [thin]]
    bits = region_grid.pack_bits(recorded, cd)
    cases = [
        ("no location", [1, 0.25, 0.125, 0], None, 200, False),
        ("tie between two candidates", [0.5, 0.5, 0, 0], None, 200, True),
        ("a limited list lifts the score but the open score guards it", [0.75, 0.5, 0, 0.6875], reef, 200, False),
        ("a neighbouring cell counts", [0.25, 0, 0, 1], beside, 200, False),
        ("too few recorded falls back", [0.75, 0.625, 0, 0], thin, 200, False),
        ("too small to suggest", [1, 0, 0, 0], reef, 63, False),
    ]
    out_cases = []
    for label, embedding, cell, side, tie in cases:
        allowed = allowed_for(
            cell,
            bits,
            len(text),
            cell_degrees=cd,
            rings=1,
            min_allowed=config["minAllowedCandidates"],
        )
        result = name(logits(unit(embedding), text, 10.0), allowed, config["topK"])
        out_cases.append(
            {
                "label": label,
                "embedding": embedding,
                "cell": cell,
                "boxShorterSide": side,
                "tie": tie,
                "expected": {
                    "openScore": result.open_score,
                    "locationLimited": result.location_limited,
                    "candidates": [{"index": i, "score": s} for i, s in result.ranked],
                    "suggestable": suggestable(
                        result,
                        side,
                        min_crop_side=config["minCropSide"],
                        min_open_score=config["minOpenScore"],
                        suggest_score=config["suggestScore"],
                        suggest_score_no_location=config["suggestScoreNoLocation"],
                    ),
                },
            }
        )
    return {
        "cellDegrees": cd,
        "neighbourCells": 1,
        "embeddingSize": 4,
        "logitScale": 10.0,
        "config": config,
        "textEmbeddings": text,
        "recorded": recorded,
        "cases": out_cases,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write-vectors", metavar="PATH", required=True)
    args = parser.parse_args(argv)
    with open(args.write_vectors, "w", encoding="utf-8") as fh:
        json.dump(vectors(), fh, indent=1)
        fh.write("\n")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
