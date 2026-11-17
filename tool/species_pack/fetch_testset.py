#!/usr/bin/env python3
"""Builds the accuracy test set: tool/species_pack/testdata/accuracy_set.csv,
and the photos it lists in a work folder kept out of git.

To rebuild the test set exactly as it was measured, fetch the photos the
committed CSV lists:

    python -I tool/species_pack/fetch_testset.py photos-from-csv

To draw a new one, run the stages in order; each caches its results in
--work and resumes:

    python -I tool/species_pack/fetch_testset.py pool
    python -I tool/species_pack/fetch_testset.py labels
    python -I tool/species_pack/fetch_testset.py photos
    python -I tool/species_pack/fetch_testset.py underwater
    python -I tool/species_pack/fetch_testset.py commons
    python -I tool/species_pack/fetch_testset.py junk-sheets --pack PACK
    python -I tool/species_pack/fetch_testset.py review-sheets
    (mark out-of-water photos in WORK/underwater_overrides.json, and label
    the junk boxes in WORK/junk_labels.json, both by eye)
    python -I tool/species_pack/fetch_testset.py write --force

`underwater` needs requirements.txt; the rest needs only Pillow. The rules
themselves live in testset.py, which is tested in CI. Developer-run only.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import region_grid  # noqa: E402
import testset  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_WORK = os.path.join(REPO, "build", "species_accuracy_work")
DEFAULT_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "testdata", "accuracy_set.csv")
USER_AGENT = "species-pack-accuracy/0.1 (+https://github.com/submersion-app/submersion)"
INAT = "https://api.inaturalist.org/v2/observations"
GBIF = "https://api.gbif.org/v1"
COMMONS = "https://commons.wikimedia.org/w/api.php"
COMMONS_CATEGORIES = ["Category:Underwater photographs of divers", "Category:Underwater divers"]
JUNK_PHOTOS = 150
CELL_DEGREES = 5
FIELDS = (
    "id,uri,created_at,observed_on,location,obscured,user.login,user.name,"
    "taxon.id,taxon.name,taxon.rank,taxon.ancestor_ids,"
    "photos.id,photos.url,photos.license_code,photos.attribution"
)


def _get(url, *, retries=8, as_json=True):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(retries):
        wait = min(2**attempt, 60)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read()
            return json.loads(data) if as_json else data
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == retries - 1:
                raise
            # A busy service says how long to wait; take it at its word.
            retry_after = e.headers.get("Retry-After") if e.headers else None
            if retry_after and retry_after.isdigit():
                wait = max(wait, int(retry_after))
        except (urllib.error.URLError, TimeoutError):
            if attempt == retries - 1:
                raise
        time.sleep(wait)
    raise RuntimeError("unreachable")


def _load(path, default):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    return default


def _save(path, value):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".partial", "w", encoding="utf-8") as fh:
        json.dump(value, fh, ensure_ascii=False)
    os.replace(path + ".partial", path)


# Stage 1: the pool of qualifying observations per region.


def _pool_record(o, region):
    """One observation as the test set needs it, or None when its first
    photo is not openly licensed or its place is hidden."""
    photos = o.get("photos") or []
    if not photos or not o.get("location") or o.get("obscured"):
        return None
    photo = photos[0]
    if photo.get("license_code") not in testset.LICENCES:
        return None
    lat, lon = (float(v) for v in o["location"].split(","))
    taxon = o.get("taxon") or {}
    group = testset.group_of(taxon.get("id"), taxon.get("ancestor_ids") or [])
    if group is None:
        return None
    user = o.get("user") or {}
    return {
        "id": str(o["id"]),
        "uri": o["uri"],
        "created": o["created_at"],
        "observed_on": o.get("observed_on") or "",
        "lat": lat,
        "lon": lon,
        "observer": user.get("login") or "",
        "observer_name": user.get("name") or user.get("login") or "",
        "taxon_name": taxon.get("name") or "",
        "taxon_rank": taxon.get("rank") or "",
        "photo_url": re.sub(r"/square\.", "/large.", photo["url"]),
        "licence": photo["license_code"],
        "attribution": photo.get("attribution") or "",
        "region": region,
        "group": group,
    }


def stage_pool(work):
    for region, (south, west, north, east) in testset.REGIONS.items():
        path = os.path.join(work, "pool", f"{region}.json")
        if os.path.exists(path):
            continue
        records, above = [], 0
        while True:
            query = urllib.parse.urlencode(
                {
                    "taxon_id": ",".join(str(t) for t in testset.TAXA),
                    "quality_grade": "research",
                    "captive": "false",
                    "photo_license": ",".join(testset.LICENCES),
                    "created_d1": testset.CUTOFF,
                    "geoprivacy": "open",
                    "taxon_geoprivacy": "open",
                    "swlat": south,
                    "swlng": west,
                    "nelat": north,
                    "nelng": east,
                    "per_page": 200,
                    "order_by": "id",
                    "order": "asc",
                    "id_above": above,
                    "fields": FIELDS,
                }
            )
            page = _get(f"{INAT}?{query}")
            results = page.get("results") or []
            for o in results:
                record = _pool_record(o, region)
                if record:
                    records.append(record)
            time.sleep(1.0)  # iNaturalist asks for at most one request a second.
            if len(results) < 200:
                break
            above = results[-1]["id"]
        _save(path, records)
        print(f"{region}: {len(records)} qualifying observations", flush=True)


# Stage 2: the sample, its labels, habitats and pre-cutoff records.


def _gbif_key(name):
    query = urllib.parse.urlencode({"name": name, "kingdom": "Animalia", "strict": "true"})
    return testset.accepted_key(_get(f"{GBIF}/species/match?{query}"))


def _habitat(key):
    flags = _get(f"{GBIF}/species/{key}/speciesProfiles?limit=50").get("results") or []
    if any(p.get("marine") or p.get("brackish") for p in flags):
        return "marine"
    if any(p.get("freshwater") for p in flags):
        return "freshwater"
    return ""


def _recorded_before_cutoff(o, key):
    """Whether GBIF has the species recorded in the observation's cell or
    the cells around it before the cutoff. An observation made before the
    cutoff (and uploaded after) may be among those records itself, so it
    then needs a second record."""
    cell = region_grid.cell_of(o["lat"], o["lon"], CELL_DEGREES)
    count = 0
    for south, west, north, east in testset.query_boxes(cell, 1, CELL_DEGREES):
        query = urllib.parse.urlencode(
            {
                "taxonKey": key,
                "decimalLatitude": f"{south},{north}",
                "decimalLongitude": f"{west},{east}",
                "eventDate": "*,2024-06-30",
                "limit": 0,
            }
        )
        count += _get(f"{GBIF}/occurrence/search?{query}")["count"]
    needed = 2 if o["observed_on"] and o["observed_on"] < testset.CUTOFF else 1
    return count >= needed


def stage_labels(work):
    sample_path = os.path.join(work, "sample.json")
    sample = _load(sample_path, None)
    if sample is None:
        natural, everything = [], []
        for region in testset.REGIONS:
            pool = _load(os.path.join(work, "pool", f"{region}.json"), [])
            named = [o for o in pool if testset.species_name(o["taxon_name"], o["taxon_rank"])]
            picked = testset.sample(named, testset.PER_REGION, testset.SEED)
            print(f"{region}: {len(pool)} in the pool, {len(named)} named to species, {len(picked)} sampled")
            natural.extend(dict(o, sample="natural") for o in picked)
            everything.extend(named)
        extra = [dict(o, sample="top-up") for o in testset.top_ups(everything, natural, testset.SEED)]
        sample = natural + extra
        for group in testset.GROUPS:
            n = sum(1 for o in natural if o["group"] == group)
            t = sum(1 for o in extra if o["group"] == group)
            print(f"{group}: {n} natural, {t} top-up")
        _save(sample_path, sample)

    keys_path = os.path.join(work, "gbif", "match.json")
    keys = _load(keys_path, {})
    names = sorted({testset.species_name(o["taxon_name"], o["taxon_rank"]) for o in sample})
    todo = [n for n in names if n not in keys]
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        for start in range(0, len(todo), 100):
            chunk = todo[start : start + 100]
            for name, key in zip(chunk, pool.map(_gbif_key, chunk)):
                keys[name] = key
            _save(keys_path, keys)
    unmatched = [n for n in names if keys[n] is None]
    print(f"{len(names)} species names, {len(unmatched)} with no GBIF species key")

    habitat_path = os.path.join(work, "gbif", "habitat.json")
    habitats = _load(habitat_path, {})
    wanted = sorted({str(k) for k in keys.values() if k is not None} - set(habitats))
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        for start in range(0, len(wanted), 100):
            chunk = wanted[start : start + 100]
            for key, habitat in zip(chunk, pool.map(_habitat, chunk)):
                habitats[key] = habitat
            _save(habitat_path, habitats)

    precut_path = os.path.join(work, "gbif", "recorded_before_cutoff.json")
    precut = _load(precut_path, {})
    todo = [o for o in sample if o["id"] not in precut and keys.get(_name(o)) is not None]
    # GBIF's occurrence search rate-limits hard, so few at a time, saved as
    # it goes so a stopped run resumes.
    with concurrent.futures.ThreadPoolExecutor(3) as pool:
        for start in range(0, len(todo), 100):
            chunk = todo[start : start + 100]
            for o, seen in zip(chunk, pool.map(lambda o: _recorded_before_cutoff(o, keys[_name(o)]), chunk)):
                precut[o["id"]] = seen
            _save(precut_path, precut)
    print(f"{sum(precut.values())} of {len(precut)} labelled observations recorded nearby before the cutoff")


def _name(o):
    return testset.species_name(o["taxon_name"], o["taxon_rank"])


# Stage 3: the photos.


def _photo_path(work, source, ident):
    return os.path.join(work, "photos", f"{source}_{ident}.jpg")


def _download(url, path):
    if os.path.exists(path):
        return
    data = _get(url, as_json=False)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".partial", "wb") as fh:
        fh.write(data)
    os.replace(path + ".partial", path)


def stage_photos(work):
    sample = _load(os.path.join(work, "sample.json"), [])
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        list(pool.map(lambda o: _download(o["photo_url"], _photo_path(work, "inaturalist", o["id"])), sample))
    print(f"{len(sample)} photos in {os.path.join(work, 'photos')}")


# Stage 4: the underwater filter.


def _sheet(paths, captions, out, *, columns=10, size=160):
    """A grid of images, each with its caption on a band above it, so a
    caption cannot be read as the next row's."""
    from PIL import Image, ImageDraw

    if not paths:
        return
    band = 18
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * (size + 6), rows * (size + band + 6)), "white")
    draw = ImageDraw.Draw(sheet)
    for i, (path, caption) in enumerate(zip(paths, captions)):
        x, y = (i % columns) * (size + 6), (i // columns) * (size + band + 6)
        draw.rectangle((x, y, x + size, y + band - 2), fill="black")
        draw.text((x + 3, y + 3), caption, fill="yellow")
        image = Image.open(path).convert("RGB") if isinstance(path, str) else path
        image.thumbnail((size, size))
        sheet.paste(image, (x, y + band))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)


