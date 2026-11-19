# Naming Level Accuracy Without a Location Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish, as each naming level's and Surer's `precision`, the lower of its held-out precision with and without a location, so no accuracy line in settings overstates.

**Architecture:** `levels.py` measures both sides and combines them into one shown figure, which its drop rules compare. `score.py` writes that figure into its measured entries and `report.py` shows both sides. A scorer rerun on the published pack then refreshes `NAMING_MEASURED`, the findings and the relevelled manifest. No app change.

**Tech Stack:** Python 3.14 standard library (`unittest`), the species pack tooling in `tool/species_pack/`.

**Spec:** `docs/design/specs/2026-11-19-marine-life-level-accuracy-without-location-design.md`

## Global Constraints

- No app change, no manifest format change, no change to any bar.
- The shown figure is the lower of the two held-out precisions; a side that names nothing held out has no figure, and the other side stands.
- Precision is carried at `PRECISION_PLACES` (3) through `levels.manifest_precision`.
- Expected for the published pair (pack `2026.11.18.0356`, both detectors, centre crop): Surer 0.897, Balanced 0.808, Eager 0.755.
- The relevelled manifest is uploaded to the `species-pack` release only on the maintainer's go-ahead.
- Run only the test files changed, by path. No em-dash characters; no mention of the tool in commits or PR text.

## Review Focus

1. A level whose no-location side names nothing held out: its figure is the with-location one, not none (Task 1, `test_shown_precision_takes_the_lower_side_that_names_something`).
2. A level whose no-location side names only wrong crops: a figure of 0 is no share to show, so the level is left out (Task 1, same test plus `manifest_precision(0.0)`, already pinned).
3. Surer's own figure is lower without a location: levels are then held below that lower figure (Task 1, `test_surers_figure_is_its_lower_side` with the existing ordering test).
4. `report.py` reading a `results.json` from before this change, without the new keys: it still writes the report, with "n/a" (Task 2, Step 3).
5. The refreshed measured entries still read as sound levels to `manifest.level_problems` and the app (Task 3, `manifest_test.py` and the relevel diff).

---

### Task 1: Measure both sides and show the lower

**Files:**
- Modify: `tool/species_pack/levels.py` (`rates`, `measure`, new `shown_precision`, module and function docstrings)
- Test: `tool/species_pack/levels_test.py`

**Interfaces:**
- Produces: `rates(bars, held_nat, held_junk, *, min_side) -> dict` with the existing keys plus `"precision without location"` and `"coverage without location"` (rate dicts like `"precision"`).
- Produces: `shown_precision(with_rate: dict, without_rate: dict) -> float | None`, the lower `value` of the sides whose `n` is above 0, unrounded; None when neither names anything.
- Produces: `measure(...)` returns `(levels, surer_precision, surer_rates)`, where `surer_precision` is now Surer's `shown_precision` (unrounded, may be 0), `surer_rates` is `rates` at Surer's bars (the third value was added in code review, so `score.py` need not measure Surer twice), and each level dict gains `"precision"`: its `manifest_precision(shown_precision(...))`.

- [ ] **Step 1: Write the failing tests** in `levels_test.py`. Add a helper `split(with_top, without_top, correct)` beside `record`, building a crop whose two namings have different top scores (limited with a location, not without, as `record` does). Then:

```python
def test_rates_measure_both_sides(self):
    level = bars.Bars(min_open=0.5, suggest=0.5, suggest_no_location=0.7, confident=NEVER, confident_no_location=NEVER)
    held = [record(0.6, True)] * 8 + [record(0.6, False)] * 2 + [record(0.8, True)] * 3
    out = levels.rates(level, held, [], min_side=64)
    self.assertAlmostEqual(out["precision"]["value"], 11 / 13)
    self.assertEqual(out["precision without location"]["value"], 1.0)
    self.assertAlmostEqual(out["coverage without location"]["value"], 3 / 13)

def test_shown_precision_takes_the_lower_side_that_names_something(self):
    rate = lambda value, n: {"value": value, "n": n}
    self.assertEqual(levels.shown_precision(rate(0.8, 10), rate(0.7, 5)), 0.7)
    self.assertEqual(levels.shown_precision(rate(0.8, 10), rate(None, 0)), 0.8)
    self.assertEqual(levels.shown_precision(rate(0.0, 4), rate(0.9, 9)), 0.0)
    self.assertIsNone(levels.shown_precision(rate(None, 0), rate(None, 0)))

def test_surers_figure_is_its_lower_side(self):
    # 90 right both ways; 20 wrong crops the location limit keeps below
    # Surer's bar are named without a location.
    fish = [record(0.9, True)] * 90 + [split(0.5, 0.85, False)] * 20
    _, surer_precision = measure(fish)
    self.assertAlmostEqual(surer_precision, 90 / 110)

def test_a_level_less_often_right_without_a_location_shows_that(self):
    fish = (
        [record(0.9, True)] * 100 + [record(0.55, True)] * 70 + [record(0.55, False)] * 30
        + [split(0.3, 0.56, False)] * 5
    )
    found, _ = measure(fish)
    self.assertEqual([level["id"] for level in found], ["balanced"])
    held = found[0]["held-out"]
    self.assertEqual(held["precision"]["value"], 0.85)
    self.assertAlmostEqual(held["precision without location"]["value"], 170 / 205)
    self.assertEqual(found[0]["precision"], 0.829)
```

