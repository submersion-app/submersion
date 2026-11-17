# Marine life identification: measured accuracy

The "Measured accuracy" piece of the
[marine life identification program](2026-11-17-marine-life-identification-program-design.md).
Refs #4668, whose first piece
([photos on Apple devices](2026-11-17-marine-life-identification-1-photos-design.md))
shipped in PR #4671 behind the `marineLifeIdEnabled` flag. Target release
v1.8.5.

Where a decision was made by the maintainer it is marked **(decided)**.
Where it is the designer's call, open to correction, it is marked
**(proposed)**.

## Why

The naming rules show a species only when a crop clears a set of bars that
the model pack carries. Today those bars were set by eye on one dive's photos,
against 685 candidates, with no region table. A pack now has about 8,000
candidates, and a share split across 8,000 names is not the same number as a
share split across 685. The program will not turn the flag on for divers
until accuracy is measured and the bars come from the measurement
(program design, "The pieces"). This piece does that, and settles one open
question from piece 1: how a crop is fitted to the classifier's square input.

## Goals

- A labelled test set of openly licensed underwater fish photos, rebuildable
  by anyone from a committed list, with every photo's licence and attribution
  recorded.
- A scoring tool that runs a pack's two models exactly as the app does and
  names each crop with the app's own rules.
- A report of top-1 and top-3 accuracy, with and without the region limit.
- Measured values for `minOpenScore`, `suggestScore`, `confidentScore`,
  `suggestScoreNoLocation` and a new `confidentScoreNoLocation`, chosen to
  meet stated precision targets, so `naming.provisional` becomes false.
- A measured comparison of pad-to-square crop fitting (what the app does)
  against the spike's centre crop, and the better one applied.

## Non-goals

- Publishing a pack. The detector's licence is unresolved
  (filippovarini/community-fish-detector#8) **(decided: deferred)**.
- Turning the flag on.
- Changing the shape of the naming rules (two scores, region limit, size
  floor). This piece sets their numbers; if the numbers show a rule is wrong,
  that is reported, not redesigned here.
- Tuning `minCropSide`, `minAllowedCandidates` or `topK`. They keep their
  values; the report shows how results vary with box size and how often the
  region limit fell back.
- Video, or any other platform than macOS for running the tool.
- Training or fine-tuning anything.

## Anti-goals

- **Bars tuned on photos the model was trained on.** Accuracy would read
  high and divers would see confident wrong names.
- **Bars tuned and graded on the same photos.** The reported precision would
  flatter the bars.
- **A test set that is not what divers photograph** (fish on a boat deck, in
  a market, in an aquarium).
- **Measuring a near-copy of the app** instead of the app.
- **Photos committed to the repository**, or any photo whose licence does not
  allow this use.

## Targets (decided)

- Among crops the app **suggests**, the top name is the true species at least
  **85%** of the time.
- Among crops the app calls **confident**, at least **95%**.

"True species" means the same GBIF accepted species key as the label. A right
genus with the wrong species is wrong, because the diver would get a wrong tag
**(proposed)**.

`confidentScore` is parsed by the app but not yet used; it will drive video
labels and auto-apply in later pieces. It is measured now so that those pieces
start from a real number.

**When a target cannot be met (decided): the app names nothing at that
level.** If no bar meets a target for one kind of photo (with or without a
location, suggested or confident), that bar is set to **never**: 1.01, which
no share can reach, since a softmax share is at most 1. The likeliest case is
confident names on photos with no location. This follows "say nothing
otherwise" and the anti-goal on confident wrong names; the findings state
what was switched off and what it would have cost.

So that confident names without a location can be switched off on their own,
the manifest gains `confidentScoreNoLocation`, the confident counterpart of
`suggestScoreNoLocation` **(proposed)**. The app reads it when present and
falls back to `confidentScore` when it is not, so manifests already written
stay valid and the format version does not change. Older apps ignore the key.

## Approaches

Three ways of running the models were weighed.

1. **The app's own Swift pipeline, driven by a command-line tool (chosen,
   decided).** A small macOS command-line program compiled from
   `packages/submersion_vision/darwin/Classes/VisionPipeline.swift` itself,
   with a stand-in for the one Flutter type the file uses. It writes each
   detection's box, pixel size and embedding as JSON. Python does everything
   after the embedding. This measures exactly what ships: decoding, EXIF
   orientation, CoreGraphics resizing, and the 16-bit Core ML models. Cost: to
   compare the centre crop, the Swift pipeline gains an optional fitting
   setting, and the tool runs only on macOS.
