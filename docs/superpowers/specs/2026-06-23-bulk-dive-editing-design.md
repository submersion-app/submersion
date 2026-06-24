# Bulk Dive Editing — Design

- **Issue:** [#150 — Batch editing: multi-select dives for bulk field updates](https://github.com/submersion-app/submersion/issues/150)
- **Date:** 2026-06-23
- **Status:** Approved (design); ready for implementation planning
- **Branch:** `worktree-issue-150-bulk-dive-editing`

## Summary

Let a diver select multiple dives and apply edits to most fields at once. This is the
single highest-volume community feature request (4+ ScubaBoard reporters). The driving
workflows are post-import cleanup: stamping a dive center, buddy, gear, weight, or
tank/gas type onto a batch of freshly imported dives that all share context.

We reuse the existing dive edit form in a new **bulk mode** (the same way
`site_merge_page.dart` reuses `SiteEditPage`), gate every field behind a per-field
"change this" toggle so only enabled fields are written, and route the save through a
dedicated set-based write path that never touches per-dive child rows it shouldn't.

## Goals

- Bulk-edit a comprehensive set of dive fields (scalars, enums, FKs, and the multi-value
  collections), not just a curated few.
- Cover the issue's named fields explicitly: dive center, buddy, equipment, weight, and
  tank/gas type — plus trip, dive type, conditions, deco, dive computer, weather, and
  rebreather settings.
- Enhanced selection: long-press to enter (preserved), shift-click range selection, and
  date-range / block selection.
- Reversible: every bulk apply can be undone.
- Correct under cloud sync: each touched record is marked pending; undo propagates too.

## Non-goals

- Bulk-editing measured or identity data (dive number, date/times, durations, max/avg
  depth, profile samples, CNS/OTU, GPS, computer serial/firmware, import metadata). These
  are never sensible to set across many dives and are hidden in bulk mode.
- A separate "set dive center at trip level" propagation feature. Date-range selection +
  bulk set covers it: select the trip's date span, set one field, apply.
- A spreadsheet / inline-grid editor (considered and rejected in favor of reusing the
  edit form).

## Background — existing code this builds on

Bulk editing already exists in a limited form; this is an expansion of an existing seam.

- **Multi-select + current bulk sheet:**
  `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
  - Selection state: `_isSelectionMode`, `Set<String> _selectedIds`,
    `_enterSelectionMode` (L185), `_toggleSelection` (L203), `_selectAll` (L216),
    `_deselectAll` (L222).
  - Long-press is the existing entry to selection mode, wired on all tile types
    (L1417/1461/1491) and table rows (`onDiveLongPress`, L1305): when not in selection
    mode, `onLongPress` calls `_enterSelectionMode(dive.id)`.
  - Current "Bulk Edit" bottom sheet (`_showBulkEditSheet`, L428) offers only Change Trip
    / Add Tags / Remove Tags, backed by `bulkUpdateTrip` / `bulkAddTags` /
    `bulkRemoveTags`.
  - Selection toolbars: `_buildSelectionAppBar` (L1143, mobile), `_buildSelectionBar`
    (L1192, desktop split-pane).
- **Reuse-the-edit-form precedent (site merge):**
  `lib/features/dive_sites/presentation/pages/site_merge_page.dart` is a 15-line wrapper
  that calls `SiteEditPage(mergeSiteIds: [...])`; `site_edit_page.dart` branches on an
  `isMerging` flag. `site_repository_impl.dart` `mergeSites` (L331) does everything in one
  `_db.transaction`, captures a `MergeSnapshot` for undo before mutating, and
  `undoMerge` (L476) restores it.
- **Repository bulk template:**
  `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
  - `bulkUpdateTrip` (L3626) is the clean model: one `UPDATE dives ... WHERE id IN`, then
    `markRecordPending('dives', id)` per dive, then `SyncEventBus.notifyLocalChange()`.
  - `updateDive` (L888) is the per-dive path; it delete-orphans and re-inserts all child
    rows (tanks L1009, weights L1088, equipment L1122, custom fields L1151, tags L1185).
    **Bulk mode must not loop this** — it would needlessly churn every child row.
  - `bulkDeleteDives` (L1220) returns deleted dives and powers the existing 5s
    snackbar-undo.

## Approach — reuse the edit form in bulk mode (Approach B)

Open the existing edit page as `DiveEditPage(bulkDiveIds: selectedIds)` with an `isBulk`
getter, mirroring `SiteEditPage`'s merge mode. The "Bulk edit…" action in the selection
toolbar replaces today's limited bottom sheet.

**Decoupling rule (the most important correctness decision):** bulk mode shares the
*form widget* but swaps the *save handler*. A normal save fans out per-dive child-row
rewrites; across hundreds of dives that is catastrophic. So on save, bulk mode builds a
request object and hands it to a new `BulkDiveEditService` that uses set-based SQL — it
never calls `updateDive`.

Trade-off accepted: weaving `isBulk` branches into the 3,473-line edit form makes that
form carry bulk concerns and harder to restructure later. Mitigation: keep bulk-only
logic in small helpers (`BulkFieldGate`, the request builder, the service) rather than
smeared inline, and extract reusable leaf field-editors where practical so a future
restyle still propagates.

## Selection mechanics

Range selection needs an **anchor** — the dive a range extends from. Current code only
tracks a `Set<String>`; we add one field, `_anchorId` (or last-tapped index).

- **Long-press** (not in selection mode) → enter selection mode, select that dive, set it
  as the anchor. (Existing behavior, now also records the anchor.)
- **Plain tap** (in selection mode) → toggle that dive; it becomes the new anchor.
- **Shift-tap / shift-click** → select the contiguous span from anchor → tapped dive;
  anchor unchanged. Pointer+keyboard gesture, so it applies on desktop / web / table
  layouts.
- **Select by date range** → new action in the selection toolbar; opens a date-range
  picker and selects every dive whose date falls inside it. This is the cross-platform
  (incl. mobile, which has no shift key) path to range/block selection, and it satisfies
  the "set the dive center for a whole trip at once" use case.
- **Select all / Deselect all** → unchanged.
- Optional desktop bonus: in the split-pane view the `isMasterSelected` detail dive can
  act as an implicit anchor, so a shift-click can both enter selection mode and grab the
  range in one gesture.

## The bulk form

### Hidden in bulk mode (identity + measured)

Dive number, entry/exit date-times, bottom time, runtime, max/avg depth, profile, CNS/OTU,
GPS entry/exit, dive computer serial/firmware, import source/id/version.

### Gated scalar fields

Every shown field is wrapped in a **`BulkFieldGate`** — a leading toggle, off by default.
Only enabled fields are written. The toggle distinguishes "leave alone" from "set to
empty": enabling a field and clearing it clears that field on all selected dives.

Fields: dive center, trip, course, dive type, rating, favorite, water type, visibility,
current direction/strength, swell height, entry/exit method, altitude, surface pressure,
surface interval, gradient factor low/high, deco algorithm, deco conservatism, dive
computer model, weather (wind speed/direction, cloud cover, precipitation, humidity,
description), dive mode, and the rebreather cluster below.

### Notes — Set vs Append

Notes gets a small mode selector: **Set** (overwrite) or **Append** (concatenate a line).
Append is the common, non-destructive batch case ("add 'Cozumel 2026' to all").

### Dive mode cascade

`diveMode` (OC / CCR / SCR) controls a dependent rebreather cluster: setpoints (bottom /
high / deco), scrubber type/duration/remaining, diluent gas, loop O2 min/max/avg, loop
volume, SCR injection rate / addition ratio / orifice, assumed VO2.

- Setting mode = CCR/SCR reveals the rebreather fields, each as its own optional gate.
  Nothing is forced — you can stamp just the mode now and fill setpoints later.
- Setting mode = OC collapses the cluster; if any rebreather gate is enabled, the confirm
  step blocks the contradiction.
- **Decision (settled):** when mode is *not* being changed, the rebreather cluster stays
  available but collapsed, because the selection may already contain CCR dives whose
  setpoints the user wants to bulk-edit without re-stamping the mode.

### Collections — Add / Remove / Replace

Each multi-value field shows a mode selector, then drops in the same editor the normal
form uses. Available modes depend on whether rows are *owned* by the dive or *references*
to shared records:

| Collection  | Add | Remove | Replace | Notes |
|-------------|-----|--------|---------|-------|
| Tags        | yes | yes    | yes     | Add/Remove exist today; add Replace |
| Equipment   | yes | yes    | yes     | shared gear items (junction `DiveEquipment`) |
| Buddies     | yes | yes    | yes     | Add carries a role (`DiveBuddies.role`) |
| Tanks       | yes | —      | yes     | owned rows — no shared identity to remove |
| Weights     | yes | —      | yes     | owned rows |
| Marine life | yes | —      | yes     | owned sightings (per-dive count) |

- **Tank Add** reuses the existing tank editor: preset (`presetName`, e.g. `al80`),
  volume, working pressure, material, gas mix (O2/He), role. Start/end pressure stay
  blank — they are measured per dive; you stamp the *type*. Add honors an **"only dives
  that don't already have a tank"** checkbox (safe to re-run after a partial import).
- **Add** appends to each dive's existing list; fresh row UUID + `order` per dive.
- **Replace** swaps each dive's whole list for the configured set (see warning in Edge
  cases — destructive of tank pressure data).

