# Combine Dives (Sequential Merge) — Design

**Issue:** [#449 — Ability to merge/combine dives](https://github.com/submersion-app/submersion/issues/449)
**Date:** 2026-07-02
**Status:** Approved

## Overview

Divers sometimes surface briefly mid-dive (surface swim between sites, a gear
check, a lost-buddy protocol). Many dive computers end the dive when the diver
surfaces and start a new one on re-descent, splitting what the diver considers
one dive into several log entries. This feature lets the user select two or
more non-time-overlapping dives and combine them into a single contiguous
dive. Time gaps between the source dives are represented as surface time
(0 depth) in the merged profile.

This is distinct from the existing same-dive consolidation feature
(`merge_dive_dialog.dart`, `DiveDataSources`), which folds a duplicate record
of the *same* dive in as an additional computer reading. Combining
*overlapping* dives from multiple computers into one entry that displays both
profiles is a planned follow-up feature; this design reserves UI space for it
but does not implement it.

## Goals

- Combine 2+ sequential (non-overlapping) dives into one contiguous dive.
- Represent inter-dive gaps as 0-depth surface time in the merged profile.
- Preserve as much data as possible from all source dives.
- Make the operation undoable from the confirmation snackbar.
- Propagate the merge correctly through sync (tombstones for sources, pending
  record for the merged dive).
- Share a single "Combine" entry point with the future overlapping-dives
  (multi-computer) combine feature.

## Non-goals

- Combining time-overlapping dives (multi-computer display) — separate task;
  this design only routes such selections to an explanatory panel.
- Auto-collapsing "the same physical tank continued across segments" into one
  tank entry — future refinement; tanks are kept as separate entries.
- Re-splitting a merged dive after the undo window has passed.
- Protecting against re-download re-importing later segments as new dives
  (see Known limitations).

## Decisions (user-confirmed)

| Decision | Choice |
|---|---|
| Fate of source dives | Deleted (sync tombstones logged), with snackbar Undo backed by a full-fidelity snapshot |
| Scalar metadata conflicts | First non-empty wins, in chronological order |
| Entry point | Dive list multi-select action bar ("Combine") |
| Stats vs surface gaps | Runtime spans surface-to-surface; averages exclude surface time |
| Overlapping selection (interim) | Explanatory panel; for 2 dives, point at the existing per-dive "Merge with another dive" action |
| Implementation approach | Pure merge builder + thin transactional service (Approach A) |

## UX flow

### Entry point

In the dive list's existing selection mode
(`lib/features/dive_log/presentation/widgets/dive_list_content.dart`,
selection app bar `_buildSelectionAppBar`), when 2 or more dives are selected,
a **Combine** action (merge icon) appears alongside Export / Bulk Edit /
Delete.

### Combine dialog

Tapping Combine opens `CombineDivesDialog`, which loads the selected dives in
full and classifies their time relationship using `effectiveEntryTime` and
`effectiveRuntime`:

- **Sequential** (every gap >= 0; touching dives count as sequential):
  shows a preview listing the dives in chronological order (dive number,
  entry time, duration), the computed surface gap between each consecutive
  pair, and the resulting merged dive (total runtime, max depth, combined
  bottom time). A note explains data handling: details are taken from the
  earliest dive, blanks filled from later dives; notes are combined; tanks,
  gear, buddies, tags, and sightings are all kept. Confirm button:
  **Combine into one dive**.
- **Overlapping** (any pair overlaps by any positive amount): an explanatory
  panel — these dives overlap in time, so they look like the same dive
  recorded by multiple computers; combining those into one entry with both
  profiles displayed is coming in a future release. When exactly 2 dives are
  selected, the panel points the user to the existing "Merge with another
  dive" action on the dive detail page. Close button only.

### Guardrails (checked before the preview renders)

- At least 2 dives selected.
- All dives belong to the same diver (`diverId`); otherwise show an error
  panel in the dialog.
- Any positive time overlap routes to the overlapping panel (there is no
  separate overlap "error").

### After confirm

The merge runs in one transaction. On success: selection mode exits, the list
refreshes (sources gone, merged dive present), the merged dive becomes the
list selection (the detail pane shows the combined result immediately), and
a snackbar shows "Combined N dives" with an **Undo** action
(`persist: false` + `showCloseIcon`, per the #406 snackbar convention).
Undo removes the merged dive, restores the sources, and clears the selection
if the merged dive was still selected. On failure: the transaction rolls
back, an error snackbar is shown, and nothing has changed.

## Merge semantics

### Timeline

- Sources are sorted by `effectiveEntryTime`.
- Merged `entryTime`/`dateTime` = first dive's; `exitTime` = last dive's
  effective exit.
- Each source segment's profile samples are copied with `timestamp`
  (seconds from dive start) shifted by the segment's offset from the merged
  entry time. Sample spacing within a segment is preserved exactly.

### Surface gaps

- Gap boundaries come from each segment's occupied span:
  `max(effectiveRuntime, last profile sample timestamp)`. Computers routinely
  keep sampling past the runtime they declare (surface bobbing before the
  log closes); trusting the declared runtime alone leaves an uncovered
  sample hole at the seam that chart smoothing renders as a swooping curve
  with overshoot loops. Profile samples that run into the next dive's entry
  classify the pair as overlapping.
- Each gap (>= 2 s) is filled with synthesized 0-depth samples at the source
  profile's native cadence (median inter-sample delta of the previous
  segment, falling back to the next segment's, then to 60 s), hugging both
  boundaries (start + 1 s and end - 1 s). The synthesized surface samples
  are indistinguishable from the computer's own rhythm, so charts render a
  genuinely flat surface line regardless of curve smoothing.
- A `DiveProfileEvents` row (`eventType: 'surface'`) is written at each gap
  boundary so the profile chart can annotate the surface interval.

### Stats (computed once at merge time, persisted on the merged dive)

| Field | Rule |
|---|---|
| `runtime` | Full span: last effective exit − first entry (includes gaps) |
| `bottomTime` | Sum of the sources' bottom times |
| `maxDepth` | Maximum across sources |
| `avgDepth` | Time-weighted mean over the segments' original samples only; the synthesized gap spans are excluded entirely (a real 0-depth sample recorded by the computer inside a segment still counts) |
| `waterTemp` / `airTemp` | First non-empty |
| `surfaceInterval` | First dive's (the interval before the whole dive) |
| `diveNumber` | First dive's number (renumbering remains a user action via existing tools) |

Because `avgDepth` and the other stats are persisted, the entity's
recompute-from-profile fallback helpers (`Dive.calculate*FromProfile`) are not
consulted for the merged dive, so the gap samples never skew SAC or averages.

### Scalar metadata

First non-empty wins, in chronological order: site, rating, visibility,
weather block, altitude, surface pressure, gradient factors / deco algorithm /
conservatism, CCR/SCR fields, computer model/serial/firmware, `computerId`,
`importSource`, `importId`, `importVersion`, and custom fields (per key).
Exceptions:

- `notes`: all non-empty notes concatenated with a separator line.
- `isFavorite`: true if any source was favorite.

### Child-data matrix

Every child table has an explicit rule; nothing relies on the `Dive` entity
round-trip (which only carries tanks, weights, custom fields, profile,
equipment, and dive types through `createDive`).

| Child | Rule |
|---|---|
| `DiveProfiles` | Concatenated, re-based; `computerId` and `isPrimary` preserved per row |
| `DiveTanks` | All kept; `tankOrder` re-sequenced chronologically; no auto-collapsing |
| `TankPressureProfiles` | Copied, re-based, re-pointed to the copied tank IDs |
| `GasSwitches` | Copied, re-based, tank references remapped to copied tank IDs |
| `DiveProfileEvents` | Copied, re-based; `tankId` text references remapped; plus synthesized `surface` events at gap boundaries |
| `DiveWeights` | First dive's set; if empty, the first source that has any (avoids double-counting) |
| `DiveEquipment` | Union, deduped by `equipmentId` |
| `DiveBuddies` | Union, deduped by `buddyId` |
| `DiveTags` | Union, deduped by `tagId` |
| `DiveDiveTypes` | Union, deduped by `diveTypeId` |
| `Sightings` | Union; same-`speciesId` rows merged (counts summed, notes joined) |
| `Media` | Re-pointed inside the transaction (`diveId` updated to the merged dive) before source deletion |
| `TideRecords` | First dive's |
| `DiveDataSources` | Carried over for provenance, re-pointed; all forced `isPrimary = false` so `reparse_service.applyParsedUpdate` can never rewrite the hand-built merged profile from one segment's raw data |

All junction/child rows receive fresh surrogate UUIDs on insert (never
re-pointed in place), per the #347 sync lesson.

## Architecture

All new code lives under `lib/features/dive_log/`.

### 1. `domain/services/dive_merge_builder.dart` (pure, no DB)

- `DiveMergeBuilder.classify(List<Dive> sources)` →
  `sequential | overlapping` (also validates count and same-diver).
- `DiveMergeBuilder.build(sources, {events, gasSwitches, tankPressures,
  sightings, buddies, tags, mediaIds, dataSources})` → `DiveMergeResult`:
  the merged `Dive` entity, every child row list (re-based timestamps,
  remapped tank IDs), and gap descriptors for the dialog preview.
- All merge-semantics rules above are implemented here as pure functions.
- The dialog preview renders from the same `build()` output that the service
  persists, so preview and result cannot drift apart.

### 2. `data/services/dive_merge_service.dart` (thin orchestrator)

Follows the `bulk_dive_edit_service.dart` pattern (snapshot → one
transaction → one sync notify).

- `apply()`:
  1. Load full source dives plus the children the entity does not carry.
  2. Capture a `DiveMergeSnapshot` — full-fidelity copy of the source dives,
     all child rows, and media `diveId` pointers.
  3. In one Drift transaction: insert the merged dive via the repository
     create path; explicitly insert the children `createDive` does not cover
     (sightings, buddies, tags, profile events, gas switches, tank pressure
     profiles, data sources); re-point media; delete sources via the
     tombstone-logging delete path.
  4. `markRecordPending` for the merged dive; deletion tombstones for the
     sources; one `SyncEventBus.notifyLocalChange()` at the end.
- `undo(snapshot)`: delete the merged dive (tombstone), re-insert the source
  dives with their original IDs and all children, restore media pointers,
  mark pending. Junction rows get fresh surrogate UUIDs.

### 3. `presentation/widgets/combine_dives_dialog.dart`

The dialog from the UX section (sequential preview / overlapping panel /
guardrail errors).

### 4. `dive_list_content.dart` + notifier wiring

Combine action in the selection app bar; snackbar + undo flow in the notifier
layer, mirroring the existing bulk-delete undo.

## Sync correctness

- Source deletions go through the existing tombstone-logging path
  (`deletion_log`, HLC-versioned), so remote devices delete them.
- The merged dive is marked pending and syncs as a new record.
- Undo's re-insert with original IDs is safe under the HLC scheme: the
  re-insert carries a newer HLC than the deletion tombstone, so remote
  devices resurrect the sources — the same mechanism the existing
  delete-undo relies on.

## Error handling

- Builder validation (overlap, fewer than 2 dives, mixed divers) happens
  before the dialog's confirm button exists; invalid states cannot reach the
  service.
- The service transaction is all-or-nothing: any exception rolls back, the
  snapshot is discarded, and the UI shows an error snackbar with no state
  change.
- Undo failure (e.g., app killed before undo is tapped) is acceptable: the
  merge itself is valid; undo is a convenience, not a journal.

## Known limitations

- Re-downloading from the dive computer can re-import the later segments as
  new dives: the merged dive's `importId` preserves only the first segment's
  identity. The carried-over `DiveDataSources` fingerprints mitigate this
  where import dedup consults them; full protection is out of scope.
- A merged dive cannot be re-split after the undo window passes.

## Testing

TDD throughout; the pure builder carries most of the coverage.

- **Builder unit tests** (no DB): overlap classification including
  touching-dives edge case; timestamp re-basing; gap sample synthesis;
  runtime / bottomTime / maxDepth / avgDepth-excluding-surface; first
  non-empty metadata; notes concatenation; favorite propagation; collection
  unions and dedup; sightings same-species merge; tank ID remapping in gas
  switches, pressure profiles, and events; weights first-set rule;
  `isPrimary = false` on carried-over data sources; mixed-diver and
  fewer-than-2 validation.
- **Service tests** (in-memory Drift DB): apply → merged row plus every
  child table populated, sources gone, tombstones present in `deletion_log`,
  media re-pointed; undo → full restoration including children the entity
  does not carry; failure injection mid-transaction → rollback leaves the
  database untouched.
- **Widget tests**: Combine action visibility (>= 2 selected); dialog
  sequential preview vs overlapping panel; confirm → snackbar with Undo;
  undo restores the list.
- **L10n**: all new strings translated into the 10 non-English locales and
  regenerated.

## Future work

- Overlapping-dives combine (multi-computer, both profiles displayed in one
  entry) — fills the reserved slot in `CombineDivesDialog`.
- Heuristic collapsing of "same physical tank continued across segments".
- Consider minimum water temperature across sources instead of
  first-non-empty.