def stage_underwater(work):
    import torch
    from PIL import Image, ImageOps

    import models

    path = os.path.join(work, "underwater.json")
    verdicts = _load(path, {})
    # Only observations the test set can keep: write drops those whose name
    # matched no GBIF species key.
    keys = _load(os.path.join(work, "gbif", "match.json"), {})
    sample = [
        o
        for o in _load(os.path.join(work, "sample.json"), [])
        if o["id"] not in verdicts and keys.get(_name(o)) is not None
    ]
    if sample:
        model, preprocess, tokenizer = models._classifier()
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        model = model.to(device)
        prompts = testset.UNDERWATER_PROMPTS + testset.DRY_PROMPTS
        with torch.no_grad():
            text = model.encode_text(tokenizer(prompts).to(device))
            text = text / text.norm(dim=-1, keepdim=True)
            for start in range(0, len(sample), 32):
                batch = sample[start : start + 32]
                images = torch.stack(
                    [
                        # Upright, as the app and the scorer see it.
                        preprocess(ImageOps.exif_transpose(Image.open(_photo_path(work, "inaturalist", o["id"]))).convert("RGB"))
                        for o in batch
                    ]
                ).to(device)
                e = model.encode_image(images)
                e = e / e.norm(dim=-1, keepdim=True)
                probs = (model.logit_scale.exp() * e @ text.T).softmax(-1).cpu().tolist()
                for o, p in zip(batch, probs):
                    scores = dict(zip(prompts, p))
                    verdicts[o["id"]] = testset.underwater(scores)
                _save(path, verdicts)
    kept = [i for i, v in sorted(verdicts.items()) if v]
    dropped = [i for i, v in sorted(verdicts.items()) if not v]
    print(f"underwater: {len(kept)} kept, {len(dropped)} dropped")
    for name, ids in (("kept", kept), ("dropped", dropped)):
        picked = sorted(ids, key=lambda i: hashlib.sha256(i.encode()).hexdigest())[:100]
        _sheet(
            [_photo_path(work, "inaturalist", i) for i in picked],
            picked,
            os.path.join(work, "sheets", f"underwater_{name}.png"),
        )