### Confirm step

Before writing, a summary dialog: "Apply N changes to 12 dives?" listing the enabled
fields and any warnings (contradictions, destructive replace). High blast radius warrants
an explicit confirm.

## Persistence & sync — the write path

The form builds a **`BulkEditRequest`** = a partial `DivesCompanion` (scalars) + a notes
mode + a list of collection ops. A new **`BulkDiveEditService`** applies it.

### Scalars — one generic set-based method

New `DiveRepository.bulkUpdateFields(List<String> diveIds, DivesCompanion partial)`:

```dart
(_db.update(_db.dives)..where((d) => d.id.isIn(diveIds)))
    .write(partial.copyWith(updatedAt: Value(now)));   // single UPDATE
// then markRecordPending('dives', id, now) per id; one notifyLocalChange() at the end
```

Drift companions encode the per-field gate precisely: `Value.absent()` = "don't touch
this column"; `Value(null)` = "set NULL". So toggle-off → absent, toggle-on-empty →
`Value(null)`, toggle-on-value → `Value(x)`. One method therefore covers all ~40 scalar
fields; we do not write 40 field-specific methods.

### Notes append

A single `customUpdate`: `SET notes = COALESCE(notes,'') || ?` over the selected ids
(only when Append is chosen; Set goes through `bulkUpdateFields`).

