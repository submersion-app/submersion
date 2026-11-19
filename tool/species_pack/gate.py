#!/usr/bin/env python3
"""The naming layer's ship gate (issue #4724;
docs/design/specs/2026-11-18-marine-life-naming-layer-design.md, "The gate").

    python -I tool/species_pack/gate.py --baseline W0 --trained W1 --check W2

W0, W1 and W2 are score.py work folders: the baseline pack, the trained pack,
and the rare-species check pack scored with `--naming-from` the trained
pack. A trained pack ships only when all five hold on the pair of detectors:

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
    parser.add_argument("--set", default=os.path.join(os.path.dirname(__file__), "testdata", "accuracy_set.csv"))
    parser.add_argument("--set-key", default=SET_KEY, help="the scorer's detector set and fitting to gate on")
    args = parser.parse_args(argv)
    held_back = set(ts.held_back_species(testset.read_rows(args.set)))
    result = verdict(
        _read(args.baseline, "per_photo.json")[args.set_key],
        _read(args.trained, "per_photo.json")[args.set_key],
        _read(args.trained, "results.json")["evaluations"][args.set_key],
        rare_check(_read(args.check, "per_photo.json")[args.set_key], held_back),
    )
    with open(os.path.join(args.trained, "gate.json"), "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=1)
    print(json.dumps(result, indent=1))
    return 0 if result["ship"] else 1


if __name__ == "__main__":
    sys.exit(main())
