# Marine life identification, piece 2: video on Apple devices

Program overview, with the decisions that apply to every piece:
[2026-11-17-marine-life-identification-program-design.md](2026-11-17-marine-life-identification-program-design.md).
The first piece, which this one builds on:
[2026-11-17-marine-life-identification-1-photos-design.md](2026-11-17-marine-life-identification-1-photos-design.md).
Read both first. This document does not repeat their reasoning.

Decisions are marked **(decided)** when the maintainer made them and
**(proposed)** when they are the designer's call, open to correction.

Target release: v1.8.5, behind the `marineLifeIdEnabled` flag **(decided)**.
One pull request.

## What this piece delivers

On an iPhone, iPad or Mac with the model pack installed:

1. Opening a video in the media viewer makes the app scan it for fish, once,
   in the background, while the video plays normally.
2. During playback, each fish the app is confident about carries a name pill
   joined by a thin line to a dot on the animal, following it as it swims.
3. Paused, the app also shows a plain dot on each animal it found but could
   not name. Tapping a dot picks its species.
4. The video's suggestions appear in the species chip row and the species
   sheet, as they do for photos.
5. Once the diver has decided, the label shows the decision: a fish they
   tagged carries their species, and a dismissed fish shows nothing.

## Why

The program's "Why" applies. Video is where most fish are: the spike found
fish in 55% of sampled frames. It is also where naming is hardest, because a
diver cannot pause on every fish and look it up. A labelled playback turns a
clip into something the diver can learn from, and each tag they make while
watching becomes a sighting on the dive.

## Goals

- Scan a linked video on the device, with no network use, with the scan's
  cost hidden behind normal playback.
- Label confidently named fish during playback in the look the program
  decided: pill, thin line, dot. No box outlines, nothing reading
  "unidentified".
- Let the diver name the fish the app could not, from the paused frame.
- Store what was found per video in a form Guided Media Tagging can build on:
  which animal, when, where in the frame over time, the candidates, and the
  diver's decision.
- Reuse piece 1's naming rules, pack, crops, embeddings, cleanup and
  decisions, changing them only where video requires it.

## Non-goals

- Live naming while a video plays without a scan first (piece 5).
- Android, Windows and Linux (piece 3). The web build compiles and the
  feature is absent.
- Scanning videos the diver has not opened, or continuing a scan after they
  leave the video.
- Drawing anything over photos. Photos are unchanged.
- Recording a moment or position on a species tag. Tags stay tags: accepting
  a fish tags the whole video, exactly as picking the species by hand does.
- Counting animals. A track is evidence a species was seen, not a census.
- Measuring accuracy or changing the naming bars (the measured accuracy
  piece, in progress in parallel).
- Publishing a pack.

## Anti-goals

- A video littered with dots on divers' hands, fins and bubbles.
- Labels that lag or jump so badly they point at the wrong fish.
- A scan that makes playback stutter, heats a phone for minutes after the
  diver has moved on, or gets the app killed for memory.
- A tag on one fish silently labelling dozens of other fish in the video.

## Constraints

- iOS 15 and macOS 12, as the app. Core ML through the existing
  `submersion_vision` plugin.
- Videos are links. The app plays a file it resolves at viewing time; for a
  Photos library video that is an exported copy, and producing it may have
  downloaded the video from iCloud. The scan must start no download the
  player did not already start.
- iOS does not allow GPU work from an app in the background.
- The same model pack and naming bars as photos. The bars are provisional
  until the measured accuracy piece sets them.
- A parallel session is building the measured accuracy piece and may change
  the naming bars, `tool/species_pack/`, and how the Swift pipeline fits a
  crop for embedding. This piece reuses that crop and embedding code as it
  is and does not edit it.

## Approaches

Three ways of building the scan were weighed.

1. **Two passes, tracking in Dart (chosen).** Swift decodes the video in
   order and runs only the detector, returning boxes and times. Dart links
   boxes into tracks, chooses each track's best moments, and asks Swift to
   crop and embed just those. Dart names each track. Two new native calls
   and some extra seeking in the second pass, but every rule that decides
   what the diver sees is pure Dart with tests, and piece 3's engine reuses
   it unchanged.
