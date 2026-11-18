# Marine life identification: measured accuracy

Findings of the measured accuracy piece
([design](../specs/2026-11-17-marine-life-identification-measured-accuracy-design.md),
[plan](../plans/2026-11-17-marine-life-identification-measured-accuracy.md)).
Refs #4668. First measured on 2026-11-17 against pack `2026.11.17.1617`
(7,646 candidates), then again against pack `2026.11.17.2349` (9,011
candidates), whose list also takes the species divers record often in
shallow surveys but rarely photograph (#4683,
[design](../specs/2026-11-17-marine-life-survey-candidates-design.md)).
Both use BioCLIP 2 (`bioclip-2-vitl14-2957b32`), 16-bit Core ML on an
Apple M5 Pro, through the app's own Swift pipeline. The numbers below are
for the 9,011 pack unless they say otherwise; "The candidate list with
surveyed species" compares the two.

Every number below is from the held-out half of the test set, with a 95%
interval where one is given. The bars were chosen on the other half.

## The answers

1. **The bars for today's packs** (Community Fish Detector, centre crop),
   now in `tool/species_pack/manifest.py` with `provisional: false`. They
   apply only to the pack measured: the same detector, classifier, fitting
   and naming files, so a rebuilt candidate list waits for a new run:

   | Bar | Value |
   | --- | --- |
   | `minOpenScore` | 0.39 |
   | `suggestScore` | 0.64 |
   | `suggestScoreNoLocation` | 0.79 |
   | `confidentScore` | never (1.01) |
   | `confidentScoreNoLocation` | never (1.01) |

   At these bars, **87.1% of suggested names are right** (83.1 to 90.2%,
   348 suggestions), against the 85% target, and a suggestion is made for
   37% of the animals the detector boxes.
2. **No confident names.** No bar could show 95% on the tune half for the
   Community Fish Detector, so, as decided, the app names nothing at that
   level. Proving 95% on the one-sided lower bound needs either more photos
   or a classifier that is right more often; with about 300 tune crops above
   a bar, it takes about 97% observed.
3. **Crop fitting: centre crop, for the Community Fish Detector.** Of the
   held-out animals, 104 were named right only with centre crop and 41 only
   with pad-to-square (paired test p = 0.0000002). For Megalodon the two do
   not differ (57 against 42, p = 0.16), so pad-to-square stays for it. The
   fitting is now a manifest setting the app follows, so each pack carries
   the one its bars were measured with.
4. **Detector: the fish detector alone or the pair, if the fish detector's
   terms are acceptable; otherwise Megalodon.** The rule chose the pair with
   the 7,646 list and the fish detector alone with the 9,011 list, but the
   measurement does not separate the two: the difference between them is
   within noise. Megalodon's place behind the fish detector does look real.
   Details under "Detectors".

## The candidate list with surveyed species

The 7,646 list held the catalogue species and every species with 50 or more
photographed human observations on GBIF, so species divers record often but
rarely photograph (Creole Wrasse) could never be suggested. The 9,011 list
adds 1,365 species with 50 or more present human observations at 0 to 40 m,
photographed or not, and drops none: the first 7,646 candidates, their name
embeddings and their places are byte for byte those of the earlier pack.
Among each region's 300 most surveyed shallow species, the share on the list
rose from 88% to 100% in the Caribbean, 77% to 100% in the Indo-Pacific and
63% to 92% in the Mediterranean (the design has the measurement).

Fish detector, centre crop, each pack at its own measured bars:

| | 7,646 candidates | 9,011 candidates |
| --- | --- | --- |
| `minOpenScore`, suggest, suggest with no location | 0.34, 0.72, 0.79 | 0.39, 0.64, 0.79 |
| Suggested names right | 89.6% (85.8 to 92.5, 318) | 87.1% (83.1 to 90.2, 348) |
| Coverage | 33.8% | 36.9% |
| Held-out natural photos named right | 285 | 303 |
| Top-1 with location / without | 54.2% / 45.9% | 54.2% / 45.5% |
| Held-out crops of species not on the list | 58 of 942 | 52 of 942 |
| Held-out junk named | 2 of 35 | 1 of 35 |

The fish detector did not get better: its top-1 accuracy with location is
54.2% on both lists. The 18 more animals named right come from its
re-measured suggest bar (0.72 to 0.64), which buys coverage (33.8% to
36.9%) with precision (89.6% to 87.1%), still above the 85% target. That is
a move along the same curve, not a gain.

