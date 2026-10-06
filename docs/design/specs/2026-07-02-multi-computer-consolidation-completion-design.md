# Multi-Computer Dive Consolidation — Completion Design

**Date:** 2026-07-02
**Status:** Implemented (see docs/superpowers/plans/2026-07-02-multi-computer-consolidation-completion.md)
**Related:** #449 (sequential combine — explicitly excluded consolidation),
`docs/superpowers/specs/2026-03-19-multi-computer-dive-consolidation-design.md` (v1.5 foundation),
`docs/superpowers/specs/2026-07-02-combine-dives-design.md` (sequential combine)

## Goal

Divers who wear multiple dive computers on one dive can import from all of
them and have **everything each computer recorded** available within a single
dive entry: profiles, tanks, transmitter pressure curves, events, temperature
and deco curves, and per-computer summary stats. Consolidation is offered
automatically at import time (reviewable, never silent), works retroactively
on dives already imported as separate entries, and is undoable.

This completes the v1.5 consolidation feature, which stores multi-computer
profiles and per-source snapshots but: attributes only profile samples (not
tanks/pressures/events), requires fully manual duplicate handling in the
import wizard, dead-ends the Combine dialog for time-overlapping dives, and
has uncatalogued bugs.

## Current state (verified 2026-07-02)

- `dive_profiles` rows carry `computerId` (nullable FK → `dive_computers`)
  and `isPrimary`; the full per-sample stream (depth, temp, HR, ascent rate,
  ceiling, NDL, TTS, RBT, CNS, deco type, setpoint, ppO2, O2 sensors 1-6) is
  therefore already stored per computer.
- `dive_data_sources` snapshots per-source metadata and summary stats
  (max/avg depth, duration, water temp, max ascent rate, surface interval,
  CNS, OTU, deco algorithm, GF low/high, GPS, raw data, `rawFingerprint`,
  `sourceUuid`). Rows exist only for multi-source dives; the primary row is
  backfilled at first consolidation (`backfillPrimaryDataSource`).
- `dive_tanks`, `tank_pressure_profiles`, `dive_profile_events` have **no**
  source attribution.
- Entry points and implementations are fragmented: the import wizard calls
  `DiveRepositoryImpl.consolidateComputer()`; dive-detail "Merge with another
  dive" calls `DiveRepositoryImpl.mergeDives()`; the dive-list Combine dialog
  shows a "coming in a future release" panel for overlapping selections
  (`DiveMergeBuilder.classify()` → `MergeOverlapping`). None of these have
  the pure-builder + transactional-service + snapshot-undo architecture that
  #449 established for sequential combine.
- Duplicate detection (`ImportDuplicateChecker`: exact `sourceUuid` pass,
  then fuzzy `DiveMatcher`) flags matches ≥ 0.5 and permits user-selected
  Consolidate at ≥ 0.7. Nothing is pre-selected. Only the primary source's
  `sourceUuid` is matched, so re-downloading from an already-consolidated
  secondary computer creates a duplicate dive.
- `ProfileSelectorWidget` is dead code, superseded by `ComputerToggleBar`;
  roadmap §2.2 and user-guide pages still describe it.

## Decisions (from brainstorming)

1. **Import UX:** auto-consolidate with review. High-confidence matches from
   a different computer arrive at the import review step with Consolidate
   pre-selected; user can override per dive. Nothing consolidates silently.
2. **Combine dialog:** the overlapping branch is completed — selecting
   time-overlapping dives consolidates them into one multi-computer dive
   with preview and undo.
3. **Data scope:** full fidelity. All data imported from each computer is
   retained and attributed: tanks and AI pressure curves, events and gas
   switches, temperature/HR/deco/ppO2 curves, per-source summary stats.
4. **Headline stats:** the primary computer's numbers drive the `dives` row,
   list rows, detail header, and statistics; **Set primary** swaps them from
   `dive_data_sources` snapshots (unchanged model).

## Section 1 — Data model