2. **One native pass.** Swift decodes, detects, tracks, chooses crops and
   embeds, returning finished tracks. Fastest, but the tracking rules live in
   Swift, must be rewritten for piece 3, and can only be tested by running
   the app against real models.
3. **Reuse frame extraction.** `submersion_transcoder`'s `extractFrames`
   returns JPEG frames to Dart, each sent through the photo `analyze`. No new
   native code, but every frame is encoded, copied and decoded again and
   every box in every frame is embedded: about ten times slower. Ruled out.

The maintainer chose approach 1 **(decided)**.

## What the diver sees

### While the scan runs

```
 ┌──────────────────────────────────────────┐
 │  ‹ toolbar ›                              │
 │                                           │
 │        ( Queen Parrotfish )               │
 │                 │                         │
 │                 ●                         │
 │                                           │
 │  [ Green Sea Turtle ] ( ◔ 40% )           │  ← chip row
 └──────────────────────────────────────────┘
```

- The scan starts once the video has been on screen for a short dwell, like
  a photo's analysis, under the same per-device toggle **(decided)**.
- The video plays, pauses and seeks normally throughout.
- Progress is a small ring with a percentage at the end of the species chip
  row, and in the species sheet's Suggested section, where photos show
  "Looking for fish..." today **(proposed)**. It disappears when the scan is
  done. It is shown only with the viewer's chrome.
- Labels appear for the part of the video already scanned. Scanning runs
  from where it last stopped towards the end, regardless of where the diver
  is watching **(proposed)**.
- Leaving the video (swiping to another item, closing the viewer, the app
  going to the background) stops the scan after the chunk in progress. What
  was scanned is kept, and the scan picks up from there the next time the
  video is opened **(decided)**.

### Playing

```
 ┌──────────────────────────────────────────┐
 │                                           │
 │    [ Blue Tang ]        ( Sergeant Major )│
 │          │                     │          │
 │          ●                     ●          │
 │                                           │
 └──────────────────────────────────────────┘
   [ ] filled: the diver tagged it
   ( ) outlined: the app's confident name
```

- A pill over a fish whose track is undecided and named at or above the
  pack's `confidentScore` **(decided: only confident names while playing)**.
  The pill is outlined and shows the name only; the score is in the chip and
  the crop view **(proposed)**.
- A filled pill over a fish whose track the diver accepted, showing the
  species they tagged **(decided)**. This includes fish named from a dot.
- Nothing over a dismissed fish, a fish below the confident bar, or a fish
  with no name.
- The dot sits on the centre of the animal's box; the pill sits above the
  box, joined by a thin vertical line. Near the top edge the pill goes below
  the box instead **(proposed)**.
- Labels follow the animal: positions are sampled four times a second and
  the dot moves smoothly between samples. A track that is not seen for more
  than half a second has no label in that gap.
- At most six labels at once, largest animals first, so a school does not
  bury the picture **(proposed)**.
- Labels are drawn whether or not the viewer's chrome is showing. They are
  hidden in people tag mode and while picking a white point.

### Paused

```
 ┌──────────────────────────────────────────┐
 │                                           │
 │    [ Blue Tang ]     ( Yellowtail         │
 │          │             Snapper )          │
 │          ●                 │        ●     │
 │                            ●              │
 │                 ●                         │
 └──────────────────────────────────────────┘
```

- Every undecided track the app could name (it passed the bars to be
  suggested, even below the confident bar) shows an outlined pill
  **(proposed)**. Accepted tracks show their filled pill.
- Every other undecided track at that moment shows a plain dot, but only
  when both hold **(decided: dots; proposed: the guard)**:
  - the track's open score is at least the pack's `minOpenScore`. This is
    the floor that keeps hands from being named; the spike scored hands at
    4% to 13% on it;
  - the track lasted at least one second.
