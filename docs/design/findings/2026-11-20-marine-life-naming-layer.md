# Marine life identification: the trained naming layer

Findings of the naming layer
([design](../specs/2026-11-18-marine-life-naming-layer-design.md),
[plan](../plans/2026-11-18-marine-life-naming-layer.md),
[runbook](../plans/2026-11-18-marine-life-naming-layer-runbook.md)),
issue #4724. Trained and gated on 2026-11-20 on an Apple M5 Pro, with the
tools in the
[species pack repository](https://github.com/submersion-app/species-pack):
the training photos were embedded and the packs scored through the app's
own Swift pipeline, and the rows were trained with PyTorch on the Mac's
GPU.

The trained pack is `2026.11.20.0513`. It is pack `2026.11.18.0356` (both
detectors, 9,151 candidates) with one file changed: `text_embeddings.f16`
holds one trained row per candidate instead of BioCLIP 2's name rows. The
candidates, regions, models and app are the same. Every comparison below
is against pack `2026.11.18.0356`, scored again on the same day with the
same scorer code (its pair named 304 right, as
[measured accuracy](2026-11-17-marine-life-measured-accuracy.md) found).

Where each number comes from:

- **Accuracy and the group results** (named right, coverage, precision,
  junk named at the bars): the held-out half of the test set, with a 95%
  interval where one is given.
- **The bars, and the junk gate's 1.82%:** the other half, the tune half.
- **The rare-species check:** every test photo of the 100 held-back
  species, from both halves.
- **The training data and validation figures:** the training photos, which
  the leak guard keeps apart from the test set.

## Summary

**The trained pack passed the gate: it may ship.** With both detectors
and centre crop, it names **602 of the 1,076 held-out natural photos
right, against 304** for the current pack (305 photos only the trained
pack named right, 7 only the current one; p 1.3e-80). Named right here,
as in the gate, means suggested at the pack's own bars (Surer, with a
location) and right; the table's first row is the largest box's top-1
with no bar. Its confident bar
is **0.93**, a real bar for the first time (the current pack's is never).
No animal group is named right less often, junk is named on 1.82% of
tune-half junk crops, and the rare-species check names 1.40% of unseen
species' photos confidently wrong.

| Held-out natural photos, both detectors, centre crop | Current pack | Trained pack |
| --- | --- | --- |
| Largest box's top-1 right, no bar | 55.0% | 65.2% (62.3% to 68.0%) |
| Top-1 / top-3 with a location | 56.7% / 71.5% | 67.2% / 78.7% |
| Top-1 / top-3 without one | 48.1% / 63.1% | 58.9% / 72.3% |
| Suggested: coverage | 32.4% | 65.9% (63.0% to 68.7%) |
| Suggested: precision | 89.7% | 87.4% (84.7% to 89.6%) |
| Confident: coverage | none | 22.4% (20.0% to 25.0%) |
| Confident: precision | none | 96.6% (93.4% to 98.3%) |
| Junk named | 1.6% | 1.6% (0.3% to 8.6%, n 62) |

## Training data

From the fetch's `select` stage: 1,161,189 observations listed, 1,103,601
after the leak guard; **377,589 training photos of 8,755 species and
74,950 validation photos**.

- **Source:** iNaturalist research-grade, wild observations, photos from
  the `inaturalist-open-data` bucket at the `large` size.
- **Licences:** CC0, CC BY and CC BY-NC only. Of the 452,539 photos
  selected, 427,100 are CC BY-NC, 22,129 CC BY and 3,310 CC0.
- **Dates and the leak guard:** observations from any date, except every
  test set observation and every observation created on or after
  2024-07-01 by any of the test set's 840 observers.
- **Validation:** the post-cutoff observations of about 10% of the
  observers with observations after the cutoff, none of whose
  observations are trained on. Every validation photo is from after the
  cutoff.
- **Caps:** at most 50 observations per candidate and 5 per observer per
  species, one photo each. 6,345 species reached 50.
- **Embedding:** 227 batches through the pair of detectors, centre crop
  and BioCLIP 2, keeping the largest box's embedding when its shorter side
  reaches the minimum crop side. **419,607 photos kept** (92.7%): 350,512
  training photos of 8,747 species (median 46 a species) and 69,095
  validation photos. Two photos had left the bucket.

## Training

From `training.json` of the trained pack:

| Value | Trained rows | Name rows |
| --- | --- | --- |
| Validation loss | 1.9266 | 2.7868 |
| Validation top-1 | 61.1% | 43.5% |

Chosen on the validation photos: the pull towards the name rows
(`anchor` in `training.json`) from 0.0001, 0.001 and 0.01; the blend from
0.25, 0.5, 0.75 and 1.0; the sharpness from 0.75, 1.0, 1.5 and 2.0; and
the epochs by stopping once the validation loss stopped falling. The
choice: **pull 0.0001, 4 epochs, blend 0.75, sharpness 0.75, seed 0**.
Training took under four minutes on the Mac's GPU. The pull and the
sharpness both chose the lowest value searched.

The pack has 9,151 candidates, and 8,747 of them had training photos.
The other 404 keep BioCLIP 2's name rows, scaled by the same sharpness,
so they compete with trained rows; the rare-species check below measures
how such a species fares.

## The gate

| Item | Passes when | Result | |
| --- | --- | --- | --- |
| More named right | significantly more held-out natural photos named right (p < 0.05) | 602 against 304 of 1,076; 305 only trained, 7 only current; p 1.3e-80 | pass |
| Confident bar | a confident bar with a location, chosen on the tune half as proven 95% right, survives the held-out gate (a bar that does not is never, 1.01) | 0.93 | pass |
| No group worse | no group named right significantly less often | none worse | pass |
| Junk | at most 2% of tune-half junk crops named | 1.82% (1 of 55) | pass |
| Rare species | at most 2% confidently wrong | 1.40% | pass |

By animal group, over every held-out photo (natural and top-up), as the
gate counts them:

| Group | Photos | Only trained right | Only current right | p |
| --- | --- | --- | --- | --- |
| Fish | 820 | 237 | 7 | 6.8e-61 |
| Sea snails and nudibranchs | 146 | 41 | 0 | 9.1e-13 |
| Coral | 78 | 20 | 0 | 1.9e-6 |
| Octopus | 72 | 24 | 1 | 1.5e-6 |
| Sharks and rays | 67 | 16 | 0 | 3.1e-5 |
| Sea stars | 56 | 13 | 0 | 0.00024 |
| Crabs | 26 | 4 | 0 | 0.125 |

Every group gained; for crabs the gain is too small to be significant.

## Rare-species check

A second layer was trained the same way, at the same settings and seed,
with every photo of the test set's 100 held-back species removed
(346,359 training photos, 8,654 species). Named at the trained pack's
bars, it named **3 of the 215 held-back species' photos confidently
wrong** and 4 confidently right: a rate of **1.40%** (0.48% to 4.02%).
This estimates how the shipped layer treats a species it has no training
photos for, such as its 404 untrained candidates; on 215 photos, the
interval allows up to about twice the 2% limit.

## Bars

The pair's bars, centre crop, as each pack's manifest carries them:

| Bar | Current pack | Trained pack |
| --- | --- | --- |
| `minOpenScore` | 0.44 | 0.19 |
| `suggestScore` | 0.74 | 0.47 |
| `suggestScoreNoLocation` | 0.81 | 0.46 |
| `confidentScore` | never (1.01) | 0.93 |
| `confidentScoreNoLocation` | never (1.01) | 0.94 |
| Surer precision shown | 0.897 | 0.865 |
| Balanced: suggest, no location, precision | 0.25, 0.63, 0.808 | 0.33, 0.39, 0.834 |
| Eager: suggest, no location, precision | 0.25, 0.44, 0.755 | left out |

The trained rows separate species far better, so lower bars name twice
as many photos at about the same precision. The scorer left the Eager
level out of the trained pack; a level is left out when it adds nothing
over the one above, does not hold on the held-out half, or would show a
higher figure than the level above. Eager is the app's default level
until a diver picks one (#4789), and a pack without it names at its most
eager level, so with this pack every diver on the default names at
Balanced: 83.4% right, on 73.4% of photos with a location, against
today's Eager, 75.5% right on 45.4%. The bars are recorded for this pack only, in
`manifest.py` of the species pack repository.

## Known limits

- **Recent photos only:** each candidate's list was one request for its
  newest 200 observations, so older photos were never offered. 583
  species had fewer than 10 photos selected for training.
- **Untrained candidates:** 404 of the 9,151 candidates had no training
  photos and keep their name rows.
- **Thin samples on two gate items:** junk passed at 1 of 55 crops, and
  the rare-species interval reaches 4.0%, above the 2% limit.
- **The search's edges:** the pull and the sharpness chose the lowest
  value searched, so a wider search may do slightly better.
- **Megalodon alone:** with the trained rows, the scorer measured centre
  crop best for Megalodon alone, while packs fit its crops to a square
  (`CROP_FIT`). Only the pair is gated and recorded; a Megalodon-only
  trained pack would get provisional bars.
- **Video tracks:** playback pills and auto-apply use the confident bar
  on tracks named from averaged embeddings, which no bar measures.
- **Terms:** the trained file is credited CC BY-NC 4.0. Whether
  iNaturalist's training clause reaches photos taken through the open
  data bucket, and whether trained numbers are an adaptation under
  Creative Commons, are unsettled, as the design's "Open risks" says.
