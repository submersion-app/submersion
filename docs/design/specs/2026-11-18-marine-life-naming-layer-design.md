# Marine life naming layer: trained rows in the species pack

Date: 2026-11-18. Part of the marine life identification program (issue
#4668), its "Training later" step:
[program design](2026-11-17-marine-life-identification-program-design.md).
Status: draft for Eric's approval.

## Why

The app names an animal by comparing its crop's BioCLIP 2 embedding with
one row per candidate species in `text_embeddings.f16`, each row the
embedding of the species' names. That is zero-shot naming: the rows were
never shown a photo. On the held-out test set it names 303 of 1,076
natural photos right at the measured bars with the fish detector, and no
confident bar can be proven for any detector set, so auto-apply has
nothing it may apply
([measured accuracy](../findings/2026-11-17-marine-life-measured-accuracy.md)).

A small naming layer trained on photos of each species should name more
animals right, and name some of them confidently enough for auto-apply.
The program design puts it next after detector work.

## What it is

One trained row per candidate, written into the pack's
`text_embeddings.f16` in place of the name rows. Every other pack file
stays byte for byte the same. The app already multiplies the unit crop
embedding by each row and by `logitScale`, and never rescales the rows
(`species_namer.dart`, `naming.py`), so a trained row can have any
direction and any length. The direction says what the species looks
like; the length says how sharply it scores.

## Goals

- Name significantly more held-out photos right at the measured
  suggestion bar than today's pack does.
- Prove a confident bar, so auto-apply has names it may apply.
- Ship the trained file as a new pack version in format 2, with no change
  to how the app names a crop. The one app change is a fix to the
  confident rule (below), needed whatever this layer does.

## Non-goals

- Retraining BioCLIP 2 or the detectors (the program design's approach 2,
  and its detector training step, are separate).
- Training on anything a diver labels. Nothing a diver labels leaves the
  device without a separate design (program design).
- A per-species bias, an adapter network, or any other change to how
  the app names a crop. Those are approach B and C below, kept for later.
- Changing the candidate list, the region table, or the detectors.

## Anti-goals

The layer fails, even if it names more animals right overall, when:

- a group of animals (corals, sharks and rays, and so on) is named
  significantly worse than today;
- junk crops (rocks, divers, gear) are named more often than the existing
  limit allows;
- a rare animal the layer never trained on is confidently given a
  look-alike's name. Auto-apply writes a confident name without a diver
  checking it, so a confident wrong name costs more than a wrong
  suggestion;
- the trained file carries terms its licences or its source's terms do
  not allow.

## Decided by Eric

- **Training data (2026-11-18): CC BY-NC photos are included**, alongside
  CC0 and CC BY. The trained file is therefore non-commercial.
- **The gate (2026-11-18): the layer ships only if it both names
  significantly more right at the suggestion bar and proves a confident
  bar.**
- **Rare species (2026-11-18): measure them and gate on it**, by leaving
  about 100 test species out of a second training run (below).
- **Approach (2026-11-18): A, trained rows in today's file.**
- **The confident rule (2026-11-18): fix the app**, so a crop with no
  usable place uses the pack's no-location confident bar.
- **Validation photos (2026-11-18): from after the cutoff**, photos
  BioCLIP 2 has not seen, with every post-cutoff observation by a test
  set observer left out.
- **The check layer's settings (2026-11-19): reuse the shipped layer's.**
  The rare-species check layer trains at the shipped layer's chosen pull,
  epochs, blend and sharpness, and its seed, instead of searching its own,
  so it differs from the shipped layer only in its photos.
- **The training fetch's limits (2026-11-19): speed it up.** No daily cap
  on photos from the AWS Open Data bucket, where every training photo
  lives, and up to 9,500 API requests a day, still under iNaturalist's
  10,000.

## Constraints

- **Licences.** GPLv3 app; App Store and Play distribution; no
  Ultralytics AGPL code. Photos under ND licences or all rights reserved
  are never used.
- **iNaturalist's Terms of Use.** They forbid using any iNaturalist data
  to train machine learning models for commercial purposes, whatever the
  photo's licence (checked on a web archive capture of 2026-10-27; the
  live page sits behind a bot check). Submersion is free, with no ads or
  purchases, so this training is non-commercial. Marking the trained file
  non-commercial passes the limit on to anyone who reuses it. iNaturalist
  is not to be contacted (Eric's rule).
- **Publishing.** Nothing is published or replaced without Eric's go. The
  `species-pack` release stays a pre-release with `--latest=false`, drafted
  first, manifest last (`docs/developer/species-identification.md`,
  "Publishing a pack").
- **Downloads.** Downloaded data lives in its own folder, and any Python
  that reads it runs with `-I`. iNaturalist API calls stay at about one a
  second and under 10,000 a day, and photo downloads from iNaturalist's
  own servers under 24 GB a day. Photos from its public AWS Open Data
  bucket, which states no download limit, are not capped.
- **Measured bars are tied to bytes.** `NAMING_MEASURED` in `manifest.py`
  matches a pack by the SHA-256 of `candidates.json`,
  `text_embeddings.f16` and `regions.bin`. The file that is scored is the
  file that ships; it is trained once.

## Approaches

**A. Trained rows in today's file (chosen).** As above. No change to how
the app names a crop (the confident rule fix below is needed whatever
the layer does), no format change, same file size (14 MB). The app
re-names stored crops from their saved embeddings when a pack with a new version and the same
classifier arrives (`RefreshAction.rename`), so divers' undecided
suggestions improve without analysing a photo again. Its limit: a row can
move and stretch but cannot carry a fixed nudge for or against a species.

**B. Rows plus a per-species nudge, format 3.** A plus one number per
candidate added to its score: the usual remedy when common species crowd
out rare ones. Needs a new pack file, changes to the Dart namer,
`naming.py` and its test vectors, and format 3, which older apps refuse,
so either a format 2 pack stays published beside it or the release waits
for divers to update. The bias cannot be folded into the rows, because
the app scales every crop embedding to unit length. **This is the planned
next step if A fails the confident bar or the rare-species check.**

**C. A small network in front of the rows.** The most capacity, but a new
model for the app to run on every platform, for gains that published
results on frozen features put as small. Dropped.

**Ruled out.** Matching against stored training embeddings (too large,
and close to shipping the photos). Retraining BioCLIP 2 (changes the
classifier id and forces every photo to be analysed again).

## Design

### Training data

- **Source:** iNaturalist research-grade observations (research grade
  excludes captive animals), through its API as `fetch_testset.py` does,
  photos from the `inaturalist-open-data` bucket.
- **Licences:** photo licence CC0, CC BY or CC BY-NC. Both share-alike
  licences are left out (my call, see "Calls made"), as are ND and all
  rights reserved.
- **Dates and the leak guard:** observations from any date, except
  every observation in the test set and every observation created on or
  after 2024-07-01 (`CUTOFF` in `testset.py`) by any of the test set's 840
  observers (its `observer` column). Every test photo was created on or
  after the cutoff, so no test photo, and no near-copy a test observer
  took around the same time, can be trained on or validated on. Their
  older observations may train.
- **Why after the cutoff matters:** BioCLIP 2 was trained on a GBIF
  download of 2024-05-01 (`testset.py`), which holds most iNaturalist
  photos from before the cutoff. Their embeddings sit closer to their name
  rows than a diver's new photo would, so settings tuned on them would
  look better than the gate. Photos from after the cutoff are new to the
  encoder, as the test set and divers' photos are.
- **The validation split:** about 10% of the observers who have
  observations after the cutoff (once the leak guard has run), chosen at
  random with a fixed seed. Their post-cutoff observations are the
  validation split, and none of their observations, from any date, are
  trained on.
- **Training:** everything else that passes, from any date. Where a
  species has more photos than the cap, photos from after the cutoff come
  first.
- **Which species:** every candidate in the base pack's `candidates.json`.
  An iNaturalist taxon belongs to a candidate when its name matches,
  through GBIF's species match as `fetch_testset.py` does, to the
  candidate's `gbifKey`; a subspecies counts for its species.
- **How many:** up to 50 observations per candidate, one photo each (the
  observation's first), spread across observers (at most 5 per observer
  per species). Counted across all dates, about 6,300 candidates have 10
  or more. At the cap that is roughly 200,000 training photos, plus the
  validation split.
- **Sizes and pace:** the `large` photo size, as the test set uses. About
  40 GB in all, so two days at the download limit. Each photo is deleted
  once its embedding is taken.

For scale (iNaturalist research grade, the test set's seven groups,
worldwide, not limited to candidates), observations at all dates and, in
brackets, created from 2024-07-01: CC0 110,000 (52,000), CC BY 641,000
(275,000), CC BY-NC 4,914,000 (2,553,000).

### From photo to embedding

Each training photo goes through the app's own pipeline, with
`tool/species_pack/vision_cli` as the scorer runs it: the live pack's
detectors (the pair), the live crop fitting (`centreCrop`), and BioCLIP 2.
The largest box is the labelled animal, as the scorer does for test
photos (`_largest`). A photo with no box, or a box shorter than
`minCropSide` (64 px), is skipped, since the app would not name it.

What is kept per photo: the 768-value embedding, the candidate index, the
observation id, observer, date, location, licence and attribution string.
About 300 MB for 200,000 photos.

### The trained rows

My proposed recipe; the builder tunes it on the validation split.

- Start every row at the base pack's name row.
- Score a training embedding as the app does: unit crop embedding times
  each row, times `logitScale` (100, unchanged). Overall sharpness is
  carried by the row lengths, since scaling every row is the same as
  changing `logitScale`, so the manifest's value stays as it is.
- Train with cross-entropy over all 9,151 candidates, plus a penalty
  pulling each row back toward its name row, so a species with few photos
  stays close to today.
- Rows of candidates with no training photos stay exactly their name
  rows by default.
- Blend the result with the name rows (a weight between 0 and 1), as the
  last step.
- Choose the penalty, the number of passes, the blend weight and the
  overall sharpness on the **validation split** (post-cutoff photos of
  observers kept out of training, above), never on the test set. The
  test set's tune half stays for bars, its held-out half for the gate.
- Write the rows as little-endian 16-bit floats, the same shape as today,
  after checking every value is finite and within 16-bit range.
- Record the seed and every chosen setting in the findings.

### Building the pack

A new step derives a trained pack from an existing pack folder: it copies
every file of the base pack (pack `2026.11.18.0356` today), writes the
trained `text_embeddings.f16`, and writes a manifest with a new
`packVersion` and the training credit. `build_pack.py` itself is not
changed: it rebuilds candidates from GBIF and can change them by a byte,
and it remains the way to build the untrained pack, which is the open
alternative for anyone who needs a pack free of the non-commercial limit.

### Credits and licence

- A new manifest credit for the trained rows: licence CC BY-NC 4.0; text
  saying the rows were trained on N research-grade iNaturalist photos
  under CC0, CC BY 4.0 and CC BY-NC 4.0, not for commercial use, with a
  link to the list of every photo.
- The list: one row per training photo with its observation link,
  licence and attribution, as `accuracy_set.csv` does for the test set.
  It is too large for the repository, so it goes on the `species-pack`
  release as an extra file that the manifest does not list (the app
  downloads only listed files). Eric uploads it with the pack.
- The developer guide says the trained file is CC BY-NC 4.0 and that
  `build_pack.py` builds the untrained alternative.

### The gate

Measured with `score.py` on the existing test set, on the detector set
the live pack runs (the pair) at its crop fitting. The baseline is pack
`2026.11.18.0356` with its measured bars. All five must hold:

1. **More named right.** Held-out photos named right at each pack's own
   measured suggestion bars: the trained pack names significantly more
   (paired McNemar test, p < 0.05, as the detector comparison uses).
2. **A confident bar.** The trained pack's confident bar with a location
   passes `bars.py`'s target (one-sided Wilson lower bound of 95% on the
   tune half) and survives the held-out gate. The no-location confident
   bar is recorded as measured, which may be never (1.01); with the fixed
   rule, the app then names no crop without a place confidently. A
   no-location bar is a bonus, not required.