# Stage 4b: a by-eye review of what the filter kept, for the groups it
# struggles with. Out-of-water photos found go in underwater_overrides.json
# in the work folder, as {"<observation id>": false}.

REVIEW_GROUPS = ("crabs", "sea snails and nudibranchs", "sea stars", "octopus")


def stage_review_sheets(work):
    sample = _load(os.path.join(work, "sample.json"), [])
    verdicts = _load(os.path.join(work, "underwater.json"), {})
    kept = [o["id"] for o in sample if o["group"] in REVIEW_GROUPS and verdicts.get(o["id"])]
    for n in range(0, len(kept), 100):
        ids = kept[n : n + 100]
        _sheet(
            [_photo_path(work, "inaturalist", i) for i in ids],
            ids,
            os.path.join(work, "sheets", f"review_{n // 100:02d}.png"),
        )
    print(f"{len(kept)} kept photos in {REVIEW_GROUPS} on {(len(kept) + 99) // 100} sheets")


# Stage 5: Commons photos of divers, for junk crops.


def _commons_files(category):
    files, cont = [], {}
    while True:
        query = urllib.parse.urlencode(
            {
                "action": "query",
                "format": "json",
                "generator": "categorymembers",
                "gcmtitle": category,
                "gcmtype": "file",
                "gcmlimit": 200,
                "prop": "imageinfo",
                "iiprop": "url|extmetadata|mime",
                "iiurlwidth": 1024,
                **cont,
            }
        )
        page = _get(f"{COMMONS}?{query}")
        for p in (page.get("query") or {}).get("pages", {}).values():
            info = (p.get("imageinfo") or [{}])[0]
            meta = info.get("extmetadata") or {}
            licence = testset.commons_licence((meta.get("LicenseShortName") or {}).get("value", ""))
            if licence is None or info.get("mime") != "image/jpeg":
                continue
            artist = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "")).strip()
            files.append(
                {
                    "id": str(p["pageid"]),
                    "title": p["title"],
                    "photo_url": info.get("thumburl") or info["url"],
                    "page_url": info.get("descriptionurl", ""),
                    "licence": licence,
                    "attribution": f"{artist or 'Unknown author'}, {p['title']}, Wikimedia Commons ({licence})",
                }
            )
        if "continue" not in page:
            return files
        cont = page["continue"]
        time.sleep(0.5)


