#!/usr/bin/env python3
"""Trains the naming layer's rows and derives a pack that carries them
(issue #4724; docs/design/specs/2026-11-18-marine-life-naming-layer-design.md).

    python -I tool/species_pack/train_naming.py --base PACK --training WORK --out PACK2

One row per candidate, starting at its name row: the app scores a crop as
its unit embedding times each row, times logitScale (100), and never
rescales the rows, so a trained row may move and stretch. Training is
cross-entropy over every candidate plus a pull back toward the name rows;
rows of candidates with no training photo stay their name rows. The pull,
the epochs, a blend with the name rows and an overall sharpness are chosen
on the validation photos (post-cutoff photos of observers kept out of
training), never on the test set. The sharpness scales every row, trained
or not: it is the same as changing logitScale, so it leaves each crop's
ranking of trained and untrained candidates as it was.

The derived pack copies every file of the base pack but the rows and the
manifest, so candidates, regions and models stay byte for byte the same.
Beside it, not in the manifest's files: training.json (settings, seed,
counts) and training_photos.csv (each training photo and its credit).
Needs numpy and torch. Developer-run; not part of CI.
"""

import argparse
import datetime
import json
import math
import os
import shutil
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import manifest as mf  # noqa: E402
import testset  # noqa: E402
import training_set as ts  # noqa: E402

SCALE = 100.0
F16_MAX = 65504.0
ANCHORS = (1e-4, 1e-3, 1e-2)
BLENDS = (0.25, 0.5, 0.75, 1.0)
SHARPNESS = (0.75, 1.0, 1.5, 2.0)
MAX_EPOCHS = 30
PATIENCE = 3
LEARNING_RATE = 1e-3
BATCH = 4096
SEED = 0
LIST_URL = "https://github.com/submersion-app/submersion/releases/download/species-pack/training_photos.csv"


def _unit(x):
    norms = np.linalg.norm(x, axis=1, keepdims=True)
    return (x / np.where(norms > 0, norms, 1)).astype(np.float32)


def load(work, *, part, exclude=frozenset()):
    """(unit embeddings, candidate indices, records) of the `part`
    ("train" or "validation") of selected.json, less any species whose gbif
    key is in `exclude`."""
    with open(os.path.join(work, "selected.json"), encoding="utf-8") as fh:
        wanted = {r["id"] for r in json.load(fh)[part]}
    folder = os.path.join(work, "embeddings")
    vectors, records = [], []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".jsonl") or name.endswith(".raw.jsonl"):
            continue
        array = np.load(os.path.join(folder, name[: -len(".jsonl")] + ".npy"))
        with open(os.path.join(folder, name), encoding="utf-8") as fh:
            rows = [json.loads(line) for line in fh]
        if len(rows) != len(array):
            raise SystemExit(f"{name}: {len(rows)} records but {len(array)} embeddings")
        for r, v in zip(rows, array):
            if r["id"] in wanted and r["gbif_key"] not in exclude:
                records.append(r)
                vectors.append(v)
    if not vectors:
        raise SystemExit(f"no {part} photos in {folder}" + (" after the held-back species" if exclude else ""))
    x = _unit(np.asarray(vectors, dtype=np.float32))
    y = np.asarray([r["candidate"] for r in records], dtype=np.int64)
    return x, y, records


def _logits(rows, x):
    return _unit(x) @ rows.T.astype(np.float32) * SCALE


def validation_loss(rows, x, y, chunk=8192):
    """Mean cross-entropy over every candidate, as the app scores."""
    total = 0.0
    for i in range(0, len(x), chunk):
        logits = _logits(rows, x[i : i + chunk]).astype(np.float64)
        top = logits.max(axis=1, keepdims=True)
        lse = np.log(np.exp(logits - top).sum(axis=1)) + top[:, 0]
        total += float((lse - logits[np.arange(len(logits)), y[i : i + chunk]]).sum())
    return total / max(len(x), 1)


