#!/usr/bin/env python3
"""The accuracy scorer's Markdown report (report.md) from its results.json,
for reading and for the findings. Split from score.py."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bars as bar_search  # noqa: E402
import manifest as pack_manifest  # noqa: E402


def _pct(rate):
    if not rate or rate.get("n", 0) == 0:
        return "n/a"
    return f"{rate['value']:.1%} ({rate['low']:.1%} to {rate['high']:.1%}, n {rate['n']})"


def _bar(value):
    return "never" if value >= bar_search.NEVER else f"{value:.2f}"


def write_report(results, path):
    """A Markdown summary of results.json, for reading and for the findings."""
    lines = [f"# Accuracy report, pack {results['pack']} ({results['candidates']} candidates)", ""]
    lines += ["## Bars after the held-out gate", ""]
    lines += ["| Run | minOpenScore | suggest | suggest, no location | confident | confident, no location | switched off |"]
    lines += ["| --- | --- | --- | --- | --- | --- | --- |"]
    for key, e in results["evaluations"].items():
        b = e["bars after held-out gate"]
        lines.append(
            f"| {key} | {b['min_open']:.2f} | {_bar(b['suggest'])} | {_bar(b['suggest_no_location'])} | "
            f"{_bar(b['confident'])} | {_bar(b['confident_no_location'])} | {', '.join(e['switched off']) or 'none'} |"
        )
    lines += ["", "## Naming levels", ""]
    lines += [
        "Under the published pack's bars when it has measured ones, else this run's (each run is listed "
        "below the table); each held to the same junk cap; precision and coverage with a location."
    ]
    lines += ["", "| Run | level | target | suggest | suggest, no location | precision | coverage | junk named |"]
    lines += ["| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for key, e in results["evaluations"].items():
        if not e.get("levels"):
            lines.append(f"| {key} | none | | | | | | |")
        for level in e.get("levels", []):
            b, h = level["bars"], level["held-out"]
            lines.append(
                f"| {key} | {level['id']} | {level['target']:.2f} | {_bar(b['suggest'])} | "
                f"{_bar(b['suggest_no_location'])} | {_pct(h['precision'])} | {_pct(h['coverage'])} | "
                f"{_pct(h['junk named'])} |"
            )
    lines.append("")
    for key, e in results["evaluations"].items():
        under = e.get("levels measured under")
        if under:
            source = "the published pack's bars" if under["published"] else "this run's bars"
            lines.append(f"- {key}: levels measured under {source}")
    # What the app would show a diver must read sensibly before it is
    # published (manifest.level_problems, which relevel_manifest.py enforces).
    for entry in results.get("measured", []):
        for problem in pack_manifest.level_problems(entry["naming"]):
            lines.append(f"- warning: {'+'.join(entry['detectorIds'])}: {problem}")
    lines += ["", "## Held-out natural sample", ""]
    lines += [
        "| Run | photos | any box | largest named right | top-1 / top-3 with location | "
        "top-1 / top-3 without | suggested: coverage | suggested: precision | confident: coverage | "
        "confident: precision | junk named |"
    ]
    lines += ["| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for key, e in results["evaluations"].items():
        d, s = e["held-out natural, detection"], e["held-out natural"]
        sw, cw = s["suggested"]["with location"], s["confident"]["with location"]
        lines.append(
            f"| {key} | {d['photos']} | {_pct(d['any box'])} | {_pct(d['largest box named right (top-1, no bars)'])} | "
            f"{s['top1 with location']:.1%} / {s['top3 with location']:.1%} | "
            f"{s['top1 without location']:.1%} / {s['top3 without location']:.1%} | {_pct(sw['coverage'])} | "
            f"{_pct(sw['precision'])} | {_pct(cw['coverage'])} | {_pct(cw['precision'])} | "
            f"{_pct(e['junk named (held-out)'])} |"
        )
    for section in ("by group (held-out, natural and top-up)", "by region", "by pack membership", "by habitat", "by box size"):
        lines += ["", f"## {section[0].upper()}{section[1:]}", ""]
        lines += ["| Run | group | crops | top-1 with location | suggested precision | suggested coverage |"]
        lines += ["| --- | --- | --- | --- | --- | --- |"]
        for key, e in results["evaluations"].items():
            for group, g in e[section].items():
                sw = g["suggested"]["with location"]
                lines.append(
                    f"| {key} | {group} | {g['crops']} | {g['top1 with location']:.1%} | "
                    f"{_pct(sw['precision'])} | {_pct(sw['coverage'])} |"
                )
    lines += ["", "## Crop fitting (centre crop against pad-to-square)", ""]
    for name, c in results["fitting comparison"].items():
        lines.append(
            f"- {name}: only centre crop right {c['only first']}, only pad-to-square right "
            f"{c['only second']}, p {c['p']:.3g}; chosen {results['fitting chosen'][name]}"
        )
    for name, m in results.get("fitting against the packs", {}).items():
        lines.append(
            f"- {name}: measured best with {m['chosen']}, but packs use {m['packs use']}; "
            "update CROP_FIT in manifest.py before pinning these bars"
        )
    lines += ["", "## Detectors", ""]
    for pair, c in results["detector comparison"].items():
        lines.append(f"- {pair}: only first right {c['only first']}, only second {c['only second']}, p {c['p']:.3g}")
    for name, n in results["named right per detector"].items():
        lines.append(f"- {name}: {n} held-out photos named right at its bars")
    for name, groups in results["groups below floor"].items():
        lines.append(f"- {name}: groups with a box in under 70% of held-out photos: {', '.join(groups) or 'none'}")
    lines.append(f"- recommended by the design's rule: {results['recommendation']}")
    lines += ["", "## The pair's merge", ""]
    for fit, a in results["pair agreement"].items():
        n = a["photos checked against boxes.py"]
        each = ", ".join(f"{name} {k}" for name, k in a["per-detector boxes equal to the single run"].items())
        lines.append(
            f"- {fit}: all {n} photos merged exactly as boxes.py merges the same run's boxes (the run stops "
            f"otherwise). Each detector's boxes in the pair run equal its single run on: {each}; the merged boxes "
            f"equal a merge of the single runs on {a['merged boxes equal to a merge of the single runs']}"
        )
    lines += ["", "## Speed and memory on this Mac", ""]
    lines += ["| Run | detect ms (median, p90) | embed ms per crop (median, p90) | peak memory of the whole run |"]
    lines += ["| --- | --- | --- | --- |"]
    for key, sp in results["speed"].items():
        mem = sp["peak memory bytes"]
        lines.append(
            f"| {key} | {sp['detect ms median'] or 0:.1f}, {sp['detect ms p90'] or 0:.1f} | "
            f"{sp['embed ms median'] or 0:.1f}, {sp['embed ms p90'] or 0:.1f} | "
            f"{mem / 1e9:.2f} GB |" if mem else f"| {key} | | | |"
        )
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
