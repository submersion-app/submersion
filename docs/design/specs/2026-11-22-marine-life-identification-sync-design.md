# Marine life identification: sync the labels across devices

Release: v1.8.5. Parent program: #4668. Builds on
[piece 1 (photos)](2026-11-17-marine-life-identification-1-photos-design.md),
[piece 2 (video)](2026-11-17-marine-life-identification-2-video-design.md)
and [piece 4 (find species, review)](2026-11-18-marine-life-identification-4-auto-apply-design.md).

Decisions are marked **(decided)** when the maintainer made them and
**(proposed)** when they are the designer's call, open to correction.

## Why

A diver analyses a trip's photos and videos on a fast laptop. Their phone is
too old to run the models (below the 8 GB memory floor), or runs on a
platform where the models are off. Today the phone shows nothing: what the
laptop found never leaves the laptop. The phone should show the same name
pills, dots, video tracks and review page, even though it can never do the
analysis itself.

The results are deliberately device-local today
(`lib/core/database/tables/identification_tables.dart`: "Never synced (no
hlc column)"), for two reasons that this design answers:

1. What was found depends on the device's model pack. Answered by the trust
   rule below: a device keeps results made elsewhere unless its own models
   are newer.
2. The crops the rows refer to live only on the analysing device. Answered by
   syncing the crops of named identifications in their own table.

## Goals

- `media_identification_runs` and `media_identifications` sync with the
  logbook, on every sync backend (iCloud, Dropbox, Google Drive, nearby).
- The crops of named identifications sync with the logbook too, in a table of
  their own **(decided)**.
- A device shows synced results on every platform the viewer runs on,
  including Android while ONNX is off, the browser app and Linux
  **(decided)**. Showing results is split from running the analysis.
- A device that can analyse trusts results made elsewhere and analyses again
  only when its own models are newer, or when the diver asks (Analyse again)
  **(decided)**.
- Decisions made on any device (accept, dismiss, a name given from the frame)
  reach every device.
- Results already on disk when this ships (the maintainer's log: 70 runs,
  2,915 identifications, 1,095 named) reach the other devices without being
  analysed again.

## Non-goals

- Syncing embeddings. They stay in the device-local cache database.
- Syncing crops of unnamed identifications (fish that only ever show as
  dots). Those keep a fallback (below) **(decided: named only)**.
- Sending crops through the media store (S3 and the like). Rejected: only
  devices connected to a media store would get them, and it is the larger
  build **(decided)**.
- Continuing a partial video scan that another device started (see Video).
- Any change to how the models analyse or name.

## Anti-goals

- Two capable devices that re-analyse each other's photos on every opening
  (the ping-pong that syncing the rows as they are would cause, because
  `decideRefresh` treats missing crops as "analyse again").
- A diver's decision lost or reverted by a sync.
- Duplicate pills on one animal after two devices analysed the same photo.
- Synced rows deleted by the launch-time orphan sweep because their media row
  had not arrived yet.
- Re-sending a 12 KB picture every time a one-word decision changes.

## Approaches considered

How the crops travel:

- **A. A synced crops table in the logbook (chosen).** One row per named
  identification holding its JPEG. Travels on every sync backend; no media
  store needed. Costs logbook and backup size: about 13 MB on the
  maintainer's log (crops average 12 KB; 34 MB if every crop synced).
- **B. Through the media store.** Keeps the logbook small, but a phone that
  syncs only the logbook never sees crops, and it needs a new file type in
  the transfer queue plus the verify and delete sweeps. Rejected.
- **C. A BLOB column on the identification row.** Every accept or dismiss
  would re-send the picture with the decision. Dropped in favour of A.

What a capable device does with results made elsewhere:

- **Trust them (chosen).** Shows what arrived; analyses again only when its
  own models are newer or on request. No battery cost, no fight between
  devices.
- **Redo them.** Every device ends with its own crops, at the cost of
  analysing everything twice and swapping pills under the diver. Rejected.

