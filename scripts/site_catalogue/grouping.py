#!/usr/bin/env python3
"""Deployments into sites.

A reef program lists what was sunk and where: one reef is dozens of rows
a few metres apart, and a mooring field is a buoy per boat. A diver names
the reef. Rows of one name that lie within a kilometre of each other are
one site; the same name farther off is another site.
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
for _path in (_HERE, os.path.dirname(_HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

from records import fold_name, km  # noqa: E402


def group_by_name(
    items: list[dict], *, radius_km: float = 1.0, name_of=None
) -> list[list[dict]]:
    """[items] (dicts with `lat` and `lon`) as groups of one site each.

    Two items share a group when their names fold alike and a chain of
    items of that name links them, each within [radius_km] of the next.
    The groups do not depend on the order of [items].
    """
    name_of = name_of or (lambda item: item["name"])
    by_name: dict[str, list[dict]] = {}
    for item in items:
        name = name_of(item)
        by_name.setdefault(fold_name(name) or name.strip().lower(), []).append(item)

    groups: list[list[dict]] = []
    for same_name in by_name.values():
        chains: list[list[dict]] = []
        for item in same_name:
            linked = [
                chain
                for chain in chains
                if any(
                    km(item["lat"], item["lon"], other["lat"], other["lon"])
                    <= radius_km
                    for other in chain
                )
            ]
            if not linked:
                chains.append([item])
                continue
            linked[0].append(item)
            for chain in linked[1:]:
                linked[0].extend(chain)
                chains.remove(chain)
        groups.extend(chains)
    return groups


def mean_position(items: list[dict]) -> tuple[float, float]:
    """The mean latitude and longitude of [items]."""
    return (
        sum(item["lat"] for item in items) / len(items),
        sum(item["lon"] for item in items) / len(items),
    )
