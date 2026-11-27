# Marine life identification: measured accuracy

Findings of the measured accuracy piece
([design](../specs/2026-11-17-marine-life-identification-measured-accuracy-design.md),
[plan](../plans/2026-11-17-marine-life-identification-measured-accuracy.md)).
Refs #4668. First measured on 2026-11-17 against pack `2026.11.17.1617`
(7,646 candidates), then again against pack `2026.11.18.0030` (9,151
candidates), whose list also takes the species divers record often in
shallow surveys but rarely photograph, and the photographed species the
earlier build's GBIF paging had skipped (#4683,
[design](../specs/2026-11-17-marine-life-survey-candidates-design.md)).
Pack `2026.11.18.0356` carries both detectors and the same naming files
as `2026.11.18.0030`; scored on it, every number below came out the same,
and "Two detectors in one pack" adds what is new (#4691,
[design](../specs/2026-11-17-marine-life-two-detectors-design.md)).
A rerun on it measured the naming levels, in "Naming levels" (#4721).
The ONNX engine that runs on Android, Windows and Linux was gated against
Core ML on pack `2026.11.20.0513`, in "The ONNX engine against Core ML"
(#4801).
All use BioCLIP 2 (`bioclip-2-vitl14-2957b32`), 16-bit Core ML on an
Apple M5 Pro, through the app's own Swift pipeline. The numbers below are
for the 9,151 pack unless they say otherwise; "The candidate list with
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
   37% of the animals the detector boxes. The observed rate meets the
   target; the interval now dips below it (with the 7,646 list it was 85.8
   to 92.5%). The held-out gate switches a bar off only when the whole
   interval is below the target, so these bars stand. Megalodon alone and
   the pair have measured bars of their own, under "Two detectors in one
   pack".
2. **No confident names.** No bar could show 95% on the tune half for the
   Community Fish Detector, so, as decided, the app names nothing at that
   level. Proving 95% on the one-sided lower bound needs either more photos
   or a classifier that is right more often; with about 300 tune crops above
   a bar, it takes about 97% observed.
3. **Crop fitting: centre crop, for the Community Fish Detector.** Of the
   held-out animals, 104 were named right only with centre crop and 41 only
   with pad-to-square (paired test p = 0.0000002). For Megalodon the two do
   not differ (57 against 41, p = 0.13), so pad-to-square stays for it. The
   fitting is now a manifest setting the app follows, so each pack carries
   the one its bars were measured with.
4. **Detector: both detectors, by the rule as it stands since #4691.**
   The rule now also needs a detector set to find something in at least
   70% of held-out photos in every animal group, and only the pair does:
   the fish detector falls short in coral, crabs, octopus, snails and sea
   stars, Megalodon in crabs. Counted only by animals named right, the pair
   and the fish detector tie (304 and 303, p = 1.0), because three quarters
   of the natural sample is fish; Megalodon's place behind the fish
   detector does look real. If the fish detector's terms are unacceptable,
   Megalodon alone is the explicitly licensed choice. The choice stays the
   maintainer's. Details under "Detectors" and "Two detectors in one
   pack".

## The candidate list with surveyed species

The 7,646 list held the catalogue species and the species with 50 or more
photographed human observations on GBIF, so species divers record often but
rarely photograph (Creole Wrasse) could never be suggested. It also missed
157 photographed species: the builder paged GBIF's species facet 1,000 at a
time, and GBIF's paging repeats species at page boundaries and skips others.
The 9,151 list asks for each facet in one request, and adds:

- 156 photographed species the paging had skipped (Brook Lamprey with 1,315
  photographed records, Belica 1,268; one more was a catalogue species
  already), and
- 1,349 species with 50 or more present human observations at 0 to 40 m,
  photographed or not: 774 fish, 343 invertebrates, 184 corals, 28 rays and
  20 sharks, Creole Wrasse and Pacific Cornetfish among them.

It drops none of the 7,646. Among each region's 300 most surveyed shallow
species, the share on the list rose from 88% to 100% in the Caribbean, 77%
to 100% in the Indo-Pacific and 63% to 92% in the Mediterranean (Red Sea, top
100: 91% to 94%; California, top 100: 91% to 100%).

Fish detector, centre crop, each pack at its own measured bars:

| | 7,646 candidates | 9,151 candidates |
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
36.9%) with precision (89.6% to 87.1%), still above the 85% target as
observed. That is a move along the same curve, not a gain.

What this test set measures is the fix's cost, not its benefit. It is drawn
from photographed iNaturalist observations, so the species the fix adds are
nearly absent from it: 13 photos of 10 such species, across both halves.
All four Swarthy Parrotfish photos are now suggested right; the other nine
got no suggestion, and none a wrong one. The cost is the precision above:
the 1,505 new names compete with the old ones. The benefit is the coverage
of what divers survey: 88% to 100% in the Caribbean, 77% to 100% in the
Indo-Pacific and 63% to 92% in the Mediterranean.

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
| Fish detector, pad-to-square | 0.39 | 0.69 | 0.68 | never | 88.6% (84.2 to 91.8) | 28.8% | 0 of 35 |
| Fish detector, centre crop | 0.39 | 0.64 | 0.79 | never | 87.1% (83.1 to 90.2) | 36.9% | 1 of 35 |
| Megalodon, pad-to-square | 0.21 | 0.75 | 0.70 | never | 92.3% (88.5 to 94.9) | 30.9% | 0 of 30 |
| Megalodon, centre crop | 0.27 | 0.80 | 0.80 | 0.95 (no location: never) | 94.7% (91.4 to 96.8) | 32.0% | 0 of 30 |
| Both, pad-to-square | 0.39 | 0.72 | 0.68 | never | 91.0% (87.2 to 93.7) | 28.7% | 0 of 62 |
| Both, centre crop | 0.44 | 0.74 | 0.81 | never | 89.7% (86.0 to 92.5) | 32.4% | 1 of 62 |

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
| Megalodon, pad-to-square | 54.4% / 69.8% | 46.7% / 61.9% |
| Both, centre crop | 56.7% / 71.5% | 48.1% / 63.1% |

Limiting candidates to the place adds about 8 to 9 points of top-1
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

| Group | Fish detector (centre crop) | Megalodon (pad-to-square) | Both (centre crop) |
| --- | --- | --- | --- |
| fish (820) | 95%, 53% | 80%, 42% | 98%, 55% |
| sharks and rays (67) | 91%, 63% | 78%, 48% | 96%, 58% |
| octopus (72) | 62%, 22% | 79%, 40% | 90%, 47% |
| crabs (26) | 50%, 19% | 65%, 38% | 77%, 42% |
| sea snails and nudibranchs (146) | 60%, 23% | 90%, 50% | 95%, 51% |
| sea stars (56) | 68%, 32% | 84%, 61% | 91%, 66% |
| coral (78) | 40%, 5% | 83%, 35% | 92%, 44% |

Which photos have a box does not depend on the candidate list; the shares
named right moved by at most 5 points from the 7,646 list, each detector at
the same fitting.

The fish detector finds fish better; Megalodon finds everything else much
better. Megalodon's model card warns that reef photos are unlike its
training imagery; for fish, that shows.

### Named right at their own bars

Held-out natural photos whose animal was named right, each detector at its
chosen fitting:

| Detector | Named right | Against |
| --- | --- | --- |
| Fish detector (centre crop) | 303 of 1,076 | |
| Megalodon (pad-to-square) | 252 of 1,076 | fish detector: 85 only Megalodon, 136 only the fish detector, p = 0.0007 |
| Both (centre crop) | 304 of 1,076 | fish detector: 66 only the pair, 65 only the fish detector, p = 1.0; Megalodon: 107 against 55, p = 0.00005 |

With the 7,646 list these were 285, 268 and 317, and the pair beat each
detector alone (p = 0.0035 and 0.0002).

- **The fish detector's 285 to 303 is not an improvement.** Its top-1
  accuracy with location is 54.2% on both lists; the extra names come from
  its lower suggest bar, which trades precision for coverage (see "The
  candidate list with surveyed species").
- **The fish detector and the pair are not separated.** They name 303 and
  304, with 65 and 66 photos only one of them names right (p = 1.0). The
  pair's own fitting choice is close too: centre crop against
  pad-to-square gives p = 0.008 here, but p = 0.064 on an intermediate
  build of this list (9,011 candidates, before the paging fix), where the
  rule took pad-to-square and the pair named 275. On this evidence the
  measurement does not separate the fish detector alone from the pair.
- **Megalodon's drop looks real.** It fell from a tie with the fish
  detector (p = 0.28) to behind it (p = 0.0007), and its top-1 with
  location fell from 55.7% to 54.4%.

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
list is not part of these runs, and the 9,151 run's medians were within
about 1 ms of these. Peak memory includes the 608 MB
classifier. Running both adds Megalodon's
detection time and about 110 MB of model to the fish detector's. Megalodon
is 56.8 million parameters and 195 GFLOPs per image; the fish detector is an
RF-DETR nano.

### Recommendation

By the rule fixed before the run (most animals named right at the 85%
target, junk within 2%, close results to the simpler and explicitly
licensed choice), which `score.py` applies and records in `results.json`,
the 7,646 list gave the pair and the 9,151 list gives the fish detector
alone, the simpler of two that tie. The two recommendations are within
noise of each other (above), so this is not a change of conclusion:

- **The fish detector alone or the pair**, if the fish detector's terms
  are acceptable. They name 303 and 304 animals right at their bars. The
  pair finds something in 77 to 98% of photos per group, against 40 to 95%
  for the fish detector, and its largest box is named right more often in
  every group but sharks and rays, by far in octopus, crabs, snails, sea
  stars and coral. That costs a second model in the download and about
  15 ms more per photo. Neither escapes the fish detector's licence question.
- **Otherwise, Megalodon alone.** It is explicitly licensed, and names
  octopus, crabs, snails and sea stars about twice as often as the fish
  detector and coral about seven times as often; it finds fish less often
  (80% of fish photos against 95%), and with the 9,151 list names fewer
  animals right overall (252 against 303, p = 0.0007), where with the 7,646
  list the two tied (p = 0.28).

The choice is the maintainer's. Since #4691 the rule also asks for a box
in at least 70% of held-out photos in every group, which only the pair
gives, so the rule now recommends the pair (see "Two detectors in one
pack").

### Megalodon's conversion

The converted Megalodon matches the PyTorch model on a dive photo (score
drift 0.0003, best box overlap 0.998). The app pipeline's YOLO path
(letterbox, suppression, mapping back) was checked against ultralytics' own
letterbox, suppression and box scaling on 20 test photos, 10 portrait and
10 landscape, upright as the app decodes them: 23 of 23 boxes matched at an
intersection over union of 0.9 or more.

## Two detectors in one pack

Measured on 2026-11-17 for #4691
([design](../specs/2026-11-17-marine-life-two-detectors-design.md)). A pack
now lists one or two detectors (manifest format 2), and the app runs every
one and merges two detectors' boxes before naming them. Pack
`2026.11.18.0356` was built with `build_pack.py --detectors both`: the fish
detector, then Megalodon, with the same `candidates.json`,
`text_embeddings.f16` and `regions.bin` as `2026.11.18.0030`, byte for
byte. Its download is 633 MB against 528 MB for the fish detector's pack;
Megalodon's model is 105 MB.

### The app merges as the scorer measured

The first measurement merged two single runs in Python
(`tool/species_pack/boxes.py`). Now the pair runs through the app's own
pipeline, which reports each detector's boxes and the merged boxes, and the
scorer merges those same per-detector boxes with `boxes.py`. They were equal
on all 2,612 photos at both fittings. Each detector's boxes inside the pair
run also equalled its own single run, and the merged boxes a merge of the
single runs, on all 2,612, so the numbers in this document hold for the
app's pair. A pack with one detector returns that detector's boxes
unchanged: the fish detector's numbers on this pack equal the earlier run's.

### Bars for each detector set

The scorer now writes bars for every set at its chosen fitting, and all
three are in `tool/species_pack/manifest.py`, so whichever pack is
published carries measured bars:

| Set (fitting) | `minOpenScore` | suggest | suggest, no location | confident | suggested right | coverage |
| --- | --- | --- | --- | --- | --- | --- |
| Fish detector (centre crop) | 0.39 | 0.64 | 0.79 | never | 87.1% (83.1 to 90.2) | 36.9% |
| Megalodon (pad-to-square) | 0.21 | 0.75 | 0.70 | never | 92.3% (88.5 to 94.9) | 30.9% |
| Both (centre crop) | 0.44 | 0.74 | 0.81 | never | 89.7% (86.0 to 92.5) | 32.4% |

### The group floor

Share of held-out photos with any box, against the 70% floor:

| Group | Fish detector | Megalodon | Both |
| --- | --- | --- | --- |
| fish (820) | 95% | 80% | 98% |
| sharks and rays (67) | 91% | 78% | 96% |
| octopus (72) | 62% (below) | 79% | 90% |
| crabs (26) | 50% (below) | 65% (below) | 77% |
| sea snails and nudibranchs (146) | 60% (below) | 90% | 95% |
| sea stars (56) | 68% (below) | 84% | 91% |
| coral (78) | 40% (below) | 83% | 92% |

Only the pair clears the floor in every group, so the rule recommends it.
Crabs decide Megalodon's place and have 26 photos; at 65% against 70%, more
crab photos could move it either way.

### Speed

On this Mac, GPU path:

- **Photos:** detection took 11.2 ms (median) with the fish detector,
  15.7 ms with Megalodon and 26.4 ms with both; embedding a crop is about
  10 ms either way.
- **Video pass 1** over a 26.8 s 4K60 HEVC clip (107 frames sampled at four
  a second, decoding included), three runs each: 3.1 s median with the fish
  detector, 4.8 s with both, 1.5 times as long. The pair finds 286 boxes
  against 268, so pass 2 embeds a few more moments (71 against 58 here;
  about 3.5 s against 2.5 s).

### Memory

Measured with the command-line harness of the
[phone memory findings](2026-11-17-marine-life-phone-memory.md): the app's own `VisionPipeline.swift` and `VideoScanner.swift`
with no Flutter, database or network, physical footprint sampled every
20 ms, on a 50 MP reef photo and the clip above, models already compiled,
two runs each (the kernel's lifetime peak agreed with the samples):

| Stage | Fish detector | Both |
| --- | --- | --- |
| Models loaded, idle | 17 MB | 19 MB |
| Photo, peak | 253 MB | 374 to 375 MB |
| Video pass 1, peak | 273 to 277 MB | 406 to 415 MB |
| Video pass 2, peak | 232 to 238 MB | 376 to 383 MB |
| After unloading | 74 to 76 MB | 94 to 95 MB |

The weights stay file-mapped, as the memory findings found for the fish
detector and classifier; the pair's extra 120 to 140 MB at its peaks is
Megalodon's working memory on top of the media decode. These are Mac
figures on the GPU path; the iPhone test is still open.

## Naming levels

Pack `2026.11.18.0356` was scored again on 2026-11-19 for the naming
levels (#4721,
[design](../specs/2026-11-18-marine-life-naming-levels-design.md)); the
rerun reproduced every bar and Surer number above exactly. A level moves
only the two suggest bars, under each set's own measured bars: Balanced
aims for 75% right and Eager for 65%, by the same Wilson test as the 85%
bars, with the same rule (the bars that name the most animals right, ties
to the higher bar), the same 2% junk cap on the tune half and the same
held-out gate. Every set keeps both levels, and all are in
`tool/species_pack/manifest.py`.

The figure shown for each level, and for Surer, is the lower of its
held-out precision with a location and without one
([design](../specs/2026-11-19-marine-life-level-accuracy-without-location-design.md)),
so its settings line never overstates for photos named without a
location; the app rounds it down to a multiple of 5. Coverage is with a
location:

| Set (fitting) | Level | suggest | suggest, no location | right, with a location | right, without | coverage | shown | junk named |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Both (centre crop), published | Surer | 0.74 | 0.81 | 89.7% (86.0 to 92.5) | 90.3% (84.6 to 94.0) | 32.4% (29.7 to 35.3) | 89.7% | 1.6% (0.3 to 8.6) |
| | Balanced | 0.25 | 0.63 | 82.5% (78.8 to 85.6) | 80.8% (76.0 to 84.8) | 45.4% (42.4 to 48.4) | 80.8% | 3.2% (0.9 to 11.0) |
| | Eager | 0.25 | 0.44 | 82.5% (78.8 to 85.6) | 75.5% (71.4 to 79.1) | 45.4% (42.4 to 48.4) | 75.5% | 3.2% (0.9 to 11.0) |
| Fish detector (centre crop) | Surer | 0.64 | 0.79 | 87.1% (83.1 to 90.2) | 89.2% (82.7 to 93.5) | 36.9% (33.9 to 40.1) | 87.1% | 2.9% (0.5 to 14.5) |
| | Balanced | 0.25 | 0.56 | 82.1% (78.2 to 85.4) | 81.0% (76.1 to 85.0) | 45.6% (42.5 to 48.8) | 81.0% | 5.7% (1.6 to 18.6) |
| | Eager | 0.25 | 0.39 | 82.1% (78.2 to 85.4) | 73.7% (69.4 to 77.6) | 45.6% (42.5 to 48.8) | 73.7% | 5.7% (1.6 to 18.6) |
| Megalodon (pad-to-square) | Surer | 0.75 | 0.70 | 92.3% (88.5 to 94.9) | 89.0% (83.6 to 92.8) | 30.9% (27.9 to 34.0) | 89.0% | 0.0% (0.0 to 11.4) |
| | Balanced | 0.57 | 0.59 | 84.9% (81.1 to 88.1) | 85.9% (81.1 to 89.6) | 45.8% (42.6 to 49.1) | 84.9% | 0.0% (0.0 to 11.4) |
| | Eager | 0.36 | 0.44 | 75.7% (72.0 to 79.1) | 79.9% (75.6 to 83.7) | 62.4% (59.2 to 65.6) | 75.7% | 0.0% (0.0 to 11.4) |

- **The published pair.** Balanced names 45.4% of the animals the
  detectors box against Surer's 32.4%, about 40% more, and is right 82.5%
  of the time against 89.7%. The app shows "About 85% right" for Surer,
  "About 80% right" for Balanced and "About 75% right" for Eager.
- **Balanced and Eager share a bar with a location.** Below 0.25 the pair
  names no more animals right, and a tie goes to the higher bar, so the
  65% target adds nothing there. Eager differs only without a location
  (0.44 against 0.63): there it names 46.4% of the animals against
  Balanced's 28.9%, and is right 75.5% of the time against 80.8%. Its
  shown figure is that no-location accuracy, so its line describes the
  photos where it differs, and with a location it understates by about a
  step. Eager is kept as measured, the maintainer's call. The fish
  detector alone shows the same pattern; Megalodon alone is the one set
  whose Eager names more everywhere.
- **Junk.** The cap holds on the tune half (55 junk boxes for the pair),
  as for the pack's own bars. On the held-out half the pair's levels named
  2 of 62 junk boxes against Surer's 1, and the fish detector's 2 of 35
  against 1; with sets this small the intervals overlap widely (see
  Limits).

`relevel_manifest.py` adds the pair's levels and Surer's precision to the
published manifest under the same pack version, so the app takes the new
manifest in place, with nothing downloaded.

## The ONNX engine against Core ML

Task D1 of piece 3 (#4801,
[design](../specs/2026-11-19-marine-life-identification-3-other-platforms-design.md),
[plan](../plans/2026-11-20-marine-life-identification-3-other-platforms.md)),
run on 2026-11-21 and 2026-11-22. The candidate was pack
`2026.11.20.0513` with its ONNX files added and every Core ML and shared
file byte for byte the live release's. Each engine scored the test set
through the app's own pipeline: Core ML through the Swift one, ONNX
through the Dart one (`tool/species_vision_onnx`, ONNX Runtime on the
M5 Pro's processor). `engine_gate.py` compares the two at the pack's
bars, and `gate.py --trained-onnx` runs the same checks inside the naming
layer's gate. Nothing was published.

### The first run failed

| Check (held out, both detectors, centre crop) | Result |
| --- | --- |
| Named right, Core ML against ONNX (1,076 photos) | 602 against 586, not significantly fewer (McNemar) |
| No group worse | passed |
| Junk named by ONNX (limit 2%) | 1.96% |
| Junk crops found by only one engine (3.1 of 62 allowed) | 9: failed |
| Linux x64 against the Mac (100 photos, every crop's cosine 0.999 or more) | 1 of 203 crops at 0.99636: failed |

The x64 failure was one crop whose box differed by about 3e-6 of the
image's width between the machines, enough for its padded edge to round
to the next pixel. The rest pointed at the pixels the Dart pipeline fed
the models, not at the models: given the Swift pipeline's own pixels, the
ONNX classifier matched Core ML at an embedding cosine of 0.99999, so the
16-bit weights were not the cause. On 300 sample crops, the Dart
pipeline's embeddings were at a median cosine of 0.951 to Core ML's for
crops under 100 px (5th percentile 0.867), 0.992 for medium ones and
0.995 for large ones.

### Two causes, both fixed in the engine (#4853)

- **The filter.** CoreGraphics' high quality interpolation, measured with
  impulses, edges, noise and full response matrices drawn through
  `CGContext`, is not the area average and bilinear filter the Dart
  pipeline used. Enlarging, it blends the two nearest pixels on a curve
  stepped in eighths (0, 1, 2, 4, 8, 12, 14, 15 and 16 sixteenths; half
  an eighth rounds up). Shrinking, it maps the first and last source
  pixels to the first and last output pixels and applies a Keys cubic
  (a = -0.5) widened by the scale. `pipeline/resampling.dart` draws the
  same way, to within a level or two; a shrink of under about 1.5 times
  also snaps the phase in CoreGraphics, which is not modelled (up to 3
  levels on noise, a fraction of one on photos). With this filter alone,
  the small crops' median cosine rose to 0.996 (5th percentile 0.981).
- **Colour.** Flutter's decoder ignores a photo's embedded colour profile
  (its output equals a plain libjpeg decode), while ImageIO converts to
  sRGB. 674 of the 3,668 test photos carry Display P3, whose red reached
  the ONNX models about 9 levels high. `pipeline/colour_profile.dart`
  reads matrix and curve profiles from JPEG and PNG files and converts to
  sRGB as littleCMS does.

What the engine cannot remove is JPEG decoding: on the photos checked,
ImageIO and the decoder Flutter uses on every platform differ by 0.2 to
1.3 levels on average, and by up to 10 at the 99th percentile. Detector
boxes found by only one engine, on a sample of photos:

| Detector | Before | Fixed | Identical pixels (the floor) |
| --- | --- | --- | --- |
| RF-DETR (295 boxes) | 42 | 28 | 10 (16-bit arithmetic alone) |
| Megalodon (116 boxes) | 13 | 2 | |

### The junk pairing rule

The fixed engine still lost 4 of the 62 held-out junk crops: RF-DETR
boxes Core ML scored 0.306 to 0.349, just over the 0.30 cut-off, and
ONNX 0.27 to 0.295. Given identical pixels the two engines scored them
within 0.006 of each other, so three were lost to JPEG decoding and one
to the filter's small remaining difference. The junk rows were labelled
on Core ML's boxes, so only another engine can lose one, and a crop the
ONNX engine drew no box over cannot hide junk it named. The maintainer
decided ("Count moved boxes too") that the 5% limit counts only crops
ONNX alone found and crops it lost with a box still over the same object
(overlap 0.5 or more); species-pack#5 made the change. None of the 4
counts. Under the same rule, the unfixed engine's first run would have
counted 3 (boxes moved to overlaps of 0.67, 0.87 and 0.88) against 3.1
allowed, so this gate on its own would not have required the fix.

### Speed

Drawing as CoreGraphics does costs more: shrinking a 12 MP photo to a
640 px detector input reads about 25 source pixels across and 19 down for
each output pixel. The engine draws both detector inputs from one shared
first pass, in whole-number arithmetic, and converts colour in fixed
point. Measured in one process on the M5 Pro:

| Per 12 MP photo | Before D1 | First fix | Merged |
| --- | --- | --- | --- |
| Both detector inputs | 105 ms | 419 ms | 161 ms |
| Display P3 to sRGB | none | 447 ms | 125 ms |

### The final run

On the engine as merged (`061ba24`; the code scored was the same):

| Check | Result |
| --- | --- |
| The pack's bars stand held out on ONNX | passed, none switched off |
| Named right, Core ML against ONNX (1,076 photos) | 602 against 602 (22 only on each side, p = 1.0) |
| No group worse | passed, every group p = 1.0 |
| Junk named by ONNX (limit 2%) | 2.0% (Core ML 1.8%) |
| Junk crops lost, counted against the 5% | 4 lost, none counted |
| `gate.py` with the ONNX checks | ship, every check passing (602 named right against the baseline's 304) |
| Linux x64 against the Mac (100 photos) | passed: 198 crops, lowest cosine 0.99999999678, same outcome on all |

On x64 the three converted models were byte for byte the Mac's, and the
photos matched by SHA-256.

**Not measured:** the test photos are at most 1,024 px, so the path for
photos over 4,096 px is untested. There Flutter shrinks the decode before
the colour conversion, as ImageIO's capped decode does (it stays in the
photo's own colour space; checked on a 6,000 px Display P3 photo), but
the two shrink differently, as they decode differently.

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
  that publish no depth still misses out. About a quarter of the 1,349
  surveyed-only species come mostly from catch surveys (trawl, seine,
  longline), so some candidates are fish divers rarely meet.
- The test set is drawn from photographed iNaturalist observations, so
  only 13 of its photos are of species the longer list adds. It measures
  the longer list's cost (precision 89.6% to 87.1%), not its benefit; the
  benefit, naming the species divers survey but rarely photograph, is
  measured by coverage of each region's survey records.
- The rule's detector output differs between the lists (the pair with
  7,646, the fish detector alone with 9,151), within noise: the two name
  304 and 303 (p = 1.0), and the pair's fitting test moved from p = 0.064
  to 0.008 between two builds of nearly the same list. A larger test set
  would be needed to tell them apart.

## Reproducing

Fetch these photos with `fetch_testset.py photos-from-csv`, convert
Megalodon, and run `score.py`; see "Measuring accuracy" in
[the developer page](../../developer/species-identification.md). The tables
here come from `report.md` and `results.json` in the work folder, written by
`tool/species_pack/score.py`, except where noted.

The naming levels were measured on the published pack's own files
(`gh release download species-pack`, checked against its manifest's sizes
and hashes), since they hold only for those bytes. With a pack that
carries Megalodon there is nothing to convert, and the scorer needs only
numpy and Pillow. Each set's `precision` and `levels` go from
`results.json`'s `measured` entries into `NAMING_MEASURED`, and
`relevel_manifest.py --in <published manifest.json> --out <new manifest.json>`
adds them to the published manifest, changing nothing else.

"The ONNX engine against Core ML" comes from `engine_gate.json` and the
gate and comparison outputs, regenerated in the species-pack repository
from the pack with its ONNX files added (`PACK`) and a work folder
(`WORK`):

1. `score.py --pack PACK --engine coreml --naming-from PACK --work WORK`,
   then the same with `--engine onnx` and `SUBMERSION_APP` set to an app
   checkout at the engine's commit; the ONNX results go to `WORK/onnx`.
2. `engine_gate.py --work WORK --pack PACK`, then
   `gate.py --baseline W0 --baseline-pack P0 --trained WORK --trained-pack PACK --check W2 --check-pack P2 --trained-onnx WORK/onnx --set testdata/accuracy_set.csv`,
   where P0 is the baseline pack (`2026.11.18.0356` with ONNX files
   added), P2 the rare-species check pack, and W0 and W2 their work
   folders, each scored with `--naming-from PACK` as `gate.py`'s own
   header describes.
3. For x64, a request file for the app's scoring runner on each machine,
   built with species-pack's `score.onnx_request`: the pack's manifest,
   both detectors' and the classifier's ONNX files, `centreCrop` and the
   100 held-out photos, with that machine's paths; as `out`, that
   machine's JSON lines file (`MAC.jsonl`, `X64.jsonl`); and as
   `ortLibrary`, the pinned ONNX Runtime library `score.py` fetches on
   the Mac, and nothing on Linux, where the app's build hook supplies it.
   Then, in an app checkout at the engine's commit on each machine,
   `SPECIES_VISION_REQUEST=request.json flutter test tool/species_vision_onnx/species_vision_onnx_test.dart`
   with that machine's request, and
   `engine_compare.py --pack PACK MAC.jsonl X64.jsonl`.
