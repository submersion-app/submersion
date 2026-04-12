# Import Review: Require Explicit Selection for Suspected Duplicates

**Issue:** [#200](https://github.com/submersion-app/submersion/issues/200) — Change the import review step so that suspected duplicates require a selection.

## Problem

In today's universal-import review step, any incoming row flagged as a suspected duplicate is silently excluded from the import's default selection. The user can confirm the import without ever reviewing those rows, which results in dives (and other entities) being inadvertently skipped or overlooked in a long import list. The failure is silent — there is no indication that rows were dropped, and an explicit user-chosen "skip" is indistinguishable from the auto-default.

## Goal

Replace the auto-skip default with an explicit "needs decision" state. Every suspected duplicate must be reviewed and resolved before the Import button becomes available. Provide efficient bulk actions so users facing many duplicates can still complete an import quickly.

## Scope

- Applies to the universal import flow in `lib/features/universal_import/` (the active import wizard, used by both dive-computer imports and file imports).
- Applies to every entity type with duplicate detection: dives, sites, buddies, trips, equipment, dive centers, certifications, courses, tags, dive types.
- Does **not** apply to the legacy `lib/features/import_wizard/` flow.

## Out of Scope

- No changes to duplicate-detection scoring thresholds (`dive_matcher.dart` stays as-is).
- No "revert to undecided" per-row control — once chosen, a row is resolved. Reverting requires cancelling and re-running the import.
- No new "merge / update existing" action for non-dive entities. Sites, buddies, etc. remain binary (import / skip).
- No persistence of partial review state across wizard sessions. A cancelled review discards decisions.
- No changes to duplicate-detection logic itself (`import_duplicate_checker.dart`).

## State Model (Approach B: orthogonal "pending review" set)

Add one field to `UniversalImportState` (`lib/features/universal_import/presentation/providers/universal_import_state.dart`):

```dart
final Map<ImportEntityType, Set<int>> pendingDuplicateReview;
```

### Invariant

For every `ImportEntityType t` and every index `i`:

> `i ∈ pendingDuplicateReview[t]` iff the row at index `i` was flagged as a suspected duplicate **and** the user has not explicitly acted on it yet.

### State helpers

```dart
bool get hasPendingReviews =>
    pendingDuplicateReview.values.any((set) => set.isNotEmpty);

int get totalPending =>
    pendingDuplicateReview.values.fold(0, (sum, s) => sum + s.length);
```

### Population (parse time)

In `_parseAndCheckDuplicates()` (`lib/features/universal_import/presentation/providers/universal_import_providers.dart` around lines 353-419):

- `pendingDuplicateReview[ImportEntityType.dives]` = all indices with `DiveMatchResult.score >= 0.5` (existing "possible duplicate" threshold from `import_duplicate_checker.dart:682`).
- `pendingDuplicateReview[type]` for every non-dive duplicate type = all indices present in the corresponding duplicate set from `ImportDuplicateResult`.
- Default `selections[type]` behavior is unchanged: duplicates are initially deselected; the new gate makes "deselected" no longer equivalent to "skipped."

### Drain conditions

- **Per-row action:** removes the index from `pendingDuplicateReview[type]`.
- **Bulk action:** removes all qualifying pending indices for that type in a single state update.
- **Cancel wizard:** state is discarded entirely; no explicit drain required.
- **Re-parse:** `_parseAndCheckDuplicates()` rebuilds `pendingDuplicateReview` from scratch.

## Notifier API Changes

In `lib/features/universal_import/presentation/providers/universal_import_providers.dart`:

### Modified

**`setDiveResolution(int index, DiveDuplicateResolution resolution)`**
Existing atomic update of `diveResolutions` and `selections[dives]` is extended to also remove `index` from `pendingDuplicateReview[ImportEntityType.dives]`. Single `copyWith`.

### New

**`setEntityAction(ImportEntityType type, int index, bool include)`**
For non-dive entity rows that are flagged duplicates. Adds/removes `index` from `selections[type]` and removes `index` from `pendingDuplicateReview[type]` in one `copyWith`.

**`applyBulkDiveAction(DiveDuplicateResolution action, {bool onlyPending = true})`**
Iterates the pending (or all duplicate) dive indices, applies `action` to each, and emits a single state update. For `action == consolidate`, only applies to indices whose `DiveMatchResult.score >= 0.7` (the existing "probable duplicate" threshold); unmatchable indices remain pending.

**`applyBulkEntityAction(ImportEntityType type, bool import, {bool onlyPending = true})`**
Iterates the pending (or all duplicate) indices for `type`, sets selection to `import`, drains pending, emits a single state update.

**`jumpToFirstPending() → (ImportEntityType, int)?`**
Returns the entity type and index of the first pending row across tabs in tab order. Returns `null` if nothing is pending. The UI uses this to switch tabs and scroll the row into view.

### Unchanged

`performImport()` needs no changes. By the time it runs, the Import button gate guarantees `pendingDuplicateReview` is empty, so the existing partition logic (consolidate vs. normal selection) operates on fully-resolved state.

## UI

File: `lib/features/universal_import/presentation/widgets/import_review_step.dart` (and `import_dive_card.dart`).

### Per-tab layout (reading order)

1. **Duplicate-summary banner** (existing, copy updated):
   > "N of M dives are suspected duplicates. Each needs a decision before importing."

2. **Bulk-action row** (new; shown only when `pendingDuplicateReview[type]` is non-empty):
   - **Dives:** three buttons.
     - `Skip all (n)` — drains *all* pending dive indices, setting each to `skip`.
     - `Import all as new (n)` — drains *all* pending dive indices, setting each to `importAsNew`.
     - `Consolidate matched (k)` — drains only pending dive indices whose `DiveMatchResult.score >= 0.7`, setting each to `consolidate`. Indices without a viable match target **remain pending**. The button is disabled when `k == 0`. In a tab where `k < n`, using this button alone does not enable Import; the remaining `n - k` pending dives still require per-row or bulk resolution.
   - **Other entity types:** two buttons — `Skip all (n)`, `Import all (n)`. Both drain *all* pending indices for that type.

3. **Row list — sorted** so unresolved (pending) rows come first. Within each group (pending / resolved / non-duplicate), original order is preserved.

### Per-row visual state

| Row state | Left border | Badge | Checkbox |
|---|---|---|---|
| Not a duplicate | none | none | checked |
| Duplicate, pending review | 4 px warning-color border (tertiary / semantic warning); paired with `Icons.warning_amber_rounded` inside the pill | "Needs decision" pill | unchecked, with inline hint "Tap Decide to choose" |
| Duplicate, resolved | subtle neutral left border | small chip showing chosen action ("Skip" / "Import as new" / "Consolidate") | matches chosen action |

The warning color is paired with an icon and text so the state is conveyed without relying on color alone (colorblind-safe).

### Import button area (bottom)

- **Gate:** enabled iff `state.totalSelected > 0 && !state.hasPendingReviews`.
- **Pending hint** (shown directly above the button when `hasPendingReviews`):
  > "N duplicate(s) need a decision" — followed by a `Review` button that calls `jumpToFirstPending()`, switches to the returned tab, and scrolls the pending row into view.
- **Existing no-selection state** (disabled when `totalSelected == 0`) is preserved.
- Helper text above the button uses `Semantics(liveRegion: true)` so the count updates are announced by screen readers as rows are resolved.

### Comparison expansion (`ImportDiveCard`)

No change to the expansion mechanism. For pending rows, the button label becomes `Decide` (new l10n key) and adopts the warning accent. Resolved rows retain the existing `Compare dives` label.

## Data Flow

```
User selects source
  │
  ▼
_parseAndCheckDuplicates()
  │
  ├─→ selections[type] = non-duplicate indices        (unchanged)
  ├─→ diveResolutions = {}                            (unchanged)
  └─→ pendingDuplicateReview[type] = duplicate indices  (NEW)
  │
  ▼
Review step
  │
  ├── Bulk action ──→ applyBulk{Dive,Entity}Action()
  │                    └─→ update selections/resolutions
  │                        drain pendingDuplicateReview[type]
  │
  └── Per-row action ──→ setDiveResolution() or setEntityAction()
                         └─→ update selections/resolutions
                             pendingDuplicateReview[type].remove(i)
  │
  ▼
Import button gate: totalSelected > 0 && !hasPendingReviews
  │
  ▼
performImport()   (existing, unchanged)
```

## Localization

New ARB keys in `lib/l10n/app_en.arb`, accessed via `context.l10n.*`:

| Key | Value |
|---|---|
| `universalImport_pending_needsDecision` | "Needs decision" |
| `universalImport_pending_gateHint` | "{count} duplicate(s) need a decision" |
| `universalImport_pending_reviewAction` | "Review" |
| `universalImport_bulk_skipAll` | "Skip all ({count})" |
| `universalImport_bulk_importAllAsNew` | "Import all as new ({count})" |
| `universalImport_bulk_importAll` | "Import all ({count})" |
| `universalImport_bulk_consolidateMatched` | "Consolidate matched ({count})" |
| `universalImport_dive_decideAction` | "Decide" |
| `universalImport_rowHint_tapCompareToDecide` | "Tap Decide to choose" |
| `universalImport_summary_decidesRequired` | "Each needs a decision before importing." |

Other locale ARB files are updated with the same keys (translations may follow in a separate PR per existing project practice).

## Accessibility

- "Needs decision" pill wrapped in `Semantics(label: 'Suspected duplicate, needs decision')`.
- Warning color paired with `Icons.warning_amber_rounded` plus text (shape + color + text).
- Pending-count hint above the Import button uses `Semantics(liveRegion: true)` so count changes are announced.

## Testing

### State / notifier (extend `test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`)

- After parse with mixed clean and duplicate dives, `pendingDuplicateReview[dives]` contains exactly the flagged indices.
- `setDiveResolution(i, skip)` drains `i` from pending.
- `setDiveResolution(i, importAsNew)` drains `i` from pending and adds to `selections[dives]`.
- `setDiveResolution(i, consolidate)` drains `i` from pending and adds to `selections[dives]`.
- `applyBulkDiveAction(skip, onlyPending: true)` drains all pending dive indices; resolutions set to skip; `selections[dives]` unchanged.
- `applyBulkDiveAction(importAsNew)` drains all pending; selections include each; resolutions = importAsNew.
- `applyBulkDiveAction(consolidate)` drains only probable-match pending indices (score ≥ 0.7); un-matchable indices remain pending.
- `setEntityAction(sites, i, true)` drains pending and adds to `selections[sites]`.
- `setEntityAction(sites, i, false)` drains pending and does not change selection.
- `applyBulkEntityAction(sites, true)` drains all pending site indices; selections updated.
- `hasPendingReviews` flips false only when the last pending index across all types is drained.
- `totalPending` sums across types correctly.
- Re-parsing discards stale `pendingDuplicateReview` entries.
- `jumpToFirstPending()` returns entities in tab order; returns `null` when empty.

### Widget (new file: `test/features/universal_import/presentation/widgets/import_review_step_pending_test.dart`)

- Import button is disabled while any tab has pending rows, even with `totalSelected > 0`.
- Import button enables after all pending rows are resolved via per-row actions.
- Import button enables after all pending rows are resolved via bulk actions.
- Pending hint "N duplicate(s) need a decision" shows the correct count and updates as rows resolve.
- `Review` button jumps to the correct tab and scrolls the first pending row into view.
- Pending rows render above resolved and non-duplicate rows within each tab.
- Pending rows display the warning-colored left border, icon, and "Needs decision" pill.
- Bulk-action buttons appear only when their tab has pending rows; their counts match the pending set size.
- For the Dives tab, `Consolidate matched` button shows only the count with `score ≥ 0.7`, and is disabled when that count is zero.
- For non-dive tabs, bulk buttons show the correct affected counts.

### Regression (new file: `test/features/universal_import/presentation/providers/issue_200_regression_test.dart`)

Simulate the exact failure mode the issue describes:

- Parse an import with ≥ 1 suspected-duplicate dive.
- Assert the Import button is disabled.
- Assert that calling `performImport()` without resolving is impossible (covered by the UI gate; verify at state level that `hasPendingReviews` is true and the button's `onPressed` is `null`).
- Assert no dive is silently skipped — i.e., the only way a dive ends up unimported is an explicit user action.

### Unchanged

- `import_duplicate_checker_test.dart` — detection logic is unchanged.

## Edge Cases

- **Large imports (many duplicates):** per-tab bulk buttons provide O(1) clicks per tab; large imports remain tractable.
- **Consolidate-bulk with no viable targets:** affected indices are left pending; the user handles them individually or chooses another bulk action.
- **All rows are duplicates:** user must resolve all before Import enables. `totalSelected > 0` gate also applies (at least one dive must be importable or consolidatable).
- **Zero duplicates:** behavior is unchanged from today — Import button enabled as soon as `totalSelected > 0`.
- **User re-runs parsing with a different file:** `_parseAndCheckDuplicates()` rebuilds the state; stale pending entries are dropped.
- **User cancels mid-review:** state is discarded; partial decisions are lost (accepted).

## Risks and Tradeoffs

- **Two state fields to keep in sync.** `pendingDuplicateReview` and `selections/diveResolutions` must always be updated together. Mitigation: all mutations go through the notifier's atomic `copyWith` methods; a debug-build invariant assertion can verify "no index is both in pending and in a resolved resolutions entry" on each state emission.
- **More clicks on average.** Users whose imports have only true duplicates will spend more time on the review step than today. Mitigation: per-tab bulk buttons; the Import all as new / Skip all actions take two clicks max per tab.
- **Ephemeral state.** Cancelled wizards lose partial decisions. Accepted; persistent draft state is a separate, larger feature.

## Files Touched

**Modified:**
- `lib/features/universal_import/presentation/providers/universal_import_state.dart` — add `pendingDuplicateReview`, helpers.
- `lib/features/universal_import/presentation/providers/universal_import_providers.dart` — populate at parse; extend `setDiveResolution`; add `setEntityAction`, `applyBulkDiveAction`, `applyBulkEntityAction`, `jumpToFirstPending`.
- `lib/features/universal_import/presentation/widgets/import_review_step.dart` — sort, bulk buttons, gate hint, row styling, Review button.
- `lib/features/universal_import/presentation/widgets/import_dive_card.dart` — pending visual state, "Decide" label.
- `lib/l10n/app_en.arb` (and peers) — new strings.

**Added:**
- `test/features/universal_import/presentation/widgets/import_review_step_pending_test.dart`
- `test/features/universal_import/presentation/providers/issue_200_regression_test.dart`

**Extended:**
- `test/features/universal_import/presentation/providers/universal_import_notifier_test.dart`

**Unchanged:**
- `lib/features/universal_import/data/services/import_duplicate_checker.dart`
- `lib/features/dive_import/domain/services/dive_matcher.dart`
- `lib/features/universal_import/data/models/import_enums.dart` (the `DiveDuplicateResolution` enum is left alone)