### Collections — bulk methods, set-based, one transaction

- **DiveRepository** (owned/junction rows it already manages):
  `bulkReplaceTags`; `bulkAddEquipment` / `bulkRemoveEquipment` / `bulkReplaceEquipment`;
  `bulkAddWeights` / `bulkReplaceWeights`; `bulkAddTank({onlyIfEmpty})` /
  `bulkReplaceTanks`. (`bulkAddTags` / `bulkRemoveTags` already exist.)
- **BuddyRepository** (buddies persist outside the Dive aggregate via
  `setBuddiesForDive`, L325): `bulkAddBuddies` / `bulkRemoveBuddies` / `bulkReplaceBuddies`
  (Add carries role).
- **SpeciesRepository** (sightings persist outside the aggregate via `addSighting`,
  L130): `bulkAddSightings` / `bulkReplaceSightings`.

Owned-row inserts (tanks, weights, sightings) generate a fresh UUID per dive and set
`order`. Every insert/update calls `markRecordPending(entityType, recordId)`; every delete
calls `logDeletion(entityType, recordId)`. Junction deletion recordIds follow existing
conventions (e.g. equipment `'diveId|equipmentId'`).

### Orchestration

`BulkDiveEditService` runs the whole apply inside one `_db.transaction` (mirroring
`mergeSites`):

1. Capture the undo snapshot (below).
2. `bulkUpdateFields` for scalars (+ notes append if requested).
3. Each collection op via the appropriate repository's bulk method.
4. A single `SyncEventBus.notifyLocalChange()` at the end.

