# Marine life identification: program overview

This is the overview for a program of about five pieces. It records the
decisions that hold across all of them. Each piece gets its own design when it
is started; the first is
[2026-11-17-marine-life-identification-1-photos-design.md](2026-11-17-marine-life-identification-1-photos-design.md),
tracked by issue #4668.

Where a decision below was made by the maintainer it is marked **(decided)**.
Where it is the designer's call, open to correction, it is marked
**(proposed)**.

## Why

Divers come back with photos and video full of animals they cannot name, and
the reef fish books at the dive shop are slow to search. Submersion already
lets a diver tag a species on a photo by hand, which also logs the sighting on
the dive. What it cannot do is look at the media itself.

This program gives the app that ability: an on-device model finds the animals
in a diver's linked photos and videos, suggests what they are, and keeps a
cropped image of each one so the diver can check the call.

It is the first part of a larger initiative, **Guided Media Tagging**, in which
the app shows the diver media with creatures or people in it and prompts them
to tag each one more specifically. The model's output is deliberately treated
as rough detections that the diver confirms or refines. The payoff is species
tags, counts and firsts.

## What the diver gets when the program is complete

- Opening a photo shows suggested species next to the species the diver has
  tagged. One tap turns a suggestion into a tag.
- A video plays back with a name pill above each fish the app can suggest a
  name for, joined by a thin line to a dot on the animal. Fish it cannot name
  are left unmarked while playing.
- Every identification keeps a small cropped image, so the diver can validate
  it without opening the photo or finding the moment in the video.
- A setting lets confident matches be tagged with no tap. Tags the app applied
  stay marked as not yet validated until the diver confirms them.
- All of it runs on the device, offline, once an optional model download is
  installed.

## Goals

- Find animals in linked photos and videos, on the device, with no network use
  after the model download.
- Suggest a species only when the app has good reason to; say nothing
  otherwise.
- Keep the diver in charge of what enters the log.
- Store what the app found in a form Guided Media Tagging can build on:
  where the animal is, when in a video, what the candidates were, and what the
  diver decided.
- Let the model be replaced without an app release.

## Non-goals

- No live camera or recording in the app. Analysis runs only on media already
  linked to the log **(decided)**.
- Finding people. That belongs to Guided Media Tagging.
- The guided tagging flow itself (a queue of media to work through).
- Training a model. The program ships models others have published; see
  "Training later" below.
- Counting individual animals. A detection is evidence a species was seen, not
  a census.

## Anti-goals

These would make the feature a failure even if it works technically.

- A dive log that fills with species the diver never chose and cannot tell
  apart from their own entries.
- Confident wrong names. A diver who is told a Caribbean sergeant major is a
  Pacific convict tang stops trusting every suggestion.
- A copy of the diver's photos or videos kept by the app. Only small crops are
  kept; originals are never copied, moved or modified.
- Any photo, video, crop or location leaving the device.
- A large download nobody asked for.

## Constraints

- **Platforms.** iOS 15, macOS 12, Android (minSdk 26), Windows and Linux.
  The web build must still compile; the feature is absent there.
- **Media is links only.** The app holds references to originals in the
  platform photo library, local files or URLs. An original may be unreachable
  on a given device or at a given moment.
- **Licences.** The app is GPLv3 and ships through the App Store and Google
  Play. Third-party copyleft in store builds is a known conflict, so models
  built on Ultralytics YOLO (AGPL-3.0) are ruled out.
- **Size.** The models are far too large to bundle for everyone.
- **Catalogue.** The built-in species catalogue has 685 species, each with a
  GBIF key, and each requires descriptions in 11 languages to add.

## What was measured

A throwaway spike ran the chosen models over one real library (82 photos and
587 frames sampled from 34 of 338 videos, wide-angle action camera footage
from the Caribbean) on an Apple M5 Pro. The library had no species tags, so
correctness below is a reading of the crops by eye, not a measured accuracy.

| Model | Size (16-bit) | Core ML | ONNX Runtime, CPU |
| --- | --- | --- | --- |
| Fish detector (RF-DETR nano, 640 px) | 55 MB | 7.5 ms per frame | 100 ms per frame |
| BioCLIP image tower (ViT-B/16) | 173 MB | 3 ms per crop | 26 ms per crop |
| BioCLIP 2 image tower (ViT-L/14) | 608 MB | 10 ms per crop | 101 ms per crop |

All three converted to both Core ML and ONNX, and the converted models matched
the originals (cosine similarity 0.99999 or better).

What the spike showed about quality:

- **Finding fish is the frequent win.** The detector found at least one fish
  in 62% of photos and 55% of frames.