2. **A Python copy of the pipeline** running the same Core ML files through
   coremltools, with PIL doing the cropping and resizing. One language and an
   easy fitting comparison, but the pixel preparation differs from the app's.
   On the photos design's parity check, small differences like that flipped
   the top name of low-scoring crops, which is exactly the region the bars
   sit in.
3. **The PyTorch originals**, as the spike used. Dropped: it measures 32-bit
   models with different preprocessing, not what the app runs.

## The test set

### Fish photos (decided: a natural sample)

Observations are taken as they come from where divers dive, not balanced per
species. Species missing from the pack then turn up about as often as divers
meet them, which is what the bars must cope with: a missing species gets the
nearest wrong name unless the bars stay quiet.

Source: iNaturalist, through its public API **(proposed details)**:

- Research grade, not captive, with coordinates that are not obscured.
- Taxon: ray-finned fish (Actinopterygii) and sharks and rays
  (Elasmobranchii), identified to species or below. A subspecies counts as
  its species.
- **Created on or after 2024-07-01.** BioCLIP 2 was trained on
  TreeOfLife-200M, built from a GBIF occurrence download created 2024-05-01
  (`10.15468/dl.bfv433`), and GBIF carries iNaturalist research-grade photos.
  Two months' margin covers observations created before the download but
  indexed after.
- Photo licence CC0, CC BY or CC BY-SA. Share-alike is included because
  nothing is redistributed.
- Seven regions, each a latitude and longitude box: Caribbean and Bahamas,
  Red Sea, Indo-Pacific coral triangle, Hawaii, Great Barrier Reef and Coral
  Sea, Mediterranean, California and Baja California Pacific coast. About 450
  observations per region, about 3,000 in all. The exact boxes are the
  builder's.
- The first photo of each observation, at iNaturalist's "large" size (1,024
  px on the longer side). Openly licensed photos are served from the
  iNaturalist open data bucket.
- Sampled across the date range (not just the newest), and never two
  observations from one observer on one day, so one diver's afternoon cannot
  dominate a region.

A pool check found 17,039 qualifying observations in a Caribbean box alone,
about 11% of all licences, so the sample is not limited by supply.

**Freshwater fish stay in (decided).** The region boxes take in rivers, lakes,
springs and cenotes, and divers dive those too, so nothing is filtered by
habitat. Freshwater species are mostly not in the pack and will count as
out-of-pack, which makes the bars somewhat stricter than a sea-only sample
would. The report breaks results down by habitat (marine or brackish, against
freshwater only, from GBIF's species profiles) so that cost is visible; the
flag is used for reporting only, never for sampling.

**Underwater only.** iNaturalist has no underwater flag. Each photo is scored
by BioCLIP 2 (the PyTorch model, used only for this filter, never for
scoring) against "underwater" and "out of water" prompts (a fish in a hand, on
a deck, on ice, at a market, in an aquarium, a drawing). Photos judged out of
water are dropped. The builder looks over a contact sheet of kept and dropped
photos and records in the findings how many of a sample of each were wrong
**(proposed)**.

**Labels.** Each observation's taxon name is matched to a GBIF accepted
species key with GBIF's name match service (kingdom Animalia, strict), the
same keys the pack's candidates use. Observations that do not match a species
key are dropped and counted. A label is **in-pack** when its key is a pack
candidate and **out-of-pack** otherwise.

**Which box carries the label.** An observation names one species but the
detector may box several fish. The largest box carries the label; other boxes
are not scored. Observations with no box are counted as missed by the
detector, and are not scored for naming **(proposed)**.

**A test photo must not vouch for its own location (proposed).** The pack's
region table comes from GBIF density maps, which include iNaturalist
research-grade records, so each test observation can switch its own species
on in its own cell. For each test observation, one GBIF occurrence count asks
whether its species has any record dated before 2024-07-01 in the
observation's cell or the cells around it (the same neighbourhood the app
uses). That answer, not the pack's bit, decides whether the label species is
allowed for that crop. Every other species' bits are used as the pack has
them. About 3,000 count queries, cached in the work folder.