3. **No group worse.** No group in the test set's group breakdown is
   named right significantly less often than by the baseline (paired
   test per group on held-out photos).
4. **Junk.** Junk crops named at the chosen bars stay within the
   scorer's existing limit (at most 2% on the tune half).
5. **Rare species.** The rare-species check below.

If any fails, the trained pack is not offered for publishing, and the
next step is approach B.

### The rare-species check

The test set holds almost no rare animals: of its 2,155 natural
underwater photos (1,005 species), 99.8% show a species with at least 10
training observations and 95.6% one with at least 100, while about 2,800
of the 9,151 candidates have fewer than 10. So the check makes some test
species rare on purpose:

- Choose 100 species at random (seed fixed and recorded) from the test
  set's underwater iNaturalist photos.
- Train a check layer exactly as the shipped one, at the shipped layer's
  chosen settings (pull, epochs, blend, sharpness) and seed, with no
  search of its own, but with every training photo of those 100 species
  removed, so their rows stay name rows.
- Name every test photo of those species (both halves) with the check
  layer, at **the shipped layer's measured bars**, each crop judged by the
  bar for its own case (with or without a place), as the fixed app does.
- **Passes when wrong confident names fall on at most 2% of those
  photos** (about 240 photos, so at most about 4), the same 2% the scorer
  allows for junk. Report the count, its interval, and the right
  confident names too.