def stage_commons(work):
    path = os.path.join(work, "commons.json")
    chosen = _load(path, None)
    if chosen is None:
        found = {}
        for category in COMMONS_CATEGORIES:
            for f in _commons_files(category):
                found[f["id"]] = f
        chosen = sorted(found.values(), key=lambda f: hashlib.sha256(f["id"].encode()).hexdigest())[:JUNK_PHOTOS]
        _save(path, chosen)
        print(f"{len(found)} openly licensed diver photos found, {len(chosen)} chosen")
    for f in chosen:
        _download(f["photo_url"], _photo_path(work, "commons", f["id"]))
        time.sleep(0.2)


# Stage 6: contact sheets of the boxes on the diver photos, for labelling.


def _model_path(models_dir, name):
    """A model's compiled folder when the pipeline has compiled it (it then
    deletes the package), otherwise its package."""
    compiled = os.path.join(models_dir, f"{name}.mlmodelc")
    return compiled if os.path.exists(compiled) else os.path.join(models_dir, f"{name}.mlpackage")


def _boxed(image, d):
    """The box with half its size again around it, the box outlined in red,
    so it can be judged in its surroundings."""
    from PIL import ImageDraw

    w, h = image.size
    x0, y0, x1, y1 = d["x"] * w, d["y"] * h, (d["x"] + d["w"]) * w, (d["y"] + d["h"]) * h
    mx, my = (x1 - x0) / 2, (y1 - y0) / 2
    left, top = max(0, int(x0 - mx)), max(0, int(y0 - my))
    crop = image.crop((left, top, min(w, int(x1 + mx)), min(h, int(y1 + my)))).copy()
    ImageDraw.Draw(crop).rectangle((x0 - left, y0 - top, x1 - left, y1 - top), outline="red", width=3)
    return crop