- [ ] **Step 2: Run** `python3.14 tool/species_pack/levels_test.py`. Expected: the four new tests ERROR or FAIL (`KeyError: 'precision without location'`, `AttributeError: shown_precision`, Surer's 1.0, no `"precision"` key); the six existing tests pass.

- [ ] **Step 3: Implement** in `levels.py`. `rates` names the held-out "without" crops with `bar_search.named` and adds the two rate dicts via `metrics.coverage_precision`. `shown_precision` as in Interfaces. In `measure`, Surer's figure becomes `shown_precision` of its two sides, each level's `shown = manifest_precision(shown_precision(...))` replaces the with-location value in the existing "none to show" and "higher than the level above" checks, the level dict gains `"precision": shown`, and `above_precision` takes the unrounded shown figure. Update the module docstring and `measure`'s to say the figure a diver is shown is the lower side.

- [ ] **Step 4: Run** `python3.14 tool/species_pack/levels_test.py`. Expected: OK, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add tool/species_pack/levels.py tool/species_pack/levels_test.py
git commit -m "feat(species-pack): measure each level's accuracy without a location"
```

### Task 2: Write and report the shown figure

**Files:**
- Modify: `tool/species_pack/score.py` (`_measured_entry`)
- Modify: `tool/species_pack/report.py` (the "Naming levels" table)
- Modify: `docs/developer/species-identification.md` (its "Naming levels" section, where it says how a level's precision is measured)

**Interfaces:**
- Consumes: from Task 1, each level's `"precision"` and its `"held-out"` keys `"precision without location"`, `"coverage without location"`; `measure`'s Surer figure, already stored by `evaluate` as `"surer precision"`.

- [ ] **Step 1:** In `_measured_entry`, each level's `"precision"` is `level["precision"]` (already rounded) instead of the with-location value; Surer's line is unchanged, since `"surer precision"` now holds the shown figure.

- [ ] **Step 2:** In `report.py`, the "Naming levels" table gains columns `precision, no location`, `coverage, no location` and `shown` (the level's `"precision"`, as a percentage, or "n/a"). Read the new keys with `.get`, so `_pct(None)` gives "n/a". The sentence over the table says precision and coverage are shown with and without a location, and that `shown` is the lower precision, which the manifest carries.

- [ ] **Step 3: Verify** the report still renders a `results.json` from before this change:

Run: `python3.14 -c "import json, sys; sys.path.insert(0, 'tool/species_pack'); import report; report.write_report(json.load(open('.superpowers/sdd/2026-11-18-marine-life-naming-levels/results.json')), '<scratchpad>/old-report.md')"` and read the "Naming levels" rows.
Expected: no exception; the new columns read "n/a".

- [ ] **Step 4:** In the developer doc, say a level's precision is the lower of its held-out precisions with and without a location.

- [ ] **Step 5: Commit**

```bash
git add tool/species_pack/score.py tool/species_pack/report.py docs/developer/species-identification.md
git commit -m "feat(species-pack): write and report the lower of each level's accuracies"
```

### Task 3: Measure the published pack and record it

**Files:**
- Modify: `tool/species_pack/manifest.py` (`NAMING_MEASURED`: each entry's `precision` and its levels' `precision`)
- Modify: `docs/design/findings/2026-11-17-marine-life-measured-accuracy.md` ("Naming levels")

**Interfaces:**
- Consumes: Task 2's measured entries in `results.json`.

- [ ] **Step 1:** In the maintainer's Terminal panel (this session's shell cannot read `build/`), from the worktree root, run the scorer on the published pack already in `build/species_pack`, then copy `results.json` and `report.md` from `build/species_accuracy_work/` into this plan's workspace (`.superpowers/sdd/2026-11-19-marine-life-level-accuracy-without-location/`) and write the exit code to `score.exit` there:

```bash
build/.venv-species-pack/bin/python -I tool/species_pack/score.py --pack build/species_pack
```

Expected: exit 0; every bar and Surer with-location figure unchanged from the 2026-11-19 levels run; the pair's measured entry carries `precision` 0.897 and levels 0.808 (Balanced) and 0.755 (Eager).

- [ ] **Step 2:** Copy each measured entry's `precision` and levels' `precision` into `NAMING_MEASURED`, then check by script that every `naming` key equals `results.json`'s `measured` entries and that `manifest.level_problems` finds nothing. Run `python3.14 tool/species_pack/manifest_test.py`. Expected: OK.

- [ ] **Step 3:** In the findings' "Naming levels" section, the table gains the no-location precision and the shown figure per level for all three sets, the published-pair bullet gives the lines as the app now shows them (85%, 80%, 75%), and the Eager bullet says its figure is now its no-location accuracy.

- [ ] **Step 4:** Rebuild the relevelled manifest from the published one (`gh release download species-pack -p manifest.json` into the scratchpad, then `relevel_manifest.py --in ... --out ...`) and diff. Expected: only `naming.precision` (0.897) and `naming.levels` differ, with precisions 0.808 and 0.755. Copy it into the workspace as `manifest-relevelled.json`.

- [ ] **Step 5: Commit**

```bash
git add tool/species_pack/manifest.py docs/design/findings/2026-11-17-marine-life-measured-accuracy.md
git commit -m "feat(species-id): measured level accuracies without a location for the published pack"
```