- Tapping an outlined pill opens the larger crop view piece 1 built for the
  species sheet: the crop, up to three names each with Add, and Dismiss.
  Opened from a pill it also offers **Other species**, which opens the
  species picker, so a fish whose three names are all wrong can still be
  named from the frame **(proposed)**.
- Any name added from a pill's crop view, including through Other species,
  is recorded as that track's species, exactly as a pick from a dot is
  (a claim, section 5). The filled pill then lands on the fish the diver
  tapped, never on a neighbour that happens to share the name
  **(proposed)**.
- Tapping a filled pill does what tapping a tagged chip does.
- Tapping a dot opens the species picker. Picking a species tags the video
  with it and records that the picked species is this track's
  **(decided)**. The track then shows a filled pill.
- When the viewer does not allow edits (unified editing on and the video
  locked), pills and dots are shown and tapping them does nothing, as with
  suggested chips on a locked photo.
- Tapping anywhere else still plays and pauses the video.

### Chip row and species sheet

These work as for photos, with three differences for a video:

- A suggestion shows **no count**. One fish that swims out and back is two
  tracks, so a count would mislead **(proposed)**.
- The sheet's title reads "Species in this video".
- The settings toggle reads "Identify fish when I open a photo or video",
  and the settings page's introduction says photos and videos.

A suggestion's crop is the crop of its best track's best moment.

## How it works

```
viewer shows a video, after a dwell
   -> already fully scanned with this pack, nothing changed?  yes: stop
   -> name again from stored embeddings if only the pack or place changed
   -> resolve the file the player opened                     none: stop
   -> for each 10 s chunk from where the scan last stopped:
        engine pass 1 (native): decode in order, detector on
          4 frames a second -> boxes per sample
        tracker (Dart): extend open tracks, close finished ones
        for tracks closed in this chunk:
          choose up to 3 best moments
          engine pass 2 (native): seek, crop, embed each moment
          name the track (Dart, off the UI isolate)
        store the closed tracks, their crops and embeddings,
        and how far the scan got
        stop here if the video is no longer on screen
   -> at the end of the video, or when stopped: close the open tracks,
      name and store them
   -> reconcile decisions with the video's species tags
```

## The parts

### 1. Engine: two new calls

Added to `VisionEngine` and `ChannelVisionEngine`, and to the plugin's
channel. The plugin still knows nothing about species or tracks.

```dart
/// Runs the detector over [path] from [startMs] to [endMs], one frame
/// every [sampleIntervalMs]. Returns the video's display size and length,
/// and the boxes found at each sampled time.
Future<VideoDetections> detectVideo({
  required String path,
  required int startMs,
  required int endMs,
  required int sampleIntervalMs,
});

/// For each moment (a time and a normalised box), decodes that frame,
/// crops the box with the pack's padding, and returns a crop thumbnail,
/// the box's size in pixels, and the crop's embedding.
Future<List<VisionMomentCrop>> embedMoments({
  required String path,
  required List<VisionMoment> moments,
});
```

Native behaviour:

- **Pass 1** uses `AVAssetReader` over the first video track, starting at
  `startMs`, reading frames in order and keeping the one nearest each sample
  time. Frames are decoded at a reduced size: the detector's input is 640
  pixels, so nothing larger is needed **(proposed: at most 960 on the longer
  side)**. Each frame goes through the existing detector code: the same
  sigmoid, score threshold and box limit as photos.
- **Pass 2** uses `AVAssetImageGenerator` with zero tolerance to fetch each
  moment's frame at full resolution, capped at the same 4096 pixels as
  photos, then the existing crop, thumbnail and embedding code.
- **Orientation.** Both passes apply the video track's preferred transform,
  so boxes are normalised against the video as the player displays it. The
  reported display size is the transformed one, matching
  `VideoPlayerController.value.size`.
- **Memory.** One frame is held at a time in each pass, each in its own
  autorelease pool. The models stay loaded together, as for photos. The
  existing memory warning handler still frees them.
