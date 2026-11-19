#!/usr/bin/env python3
"""The model pack manifest: what the app reads to download, verify and run
a pack (lib/features/species_id/domain/entities/species_pack_manifest.dart).

Standard library only, so its test runs in CI without the model tooling.
"""

import copy
import hashlib
import json
import os
import zipfile

# Format 2 (issue #4691): one or two detectors, each in its own format.
FORMAT_VERSION = 2

# The detectors a pack can carry. Change one only with its model. Each is
# run as the scorer measured it: the fish detector with the spike's
# settings, Megalodon with ultralytics' defaults.
DETECTORS = {
    "cfd": {
        "id": "cfd-rfdetr-nano-640-20260706",
        "format": "rfdetr",
        "file": "detector",
        "inputSize": 640,
        "mean": [0.485, 0.456, 0.406],
        "std": [0.229, 0.224, 0.225],
        "scoreThreshold": 0.3,
        "maxBoxes": 8,
    },
    "megalodon": {
        "id": "megalodon-yolo11x-403704d",
        "format": "yolo",
        "file": "detector-megalodon",
        "inputSize": 640,
        "mean": [0.0, 0.0, 0.0],
        "std": [1.0, 1.0, 1.0],
        "scoreThreshold": 0.25,
        "maxBoxes": 8,
    },
}
# What a pack can carry, in the order their boxes are pooled.
DETECTOR_SETS = {"cfd": ("cfd",), "megalodon": ("megalodon",), "both": ("cfd", "megalodon")}
# How a crop is fitted to the classifier's square input, per detector set,
# as measured (measured accuracy findings): centre crop named significantly
# more right with the fish detector and with the pair; for Megalodon alone
# the two did not differ, so pad-to-square stays.
CROP_FIT = {"cfd": "centreCrop", "megalodon": "padSquare", "both": "centreCrop"}
# Two detectors' boxes are merged as the scorer merged them (boxes.py).
BOXES = {"mergeIoU": 0.5, "maxBoxes": 8, "cropPadding": 0.10}
CLASSIFIER_SETTINGS = {
    "inputSize": 224,
    "mean": [0.48145466, 0.4578275, 0.40821073],
    "std": [0.26862954, 0.26130258, 0.27577711],
    "logitScale": 100.0,
}

# Provisional: set by eye in the spike against 685 candidates. Replaced by
# measured values before the feature is turned on (program design).
NAMING_PROVISIONAL = {
    "provisional": True,
    "minCropSide": 64,
    "minOpenScore": 0.15,
    "suggestScore": 0.50,
    "confidentScore": 0.70,
    "suggestScoreNoLocation": 0.70,
    "confidentScoreNoLocation": 0.70,
    "minAllowedCandidates": 200,
    "topK": 5,
}
# The pack files that decide how a crop is named, besides the models: the
# candidates, their text embeddings, and where each has been recorded.
CONTENT_FILES = ("candidates.json", "text_embeddings.f16", "regions.bin")

