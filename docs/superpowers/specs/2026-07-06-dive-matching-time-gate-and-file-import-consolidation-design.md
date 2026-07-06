# Dive matching time-gate + file-import consolidation

- **Date:** 2026-07-06
- **Status:** Approved (design)
- **Scope:** Two related fixes in the import subsystem, prompted by a
  ScubaBoard tester report (user *stiebs*, post 10791329).

## Problem

A tester imported a dive from Subsurface that Submersion flagged as a **50%**
"possible duplicate" of an existing dive, even though the two dives were:

- months apart (different calendar dates),
- ~4.5 km apart (different sites),
- at different times of day,

and shared **only** their duration (both 47 min). The tester also noted that
**Combine / Consolidate is only offered for direct dive-computer downloads, not
for file imports.**

### Root cause 1 — the matcher lets depth + duration alone reach the threshold

File imports (UDDF / Subsurface / universal) score candidate pairs with
`DiveMatcher.calculateMatchScore`
(`lib/features/dive_import/domain/services/dive_matcher.dart:17`), a weighted
sum:

```
score = timeScore*0.50 + depthScore*0.30 + durationScore*0.20
```

- `timeScore` = 1.0 within 5 min, ramps to **0.0 at >= 15 min apart**.
- `depthScore` = 1.0 within 10%, 0.0 at >= 20% difference.
- `durationScore` = 1.0 within 3 min, 0.0 at >= 10 min difference.

For the reported pair: `timeScore = 0.0` (months apart), `depthScore = 1.0`
(similar profile — common for recreational diving), `durationScore = 1.0`
(identical 47 min):

```
score = 0.00*0.50 + 1.00*0.30 + 1.00*0.20 = 0.50
```

`isPossibleDuplicate` is `score >= 0.5`
(`dive_matcher.dart:96`), so the pair lands *exactly* on the threshold and is
flagged. **Time is treated as a compensable weighted term when it should be a
necessary gate:** a dive is a single event in time; two recordings that don't
line up in time cannot be the same dive, no matter how alike their depth and
duration. The dive-computer *download* path does not have this bug because it
pre-filters candidates with a SQL `WHERE ABS(time_diff) <= toleranceMinutes`
(default 5 min) before scoring — time is already a gate there. Only the
file-import matcher scores against every existing dive with no time gate.

### Root cause 2 — the live file-import adapter never offers consolidation

There are three import adapters. Only the download adapter supports
consolidation:

| Path | `supportedDuplicateActions` | Calls `DiveConsolidationService`? | Routed? |
|---|---|---|---|
| `DiveComputerAdapter` (downloads) | skip, importAsNew, consolidate, replaceSource | yes | yes |
| `UniversalAdapter` (file imports) | **skip, importAsNew only** | **no** (`consolidatedCount: 0` hardcoded) | **yes** |
| `UniversalImportNotifier` + `ImportReviewStep` | consolidate supported | yes (`performConsolidations`) | **no (orphaned)** |

The routed file-import adapter (`universal_adapter.dart:140`) simply omits
`consolidate` from its supported actions, and its `performImport`
(`universal_adapter.dart:461-476`) calls `UddfEntityImporter.import` and returns
a hardcoded `consolidatedCount: 0`. A complete, working consolidation path for
file imports (`import_consolidation_service.dart#performConsolidations` +
`UniversalImportNotifier.performImport`) already exists but is not mounted in the
router — the router points file imports at the unified wizard
(`UniversalAdapter`).

Investigation **ruled out** a deeper blocker: `DiveConsolidationBuilder.classify`
(`lib/features/dive_log/domain/services/dive_consolidation_builder.dart:85`) does
**not** require a dive-computer serial. Its `sameComputer` guard only rejects a
*duplicate non-empty* serial; null/empty serials pass. File-imported dives
(which have `computerId == null` and often a null serial) consolidate fine. This
is a UI/wiring gap, not a model limitation.

## Goals

1. Stop the matcher from flagging dives that are far apart in time as possible
   duplicates, without weakening detection of genuine duplicates.
2. Offer **manual** Combine / Consolidate for file imports, reusing the existing
   `DiveConsolidationService` and the review UI the download flow already uses.

## Non-goals

- No change to the dive-computer download matcher
  (`findMatchingDiveWithScore`) — it already gates on time.
- No unification of the two matchers' differing weight sets (50/30/20 vs
  40/35/25) or depth models (% vs absolute). Latent inconsistency, out of scope.
- No `replaceSource` for file imports (download-only for now).
- No **auto**-consolidation for file imports (see Part 2, decision 4).
- The other items in the tester's post (FIT multi-select, Windows photo
  "file-not-found") are separate subsystems and out of scope.

## Part 1 — Make time a necessary gate in `DiveMatcher`

**Change:** in `calculateMatchScore`, short-circuit to "no match" when the time
evidence is already zero, before the weighted sum.