def stage_junk_sheets(work, pack):
    import subprocess
    import zipfile

    from PIL import Image

    import megalodon

    # Before any building or unzipping: both detectors run here.
    mega_dir = megalodon.converted_dir(work, "megalodon-2024")
    chosen = _load(os.path.join(work, "commons.json"), [])
    tool = os.path.join(work, "species_vision")
    subprocess.run([os.path.join(os.path.dirname(__file__), "vision_cli", "build.sh"), tool], check=True)
    pack_models = os.path.join(work, "models", "junk")
    os.makedirs(pack_models, exist_ok=True)
    for name in ("detector", "classifier"):
        if not os.path.exists(os.path.join(pack_models, f"{name}.mlmodelc")):
            with zipfile.ZipFile(os.path.join(pack, f"{name}.coreml.zip")) as zf:
                zf.extractall(pack_models)
    with open(os.path.join(pack, "manifest.json"), encoding="utf-8") as fh:
        pack_detector = json.load(fh)["detector"]["id"]
    mega_manifest = os.path.join(mega_dir, "manifest.json")
    with open(mega_manifest, "w", encoding="utf-8") as fh:
        json.dump(megalodon.manifest_for("megalodon-2024", os.path.join(pack, "manifest.json")), fh)
    runs = {
        pack_detector: (os.path.join(pack, "manifest.json"), _model_path(pack_models, "detector")),
        megalodon.CHECKPOINTS["megalodon-2024"]["id"]: (
            mega_manifest,
            _model_path(mega_dir, "detector"),
        ),
    }
    paths = "\n".join(_photo_path(work, "commons", f["id"]) for f in chosen) + "\n"
    for detector, (manifest, model) in runs.items():
        out_path = os.path.join(work, f"junk_detections_{detector}.jsonl")
        if not os.path.exists(out_path):
            result = subprocess.run(
                [
                    tool,
                    "--manifest",
                    manifest,
                    "--detector",
                    model,
                    "--classifier",
                    _model_path(pack_models, "classifier"),
                    "--crop-fit",
                    "padSquare",
                ],
                input=paths,
                capture_output=True,
                text=True,
                check=True,
            )
            with open(out_path, "w", encoding="utf-8") as fh:
                fh.write(result.stdout)
        crops, captions = [], []
        for line in open(out_path, encoding="utf-8"):
            r = json.loads(line)
            if "error" in r:
                continue
            ident = os.path.basename(r["path"])[len("commons_") : -len(".jpg")]
            image = Image.open(r["path"]).convert("RGB")
            for i, d in enumerate(r["detections"]):
                crops.append(_boxed(image, d))
                captions.append(f"{ident}:{i}")
        for n in range(0, len(crops), 36):
            _sheet(
                crops[n : n + 36],
                captions[n : n + 36],
                os.path.join(work, "sheets", f"junk_{detector}_{n // 36:02d}.png"),
                columns=6,
                size=260,
            )
        print(f"{detector}: {len(crops)} boxes on {len(chosen)} diver photos")
    print(f"label them as detector:photo:box in {os.path.join(work, 'junk_labels.json')}")


