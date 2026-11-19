#!/usr/bin/env python3
"""The naming layer's ship gate (issue #4724;
docs/design/specs/2026-11-18-marine-life-naming-layer-design.md, "The gate").

    python -I tool/species_pack/gate.py --baseline W0 --baseline-pack P0 \
        --trained W1 --trained-pack P1 --check W2 --check-pack P2

W0, W1 and W2 are score.py work folders: the baseline pack P0, the trained
pack P1, and the rare-species check pack P2 scored with `--naming-from` the
trained pack. The gate first confirms that each folder was scored on its
pack (its version and every file's hash), that all three cover the same
photos, that W2 was named at the trained pack's bars, that each trained
pack's training.json describes its own rows, that P1 and P2 were both
built from P0 (every file but the rows the same, training started from
its name rows), and that P2 held back exactly the test set's held-back
species and was trained with P1's chosen settings. A trained pack ships
only when all five hold on the pair of detectors at centre crop:

1. significantly more held-out natural photos named right at each pack's
   own bars (paired McNemar test, p < 0.05);
2. a confident bar with a location survives the held-out gate;
3. no group named right significantly less often (held-out photos);
4. junk named on at most 2% of tune-half junk crops;
5. the rare-species check: confident wrong names on at most 2% of the
   held-back species' photos.

Standard library only.
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bars as bar_search  # noqa: E402
import testset  # noqa: E402
import training_set as ts  # noqa: E402

ALPHA = 0.05
JUNK_LIMIT = 0.02
RARE_LIMIT = 0.02
SET_KEY = "both centreCrop"


def _paired(baseline, trained, ids):
    only_trained = sum(1 for i in ids if trained[i]["named_right"] and not baseline[i]["named_right"])
    only_baseline = sum(1 for i in ids if baseline[i]["named_right"] and not trained[i]["named_right"])
    return only_trained, only_baseline, bar_search.mcnemar_p(only_trained, only_baseline)


def more_named_right(baseline, trained):
    ids = [i for i, p in trained.items() if p["held_out"] and p["sample"] == "natural" and i in baseline]
    only_trained, only_baseline, p = _paired(baseline, trained, ids)
    return {
        "pass": p < ALPHA and only_trained > only_baseline,
        "photos": len(ids),
        "baseline named right": sum(1 for i in ids if baseline[i]["named_right"]),
        "trained named right": sum(1 for i in ids if trained[i]["named_right"]),
        "only trained": only_trained,
        "only baseline": only_baseline,
        "p": p,
    }


def confident_bar(trained_eval):
    bar = trained_eval["bars after held-out gate"]["confident"]
    return {"pass": bar < bar_search.NEVER, "confidentScore": bar}


def no_group_worse(baseline, trained):
    groups = {}
    for i, p in trained.items():
        if p["held_out"] and i in baseline:
            groups.setdefault(p["group"], []).append(i)
    by_group, worse = {}, []
    for group, ids in sorted(groups.items()):
        only_trained, only_baseline, p = _paired(baseline, trained, ids)
        by_group[group] = {"photos": len(ids), "only trained": only_trained, "only baseline": only_baseline, "p": p}
        if p < ALPHA and only_baseline > only_trained:
            worse.append(group)
    return {"pass": not worse, "worse": worse, "by group": by_group}


def junk(trained_eval):
    rate = trained_eval["junk named (tune, at the chosen bars)"]
    return {"pass": rate <= JUNK_LIMIT, "junk named": rate}


def rare_check(check_per_photo, held_back):
    """Confident names on every test photo of the held-back species, named
    by the check layer at the shipped layer's bars."""
    photos = [p for p in check_per_photo.values() if p["gbif_key"] and int(p["gbif_key"]) in held_back]
    wrong = sum(1 for p in photos if p["confident_wrong"])
    right = sum(1 for p in photos if p["confident_right"])
    rate = wrong / len(photos) if photos else None
    return {
        "pass": bool(photos) and rate <= RARE_LIMIT,
        "photos": len(photos),
        "confident wrong": wrong,
        "confident right": right,
        "rate": rate,
        "interval": bar_search.wilson(wrong, len(photos), bar_search.Z_TWO_SIDED),
    }


def confirm_scored(results, manifest, label):
    """Stops unless `results` (score.py's results.json) were scored on the
    pack `manifest` describes: its version and every file's hash, models
    and naming files alike, so a stale run, or another pack that shares
    some of its files, cannot stand in."""
    if "files" not in results:
        raise SystemExit(f"the {label} scores do not record their pack's files; score it again with this score.py")
    if results.get("pack") != manifest.get("packVersion"):
        raise SystemExit(f"the {label} scores were made on pack {results.get('pack')}, not {manifest.get('packVersion')}")
    if results["files"] != {f["name"]: f["sha256"] for f in manifest["files"]}:
        raise SystemExit(f"the {label} scores were not made on the {label} pack's files")