### Junk crops: divers, hands and gear

The detector boxes divers and hands as fish at up to 0.95. The spike's
8-crop sample is too small to test against. A second set **(proposed)**:

- About 150 openly licensed photos of scuba divers from Wikimedia Commons
  (CC0, public domain, CC BY, CC BY-SA), from its scuba diver categories.
- The detector runs on them; the builder labels each box by eye as person or
  gear, fish, or unclear. Only person or gear boxes are used, as **junk**.
  Labels are recorded with the source "by eye (builder)", and contact sheets
  of every labelled box are kept in the work folder and linked from the
  findings, so the maintainer can check them **(proposed)**.
- Junk is kept apart from the natural sample, because its real frequency in
  divers' photos is unknown. It has its own target: at the chosen bars, **no
  more than 2% of junk crops are named** (suggestable) **(proposed: the 2% is
  the designer's number)**.
- Junk crops are split into tune and held-out halves like the fish. Each is
  named twice: with no location, and with the grid cell of a fish
  observation picked by a hash of the crop's id, so that the region limit's
  lift is tested at real dive locations. A crop counts as named if it is
  suggestable either way.
- The 2% is a point estimate on the tune half (a bound would demand close to
  zero named from about 75 crops). If the bars chosen from the fish photos
  name more than that, `minOpenScore` rises until they do not, and the cost in
  fish named is reported. The held-out junk rate is reported with its
  interval.

### What is committed and what is not

- Committed: `tool/species_pack/testdata/accuracy_set.csv`, one row per
  photo: source, observation or file id, photo URL, licence, attribution
  (observer or author name and the page URL), region, coordinates, label
  name, GBIF key, how the label was made (observation or by eye), and the
  underwater filter's verdict. Anyone can rebuild the set from it.
- Not committed: the photos, embeddings and intermediate JSON. They live in
  a work folder, `build/species_accuracy_work` by default, which `build/`
  already keeps out of git.

## Running the models

### The command-line tool

`tool/species_pack/vision_cli/` holds `main.swift` and a stand-in for
`FlutterStandardTypedData`, and a build script that compiles them with
`swiftc` together with the package's own `VisionPipeline.swift` (not a copy),
so the tool cannot drift from the app.

- Input: a manifest, the two compiled model paths, the crop fitting, and a
  list of image paths.
- Output: one JSON line per image with its oriented width and height, and per
  detection the normalised box, detector score, pixel size and embedding.
- Models load once per run. It runs on the Mac's GPU and Neural Engine like
  the app.

Two small changes to the package make that possible **(proposed)**:

1. `VisionPipeline.swift` imports Flutter only when it can
   (`canImport(Flutter)` and `canImport(FlutterMacOS)` in place of the
   platform check), so it compiles outside the plugin.
2. `VisionError` moves from `SubmersionVisionPlugin.swift` into the pipeline
   file, which uses it.

### Crop fitting

`VisionModelSettings` gains an optional `cropFit`: `padSquare` (today's
behaviour, the default when absent) or `centreCrop` (the spike's: shorter side
resized to the input size, the centre cut out). The app's Dart side does not
send it, so the app keeps pad-to-square unless this piece's result changes
that.

**Choosing between them (proposed, fixed before the run):** each fitting gets
its own bars from the tune half (below), and is compared on the held-out half
by the number of crops correctly suggested at the 85% target, with top-1
accuracy as a second reading. Centre crop is adopted only if it suggests
significantly more correct names (a paired test on the same crops, 5% level).
Otherwise pad-to-square stays, which needs no app change.

If centre crop is adopted: the Dart manifest entity reads `classifier.cropFit`
(an unknown value is treated as `padSquare`), `VisionModels` carries it to the
native side, the channel passes it, and `manifest.py` writes `centreCrop`.

## Scoring

### Naming

`tool/species_pack/naming.py` mirrors
`lib/features/species_id/domain/services/species_namer.dart`: unit-normalise,
dot with the text embeddings, times `logitScale`, open softmax over all
candidates, region mask from the cell and its neighbours, fallback when fewer
than `minAllowedCandidates` are allowed, limited softmax, top `topK`. It
returns the scores, not a yes or no, so the bar search can try every bar.

The two must not drift. `naming.py` writes `testdata/naming_vectors.json`
(small, generated embeddings, candidates and region bits, with the expected
open score, ranking and limited scores), and a Dart test checks
`SpeciesNamer` against the same file, the way `region_vectors.json` keeps the
grid in step **(proposed)**.

Each fish crop is named twice: with the observation's coordinates (its grid
cell) and with no location.