# Measured bars (tool/species_pack/score.py), one entry per measured
# detector set. They hold only for the exact pack they were measured on: the
# same detectors in the same order, classifier and crop fitting, and the
# same naming files byte for byte. Any other pack, a rebuilt candidate list
# of the same size included, gets the provisional bars until the scorer is
# run on it. A bar of 1.01 is never: no confident names, since at each
# set's chosen fitting no bar proved 95% right. Measured on the pack with
# surveyed species (9,151 candidates); the earlier 7,646 pack's bars no
# longer apply. Each set's `precision` (its own bars, held-out, with a
# location) and naming levels (issue #4721) were measured on pack
# 2026.11.18.0356 under these bars.
_MEASURED_CONTENTS = {
    "candidates.json": "4f0dc61c95ab06de3a0b2ecb1401260e23907c3d2ff09d2da165bd9c8c34d50c",
    "text_embeddings.f16": "9aa97fc27a4b91039bd8eb9b6ad7be2da0cc97e4818a1ad81bb7f61b111cde33",
    "regions.bin": "f07736bd1c38fb5321b1900ebf0ab51555a9cf0715af4f364292202d953e4bcd",
}
_FINDINGS = "docs/design/findings/2026-11-17-marine-life-measured-accuracy.md"
NAMING_MEASURED = [
    {
        "naming": {
            "provisional": False,
            "minCropSide": 64,
            "minOpenScore": 0.39,
            "suggestScore": 0.64,
            "confidentScore": 1.01,
            "suggestScoreNoLocation": 0.79,
            "confidentScoreNoLocation": 1.01,
            "minAllowedCandidates": 200,
            "topK": 5,
            "precision": 0.871,
            "levels": [
                {
                    "id": "balanced",
                    "target": 0.75,
                    "suggestScore": 0.25,
                    "suggestScoreNoLocation": 0.56,
                    "precision": 0.821,
                },
                {
                    "id": "eager",
                    "target": 0.65,
                    "suggestScore": 0.25,
                    "suggestScoreNoLocation": 0.39,
                    "precision": 0.821,
                },
            ],
        },
        "detectorIds": [DETECTORS["cfd"]["id"]],
        "classifierId": "bioclip-2-vitl14-2957b32",
        "cropFit": "centreCrop",
        # The bars' pack. Its precision and levels came from 2026.11.18.0356,
        # which carries this detector and the same naming files.
        "packVersion": "2026.11.18.0030",
        "contents": _MEASURED_CONTENTS,
        "findings": _FINDINGS,
    },
    # Megalodon alone and both detectors (issue #4691), measured on pack
    # 2026.11.18.0356, which carries both and the same naming files.
    {
        "naming": {
            "provisional": False,
            "minCropSide": 64,
            "minOpenScore": 0.21,
            "suggestScore": 0.75,
            "confidentScore": 1.01,
            "suggestScoreNoLocation": 0.70,
            "confidentScoreNoLocation": 1.01,
            "minAllowedCandidates": 200,
            "topK": 5,
            "precision": 0.923,
            "levels": [
                {
                    "id": "balanced",
                    "target": 0.75,
                    "suggestScore": 0.57,
                    "suggestScoreNoLocation": 0.59,
                    "precision": 0.849,
                },
                {
                    "id": "eager",
                    "target": 0.65,
                    "suggestScore": 0.36,
                    "suggestScoreNoLocation": 0.44,
                    "precision": 0.757,
                },
            ],
        },
        "detectorIds": [DETECTORS["megalodon"]["id"]],
        "classifierId": "bioclip-2-vitl14-2957b32",
        "cropFit": "padSquare",
        "packVersion": "2026.11.18.0356",
        "contents": _MEASURED_CONTENTS,
        "findings": _FINDINGS,
    },
    {
        "naming": {
            "provisional": False,
            "minCropSide": 64,
            "minOpenScore": 0.44,
            "suggestScore": 0.74,
            "confidentScore": 1.01,
            "suggestScoreNoLocation": 0.81,
            "confidentScoreNoLocation": 1.01,
            "minAllowedCandidates": 200,
            "topK": 5,
            "precision": 0.897,
            "levels": [
                {
                    "id": "balanced",
                    "target": 0.75,
                    "suggestScore": 0.25,
                    "suggestScoreNoLocation": 0.63,
                    "precision": 0.825,
                },
                {
                    "id": "eager",
                    "target": 0.65,
                    "suggestScore": 0.25,
                    "suggestScoreNoLocation": 0.44,
                    "precision": 0.825,
                },
            ],
        },
        "detectorIds": [DETECTORS["cfd"]["id"], DETECTORS["megalodon"]["id"]],
        "classifierId": "bioclip-2-vitl14-2957b32",
        "cropFit": "centreCrop",
        "packVersion": "2026.11.18.0356",
        "contents": _MEASURED_CONTENTS,
        "findings": _FINDINGS,
    },
]

REGION = {"cellDegrees": 5, "neighbourCells": 1}
CROP_THUMBNAIL_SIZE = 320


def file_entry(path, engine):
    """A manifest `files` entry for the file at `path`."""
    digest = hashlib.sha256()
    size = 0
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
            size += len(chunk)
    return {
        "name": os.path.basename(path),
        "engine": engine,
        "size": size,
        "sha256": digest.hexdigest(),
    }


def contents_of(files):
    """The SHA-256 of each naming file among a manifest's `files` entries."""
    return {f["name"]: f["sha256"] for f in files if f["name"] in CONTENT_FILES}


def detector_ids(detector_set):
    """The ids of a detector set's detectors, in pool order."""
    return [DETECTORS[k]["id"] for k in DETECTOR_SETS[detector_set]]


def model_zip(stem, engine):
    """A model's file in a pack: `<stem>.<engine>.zip`, as the app names it."""
    return f"{stem}.{engine}.zip"