```dart
final timeScore = _calculateTimeScore(wearableStartTime, existingStartTime);
// Time is a NECESSARY condition, not just a weighted term. `_calculateTimeScore`
// is already 0.0 once the starts are >= 15 min apart; at that point there is no
// time evidence the two recordings are the same physical dive, so a depth+
// duration coincidence must not be able to reach the possible-duplicate
// threshold (depth 0.30 + duration 0.20 = 0.50).
if (timeScore <= 0) return 0.0;

final depthScore = _calculateDepthScore(wearableMaxDepth, existingMaxDepth);
final durationScore = _calculateDurationScore(
  wearableDurationSeconds, existingDurationSeconds,
);
return (timeScore * 0.50) + (depthScore * 0.30) + (durationScore * 0.20);
```

**Why the 15-min boundary is safe (low false-negative risk):**

- A re-import of an old dive carries the dive's *original* timestamp, which
  matches the existing entry to the second — the import date is irrelevant.
- Two computers on one diver enter the water within seconds; their entry times
  are far inside 15 min.
- Cross-source timezone skew was already addressed
  (see `2026-03-17-dive-time-timezone-fix-design.md`), so the two sides compare
  on the same wall-clock basis (dive times are wall-clock-as-UTC by design).

**Effect on the report:** the reported pair scores `0.0` instead of `0.50` and
is not flagged. Same-day-but-hours-apart collisions (morning vs afternoon dive
with matching depth+duration) are also fixed, since they too exceed 15 min.

**Placement:** the gate lives in `calculateMatchScore`, so it fixes every
consumer at once — `UddfDuplicateChecker` and `ImportDuplicateChecker` both call
it. No checker-level *production* change is required for Part 1 (a checker-level
regression test is still added — see Testing plan).

## Part 2 — Wire manual consolidation into `UniversalAdapter`

Port the proven wiring from the orphaned
`UniversalImportNotifier.performImport` into the live adapter. Four edits:

### 1. Offer the action

`UniversalAdapter.supportedDuplicateActions` gains `DuplicateAction.consolidate`:

```dart
Set<DuplicateAction> get supportedDuplicateActions => const {
  DuplicateAction.skip,
  DuplicateAction.importAsNew,
  DuplicateAction.consolidate,
};
```

Because every layer of the review UI reads this one set
(`review_step.dart:40`, `entity_review_list.dart:994`,
`dive_comparison_card.dart:374`), the "Consolidate" button (per-card and bulk)
appears automatically — no widget changes.

### 2. Mark exact re-imports so they default to skip

`ImportDuplicateChecker._checkDiveDuplicates`
(`import_duplicate_checker.dart:670`) currently builds every `DiveMatchResult`
with `matchedExistingSource` defaulting to `false`. Set it **`true` in the Pass 0
`sourceUuid` exact-match branch** (`import_duplicate_checker.dart:709`), leaving
Pass 1 (content-fuzzy) matches `false`.

Consequences, all already implemented generically in the wizard providers:

- `setBundle` forces `matchedExistingSource` matches to **skip** — an exact
  re-import is never auto- or bulk-consolidated.
- `applyBulkAction`'s consolidate gate (`score >= 0.7 && !matchedExistingSource`)
  excludes them from "Consolidate all".

`matchedComputerId` is **not** populated for file imports: it is only consumed by
the auto-consolidate branch, which cannot fire for file imports (decision 4), so
adding it would be dead data and would force `_checkDiveDuplicates` async for no
benefit.

### 3. Fold consolidate-flagged dives after import

In `UniversalAdapter.performImport`:

1. Read the consolidate-flagged dive indices from
   `duplicateActions[ImportEntityType.dives]` (entries whose action is
   `consolidate`).
2. Ensure those indices are included in the import selection (they must be
   imported as standalone dives first, exactly like `importAsNew`, so their
   cross-references resolve). Extend the existing `resolve()` /
   `_resolveSelections` so `consolidate` is treated like `importAsNew` for
   selection purposes.
3. After `importer.import(...)`, if any consolidate indices exist, call
   `performConsolidations` with `result.diveIdByIndex`, the per-index match
   results from `bundle.groups[dives].matchResults`, the
   `diveConsolidationServiceProvider`, and the dive repository.
