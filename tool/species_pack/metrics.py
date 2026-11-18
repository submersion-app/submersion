#!/usr/bin/env python3
"""The numbers in the accuracy report: top-k accuracy, coverage and
precision with their intervals, and breakdowns by group.

Standard library only, so its test runs in CI without the model tooling.
"""

import os
import sys
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from bars import Z_TWO_SIDED, wilson  # noqa: E402


@dataclass(frozen=True)
class Rate:
    n: int
    hits: int
    value: float
    low: float
    high: float


def size_bucket(shorter_side):
    """The report's box size groups, in pixels of the analysed image."""
    if shorter_side < 64:
        return "under 64"
    if shorter_side < 128:
        return "64-127"
    if shorter_side < 256:
        return "128-255"
    return "256+"


def top_k(ranks, k):
    """The share of crops whose label ranks within the first `k`. A rank
    is 0-based, or None when the label is not ranked at all."""
    if not ranks:
        return 0.0
    return sum(1 for r in ranks if r is not None and r < k) / len(ranks)


def rate(hits, n):
    """`hits` of `n`, with a two-sided 95% Wilson interval."""
    low, high = wilson(hits, n, Z_TWO_SIDED)
    return Rate(n=n, hits=hits, value=hits / n if n else 0.0, low=low, high=high)


def coverage_precision(named, correct):
    """Coverage over every crop, and precision over the crops named."""
    named_count = sum(1 for x in named if x)
    right = sum(1 for x, c in zip(named, correct) if x and c)
    return rate(named_count, len(named)), rate(right, named_count)


def recommend(named_right, paired_p, preference, junk_ok, *, alpha=0.05):
    """The design's detector rule. Among eligible runs (within the junk
    target and, since issue #4691, over every group's floor; `junk_ok` maps
    a run to whether it is eligible), the one naming the most animals right,
    unless a run earlier in `preference` (simpler, or explicitly licensed)
    is not significantly worse than it. `paired_p` maps a frozenset of two
    run names to their paired test's p. None when no run is eligible."""
    eligible = [name for name in named_right if junk_ok.get(name)]
    if not eligible:
        return None
    best = max(eligible, key=lambda name: named_right[name])
    for name in preference:
        if name not in eligible:
            continue
        if name == best or named_right[name] >= named_right[best]:
            return name
        if paired_p.get(frozenset((name, best)), 0.0) >= alpha:
            return name
    return best


# Each animal group must be found this often for a detector set to be
# recommended (issue #4691): a set that boxes fish well and coral rarely is
# not chosen on a sample that is mostly fish.
GROUP_FLOOR = 0.70


def groups_below_floor(any_box_by_group, floor=GROUP_FLOOR):
    """The groups, sorted, whose share of held-out photos with any box is
    under `floor`. `any_box_by_group` maps a group to that share."""
    return sorted(group for group, share in any_box_by_group.items() if share < floor)


def breakdown(items, key, measure):
    """`measure` applied to each group of `items` sharing a `key`, keys
    sorted."""
    groups = {}
    for item in items:
        groups.setdefault(key(item), []).append(item)
    return {k: measure(groups[k]) for k in sorted(groups)}
