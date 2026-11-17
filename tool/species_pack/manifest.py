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
# The pack files that decide how a crop is named, besides the models: the
# candidates, their text embeddings, and where each has been recorded.
CONTENT_FILES = ("candidates.json", "text_embeddings.f16", "regions.bin")

# Measured bars (tool/species_pack/score.py). They hold only for the exact
# pack they were measured on: the same detector, classifier and crop
# fitting, and the same naming files byte for byte. Any other pack, a
# rebuilt candidate list of the same size included, gets the provisional
# bars until the scorer is run on it. A bar of 1.01 is never: no confident
# names, since no bar proved 95% right.
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
    "cropFit": "centreCrop",
    "packVersion": "2026.11.17.1617",
    "contents": {
        "candidates.json": "7e36bbf837c705f2679baf29e120462b35707421c96955403e031d61d3e7accb",
        "text_embeddings.f16": "957f0e7ee016dc7ef99a1b96c81b81130439b5dbb9b9170e0d190839b0e1b20e",
        "regions.bin": "ec2f86088a9bd113b7faa96550168e8672ed7e63f6cb2b6d0d64f43e15ac426f",
    },
    "findings": "docs/design/findings/2026-11-17-marine-life-measured-accuracy.md",
}

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


def naming_for(detector_id, classifier_id, crop_fit, contents, measured=NAMING_MEASURED):
    """The naming bars for a pack: the measured ones when it is the measured
    pack (same detector, classifier, crop fitting and naming files, from
    `contents_of`), otherwise the provisional ones. A share is split across
    the whole candidate list, so any change to the list moves every score."""
    if (
        measured is not None
        and detector_id == measured["detectorId"]
        and classifier_id == measured["classifierId"]
        and crop_fit == measured["cropFit"]
        and contents == measured["contents"]
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
        "naming": dict(
            naming
            or naming_for(detector_id, classifier_id, CLASSIFIER_SETTINGS["cropFit"], contents_of(files))
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
