#!/usr/bin/env python3
"""The naming levels below a pack's own bars (issue #4721): each chosen on
the tune half by bars.level_bars, kept only when it stands held out, and
the held-out rates a diver is shown for it.

Each record is one crop named with a location (`"with"`) and without one
(`"without"`), as score.py keeps them. The figure a diver is shown for a
level, and for Surer, is the lower of its held-out precisions with and
without a location, so it never overstates for either kind of photo.

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


# Where each held-out precision in `rates` was measured, and its key there.
SIDES = (("with a location", "precision"), ("without a location", "precision without location"))


def _lower_side(sides):
    """The (where, rate) of `sides` with the lower `value`, counting only a
    side that names something; on a tie, the one naming more crops, since
    it alone gives the same figure. None when no side names anything."""
    named = [side for side in sides if side[1] and side[1].get("n")]
    return min(named, key=lambda side: (side[1]["value"], -side[1]["n"])) if named else None


def shown_precision(with_rate, without_rate):
    """The figure a diver is shown: the lower `value` of the two held-out
    precisions, counting only a side that names something (a side naming
    nothing has no figure, and the other stands). Unrounded; None when
    neither side names anything."""
    (with_where, _), (without_where, _) = SIDES
    side = _lower_side([(with_where, with_rate), (without_where, without_rate)])
    return None if side is None else side[1]["value"]


def deciding_side(held):
    """(where, rate) of the side of `held` (as `rates` returns it) that sets
    its shown figure, as shown_precision takes it; None when neither side
    names anything. A side missing from `held` names nothing."""
    return _lower_side([(where, held.get(key)) for where, key in SIDES])


def rates(bars, held_nat, held_junk, *, min_side):
    """Held-out precision and coverage at `bars`, with a location and
    without one, and the held-out junk they name with or without one."""
    scored, unplaced = _split(held_nat)
    junk_with, junk_without = _split(held_junk)
    named = bar_search.named(scored, bars, min_side=min_side)
    coverage, precision = metrics.coverage_precision(named, [s.correct for s in scored])
    named_unplaced = bar_search.named(unplaced, bars, min_side=min_side)
    coverage_unplaced, precision_unplaced = metrics.coverage_precision(
        named_unplaced, [s.correct for s in unplaced]
    )
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
        "precision without location": precision_unplaced.__dict__,
        "coverage without location": coverage_unplaced.__dict__,
        "junk named": metrics.rate(sum(junk), len(junk)).__dict__,
    }


def measure(surer, tune_nat, tune_junk, held_nat, held_junk, *, min_side):
    """(levels, Surer's shown figure, Surer's held-out rates) under
    `surer`, the bars the pack names at. A shown figure is the lower of the
    held-out precisions with and without a location (shown_precision). The
    levels come surest first, each with its shown figure as `"precision"`,
    rounded as a manifest carries it. Surer's figure is unrounded and None
    when its bars name nothing held out; it may be 0, which still bounds
    the levels, though a manifest carries only a share in (0, 1]. Surer's
    rates are `rates` at its bars, which its figure is taken from.

    A level is left out when it adds nothing over the level above, fails
    the held-out gate, has no shown figure in (0, 1] (nothing named, or
    nothing right, on the side that decides it; the app and
    manifest.level_problems require a share), or shows a higher figure than
    the level above: a diver must never read that more names are more often
    right, and the app and manifest.level_problems refuse such a level."""
    tune_with, tune_without = _split(tune_nat)
    tune_junk_with, tune_junk_without = _split(tune_junk)
    held_with, held_without = _split(held_nat)

    surer_rates = rates(surer, held_nat, held_junk, min_side=min_side)
    surer_precision = shown_precision(surer_rates["precision"], surer_rates["precision without location"])
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
        figure = shown_precision(held["precision"], held["precision without location"])
        shown = manifest_precision(figure)
        # Nothing named, or nothing right at the places the manifest keeps.
        if shown is None:
            continue
        if above_precision is not None and shown > round(above_precision, PRECISION_PLACES):
            continue
        levels.append(
            {"id": level_id, "target": target, "bars": level.__dict__, "held-out": held, "precision": shown}
        )
        ceiling, above_precision = level, figure
    return levels, surer_precision, surer_rates
