#!/usr/bin/env python3
"""Builds a marine life model pack for the app (issue #4668).

    python3.14 -m venv .venv && .venv/bin/pip install -r tool/species_pack/requirements.txt
    .venv/bin/python tool/species_pack/build_pack.py --out build/species_pack

Writes `manifest.json` and the five files the Core ML engine needs. GBIF
responses and converted models are kept in `--work`, so a second run is
quick. Developer-run only: not part of the app build or CI.
"""

import argparse
import datetime
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import candidates as cand  # noqa: E402
import manifest as mf  # noqa: E402
import region_grid  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

CREDITS = [
    {
        "name": "BioCLIP 2",
        "licence": "MIT",
        "text": "Imageomics Institute. Gu et al., BioCLIP 2: Emergent Properties from Scaling Hierarchical Contrastive Learning.",
    },
    {
        "name": "Community Fish Detector",
        "licence": "Redistribution awaiting the authors' permission",
        "text": "RF-DETR detector trained on the Community Fish Detection Dataset.",
    },
    {
        "name": "RF-DETR",
        "licence": "Apache-2.0",
        "text": "Roboflow.",
    },
    {
        "name": "GBIF occurrence and taxonomy data",
        "licence": "CC0 and CC BY 4.0",
        "text": "GBIF.org. Species names and where each species has been recorded.",
    },
]


def default_version(now=None):
    """The pack version when none is given: the UTC date and time, so two
    builds on one day differ (devices compare versions to offer an update,
    and to name stored crops again)."""
    now = now or datetime.datetime.now(datetime.timezone.utc)
    return now.strftime("%Y.%m.%d.%H%M")


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", required=True)
    parser.add_argument("--work", default=os.path.join(REPO, "build", "species_pack_work"))
    parser.add_argument("--max-candidates", type=int, default=10000)
    parser.add_argument("--min-images", type=int, default=50, help="photographed human observations")
    parser.add_argument(
        "--min-survey-records",
        type=int,
        default=50,
        help="present human observations at 0 to 40 m, for species divers record but rarely photograph",
    )
    parser.add_argument("--version", default=default_version())
    parser.add_argument("--skip-models", action="store_true", help="reuse converted models in --work")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    os.makedirs(args.work, exist_ok=True)

    import models

    # 1 and 2: models.
    detector_pkg = os.path.join(args.work, "detector.mlpackage")
    classifier_pkg = os.path.join(args.work, "classifier.mlpackage")
    if not (args.skip_models and os.path.exists(detector_pkg) and os.path.exists(classifier_pkg)):
        print("converting models", flush=True)
        detector_pkg = models.convert_detector(models.fetch_detector(args.work), args.work)
        classifier_pkg = models.convert_classifier(args.work)
    models.zip_model(detector_pkg, os.path.join(args.out, "detector.coreml.zip"))
    models.zip_model(classifier_pkg, os.path.join(args.out, "classifier.coreml.zip"))

    # 3: candidates.
    with open(os.path.join(REPO, "assets", "data", "species.json"), encoding="utf-8") as fh:
        catalogue = json.load(fh)["species"]
    with open(os.path.join(REPO, "assets", "data", "species_gbif_keys.json"), encoding="utf-8") as fh:
        keys = json.load(fh)
    rows = cand.catalogue_candidates(catalogue, keys["speciesKeys"])
    have = {r["gbifKey"] for r in rows}
    print(f"catalogue candidates: {len(rows)}", flush=True)
    with ThreadPoolExecutor(8) as pool:
        catalogue_records = list(pool.map(lambda r: cand.fetch_species(r["gbifKey"], args.work), rows))
    orders = cand.expansion_order_keys(
        [(r["category"], rec) for r, rec in zip(rows, catalogue_records)]
    )
    print(f"widening within {len(orders)} orders", flush=True)
    photographed = cand.fetch_photographed_species(sorted(orders), args.work, min_images=args.min_images)
    surveyed = cand.fetch_surveyed_species(sorted(orders), args.work, min_records=args.min_survey_records)
    print(f"photographed species: {len(photographed)}, surveyed species: {len(surveyed)}", flush=True)
    wanted = cand.wanted_keys(photographed, surveyed, have, args.max_candidates - len(rows))
    photographed_keys = {k for k, _ in photographed}
    print(f"fetching {len(wanted)} GBIF species", flush=True)
    with ThreadPoolExecutor(8) as pool:
        records = list(pool.map(lambda k: cand.fetch_species(k, args.work), wanted))
    for record in records:
        row = cand.gbif_candidate(record)
        if row and row["gbifKey"] not in have:
            have.add(row["gbifKey"])
            rows.append(row)
    survey_only = sum(1 for r in rows if "catalogId" not in r and r["gbifKey"] not in photographed_keys)
    print(f"candidates: {len(rows)}, of them from surveys only: {survey_only}", flush=True)
    candidates_path = os.path.join(args.out, "candidates.json")
    with open(candidates_path, "w", encoding="utf-8") as fh:
        json.dump(rows, fh, ensure_ascii=False)

    # 4: text embeddings.
    print("embedding names", flush=True)
    embeddings = models.text_embeddings(rows)
    embeddings_path = os.path.join(args.out, "text_embeddings.f16")
    embeddings.astype("<f2").tofile(embeddings_path)

    # 5: regions.
    import regions

    cell_degrees = mf.REGION["cellDegrees"]
    print("mapping regions", flush=True)
    with ThreadPoolExecutor(8) as pool:
        cells = list(pool.map(lambda r: regions.cells_for(r["gbifKey"], cell_degrees, args.work), rows))
    regions_path = os.path.join(args.out, "regions.bin")
    with open(regions_path, "wb") as fh:
        fh.write(region_grid.pack_bits([sorted(c) for c in cells], cell_degrees))
    print(f"species with no recorded place: {sum(1 for c in cells if not c)}", flush=True)

    # 6: manifest.
    files = [
        mf.file_entry(os.path.join(args.out, "detector.coreml.zip"), "coreml"),
        mf.file_entry(os.path.join(args.out, "classifier.coreml.zip"), "coreml"),
        mf.file_entry(candidates_path, "all"),
        mf.file_entry(embeddings_path, "all"),
        mf.file_entry(regions_path, "all"),
    ]
    manifest = mf.build_manifest(
        pack_version=args.version,
        detector_id=models.DETECTOR_ID,
        classifier_id=models.CLASSIFIER_ID,
        embedding_size=models.EMBEDDING_SIZE,
        files=files,
        credits=CREDITS,
    )
    mf.write_manifest(os.path.join(args.out, "manifest.json"), manifest)
    total = sum(f["size"] for f in files)
    print(f"pack {args.version}: {len(rows)} candidates, {total / 1e6:.0f} MB", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