- **Naming them is the occasional one.** Only 12% of photos and 3% of frames
  had a fish that was both large enough and confidently named. Most fish in
  wide-angle footage are distant blue silhouettes that nothing could name. Of
  1,048 boxes, 403 were at least 64 px on the shorter side.
- **Close fish were named plausibly**: queen parrotfish, blue tang and
  schoolmaster snapper at 70% to 95%.
- **The detector boxes divers and hands as fish**, at up to 0.95. BioCLIP 2
  scored those crops at 4% to 13%. Adding "human" as a candidate name caught
  none of eight.
- **Wrong-ocean names were common.** Among crops named at 50% or more, a third
  were species with no records in the Western Atlantic at all.
- **The catalogue is too small to be the candidate list.** 14 of 20 very
  common Caribbean reef fish are missing from it. A missing fish gets the
  nearest wrong name.
- **The two BioCLIP versions agreed on only 3% to 6% of crops.** The older one
  is confidently wrong on junk (a hand scored 75% as a jellyfish). BioCLIP 2's
  confidence can be relied on.

## Approaches

Three ways of building this were weighed.

1. **Off-the-shelf pair, as a replaceable download (chosen).** The Community
   Fish Detector for where the animals are, and BioCLIP 2 to name each crop
   against a list of candidate species. Fastest route to something real.
   Finds fish only. The download is about 660 MB. The detector's weights have
   no stated licence, and BioCLIP was partly trained on images with
   non-commercial terms.
2. **Train our own small models.** A detector and classifier trained only on
   freely licensed images: clean licences, tens of megabytes, and able to box
   turtles, rays and invertebrates as well as fish. It is a training project
   of weeks, needing rented GPU time, a data pipeline and a test set, with a
   real chance of a worse result.
3. **Name whole photos with no detector.** Simplest, but there are no
   positions, so no labels over a video and no crop of each animal.

Also ruled out: the operating systems' built-in recognisers, which stop at
"fish"; and cloud services, which break the offline requirement.

Approach 1 was picked **(decided)** because it shows real results soonest, and
because the model ships as a pack the app does not hard-code, so approach 2
can replace it later without changing the app.

FishSnapper, the app that prompted this, credits the same family of models
(BioCLIP 2.5 and a YOLOv9 detector), is 732 MB, and needs an iPhone 15 Pro.

## Decisions that hold across every piece

### Models and how they run

- **Detector:** Community Fish Detector, RF-DETR nano, one class ("fish"),
  640 px input **(decided)**.
- **Classifier:** the BioCLIP 2 image tower only. The older, smaller BioCLIP
  is not offered: its confidence cannot be trusted, and the design leans on
  confidence **(decided)**.
- **Runtime:** a plugin package of our own, in the shape of `submersion_ocr`,
  with one Dart interface and two engines: Core ML on iPhone, iPad and Mac;
  ONNX Runtime on Android, Windows and Linux. The published Flutter packages
  were rejected because each breaks a supported platform or OS version
  **(proposed)**.
- **Division of work:** native code decodes the image, runs the detector, cuts
  the crops and runs the classifier, returning positions, crop thumbnails and
  one embedding per crop. Turning an embedding into species names is done in
  Dart, so that the naming rules are identical and testable on every platform
  **(proposed)**.

### The model pack

The models are an optional download, never bundled **(decided)**.

- The download states its size and asks before starting.
- A pack is a manifest plus files. The manifest gives a pack version, a format
  version, each file's size and SHA-256, the model input sizes, the embedding
  width, and the thresholds the naming rules use, so that thresholds can be
  tuned by publishing a pack.
- A pack carries, per engine, the detector and classifier in that engine's
  format; and for every engine, the candidate table, the candidates' text
  embeddings, and a table of where each candidate has been recorded.
- Packs are published on the project's GitHub Releases. The app fetches the
  manifest over HTTPS from there and checks every file against the manifest's
  checksums. The app accepts a pack only if it understands its format version,
  so an old app ignores a pack it cannot read.
- A pack is built by a developer-run script kept in the repository. It is not
  part of the app build or CI.
- An installed pack is excluded from iCloud and computer device backups. It
  is large and can be downloaded again.
- **Phones and tablets need 8 GB of memory at launch (decided 2026-11-18).**
  An iPhone 17 Pro Max gave the app a 3,376 MiB limit and a 6 GB phone's is
  unmeasured, so the floor started at 6 GB and rose to 8 GB in the
  [release gate](2026-11-18-marine-life-release-gate-design.md); it comes
  back down once a 6 GB phone is measured.

### Naming rules

These came out of the spike and apply wherever a name is shown.