One migration (next schema version) adds a nullable `computerId` column,
FK → `dive_computers` with `onDelete: setNull`, to:

| Table | New column |
|---|---|
| `dive_tanks` | `computerId` |
| `tank_pressure_profiles` | `computerId` |
| `dive_profile_events` | `computerId` |

Semantics are identical to `dive_profiles.computerId`: **null means primary
source or manual entry**. Existing rows are valid without backfill; manual
dives never populate it; consolidated secondary sources stamp their
`computerId` into every child row they contribute.

`dive_data_sources` is structurally unchanged and keeps its
multi-source-only population rule.

Sync: the new columns ride the existing HLC changeset mechanism; the
migration defensively re-asserts columns (v83 stranded-column pattern).

Accepted limitation: two file-based sources with no registered computer both
get `computerId = null` and are indistinguishable per-row (profiles already
have this limitation); their `dive_data_sources` snapshots still distinguish
them via `computerModel`/`computerSerial`. Attributing by a `sourceId` FK to
`dive_data_sources` was considered and rejected: it breaks the established
convention and forces snapshot rows to exist for every dive.

## Section 2 — Unified consolidation service

Mirrors the #449 architecture: pure builder, transactional service,
full-fidelity snapshot undo.

### `DiveConsolidationBuilder` (domain, pure, no DB)

Input: a target dive plus one or more **source payloads**. A payload is
either an existing dive with its children, or an incoming parsed reading
from the import pipeline — both normalize to one structure.

- **Classify:** time-overlapping → consolidate. `DiveMergeBuilder.classify()`
  keeps owning sequential/invalid; the Combine dialog routes
  `MergeOverlapping` results here. Rejections carry specific reasons:
  same computer on both sides → "re-download, not a second computer";
  different divers → refuse.
- **Time-base alignment:** secondary samples, events, and pressure points
  are re-based to the primary dive's t=0 using the entry-time delta.
  Samples preceding the primary's start get negative timestamps; the chart
  renders the union window. (Suspected bug zone in current code — verify
  and characterize first.)
