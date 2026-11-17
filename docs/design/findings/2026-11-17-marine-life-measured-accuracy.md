# Marine life identification: measured accuracy

Findings of the measured accuracy piece
([design](../specs/2026-11-17-marine-life-identification-measured-accuracy-design.md),
[plan](../plans/2026-11-17-marine-life-identification-measured-accuracy.md)).
Refs #4668. Measured on 2026-11-17 against pack `2026.11.17.1617`: 7,646
candidates, BioCLIP 2 (`bioclip-2-vitl14-2957b32`), 16-bit Core ML on an
Apple M5 Pro, through the app's own Swift pipeline.

Every number below is from the held-out half of the test set, with a 95%
interval where one is given. The bars were chosen on the other half.

## The answers

1. **The bars for today's packs** (Community Fish Detector, centre crop),
   now in `tool/species_pack/manifest.py` with `provisional: false`. They
   apply only to the pack measured: the same detector, classifier, fitting
   and naming files, so a rebuilt candidate list waits for a new run:

   | Bar | Value |
   | --- | --- |
   | `minOpenScore` | 0.34 |
   | `suggestScore` | 0.72 |
   | `suggestScoreNoLocation` | 0.79 |
   | `confidentScore` | never (1.01) |
   | `confidentScoreNoLocation` | never (1.01) |

   At these bars, **89.6% of suggested names are right** (85.8 to 92.5%,
   318 suggestions), against the 85% target, and a suggestion is made for
   34% of the animals the detector boxes.
2. **No confident names.** No bar could show 95% on the tune half for the
   Community Fish Detector, so, as decided, the app names nothing at that
   level. Proving 95% on the one-sided lower bound needs either more photos
   or a classifier that is right more often; with about 300 tune crops above
   a bar, it takes about 97% observed.
3. **Crop fitting: centre crop, for the Community Fish Detector.** Of the
   held-out animals, 97 were named right only with centre crop and 53 only
   with pad-to-square (paired test p = 0.0004). For Megalodon the two do not
   differ (56 against 47, p = 0.43), so pad-to-square stays for it. The
   fitting is now a manifest setting the app follows, so each pack carries
   the one its bars were measured with.
4. **Detector: the pair, if the fish detector's terms are acceptable;
   otherwise Megalodon.** Details under "Detectors".

## The test set

`tool/species_pack/testdata/accuracy_set.csv` lists every photo with its
licence and attribution. The photos are not committed;
`fetch_testset.py photos-from-csv` downloads exactly these again.

- **Pool:** 108,280 research-grade, wild, open-location iNaturalist
  observations created from 2024-07-01 (after BioCLIP 2's training data was
  downloaded), with a CC0, CC BY or CC BY-SA first photo, in seven dive
  regions.
- **Natural sample:** 450 per region (415 in the Red Sea, its whole
  qualifying pool), one per observer per day: 3,115. Top-ups brought each
  group other than fish towards 150: 403 more.
- **Labels:** each name matched to a GBIF accepted species key. 32 of 1,467
  names had none; their 67 observations were dropped, leaving 3,451.
- **Underwater only:** a BioCLIP 2 zero-shot filter dropped 450 of those
  (472 of the 3,518 sampled). Its
  contact sheets showed it kept about 60% out-of-water photos of crabs,
  snails, sea stars and octopus (shells in hands, crabs on beaches, sea
  stars at low tide), so every kept photo in those four groups (1,074) was
  then reviewed by eye and 467 more dropped. Fish were checked on a sample
  only: of about 55 fish in a random 100 kept photos, none was out of
  water; one fish photo in the whole set was dropped by the filter.
- **What remained:** 2,534 underwater photos of 1,058 species:

  | Group | Natural | Top-up |
  | --- | --- | --- |
  | fish | 1,651 | 0 |
  | sharks and rays | 62 | 88 |
  | octopus | 17 | 121 |
  | crabs | 48 | 0 |
  | sea snails and nudibranchs | 286 | 0 |
  | sea stars | 53 | 58 |
  | coral | 38 | 112 |

  Crabs fell short of 150: top-ups were drawn before filtering, and most crab
  observations are on land or the shore. Their numbers have wide intervals.
- **Habitat:** 2,429 marine or brackish species, 97 freshwater only, 8
  unknown. Freshwater fish stayed in, as decided.
- **Licences:** 1,991 CC BY, 448 CC0, 95 CC BY-SA.
- **A test photo does not vouch for its own location:** for each
  observation, GBIF was asked whether its species had records before
  2024-07-01 in its 5 degree cell or the cells around it. 3,447 of 3,451 did,
  so this guard changed little.
