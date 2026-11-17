#!/usr/bin/env python3
"""The model pack manifest: what the app reads to download, verify and run
a pack (lib/features/species_id/domain/entities/species_pack_manifest.dart).

Standard library only, so its test runs in CI without the model tooling.
"""

import hashlib
import json
import os

FORMAT_VERSION = 1

# The spike's settings (spec appendix). Change them only with the models.
DETECTOR_SETTINGS = {
    "inputSize": 640,
    "mean": [0.485, 0.456, 0.406],
    "std": [0.229, 0.224, 0.225],
    "scoreThreshold": 0.3,
    "maxBoxes": 8,
    "cropPadding": 0.10,
}
CLASSIFIER_SETTINGS = {
    "inputSize": 224,
    "mean": [0.48145466, 0.4578275, 0.40821073],
    "std": [0.26862954, 0.26130258, 0.27577711],
    "logitScale": 100.0,
    # How the app fits a crop to the square input. Centre crop named
    # significantly more fish right than padding with the mean colour, with
    # the Community Fish Detector (measured accuracy findings); the bars
    # below were measured with it.
    "cropFit": "centreCrop",
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
# Measured bars (tool/species_pack/score.py). They hold only for the
# detector, classifier and candidate list size they were measured on:
# `naming_for` falls back to the provisional bars for any other pack. A bar
# of 1.01 is never: no confident names, since no bar proved 95% right.
NAMING_MEASURED = {
    "naming": {
        "provisional": False,
        "minCropSide": 64,
        "minOpenScore": 0.34,
        "suggestScore": 0.72,
        "confidentScore": 1.01,
        "suggestScoreNoLocation": 0.79,
        "confidentScoreNoLocation": 1.01,
        "minAllowedCandidates": 200,
        "topK": 5,
    },
    "detectorId": "cfd-rfdetr-nano-640-20260706",
    "classifierId": "bioclip-2-vitl14-2957b32",
    "candidates": 7646,
    "findings": "docs/design/findings/2026-11-17-marine-life-measured-accuracy.md",
}

# How far a pack's candidate count may stray from the measured one. A
# share is split across the whole list, so a much longer or shorter list
# moves every score.
MEASURED_COUNT_TOLERANCE = 0.10

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


def naming_for(detector_id, classifier_id, candidate_count, measured=NAMING_MEASURED):
    """The naming bars for a pack: the measured ones when it has the
    measured detector and classifier and a candidate list within 10% of the
    measured size, otherwise the provisional ones. Another detector gives
    other crops, and so other scores."""
    if (
        measured is not None
        and detector_id == measured["detectorId"]
        and classifier_id == measured["classifierId"]
        and abs(candidate_count - measured["candidates"])
        <= MEASURED_COUNT_TOLERANCE * measured["candidates"]
    ):
        return dict(measured["naming"])
    return dict(NAMING_PROVISIONAL)


def build_manifest(
    *,
    pack_version,
    detector_id,
    classifier_id,
    embedding_size,
    files,
    credits,
    candidate_count,
    naming=None,
):
    return {
        "formatVersion": FORMAT_VERSION,
        "packVersion": pack_version,
        "detector": {"id": detector_id, **DETECTOR_SETTINGS},
        "classifier": {
            "id": classifier_id,
            "embeddingSize": embedding_size,
            **CLASSIFIER_SETTINGS,
        },
        "naming": dict(naming or naming_for(detector_id, classifier_id, candidate_count)),
        "region": dict(REGION),
        "cropThumbnailSize": CROP_THUMBNAIL_SIZE,
        "files": list(files),
        "credits": list(credits),
    }


def write_manifest(path, manifest):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