- **Background and heat.** A pass refuses to start (code `not_foreground`)
  when an iOS app is not active, and stops early with what it has when the
  app leaves the foreground mid-chunk. It also refuses when the device's
  thermal state is serious or critical (code `too_hot`) **(proposed)**.
- Everything runs on the plugin's existing serial queue, so a video chunk
  and a photo analysis never use the models at the same time.

**Where the Swift goes (proposed).** The two passes live in a new file,
`VideoScanner.swift`, which imports AVFoundation. `VisionPipeline.swift`
changes only as much as reuse needs: the padding, crop, thumbnail and
embedding steps that `analyze()` performs inline for each box move into one
internal method that both `analyze()` and pass 2 call, and the detector step
becomes callable on an already decoded frame. How a crop is fitted for
embedding stays exactly as it is.

The measured accuracy piece is editing `VisionPipeline.swift` at the same
time (it routes `embed()` through a new crop fit, moves `VisionError` into
that file, and compiles it into a command-line tool). Keeping AVFoundation
out of `VisionPipeline.swift` keeps that tool's build unchanged, and keeping
the edit there to one extraction keeps the eventual merge small. This piece
is built on main; whichever of the two merges second resolves the overlap.

### 2. Tracking (Dart, pure)

`lib/features/species_id/domain/services/video_tracker.dart`, no Flutter
imports.

- **Linking.** Each sample's boxes are matched to open tracks by
  overlap, greedily from the highest overlap down, with a threshold the
  builder sets (start from an intersection over union of 0.3).
- **Gaps.** A track missing from up to two consecutive samples (half a
  second) stays open; longer, and it is closed at its last sighting.
- **Flicker.** A track seen in only one sample is dropped.
- **Chunks.** The tracker's open tracks carry from one chunk to the next, so
  a fish crossing a chunk boundary is one track.
- **Best moments.** Up to three per track, ranked by detector score times box
  area, at least one second apart where the track is long enough.

The thresholds are constants beside the tracker, not pack values: they
describe the video, not the model **(proposed)**.

### 3. Naming a track

A track's embedding is the average of its best moments' embeddings,
normalised. It is named once with the existing `SpeciesNamer`, exactly as a
photo crop is, with the shorter side of its best moment's box for the size
floor. The track's crop is its best moment's crop. Its open score is the one
the namer reports for that embedding.

Two more facts are decided when a track (or a photo crop) is named, and
stored with it, so labels keep working after the model is removed
**(proposed)**:

- **confident:** suggestable, and its top score is at or above the pack's
  confident bar. The bar is `confidentScore` when candidates were limited by
  place. Without a usable place it is `confidentScoreNoLocation`, a field the
  measured accuracy piece adds to `NamingConfig` (it falls back to
  `confidentScore`, and a value above 1 means never). Until that piece
  merges, `confidentScore` is used for both.
- **specific:** its open score is at or above `minOpenScore`. This is the
  dot guard's first half.

Both are worked out by a small function beside the reconcile rules from the
namer's result and the pack's `NamingConfig`. `SpeciesNamer` itself is not
changed: the measured accuracy piece mirrors it in Python and checks the two
agree on shared vectors.

### 4. Storage

Main schema version **376**: columns added to piece 1's two tables, no new
table. Neither table syncs, and both stay that way.

**`media_identification_runs`** gains:

| Column | Meaning |
| --- | --- |
| `scanned_ms` | Video only: how far the scan has got, in milliseconds. Null for photos |
| `video_duration_ms` | Video only: the video's length as the engine read it. Null for photos |

A video's run is written after its first chunk and updated after each one.
The scan is complete when `scanned_ms` reaches `video_duration_ms`.
`image_width` and `image_height` hold the video's display size.

**`media_identifications`**: one row per track. It gains:

| Column | Meaning |
| --- | --- |
| `start_ms`, `end_ms` | Video only: when the track was first and last seen |
| `best_ms` | Video only: the moment whose box, crop and size the row's box columns hold |
| `track_path` | Video only: the box at each sample, packed binary |
| `claimed_species_id` | The species the diver gave this track from a dot or a pill, before the tag is written |
| `confident` | Whether it passed the confident bar when last named (section 3). False for rows from before 376 |
| `specific` | Whether its open score passed `minOpenScore` when last named. False for rows from before 376 |

