#!/usr/bin/env python3
"""Fetches and embeds the naming layer's training photos (issue #4724;
docs/design/specs/2026-11-18-marine-life-naming-layer-design.md).

    python -I tool/species_pack/fetch_training.py --pack PACK STAGE

Stages, each resumable:

- lists: one iNaturalist request per candidate in the pack (research grade,
  wild, a training licence, newest first), each observation's name checked
  against GBIF to the candidate it belongs to.
- select: the leak guard, the validation observers and the caps
  (training_set.py), into selected.json.
- embed: per batch of photos, download, run the app's vision pipeline (the
  pair of detectors, centre crop, BioCLIP 2), keep the largest box's
  embedding, delete the photos. A photo gone from the bucket is skipped;
  one whose download may work later leaves its batch for the next run.
- all: the three in order.

--wait: at a daily limit, sleep to the next UTC day and carry on.

Stays at one iNaturalist request a second and under 9,500 a day, and under
20 GB a day of photos from any host but iNaturalist's AWS Open Data
bucket, which states no limit and is not counted: a stage that reaches a
limit stops and says to run it again tomorrow. Downloads live under the
work folder's photos/, apart from these scripts. Developer-run; not part
of CI.
"""

import argparse
import concurrent.futures
import datetime
import http.client
import json
import os
import shutil
import sys
import threading
import time
import urllib.error
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fetch_testset as ft  # noqa: E402
import testset  # noqa: E402
import training_set as ts  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_WORK = os.path.join(REPO, "build", "naming_training")
# iNaturalist asks API users for under 10,000 requests a day.
DAILY_REQUESTS = 9500
# Its guidance for media from its own servers is under 24 GB a day. Photos
# from its public AWS Open Data bucket, which states no limit, are not
# counted (Eric, 2026-11-19); any other host stays under this.
DAILY_BYTES = 20 * 10**9
OPEN_DATA_HOST = "inaturalist-open-data.s3.amazonaws.com"
BATCH = 2000
MIN_SIDE = 64
FIT = "centreCrop"


def labelled_crop(result, min_side):
    """The largest detection in a vision tool result when its shorter side
    is at least `min_side`, else None (as the app would not name it)."""
    if "error" in result:
        return None
    detections = result.get("detections") or []
    if not detections:
        return None
    largest = max(detections, key=lambda d: d["pixelWidth"] * d["pixelHeight"])
    return largest if min(largest["pixelWidth"], largest["pixelHeight"]) >= min_side else None


def batch_of(records, size=BATCH):
    """`records` in batches of `size`, by observation id."""
    ordered = sorted(records, key=lambda r: int(r["id"]))
    return [ordered[i : i + size] for i in range(0, len(ordered), size)]


def candidate_for(gbif_key, index):
    """The candidate index a resolved GBIF key belongs to, or None."""
    return index.get(gbif_key) if gbif_key is not None else None


def seconds_until_next_utc_day(now):
    """Seconds from the aware datetime `now` to the next UTC midnight, plus a
    minute so the new day's allowance has surely started."""
    utc = datetime.timezone.utc
    tomorrow = now.astimezone(utc).date() + datetime.timedelta(days=1)
    midnight = datetime.datetime.combine(tomorrow, datetime.time(), tzinfo=utc)
    return int((midnight - now).total_seconds()) + 60


def _until_done(stage, wait):
    """Runs `stage` (which returns False when it stopped at a daily limit)
    until it finishes, sleeping to the next UTC day between runs when
    `wait`. False when it stopped and `wait` is off."""
    while not stage():
        if not wait:
            return False
        delay = seconds_until_next_utc_day(datetime.datetime.now(datetime.timezone.utc))
        print(f"waiting {delay / 3600:.1f} hours for the next day's allowance", flush=True)
        time.sleep(delay)
    return True


# What download_batch found: every photo there or gone for good, the day's
# budget spent first, or a photo whose download may work on a later run.
DONE, LIMIT, RETRY = "done", "limit", "retry"
# Failures that may pass: ft._get has already retried these a few times.
_MAY_PASS = (urllib.error.URLError, TimeoutError, ConnectionError, http.client.HTTPException)


def _gone(error):
    """Whether a download error means the photo is not there to fetch: a
    client error other than too many requests."""
    return isinstance(error, urllib.error.HTTPError) and 400 <= error.code < 500 and error.code != 429


def uncapped(url):
    """Whether a photo comes from iNaturalist's AWS Open Data bucket, whose
    downloads the daily byte cap does not count."""
    parts = urllib.parse.urlsplit(url)
    return parts.scheme == "https" and parts.hostname == OPEN_DATA_HOST