def model_in(folder):
    """The model a folder holds: a compiled model when there is one (the
    vision tool compiles a package once and deletes it), else the package.
    None when there is neither."""
    names = sorted(os.listdir(folder)) if os.path.isdir(folder) else []
    for ext in (".mlmodelc", ".mlpackage"):
        for name in names:
            if name.endswith(ext):
                return os.path.join(folder, name)
    return None


def unpack_model(pack, stem, folder, engine="coreml"):
    """The model `stem` of the pack folder `pack`, unpacked into `folder`
    unless a model is already there, as its path. Stops, naming the zip,
    when the zip holds no model."""
    path = model_in(folder)
    if path is None:
        name = model_zip(stem, engine)
        with zipfile.ZipFile(os.path.join(pack, name)) as zf:
            zf.extractall(folder)
        path = model_in(folder)
        if path is None:
            raise SystemExit(f"{name} in {pack} holds no Core ML model (.mlpackage or .mlmodelc at its top)")
    return path


def pack_detectors(manifest):
    """A pack manifest's detectors and box settings in format 2's shape,
    from either format, as copies. A format 1 pack's one detector is the
    fish detector (as the app reads it), run with its own box limit and
    crop padding."""
    if "detectors" in manifest:
        return copy.deepcopy(manifest["detectors"]), copy.deepcopy(manifest["boxes"])
    d = copy.deepcopy(manifest["detector"])
    detector = {
        "id": d["id"],
        "format": "rfdetr",
        "file": "detector",
        **{k: d[k] for k in ("inputSize", "mean", "std", "scoreThreshold", "maxBoxes")},
    }
    return [detector], {"mergeIoU": BOXES["mergeIoU"], "maxBoxes": d["maxBoxes"], "cropPadding": d["cropPadding"]}


def with_detectors(manifest, detectors, boxes):
    """A format 2 copy of `manifest` carrying `detectors` and `boxes`, for
    running a set of detectors with the vision tool."""
    out = copy.deepcopy({k: v for k, v in manifest.items() if k not in ("detector", "detectors", "boxes")})
    out["formatVersion"] = FORMAT_VERSION
    out["detectors"] = copy.deepcopy(list(detectors))
    out["boxes"] = copy.deepcopy(boxes)
    return out


def fitting_mismatches(chosen):
    """The detector sets (keys of DETECTOR_SETS) whose crop fitting a scorer
    run chose differs from CROP_FIT, which the packs are built with. Bars
    pinned at such a fitting would never match a built pack."""
    return {
        name: {"chosen": fit, "packs use": CROP_FIT[name]}
        for name, fit in chosen.items()
        if CROP_FIT[name] != fit
    }


def naming_for(detector_ids, classifier_id, crop_fit, contents, measured=NAMING_MEASURED):
    """The naming bars for a pack: the measured ones when it is a measured
    pack (same detectors in the same order, classifier, crop fitting and
    naming files, from `contents_of`), otherwise the provisional ones. A
    share is split across the whole candidate list, so any change to the
    list moves every score."""
    for entry in measured or ():
        if (
            list(detector_ids) == list(entry["detectorIds"])
            and classifier_id == entry["classifierId"]
            and crop_fit == entry["cropFit"]
            and contents == entry["contents"]
        ):
            return copy.deepcopy(entry["naming"])
    return dict(NAMING_PROVISIONAL)


# The naming levels a manifest may carry, surest first (issue #4721). Surer
# is the naming block's own bars and is never listed.
LEVEL_IDS = ("balanced", "eager")
# The naming keys a republished manifest may change: the levels and the
# accuracy measured at them. Anything else needs a new pack version.
LEVEL_KEYS = ("precision", "levels")


def _is_number(value):
    """Whether `value` is a JSON number; a bool is not one."""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _is_share(value):
    """Whether `value` is a number in (0, 1]; a missing or non-numeric one
    is reported as a problem rather than raising."""
    return _is_number(value) and 0 < value <= 1