- `track_path` packs each sample as a time offset from `start_ms` and four
  box values, as 16-bit integers: about 10 bytes a sample, 1.2 KB for a
  thirty-second track. The exact layout is the builder's, with a version
  byte first **(proposed)**.
- Nothing queries positions, which is why they are a column and not a
  table.
- The existing box columns hold the best moment's box, so everything piece 1
  does with a row (the crop, the size floor, the sheet) works on a track.
- Integer columns end in `_ms`, avoiding the endings the demo date-shift
  guard treats as dates.
- Embeddings and crops are stored per row exactly as for photos, in the
  device-local cache and under `species_id/crops/<media id>/`. The local
  cache schema does not change.

Registering the new columns follows `docs/developer/database.md`: the
migration rung in `lib/core/database/migrations/`, column backstops (not in
`before_open.dart`), and the generated SQL column notes. Main is at 375
today; if the measured accuracy piece or anything else takes 376 first, this
piece takes the next number when it merges main.

### 5. Decisions on a video

Piece 1's reconcile rule applies to a video's tracks, with two changes:

1. **A claim wins.** An undecided track with a `claimed_species_id` is
   accepted when that species is tagged on the video, before any other
   rule. A claim is the diver saying "this fish is that species", so it
   holds even when the species is not among the track's candidates.
2. **Only nameable tracks are matched by name** **(decided)**. On a video, the rule that a tag accepts "every
   identification whose best name it is, else the one ranking it highest"
   considers only tracks that passed the bars to be suggested. A photo is
   unchanged.

The second change exists because of the decision that a decision becomes
the label. A wide-angle clip can hold dozens of distant fish whose weak best
guess is "blue tang". Without the change, tagging blue tang once would label
all of them.

Dismissing a pill or a suggestion rejects the tracks it covers at once, in
both editing modes, as for photos.

Adding a suggestion from the chip row or the sheet (not from the frame)
writes no claim: it is a species for the whole video, and the rules above
decide which tracks it accepts.

**Naming a fish from the frame** (a dot's picker, or any Add in a pill's
crop view):

- **Unified editing off:** write the claim, then tag the video through
  `SpeciesTaggingService.tagPhoto` (which tags any media item). The reconcile
  that the tag change triggers accepts the track.
