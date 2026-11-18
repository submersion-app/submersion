#!/usr/bin/env python3
"""Chooses a pack's naming bars from scored crops (the measured accuracy
design, docs/design/specs/2026-11-17-marine-life-identification-measured-accuracy-design.md).

A setting meets a precision target when the one-sided 95% Wilson lower
bound of its precision is at least the target, so a bar never passes on a
lucky handful of photos. Among settings that meet a target, the one naming
the most fish correctly wins; ties go to the higher value, which adds no
correct names and only removes wrong ones.

Standard library only, so its test runs in CI without the model tooling.
"""

import math
from dataclasses import dataclass, replace

# A share is at most 1, so no crop ever reaches this bar.
NEVER = 1.01
OPEN_GRID = [round(i / 100, 2) for i in range(0, 51)]
BAR_GRID = [round(i / 100, 2) for i in range(20, 100)]
Z_ONE_SIDED = 1.6448536269514722
Z_TWO_SIDED = 1.959963984540054


@dataclass(frozen=True)
class Scored:
    """One naming of one crop under one condition (with or without a
    location). Junk crops are never correct."""

    open_score: float
    top_score: float
    correct: bool
    shorter_side: int
    # Whether the candidates were limited by place; when not, the app
    # applies the no-location bars.
    limited: bool


@dataclass(frozen=True)
class Bars:
    min_open: float
    suggest: float
    suggest_no_location: float
    confident: float
    confident_no_location: float


def wilson(correct, total, z):
    """The Wilson score interval for `correct` of `total`. (0, 1) when
    there is nothing to judge."""
    if total == 0:
        return (0.0, 1.0)
    p = correct / total
    z2 = z * z
    denominator = 1 + z2 / total
    centre = (p + z2 / (2 * total)) / denominator
    half = z * math.sqrt(p * (1 - p) / total + z2 / (4 * total * total)) / denominator
    return (max(0.0, centre - half), min(1.0, centre + half))


def _suggested(scored, *, min_open, bar, min_side):
    return [c for c in scored if c.shorter_side >= min_side and c.open_score >= min_open and c.top_score >= bar]


def meets(scored, *, min_open, bar, min_side, target):
    """(whether the crops named at this setting meet `target`, how many
    of them are correct). Naming nothing does not meet a target."""
    named = _suggested(scored, min_open=min_open, bar=bar, min_side=min_side)
    correct = sum(1 for c in named if c.correct)
    if not named:
        return (False, 0)
    return (wilson(correct, len(named), Z_ONE_SIDED)[0] >= target, correct)


def _best_bar(scored, *, min_open, min_side, target, floor=0.0):
    """(bar, correct) for the bar at or above `floor` that meets `target`
    with the most correct names, ties to the higher bar; (NEVER, 0) when
    none meets it."""
    best = (NEVER, 0)
    for bar in BAR_GRID:
        if bar < floor:
            continue
        passes, correct = meets(scored, min_open=min_open, bar=bar, min_side=min_side, target=target)
        if passes and (best[0] == NEVER or correct >= best[1]):
            best = (bar, correct)
    return best


def _bars_at(min_open, limited, no_location, *, min_side, suggest_target, confident_target):
    suggest, _ = _best_bar(limited, min_open=min_open, min_side=min_side, target=suggest_target)
    no_loc, _ = _best_bar(no_location, min_open=min_open, min_side=min_side, target=suggest_target)
    confident, _ = _best_bar(
        limited, min_open=min_open, min_side=min_side, target=confident_target, floor=suggest
    )
    confident_no_loc, _ = _best_bar(
        no_location, min_open=min_open, min_side=min_side, target=confident_target, floor=no_loc
    )
    return Bars(min_open, suggest, no_loc, confident, confident_no_loc)