What this test set measures is the fix's cost, not its benefit. It is drawn
from photographed iNaturalist observations, so the surveyed-only species
the fix adds are nearly absent from it: 12 photos of 9 such species, across
both halves. All four Swarthy Parrotfish photos are now suggested right; the
other eight got no suggestion, and none a wrong one. The cost is the
precision above: the 1,365 new names compete with the old ones. The benefit
is the coverage of what divers survey: 88% to 100% in the Caribbean, 77% to
100% in the Indo-Pacific and 63% to 92% in the Mediterranean.

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
| Fish detector, pad-to-square | 0.39 | 0.69 | 0.69 | never | 88.2% (83.9 to 91.5) | 28.9% | 0 of 35 |
| Fish detector, centre crop | 0.39 | 0.64 | 0.79 | never | 87.1% (83.1 to 90.2) | 36.9% | 1 of 35 |
| Megalodon, pad-to-square | 0.21 | 0.75 | 0.70 | never | 92.4% (88.6 to 95.0) | 31.1% | 0 of 30 |
| Megalodon, centre crop | 0.27 | 0.80 | 0.80 | 0.95 (no location: never) | 94.4% (91.1 to 96.5) | 32.2% | 0 of 30 |
| Both, pad-to-square | 0.39 | 0.72 | 0.68 | never | 91.1% (87.3 to 93.8) | 28.9% | 0 of 62 |
| Both, centre crop | 0.49 | 0.73 | 0.81 | never | 90.3% (86.6 to 93.0) | 31.6% | 1 of 62 |

"Coverage" is the share of boxed animals given a suggestion, with location.
No bar was switched off by the held-out gate (which also switches off a bar
that names nothing on the held-out half, having no evidence for it).

Among bars that meet a target, the search takes the one naming the most
animals right and, on a tie, the higher bar, where the design said "the
lowest bar that meets". A lower bar naming the same number right only adds
wrong names on the tune half; on new photos it can cut a correct name that
falls in the gap, by at most one 0.01 step.

The fish detector's chosen bars named 1 of 35 held-out junk crops (2.9%,
interval 0.5 to 14.5%; 2 of 35 with the 7,646 list), above the 2% the tune
half met. The junk set is small; a larger one would settle whether that is
real.

### Without bars

Top-1 and top-3 accuracy of the largest box, among photos with a box:

| Run | top-1 / top-3 with location | top-1 / top-3 without |
| --- | --- | --- |
| Fish detector, centre crop | 54.2% / 68.8% | 45.5% / 59.9% |
| Megalodon, pad-to-square | 54.5% / 69.8% | 46.9% / 61.9% |
| Both, pad-to-square | 51.9% / 67.5% | 42.3% / 58.9% |
| Both, centre crop | 56.7% / 71.6% | 48.1% / 63.1% |

Limiting candidates to the place adds about 8 to 10 points of top-1
accuracy.

### By what kind of crop

For the fish detector with centre crop:

- **Box size:** suggested names were right 80% of the time for boxes 64 to
  127 px on the shorter side, 85% for 128 to 255 px and 89% above; coverage
  rises from 20% to 49%. Boxes under 64 px are never named.
- **Out of the pack:** 52 of 942 held-out crops were of species not in the
  pack (58 with the 7,646 list); 7 were given a (necessarily wrong)
  suggestion.
- **Freshwater:** 12 suggestions, 92% right; marine 87%.
- **Regions:** suggested precision ranged from 81% (California) to 97%
  (Great Barrier Reef), each on 23 to 82 suggestions.

## Detectors

### Finding the animal

The share of held-out photos (natural and top-up) in which the detector
returned any box, and the share whose largest box was named right (top-1,
no bars), each at its chosen fitting:

| Group | Fish detector (centre crop) | Megalodon (pad-to-square) | Both (pad-to-square) |
| --- | --- | --- | --- |
| fish (820) | 95%, 53% | 80%, 42% | 98%, 50% |
| sharks and rays (67) | 91%, 63% | 78%, 48% | 96%, 57% |
| octopus (72) | 62%, 22% | 79%, 40% | 90%, 42% |
| crabs (26) | 50%, 19% | 65%, 38% | 77%, 38% |
| sea snails and nudibranchs (146) | 60%, 23% | 90%, 51% | 95%, 49% |
| sea stars (56) | 68%, 32% | 84%, 61% | 91%, 61% |
| coral (78) | 40%, 5% | 83%, 35% | 92%, 35% |

Which photos have a box does not depend on the candidate list; the shares
named right moved by at most 5 points from the 7,646 list (the pair was
measured at centre crop then, where it names a few points more).

The fish detector finds fish better; Megalodon finds everything else much
better. Megalodon's model card warns that reef photos are unlike its
training imagery; for fish, that shows.

### Named right at their own bars

Held-out natural photos whose animal was named right, each detector at its
chosen fitting:

| Detector | Named right | Against |
| --- | --- | --- |
| Fish detector (centre crop) | 303 of 1,076 | |
| Megalodon (pad-to-square) | 254 of 1,076 | fish detector: 87 only Megalodon, 136 only the fish detector, p = 0.0013 |
| Both (pad-to-square) | 275 of 1,076 | fish detector: 84 only the pair, 112 only the fish detector, p = 0.054; Megalodon: p = 0.055 |

