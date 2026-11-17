#!/usr/bin/env python3
"""Scores a model pack against the accuracy test set, for each detector and
crop fitting, and chooses the naming bars (the measured accuracy design,
docs/design/specs/2026-11-17-marine-life-identification-measured-accuracy-design.md).

    python -I tool/species_pack/score.py --pack PACK

Runs the app's own vision pipeline (tool/species_pack/vision_cli) over every
photo, names each crop with naming.py, chooses bars with bars.py on the tune
half of the natural sample, gates them on the held-out half, and writes
report.md and results.json to the work folder. Needs numpy, Pillow and the
converted Megalodon model (megalodon.py). Developer-run; not part of CI.
"""

import argparse
import functools
import hashlib
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bars as bar_search  # noqa: E402
import boxes as box_math  # noqa: E402
import manifest as pack_manifest  # noqa: E402
import megalodon  # noqa: E402
import metrics  # noqa: E402
import naming  # noqa: E402
import region_grid  # noqa: E402
import testset  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_WORK = os.path.join(REPO, "build", "species_accuracy_work")
FITS = ("padSquare", "centreCrop")
MEGALODON = "megalodon-2024"
BOTH = "both"


# Running the vision tool.


def _read_json(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def _model_path(models_dir, name):
    compiled = os.path.join(models_dir, f"{name}.mlmodelc")
    return compiled if os.path.exists(compiled) else os.path.join(models_dir, f"{name}.mlpackage")


class Runner:
    """Runs the vision tool once per detector and fitting, cached by pack
    version, and keeps each run's results by photo path."""

    def __init__(self, pack, work):
        self.pack, self.work = pack, work
        with open(os.path.join(pack, "manifest.json"), encoding="utf-8") as fh:
            self.manifest = json.load(fh)
        self.version = self.manifest["packVersion"]
        # The models' own hashes, so a pack rebuilt under the same version
        # with other models is extracted again rather than read stale.
        self.model_hashes = {
            f["name"]: f["sha256"]
            for f in self.manifest["files"]
            if f["name"] in ("detector.coreml.zip", "classifier.coreml.zip")
        }
        self.models = os.path.join(work, "models", self.version)
        source = os.path.join(self.models, "source.json")
        if os.path.exists(self.models) and _read_json(source) != self.model_hashes:
            shutil.rmtree(self.models)
        os.makedirs(self.models, exist_ok=True)
        for name in ("detector", "classifier"):
            if not os.path.exists(os.path.join(self.models, f"{name}.mlmodelc")) and not os.path.exists(
                os.path.join(self.models, f"{name}.mlpackage")
            ):
                with zipfile.ZipFile(os.path.join(pack, f"{name}.coreml.zip")) as zf:
                    zf.extractall(self.models)
        with open(source, "w", encoding="utf-8") as fh:
            json.dump(self.model_hashes, fh)
        self.tool = os.path.join(work, "species_vision")
        subprocess.run([os.path.join(os.path.dirname(__file__), "vision_cli", "build.sh"), self.tool], check=True)
        mega_dir = megalodon.converted_dir(work, MEGALODON)
        self.mega_manifest = os.path.join(mega_dir, "manifest.json")
        with open(self.mega_manifest, "w", encoding="utf-8") as fh:
            json.dump(megalodon.manifest_for(MEGALODON, os.path.join(pack, "manifest.json")), fh)
        self.detectors = {
            self.manifest["detector"]["id"]: (os.path.join(pack, "manifest.json"), self.models),
            megalodon.CHECKPOINTS[MEGALODON]["id"]: (self.mega_manifest, mega_dir),
        }
        self.memory = {}

    def _fingerprint(self, detector, fit, photos):
        """What a run's output depends on: the photos, the detector's
        settings, the fitting, and the tool's source."""
        digest = hashlib.sha256()
        manifest, _ = self.detectors[detector]
        with open(manifest, encoding="utf-8") as fh:
            settings = json.load(fh)
        digest.update(
            json.dumps(
                [
                    sorted(photos),
                    settings["detector"],
                    settings["classifier"],
                    fit,
                    self.model_hashes,
                    megalodon.CHECKPOINTS[MEGALODON]["sha256"],
                ]
            ).encode()
        )
        here = os.path.dirname(os.path.abspath(__file__))
        for source in (
            os.path.join(here, "megalodon.py"),
            os.path.join(REPO, "packages", "submersion_vision", "darwin", "Classes", "VisionPipeline.swift"),
            os.path.join(here, "vision_cli", "main.swift"),
            os.path.join(here, "vision_cli", "FlutterShim.swift"),
        ):
            with open(source, "rb") as fh:
                digest.update(fh.read())
        return digest.hexdigest()

    def run(self, detector, fit, photos):
        out = os.path.join(self.work, "runs", f"{detector}_{fit}_{self.version}.jsonl")
        mem = out[: -len(".jsonl")] + ".time.txt"
        key_path = out[: -len(".jsonl")] + ".key"
        key = self._fingerprint(detector, fit, photos)
        stored = open(key_path, encoding="utf-8").read().strip() if os.path.exists(key_path) else None
        if not os.path.exists(out) or stored != key:
            os.makedirs(os.path.dirname(out), exist_ok=True)
            manifest, models_dir = self.detectors[detector]
            with open(out + ".partial", "w", encoding="utf-8") as fh, open(mem, "w", encoding="utf-8") as err:
                subprocess.run(
                    [
                        "/usr/bin/time",
                        "-l",
                        self.tool,
                        "--manifest",
                        manifest,
                        "--detector",
                        _model_path(models_dir, "detector"),
                        "--classifier",
                        _model_path(self.models, "classifier"),
                        "--crop-fit",
                        fit,
                    ],
                    input="\n".join(photos) + "\n",
                    stdout=fh,
                    stderr=err,
                    text=True,
                    check=True,
                )
            os.replace(out + ".partial", out)
            with open(key_path, "w", encoding="utf-8") as fh:
                fh.write(key + "\n")
        with open(mem, encoding="utf-8") as fh:
            m = re.search(r"(\d+)\s+maximum resident set size", fh.read())
        self.memory[(detector, fit)] = int(m.group(1)) if m else None
        results = {}
        with open(out, encoding="utf-8") as fh:
            for line in fh:
                r = json.loads(line)
                results[r["path"]] = r
        # A photo with no result, or one the tool could not read, is not a
        # photo where the detector found nothing.
        failed = [p for p in photos if p not in results or "error" in results[p]]
        if failed:
            raise SystemExit(f"{detector} {fit}: {len(failed)} photos have no usable result, for example {failed[:2]}")
        return results


# Naming.


class Namer:
    """The pack's candidates, text embeddings and region table, naming
    embeddings as the app does. Logits and region masks take fast paths
    that are checked against naming.py on the first crops."""

    def __init__(self, pack, manifest):
        import numpy as np

        self.np = np
        with open(os.path.join(pack, "candidates.json"), encoding="utf-8") as fh:
            self.candidates = json.load(fh)
        size = manifest["classifier"]["embeddingSize"]
        self.text = (
            np.fromfile(os.path.join(pack, "text_embeddings.f16"), dtype="<f2")
            .astype(np.float64)
            .reshape(len(self.candidates), size)
        )
        with open(os.path.join(pack, "regions.bin"), "rb") as fh:
            self.bits = fh.read()
        self.scale = manifest["classifier"]["logitScale"]
        self.config = manifest["naming"]
        self.cell_degrees = manifest["region"]["cellDegrees"]
        self.rings = manifest["region"]["neighbourCells"]
        self.index = {c["gbifKey"]: i for i, c in enumerate(self.candidates)}
        self.checked = 0

    @functools.lru_cache(maxsize=None)
    def _base_mask(self, cell):
        cells = region_grid.neighbourhood(cell, self.rings, self.cell_degrees)
        return tuple(region_grid.allowed_mask(self.bits, len(self.candidates), cells, self.cell_degrees))

    def _allowed(self, cell, overrides):
        if cell is None:
            return None
        mask = list(self._base_mask(cell))
        for i, allowed in overrides.items():
            mask[i] = allowed
        count = sum(mask)
        return mask if count and count >= self.config["minAllowedCandidates"] else None

    def name(self, embedding, cell, overrides):
        """(with location, without location) namings of one embedding."""
        e = self.np.asarray(embedding, dtype=self.np.float64)
        norm = self.np.linalg.norm(e)
        if not norm or not self.np.isfinite(norm):
            return None, None
        logits = (self.text @ (e / norm) * self.scale).tolist()
        allowed = self._allowed(cell, overrides)
        if self.checked < 20:
            slow = naming.logits(naming.unit(list(embedding)), self.text.tolist(), self.scale)
            if max(abs(a - b) for a, b in zip(slow, logits)) >= 1e-6:
                raise SystemExit("fast logits disagree with naming.py")
            slow_mask = naming.allowed_for(
                cell,
                self.bits,
                len(self.candidates),
                cell_degrees=self.cell_degrees,
                rings=self.rings,
                min_allowed=self.config["minAllowedCandidates"],
                overrides=overrides,
            )
            if slow_mask != allowed:
                raise SystemExit("fast region mask disagrees with naming.py")
            self.checked += 1
        top_k = self.config["topK"]
        return naming.name(logits, allowed, top_k), naming.name(logits, None, top_k)


# One crop's record.


def _crop_record(row, detection, namer, junk_cell=None):
    label = namer.index.get(int(row["gbif_key"])) if row["gbif_key"] else None
    if row["source"] == "commons":
        cell, overrides = junk_cell, {}
    else:
        cell = region_grid.cell_of(float(row["lat"]), float(row["lon"]), namer.cell_degrees)
        # A test photo must not vouch for its own species' place: with no
        # record before the cutoff, the label species is not allowed there.
        # It can only switch the pack's bit off, never on, as the app reads
        # the pack's table alone.
        overrides = {label: False} if label is not None and row["recorded_before_cutoff"] != "yes" else {}
    with_loc, no_loc = namer.name(detection["embedding"], cell, overrides)
    if with_loc is None:
        return None
    side = min(detection["pixelWidth"], detection["pixelHeight"])

    def scored(n):
        top = n.ranked[0] if n.ranked else (None, 0.0)
        return bar_search.Scored(
            open_score=n.open_score,
            top_score=top[1],
            correct=label is not None and top[0] == label,
            shorter_side=side,
            limited=n.location_limited,
        )

    def rank(n):
        order = [i for i, _ in n.ranked]
        return order.index(label) if label in order else None

    return {
        "row": row,
        "with": scored(with_loc),
        "without": scored(no_loc),
        "rank_with": rank(with_loc),
        "rank_without": rank(no_loc),
        "in_pack": label is not None,
        "side": side,
    }


def _key(row):
    return (row["source"], row["id"])


def _largest(detections):
    return max(detections, key=lambda d: d["pixelWidth"] * d["pixelHeight"]) if detections else None


# Scoring one detector and fitting.


def _photo(work, row):
    return os.path.join(work, "photos", f"{row['source']}_{row['id']}.jpg")


def _junk_records(name, results_by_photo, junk_rows, namer, work, fish_cells):
    """Each junk row named from the detection it labels, found by its box
    (an intersection over union of 0.9 or more). A single detector's run
    must find every one of its rows among its own boxes, or the junk check
    would pass on nothing. In a merged run a row may match a box from
    either detector, since the other detector's box can have replaced its
    own, and each merged box counts once however many rows match it."""
    records, missing, used = [], [], set()
    for row in sorted(junk_rows, key=lambda r: (r["id"], r["detector"], int(r["box"]))):
        if name != BOTH and row["detector"] != name:
            continue
        key = f"{row['detector']}:{row['id']}:{row['box']}"
        path = _photo(work, row)
        detections = [
            (i, d)
            for i, d in enumerate((results_by_photo.get(path) or {}).get("detections", []))
            if ((path, i) not in used if name == BOTH else d.get("source") == row["detector"])
        ]
        target = tuple(float(row[k]) for k in ("box_x", "box_y", "box_w", "box_h"))
        found = box_math.best_match(target, [(d["x"], d["y"], d["w"], d["h"]) for _, d in detections])
        if found is None:
            missing.append(key)
            continue
        index, detection = detections[found]
        used.add((path, index))
        cell = fish_cells[int(hashlib.sha256(key.encode()).hexdigest(), 16) % len(fish_cells)]
        record = _crop_record(row, detection, namer, junk_cell=cell)
        if record:
            records.append(record)
    if missing and name != BOTH:
        raise SystemExit(f"{name}: {len(missing)} junk rows match no box in this run, for example {missing[:3]}")
    return records


def evaluate(name, results_by_photo, animals, junk_rows, namer, work, min_side, tune):
    """Every number for one detector (or merged pair) and fitting.
    `results_by_photo` maps a photo path to its detections, each tagged
    with the detector (`source`) that found it."""
    natural = [r for r in animals if r["sample"] == "natural"]
    if not natural:
        raise SystemExit("the test set has no underwater photos in its natural sample")
    fish_cells = [region_grid.cell_of(float(r["lat"]), float(r["lon"]), namer.cell_degrees) for r in natural]

    crops = {}
    any_box = {}
    for row in animals:
        detections = (results_by_photo.get(_photo(work, row)) or {}).get("detections", [])
        any_box[row["id"]] = bool(detections)
        biggest = _largest(detections)
        if biggest is not None:
            record = _crop_record(row, biggest, namer)
            if record:
                crops[row["id"]] = record

    junk = _junk_records(name, results_by_photo, junk_rows, namer, work, fish_cells)

    def half(records, want_tune):
        return [c for c in records if (_key(c["row"]) in tune) == want_tune]

    nat = [crops[r["id"]] for r in natural if r["id"] in crops]
    tune_nat, held_nat = half(nat, True), half(nat, False)
    tune_junk, held_junk = half(junk, True), half(junk, False)
    if not tune_junk:
        raise SystemExit(f"{name}: no junk crops in the tune half, so the junk check would test nothing")
    chosen = bar_search.choose_bars(
        [c["with"] for c in tune_nat],
        [c["without"] for c in tune_nat],
        [c["with"] for c in tune_junk],
        [c["without"] for c in tune_junk],
        min_side=min_side,
    )
    gated, switched_off = bar_search.held_out_gate(
        chosen, [c["with"] for c in held_nat], [c["without"] for c in held_nat], min_side=min_side
    )

    def naming_rates(records, confident=False):
        out = {}
        for key, condition in (("with location", "with"), ("without location", "without")):
            scored = [c[condition] for c in records]
            named = bar_search.named(scored, gated, min_side=min_side, confident=confident)
            coverage, precision = metrics.coverage_precision(named, [s.correct for s in scored])
            out[key] = {"coverage": coverage.__dict__, "precision": precision.__dict__}
        return out

    def summary(records):
        return {
            "crops": len(records),
            "top1 with location": metrics.top_k([c["rank_with"] for c in records], 1),
            "top3 with location": metrics.top_k([c["rank_with"] for c in records], 3),
            "top1 without location": metrics.top_k([c["rank_without"] for c in records], 1),
            "top3 without location": metrics.top_k([c["rank_without"] for c in records], 3),
            "suggested": naming_rates(records),
            "confident": naming_rates(records, confident=True),
        }

    held_rows = [r for r in animals if _key(r) not in tune]
    held_all = [crops[r["id"]] for r in held_rows if r["id"] in crops]
    held_natural_rows = [r for r in held_rows if r["sample"] == "natural"]

    def recall(rows):
        found = sum(1 for r in rows if any_box.get(r["id"]))
        named_right = sum(1 for r in rows if r["id"] in crops and crops[r["id"]]["rank_with"] == 0)
        return {
            "any box": metrics.rate(found, len(rows)).__dict__,
            "largest box named right (top-1, no bars)": metrics.rate(named_right, len(rows)).__dict__,
        }

    def correct_at_bars(rows):
        """Per photo: whether its labelled animal was named right at the bars."""
        out = {}
        for r in rows:
            c = crops.get(r["id"])
            out[r["id"]] = bool(
                c and bar_search.named([c["with"]], gated, min_side=min_side)[0] and c["with"].correct
            )
        return out

    junk_named = [
        a or b
        for a, b in zip(
            bar_search.named([c["with"] for c in held_junk], gated, min_side=min_side),
            bar_search.named([c["without"] for c in held_junk], gated, min_side=min_side),
        )
    ]
    curve = []
    limited = [c["with"] for c in held_nat if c["with"].limited]
    for bar in bar_search.BAR_GRID[::5]:
        picked = [s for s in limited if s.shorter_side >= min_side and s.open_score >= gated.min_open and s.top_score >= bar]
        curve.append(
            {
                "suggestScore": bar,
                "coverage": len(picked) / len(limited) if limited else 0.0,
                "precision": sum(s.correct for s in picked) / len(picked) if picked else None,
            }
        )
    return {
        "detector": name,
        "bars chosen on tune": chosen.__dict__,
        "bars after held-out gate": gated.__dict__,
        "switched off": switched_off,
        "held-out natural": summary(held_nat),
        "held-out natural, detection": {
            "photos": len(held_natural_rows),
            **recall(held_natural_rows),
            "largest box at least 64 px": metrics.rate(
                sum(1 for r in held_natural_rows if r["id"] in crops and crops[r["id"]]["side"] >= 64),
                len(held_natural_rows),
            ).__dict__,
        },
        "fallback to no location": metrics.rate(
            sum(1 for c in held_nat if not c["with"].limited), len(held_nat)
        ).__dict__,
        "junk named (tune, at the chosen bars)": bar_search.junk_rate(
            [c["with"] for c in tune_junk], [c["without"] for c in tune_junk], chosen, min_side=min_side
        ),
        "junk named (held-out)": metrics.rate(sum(junk_named), len(junk_named)).__dict__,
        "junk crops": {"tune": len(tune_junk), "held-out": len(held_junk)},
        "by group (held-out, natural and top-up)": metrics.breakdown(
            held_rows, lambda r: r["group"], lambda rows: {**recall(rows), **summary([crops[r["id"]] for r in rows if r["id"] in crops])}
        ),
        "by region": metrics.breakdown(held_nat, lambda c: c["row"]["region"], summary),
        "by pack membership": metrics.breakdown(held_nat, lambda c: "in pack" if c["in_pack"] else "not in pack", summary),
        "by habitat": metrics.breakdown(held_nat, lambda c: c["row"]["habitat"] or "unknown", summary),
        "by box size": metrics.breakdown(held_nat, lambda c: metrics.size_bucket(c["side"]), summary),
        "curve": curve,
        "_correct_at_bars": correct_at_bars(held_natural_rows),
        "_suggested_correct": {
            c["row"]["id"]: bool(bar_search.named([c["with"]], gated, min_side=min_side)[0] and c["with"].correct)
            for c in held_nat
        },
        "_all": held_all,
    }


def _timings(results):
    detect = [r["detectMs"] for r in results.values() if "detectMs" in r]
    embed = [d["embedMs"] for r in results.values() for d in r.get("detections", []) if "embedMs" in d]

    def p(values, q):
        return statistics.quantiles(values, n=10)[q - 1] if len(values) >= 10 else None

    return {
        "detect ms median": statistics.median(detect) if detect else None,
        "detect ms p90": p(detect, 9),
        "embed ms median": statistics.median(embed) if embed else None,
        "embed ms p90": p(embed, 9),
    }


def _labelled(results, detector):
    """Each detection tagged with the detector that found it."""
    return {
        path: dict(r, detections=[dict(d, source=detector) for d in r.get("detections", [])])
        for path, r in results.items()
    }


def _merged(a, b, max_boxes):
    out = {}
    for path in set(a) | set(b):
        runs = [a.get(path, {}).get("detections", []), b.get(path, {}).get("detections", [])]
        out[path] = {"path": path, "detections": box_math.merge(runs, iou_threshold=0.5, max_boxes=max_boxes)}
    return out


def _paired(a, b):
    only_a = sum(1 for k in a if a[k] and not b.get(k))
    only_b = sum(1 for k in b if b[k] and not a.get(k))
    return {"only first": only_a, "only second": only_b, "p": bar_search.mcnemar_p(only_a, only_b)}


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
    lines += ["", "## Detectors", ""]
    for pair, c in results["detector comparison"].items():
        lines.append(f"- {pair}: only first right {c['only first']}, only second {c['only second']}, p {c['p']:.3g}")
    for name, n in results["named right per detector"].items():
        lines.append(f"- {name}: {n} held-out photos named right at its bars")
    lines.append(f"- recommended by the design's rule: {results['recommendation']}")
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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--pack", required=True)
    parser.add_argument("--set", default=os.path.join(os.path.dirname(__file__), "testdata", "accuracy_set.csv"))
    parser.add_argument("--work", default=DEFAULT_WORK)
    args = parser.parse_args(argv)

    rows = testset.read_rows(args.set)
    animals = [r for r in rows if r["source"] == "inaturalist" and r["underwater"] == "yes"]
    junk_rows = [r for r in rows if r["source"] == "commons"]
    missing = sorted({_photo(args.work, r) for r in animals + junk_rows if not os.path.exists(_photo(args.work, r))})
    if missing:
        raise SystemExit(
            f"{len(missing)} test photos are not in {args.work}/photos, for example {missing[:2]}; "
            "fetch them with fetch_testset.py photos-from-csv"
        )
    # Keyed by source and id: an iNaturalist id and a Commons page id can
    # be the same number.
    tune = (
        {("inaturalist", i) for i in testset.tune_ids([r for r in animals if r["sample"] == "natural"])}
        | {("inaturalist", i) for i in testset.tune_ids([r for r in animals if r["sample"] == "top-up"])}
        | {("commons", i) for i in testset.tune_ids(junk_rows)}
    )

    runner = Runner(args.pack, args.work)
    namer = Namer(args.pack, runner.manifest)
    min_side = runner.manifest["naming"]["minCropSide"]
    max_boxes = runner.manifest["detector"]["maxBoxes"]
    commons = sorted({_photo(args.work, r) for r in junk_rows})
    photos = [_photo(args.work, r) for r in animals] + commons
    cfd = runner.manifest["detector"]["id"]
    mega = megalodon.CHECKPOINTS[MEGALODON]["id"]

    results = {
        "pack": runner.version,
        "candidates": len(namer.candidates),
        # What NAMING_MEASURED in manifest.py needs to name this exact pack.
        "detectorId": cfd,
        "classifierId": runner.manifest["classifier"]["id"],
        "contents": pack_manifest.contents_of(runner.manifest["files"]),
        "evaluations": {},
        "speed": {},
    }
    kept = {}
    for fit in FITS:
        runs = {}
        for detector in (cfd, mega):
            raw = runner.run(detector, fit, photos)
            runs[detector] = _labelled(raw, detector)
            results["speed"][f"{detector} {fit}"] = {
                **_timings(raw),
                "peak memory bytes": runner.memory.get((detector, fit)),
            }
        runs[BOTH] = _merged(runs[cfd], runs[mega], max_boxes)
        for name, by_photo in runs.items():
            key = f"{name} {fit}"
            print(f"scoring {key}", flush=True)
            kept[key] = evaluate(name, by_photo, animals, junk_rows, namer, args.work, min_side, tune)

    for name in (cfd, mega, BOTH):
        results.setdefault("fitting comparison", {})[name] = _paired(
            kept[f"{name} centreCrop"]["_suggested_correct"], kept[f"{name} padSquare"]["_suggested_correct"]
        )
    detectors = {}
    for name in (cfd, mega, BOTH):
        better = (
            "centreCrop" if results["fitting comparison"][name]["p"] < 0.05
            and results["fitting comparison"][name]["only first"] > results["fitting comparison"][name]["only second"]
            else "padSquare"
        )
        detectors[name] = kept[f"{name} {better}"]["_correct_at_bars"]
        results.setdefault("fitting chosen", {})[name] = better
    results["detector comparison"] = {
        f"{a} vs {b}": _paired(detectors[a], detectors[b]) for a, b in ((mega, cfd), (BOTH, cfd), (BOTH, mega))
    }
    for key, value in kept.items():
        results["evaluations"][key] = {k: v for k, v in value.items() if not k.startswith("_")}
    results["named right per detector"] = {name: sum(v.values()) for name, v in detectors.items()}
    # Simplest first: one explicitly licensed detector, then the other, then
    # the pair.
    preference = [mega, cfd, BOTH]
    junk_ok = {
        name: kept[f"{name} {results['fitting chosen'][name]}"]["junk named (tune, at the chosen bars)"] <= 0.02
        for name in preference
    }
    paired = {
        frozenset((a, b)): _paired(detectors[a], detectors[b])["p"]
        for a, b in ((mega, cfd), (BOTH, cfd), (BOTH, mega))
    }
    results["recommendation"] = metrics.recommend(results["named right per detector"], paired, preference, junk_ok)

    os.makedirs(args.work, exist_ok=True)
    with open(os.path.join(args.work, "results.json"), "w", encoding="utf-8") as fh:
        json.dump(results, fh, indent=1, default=str)
    write_report(results, os.path.join(args.work, "report.md"))
    print(f"wrote {os.path.join(args.work, 'results.json')} and report.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