def level_problems(naming):
    """What is wrong with a naming block's levels, as messages; empty when
    nothing is. Each level is a known id, in order, with each bar no higher
    than the level above it (Surer first) and at least one lower, and a
    precision in (0, 1] no higher than the level above's: a diver must
    never read that more names are more often right."""
    problems = []
    precision = naming.get("precision")
    if precision is not None and not _is_share(precision):
        problems.append(f"precision {precision} is not in (0, 1]")
    levels = naming.get("levels", [])
    if not isinstance(levels, list) or not all(isinstance(level, dict) for level in levels):
        return problems + [f"levels {levels} are not a list of objects"]
    ids = [level.get("id") for level in levels]
    if ids != [i for i in LEVEL_IDS if i in ids] or len(set(ids)) != len(ids):
        problems.append(f"levels {ids} are not a subset of {list(LEVEL_IDS)} in order")
    above = (naming["suggestScore"], naming["suggestScoreNoLocation"])
    # Only well-formed values are compared against: a bad one is reported
    # once, where it is, rather than raising further down.
    above_precision = precision if _is_share(precision) else None
    for level in levels:
        bars = (level.get("suggestScore"), level.get("suggestScoreNoLocation"))
        well_formed = all(_is_number(b) for b in bars)
        if not (well_formed and all(0 <= b <= a for b, a in zip(bars, above))):
            problems.append(f"{level.get('id')} bars {bars} are not at or below {above}")
        elif bars == above:
            problems.append(f"{level.get('id')} bars {bars} name nothing more than the level above")
        # The app drops a level with no numeric target, so it must not be
        # published without one.
        target = level.get("target")
        if not _is_share(target):
            problems.append(f"{level.get('id')} target {target} is not in (0, 1]")
        level_precision = level.get("precision")
        if not _is_share(level_precision):
            problems.append(f"{level.get('id')} precision {level_precision} is not in (0, 1]")
        elif above_precision is not None and level_precision > above_precision:
            problems.append(
                f"{level.get('id')} precision {level_precision} is above the level above's {above_precision}"
            )
        if well_formed:
            above = bars
        if _is_share(level_precision):
            above_precision = level_precision
    return problems


def _check_levels(naming):
    """Raises ValueError, naming each problem, unless `naming`'s levels are
    sound (level_problems)."""
    problems = level_problems(naming)
    if problems:
        raise ValueError("; ".join(problems))


def relevel(published, measured=NAMING_MEASURED):
    """`published` (a manifest as JSON) with the naming levels measured for
    its exact pack, keeping its pack version, so a device that has the pack
    takes the new manifest without downloading (issue #4721). Raises
    ValueError when the pack has no measured bars, or when anything but the
    levels and their precision would change."""
    classifier = published["classifier"]
    # Either format: a format 1 pack names its one detector `detector`.
    detectors, _ = pack_detectors(published)
    naming = naming_for(
        [d["id"] for d in detectors],
        classifier["id"],
        classifier["cropFit"],
        contents_of(published["files"]),
        measured,
    )
    if naming.get("provisional", True):
        raise ValueError(f"pack {published['packVersion']} has no measured bars")
    current = published["naming"]
    changed = sorted(k for k in set(current) | set(naming) if k not in LEVEL_KEYS and current.get(k) != naming.get(k))
    if changed:
        raise ValueError(f"republishing would change {changed}; that needs a new pack version")
    _check_levels(naming)
    out = copy.deepcopy(published)
    out["naming"] = naming
    return out


def build_manifest(
    *,
    pack_version,
    detector_set,
    classifier_id,
    embedding_size,
    files,
    credits,
    naming=None,
):
    crop_fit = CROP_FIT[detector_set]
    # A copy all the way down: the naming block carries a list of levels.
    # naming_for already returns one of its own.
    naming = (
        copy.deepcopy(naming)
        if naming
        else naming_for(detector_ids(detector_set), classifier_id, crop_fit, contents_of(files))
    )
    # A new pack's levels reach devices as a republish's do, so they are
    # held to the same checks as relevel (issue #4721). The app reads them
    # unless the bars are marked provisional; a missing flag is not.
    if naming.get("provisional") is not True:
        _check_levels(naming)
    return {
        "formatVersion": FORMAT_VERSION,
        "packVersion": pack_version,
        "detectors": [copy.deepcopy(DETECTORS[k]) for k in DETECTOR_SETS[detector_set]],
        "boxes": copy.deepcopy(BOXES),
        "classifier": {
            "id": classifier_id,
            "embeddingSize": embedding_size,
            **copy.deepcopy(CLASSIFIER_SETTINGS),
            "cropFit": crop_fit,
        },
        "naming": naming,
        "region": dict(REGION),
        "cropThumbnailSize": CROP_THUMBNAIL_SIZE,
        "files": list(files),
        "credits": list(credits),
    }


def write_manifest(path, manifest):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