With the 7,646 list these were 285, 268 and 317 (the pair at centre crop),
and the pair beat each detector alone (p = 0.0035 and 0.0002).

- **The fish detector's 285 to 303 is not an improvement.** Its top-1
  accuracy with location is 54.2% on both lists; the extra names come from
  its lower suggest bar, which trades precision for coverage (see "The
  candidate list with surveyed species").
- **The pair's 317 to 275 is mostly its fitting rule flipping.** Its
  centre crop test gives p = 0.064 (82 named right only with centre crop,
  59 only with pad-to-square), just past the 0.05 cut-off, so the rule took
  pad-to-square. At centre crop the pair names 298 against the fish
  detector's 303, and the fish detector against the pair at its chosen
  fitting is p = 0.054. On this evidence the measurement does not separate
  the fish detector alone from the pair.
- **Megalodon's drop looks real.** It fell from a tie with the fish
  detector (p = 0.28) to behind it (p = 0.0013), and its top-1 with
  location fell from 55.7% to 54.5%.

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

From the scoring runs over all 2,612 photos with the 7,646 list (centre
crop for the fish detector, pad-to-square for Megalodon); the candidate
list is not part of these runs, and the 9,011 run's medians were within
about 1 ms of these. Peak memory includes the 608 MB
classifier. Running both adds Megalodon's
detection time and about 110 MB of model to the fish detector's. Megalodon
is 56.8 million parameters and 195 GFLOPs per image; the fish detector is an
RF-DETR nano.

### Recommendation

By the rule fixed before the run (most animals named right at the 85%
target, junk within 2%, close results to the simpler and explicitly
licensed choice), which `score.py` applies and records in `results.json`,
the 7,646 list gave the pair and the 9,011 list gives the fish detector
alone. The two recommendations are within noise of each other (above), so
this is not a change of conclusion:

- **The fish detector alone or the pair**, if the fish detector's terms
  are acceptable. The fish detector alone names 303 at its bars, the pair
  275 to 298 depending on its fitting; neither separates from the other.
  The pair finds something in 92 to 98% of photos in every group, so its
  advantage is in the groups other than fish, at the cost of a second model
  in the download and about 15 ms more per photo. Neither escapes the fish
  detector's licence question.
- **Otherwise, Megalodon alone.** It is explicitly licensed, and names
  octopus, crabs, snails and sea stars about twice as often as the fish
  detector and coral about seven times as often; it finds fish less often
  (80% of fish photos against 95%), and with the 9,011 list names fewer
  animals right overall (254 against 303, p = 0.0013), where with the 7,646
  list the two tied (p = 0.28).

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
- The filter sums its 5 "underwater" prompts against its 15 "out of water"
  ones, which tilts an undecided photo towards being dropped. In practice it
  erred the other way: it dropped one fish photo in 1,673 and kept most
  out-of-water invertebrates, which the review by eye then removed. A new
  test set drawn with it needs the same review.
- Research grade is a community identification and is sometimes wrong.
- Recall is "the detector returned a box", backed by "its largest box was
  named right"; there are no hand-drawn boxes.
- The junk set is small (60 to 65 boxes per detector); its rates have wide
  intervals.
- Crabs have 26 held-out photos.
- Megalodon 2023 (YOLOv8x) was not measured: its checkpoint was saved with
  `dill` and needs a general type loader to open, which the safe loader
  refuses. Megalodon 2024 is its successor.
- The bars hold for this detector, classifier and candidate list. The list
  now takes species divers record often in shallow surveys but rarely
  photograph (Creole Wrasse), from GBIF records at 0 to 40 m; records
  without a depth do not count, so a species surveyed only by programmes
  that publish no depth still misses out. About a quarter of the 1,365 added
  species come mostly from catch surveys (trawl, seine, longline), so some
  candidates are fish divers rarely meet.
- The test set is drawn from photographed iNaturalist observations, so
  only 12 of its photos are of surveyed-only species. It measures the
  longer list's cost (precision 89.6% to 87.1%), not its benefit; the
  benefit, naming the species divers survey but rarely photograph, is
  measured by coverage of each region's survey records.
- The rule's detector output differs between the lists (the pair with
  7,646, the fish detector alone with 9,011), within noise: the pair's
  fitting test sits near its cut-off (p = 0.064), and the fish detector
  against the pair is p = 0.054. A larger test set would be needed to tell
  them apart.

## Reproducing

Fetch these photos with `fetch_testset.py photos-from-csv`, convert
Megalodon, and run `score.py`; see "Measuring accuracy" in
[the developer page](../../developer/species-identification.md). The tables
here come from `report.md` and `results.json` in the work folder, written by
`tool/species_pack/score.py`, except where noted.