The check layer is never shipped.

### Recording the bars

When the gate passes, the scorer's `measured` entry for the pair joins
`NAMING_MEASURED`, with its own `contents` hashes (today's entries share
one; the trained file needs its own). Only the pair is recorded, since
only the pair is gated and the training crops come from the pair's boxes.
A Megalodon-only or fish-detector-only pack with the trained file gets
the provisional bars; the fallback the release gate design keeps (a
Megalodon-only pack) stays the untrained pack with its measured bars.

A findings document in `docs/design/findings/` records the training
data, the recipe and settings, every gate number, and the rare-species
check. The developer guide gains a "Training the naming layer" section.

### The app's confident rule

Today `namingFlags` in
`lib/features/species_id/domain/services/identification_rules.dart`
marks a crop confident when its top score reaches `confidentScore`,
whether or not the crop had a usable place. The manifest's
`confidentScoreNoLocation` is parsed but never read, though the comment
there expects it to be. The scorer, meanwhile, measures the two bars
separately (`bars.named(..., confident=True)`). Auto-apply and the video
pills both read the stored `confident` flag.

The fix: a crop named with its candidates limited to a place
(`NamingResult.locationLimited`) uses `confidentScore`; any other crop
uses `confidentScoreNoLocation`. Tests in
`test/features/species_id/domain/identification_rules_test.dart` cover
both cases, and the case where the no-location bar is never. The stale
comment goes. The builder checks how a video track's naming sets
`locationLimited`, so tracks follow the same rule.

