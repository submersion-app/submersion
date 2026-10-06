# Import Review: Require Explicit Selection for Suspected Duplicates

**Issue:** [#200](https://github.com/submersion-app/submersion/issues/200) — Change the import review step so that suspected duplicates require a selection.

## Problem

In today's import review step, every row the duplicate checker flags is given an automatic default action the user never confirmed:

- Probable duplicates (score ≥ 0.7) auto-default to `skip` and are deselected.
- Possible duplicates (0.5 ≤ score < 0.7) auto-default to `importAsNew` and stay selected.
- Unscored duplicates (non-dive entities) auto-default to `skip`.

The user can confirm the import without reviewing any of these rows, so dives and other entities can be silently skipped or silently double-imported. The failure is silent — there is no indication that the app decided anything on the user's behalf, and a user-chosen action is indistinguishable from the auto-default.

## Goal

Replace every auto-default with an explicit "needs decision" state. Every suspected duplicate (any row with `score >= 0.5` for dives, or any entry in `EntityGroup.duplicateIndices` for non-dives) must be reviewed and resolved before the Import button becomes available. Provide efficient bulk actions per tab so users facing many duplicates can complete an import without clicking dozens of rows individually.

## Scope

- Applies to the active unified import flow in `lib/features/import_wizard/` — the `UnifiedImportWizard` widget, `ReviewStep`, `EntityReviewList`, `DuplicateActionCard`, and `ImportWizardNotifier` / `ImportWizardState`.
- Applies to every entity type the duplicate checker flags: dives, sites, buddies, trips, equipment, dive centers, certifications, courses, tags, dive types.
- Applies to every import source (file, dive computer, HealthKit, UDDF, FIT) because they all route through `UnifiedImportWizard` with different `SourceAdapter` implementations.
- Respects the adapter's `supportedDuplicateActions` set — the bulk-action row only shows buttons for actions the adapter supports.
- Does **not** apply to the orphaned `lib/features/universal_import/presentation/widgets/import_review_step.dart` (dead code; out of scope to clean up in this change).

## Out of Scope

- No changes to duplicate-detection scoring thresholds (`dive_matcher.dart` stays as-is).
- No "revert to undecided" per-row control — once chosen, a row is resolved. Reverting requires cancelling and re-running the import.
- No new action options for non-dive entities; they remain binary (import / skip) per adapter capability.
- No persistence of partial review state across wizard sessions. A cancelled review discards decisions.
- No changes to duplicate-detection logic itself (`import_duplicate_checker.dart`).
- No rewiring of the router or deletion of the orphaned `universal_import/` review-step widget.

## State Model (Approach B: orthogonal "pending review" set)

Add one field to `ImportWizardState` (`lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`):

```dart
final Map<ImportEntityType, Set<int>> pendingDuplicateReview;
```

### Invariant

For every `ImportEntityType t` and every index `i`:

> `i ∈ pendingDuplicateReview[t]` iff the row at index `i` was flagged as a suspected duplicate **and** the user has not explicitly acted on it yet.

### State helpers

```dart
Set<int> pendingFor(ImportEntityType type) =>
    pendingDuplicateReview[type] ?? const {};

bool get hasPendingReviews =>
    pendingDuplicateReview.values.any((set) => set.isNotEmpty);

int get totalPending =>
    pendingDuplicateReview.values.fold(0, (sum, s) => sum + s.length);
```

### Population (`setBundle`)

The existing `ImportWizardNotifier.setBundle(ImportBundle bundle)` method initializes `selections` and `duplicateActions` from the bundle's duplicate data. Today it auto-defaults actions based on score (skip for probable, importAsNew for possible) and deselects duplicates from `selections`.

After this change:

- `pendingDuplicateReview[type]` is populated with every index in `EntityGroup.duplicateIndices` for that type, regardless of whether it's probable or possible.
- `duplicateActions[type]` is cleared for pending rows (no auto-default values). Non-pending rows are unaffected.
- `selections[type]` continues to exclude pending indices by default (nothing is imported until the user resolves). A user-chosen `importAsNew` or `consolidate` re-adds the index to `selections`.

### Drain conditions

- **Per-row action** (existing `setDuplicateAction(type, index, action)`): the chosen index is removed from `pendingDuplicateReview[type]` in the same state emission.
- **Non-duplicate toggle** (existing `toggleSelection(type, index)`): if the index happens to be pending (edge case where the user toggles the checkbox of a pending row), it is also drained.
- **Bulk action** (new, see below): all targeted indices are drained in a single emission.
- **Cancel wizard / re-build bundle**: the state is discarded or rebuilt from scratch.

## Notifier API Changes

All in `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`.

### Modified

**`setBundle(ImportBundle bundle)`**
Extend current auto-default logic to populate `pendingDuplicateReview` from each `EntityGroup.duplicateIndices`. Do not auto-assign `duplicateActions` values for pending rows (leave those absent until the user acts).

**`setDuplicateAction(ImportEntityType type, int index, DuplicateAction action)`**
Current behavior: records the action in `duplicateActions` and syncs `selections[type]` accordingly. Extension: also drains `index` from `pendingDuplicateReview[type]` in the same `copyWith`.

**`toggleSelection(ImportEntityType type, int index)`**
Current behavior: toggles `selections[type]`. Extension: if `index` is in `pendingDuplicateReview[type]`, drain it (explicit user interaction counts as a decision).

### New

**`applyBulkAction(ImportEntityType type, DuplicateAction action)`**
Apply `action` to every pending-review index for `type`, in one state emission. Respects the adapter's `supportedDuplicateActions`:

- For `DuplicateAction.consolidate`: only applies to indices whose `DiveMatchResult.score >= 0.7` (probable threshold from `dive_matcher.dart`). Weaker matches remain pending. Only relevant on adapters that support consolidate.
- For `DuplicateAction.skip`: applies to all pending indices; removes them from `selections[type]`.
- For `DuplicateAction.importAsNew`: applies to all pending indices; adds them to `selections[type]`.

Indices that do not apply (e.g., non-matchable for consolidate) stay pending.

**`firstPendingLocation() → PendingLocation?`**
Returns `(type, index)` for the first pending row across tabs in `ImportEntityType.values` enum order, using the smallest index within the first non-empty pending set. Returns null if no pending rows exist. The UI uses this to switch tabs and scroll the first unresolved row into view.

```dart
class PendingLocation {
  const PendingLocation({required this.type, required this.index});
  final ImportEntityType type;
  final int index;
}
```

### Unchanged

`performImport()` is unchanged. By the time the Import button fires, the gate guarantees `pendingDuplicateReview` is empty, so the existing partition logic (non-duplicate selection + per-duplicate `duplicateActions`) operates on fully-resolved state.

## UI

Files:

- `lib/features/import_wizard/presentation/widgets/review_step.dart`
- `lib/features/import_wizard/presentation/widgets/entity_review_list.dart`
- `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart`
- Supporting card: `needs_decision_pill.dart` (new shared widget, to be created under `lib/features/import_wizard/presentation/widgets/`).

### Per-tab layout (reading order)

1. **Existing non-duplicate header row** — select all / deselect all toggle, count. Unchanged.
2. **New bulk-action row** — shown only when `pendingDuplicateReview[type]` is non-empty, and only rendering buttons for actions the `adapter.supportedDuplicateActions` set includes:
   - If `skip` supported: `Skip all (n)` button.
   - If `importAsNew` supported: `Import all as new (n)` (for dives) / `Import all (n)` (for non-dives) button.
   - If `consolidate` supported AND matchable pending count `k` > 0: `Consolidate matched (k)` button (disabled when `k == 0`).
3. **Row list — sorted** so pending indices come first (in ascending order), then the existing non-pending ordering (by match score for duplicates, original order for non-duplicates).

### Per-row visual state

For dive duplicate cards (`DuplicateActionCard`):

| Row state | Left border | Badge | Action header |
|---|---|---|---|
| Not pending, user has chosen | subtle neutral | chosen-action chip ("Skip" / "Import as New" / "Consolidate") | existing behavior |
| Pending (needs decision) | 4 px warning-color border | "Needs decision" pill (icon + text) | button label "Decide" instead of "Compare dives" |

For non-dive duplicate cards (`_EntityDuplicateCard`):

| Row state | Left border | Badge | Expand button |
|---|---|---|---|
| Not pending | subtle neutral | chosen-action chip | existing |
| Pending | 4 px warning-color border | "Needs decision" pill | "Decide" |

For non-duplicate rows (`_NonDuplicateRow`): unchanged.

### Import button area (bottom)

- **Gate:** enabled iff `state.totalSelected > 0 && !state.hasPendingReviews`.
- **Pending hint** (shown above the button when `hasPendingReviews`):
  > "N duplicate(s) need a decision" — followed by a `Review` button that calls `firstPendingLocation()` and animates the `DefaultTabController` to the matching tab.
- Helper text uses `Semantics(liveRegion: true)` so count changes are announced.

### Comparison expansion

No change to the expansion mechanism itself. For pending rows, the button label becomes `Decide` (using `universalImport_dive_decideAction` l10n key) and adopts the warning accent. Resolved rows retain existing labels.

## Data Flow

```
User starts import via UnifiedImportWizard
  │
  ▼
Source-specific acquisition (file pick / BLE / HealthKit / ...)
  │
  ▼
adapter.buildBundle() → ImportBundle with groups
adapter.checkDuplicates(bundle) → bundle with duplicateIndices filled
  │
  ▼
notifier.setBundle(checkedBundle)
  ├─→ selections[type] = all indices - duplicateIndices  (unchanged)
  ├─→ duplicateActions[type] cleared for pending indices (CHANGED)
  └─→ pendingDuplicateReview[type] = duplicateIndices    (NEW)
  │
  ▼
ReviewStep
  │
  ├── Bulk action ──→ applyBulkAction(type, action)
  │                    └─→ update duplicateActions + selections
  │                        drain pendingDuplicateReview[type]
  │
  └── Per-row action ──→ setDuplicateAction(type, i, action)
                         └─→ update duplicateActions + selections
                             pendingDuplicateReview[type].remove(i)
  │
  ▼
Import button gate: totalSelected > 0 && !hasPendingReviews
  │
  ▼
performImport()   (existing, unchanged)
```

## Localization

Already added to `lib/l10n/arb/app_en.arb` (inherited from a previous cherry-pick). Relevant keys:

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

One additional key to add during implementation: `universalImport_semantics_needsDecision` for the pill's screen-reader label.

The key prefix `universalImport_*` is a historical artifact from the spec's original (mis-targeted) scope. Renaming is out of scope; the keys ship as-is. (The `universalImport_` ARB namespace is used by the active flow too, so the keys are visible.)

## Accessibility

- "Needs decision" pill wrapped in `Semantics(label: context.l10n.universalImport_semantics_needsDecision)`.
- Warning color paired with `Icons.warning_amber_rounded` plus text (shape + color + text — colorblind-safe).
- Pending-count hint above the Import button uses `Semantics(liveRegion: true)` for announcement on count change.

## Testing

### State / notifier

File: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart` (extend).

- After `setBundle` with a bundle containing duplicates, `pendingDuplicateReview[type]` contains exactly the flagged indices; `duplicateActions[type]` has no entries for pending indices.
- After `setDuplicateAction(type, i, action)`, index `i` is drained from pending; `duplicateActions[type][i] == action`; `selections[type]` reflects the action.
- After `toggleSelection(type, i)` on a pending index, the index is drained from pending.
- `applyBulkAction(type, skip)` drains all pending for that type, sets each to skip, removes from selection.
- `applyBulkAction(type, importAsNew)` drains all pending, sets each to importAsNew, adds to selection.
- `applyBulkAction(type, consolidate)` on a dive bundle drains only indices with `score >= 0.7`; weaker pending stays pending.
- `applyBulkAction` on an adapter without a given action throws or is a no-op (TBD — pick one during planning; probably no-op with an assertion).
- `hasPendingReviews` flips false only when the last pending index is drained.
- `firstPendingLocation()` returns null when empty; returns dive-first when dives have pending; returns next tab when dives drained.

### Widget

New file: `test/features/import_wizard/presentation/widgets/review_step_pending_test.dart`.

- Import button is disabled while any tab has pending rows, even when `totalSelected > 0`.
- Import button enables after all pending are resolved via per-row actions.
- Import button enables after all pending are resolved via bulk actions.
- Pending hint appears and shows correct count; `Review` button jumps to the first pending tab.
- Pending rows sort above resolved rows in the list.
- Pending rows render the warning border + "Needs decision" pill.
- Dive bulk-action row shows only buttons supported by the adapter (e.g., file-import adapter shows skip + importAsNew only; DC adapter shows all three).
- `Consolidate matched` button shows correct count and is disabled when count is 0.

### Regression

New file: `test/features/import_wizard/presentation/providers/issue_200_regression_test.dart`.

Self-contained regression guard: after `setBundle` with a bundle containing a probable duplicate dive, assertions prove that (a) `hasPendingReviews` is true, (b) `duplicateActions` has no entry for the pending index (no silent default), (c) only explicit user action drains the pending set, and (d) the Import button's gate condition remains true while any duplicate is unresolved.

### Unchanged

- `import_duplicate_checker_test.dart` — detection logic is unchanged.

## Edge Cases

- **Large imports (many duplicates):** per-tab bulk buttons reduce friction to O(1) clicks per tab.
- **Consolidate-bulk with no viable targets:** un-matchable indices stay pending; user must resolve them individually.
- **All rows are duplicates:** user must resolve all before Import enables. The `totalSelected > 0` guard still applies (at least one importable row required).
- **Zero duplicates:** behavior unchanged — Import enables as soon as `totalSelected > 0`.
- **Mid-flow re-parse:** `setBundle` rebuilds the entire state; stale pending entries are discarded.
- **Cancel mid-review:** the wizard's state is discarded. Partial decisions are lost. Accepted.
- **Adapter without consolidate support:** the bulk-action row omits the Consolidate button; per-row `Consolidate` option also not shown by `DiveComparisonCard`. No behavior change from today.

## Risks and Tradeoffs

- **Two state fields (`pendingDuplicateReview` and `duplicateActions` + `selections`) must stay in sync.** Mitigation: all mutations go through the notifier's `copyWith`. A debug assertion can verify "no index is in pending AND in duplicateActions simultaneously" on each emission.
- **More clicks on average.** Users importing many duplicates will spend more time on the review step than today. Mitigation: per-tab bulk buttons take 2 clicks max per tab.
- **Ephemeral state.** Cancelled wizards lose partial decisions. Accepted; persistent draft state is a separate feature.
- **ARB key-prefix inconsistency.** The `universalImport_*` keys land in the `import_wizard/` flow. Not ideal, but renaming them mid-feature rippled through too much code. Tracked as a follow-up.

## Files Touched

**Modified:**

- `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` — add `pendingDuplicateReview` field; extend `setBundle`, `setDuplicateAction`, `toggleSelection`; add `applyBulkAction`, `firstPendingLocation`, `debugSetState` (test-only); add `PendingLocation` type.
- `lib/features/import_wizard/presentation/widgets/review_step.dart` — gate Import button, pending hint bar, banner-copy addendum.
- `lib/features/import_wizard/presentation/widgets/entity_review_list.dart` — sort pending to top, bulk-action row, pass `isPending` to cards.
- `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart` — visual pending state, "Decide" label.
- `lib/l10n/arb/app_en.arb` — add `universalImport_semantics_needsDecision` key.

**Added:**

- `lib/features/import_wizard/presentation/widgets/needs_decision_pill.dart` — shared pill widget.
- `test/features/import_wizard/presentation/widgets/review_step_pending_test.dart`
- `test/features/import_wizard/presentation/providers/issue_200_regression_test.dart`

**Extended:**

- `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

**Unchanged:**

- `lib/features/universal_import/**` — no changes (orphan review step not touched).
- `lib/features/universal_import/data/services/import_duplicate_checker.dart` — detection logic unchanged.
- `lib/features/dive_import/domain/services/dive_matcher.dart` — scoring unchanged.
- `lib/features/import_wizard/data/adapters/*` — adapter interfaces unchanged; the gate and bulk actions respect the existing `supportedDuplicateActions`.
