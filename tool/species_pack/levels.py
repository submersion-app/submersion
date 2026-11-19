#!/usr/bin/env python3
"""The naming levels below a pack's own bars (issue #4721): each chosen on
the tune half by bars.level_bars, kept only when it stands held out, and
the held-out rates a diver is shown for it.

Each record is one crop named with a location (`"with"`) and without one
(`"without"`), as score.py keeps them.

Standard library only, so its test runs in CI without the model tooling.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bars as bar_search  # noqa: E402
import metrics  # noqa: E402

# Precision as the manifest carries it, and so as the app and
# manifest.level_problems compare one level's against the next.
PRECISION_PLACES = 3


def manifest_precision(value):
    """`value` as a manifest carries a precision: rounded to
    PRECISION_PLACES, or None when that leaves no share in (0, 1] to show
    (none measured, or nothing right at those places), as the app and
    manifest.level_problems require."""
    if value is None:
        return None
    rounded = round(value, PRECISION_PLACES)
    return rounded if rounded > 0 else None


def _split(records):
    return [c["with"] for c in records], [c["without"] for c in records]


def rates(bars, held_nat, held_junk, *, min_side):
    """Held-out precision and coverage with a location at `bars`, and the
    held-out junk they name with or without one."""
    scored, _ = _split(held_nat)
    junk_with, junk_without = _split(held_junk)
    named = bar_search.named(scored, bars, min_side=min_side)
    coverage, precision = metrics.coverage_precision(named, [s.correct for s in scored])
    junk = [
        a or b
        for a, b in zip(
            bar_search.named(junk_with, bars, min_side=min_side),
            bar_search.named(junk_without, bars, min_side=min_side),
        )
    ]
    return {
        "precision": precision.__dict__,
        "coverage": coverage.__dict__,
        "junk named": metrics.rate(sum(junk), len(junk)).__dict__,
    }


def measure(surer, tune_nat, tune_junk, held_nat, held_junk, *, min_side):
    """(levels, Surer's held-out precision) under `surer`, the bars the
    pack names at. The levels come surest first; Surer's precision is None
    when its bars name nothing held out. It may be 0, which still bounds
    the levels, though a manifest carries only a share in (0, 1].

    A level is left out when it adds nothing over the level above, fails
    the held-out gate, names nothing right held out with a location (no
    share in (0, 1] to show, which the app and manifest.level_problems
    require), or was more often right held out than the level above: a
    diver must never read that more names are more often right, and the
    app and manifest.level_problems refuse such a level."""
    tune_with, tune_without = _split(tune_nat)
    tune_junk_with, tune_junk_without = _split(tune_junk)
    held_with, held_without = _split(held_nat)

    surer_rates = rates(surer, held_nat, held_junk, min_side=min_side)["precision"]
    surer_precision = surer_rates["value"] if surer_rates["n"] else None
    levels = []
    ceiling, above_precision = surer, surer_precision
    for level_id, target in bar_search.LEVEL_TARGETS:
        level = bar_search.level_bars(
            tune_with,
            tune_without,
            tune_junk_with,
            tune_junk_without,
            surer=surer,
            ceiling=ceiling,
            min_side=min_side,
            target=target,
        )
        if level is None or not bar_search.level_gate(
            level, surer, held_with, held_without, min_side=min_side, target=target
        ):
            continue
        held = rates(level, held_nat, held_junk, min_side=min_side)
        precision = held["precision"]
        shown = manifest_precision(precision["value"])
        # Nothing named, or nothing right at the places the manifest keeps.
        if shown is None:
            continue
        if above_precision is not None and shown > round(above_precision, PRECISION_PLACES):
            continue
        levels.append({"id": level_id, "target": target, "bars": level.__dict__, "held-out": held})
        ceiling, above_precision = level, precision["value"]
    return levels, surer_precision