def top1(rows, x, y, chunk=8192):
    """The share of `x` whose best candidate over every candidate is `y`."""
    right = 0
    for i in range(0, len(x), chunk):
        right += int((_logits(rows, x[i : i + chunk]).argmax(axis=1) == y[i : i + chunk]).sum())
    return right / max(len(x), 1)


def _device():
    import torch

    return "mps" if torch.backends.mps.is_available() else "cpu"


def train(name_rows, x, y, *, anchor, epochs, lr, seed, device=None, validation=None):
    """Trained rows, starting at `name_rows`. With `validation` (x, y), the
    rows of the epoch with the lowest validation loss, stopping after
    PATIENCE epochs without improvement. Rows of candidates absent from `y`
    stay exactly their name rows."""
    import torch
    import torch.nn.functional as F

    device = device or _device()
    torch.manual_seed(seed)
    generator = torch.Generator().manual_seed(seed)
    seen = np.zeros(len(name_rows), dtype=bool)
    seen[np.unique(y)] = True
    names = torch.tensor(name_rows, dtype=torch.float32, device=device)
    rows = names.clone().requires_grad_(True)
    keep = torch.tensor(seen, device=device)[:, None].float()
    inputs = torch.tensor(_unit(x), device=device)
    labels = torch.tensor(y, dtype=torch.long, device=device)
    optimiser = torch.optim.Adam([rows], lr=lr)
    best, best_loss, stale = None, math.inf, 0
    for _ in range(epochs):
        order = torch.randperm(len(inputs), generator=generator).to(device)
        for i in range(0, len(inputs), BATCH):
            batch = order[i : i + BATCH]
            logits = inputs[batch] @ rows.T * SCALE
            pull = (((rows - names) * keep) ** 2).sum()
            loss = F.cross_entropy(logits, labels[batch]) + anchor * pull
            optimiser.zero_grad()
            loss.backward()
            rows.grad.mul_(keep)
            optimiser.step()
        if validation is not None:
            current = rows.detach().cpu().numpy()
            score = validation_loss(current, *validation)
            if score < best_loss:
                best, best_loss, stale = current.copy(), score, 0
            else:
                stale += 1
                if stale >= PATIENCE:
                    break
    out = best if best is not None else rows.detach().cpu().numpy()
    out = out.astype(np.float32)
    out[~seen] = name_rows[~seen]
    return out


def finish(trained, name_rows, *, blend, sharpness):
    """`sharpness` times a blend of the trained and name rows. Every row is
    scaled, untrained ones too: scaling only the trained rows would rank
    untrained species lower whenever `sharpness` is above 1."""
    return (sharpness * (blend * trained + (1 - blend) * name_rows)).astype(np.float32)


def search(name_rows, train_xy, validation_xy, *, seed=SEED, log=print):
    """(rows, settings) with the lowest validation loss over the grid."""
    best_rows, best = None, {"validation loss": math.inf}
    for anchor in ANCHORS:
        trained = train(
            name_rows, *train_xy, anchor=anchor, epochs=MAX_EPOCHS, lr=LEARNING_RATE, seed=seed, validation=validation_xy
        )
        for blend in BLENDS:
            for sharpness in SHARPNESS:
                rows = finish(trained, name_rows, blend=blend, sharpness=sharpness)
                loss = validation_loss(rows, *validation_xy)
                log(f"anchor {anchor} blend {blend} sharpness {sharpness}: validation loss {loss:.4f}")
                if loss < best["validation loss"]:
                    best_rows = rows
                    best = {"anchor": anchor, "blend": blend, "sharpness": sharpness, "validation loss": loss}
    if best_rows is None:
        raise SystemExit("no setting gave a finite validation loss: training diverged")
    best["validation top-1"] = top1(best_rows, *validation_xy)
    return best_rows, best