1. **A confidence bar.** A crop gets a suggested name only when it is large
   enough and the classifier is confident enough. Below the bar the app says
   nothing. The bars are carried in the pack. A score is a share split across
   the whole candidate list, so a bar only means something for the list it
   was set against: the spike's values (0.50 to suggest, 0.70 for confident,
   against 685 candidates) are **provisional** and will not carry over to a
   list of thousands. They are replaced by measured values before any diver
   sees the feature **(decided)**; see "The pieces".
2. **Candidates limited by place.** When the dive site (or the photo itself)
   has coordinates, only species recorded near there are candidates. The
   record table ships in the pack, so this works offline. Limiting the list
   raises every remaining score, so two guards apply: a crop must first look
   like something specific against the whole list, and a place with too few
   recorded species is treated as no place at all.
3. **More candidates than the catalogue.** The pack's candidate list is much
   larger than the built-in catalogue. Accepting a suggestion for a species
   the diver's catalogue lacks adds it as one of their own species.
4. **Divers and hands.** The confidence bar keeps them from being named. They
   must also not be offered as unnamed "fish" once unnamed detections become
   visible (paused video, Guided Media Tagging). How is settled in the video
   piece.

### What is stored

- **An identification** records which media it is on, where the animal is (a
  box normalised to the image), the moment in a video if any, the detector's
  score, the ranked candidate species with scores, the pack version that
  produced it, and its state: suggested, accepted, or rejected.
- **A crop** of about 320 px is kept for each identification, in the app's
  own data on the device, so that validation works even when the original is
  unreachable. This is a deliberate, narrow exception to "media is links
  only": thumbnails of detected animals, never the originals **(decided)**.
- **Tags stay tags.** An identification becomes a species tag on the media
  (and so a sighting on the dive) only when it is accepted. The existing tag
  and sighting records are unchanged and remain the only thing the rest of the
  app reads.
- **Identifications and the diver's decisions on them live in the main
  database, with the logbook they belong to.** They are in the app's backups
  and survive a restore, a reset or a visit to the demo logbook. They do not
  sync; accepted tags sync as they do today **(decided)**.
- **Embeddings**, the numbers a crop is named from, are kept in the
  device-local cache. They can be recomputed, and keeping them lets the app
  re-name a fish after a pack update without the original or the model.
- **Crops are files on the device.** They are not in the app's backups. A
  photo whose crops are missing is analysed again the next time it is opened.
- The app remembers that a piece of media was analysed, and with which pack,
  including when nothing was found, so it does not repeat the work.

### Applying suggestions

- Suggestions are shown for the diver to accept one at a time, or all at once.
- A setting, off by default, tags confident matches with no tap **(proposed;
  the maintainer asked for "a way to auto-apply")**.
- A tag the app applied is marked as not yet validated until the diver
  confirms it against its crop. Rejecting it removes the tag. Today removing
  a tag never removes a sighting; whether that should differ for a sighting
  the app itself created is settled in the auto-apply piece.

### How labels look on video

**(decided, from a reference frame the maintainer supplied)**

- A rounded name pill above the animal, a thin line down, and a dot on the
  animal. No box outline.