### Tune and test halves

Observations are split 50:50 by a hash of the observation id, within each
region, so the split is repeatable and every region is in both halves. Bars are
chosen on the tune half only. Every number in the findings comes from the
held-out half, with a 95% Wilson interval.

### Choosing the bars

Grids: `minOpenScore` from 0 to 0.50 by 0.01, score bars from 0.20 to 0.99 by
0.01. A setting **meets** a target when the one-sided 95% Wilson lower bound of
its precision on the tune half is at least the target. That asks a little more
than the point estimate, so a bar does not pass on a lucky handful of photos
**(proposed)**.

- `minOpenScore` and `suggestScore` are chosen together, over the crops named
  with location (those where the limit applied; crops that fell back are
  graded under the no-location bar, as in the app): the pair that meets 85%
  with the most correct suggestions. Ties go to the higher `minOpenScore`.
- `suggestScoreNoLocation`: with that `minOpenScore` fixed, the lowest bar
  that meets 85% over every crop named with no location.
- `confidentScore` and `confidentScoreNoLocation`: with that `minOpenScore`
  fixed, the lowest bar at or above the matching suggest bar that meets 95%,
  with location and without.
- Then the junk check above, which may raise `minOpenScore`; if it does, the
  score bars are chosen again with the new value.
- Any bar for which no grid value meets its target on the tune half is set to
  never (1.01).
- **The held-out gate.** Each chosen bar is then checked once on the held-out
  half. It stands when the 95% Wilson interval of its held-out precision
  reaches the target (its upper end is at or above it). When the whole
  interval lies below the target, the bar is set to never. The held-out half
  only passes or fails a bar; no value is ever chosen from it **(proposed)**.
- Every crop below `minCropSide` (64 px) is never suggestable, as in the app,
  and counts against coverage.

Precision is the share of suggested crops whose top name is the label, over
in-pack and out-of-pack crops together: an out-of-pack crop that is suggested
is always wrong.

### The report

`tool/species_pack/score.py` writes a Markdown report and a JSON file of every
number. For each fitting, on the held-out half:

- Detection: share of photos with any box; share whose largest box is at
  least 64 px.
- Top-1 and top-3 accuracy, with and without the region limit, over in-pack
  crops, and over all crops.
- At the chosen bars: coverage (share of fish crops suggested), precision of
  suggestions, coverage and precision of confident names, each with and
  without location.
- The same, broken down by region, by in-pack or out-of-pack, by habitat
  (marine or brackish, against freshwater only), and by box size (64 to 127,
  128 to 255, 256 px and over).
- Which bars, if any, were set to never, and what they would have named.
- How often the region limit fell back to no location.
- The junk naming rate.
- A precision and coverage curve over `suggestScore`, so the cost of a
  stricter or looser target is visible.

## Applying the result