def f16_bytes(rows):
    """`rows` as little-endian 16-bit floats, refusing any value that is not
    finite or does not fit."""
    if not np.all(np.isfinite(rows)):
        raise ValueError("rows hold a value that is not finite")
    if np.abs(rows).max(initial=0) > F16_MAX:
        raise ValueError(f"rows hold a value above {F16_MAX:g}, which 16-bit floats cannot store")
    return np.asarray(rows, dtype="<f2").tobytes()


def _read_manifest(pack):
    with open(os.path.join(pack, "manifest.json"), encoding="utf-8") as fh:
        return json.load(fh)


def name_rows_of(pack):
    base = _read_manifest(pack)
    # Training scores crops as the app does, at the pack's logit scale.
    scale = base["classifier"].get("logitScale")
    if scale != SCALE:
        raise SystemExit(f"{pack} names at logitScale {scale}, but training assumes {SCALE:g}")
    with open(os.path.join(pack, "candidates.json"), encoding="utf-8") as fh:
        count = len(json.load(fh))
    size = base["classifier"]["embeddingSize"]
    return np.fromfile(os.path.join(pack, "text_embeddings.f16"), dtype="<f2").astype(np.float32).reshape(count, size)


def derive(base, out, rows, *, version, credit):
    """A pack in `out`: every file of `base` but the rows and manifest,
    `rows` as text_embeddings.f16, and a manifest with `version` and
    `credit` added."""
    manifest = _read_manifest(base)
    os.makedirs(out, exist_ok=True)
    files = []
    for entry in manifest["files"]:
        target = os.path.join(out, entry["name"])
        if entry["name"] == "text_embeddings.f16":
            with open(target, "wb") as fh:
                fh.write(f16_bytes(rows))
        else:
            shutil.copy2(os.path.join(base, entry["name"]), target)
        files.append(mf.file_entry(target, entry["engine"]))
    derived = mf.derive_manifest(manifest, files, pack_version=version, credits=[*manifest["credits"], credit])
    mf.write_manifest(os.path.join(out, "manifest.json"), derived)
    return derived


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base", required=True, help="the pack whose candidates and models the rows are for")
    parser.add_argument("--training", required=True, help="fetch_training.py's work folder")
    parser.add_argument("--out", required=True)
    parser.add_argument("--version", default=datetime.datetime.now(datetime.timezone.utc).strftime("%Y.%m.%d.%H%M"))
    parser.add_argument("--exclude-held-back", metavar="ACCURACY_CSV", help="train the rare-species check layer")
    parser.add_argument("--list-url", default=LIST_URL)
    parser.add_argument("--seed", type=int, default=SEED)
    args = parser.parse_args(argv)

    exclude = set()
    if args.exclude_held_back:
        exclude = set(ts.held_back_species(testset.read_rows(args.exclude_held_back)))
    name_rows = name_rows_of(args.base)
    x, y, records = load(args.training, part="train", exclude=exclude)
    xv, yv, _ = load(args.training, part="validation", exclude=exclude)
    print(f"{len(x)} training and {len(xv)} validation photos, {len(np.unique(y))} species", flush=True)
    rows, settings = search(name_rows, (x, y), (xv, yv), seed=args.seed)
    settings.update(
        {
            "seed": args.seed,
            "training photos": len(x),
            "validation photos": len(xv),
            "species trained": int(len(np.unique(y))),
            "held back species": sorted(exclude),
            "name rows validation loss": validation_loss(name_rows, xv, yv),
            "name rows validation top-1": top1(name_rows, xv, yv),
        }
    )
    derive(args.base, args.out, rows, version=args.version, credit=mf.training_credit(len(records), args.list_url))
    with open(os.path.join(args.out, "training.json"), "w", encoding="utf-8") as fh:
        json.dump(settings, fh, indent=1)
    ts.write_credits(os.path.join(args.out, "training_photos.csv"), records)
    print(json.dumps(settings, indent=1), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