def named(scored, bars, *, min_side, confident=False):
    """Whether the app would name each crop at these bars: limited crops
    against the location bar, the rest against the no-location bar."""
    out = []
    for c in scored:
        if confident:
            bar = bars.confident if c.limited else bars.confident_no_location
        else:
            bar = bars.suggest if c.limited else bars.suggest_no_location
        out.append(c.shorter_side >= min_side and c.open_score >= bars.min_open and c.top_score >= bar)
    return out


def junk_rate(junk_with, junk_without, bars, *, min_side):
    """The share of junk crops named with a location or without one."""
    if not junk_with:
        return 0.0
    either = [
        a or b
        for a, b in zip(named(junk_with, bars, min_side=min_side), named(junk_without, bars, min_side=min_side))
    ]
    return sum(either) / len(either)


def choose_bars(
    with_location,
    no_location,
    junk_with,
    junk_without,
    *,
    min_side,
    suggest_target=0.85,
    confident_target=0.95,
    max_junk_rate=0.02,
):
    """The bars, chosen on the tune half. `junk_with` and `junk_without`
    are the same junk crops in the same order, named with and without a
    location."""
    limited = [c for c in with_location if c.limited]
    kw = dict(min_side=min_side, suggest_target=suggest_target, confident_target=confident_target)

    best_open, best_correct = 0.0, -1
    for min_open in OPEN_GRID:
        bar, correct = _best_bar(limited, min_open=min_open, min_side=min_side, target=suggest_target)
        if bar != NEVER and correct >= best_correct:
            best_open, best_correct = min_open, correct
    chosen = _bars_at(best_open, limited, no_location, **kw)

    if junk_rate(junk_with, junk_without, chosen, min_side=min_side) <= max_junk_rate:
        return chosen
    for min_open in OPEN_GRID:
        if min_open <= chosen.min_open:
            continue
        raised = _bars_at(min_open, limited, no_location, **kw)
        if junk_rate(junk_with, junk_without, raised, min_side=min_side) <= max_junk_rate:
            return raised
    return Bars(OPEN_GRID[-1], NEVER, NEVER, NEVER, NEVER)


def held_out_gate(bars, with_location, no_location, *, min_side, suggest_target=0.85, confident_target=0.95):
    """Checks each bar once on the held-out half. A bar whose two-sided 95%
    interval lies wholly below its target is switched off; a confident bar
    goes with its suggest bar. A bar that names nothing held out has no
    evidence of meeting its target, so it is switched off too. Returns the
    gated bars and the manifest names of those switched off. No value is
    chosen here."""
    limited = [c for c in with_location if c.limited]

    def fails(scored, bar, target):
        picked = _suggested(scored, min_open=bars.min_open, bar=bar, min_side=min_side)
        if not picked:
            return True
        correct = sum(1 for c in picked if c.correct)
        return wilson(correct, len(picked), Z_TWO_SIDED)[1] < target

    gated = bars
    off = []
    checks = [
        ("suggestScore", "suggest", limited, suggest_target),
        ("confidentScore", "confident", limited, confident_target),
        ("suggestScoreNoLocation", "suggest_no_location", no_location, suggest_target),
        ("confidentScoreNoLocation", "confident_no_location", no_location, confident_target),
    ]
    for key, field, scored, target in checks:
        follows = {"confident": "suggest", "confident_no_location": "suggest_no_location"}.get(field)
        switched_with_suggest = follows is not None and getattr(gated, follows) == NEVER
        if getattr(gated, field) != NEVER and (switched_with_suggest or fails(scored, getattr(gated, field), target)):
            gated = replace(gated, **{field: NEVER})
            off.append(key)
    return gated, off


def mcnemar_p(only_a, only_b):
    """Exact two-sided McNemar test: the chance of a split at least this
    uneven between crops only one method got right, if both were equal."""
    n = only_a + only_b
    if n == 0:
        return 1.0
    k = min(only_a, only_b)
    tail = sum(math.comb(n, i) for i in range(k + 1)) / 2**n
    return min(1.0, 2 * tail)