def download_batch(batch, paths, budget, download=None, workers=8):
    """Downloads each record's photo to its path, charging `budget` photo by
    photo. LIMIT when the day's budget ran out first, RETRY when a photo
    failed in a way that may pass later: either way the batch waits for
    another run, which fetches only the photos still missing, so none is
    charged twice. A photo gone from the bucket is skipped (DONE)."""
    download = download or ft._download
    lock = threading.Lock()

    def fetch(r):
        path = paths[r["id"]]
        if os.path.exists(path):
            return DONE
        capped = not uncapped(r["photo_url"])
        if capped:
            with lock:
                if budget.exhausted():
                    return LIMIT
        try:
            download(r["photo_url"], path)
        except _MAY_PASS as e:
            if _gone(e):
                print(f"skipping {r['id']}: {e}", flush=True)
                return DONE
            print(f"left for a later run {r['id']}: {e}", flush=True)
            return RETRY
        if capped:
            with lock:
                budget.spend(os.path.getsize(path))
        return DONE

    with concurrent.futures.ThreadPoolExecutor(workers) as pool:
        outcomes = set(pool.map(fetch, batch))
    return LIMIT if LIMIT in outcomes else RETRY if RETRY in outcomes else DONE


def embedding_array(vectors):
    """A batch's embeddings as one float32 array; (0, 0) when it kept none,
    which numpy cannot reshape from an empty list."""
    import numpy as np

    return np.asarray(vectors, dtype=np.float32) if vectors else np.zeros((0, 0), dtype=np.float32)


def _today():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")


class _Budget:
    """A daily count kept in a file, so a limit holds across runs."""

    def __init__(self, path, limit):
        self.path, self.limit = path, limit
        self.counts = ft._load(path, {})

    def used(self):
        return self.counts.get(_today(), 0)

    def spend(self, amount):
        self.counts[_today()] = self.used() + amount
        ft._save(self.path, self.counts)

    def exhausted(self):
        return self.used() >= self.limit


class _DailyLimit(Exception):
    """The day's request budget has no room for another attempt."""


def _charge(budget):
    """Charges one request attempt to `budget`, or stops the request when
    the day has no room for it."""
    if budget.exhausted():
        raise _DailyLimit
    budget.spend(1)


def _candidates(pack):
    with open(os.path.join(pack, "candidates.json"), encoding="utf-8") as fh:
        return json.load(fh)


# Stage lists.


def stage_lists(work, pack, limit=None):
    cands = _candidates(pack)
    index = {c["gbifKey"]: i for i, c in enumerate(cands)}
    names_path = os.path.join(work, "gbif_names.json")
    names = ft._load(names_path, {})
    budget = _Budget(os.path.join(work, "requests.json"), DAILY_REQUESTS)
    done = 0
    for i, c in enumerate(cands[:limit] if limit else cands):
        path = os.path.join(work, "lists", f"{c['gbifKey']}.json")
        if os.path.exists(path):
            continue
        query = urllib.parse.urlencode(
            {
                "taxon_name": c["scientificName"],
                "quality_grade": "research",
                "captive": "false",
                "photo_license": ",".join(ts.LICENCES),
                "per_page": 200,
                "order_by": "created_at",
                "order": "desc",
                "fields": ft.FIELDS,
            }
        )
        # Every attempt counts toward the day's limit, retries included, and
        # none is sent once the day has no room: the list waits for tomorrow.
        try:
            page = ft._get(f"{ft.INAT}?{query}", on_attempt=lambda: _charge(budget))
        except _DailyLimit:
            print(f"stopped at the day's {DAILY_REQUESTS} requests; run lists again tomorrow", flush=True)
            return False
        time.sleep(1.0)  # iNaturalist asks for at most one request a second.
        records = []
        for o in page.get("results") or []:
            taxon = o.get("taxon") or {}
            name = testset.species_name(taxon.get("name") or "", taxon.get("rank") or "")
            if name is None:
                continue
            if name not in names:
                names[name] = ft._gbif_key(name)
            resolved = candidate_for(names[name], index)
            if resolved is None:
                continue
            record = ts.observation_record(o, resolved, cands[resolved]["gbifKey"])
            if record:
                records.append(record)
        ft._save(names_path, names)
        ft._save(path, records)
        done += 1
        if done % 100 == 0:
            print(f"lists: {done} candidates this run, at {c['scientificName']} ({i + 1} of {len(cands)})", flush=True)
    return True


# Stage select.


