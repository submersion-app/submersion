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
# longer apply.
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
        },
        "detectorIds": [DETECTORS["cfd"]["id"]],
        "classifierId": "bioclip-2-vitl14-2957b32",
        "cropFit": "centreCrop",
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
            return dict(entry["naming"])
    return dict(NAMING_PROVISIONAL)


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
        "naming": dict(
            naming or naming_for(detector_ids(detector_set), classifier_id, crop_fit, contents_of(files))
        ),
        "region": dict(REGION),
        "cropThumbnailSize": CROP_THUMBNAIL_SIZE,
        "files": list(files),
        "credits": list(credits),
    }


def write_manifest(path, manifest):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