- **Junk:** both detectors ran on 150 openly licensed Commons photos of
  divers, and each box was labelled by eye; 65 of the Community Fish
  Detector's 191 boxes and 60 of Megalodon's 103 were people, gear or bare
  scenery. Those 125 boxes, on 78 of the photos, are the CSV's junk rows,
  each with its box so a later run finds the same one. The contact sheets
  are in the work folder (`sheets/junk_*.png`) for checking.

## Results

### Bars and naming, per detector and fitting

| Run | `minOpenScore` | suggest | suggest, no location | confident | suggested right | coverage | junk named |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Fish detector, pad-to-square | 0.44 | 0.69 | 0.74 | never | 89.3% (85.0 to 92.4) | 28.7% | 0 of 35 |
| Fish detector, centre crop | 0.34 | 0.72 | 0.79 | never | 89.6% (85.8 to 92.5) | 33.8% | 2 of 35 |
| Megalodon, pad-to-square | 0.22 | 0.74 | 0.74 | never | 92.1% (88.4 to 94.7) | 32.9% | 0 of 30 |
| Megalodon, centre crop | 0.27 | 0.81 | 0.81 | 0.97 (no location: never) | 94.5% (91.3 to 96.6) | 33.1% | 0 of 30 |
| Both, pad-to-square | 0.44 | 0.72 | 0.74 | never | 90.3% (86.5 to 93.1) | 29.6% | 0 of 62 |
| Both, centre crop | 0.30 | 0.78 | 0.85 | never | 91.1% (87.6 to 93.7) | 33.3% | 1 of 62 |

"Coverage" is the share of boxed animals given a suggestion, with location.
No bar was switched off by the held-out gate (which also switches off a bar
that names nothing on the held-out half, having no evidence for it).

Among bars that meet a target, the search takes the one naming the most
animals right and, on a tie, the higher bar, where the design said "the
lowest bar that meets". A lower bar naming the same number right only adds
wrong names on the tune half; on new photos it can cut a correct name that
falls in the gap, by at most one 0.01 step.

The fish detector's chosen bars named 2 of 35 held-out junk crops (5.7%,
interval 1.6 to 18.6%), above the 2% the tune half met. The junk set is
small; a larger one would settle whether that is real.

### Without bars

Top-1 and top-3 accuracy of the largest box, among photos with a box:

| Run | top-1 / top-3 with location | top-1 / top-3 without |
| --- | --- | --- |
| Fish detector, centre crop | 54.2% / 68.8% | 45.9% / 61.0% |
| Megalodon, pad-to-square | 55.7% / 70.5% | 48.3% / 63.0% |
| Both, centre crop | 56.7% / 72.0% | 48.5% / 64.1% |

Limiting candidates to the place adds about 8 points of top-1 accuracy.

### By what kind of crop

For the fish detector with centre crop:

- **Box size:** suggested names were right 82% of the time for boxes 64 to
  127 px on the shorter side, 89% for 128 to 255 px and 91% above; coverage
  rises from 19% to 45%. Boxes under 64 px are never named.
- **Out of the pack:** 58 of 942 held-out crops were of species not in the
  pack; 6 were given a (necessarily wrong) suggestion.
- **Freshwater:** 13 suggestions, 92% right; marine 89%.
- **Regions:** suggested precision ranged from 81% (Mediterranean) to 97%
  (Great Barrier Reef), each on 26 to 71 suggestions.

## Detectors

### Finding the animal

The share of held-out photos (natural and top-up) in which the detector
returned any box, and the share whose largest box was named right (top-1,
no bars):

| Group | Fish detector | Megalodon | Both |
| --- | --- | --- | --- |
| fish (820) | 95%, 53% | 80%, 43% | 98%, 55% |
| sharks and rays (67) | 91%, 63% | 78%, 49% | 96%, 58% |
| octopus (72) | 62%, 22% | 79%, 40% | 90%, 47% |
| crabs (26) | 50%, 19% | 65%, 38% | 77%, 42% |
| sea snails and nudibranchs (146) | 60%, 23% | 90%, 51% | 95%, 51% |
| sea stars (56) | 68%, 32% | 84%, 61% | 91%, 66% |
| coral (78) | 40%, 6% | 83%, 40% | 92%, 47% |

The fish detector finds fish better; Megalodon finds everything else much
better. Megalodon's model card warns that reef photos are unlike its
training imagery; for fish, that shows.

### Named right at their own bars

Held-out natural photos whose animal was named right, each detector at its
chosen fitting:

| Detector | Named right | Against |
| --- | --- | --- |
| Fish detector (centre crop) | 285 of 1,076 | |
| Megalodon (pad-to-square) | 268 of 1,076 | fish detector: 102 only Megalodon, 119 only the fish detector, p = 0.28 |
| Both (centre crop) | 317 of 1,076 | fish detector: p = 0.0035; Megalodon: p = 0.0002 |