def confirm_training_record(training, manifest, label):
    """Stops unless a pack's training.json describes that pack's rows: the
    rows hash it recorded is the one its manifest lists. This catches a
    stale record left beside rows trained later, not a hand-edited one;
    whoever could forge it could rewrite the scores as well."""
    if training.get("rows sha256") != ts.rows_sha256(manifest):
        raise SystemExit(f"the {label} pack's training.json does not describe its rows; train it again")


def _all_but_rows(manifest):
    return {f["name"]: f["sha256"] for f in manifest["files"] if f["name"] != "text_embeddings.f16"}


def confirm_same_base(base_manifest, packs, records):
    """Stops unless every pack in `packs` (label to manifest) was built from
    the baseline pack: each file but the rows the same, and its training
    (records, label to training.json) started from the baseline's name
    rows. So the check layer differs from the shipped one in its photos,
    not in its candidates, regions, models or starting rows."""
    for label, manifest in packs.items():
        if _all_but_rows(manifest) != _all_but_rows(base_manifest):
            raise SystemExit(f"the {label} pack's files other than its rows differ from the baseline pack's")
    for label, record in records.items():
        if record.get("base rows sha256") != ts.rows_sha256(base_manifest):
            raise SystemExit(f"the {label} pack was not trained from the baseline pack's name rows")


def confirm_same_photos(*per_photo):
    """Stops unless every per-photo map covers the same photos, so no
    comparison quietly drops the ones a stale or partial run missed."""
    first = set(per_photo[0])
    if any(set(p) != first for p in per_photo[1:]):
        raise SystemExit("the baseline, trained and check scores cover different photos")


def confirm_check_pack(training, held_back, check_eval, trained_eval, trained_training):
    """Stops unless the check scores stand for the rare-species check: the
    check pack held back exactly `held_back` and was trained with the
    trained pack's chosen settings (their training.json files), and it was
    named at the trained pack's bars."""
    if sorted(training.get("held back species") or []) != sorted(held_back):
        raise SystemExit("the check pack held back other species than the test set's held-back ones")
    shipped_settings = {k: trained_training.get(k) for k in ts.SETTING_KEYS}
    if None in shipped_settings.values() or any(training.get(k) != v for k, v in shipped_settings.items()):
        raise SystemExit(f"the check pack was not trained with the trained pack's settings {shipped_settings}")
    named_at = check_eval["bars after held-out gate"]
    shipped = trained_eval["bars after held-out gate"]
    if any(abs(named_at[k] - shipped[k]) > 1e-9 for k in shipped):
        raise SystemExit(f"--check was named at bars {named_at}, not the trained pack's {shipped}")


def verdict(baseline, trained, trained_eval, rare):
    out = {
        "more_named_right": more_named_right(baseline, trained),
        "confident_bar": confident_bar(trained_eval),
        "no_group_worse": no_group_worse(baseline, trained),
        "junk": junk(trained_eval),
        "rare_species": rare,
    }
    out["ship"] = all(v["pass"] for v in out.values())
    return out


def _read(folder, name):
    with open(os.path.join(folder, name), encoding="utf-8") as fh:
        return json.load(fh)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--trained", required=True)
    parser.add_argument("--check", required=True)
    parser.add_argument("--baseline-pack", required=True, help="the pack --baseline was scored on")
    parser.add_argument("--trained-pack", required=True, help="the pack --trained was scored on")
    parser.add_argument("--check-pack", required=True, help="the check layer's pack, to confirm what it held back")
    parser.add_argument("--set", default=os.path.join(os.path.dirname(__file__), "testdata", "accuracy_set.csv"))
    args = parser.parse_args(argv)
    held_back = set(ts.held_back_species(testset.read_rows(args.set)))
    results = {}
    manifests = {}
    for label, folder, pack in (
        ("baseline", args.baseline, args.baseline_pack),
        ("trained", args.trained, args.trained_pack),
        ("check", args.check, args.check_pack),
    ):
        results[label] = _read(folder, "results.json")
        manifests[label] = _read(pack, "manifest.json")
        confirm_scored(results[label], manifests[label], label)
    per_photo = {
        label: _read(folder, "per_photo.json")[SET_KEY]
        for label, folder in (("baseline", args.baseline), ("trained", args.trained), ("check", args.check))
    }
    confirm_same_photos(*per_photo.values())
    training = {
        label: _read(pack, "training.json") for label, pack in (("trained", args.trained_pack), ("check", args.check_pack))
    }
    for label, record in training.items():
        confirm_training_record(record, manifests[label], label)
    confirm_same_base(manifests["baseline"], {label: manifests[label] for label in training}, training)
    trained_eval = results["trained"]["evaluations"][SET_KEY]
    confirm_check_pack(
        training["check"], held_back, results["check"]["evaluations"][SET_KEY], trained_eval, training["trained"]
    )
    result = verdict(
        per_photo["baseline"],
        per_photo["trained"],
        trained_eval,
        rare_check(per_photo["check"], held_back),
    )
    with open(os.path.join(args.trained, "gate.json"), "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=1)
    print(json.dumps(result, indent=1))
    return 0 if result["ship"] else 1


if __name__ == "__main__":
    sys.exit(main())