- **Build:** primary dive row untouched (stats remain primary's); secondary
  profiles/events/pressures copied with their `computerId`; one
  `dive_data_sources` snapshot per source; tags/buddies/equipment/dive
  types/sightings unioned (reusing #449 merge rules); media re-pointed.
  Output includes a **preview model** consumed by dialogs — the same object
  the service persists.
- **Tank dedup (conservative):** a secondary tank merges into an existing
  tank only when gas mix matches within ±0.5% O2/He **and** start/end
  pressures agree within ±5 bar; otherwise it is kept as an additional
  attributed tank. A deduped tank's pressure curve still transfers, attached
  to the surviving tank with the secondary `computerId` — two transmitters
  on one cylinder yield two comparable curves. Events are never deduped,
  only attributed.

### `DiveConsolidationService` (data layer)

Thin transactional orchestrator: `captureSnapshot` → `apply` (single
transaction, all-or-nothing) → snackbar `undo` (restore by original IDs;
HLC beats tombstones — same mechanism as `DiveMergeService`). Source dives
are deleted via the tombstone path (sync-safe).

### Repository changes

- `mergeDives()` and `consolidateComputer()` are absorbed into the new
  builder/service and deleted.
- `setPrimaryDataSource()` remains (swaps `dives`-row stats from snapshots);
  child-row attribution is by `computerId`, not primary flag, so it needs no
  child rewrites.
- `unlinkComputer()` is extended: the departing computer's attributed tanks,
  pressure curves, and events leave with it and are restored onto the
  rebuilt standalone dive; deduped-tank pressure curves follow their
  `computerId`.
- `import_consolidation_service.dart` and the import adapters call the new
  service.

## Section 3 — Import-time auto-consolidation

`ImportDuplicateChecker` keeps its two passes; the interpretation changes:

- **Same computer, matching dive** → re-download; default action Skip /
  Replace-source (unchanged).
- **Different computer, time-overlapping dive** → consolidation candidate.
  Score ≥ 0.85 (stricter than the existing 0.7 consolidate-allowed floor):
  review step pre-selects **Consolidate** with the target dive and both
  computer names shown. Score 0.5–0.85: flagged, requires explicit choice
  (#200 behavior). User can override any pre-selection; nothing is silent.
- **Re-download hole closed:** the checker matches against **all** of a
  dive's `dive_data_sources` rows (`sourceUuid` and `rawFingerprint`), not
  just the primary's, so a re-download from an already-consolidated
  secondary computer resolves as a same-computer duplicate → Skip.

Detection remains scoped to the active diver (#203). HealthKit remains
non-consolidating (out of scope).

## Section 4 — UI

- **Data Sources section → comparison grid:** computers as columns; rows for
  max/avg depth, duration, water temp, CNS, OTU, deco algorithm, GF. Values
  respect the active diver's unit settings. Set primary / Unlink unchanged
  in placement.
- **Profile chart:** `ComputerToggleBar` selection becomes the master filter
  for all per-computer overlays — depth (today), temperature, ceiling/TTS,
  ppO2, heart rate, event markers (color-matched to each computer's line),
  and tank-pressure curves (legend labels the computer). Chart renders the
  union time window, including negative-timestamp lead-in samples.
- **Tanks section:** secondary-computer tanks get a source badge; deduped
  tanks list both pressure sources.
- **Combine dialog overlapping branch:** replaces the "future release" panel
  with a consolidation preview — both profiles overlaid on the shared
  timeline, a primary selector defaulting to the earlier entry time
  (swappable), confirm → snackbar undo. Dive-detail "Merge with another
  dive" keeps its entry point but routes through the same service and gains
  the same preview.
- **Housekeeping:** delete `ProfileSelectorWidget` and its l10n keys; update
  `FEATURE_ROADMAP.md` §2.2 and user-guide pages (`docs/features/
  profile-analysis.md`, `docs/guide/dive-computer.md`) to describe the
  toggle bar + Data Sources model. New strings translated into all 10
  non-English locales.

## Section 5 — Bug-hunt, testing, error handling

**Characterize before refactoring.** The existing flows (wizard consolidate,
dive-detail merge, Set primary, Unlink) are exercised systematically to
catalogue bugs as failing tests before the new builder/service lands. First
targets: time-base alignment and the re-download hole.

Test layers (TDD throughout):

- **Builder unit tests** (pure, table-driven): classify boundaries,
  entry-time-delta alignment incl. negative timestamps, tank-dedup tolerance
  edges, event attribution, >2 computers, consolidating an
  already-consolidated dive (sources union, never nest).
- **Service tests with FK ON** (FK-off tests have masked child-before-parent
  insert bugs here before): consolidate → unlink → verify-restored
  round-trip across all five child tables.
- **Migration test:** columns exist post-upgrade; old rows read back null;
  defensive re-assert is idempotent.
- **Sync round-trip:** consolidated dive arrives intact on a second device
  (all sources, attributed children); tombstoned source dives do not
  resurrect; undo after sync strands nothing.
- **Widget tests:** comparison grid (unit-aware), toggle bar driving all
  overlays, overlapping-combine preview and primary swap.

Error handling: `apply` is all-or-nothing with the snapshot captured first.
Classify rejections carry user-facing reasons. Deleted computers degrade
gracefully: `setNull` clears attribution but the `dive_data_sources`
snapshot still names the model/serial, so the UI groups under that name
rather than "Unknown". User-edited profile layers (`computerId = null`,
`isPrimary = true`) are never touched by consolidation.

## Non-goals

- HealthKit consolidation.
- Re-splitting a consolidated or combined dive after the undo window.
- Buddy profile comparison and multi-transmitter sidemount UX (roadmap v2.0
  items beyond this feature).
- Changes to sequential combine (#449) beyond routing its overlapping branch.
- Best-of or per-field headline stats.
