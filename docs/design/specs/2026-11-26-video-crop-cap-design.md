# Cap identification crops per species on a video

Date: 2026-11-26. Status: approved design, built for issue #5032
(plan: `docs/design/plans/2026-11-26-video-crop-cap.md`).

## Why

Every animal the on-device model follows through a video keeps its own crop,
a JPEG of at most 320 px (about 18.6 KB). A school of fish produces dozens of
tracks per species, each with a crop. Named crops sync to every device in
`media_identification_crops` (issue #4876); unnamed ones stay files on the
device that analysed the video.

Measured on Eric's production log (2026-11-26, a read-only copy):

- Synced crops: 2,609 rows, 48.4 MB of the 78.4 MB log (62%). 2,596 of them
  are video tracks; photos hold 0.2 MB.
- Local crop files on the analysing Mac: about 3,166 files, 47 MB.
- One 89 s video has 404 tracks (118 named). Brown chromis alone has 329
  synced crops over 17 videos; the largest single (video, species) group is
  82 tracks.

Eric wants the growth fixed for all four costs it causes: sync time, cloud
quota, phone storage and backup size. So both the synced crops and the local
files are in scope.

## What the crops are for

Eric uses a species' crops on a video to:

1. Identify the animal: a few clear crops are enough.
2. Find a shot he remembers, and then watch the video from that point.

Video playback does not use crops. The boxes, dots and pills over a playing
video come from the identification rows (`track_path`, box columns, stored
naming flags) through `videoTracksProvider`. Tracking across a video happens
during the scan from boxes and embeddings; the crop is written after.

## Goals

- Keep the clearest crops of each species on a video: at most 3 synced and 3
  local files, plus the tracks the diver named themself, for new scans and
  for what is already stored.
- Let the diver jump from the crop sheet to every moment the species was seen
  in the video, including tracks whose crop was dropped.
- Leave identification rows, decisions, playback labels and track boxes
  exactly as they are.

## Non-goals

- Photos. They stop at 8 boxes per image (`maxBoxes: 8`) and hold 0.2 MB of
  crops. Photos are left alone.
- Regenerating a dropped crop from the video on request (approach B below).
  A possible later upgrade, not part of this work.
- A setting for the cap. It is a fixed 3.
- Changing the crop size, JPEG quality or the Species pages from #5030.

## Anti-goals

- A video analysed again because a crop the cap dropped is "missing". The
  readiness check in `media_identification_readiness.dart`
  (`_cropsPresent`) re-analyses a media item when a named undecided
  identification has no crop; it must not do so for crops the cap dropped.
  This would cost far more than the crops it saves.
- Two devices deleting different crop sets so that a group ends up with fewer
  than 3 crops while it has more tracks than that.
- Touching identification rows or their tombstones. Only crops go.

## Approaches considered

- **A. Keep the best 3 and list every moment (chosen).** For each video and
  species keep the crops of the 3 largest boxes, plus every track the diver
  named themself; drop the rest, synced and files. The crop sheet lists
  every moment as time chips that jump the video there. Saves about 40% of
  the synced crops on Eric's log (48 MB to about 29 MB) and a similar share
  of the files. Reuses the existing seek-to-moment pattern.
- **B. Keep 1 and cut the others on request.** Keep only the best crop, and
  cut any other track's crop from the video at view time with the engine's
  existing `cropAndEmbed` for a moment, into a cache. Saves the most (to
  about 19 MB) but only works where the pack is installed and the video
  file is reachable, so the web, phones below the 8 GB floor and devices
  without the video show times only. More platform work.
- **C. Keep 3 spread across the video.** Coverage instead of clarity. Since
  Eric jumps to the video by time anyway, this gives up the clearest views
  for coverage the time chips already provide.

Eric picked A.

## Design (as decided)

### Which crops a video keeps

**Groups.** For each video, group its tracks under one key, so that an
accepted track and an undecided track of the same fish share a group. The key
is the GBIF key of the track's top candidate, which is also what a species
tag matches when it accepts tracks (`candidateMatches`). The one exception is
an accepted track whose top candidate does not match its decided species (the
diver chose another species): it groups under its decided species id. (My
call, from the builder check.)

**Two caps per group, following the synced-versus-file line.** "Named" here
means `isNamed` (specific, suggestable or said by the diver), the crops that
sync. Within each group:

- Named tracks keep at most 3 synced crops.
- Unnamed tracks keep at most 3 file crops (Eric chose to keep 3 per guess
  over keeping none, so a later pack that names one can still show its
  picture). On Eric's log this keeps 3,117 of 3,753 unnamed crops, about
  7 MB saved; the cap is there for the schools that do produce dozens.
- Claimed tracks (`claimed_species_id` set: the diver gave the species with
  a dot or a pill) always keep their crop and do not count toward the 3.
- So a group holds at most 3 synced crops, 3 file crops and its claimed
  tracks. Every other track's crop is deleted. Its row stays.

**Ranking within the named cap.** Tracks the screens can show come first:
accepted tracks, then undecided suggestable ones (which a species tag will
accept), then the rest (specific only, and rejected tracks). Within each
tier, the largest box pixel area (`box_pixel_width * box_pixel_height`)
first, with a total order for ties (detector score, then id) so every
device ranks the same rows the same way. This keeps the 3 slots on tracks
the crop sheet and suggestions will list, even though tags are accepted
after the cap first runs. (My call, from the builder check.) Unnamed tracks
rank by box area alone.

Rejected tracks are not protected. (My call.)

### When the cap applies

- **New scans:** at the end of each video scan chunk, after its rows and
  crops are written (`video_identification_scan.dart`, where `_crops.write`
  runs). Later chunks add tracks, so the cap runs after each one.
- **Existing crops (Eric chose to trim automatically):** a pass at launch,
  next to the existing named-crop backfill and orphan sweep. It trims every
  video already stored down to its kept set. It must be idempotent and cheap
  once done (for example, only videos with more than 3 crops in a group, or
  a stored marker of the last trim).
- Trimming deletes synced crops with tombstones (`deleteIds` with
  `publish: true`), so every device drops them, and deletes the local files.

### Which device trims

Only the device that analysed a video (`run.madeOn(me)`, as
`NamedCropBackfill` already checks) trims that video's synced crops and
publishes the tombstones. Other devices drop them when the tombstones arrive.
Each device removes its own crop files for its own videos. This keeps two
devices with different rows mid-sync from each deleting a different set.
(My call, agreed by Eric.)

A run with no `analysed_by` exists only on the device that made it (it is
stamped with that device's id before it first leaves), so `madeOn` treating
null as "made here" is correct for trimming. A video whose analysing device
is retired or restored under a new sync id is never trimmed and keeps its
crops; there is no takeover rule. (My call. Eric's log has three analysing
devices: 147, 30 and 3 runs.)

A crop deleted by the cap cannot be brought back, except by analysing the
video again (for example a future pack with a new tracker), which applies
the cap again.

### What the screens show

- **Crop sheet on a video (#5026, `species_crop_sheet.dart`):** the sheet's
  tracks stay those `cropsOfSpecies` lists today: the tracks accepted as the
  tag's species. It shows those that still have a crop, large plus the
  thumbnail strip as today. If none of them has a crop, it shows the largest
  kept crop of the same group instead, so the sheet still opens. The count
  line says how many of the sheet's tracks there are in all, for example
  "3 best of 82 sightings" (new string, every locale).
- Below it, a **"Seen at" row of time chips** (Eric chose chips over a
  timeline bar). One chip per stretch of the video where the species was
  seen, built from all of the sheet's tracks (`start_ms`, `end_ms`), whether
  or not each kept a crop. Rejected and undecided tracks are left out, so no
  chip jumps to a moment the diver said was something else. (My call, from
  the builder check.) Overlapping tracks merge into one
  stretch; a stretch is shown as "0:04 to 0:31", or a single time when it is
  under a second. On Eric's log a (video, species) has a median of 1
  stretch, 90% have 3 or fewer, and the most is 15 with no merging gap.
- Tapping a chip closes the sheet and pauses the video at the start of that
  stretch, the same way a video face tag's chip does (`_showMoment` in
  `media_viewer_actions.dart`, issue #1745). A video that cannot play here
  does nothing on tap, as there.
- Photos get no time chips.
- **Fallback:** a screen that asks for a crop the cap dropped (a suggestion's
  highest-scoring track, a Species review row's largest box, or a track
  renamed after the trim) uses the largest kept crop of the same species on
  that video instead of a placeholder. (My call.)

## Constraints

- Sync rules for crops (`identification_crop_repository.dart`,
  `identification_sync_marks.dart`): crops have no reference to media or
  rows, and arrive in either order. Deletes that should reach peers go
  through `IdentificationSyncMarks.deleted(cropIds:)`.
- The crops folder is shared by every logbook opened on the device; only
  this logbook's videos are trimmed (as `_sweepDeletedLeftovers` already
  restricts itself).
- A browser keeps no files and never analyses: it never trims.
- A launch pass and a running scan of the same video can overlap; the trim
  must not delete a crop that a concurrent write just made part of the kept
  set.
- Playback, track labels, rejecting a track and the Species pages keep
  working with dropped crops; none of them reads a crop to work.
- Every user-visible string goes through l10n, in every locale.
- Files stay under 800 lines; `video_identification_scan.dart` (768) and
  `media_identification_service.dart` (770) are near the cap, so the ranking
  and trimming belong in their own files.

## Left to the builder

- How readiness tells a dropped crop from a missing one. The rule must keep
  re-analysing when a restore onto a new device lost every crop, and must not
  re-analyse for crops the cap dropped.
- Whether the launch pass is a marker-gated one-time run or an idempotent
  sweep each launch, and its batching.
- How the crop sheet reaches the video controller (for example the sheet
  returns the chosen time and the viewer seeks).
- Merging gap for stretches (0 s or a small gap such as 2 s), and the exact
  chip wording, within the layout above.
- Test fixtures: a video group with many tracks, a group with exactly 3, a
  claimed track outside the top 3, a rename after a trim, a peer applying the
  tombstones, and the readiness case.

## As built

- Readiness: a group of named tracks holding an undecided one needs a crop
  on at least one of its tracks; a video whose named tracks have none is
  analysed again.
- The launch step trims every media holding more than 3 crops each launch;
  a trimmed video costs one read of its rows after that.
- Stretches merge tracks that overlap or start within 1 s of the last
  one's end; a stretch under 1 s shows one time.
- The crop sheet hands the tapped time back to the viewer, which pauses
  the video on it as a face tag's chip does.