# Stage 7: the CSV.


def stage_photos_from_csv(work, csv_path):
    """Downloads every photo the committed list names: the way to rebuild
    the test set exactly as it was measured, rather than drawing a new
    sample."""
    rows = testset.read_rows(csv_path)
    wanted = {}
    for r in rows:
        wanted[_photo_path(work, r["source"], r["id"])] = r["photo_url"]
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        list(pool.map(lambda item: _download(item[1], item[0]), wanted.items()))
    missing = [p for p in wanted if not os.path.exists(p)]
    print(f"{len(wanted) - len(missing)} of {len(wanted)} photos in {os.path.join(work, 'photos')}")
    if missing:
        raise SystemExit(f"{len(missing)} photos could not be fetched")


def _junk_boxes(work):
    """Each detector's boxes on the diver photos, as labelled:
    {"detector:photo:index": (x, y, w, h)}."""
    boxes = {}
    for path in sorted(os.listdir(work)):
        if not (path.startswith("junk_detections_") and path.endswith(".jsonl")):
            continue
        detector = path[len("junk_detections_") : -len(".jsonl")]
        with open(os.path.join(work, path), encoding="utf-8") as fh:
            for line in fh:
                r = json.loads(line)
                ident = os.path.basename(r["path"])[len("commons_") : -len(".jpg")]
                for i, d in enumerate(r.get("detections", [])):
                    boxes[f"{detector}:{ident}:{i}"] = (d["x"], d["y"], d["w"], d["h"])
    return boxes


