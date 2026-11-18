#!/usr/bin/env python3
"""Merging two detectors' boxes, for measuring a pair of detectors run
together. Boxes are (x, y, w, h), normalised 0 to 1 with the origin top
left, as the vision pipeline reports them.

Standard library only, so its test runs in CI without the model tooling.
"""


def iou(a, b):
    """Intersection over union of two (x, y, w, h) boxes."""
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    ix = max(0.0, min(ax + aw, bx + bw) - max(ax, bx))
    iy = max(0.0, min(ay + ah, by + bh) - max(ay, by))
    inter = ix * iy
    union = aw * ah + bw * bh - inter
    return inter / union if union > 0 else 0.0


def best_match(target, candidates, *, min_iou=0.9):
    """The index of the candidate box overlapping `target` most, at
    `min_iou` or more, or None. Boxes are (x, y, w, h)."""
    best, best_iou = None, min_iou
    for i, box in enumerate(candidates):
        overlap = iou(target, box)
        if overlap >= best_iou:
            best, best_iou = i, overlap
    return best


def merge(runs, *, iou_threshold=0.5, max_boxes=8):
    """The boxes of several runs pooled, best score first, dropping any box
    that overlaps a kept one at or above `iou_threshold`, up to `max_boxes`.
    Each box is a dict with x, y, w, h and score; other fields ride along."""
    pooled = sorted((box for run in runs for box in run), key=lambda box: -box["score"])
    kept = []
    for box in pooled:
        rect = (box["x"], box["y"], box["w"], box["h"])
        if all(iou(rect, (k["x"], k["y"], k["w"], k["h"])) < iou_threshold for k in kept):
            kept.append(box)
            if len(kept) == max_boxes:
                break
    return kept


def _plain(box):
    return (box["x"], box["y"], box["w"], box["h"], box["score"])


def disagreements(results, *, iou_threshold=0.5, max_boxes=8):
    """The photos, sorted, where the app's merged boxes are not `merge` of
    that same run's per-detector boxes, exactly. `results` maps a photo to
    the vision tool's result with `detectorBoxes` and `mergedBoxes`; its
    `detections` must be those merged boxes in order, less any too small to
    crop."""
    bad = []
    for path, result in results.items():
        runs = result.get("detectorBoxes")
        merged = result.get("mergedBoxes")
        if runs is None or merged is None:
            bad.append(path)
            continue
        want = [_plain(b) for b in merge(runs, iou_threshold=iou_threshold, max_boxes=max_boxes)]
        got = [_plain(b) for b in merged]
        remaining = iter(got)
        in_order = all(any(_plain(d) == m for m in remaining) for d in result.get("detections", []))
        if got != want or not in_order:
            bad.append(path)
    return sorted(bad)
