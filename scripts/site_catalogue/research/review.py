#!/usr/bin/env python3
"""The page a batch of researched sites is approved from.

    python3 scripts/site_catalogue/research/check.py --review OUT

One self-contained HTML file, with no scripts and nothing fetched: per
area, every entry waiting for a decision, each with the point that would
ship, a map link to it, every page's figure with its distance from that
point, the depth, entry, type and hazards it would carry, and the line it
would carry as its description. Entries that break a rule are listed with
the rule and are not offered for approval. Entries already approved or
rejected are folded at the end.

The page writes nothing back. The maintainer's answers are written into
each entry's `review` by hand.
"""

import html
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_CATALOGUE = os.path.dirname(_HERE)
for _path in (_HERE, _CATALOGUE, os.path.dirname(_CATALOGUE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import evidence  # noqa: E402
import src_research  # noqa: E402

_STYLE = """
:root { color-scheme: light dark; --muted: #667; --line: #ccd; --bad: #a33; }
@media (prefers-color-scheme: dark) { :root { --muted: #99a; --line: #445; --bad: #e88; } }
body { font: 15px/1.45 system-ui, sans-serif; margin: 24px auto; max-width: 980px; padding: 0 16px; }
h1 { font-size: 22px; } h2 { font-size: 18px; margin-top: 32px; border-bottom: 1px solid var(--line); }
.entry { border: 1px solid var(--line); border-radius: 8px; padding: 12px 16px; margin: 12px 0; }
.entry h3 { margin: 0 0 4px; font-size: 16px; } .id { color: var(--muted); font-family: monospace; }
table { border-collapse: collapse; width: 100%; } td { padding: 2px 8px 2px 0; vertical-align: top; }
td:first-child { color: var(--muted); width: 110px; } .fail { color: var(--bad); }
.decision { margin-top: 8px; font-weight: 600; } .left { color: var(--muted); }
.flag { font-style: italic; }
"""


def _e(text) -> str:
    return html.escape(str(text), quote=True)


def _metres(value: float) -> str:
    return f"{value:,.0f} m"


def _domain(url: str) -> str | None:
    """The page's domain, or None when [url] names no host: a malformed
    source is shown as written, not allowed to stop the page."""
    try:
        return evidence.registrable_domain(url)
    except ValueError:
        return None


def _figure(source: dict) -> str:
    return f"{source.get('lat')}, {source.get('lon')}"


def _map_link(lat: float, lon: float) -> str:
    url = (
        f"https://www.openstreetmap.org/?mlat={lat:.6f}&mlon={lon:.6f}"
        f"#map=17/{lat:.6f}/{lon:.6f}"
    )
    return f'<a href="{_e(url)}">map</a>'


# How each route placed the site, as the reviewer reads it.
_ROUTES = {
    "confirmed": "two stated figures that agree",
    "stated": "one stated figure",
    "map": "a counting page's map",
}


def _named_rows(checked, domains) -> list[str]:
    """The pages that name the site: for a stated or map-read site, the
    only proof it exists."""
    named = checked.entry.get("named")
    if not isinstance(named, dict):
        return []
    rows = [f"<tr><td>Named in</td><td>{_e(named.get('place') or '(no place)')}</td></tr>"]
    for source in named.get("sources") or []:
        if not isinstance(source, dict):
            continue
        url = source.get("url")
        url = url if isinstance(url, str) else ""
        domain = _domain(url)
        kind = domains.kind_of(url) or "on no list"
        link = f'<a href="{_e(url)}">page</a>' if domain else ""
        rows.append(
            f"<tr><td></td><td>{_e(domain or url or '(no address)')} &nbsp; "
            f"{_e(kind.replace('_', ' '))} &nbsp; {link}</td></tr>"
        )
    return rows


def _between_row(position: dict, domains) -> list[str]:
    """The distance between the two counting figures, when there are two."""
    points = []
    for source in position.get("sources") or []:
        if not isinstance(source, dict) or not isinstance(source.get("url"), str):
            continue
        if domains.kind_of(source["url"]) != "counting":
            continue
        try:
            points.append((
                evidence.parse_coordinate(source.get("lat"), "lat")[0],
                evidence.parse_coordinate(source.get("lon"), "lon")[0],
            ))
        except ValueError:
            return []
    if len(points) != 2:
        return []
    apart = _metres(evidence.metres_between(*points[0], *points[1]))
    return [f"<tr><td>Between figures</td><td>{_e(apart)}</td></tr>"]


def _position_rows(checked, domains) -> list[str]:
    position = checked.entry.get("position") or {}
    rows = []
    if checked.position:
        lat, lon = checked.position
        rows.append(f"<tr><td>Position</td><td>{lat:.6f}, {lon:.6f} "
                    f"[{_map_link(lat, lon)}]</td></tr>")
    if checked.route in _ROUTES:
        rows.append(f"<tr><td>Placed by</td><td>{_e(_ROUTES[checked.route])}</td></tr>")
    for source in position.get("sources") or []:
        if not isinstance(source, dict):
            continue
        url = source.get("url")
        url = url if isinstance(url, str) else ""
        kind = domains.kind_of(url) or "on no list"
        distance = ""
        if checked.position:
            try:
                lat, _ = evidence.parse_coordinate(source.get("lat"), "lat")
                lon, _ = evidence.parse_coordinate(source.get("lon"), "lon")
                distance = _metres(evidence.metres_between(*checked.position, lat, lon))
            except ValueError:
                distance = "unreadable"
        domain = _domain(url)
        where = domain or url or "(no address)"
        link = f'<a href="{_e(url)}">page</a>' if domain else ""
        # A map reading names the image it was read off; a stated pin on the
        # publisher's embedded map names the map's layer.
        image = source.get("map")
        if isinstance(image, str) and _domain(image):
            label = "map image" if source.get("method") == "map" else "map layer"
            link += f' <a href="{_e(image)}">{label}</a>'
        rows.append(
            f"<tr><td></td><td>{_e(where)} "
            f"&nbsp; {_e(_figure(source))} &nbsp; {_e(distance)} &nbsp; "
            f"{_e(kind.replace('_', ' '))} &nbsp; {link}</td></tr>"
        )
    return rows + _between_row(position, domains)


def _depth(checked) -> str:
    if checked.max_depth is None:
        return "none"
    if checked.min_depth is not None:
        return f"{checked.min_depth:g} to {checked.max_depth:g} m"
    return f"to {checked.max_depth:g} m"


def _entry_html(checked, domains) -> str:
    entry = checked.entry
    rows = _named_rows(checked, domains) + _position_rows(checked, domains)
    rows.append(f"<tr><td>Depth</td><td>{_e(_depth(checked))}</td></tr>")
    rows.append(f"<tr><td>Entry</td><td>{_e(', '.join(checked.entries) or 'none')}</td></tr>")
    rows.append(f"<tr><td>Type</td><td>{_e(', '.join(checked.types) or 'none')}</td></tr>")
    hazards = evidence.hazards_text(checked.hazards) or "none"
    rows.append(f"<tr><td>Hazards</td><td>{_e(hazards)}</td></tr>")
    line = src_research.describe(checked.entries, checked.types) or "(no description)"
    rows.append(f"<tr><td>Ships as</td><td>{_e(line)}</td></tr>")
    for left in checked.left_out:
        rows.append(f'<tr><td></td><td class="left">{_e(left)}</td></tr>')
    if entry.get("note"):
        rows.append(f"<tr><td>Note</td><td>{_e(entry['note'])}</td></tr>")
    for flag in checked.flags:
        rows.append(f'<tr><td>Check</td><td class="flag">{_e(flag.rule)}: '
                    f"{_e(flag.message)}</td></tr>")
    failures = [f for f in checked.findings if f.fatal]
    for finding in failures:
        rows.append(f'<tr><td class="fail">{_e(finding.rule)}</td>'
                    f'<td class="fail">{_e(finding.message)}</td></tr>')
    if failures:
        decision = '<div class="decision fail">Not offered for approval</div>'
    elif checked.state == "pending":
        decision = '<div class="decision">Approve or reject</div>'
    else:
        decision = f'<div class="decision">{_e(checked.state.capitalize())}</div>'
    status = "fail" if failures else "pass"
    return (
        f'<div class="entry {status}"><h3>{_e(entry.get("name") or "(no name)")}</h3>'
        f'<div class="id">{_e(checked.id)} &middot; {_e(checked.state)}</div>'
        f"<table>{''.join(rows)}</table>{decision}</div>"
    )


def render(checked: list, domains) -> str:
    """The review page for every checked entry."""
    parts = ["<!doctype html>", '<html lang="en"><head><meta charset="utf-8">',
             '<meta name="viewport" content="width=device-width, initial-scale=1">',
             f"<title>Researched sites review</title><style>{_STYLE}</style></head><body>",
             "<h1>Researched sites review</h1>"]
    if not checked:
        parts.append("<p>No researched sites.</p></body></html>")
        return "\n".join(parts)
    open_ = [c for c in checked if c.state == "pending" or not c.ok]
    decided = [c for c in checked if c not in open_]
    areas: dict[str, list] = {}
    for item in open_:
        areas.setdefault(str(item.entry.get("area") or "(no area)"), []).append(item)
    for area in sorted(areas):
        group = areas[area]
        passing = sum(1 for c in group if c.ok)
        parts.append(
            f"<h2>{_e(area)} ({len(group)} entries: {passing} pass, "
            f"{len(group) - passing} fail)</h2>"
        )
        parts.extend(_entry_html(c, domains) for c in group)
    if decided:
        parts.append(f"<details><summary>Already decided ({len(decided)})</summary>")
        parts.extend(_entry_html(c, domains) for c in decided)
        parts.append("</details>")
    parts.append("</body></html>")
    return "\n".join(parts)