It lands **before the release that turns marine life identification on**
(#4701 is in no release yet; the latest app release is v1.8.4), so no
installed app ever applies the with-location bar to a crop without a
place. Its own small PR, ahead of the layer (my call), since it is needed
as soon as any pack carries a real confident bar. It touches the rule
the auto-apply and live-naming work share, so it is coordinated with them
through the program's parent session. Stored identifications get their
flags again when the app re-names them on the next pack version.

### What the app does with the trained pack

Nothing new beyond the rule fix. Format 2 and the same file names. On the
new pack version the app downloads it and re-names stored crops from
their saved embeddings. The live-naming and auto-apply work call the
same namer; auto-apply gains a confident bar to use.

## Tools and files

- `tool/species_pack/fetch_training.py` (new): stages the training list,
  downloads photos into their own folder, runs `vision_cli`, keeps
  embeddings and credit rows, deletes photos. Resumable, like
  `fetch_testset.py`.
- `tool/species_pack/train_naming.py` (new): trains rows (shipped and
  check layers), derives the trained pack, writes the credit list.
- `tool/species_pack/score.py`: compare a trained pack with a baseline
  pack, per photo, for gate items 1 and 3; run the rare-species check.
- `tool/species_pack/manifest.py`: the training credit; per-entry
  `contents` in `NAMING_MEASURED`.
- Tests beside each, standard library only where the module allows, as
  the existing `*_test.py` files are.
- `lib/features/species_id/domain/services/identification_rules.dart`
  and its test: the confident rule fix, in its own PR first.
- Docs: the developer guide, the findings, and a pointer from the program
  design's "Training later" to this design.

## Left to the builder

- The training code and library (numpy is already in the tool's
  requirements; anything new is the builder's call, licence permitting).
- The recipe's settings, within "The trained rows", chosen on the
  validation split; whether rows with no photos may move as negatives,
  judged on a validation analogue of the rare-species check, not the test
  set.
- Whether training uses the region mask at each photo's location instead
  of the open softmax, judged on the validation split.
- Whether out-of-water photos (an animal on a deck) are filtered from
  training.
- How `score.py` takes the baseline (a `--baseline` pack, or comparing
  two runs' per-photo results), and whether vision runs are reused across
  pack versions when the models and settings match (today the run file
  name carries the pack version, so a derived pack reruns them).
- The exact credit wording, within the facts above.

## Calls made in this design (for Eric to check)

- **Both share-alike licences are left out** (CC BY-SA and CC BY-NC-SA,
  about 3% of photos in these groups). Each requires the trained file to
  carry its own licence, and CC BY-SA would also allow commercial use of
  a file built partly from non-commercial photos. Without them the file
  has one licence: CC BY-NC 4.0.
- **The validation split is about 10% of post-cutoff observers**, kept
  wholly out of training; where a species has more photos than the cap,
  post-cutoff photos come first.
- **All 9,151 candidates keep a row**; the region table is unchanged.
- **The gate is measured on the pair**, the live detector set; the
  confident bar with a location is the required one.
- **The rare-species pass mark is 2%** of the held-back species' photos,
  at the shipped layer's bars.
- **Up to 50 photos per species, 5 per observer.**
- **Settings are chosen on the validation split**, never the test set.
- **The trained pack derives from pack 2026.11.18.0356** rather than a
  fresh `build_pack.py` run.
- **The credit list goes on the release as an unlisted file**, uploaded
  by Eric with the pack.
- **The confident rule fix is its own PR**, landing before the layer and
  before the release that turns the feature on.
- **Only the pair's trained bars are recorded** in `NAMING_MEASURED`; a
  trained pack with another detector set gets the provisional bars.

## Open risks

- **iNaturalist's terms.** Whether the training clause reaches photos
  taken through GBIF or the open data bucket is unsettled. The design
  reads this training as non-commercial and marks the file so.
- **Whether trained numbers are an "adaptation" under Creative Commons**
  is unsettled; the design credits as if they are.
- **A may not be enough.** If the confident bar or the rare-species check
  fails, approach B follows, with an app release.
- **Video tracks.** Playback pills and auto-apply also use the
  confident bar on tracks named from averaged embeddings, which the gate
  does not measure (true of any confident bar, not only this layer's).
- **Test set size.** A confident bar is proven only on the tune-half
  crops that score above it, and 52 all named right is the fewest that
  can reach the 95% bound. If too few crops score that high, the bar
  fails even when the layer is good enough; if it fails narrowly, a
  larger test set is an alternative to approach B.