4. Return `consolidatedCount: summary.consolidated` (no longer hardcoded `0`),
   and surface `summary.failed` (> 0) to the user (reuse the orphaned path's
   warning wording: "N dive(s) could not be consolidated ... the partial imports
   were removed again to avoid duplicates.").

`performConsolidations` already imports-then-folds each dive and, on a fold
failure, deletes the freshly-imported standalone dive
(`bulkDeleteDives`, tombstone-honoring) so no bare duplicate is stranded.

**Small refactor:** `performConsolidations` currently takes
`duplicateResult: ImportDuplicateResult?` and calls `diveMatchFor(index)`. The
adapter has a `Map<int, DiveMatchResult>` instead. Generalize the parameter to a
plain `Map<int, DiveMatchResult> matchByIndex` (or a
`DiveMatchResult? Function(int)` callback) and update its single existing caller
(`universal_import_providers.dart:638`).

### 4. Manual only — no auto-consolidation for file imports

`setBundle`'s auto-consolidate branch requires `currentComputerId != null`
(`import_wizard_providers.dart:288`). `UniversalAdapter.buildBundle` leaves
`currentComputerId` null (a file may contain dives from several computers, so
there is no single "current computer" and no confident cross-computer proof).
We keep it null: file-import duplicates stay pending and the user explicitly
chooses Consolidate. This is intentional and requires no code change.

## Data flow (Part 2, happy path)

```
file import → checkDuplicates
   Pass 0 sourceUuid exact  → DiveMatchResult(matchedExistingSource: true)  → default skip
   Pass 1 content + TIME GATE→ DiveMatchResult(score>=0.5, existingSource:false) → pending
review UI shows Consolidate (per-card / bulk) because adapter now supports it
user picks Consolidate on a Pass-1 match
performImport:
   import consolidate-flagged dives as standalone (importer.import → diveIdByIndex)
   performConsolidations: apply(target = match.diveId, secondary = new dive) then tombstone
   summary.consolidated → UnifiedImportResult.consolidatedCount
```

## Edge cases & risks

- **Same physical computer, cross-source (Subsurface serial == an existing
  download's serial), overlapping in time.** Pass 1 matches (source UUIDs
  differ, so `matchedExistingSource` is false) and Consolidate is offered. On
  apply, `DiveConsolidationBuilder.classify` returns `sameComputer` and throws;
  `performConsolidations` catches it, deletes the just-imported standalone dive,
  and reports it under `summary.failed` → the user sees a non-fatal warning. No
  crash, no stranded duplicate. Suppressing the *offer* for equal-serial matches
  is a possible future refinement but is **deferred** — the graceful-failure path
  already prevents harm, and this scenario is uncommon.
- **Import + fold are not one transaction** (pre-existing property of
  `performConsolidations`). Compensating delete keeps the DB consistent on
  partial failure.
- **Time gate false negative.** Only if two recordings of the same dive differ
  by >= 15 min in start time — precluded by the reasons in Part 1. Accepted.
- **Orphaned code.** `UniversalImportNotifier.performImport` /
  `ImportReviewStep` remain in the tree, still unrouted. This change does not
  depend on them; leave them as-is (a separate cleanup may remove them later).

## Testing plan (TDD — tests first)

**Part 1 — `dive_matcher_test.dart`:**
- Months apart + identical duration + depth within 10% → `score == 0.0`, not
  `isPossibleDuplicate` (regression test for the exact report).
- ~4 hours apart, same depth+duration → `0.0` (same-day collision).
- Just over 15 min apart → gated to `0.0`; within 15 min → weighted score as
  before.
- Existing "real duplicate" cases (identical, 8-min offset, etc.) still score
  as before — the gate must not regress them.
- Checker-level: add a `ImportDuplicateChecker` / `UddfDuplicateChecker` case
  where a far-apart existing dive is **not** returned as a match.

**Part 2:**
- `ImportDuplicateChecker`: Pass 0 sourceUuid match sets
  `matchedExistingSource: true`; Pass 1 content match leaves it `false`.
- `UniversalAdapter.supportedDuplicateActions` includes `consolidate`.
- `UniversalAdapter.performImport`: a consolidate-flagged dive is imported then
  folded via `DiveConsolidationService.apply`, `consolidatedCount == 1`, and the
  standalone dive is tombstoned. (Mirror
  `dive_computer_adapter_consolidate_integration_test.dart`.)
- Same-serial target → fold rejected, standalone deleted, reported as failed,
  import otherwise succeeds.
- `performConsolidations` signature change: update its existing test/caller.

**Whole-project gates (per CLAUDE.md):** `dart format .`, `flutter analyze`,
`flutter test` on affected files, then drive an actual file import to confirm the
Consolidate button appears and folds.

## Files touched

Part 1:
- `lib/features/dive_import/domain/services/dive_matcher.dart` (gate)
- `test/features/dive_import/domain/services/dive_matcher_test.dart`
- checker tests under `test/features/universal_import/...` and
  `test/features/dive_import/...`

Part 2:
- `lib/features/import_wizard/data/adapters/universal_adapter.dart`
  (supported actions + `performImport` fold + `resolve()` includes consolidate)
- `lib/features/universal_import/data/services/import_duplicate_checker.dart`
  (`matchedExistingSource: true` in Pass 0)
- `lib/features/universal_import/presentation/providers/import_consolidation_service.dart`
  (generalize match-lookup param) + its caller
  `universal_import_providers.dart`
- tests under `test/features/import_wizard/...` and
  `test/features/universal_import/...`

## Precedent

`2026-03-17-dive-time-timezone-fix-design.md`,
`2026-03-19-multi-computer-dive-consolidation-design.md`,
`2026-03-23-unified-import-wizard-design.md`,
`2026-03-24-dive-data-source-provenance-design.md`.