def stage_write(work, csv_path, force=False):
    if os.path.exists(csv_path) and not force:
        raise SystemExit(
            f"{csv_path} exists; it is the list the findings were measured on. Pass --force to replace it."
        )
    sample = _load(os.path.join(work, "sample.json"), [])
    keys = _load(os.path.join(work, "gbif", "match.json"), {})
    habitats = _load(os.path.join(work, "gbif", "habitat.json"), {})
    precut = _load(os.path.join(work, "gbif", "recorded_before_cutoff.json"), {})
    underwater = _load(os.path.join(work, "underwater.json"), {})
    # The by-eye review overrides the filter where it was wrong.
    underwater.update(_load(os.path.join(work, "underwater_overrides.json"), {}))
    labelled = [o["id"] for o in sample if keys.get(_name(o)) is not None]
    no_precut = testset.unchecked(labelled, precut)
    if no_precut:
        raise SystemExit(f"{len(no_precut)} observations have no pre-cutoff check yet; finish the labels stage")
    # The filter is part of the sampling rule: a missing verdict would drop
    # the photo from the set without a word.
    no_verdict = testset.unchecked(labelled, underwater)
    if no_verdict:
        raise SystemExit(f"{len(no_verdict)} observations have no underwater verdict yet; finish the underwater stage")
    rows = []
    for o in sample:
        key = keys.get(_name(o))
        if key is None:
            continue
        rows.append(
            {
                "source": "inaturalist",
                "id": o["id"],
                "box": "",
                "box_x": "",
                "box_y": "",
                "box_w": "",
                "box_h": "",
                "photo_url": o["photo_url"],
                "licence": o["licence"],
                "attribution": o["attribution"],
                "page_url": o["uri"],
                "region": o["region"],
                "group": o["group"],
                "sample": o["sample"],
                "detector": "",
                "lat": o["lat"],
                "lon": o["lon"],
                "created": o["created"],
                "observer": o["observer"],
                "label_name": _name(o),
                "gbif_key": key,
                "label_source": "iNaturalist research grade",
                "habitat": habitats.get(str(key), ""),
                "recorded_before_cutoff": "yes" if precut.get(o["id"]) else "no",
                "underwater": {True: "yes", False: "no"}.get(underwater.get(o["id"]), ""),
            }
        )
    commons = {f["id"]: f for f in _load(os.path.join(work, "commons.json"), [])}
    labels = _load(os.path.join(work, "junk_labels.json"), {})
    junk_boxes = _junk_boxes(work)
    stale = [k for k, label in labels.items() if label in ("person", "scenery") and k not in junk_boxes]
    if stale:
        raise SystemExit(
            f"{len(stale)} junk labels name boxes no junk_detections file has, for example {stale[:3]}; "
            "rerun junk-sheets and label its boxes again"
        )
    for label_id, label in sorted(labels.items()):
        if label not in ("person", "scenery"):
            continue
        detector, ident, box = label_id.split(":")
        f = commons[ident]
        rows.append(
            {
                "source": "commons",
                "id": ident,
                "box": box,
                "box_x": junk_boxes[label_id][0],
                "box_y": junk_boxes[label_id][1],
                "box_w": junk_boxes[label_id][2],
                "box_h": junk_boxes[label_id][3],
                "photo_url": f["photo_url"],
                "licence": f["licence"],
                "attribution": f["attribution"],
                "page_url": f["page_url"],
                "region": "junk",
                "group": "",
                "sample": "",
                "detector": detector,
                "lat": "",
                "lon": "",
                "created": "",
                "observer": "",
                "label_name": "person or gear" if label == "person" else "bare scenery",
                "gbif_key": "",
                "label_source": "by eye (builder)",
                "habitat": "",
                "recorded_before_cutoff": "",
                "underwater": "",
            }
        )
    testset.write_rows(csv_path, rows)
    print(f"{len(rows)} rows written to {csv_path}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "stage",
        choices=[
            "pool",
            "labels",
            "photos",
            "underwater",
            "review-sheets",
            "commons",
            "junk-sheets",
            "write",
            "photos-from-csv",
        ],
    )
    parser.add_argument("--work", default=DEFAULT_WORK)
    parser.add_argument("--csv", default=DEFAULT_CSV)
    parser.add_argument("--pack", help="a built pack folder, for junk-sheets")
    parser.add_argument("--force", action="store_true", help="let write replace an existing CSV")
    args = parser.parse_args(argv)
    os.makedirs(args.work, exist_ok=True)
    if args.stage == "pool":
        stage_pool(args.work)
    elif args.stage == "labels":
        stage_labels(args.work)
    elif args.stage == "photos":
        stage_photos(args.work)
    elif args.stage == "underwater":
        stage_underwater(args.work)
    elif args.stage == "review-sheets":
        stage_review_sheets(args.work)
    elif args.stage == "commons":
        stage_commons(args.work)
    elif args.stage == "junk-sheets":
        if not args.pack:
            parser.error("junk-sheets needs --pack")
        stage_junk_sheets(args.work, args.pack)
    elif args.stage == "photos-from-csv":
        stage_photos_from_csv(args.work, args.csv)
    else:
        stage_write(args.work, args.csv, force=args.force)
    return 0


if __name__ == "__main__":
    sys.exit(main())