## Design

### 1. The two tables join sync

Both join as **clock-guarded entities** with their own `hlc` column, the way
`mediaSpecies` and `mediaPeople` did (template: commit `487f8048fd6`, which
gave an existing table its clock late; full new-entity templates
`2d6efe8cbdf` and `02cb3f69a2c`). Clock-guarded fits: neither table has an
`updatedAt`, the rows are machine output plus a decision, and a newer copy
simply replaces an older one with no conflict cards.

Entity types **(proposed)**: `mediaIdentificationRuns` (pk `media_id`) and
`mediaIdentifications` (pk `id`). Registration covers every registry the
template touches: `hlcTargets`, `_hlcBackfillTargets`, `SyncData` field and
JSON, `_baseTables`, `clockGuardedEntities`, every serializer arm,
`mergeOrder` (after `media` and `mediaSpecies`), `entityHasUpdatedAt`
(false), `parentRefs` (`mediaId` to `media`, not nullable), `syncRecordId`
(runs return `mediaId`), `ConflictReferenceResolver`
(`decidedSpeciesId` and `claimedSpeciesId` to species), the conflict field
catalogue with l10n labels, and the guard tests that enumerate these.

Known wrinkles found in recon, for the builder:

- Runs have no `id` column. `_backfillTable` selects `id` and would fail
  silently ("HLC backfill skipped"); generalise it to the target's pk. Base
  paging (`_pageBlobTableByBytes`, `_pageBaseTableById`) orders by `id`, so
  runs use `table: null, full: () => _exportX(null)` as `diveSafetyReviews`
  does. Identifications have `id` and can page by bytes.
- BLOB columns (`scannedRanges`, `trackPath`) pass `_syncBlobSerializer`
  explicitly at export, fetch, upsert and base.
- Columns a write can set back to null (`decidedSpeciesId`, `decidedAt`,
  `claimedSpeciesId`, `scannedRanges`) go in `clockGuardedClearTables` and
  `clockGuardedClearKeys`, or a clear never reaches a peer (precedent:
  `mediaSpecies` for #4727).
- `MediaIdentificationRepository` calls no `SyncRepository` method today.
  Every write (run store or replace, insert, decision, claim, rename) marks
  its rows pending in the same transaction, and every delete logs a
  deletion (tombstone).
- An undo that restores media (`media_row_restore.dart`) re-marks the
  identification rows and crop rows of that media pending, as it does for
  `mediaSpecies`, `mediaTags` and `mediaPeople`.

The change-log class stays `excluded` for both tables **(proposed)**: sync
does not need tracking, and the change log's revert of machine output is not
wanted.

### 2. Where a run came from, and which rows belong to it

New nullable columns **(proposed)**:

- `media_identification_runs.analysed_by`: the sync device id of the device
  that analysed or last renamed it.
- `media_identification_runs.run_id`: a fresh id minted when an analysis of
  the media starts (a photo analysis, or a video scan from the start). It does
  not move per video chunk, unlike `analysed_at`, which every chunk rewrites.
  A rename keeps it.
- `media_identifications.run_id`: the `run_id` of the run that produced or
  last carried the row.

A run is **made here** when `analysed_by` equals this device's id; otherwise
it is **made elsewhere**.

Runs made before this change have a null `analysed_by`; every one of them was
made on the device that holds it, since nothing synced. They are stamped with
this device's sync device id **before they are first published**: in the
same step that backfills their `hlc` (`_hlcBackfillTargets`), not in the
rung, because the sync device id may not exist yet when the rung runs. A
null never leaves the device. A database restored onto another device
carries the stamp of the device that made the runs, so the restored device
trusts them (named crops come with the restore; unnamed rows show only as
dots, which need no crop) **(proposed)**.

Rows on screen and in review are the run's own rows plus every decided or
claimed row. An undecided, unclaimed row whose `run_id` differs from its
run's `run_id` is a leftover of a run that lost a sync race (two devices
analysed the same photo before syncing): it is hidden at read time, and the
next write for that media on a device that analyses deletes it with a
tombstone. This keeps the anti-goal "no duplicate pills" without a merge
hook. Rows and runs made before this change get matching `run_id`s from the
rung (one id per media, written to the run and its rows).