It returns a `BulkEditSnapshot`. Because writes span repositories, the service owns the
transaction boundary and the bulk methods must be transaction-participating (not each
opening their own).

## Undo safety

Modeled on `MergeSnapshot`, but it must store **per-dive prior values**, not one "before"
state — bulk editing collapses heterogeneous dives to one value, so undo must restore each
dive's distinct original.

`BulkEditSnapshot`:
- `Map<diveId, priorScalars>` — prior values of only the touched columns, per dive.
- `Map<diveId, priorCollectionRows>` — prior membership of only the touched collections,
  per dive.

Captured before mutating, scoped to touched dives × touched fields. Surfaced through the
existing snackbar-undo pattern used by `bulkDeleteDives`. Undo is itself a write
(re-marks pending, `notifyLocalChange()`), so sync (LWW + HLC) carries the reversal to
peers.

## Error handling & edge cases

- **Atomicity:** the whole apply is one transaction; any failure rolls back entirely — no
  half-applied batches.
- **Contradiction guard:** mode = OC with CCR setpoints enabled is blocked at confirm.
- **Replace-tanks is destructive:** replacing tanks cascades to delete
  `tank_pressure_profiles` / `gas_switches` (the root of the #276 SAC-disappears bug). The
  confirm dialog warns when any selected dive already has tank pressure data. *Add* never
  touches existing tanks.
- **Empty selection / nothing enabled:** Apply stays disabled.
- **Mixed selections** (e.g. some OC, some CCR): expected and supported — gates set only
  enabled fields; collection ops act per dive.
- **Large batches** (hundreds): set-based SQL scales; the per-dive `markRecordPending`
  loop is the cost. Show a progress indicator for large applies.
- **Validation:** reuse each field's existing edit-form validators, applied only to
  enabled fields.

## Components & files

**New:**
- `BulkFieldGate` widget (toggle wrapper reporting enabled + value).
- `BulkEditRequest` model (partial `DivesCompanion` + notes mode + collection ops).
- `BulkDiveEditService` (orchestrator + snapshot capture) and its Riverpod provider.
- `BulkEditSnapshot` model.
- Bulk methods on `DiveRepository`, `BuddyRepository`, `SpeciesRepository`.
- A bulk-edit confirm dialog.
- l10n strings for all new UI, translated across all 11 locales.

**Modified:**
- `dive_edit_page.dart` — `bulkDiveIds` constructor param, `isBulk` getter, hidden-field
  logic, per-field gates, collection mode selectors, notes Set/Append, save → service.
- `dive_list_content.dart` — `_anchorId`, shift-click range, "Select by date range"
  action, replace `_showBulkEditSheet` with the "Bulk edit…" entry.
- `dive_repository_impl.dart` — `bulkUpdateFields`, notes append, new collection bulk
  methods.

## Testing strategy (TDD, ≥80% per repo convention)

- **Repository unit tests** (in-memory Drift): `bulkUpdateFields` writes only enabled
  columns, bumps `updatedAt`, marks each dive pending, leaves child rows untouched;
  notes-append SQL; tank/weight Add generates fresh ids + honors `onlyIfEmpty`; each
  collection's Add/Remove/Replace; buddy role on Add; sighting per-dive rows.
- **Service tests:** atomic multi-field apply; rollback on simulated failure; snapshot
  captures per-dive priors; undo restores exactly; one `notifyLocalChange`.
- **Widget tests:** bulk mode hides measured fields, shows gates; dive-mode cascade
  reveal/collapse; collection mode selectors; confirm-dialog summary; contradiction block;
  replace-tanks warning.
- **Selection tests:** long-press enters + sets anchor; shift-click range; date-range
  select; anchor updates on tap; select-all/deselect.
- **Sync test:** a bulk edit marks the correct records pending; undo too.
- **l10n:** new strings present and translated in all 11 locales; regenerated.

## Open questions

None blocking. Trip-level dive-center propagation is intentionally folded into
date-range selection + bulk set rather than built as separate machinery.