def stage_select(work, csv_path):
    rows = testset.read_rows(csv_path)
    inat = [r for r in rows if r["source"] == "inaturalist"]
    test_ids = {r["id"] for r in inat}
    test_observers = {r["observer"] for r in inat if r["observer"]}
    by_id = {}
    folder = os.path.join(work, "lists")
    for name in sorted(os.listdir(folder)):
        if name.endswith(".json"):
            for r in ft._load(os.path.join(folder, name), []):
                by_id.setdefault(r["id"], r)
    records = ts.guard(list(by_id.values()), test_ids, test_observers)
    train, validation = ts.split(records, ts.validation_observers(records))
    train, validation = ts.cap(train), ts.cap(validation)
    ft._save(os.path.join(work, "selected.json"), {"train": train, "validation": validation})
    species = len({r["gbif_key"] for r in train})
    print(
        f"select: {len(by_id)} observations, {len(records)} after the leak guard; "
        f"{len(train)} training photos of {species} species, {len(validation)} validation photos",
        flush=True,
    )


# Stage embed.


def stage_embed(work, pack):
    import numpy as np

    import score

    selected = ft._load(os.path.join(work, "selected.json"), None)
    if selected is None:
        raise SystemExit("no selected.json; run select first")
    runner = score.Runner(pack, os.path.join(work, "score"))
    budget = _Budget(os.path.join(work, "downloads.json"), DAILY_BYTES)
    out_dir = os.path.join(work, "embeddings")
    os.makedirs(out_dir, exist_ok=True)
    batches = batch_of(selected["train"] + selected["validation"])
    left = 0
    for n, batch in enumerate(batches):
        meta_path = os.path.join(out_dir, f"{n:04d}.jsonl")
        if os.path.exists(meta_path):
            continue
        if budget.exhausted():
            print(f"stopped at the day's {DAILY_BYTES // 10**9} GB of photos; run embed again tomorrow", flush=True)
            return False
        photos_dir = os.path.join(work, "photos", f"{n:04d}")
        paths = {r["id"]: os.path.join(photos_dir, f"{r['id']}.jpg") for r in batch}
        outcome = download_batch(batch, paths, budget)
        if outcome == LIMIT:
            print(f"stopped at the day's {DAILY_BYTES // 10**9} GB of photos; run embed again tomorrow", flush=True)
            return False
        if outcome == RETRY:
            # Its photos stay on disk; a later run fetches only the rest.
            left += 1
            print(f"embed: batch {n + 1} of {len(batches)} left for a later run", flush=True)
            continue
        present = [r for r in batch if os.path.exists(paths[r["id"]])]
        raw = os.path.join(out_dir, f"{n:04d}.raw.jsonl")
        results = {}
        # A batch whose every download failed has nothing to hand the tool.
        if present:
            runner.analyze(score.BOTH, FIT, [paths[r["id"]] for r in present], raw)
            with open(raw, encoding="utf-8") as fh:
                for line in fh:
                    result = json.loads(line)
                    results[result["path"]] = result
            os.remove(raw)
        vectors, kept = [], []
        for r in present:
            crop = labelled_crop(results.get(paths[r["id"]], {"error": "no result"}), MIN_SIDE)
            if crop is None:
                continue
            vectors.append(crop["embedding"])
            kept.append({**r, "side": min(crop["pixelWidth"], crop["pixelHeight"])})
        np.save(os.path.join(out_dir, f"{n:04d}.npy"), embedding_array(vectors))
        # The metadata file is written last: its presence marks the batch done.
        with open(meta_path + ".partial", "w", encoding="utf-8") as fh:
            for r in kept:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")
        os.replace(meta_path + ".partial", meta_path)
        shutil.rmtree(photos_dir, ignore_errors=True)
        print(f"embed: batch {n + 1} of {len(batches)}, {len(kept)} of {len(batch)} photos kept", flush=True)
    if left:
        print(f"embed: {left} batches left for a later run; run embed again tomorrow", flush=True)
        return False
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("stage", choices=["lists", "select", "embed", "all"])
    parser.add_argument("--pack", required=True, help="the base pack folder (its candidates and models)")
    parser.add_argument("--set", default=ft.DEFAULT_CSV, help="the accuracy test set, for the leak guard")
    parser.add_argument("--work", default=DEFAULT_WORK)
    parser.add_argument("--limit", type=int, help="only the first N candidates (a dry run)")
    parser.add_argument("--wait", action="store_true", help="at a daily limit, sleep to the next UTC day and go on")
    args = parser.parse_args(argv)
    os.makedirs(args.work, exist_ok=True)
    if args.stage in ("lists", "all") and not _until_done(
        lambda: stage_lists(args.work, args.pack, args.limit), args.wait
    ):
        return 0
    if args.stage in ("select", "all"):
        stage_select(args.work, args.set)
    if args.stage in ("embed", "all") and not _until_done(lambda: stage_embed(args.work, args.pack), args.wait):
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