Two devices that both accepted the same animal before syncing keep two
decided rows; the species tag is already de-duplicated by species on the
media. Rare, and harmless: accepted rows draw one filled pill per animal box,
so the two may overlap **(proposed: accept this)**.

### 3. The trust rule

`decideRefresh` and `decideVideoRefresh` gain the run's origin. For a run
**made here**, nothing changes. For a run **made elsewhere**:

- Missing crops and missing embeddings never trigger analysis.
- A different region cell never triggers anything: the other device named it
  with its own location.
- Analyse only when this device's **models** are newer than the run's: the
  installed pack's version is later than `run.packVersion` **and** its
  detector id (which includes the video tracker version) or classifier id
  differs from the run's **(proposed)**.
- A later pack with the same models (a naming-only update) leaves a run made
  elsewhere alone. Renaming needs the embeddings, which only the device that
  made the run holds; that device renames cheaply when it installs the pack,
  and the renamed rows sync. Analysing instead would make whichever device
  installs the pack first re-analyse the other's whole library, possibly a
  phone doing the laptop's work **(proposed)**.
- An older or equal pack here leaves the run alone.
- Analyse again from the labels menu always analyses, as today.

Pack versions compare by the manifest's ordering (the pack version string is
a date stamp, `2026.11.18.0356`); the builder uses the existing comparison if
there is one.

When a capable device does analyse a run made elsewhere, `carryDecisions`
works as today: decided rows are kept or carried to the matching fresh
detection, undecided rows are replaced. The run's `analysed_by` becomes this
device, and the fresh rows sync back.

The Find species run (piece 4) and its "all checked" card use the same rule,
through `Readiness.upToDate`.

Auto-apply (`onItemSettled`) runs only on the device that made the run
**(proposed)**: a receiving device never tags by itself what another device
found, so a confident match is applied once, by its analyser, and the tag
syncs.

### 3a. Decisions merge on their own (decided)

A diver's decision must never be reverted by a machine write that raced it
(the laptop renaming or rescanning while the phone accepts). Whole-row
newest-wins would let the laptop's later copy, carrying the old decision,
overwrite the accept. So `mediaIdentifications` gets a **decision-aware
merge**, built on the sync layer's existing **fact groups**
(`lib/core/services/sync/sync_fact_groups.dart`, which media already uses
for its upload and verification facts): a set of columns that merges
last-writer-wins under its own clock, independent of the row clock.

- A new fact group `identificationDecision` on `mediaIdentifications`, with
  its own clock column `decision_hlc`, holds `decision`,
  `decidedSpeciesId`, `decidedAt` and `claimedSpeciesId`.
- Every decision or claim write (accept, dismiss, undo, reopen, a name from
  the frame, its withdrawal) stamps that group clock. Machine writes
  (analysis, rename, a video chunk) stamp only the row clock.
- The merge already resolves each group by its own clock and writes it with
  explicit values (`writeFactGroup`), so a cleared decision or claim lands
  on the peer too, and a stale machine row that loses on the row clock can
  still carry a newer decision. The newer decision wins whichever device
  wrote the row last.
- A null group clock means "never decided under a clock"
  (`nullClockIsUnset: true`, as the list arrangements do): a row a peer
  renamed but never decided must not borrow its newer row clock and undo a
  decision made here. Rows from before this change existed on one device
  only, so nothing they hold is overridden by it.
- `carryDecisions` moving a decision onto a fresh row (new id) during a
  re-analysis stamps the group clock on the fresh row, so the carried
  decision syncs with it.

This replaces comparing decision times by wall clock, and with it the need
for a `claimed_at` column **(proposed: the builder found the fact group fits
exactly)**.