- **Unified editing on, video unlocked:** write the claim at once (it is the
  app's bookkeeping, like a dismissal) and hold the species in the sitting
  with `holdPickedSpecies`. Save writes the tag and the reconcile accepts the
  track. Cancel writes no tag; the track stays undecided with its claim,
  which the next naming from the frame replaces.

**Labels follow the sitting (proposed).** While a sitting holds tags that
are not yet saved, the labels show what Save would make of them: the label
layer runs the same reconcile in memory against the tags the viewer is
showing (stored, or held in the sitting) and draws from that. A fish named
from a dot shows its filled pill at once, and Cancel puts the dot back. The
chip row already filters suggestions by held tags the same way, so the two
agree. Nothing is written until the real reconcile after Save.

### 6. When a video is scanned or named again

On opening a video that has a run:

- **The scan is incomplete, and the detector and classifier are the
  installed pack's:** resume from `scanned_ms`.
- **A crop file is missing, or the detector or classifier id differs:** scan
  again from the start. Undecided tracks are replaced. A decided track is
  carried to a fresh track that overlaps it in time by at least half of the
  shorter one, with boxes overlapping by at least `sameAnimalOverlap` at
  their shared samples on average, so a dismissal or a claim survives
  **(proposed)**.
- **Only the pack version or the location cell differs:** name the
  undecided tracks again from their stored embeddings, with no engine and
  no file. A missing embedding means scanning again.
- **Nothing differs:** do nothing.

### 7. The service

Video scanning joins `MediaIdentificationService` rather than a second
service, so the two never compete for the engine and pack changes, logbook
switches and cleanup already wait for it **(proposed)**.

- A video request becomes a job that runs one chunk at a time. Between
  chunks it yields to newer requests and checks that it is still wanted.
- `cancelPending` for a video drops its remaining chunks; the one running
  finishes and is stored.
- Skips as for photos: the flag off, the toggle off, no pack, no engine.
- **The file.** The scan reads the file the player opened: the path from
  `videoPlaybackProvider`'s `FilePlayback`, opened per chunk through
  `videoFileAccessProvider` so a security-scoped bookmark is held only for
  the call. With no file, nothing is recorded and the video is tried again
  next time. The scan never starts a download.
- **Failures.** A chunk whose models were freed (`not_loaded`) loads them
  again once. Any other failure, or `not_foreground` or `too_hot`, ends this
  scan with what is stored; the next opening resumes.
- The busy and activity signals carry a progress fraction for a video, so
  the chip row and sheet can show the ring.
- The logbook generation is checked before every write, as today.

**Starting it.** `IdentificationTrigger` applies to videos as well as
photos, with the same dwell and the same "current item only" rule.

### 8. The label layer

A new widget in `lib/features/species_id/presentation/widgets/`, mounted by
the viewer over the current video next to `VideoPeopleLayer`, listening to
the player's controller:

- It places labels against the contain-fitted video rect with
  `containedImageRect` from `face_box_geometry.dart`, as the people layer
  does.
- At each position it interpolates each visible track's box between its two
  nearest samples.
- It decides each track's label from pure functions in the domain layer
  (pill outlined, pill filled, dot, or nothing, given playing or paused), so
  the rules are tested without widgets. Their inputs are the stored rows,
  with their `confident`, `specific` and claim fields, and the tags the
  viewer is showing; the decision they draw is the in-memory reconcile of
  section 5, not only the stored one.
- Only pills and dots take taps, and only while paused. Everything else
  passes through to the player.
- With the flag off it is not mounted.

The track rows for a video are read once per opening and re-read when the
repository's change signal ticks, as the suggestions provider does. Decoding
`track_path` happens off the build, when rows load.

### 9. Strings

New strings in all 11 languages:

- the video sheet title;
- the progress label for screen readers ("Looking for fish, 40%");
- a semantic label for a dot ("Unnamed fish, tap to name");
- the reworded toggle and introduction.

## Edge cases

- **The original is not on this device.** The player shows nothing to play,
  so nothing is scanned.
- **A portrait or rotated video.** Boxes follow the displayed orientation.
  Checked by hand with a portrait clip.
- **A very short video.** It is scanned in one chunk. Tracks under a second
  never show dots.
- **A very long video.** No limit. It resumes chunk by chunk across openings.
- **The diver seeks ahead of the scan.** Labels appear there once the scan
  reaches it.
- **The diver leaves mid-chunk.** That chunk finishes and is stored, then the
  scan stops.
- **The app goes to the background.** The scan stops; it resumes on the next
  opening.
- **A memory warning mid-scan.** The models reload once; a second failure
  ends this scan.
- **The pack is removed or replaced mid-scan.** The running chunk finishes,
  then the pack change runs, as for photos. A new detector or classifier
  means scanning again.
- **Another logbook is opened mid-scan.** The chunk's results are dropped.
- **The video gains or changes its dive or site.** Named again, from stored
  embeddings, on the next opening.
- **The diver tags a species by hand.** Matching tracks are accepted under
  the rules in section 5.
- **The diver removes a tag.** Accepted tracks of that species become
  rejected and lose their labels.
- **The same file linked twice.** Two media items, two scans. Not shared.
- **A Live Photo.** Treated as a photo; its motion part is not scanned.

## Testing

Tests are written first. Run only the test files written or changed, by
path.

- **Tracker:** linking, gaps, flicker, chunk boundaries, best moments.
  Inputs are built sample by sample, not hand-typed positions.
- **Track path codec:** round trip, version byte, rejection of a bad blob.
- **Naming a track:** averaging, normalising, the size floor from the best
  moment.
- **Label rules:** every combination of decision, suggestability, confidence,
  dot guard, and playing or paused; interpolation and gaps; the six-label
  cap.
- **Reconcile:** a claim wins; nameable-only matching on video; photos
  unchanged.
- **Refresh rules:** resume, scan again, name again, nothing; decisions
  carried across a scan again.
- **Storage:** the migration to 376 following
  `test/core/database/migration_v362_dive_deco_status_test.dart`; repository
  reads and writes of the new columns.
- **Service:** chunk order, resume, stop on leaving, yielding to a photo,
  each failure code, no file, logbook switch. Uses a fake `VisionEngine`.
- **Channel engine:** the two new calls' channel contract, with the mock
  handler restored in teardown.
- **Widgets:** the label layer playing and paused, taps on pills and dots in
  both editing modes and when locked, the progress ring, the sheet title,
  everything hidden with the flag off.

The Swift code is exercised by running the macOS app against a locally built
pack and a real dive video. No automated test runs the real models.

## Screenshots for the pull request

Light and dark where colours differ; phone and desktop widths where layout
differs. Taken through background window control on macOS.

- **Before and after:** a video in the viewer (chip row); the species sheet
  for a video; the settings page (reworded toggle).
- **After only:** a scan in progress; playback with pills; paused with pills
  and dots; the picker opened from a dot; a filled pill after tagging.

## Left to the builder

- Internal names, file layout and provider shapes.
- The tracker's thresholds, starting from the values above.
- The `track_path` layout.
- The pass 1 decode size, within the detector's needs.
- The pill's exact styling, within the program's decided look.
- How the progress fraction travels from the service to the chip row.
- Whether the thermal check is per chunk or per sample.

## For the maintainer to check

1. (Decided since: on a video, a tag matches by name only tracks the app
   could suggest. Photos keep piece 1's rule.)
2. Paused, every suggestable track shows an outlined pill, not only those
   above the confident bar; playing shows only confident ones.
3. A dot needs the track's open score at or above `minOpenScore` and a track
   of at least a second.
4. Video suggestions show no count.
5. The outlined pill shows the name only, no score.
6. At most six labels at once, largest first.
7. Progress is a ring at the end of the chip row and in the sheet.
8. The scan refuses to run in the background on iOS and on a hot device.
9. Claims and dismissals write at once, even under unified editing.
10. Video scanning lives in the existing service, one chunk at a time.
11. Pass 1 decodes at 960 pixels at most; pass 2 at full resolution, capped
    at 4096.
12. A name added from a pill's crop view is recorded against that fish (a
    claim), like a pick from a dot; adding from the chip row or sheet is not.
13. A pill's crop view gains Other species, so a fish with three wrong names
    can still be named from the frame.
14. Under unified editing, labels follow the sitting before Save, and Cancel
    reverts them.
15. Whether a track is confident, and whether it looks specific enough for a
    dot, is stored when it is named, so labels survive removing the model.
    Without a place, the confident bar is the measured accuracy piece's
    `confidentScoreNoLocation` once that merges.
16. The Swift video code goes in its own file; `VisionPipeline.swift` gets
    one small extraction, and this piece is built on main alongside the
    measured accuracy piece.

## Risks

- **Memory on 6 GB phones is still unmeasured.** The player, a decoder and
  670 MB of models share the app's limit. Pass 1's small frames keep the
  scan's own share low, but nothing has been tried on a phone.
- **Tracking is simple.** Overlap matching loses a fish that darts across
  the frame between samples, and may swap two fish that cross. A swap puts a
  label on the wrong fish for the rest of the track.
- **Sparse names on wide footage.** The spike named 3% of frames. Most videos
  will show dots, not pills, until the diver works through them.
- **The bars are provisional,** as for photos.
- **Rotation.** The player and the scan must agree on orientation; a
  mismatch draws every label in the wrong place. Checked by hand only.
- **Conflicts.** The measured accuracy piece may change the Swift crop code
  and the naming bars at the same time.