- While playing, animals the app can suggest a name for get a pill, as they
  do when paused **(decided 2026-11-18, issue #4709, replacing "only
  confidently named animals")**: the published pack's confident bar is never
  reached. Nothing reads "unidentified".
- **(proposed)** While paused, animals the app found but could not name show a
  plain dot that can be tapped to tag.
- Each pill follows one animal across frames. The scan links detections into
  tracks and names each track from its best crops, about a second after it
  appears, and again only on a clearly better view (issue #4709).

### Video analysis

**(decided)** Both of these, with everything found stored so later playbacks
cost nothing:

- **Scan first:** the video is analysed once, with progress shown, then plays
  back with labels in step. This is the path on slower devices.
- **Live:** names appear as the video plays.

**(decided 2026-11-18, issue #4709)** Live naming is the same scan following
the playhead, on every device, with no device list or second engine: it
scans from where the diver is watching, moves when they seek, names a fish
while it is still in view, and fills in what it skipped afterwards. A device
faster than playback (every phone and tablet the memory floor admits, and
Apple silicon Macs) shows names as the fish appear; a slower one scans the
same stretches in the same order, and its names show when the diver pauses
or goes back.

## The pieces, in order

1. **Photos on Apple devices.** The Core ML engine, the pack download, stored
   identifications and crops, and suggestions in the photo viewer. Target
   release v1.8.6 **(decided)**.
2. **Video on Apple devices.** Scan first, then labelled playback in the look
   above **(decided to come second)**.
3. **Android, Windows and Linux.** The ONNX Runtime engine.
4. **Auto-apply and review.** The setting, the not-yet-validated state, and a
   place to work through what the app applied.
5. **Live naming** during playback: the scan follows the playhead and names
   fish in view, on every device (issue #4709).

The order of pieces 3 to 5 is not fixed.

One more piece has no fixed place in the order but gates the release:

- **Measured accuracy.** A labelled test set built from openly licensed
  photos, a tool that scores a pack against it, and confidence bars set from
  the result. Until this is done the bars are provisional and accuracy is a
  matter of opinion.

Every piece stays behind a feature flag. The flag is turned on for divers
only when all three of these hold **(decided for the second; proposed for the
others)**:

1. The detector's licence is cleared.
2. The measured accuracy piece is done and the bars come from it.
3. The maintainer is satisfied with the results.

On 2026-11-18 the maintainer settled all three and chose to turn it on
everywhere it can run, in one step: the
[release gate design](2026-11-18-marine-life-release-gate-design.md)
records the pack, the licence risks accepted and the 8 GB floor. The flag
is now on by default for iPhone, iPad and Mac, once the pack is published.

## Open risks

- **The detectors' licences.** A pack can carry the Community Fish
  Detector, FathomNet's Megalodon or both
  ([two detectors design](2026-11-17-marine-life-two-detectors-design.md),
  issue #4691), so this is now a choice of which pack to publish. The
  Community Fish Detector's weights have no stated licence, and its authors
  leave their use to the user (filippovarini/community-fish-detector#8).
  Megalodon's weights are CC BY 4.0 from MBARI, but it was trained with
  Ultralytics' AGPL-3.0 code, and whether that reaches the weights is not
  settled. **Accepted (2026-11-18):** the first published pack carries both
  detectors, and the maintainer accepts both risks; if either is challenged,
  a Megalodon-only pack replaces it without an app update
  ([release gate](2026-11-18-marine-life-release-gate-design.md)).
- **Training data terms.** BioCLIP 2 is published under MIT but was trained
  partly on images with non-commercial terms. Whether that reaches the weights
  is unsettled. Its authors ship it as MIT.
- **Accuracy is not measured.** The spike was judged by eye on one library,
  against the 685-species catalogue and with no table of where species are
  recorded. The measured accuracy piece closes this.
- **Phone memory.** Measured on a Mac and on an iPhone 17 Pro Max
  ([findings](../findings/2026-11-17-marine-life-phone-memory.md)). On the
  iPhone, Core ML runs both models on the Neural Engine and iOS counts
  their memory against the app's limit: 634 to 718 MiB, against a limit
  of 3,376 MiB there. With a 50 MP photo open, identification's highest
  point was 2.4 GiB, leaving 0.9 GiB, and the app's own media handling
  peaked higher than identification did. On the Mac harness a pack
  carrying both detectors peaks at 0.41 GB
  ([two detectors](../findings/2026-11-17-marine-life-measured-accuracy.md#two-detectors-in-one-pack));
  that pack was not run on the iPhone. A 6 GB iPhone, whose limit may be
  lower, is still unmeasured, so at launch iPhone and iPad need 8 GB
  (`minimumMemoryBytes`, 6.5 GiB as the device reports it, in
  `MemoryReading.swift`); the floor comes down once the media memory fix
  lands and a 6 GB phone is measured
  ([release gate](2026-11-18-marine-life-release-gate-design.md)).
- **Speed off Apple hardware.** On the CPU path the detector alone took 100 ms
  on a fast laptop. Phones and older laptops will be several times slower.
- **Fish mostly.** The Community Fish Detector rarely boxes coral, crabs,
  octopus, snails or sea stars. Megalodon finds them far more often, and a
  pack carrying both finds something in at least 77% of held-out photos in
  every group measured
  ([findings](../findings/2026-11-17-marine-life-measured-accuracy.md)).
  Turtles and marine mammals were not measured.

## Training later

Out of scope here, recorded so the storage design leaves room for it.

- Every identification a diver accepts, corrects or rejects, with its crop, is
  a labelled example. The stored identifications are a training set.
- The cheapest useful step is fine-tuning the detector to stop boxing divers
  and hands: a few thousand corrected boxes and hours of training.
- Next is a small naming layer trained on top of BioCLIP 2's embeddings:
  designed in [the naming layer design](2026-11-18-marine-life-naming-layer-design.md)
  (issue #4724).
- A small model of our own (approach 2) is worth attempting only if download
  size or phone speed turns out to block people.
- Nothing a diver labels leaves their device without a separate, explicit
  design for that.