### False boxes

On the 150 diver photos, half of Megalodon's boxes (51 of 103) were on
people or their gear, against 56 of the fish detector's 191. A detector of
every organism counts a diver as one. At the bars, almost none of these
became a name (table above): the open score and the bars, not the detector,
keep divers from being named.

### Speed and memory on this Mac

| Detector | Detection, median (90th percentile) | Embedding one crop, median | Peak memory of a scoring run |
| --- | --- | --- | --- |
| Fish detector | 10.7 ms (12.2) | 8.9 ms | 1.30 GB |
| Megalodon | 15.2 ms (16.8) | 9.9 ms | 1.36 GB |

From the scoring runs over all 2,612 photos (centre crop for the fish
detector, pad-to-square for Megalodon). Peak memory includes the 608 MB
classifier. Running both adds Megalodon's
detection time and about 110 MB of model to the fish detector's. Megalodon
is 56.8 million parameters and 195 GFLOPs per image; the fish detector is an
RF-DETR nano.

### Recommendation

By the rule fixed before the run (most animals named right at the 85%
target, junk within 2%, close results to the simpler and explicitly
licensed choice), which `score.py` applies and records in `results.json`:

- **Run both**, if the fish detector's terms are acceptable. The pair names
  significantly more animals than either alone (317 against 285 and 268),
  finds something in 92 to 98% of photos in every group, and kept junk at 1
  of 62. It costs a second model in the download and about 15 ms more per
  photo. It does not escape the fish detector's licence question.
- **Otherwise, Megalodon alone.** It ties the fish detector on animals named
  right (p = 0.28), is explicitly licensed, and names octopus, crabs,
  snails and sea stars about twice as often and coral six times as often;
  it finds fish less often (80% of fish photos against 95%).

The choice is the maintainer's.

### Megalodon's conversion

The converted Megalodon matches the PyTorch model on a dive photo (score
drift 0.0003, best box overlap 0.998). The app pipeline's YOLO path
(letterbox, suppression, mapping back) was checked against ultralytics' own
letterbox, suppression and box scaling on 20 test photos, 10 portrait and
10 landscape, upright as the app decodes them: 23 of 23 boxes matched at an
intersection over union of 0.9 or more.

## Licence notes

Stated, not settled:

- The Community Fish Detector's authors leave the terms of the weights to
  the user (filippovarini/community-fish-detector#8, closed 2026-11-17).
- Megalodon's weights are CC BY 4.0 from MBARI; a pack would credit them.
- Megalodon was trained with Ultralytics' code (AGPL-3.0), and the pack
  tools load its checkpoint with the `ultralytics` package's layer classes.
  Ultralytics' position on models trained with its code differs from
  MBARI's licence on the weights. The program design ruled out Ultralytics
  YOLO models for store builds over this kind of copyleft; MBARI's licence
  reopens the question. The Community Fish Detector's own README says it
  moved off YOLO because "the AGPL license used by YOLOv12x and related
  model families is prohibitive for some of the use cases" its authors
  support. The app would run only a Core ML file.

## Limits

- iNaturalist photos are mostly close-ups the photographer chose. Wide-angle
  dive footage has more small, distant animals, so real coverage will be
  lower; precision at the bars should hold better, since small boxes are
  never named.
- Photos are 1,024 px on the longer side, smaller than a diver's originals,
  so box sizes in pixels run small and the 64 px floor is tested only
  roughly.
- The underwater filter, the invertebrate review and the junk labels are
  judgements by eye. Fish were sample-checked only.
- Research grade is a community identification and is sometimes wrong.
- Recall is "the detector returned a box", backed by "its largest box was
  named right"; there are no hand-drawn boxes.
- The junk set is small (60 to 65 boxes per detector); its rates have wide
  intervals.
- Crabs have 26 held-out photos.
- Megalodon 2023 (YOLOv8x) was not measured: its checkpoint was saved with
  `dill` and needs a general type loader to open, which the safe loader
  refuses. Megalodon 2024 is its successor.
- The bars hold for this detector, classifier and candidate list size. The
  candidate list misses species that are recorded often but photographed
  rarely (Creole Wrasse); fixing it is a piece of its own, after which the
  scorer is run again.

## Reproducing

Fetch these photos with `fetch_testset.py photos-from-csv`, convert
Megalodon, and run `score.py`; see "Measuring accuracy" in
[the developer page](../../developer/species-identification.md). The tables
here come from `report.md` and `results.json` in the work folder, written by
`tool/species_pack/score.py`, except where noted.
