# Marine Life Naming Layer Runbook

A step-by-step runbook for finishing the naming layer (issue #4724), written so
that any coding agent with a shell and a file editor can carry it out without
other context, on a local model, over several days.

- **Design (read first):** `docs/design/specs/2026-11-18-marine-life-naming-layer-design.md`
- **Implementation plan (tasks 1 to 6 are done):** `docs/design/plans/2026-11-18-marine-life-naming-layer.md`
- **Branch:** the tools reached main in pull requests #4743 and #4752; the
  worktree is on `ericgriffin/feat-4724-faster-fetch`, the faster fetch
  (see Phase 7.0)
- **Worktree:** `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/feat-4724-naming-layer`
- **Pipeline (since 2026-11-19):** the tools moved to their own repository,
  `submersion-app/species-pack` (issue #4769), cloned at
  `/Users/ericgriffin/repos/submersion-app/species-pack`. `env.sh` points
  `TOOLS` at that clone and `SUBMERSION_APP` at the worktree above, whose
  `VisionPipeline.swift` embedded the training photos. A path below that
  names `tool/species_pack/` means that clone; Phases 7 to 9 change the
  pack repository, not this one, and are planned again with Eric at the
  Phase 6 checkpoint.

## How to use this runbook

- Work through the phases in order. Each step says what to run, what a good
  result looks like, and what to do when it is not good.
- **STOP** means: do nothing more, and report to Eric what you saw, quoting
  the command and its last 20 lines of output. Wait for his answer.
- **CHECKPOINT** means: report to Eric and wait for his go before the next
  phase, even when everything looks right.
- Keep a progress log: after every step, append one line to
  `$DATA/progress.md` with the date, the step number, and the result. A new
  run of the agent reads that file first and carries on from the last step
  that is marked done.
- Never improvise around a failure. A step that fails twice in the same way is
  a STOP.

## Rules (from Eric; these override anything else)

1. **Ask, never decide and go.** Anything this runbook does not settle is a
   question for Eric, not a choice for you.
2. **Never publish or replace a species pack.** Do not run `gh release` with
   `create`, `upload`, `edit` or `delete`, ever. Publishing is Eric's alone.
3. **Never push, open a pull request, or comment on GitHub** before the
   Phase 9 CHECKPOINT.
4. **No em-dashes anywhere** (the character U+2014), and no en-dashes or
   double hyphens used as punctuation, in any file, commit message or PR text.
   Use commas, colons, semicolons or parentheses.
5. **No mention of AI tools, assistants or models** in commits, files, PRs or
   comments: no `Co-Authored-By` trailers, no "generated with" lines.
6. **Run only the test files you write or change, by path.** Never run a test
   folder or the whole Flutter suite.
7. **Downloaded data lives only under `$DATA`**, never inside the repository,
   and any Python that reads downloaded data runs with `-I`.
8. **Do not contact anyone:** not iNaturalist, GBIF, model authors or dataset
   authors.
9. **Stay within the download limits:** about one iNaturalist API request a
   second and under 9,500 a day (iNaturalist asks for under 10,000), and
   under 20 GB a day of photos from any host but iNaturalist's AWS Open
   Data bucket, which states no limit and is not capped (Eric,
   2026-11-19). The fetcher enforces these; never raise them without
   Eric.
10. Commit messages follow `type(species-id): summary`, in plain words.
    Stage files by explicit path, never `git add -A` or `git add .`.

## Phase 0: Environment

### 0.1 Create the environment file

Every shell call may start fresh, so put the paths in one file and source it
at the start of every command.

```bash
mkdir -p /Users/ericgriffin/repos/submersion-app/naming-training
cat > /Users/ericgriffin/repos/submersion-app/naming-training/env.sh <<'EOF'
export REPO=/Users/ericgriffin/repos/submersion-app/submersion
export WT=$REPO/.claude/worktrees/feat-4724-naming-layer
export DATA=/Users/ericgriffin/repos/submersion-app/naming-training
export PY=$DATA/venv/bin/python
export TOOLS=/Users/ericgriffin/repos/submersion-app/species-pack
export SUBMERSION_APP=$WT
export CSV=$TOOLS/testdata/accuracy_set.csv
export BASE=$DATA/pack-0356
EOF
```

From here on every command block starts with
`source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh`.

### 0.2 Check the worktree and branch

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && git branch --show-current && git status --short && git log --oneline -1
```

Good: the branch is `ericgriffin/feat-4724-naming-layer` and `git status`
prints nothing. If the worktree folder is missing, recreate it:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git worktree add .claude/worktrees/feat-4724-naming-layer ericgriffin/feat-4724-naming-layer
```

If the branch itself is missing: STOP.

### 0.3 Python environment

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
[ -x $PY ] || python3.14 -m venv $DATA/venv
$PY -m pip install -q numpy==2.5.5 pillow==13.0.0 torch==2.15.0
$PY -c "import numpy, PIL, torch; print('ok', torch.__version__, torch.backends.mps.is_available())"
```

Good: `ok 2.15.0 True`. `False` for MPS is acceptable (training then runs on
the CPU, slower). Any import error: STOP.

### 0.4 The base pack

`$DATA/pack-0356` should already hold pack 2026.11.18.0356. Check it is
intact against the hashes the repository records:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 - <<'EOF'
import hashlib, json, os, sys
sys.path.insert(0, os.environ["TOOLS"])
import manifest as mf
base = os.environ["BASE"]
m = json.load(open(os.path.join(base, "manifest.json")))
assert m["packVersion"] == "2026.11.18.0356", m["packVersion"]
for f in m["files"]:
    digest = hashlib.sha256(open(os.path.join(base, f["name"]), "rb").read()).hexdigest()
    assert digest == f["sha256"], f["name"]
assert mf.contents_of(m["files"]) == mf._MEASURED_CONTENTS
print("base pack ok")
EOF
```

Good: `base pack ok`. If the folder is missing or a hash differs, download it
again (reading the public release is allowed; changing it is not):

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
rm -rf $BASE && mkdir -p $BASE && gh release download species-pack --dir $BASE
```

then rerun the check. If the release's `packVersion` is no longer
`2026.11.18.0356`: STOP (the published pack changed, and the baseline must be
chosen again).

### 0.5 The test photos and baseline scoring

`$DATA/score-baseline` should hold the scorer's work folder for pack 0356:
`photos/` (about 3,500 test photos, 1.6 GB), `runs/`, `results.json` and
`per_photo.json`.

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
ls $DATA/score-baseline/photos | wc -l
```

Good: about 3,500. If the photos are missing:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && $PY -I $TOOLS/fetch_testset.py photos-from-csv --work $DATA/score-baseline --csv $CSV
```

The baseline is scored again in Phase 5, with the branch's own code, so the
two packs are compared on identical vision output.

Mark Phase 0 done in `$DATA/progress.md`.

## Phase 1: Let the fetcher wait for the next day

Today `fetch_training.py` stops when it reaches a daily limit, and must be run
again the next day. Add a `--wait` flag so one run sleeps until the next UTC
day and carries on.

### 1.1 Write the failing test

Add to `tool/species_pack/fetch_training_test.py`, above
`if __name__ == "__main__":`:

```python
class NextDayTest(unittest.TestCase):
    def test_seconds_until_next_utc_day(self):
        import datetime

        utc = datetime.timezone.utc
        late = datetime.datetime(2026, 11, 19, 23, 0, tzinfo=utc)
        self.assertEqual(fetch_training.seconds_until_next_utc_day(late), 3600 + 60)
        sydney = datetime.timezone(datetime.timedelta(hours=11))
        same_instant = datetime.datetime(2026, 11, 20, 10, 0, tzinfo=sydney)
        self.assertEqual(fetch_training.seconds_until_next_utc_day(same_instant), 3600 + 60)
        midnight = datetime.datetime(2026, 11, 20, 0, 0, tzinfo=utc)
        self.assertEqual(fetch_training.seconds_until_next_utc_day(midnight), 86400 + 60)
```

Run it and see it fail with an `AttributeError`:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 $TOOLS/fetch_training_test.py
```

### 1.2 Implement

In `tool/species_pack/fetch_training.py`, add after `candidate_for`:

```python
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
```

In `main`, add the flag after `--limit`:

```python
    parser.add_argument("--wait", action="store_true", help="at a daily limit, sleep to the next UTC day and go on")
```

and replace the three stage calls at the end of `main` with:

```python
    if args.stage in ("lists", "all") and not _until_done(
        lambda: stage_lists(args.work, args.pack, args.limit), args.wait
    ):
        return 0
    if args.stage in ("select", "all"):
        stage_select(args.work, args.set)
    if args.stage in ("embed", "all") and not _until_done(lambda: stage_embed(args.work, args.pack), args.wait):
        return 0
    return 0
```

Also add one line to the module docstring's list of stages:
`--wait: at a daily limit, sleep to the next UTC day and carry on.`

### 1.3 Verify and commit

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 $TOOLS/fetch_training_test.py && python3.14 -m py_compile $TOOLS/fetch_training.py
git add tool/species_pack/fetch_training.py tool/species_pack/fetch_training_test.py
git commit -m "feat(species-id): let the training fetch wait for the next day's allowance"
```

Good: the tests print `OK`. Mark Phase 1 done.

## Phase 2: Fetch, select and embed the training photos

This phase runs for about a day: about 9 hours of lists (9,151 requests at
about 3.6 s each, within one day's 9,500), then about 90 GB of photos from
the AWS Open Data bucket, uncapped, so as fast as the connection and the
vision tool allow (about 37 ms a photo). It is resumable: a candidate's
list file, and a batch's `.jsonl`, mark that piece done, so restarting
after any interruption loses nothing.

### 2.1 Start it

Run it detached, kept awake, with its output in a text file:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && nohup caffeinate -i $PY -I $TOOLS/fetch_training.py all --wait \
  --pack $BASE --set $CSV --work $DATA/training > $DATA/fetch.txt 2>&1 &
echo $! > $DATA/fetch.pid
```

While it runs, leave the worktree in place: the embed stage loads the scorer
and builds the vision tool from `$WT` when it starts. Do not remove, archive
or switch the branch of the worktree until Phase 2 is done.

### 2.2 Check on it (every few hours)

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
ps -p $(cat $DATA/fetch.pid) > /dev/null && echo running || echo stopped
ls $DATA/training/lists 2>/dev/null | wc -l
ls $DATA/training/embeddings/*.jsonl 2>/dev/null | grep -v raw | wc -l
tail -5 $DATA/fetch.txt
cat $DATA/training/requests.json $DATA/training/downloads.json 2>/dev/null
```

What you should see, in order:

- `lists: N candidates this run, ...` lines every 100 candidates, one every
  few seconds. The lists folder grows to 9,151 files.
- `stopped at the day's 9500 requests` then `waiting X hours`, only if a
  run spans two UTC days. Expected then.
- `select: ... training photos of ... species, ... validation photos`. Write
  this line into `progress.md`; the findings need it. Expect roughly 150,000
  to 250,000 training photos of roughly 5,000 to 7,000 species, and 15,000
  to 40,000 validation photos. Numbers far outside these: STOP.
- `embed: batch K of M, kept of total photos kept` lines, about 90% kept
  each. A batch keeping under 70%: STOP.
- `stopped at the day's 20 GB of photos` should not appear, since every
  training photo so far comes from the uncapped open data bucket. If it
  does, photos are coming from another host: note it in `progress.md` and
  let it wait for the next day.

If the process is `stopped` before the last batch is embedded, look at the
end of `fetch.txt`:

- A network error, timeout, or HTTP 5xx: start it again with 2.1. It resumes.
- HTTP 429 (too many requests) repeatedly, or HTTP 403: STOP. Do not lower
  the pause or work around it.
- A Python traceback from our code: STOP.

### 2.3 Done when

- `ls $DATA/training/lists | wc -l` is 9,151;
- `$DATA/training/selected.json` exists;
- every batch has its `.jsonl` (the count equals M in the last `embed:` line);
- `$DATA/training/photos` holds no photos (`find $DATA/training/photos -type f | wc -l` is 0).

Mark Phase 2 done, with the select line and the final batch count.

## Phase 3: Train the shipped layer

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && $PY -I $TOOLS/train_naming.py --base $BASE --training $DATA/training \
  --out $DATA/pack-trained > $DATA/train.txt 2>&1; echo "exit $?"; tail -20 $DATA/train.txt
```

It searches 3 pulls, 4 blends and 4 sharpness values, choosing on the
validation photos. Expect tens of minutes to a few hours.

Check:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cat $DATA/pack-trained/training.json
cd $WT && python3.14 - <<'EOF'
import json, os
base = json.load(open(os.path.join(os.environ["BASE"], "manifest.json")))
new = json.load(open(os.path.join(os.environ["DATA"], "pack-trained", "manifest.json")))
changed = [f["name"] for f, g in zip(new["files"], base["files"]) if f["sha256"] != g["sha256"]]
print("changed:", changed, "| version:", new["packVersion"], "| provisional:", new["naming"]["provisional"])
print("credit:", new["credits"][-1]["licence"])
EOF
```

Good:

- `exit 0`;
- `changed: ['text_embeddings.f16']`, `provisional: True` (the bars are
  measured in Phase 5), credit `CC BY-NC 4.0`;
- in `training.json`, `validation top-1` above `name rows validation top-1`,
  and `validation loss` below `name rows validation loss`.

If the trained rows are not better than the name rows on validation: STOP
(training did not work, and scoring it would waste a day).

Write the `training.json` values into `progress.md`. Mark Phase 3 done.

## Phase 4: Train the rare-species check layer

The same training with every photo of 100 held-back test species removed,
at the shipped layer's chosen settings (pull, epochs, blend, sharpness) and
seed rather than a search of its own, so it differs from the shipped layer
only in its photos (Eric, 2026-11-19). This pack is never shipped.

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && $PY -I $TOOLS/train_naming.py --base $BASE --training $DATA/training \
  --out $DATA/pack-check --exclude-held-back $CSV --settings-from $DATA/pack-trained \
  > $DATA/train-check.txt 2>&1; echo "exit $?"
python3.14 - <<'EOF'
import json, os
d = os.environ["DATA"]
check = json.load(open(f"{d}/pack-check/training.json"))
shipped = json.load(open(f"{d}/pack-trained/training.json"))
keys = ("anchor", "epochs", "blend", "sharpness", "seed")
print(len(check["held back species"]), check["training photos"], shipped["training photos"])
print("same settings:", all(check[k] == shipped[k] for k in keys), {k: check[k] for k in keys})
EOF
```

Good: `exit 0`, `100` held-back species, fewer training photos than the
shipped layer, and `same settings: True`. Mark Phase 4 done.

## Phase 5: Score the three packs

Each scoring run needs the test photos in its work folder; link them rather
than copy them. A run takes from tens of minutes to a couple of hours (the
vision tool runs every test photo six ways).

### 5.1 Baseline, with this branch's code

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && $PY -I $TOOLS/score.py --pack $BASE --work $DATA/score-baseline > $DATA/score-baseline.txt 2>&1; echo "exit $?"
$PY -I -c "import json; print(json.load(open('$DATA/score-baseline/results.json'))['named right per detector'])"
```

Good: `exit 0` and `both` = 304 (the published measurement; the fish
detector 303, Megalodon 252). Within 5 of 304: write the number in
`progress.md` and carry on (the comparison uses this run, scored with the
same code as the trained pack). Further off: STOP.

### 5.2 Trained pack

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
mkdir -p $DATA/score-trained && ln -sfn $DATA/score-baseline/photos $DATA/score-trained/photos
cd $WT && $PY -I $TOOLS/score.py --pack $DATA/pack-trained --work $DATA/score-trained > $DATA/score-trained.txt 2>&1; echo "exit $?"
$PY -I -c "import json; r=json.load(open('$DATA/score-trained/results.json')); print(r['named right per detector']); print(r['evaluations']['both centreCrop']['bars after held-out gate'])"
```

Good: `exit 0`. Write both printed lines into `progress.md`.

### 5.3 Check pack, at the trained pack's bars

The check layer is named at the bars measured for the trained pack, so first
write those bars into a small folder that `--naming-from` can read (it reads
a pack folder's `manifest.json`; the trained pack's own manifest still says
provisional until Phase 7):

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
mkdir -p $DATA/score-trained/bars-pack && python3.14 - <<'PYEOF'
import json, os
d = os.environ["DATA"]
r = json.load(open(f"{d}/score-trained/results.json"))
both = [m for m in r["measured"] if len(m["detectorIds"]) == 2][0]
assert both["cropFit"] == "centreCrop", f"the pair measured best with {both['cropFit']}"
m = json.load(open(f"{d}/pack-trained/manifest.json"))
m["naming"] = both["naming"]
json.dump(m, open(f"{d}/score-trained/bars-pack/manifest.json", "w"), indent=1)
print(both["naming"])
PYEOF
```

An assertion error means the scorer chose another crop fitting for the
pair than the packs use (`centreCrop`), so its measured bars are not the
ones the gate or the app would read: STOP.

Then score the check pack at those bars:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
mkdir -p $DATA/score-check && ln -sfn $DATA/score-baseline/photos $DATA/score-check/photos
cd $WT && $PY -I $TOOLS/score.py --pack $DATA/pack-check --work $DATA/score-check \
  --naming-from $DATA/score-trained/bars-pack > $DATA/score-check.txt 2>&1; echo "exit $?"
```

Good: `exit 0`. Mark Phase 5 done.

## Phase 6: The gate

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 -I $TOOLS/gate.py --baseline $DATA/score-baseline --trained $DATA/score-trained \
  --check $DATA/score-check --baseline-pack $BASE --trained-pack $DATA/pack-trained \
  --check-pack $DATA/pack-check --set $CSV > $DATA/gate.txt; echo "exit $?"; cat $DATA/gate.txt
```

`gate.py` first confirms that each scoring folder was made on its pack (its
version and every file's hash), that the three cover the same photos, that the check scores
were named at the trained pack's bars, and that `pack-check` held back
exactly the test set's held-back species; any mismatch stops it with a
message, which is a STOP here. It writes `$DATA/score-trained/gate.json` and exits 0
when the trained pack may ship, 1 when it may not. Its five items:

| Item | Passes when |
| --- | --- |
| `more_named_right` | significantly more held-out natural photos named right than the baseline (p < 0.05) |
| `confident_bar` | the pair's confident bar with a location is a real bar (at most 1.0, not 1.01) |
| `no_group_worse` | no animal group named right significantly less often |
| `junk` | junk named on at most 2% of tune-half junk crops |
| `rare_species` | wrong confident names on at most 2% of the held-back species' photos |

Copy `gate.txt` into `progress.md`. Then CHECKPOINT: report every item's
numbers to Eric. Do not start Phase 7 until he answers. If `ship` is false,
Phase 7 is skipped; Eric decides the next step (the design's planned next
step is approach B, which is a new design, not something to start here).

## Phase 7: Record the measured bars (only when the gate passed and Eric said go)

### 7.0 The branch

The tools went to main in pull requests that refer to #4724 without closing
it: the fetcher, trainer, gate and scorer output (#4743), the check layer at
the shipped layer's settings (#4752), and the faster fetch. Phases 7 and 8
make the last one, which closes #4724. Check that no earlier one is still
open:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && gh pr list --state open --search "4724 in:body" --json number,title,url
```

- `[]`: start the branch from main in the same worktree:
  `git fetch origin && git switch -c ericgriffin/feat-4724-naming-measured origin/main`.
- Any pull request listed: STOP, and ask Eric whether to wait for it, or to
  add these commits to it.

### 7.1 Add the measured entry

In `tool/species_pack/manifest.py`, after `_FINDINGS = ...`, add the trained
file's contents, copying the three hashes from the trained pack:

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 -c "
import json, sys; sys.path.insert(0, '$TOOLS'); import manifest as mf
m = json.load(open('$DATA/pack-trained/manifest.json')); print(json.dumps(mf.contents_of(m['files']), indent=4))
r = json.load(open('$DATA/score-trained/results.json')); print(json.dumps([e for e in r['measured'] if len(e['detectorIds']) == 2][0], indent=4))"
```

If the printed entry's `cropFit` is not `centreCrop`: STOP (the entry below
is recorded for `centreCrop`, the fitting the packs use).

Add, using those printed values:

```python
# The trained naming rows (issue #4724), on the same candidates and regions.
_TRAINED_CONTENTS = {
    "candidates.json": "<hash>",
    "text_embeddings.f16": "<hash>",
    "regions.bin": "<hash>",
}
_TRAINED_FINDINGS = "docs/design/findings/<the findings file from Phase 8>"
```

and append one entry to the end of `NAMING_MEASURED`, preceded by a one-line
comment naming issue #4724 and the trained pack's version:

```python
    {
        "naming": {<the printed "naming" dict>},
        "detectorIds": [DETECTORS["cfd"]["id"], DETECTORS["megalodon"]["id"]],
        "classifierId": "bioclip-2-vitl14-2957b32",
        "cropFit": "centreCrop",
        "packVersion": "<the trained pack's version>",
        "contents": _TRAINED_CONTENTS,
        "findings": _TRAINED_FINDINGS,
    },
```

Only the pair's entry is added (the design: only the pair is gated).

### 7.2 Rewrite the trained pack's manifest with the measured bars

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 - <<'EOF'
import json, os, sys
sys.path.insert(0, os.environ["TOOLS"])
import manifest as mf
d, base = os.environ["DATA"], os.environ["BASE"]
pack = f"{d}/pack-trained"
m = json.load(open(f"{pack}/manifest.json"))
out = mf.derive_manifest(json.load(open(f"{base}/manifest.json")), m["files"], pack_version=m["packVersion"], credits=m["credits"])
assert out["naming"]["provisional"] is False, out["naming"]
mf.write_manifest(f"{pack}/manifest.json", out)
print("measured:", out["naming"])
EOF
```

Good: `measured: {... "provisional": False ...}`. An assertion error means the
entry does not match the trained files: STOP.

### 7.3 Test and commit

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 $TOOLS/manifest_test.py
git add tool/species_pack/manifest.py
git commit -m "feat(species-id): measured bars for the trained naming rows"
```

The commit waits until the findings file exists if `_TRAINED_FINDINGS` names
it; do Phase 8.1 first in that case and commit both together.

## Phase 8: Write it down

### 8.1 Findings

Create `docs/design/findings/<YYYY-MM-DD>-marine-life-naming-layer.md` (the
date the gate ran) with these sections, filling every number from the files
named:

1. **Summary**: shipped or not, and the headline (pair named right, baseline
   against trained, from `gate.json` `more_named_right`; the confident bar).
2. **Training data**: the `select:` line from `progress.md`; licences CC0, CC
   BY and CC BY-NC; dates and leak guard as in the design; observations per
   candidate capped at 50 and 5 per observer; batches embedded and photos
   kept.
3. **Training**: every value in `pack-trained/training.json` (pull, blend,
   sharpness, seed, validation loss and top-1 against the name rows).
4. **The gate**: one table row per gate item with its numbers from
   `gate.json`, including the per-group table from `no_group_worse`.
5. **Rare-species check**: photos, confident wrong, confident right, rate and
   interval from `gate.json` `rare_species`; that the check layer trained
   without 100 species (`pack-check/training.json`).
6. **Bars**: the trained pack's measured bars for the pair, and the
   baseline's, side by side.
7. **Known limits**: only the newest 200 observations per species were
   listed, so the per-observer cap left common species near 40 photos rather
   than 50; video tracks (averaged embeddings) are not measured by any bar;
   the iNaturalist terms and Creative Commons questions from the design's
   "Open risks".

Use plain sentences and tables. No em-dashes.

### 8.2 Developer guide

In `docs/developer/species-identification.md`, add a section
`## Training the naming layer` after `## Measuring accuracy` (before
`## Trying a pack locally`), covering:

- what the layer is (one trained row per candidate in `text_embeddings.f16`,
  no app change), linking the design;
- the commands from Phases 2 to 6 of this runbook, with `$DATA` described as
  "a work folder outside the repository";
- that the trained file is CC BY-NC 4.0, and `build_pack.py` still builds the
  untrained pack, the open alternative;
- that publishing a trained pack also uploads `training_photos.csv` to the
  `species-pack` release as a file the manifest does not list, and that only
  Eric publishes.

### 8.3 Program design pointer

In `docs/design/specs/2026-11-17-marine-life-identification-program-design.md`,
under `## Training later`, change the line

`- Next is a small naming layer trained on top of BioCLIP 2's embeddings.`

to

`- Next is a small naming layer trained on top of BioCLIP 2's embeddings:
  designed in [the naming layer design](2026-11-18-marine-life-naming-layer-design.md)
  (issue #4724).`

### 8.4 Commit

```bash
source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
cd $WT && python3.14 $REPO/scripts/check_docs_links.py 2>&1 | tail -3
grep -rn $'\xe2\x80\x94' docs/design/findings docs/developer/species-identification.md docs/design/specs/2026-11-17-marine-life-identification-program-design.md && echo "EM-DASH FOUND"
git add docs/design/findings/<the file> docs/developer/species-identification.md \
  docs/design/specs/2026-11-17-marine-life-identification-program-design.md
git commit -m "docs(species-id): record the naming layer's training and gate"
```

Good: the link check passes and no `EM-DASH FOUND`. Mark Phase 8 done.

## Phase 9: CHECKPOINT before anything leaves this machine

Report to Eric:

- the gate result and its five items;
- `git log --oneline origin/main..HEAD`;
- where the trained pack is (`$DATA/pack-trained`), its version, size, and
  `training_photos.csv` row count.

Then wait. Eric decides whether and when to push, open the pull request and
publish. If he says to open the pull request:

1. Prepare the Flutter side of the worktree, since the pre-push hook analyzes
   the whole repository:

   ```bash
   source /Users/ericgriffin/repos/submersion-app/naming-training/env.sh
   cd $WT && git submodule update --init --recursive && flutter pub get \
     && dart run build_runner build --delete-conflicting-outputs
   ```

2. `git fetch origin && git rebase origin/main`, then rerun
   `manifest_test.py` with `python3.14`, the one test file this branch
   touches.
3. `git push -u origin ericgriffin/feat-4724-naming-measured` (the hook runs
   its checks; a failure there is a STOP).
4. Open the pull request with `gh pr create --base main`, title
   `feat(species-id): a naming layer trained on photos`, and a body from the
   repository template (`.github/pull_request_template.md`) with:
   `Closes #4724` under Related Issue, naming the tools pull request it
   builds on; a Summary of the gate numbers and what the measured bars
   change; the Changes as one bullet each for the measured entry, the
   findings and the developer guide; the Test Plan listing
   `manifest_test.py`; Browser: tick "Nothing device-only"; and the
   Screenshots section deleted (nothing under a UI path changes). No mention
   of AI tools.
5. Report the pull request link to Eric. Reviews, Copilot and publishing are
   his to start.