- `manifest.py`: `NAMING_PROVISIONAL` stays as the values for a pack the bars
  were not measured on. A new `NAMING_MEASURED` holds the chosen bars with
  `provisional: false`, the classifier id, the candidate count and the
  findings file they came from. `build_manifest` uses the measured bars only
  when the pack's classifier id matches and its candidate count is within 10%
  of the measured one; otherwise it writes the provisional bars, so a small
  development pack is never labelled measured **(proposed)**.
- The pack the bars are measured on is a full build at the builder's defaults
  (8,000 candidates, at least 50 images). The 1,495-candidate development pack
  is used while building the tool, never for the numbers.
- `CLASSIFIER_SETTINGS["cropFit"]` and, if centre crop wins, the Swift and
  Dart changes above.
- The app: `NamingConfig` gains `confidentScoreNoLocation`, read when present
  and otherwise equal to `confidentScore`. Nothing in the app uses either
  confident bar yet, so this changes no behaviour today.
- `docs/design/findings/2026-11-<day>-marine-life-measured-accuracy.md`: the
  method, the test set's make-up, the numbers, the chosen bars, the fitting
  decision, and the limits below.
- `docs/developer/species-identification.md` gains a "Measuring accuracy"
  section: building the test set, building the tool, running the scorer.

## Limits the findings must state

- iNaturalist photos are mostly close-ups chosen by the photographer.
  Wide-angle dive footage has more small, distant fish, so real coverage will
  be lower than measured. Precision at the bars should hold better than
  coverage, because small crops are filtered by size.
- "Large" photos cap the longer side at 1,024 px, so boxes are smaller in
  pixels than in a diver's original. The 64 px floor is tested only roughly.
- The underwater filter and the junk labels are judgements, not ground truth.
- iNaturalist research grade is a community identification and is sometimes
  wrong.
- The bars hold for this classifier and a candidate list of this size.
  Changing either means running the scorer again.

## Testing

Tests are written first. The pure parts get Python tests beside them, wired
into CI's "Run Python guard tests with coverage" step like `manifest_test.py`,
with the new modules added to its coverage list:

- naming: matches the shared vectors; open score unaffected by the region
  limit; fallback below `minAllowedCandidates`; unusable embeddings.
- the split: repeatable, balanced within each region.
- Wilson bounds and the bar search on small hand-built score lists, including
  ties, no setting meeting the target, and the junk raise.
- label handling: subspecies to species, unmatched names dropped, in-pack and
  out-of-pack.
- licence filtering and the test set CSV round trip.
- `build_manifest` choosing measured or provisional bars.
- Dart: `SpeciesNamer` against `naming_vectors.json`; the manifest reading
  `confidentScoreNoLocation`, and falling back when it is absent; and, only if
  centre crop is adopted, the manifest's `cropFit` parsing and the channel
  arguments.

Network fetching, the Swift tool and the full run are exercised by running
them; no automated test runs the models.

## Left to the builder

- File layout inside `tool/species_pack/` and module names.
- The region boxes, the underwater prompts, and the Commons categories.
- The JSON shape between the Swift tool and Python.
- Request pacing for iNaturalist (at most one request a second) and GBIF.
- The report's exact layout.

## Calls made by the designer, for the maintainer to check

1. A right genus with the wrong species counts as wrong.
2. Observations are kept from 2024-07-01, two months after BioCLIP 2's data
   was downloaded.
3. CC BY-SA photos are included.
4. The largest box carries the observation's label.
5. Junk crops have their own target: at most 2% named, as a point estimate
   on the tune half, tested with and without a location.
6. On the tune half a bar passes on the lower bound of its precision, not the
   point estimate; on the held-out half it fails only when the whole interval
   is below the target.
7. Centre crop is adopted only if it is significantly better; otherwise
   pad-to-square stays.
8. Measured bars apply only to packs within 10% of the measured candidate
   count with the same classifier.
9. `minCropSide`, `minAllowedCandidates` and `topK` are not tuned.
10. The manifest gains an optional `confidentScoreNoLocation`.
11. The builder labels the junk boxes and reviews the underwater filter, and
    leaves contact sheets for the maintainer to check.
12. A test photo's own sighting does not count toward its species being
    allowed in its cell.