### 3b. The pack's naming bars travel with the run (decided)

The naming level (Eager by default) is computed from the installed pack's
manifest (`levelInForce`). With no pack, a device falls back to the stored
flags, which are the stricter Surer level, and would show fewer pills than
the laptop. So each run stores the naming bars of the pack that named it: a
new nullable `naming_bars` column holding the manifest's `minCropSide`,
`minOpenScore`, `suggestScore`, `suggestScoreNoLocation` and its measured
levels, as JSON **(proposed format)**.

- With a pack installed, the device applies its level as today.
- With none, it applies the diver's chosen level to each media's rows using
  that run's stored bars, so a labels-only phone shows the same pills and
  review rows as the device that analysed. A run with no stored bars (made
  before this change and not renamed since) falls back to the stored flags.
- Runs made before this change are filled in on the analysing device: the
  next time that device reads its installed pack, it writes the bars onto
  its own runs of that pack version, which then sync.

### 4. Crops of named identifications sync

New synced table `media_identification_crops` **(proposed name)**:
`id` (pk, the identification's id, so the sync pagers that key by `id` stream crops by size), `media_id`, `jpeg` (BLOB), `hlc`. Clock-guarded,
parent `media`, no FK to media (same undo reasoning as the other two
tables), no FK to the identification (rows may arrive in either order).

**Named** means: `specific`, or `suggestable`, or decided, or claimed. That
is every row a review list or a name pill can show.

- Named crops live in the table only; unnamed crops stay as files in
  `IdentificationCropStore` **(proposed)**. `IdentificationCropStore` fronts
  both: `fileFor` / the crop widget read the file when there is one, else the
  table's bytes. No crop is stored twice.
- When analysis or naming makes a row named, its crop moves into the table
  (written, then the file deleted); when a row is deleted, its crop row is
  deleted with a tombstone. A row that stops being named (a later pack drops
  it below the bars) keeps its crop row: harmless, and avoids churn.
- `_cropsPresent` counts a table crop as present.
- **Backfill:** a one-time step after the upgrade moves every named crop file
  already on the device into the table, marked pending, so the maintainer's
  existing results sync with their crops without analysing again. It runs in
  the background after launch, in batches, and is safe to repeat.

Every place a crop is drawn (the suggestion row, its enlarged view, and the
review row) shows a named identification, whose crop now syncs. An unnamed
one only ever shows as a dot, and no screen draws its crop, so the outlined
thumbnail fallback proposed earlier would never be seen and is not built
**(builder's finding)**. A named row whose crop has not arrived yet shows
the existing placeholder until it does.

### 5. Showing results is split from analysing

Today `marineLifeIdEnabled` means both "this build ships the feature" and
"this platform runs the models" (`visionEngineRuns`). Split it
**(decided: everywhere the viewer runs)**:

- **Labels shown** (new): the build define, on every platform. Gates the
  label layers over photos and videos, the labels menu's modes, the species
  review page, the suggestion section on the media detail, and accepting,
  dismissing and naming from the frame.
- **Analysis runs** (today's `marineLifeIdEnabled`): additionally needs the
  engine on this platform. Gates the identification trigger, Analyse and
  Analyse again in the labels menu, Find species on a dive, the model pack
  page and download prompt, and auto-apply.

On a device where labels show but analysis does not run, the labels menu
lists only the modes, and a photo with no results shows nothing (no
"analyse" prompt). With results from another device and no model here,
its status line gives what was found and offers nothing more (a new
`foundNoModel` state). An Apple device below the memory floor keeps today's
behaviour: the feature is on, analysis reports `deviceNotEligible`.

Video labels need the video player: Linux has none, so on Linux only photo
labels show. The browser app shows photo and video labels where its viewer
plays the video.

The builder audits every read of `marineLifeIdEnabled` and assigns it to one
of the two flags by the lists above; anything not listed defaults to
"analysis runs".

### 6. Video

A video's run and tracks sync like a photo's: tracks carry their packed
`trackPath`, the run its `scannedRanges`. A partially scanned video made
elsewhere shows what was scanned (the scrub bar tint follows
`scannedRanges`). A capable device does not continue that scan
**(proposed)**: continuing needs the other device's embeddings to name tracks
joined across the seam. It continues only after Analyse again, which scans it
from the start on this device. The analysing device carries on its own
partial scans as today, and each chunk's rows sync as they are written.

### 7. Deletes and the orphan sweep

- A media delete that is purged (not undoable) deletes the media's runs,
  identifications and crop rows with tombstones, so peers drop them too.
- `IdentificationCleanup.sweepOrphans` only purges media ids whose media row
  is known deleted (a `media` tombstone in the deletion log), never rows
  whose media simply has not arrived yet **(proposed)**. Rows waiting for
  their media stay; the label layers never show them without the media.
- **Clear all identifications** (settings) now clears them on every device,
  with tombstones **(proposed)**; its confirmation text says so. The
  alternative (clear on this device only) would come back on the next sync.

### 8. Schema and older devices

One rung **(proposed: v381)**: `hlc`, `analysed_by`, `run_id` and
`naming_bars` on runs; `hlc`, `run_id` and `decision_hlc` on identifications
(with `run_id` filled for existing rows, section 2); and the new crops
table. Each gets a backstop in `before_open_table_backstops.dart`.

**The compatibility floor rises to 381 (decided).** Without it, a device on
an older version reads past the changesets that carry the existing results
and never gets them after it updates (nothing triggers a full resync in
normal use), which is exactly the maintainer's case: the laptop updates
first, the phone later. With the floor at 381, a device below it is held
(its cursor stays put) until it updates, then reads everything, labels
included. The cost, accepted: a device that delays updating stops syncing
until it does. The floor comment in `database.dart` records why.

Rows already on disk get stamped (and their runs' `analysed_by` filled) by
`_hlcBackfillTargets` at the next sync and publish then; named crop files
arrive through the backfill in section 4.

## Testing

TDD throughout. At least:

- Registration and guard tests for the three entities (hlc targets, parent
  refs, clock-guard set, base parity, serializer batch coverage, conflict
  catalogue coverage).
- Round trip: runs, identifications (with `trackPath`, `scannedRanges`) and
  crops survive export, apply and a base adopt; a clear of
  `decidedSpeciesId` and `claimedSpeciesId` reaches the peer.
- Trust rule: a run made elsewhere with missing crops and embeddings is left
  alone; an older pack here leaves it; a newer pack analyses; a run made here
  behaves exactly as before (existing `decideRefresh` tests unchanged).
- Sync race: two runs for one media; the losing run's undecided rows are
  hidden and later tombstoned; decided rows survive. A video scanned in
  several chunks shows every track (one `run_id` across chunks).
- Decision merge: an accept on one side and a later machine rewrite on the
  other converge to the accept on both; a later undo beats an earlier
  accept; a claim races the same way; a cleared claim reaches the peer.
- Naming bars: a device with no pack shows the Eager pills from the run's
  stored bars, matching the analysing device; a run without bars falls back
  to the stored flags.
- `analysed_by`: pre-existing runs are stamped with this device's id before
  their first publish and never leave the device null.
- Floor: the schema floor is 381 and a peer below it is held.
- Crops: named crops move to the table, the store reads from either, the
  backfill moves existing files and is repeatable, deletes tombstone.
- Orphan sweep keeps rows whose media has not arrived, purges tombstoned
  media.
- Flag split: labels and review show with analysis off; trigger, Analyse and
  pack page hidden.
- Migration test for the rung.

## Left to the builder

- Entity type and table names, if a better convention exists.
- How the read path filters leftover rows (query or Dart).
- Batch size and scheduling of the crop backfill.
- Exact pack version comparison helper.
- Where in the labels menu and review page the analysis-only items are hidden.
