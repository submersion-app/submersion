# Unified Import Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify all five import flows (UDDF, FIT, HealthKit, Universal, Dive Computer) into a single shared wizard component with source-specific adapters.

**Architecture:** Shared wizard shell with adapter pattern. Each source provides acquisition steps and an adapter that normalizes data into a common `ImportBundle`. Three shared steps (Review, Import, Summary) render identically for all sources. Migration is incremental — one adapter at a time, old and new coexist.

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier), go_router, Drift ORM, Material 3

**Spec:** `docs/superpowers/specs/2026-03-23-unified-import-wizard-design.md`

---

## File Map

### New Files

**Domain models** (`lib/features/import_wizard/domain/models/`):
- `import_bundle.dart` — ImportBundle, ImportSourceInfo, ImportSourceType, ImportEntityType, EntityGroup, EntityItem
- `unified_import_result.dart` — UnifiedImportResult
- `duplicate_action.dart` — DuplicateAction enum
- `wizard_step_def.dart` — WizardStepDef

**Adapter interface** (`lib/features/import_wizard/domain/adapters/`):
- `import_source_adapter.dart` — ImportSourceAdapter abstract class

**State management** (`lib/features/import_wizard/presentation/providers/`):
- `import_wizard_providers.dart` — ImportWizardState, ImportWizardNotifier, provider definitions

**Wizard shell & widgets** (`lib/features/import_wizard/presentation/`):
- `pages/unified_import_wizard.dart` — UnifiedImportWizard page widget
- `widgets/wizard_step_indicator.dart` — Shared step dots-and-lines indicator
- `widgets/review_step.dart` — Tabbed entity review with duplicate handling
- `widgets/entity_review_list.dart` — Per-entity-type scrollable item list
- `widgets/duplicate_action_card.dart` — Tri-state duplicate card wrapper
- `widgets/import_progress_step.dart` — Shared import progress display
- `widgets/import_summary_step.dart` — Shared summary display

**Provider invalidation** (`lib/features/import_wizard/data/services/`):
- `import_provider_invalidator.dart` — Shared invalidation helper

**Adapters** (`lib/features/import_wizard/data/adapters/`):
- `fit_adapter.dart` — FitAdapter
- `healthkit_adapter.dart` — HealthKitAdapter
- `uddf_adapter.dart` — UddfAdapter
- `dive_computer_adapter.dart` — DiveComputerAdapter
- `universal_adapter.dart` — UniversalAdapter

**Tests** (`test/features/import_wizard/`):
- `domain/models/import_bundle_test.dart`
- `domain/models/unified_import_result_test.dart`
- `presentation/providers/import_wizard_notifier_test.dart`
- `presentation/pages/unified_import_wizard_test.dart`
- `presentation/widgets/wizard_step_indicator_test.dart`
- `presentation/widgets/review_step_test.dart`
- `presentation/widgets/entity_review_list_test.dart`
- `presentation/widgets/duplicate_action_card_test.dart`
- `presentation/widgets/import_progress_step_test.dart`
- `presentation/widgets/import_summary_step_test.dart`
- `data/adapters/fit_adapter_test.dart`
- `data/adapters/healthkit_adapter_test.dart`
- `data/adapters/uddf_adapter_test.dart`
- `data/adapters/dive_computer_adapter_test.dart`
- `data/adapters/universal_adapter_test.dart`
- `data/services/import_provider_invalidator_test.dart`

**Tests** (`test/core/presentation/widgets/`):
- `dive_comparison_card_test.dart` (new — no existing test file for this widget)

### Modified Files

- `lib/core/presentation/widgets/dive_comparison_card.dart` — Add tri-state selector mode
- `lib/core/router/app_router.dart` — Update routes to use UnifiedImportWizard
- `lib/features/dive_computer/presentation/providers/download_providers.dart` — Remove auto-import from DownloadNotifier

### Files Removed After Full Migration

**Source files:**

- `lib/features/dive_import/presentation/pages/fit_import_page.dart`
- `lib/features/dive_import/presentation/pages/healthkit_import_page.dart`
- `lib/features/dive_import/presentation/pages/uddf_import_page.dart`
- `lib/features/dive_import/presentation/providers/uddf_import_providers.dart` (review/import logic only — parse logic extracted)
- `lib/features/dive_import/presentation/providers/dive_import_providers.dart` (review/import logic only)
- `lib/features/dive_computer/presentation/pages/device_discovery_page.dart`
- `lib/features/dive_computer/presentation/pages/device_download_page.dart`
- `lib/features/universal_import/presentation/pages/universal_import_page.dart`

**Test files referencing removed code (update or remove):**

- `test/features/dive_import/presentation/pages/uddf_import_page_test.dart`
- `test/features/dive_import/presentation/providers/dive_import_notifier_test.dart`
- `test/features/dive_import/presentation/providers/uddf_import_providers_test.dart`

---

## Task 1: Core Domain Models

**Files:**
- Create: `lib/features/import_wizard/domain/models/import_bundle.dart`
- Create: `lib/features/import_wizard/domain/models/unified_import_result.dart`
- Create: `lib/features/import_wizard/domain/models/duplicate_action.dart`
- Create: `lib/features/import_wizard/domain/models/wizard_step_def.dart`
- Test: `test/features/import_wizard/domain/models/import_bundle_test.dart`
- Test: `test/features/import_wizard/domain/models/unified_import_result_test.dart`

- [ ] **Step 1: Write tests for ImportBundle and related types**

Test `ImportBundle.hasType()`, `availableTypes`, `EntityGroup` construction, `EntityItem` with and without `diveData`. Test that `ImportSourceType` and `ImportEntityType` enums have all expected values.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/domain/models/import_bundle_test.dart`
Expected: FAIL — files don't exist yet.

- [ ] **Step 3: Implement import_bundle.dart**

Create `ImportBundle`, `ImportSourceInfo`, `ImportSourceType`, `ImportEntityType`, `EntityGroup`, `EntityItem`. All immutable with `const` constructors. Reference existing `IncomingDiveData` from `lib/core/domain/models/incoming_dive_data.dart` and `DiveMatchResult` from `lib/features/dive_import/domain/services/dive_matcher.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/domain/models/import_bundle_test.dart`

- [ ] **Step 5: Write tests for UnifiedImportResult**

Test construction, `importedCounts` map access, `consolidatedCount`, `skippedCount`, `errorMessage`.

- [ ] **Step 6: Implement unified_import_result.dart**

Immutable class with `Map<ImportEntityType, int> importedCounts`, `int consolidatedCount`, `int skippedCount`, `String? errorMessage`.

- [ ] **Step 7: Implement duplicate_action.dart**

```dart
enum DuplicateAction { skip, importAsNew, consolidate }
```

- [ ] **Step 8: Implement wizard_step_def.dart**

```dart
class WizardStepDef {
  final String label;
  final IconData? icon;
  final Widget Function(BuildContext) builder;
  final ProviderListenable<bool> canAdvance;
  final bool autoAdvance;
  const WizardStepDef({...});
}
```

- [ ] **Step 9: Run all model tests**

Run: `flutter test test/features/import_wizard/domain/models/`

- [ ] **Step 10: Commit**

```
feat: add core domain models for unified import wizard
```

---

## Task 2: ImportSourceAdapter Interface

**Files:**
- Create: `lib/features/import_wizard/domain/adapters/import_source_adapter.dart`

- [ ] **Step 1: Create the abstract class**

Define `ImportSourceAdapter` with: `sourceType`, `displayName`, `acquisitionSteps`, `supportedDuplicateActions`, `buildBundle()`, `checkDuplicates(bundle)`, `performImport(bundle, selections, duplicateActions, {onProgress})`. Import types from Task 1.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/import_wizard/domain/adapters/import_source_adapter.dart`

- [ ] **Step 3: Commit**

```
feat: add ImportSourceAdapter interface
```

---

## Task 3: ImportWizardNotifier

**Files:**
- Create: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`
- Test: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

- [ ] **Step 1: Write tests for ImportWizardNotifier**

Test the following behaviors with a mock adapter (use Mockito `@GenerateNiceMocks`):
1. `setBundle()` — stores bundle, initializes selections (all non-duplicates selected), initializes duplicate actions (likely → skip, possible → importAsNew)
2. `toggleSelection()` — flips selection for a given entity type and index
3. `selectAll()` / `deselectAll()` — bulk selection for non-duplicate items
4. `setDuplicateAction()` — sets action for a specific duplicate
5. `performImport()` — delegates to adapter with correct selections and actions, stores result
6. State transitions: `isImporting` true during import, result populated after

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

- [ ] **Step 3: Implement ImportWizardState**

Immutable state class with `copyWith`. Fields: `currentStep`, `bundle`, `selections` (`Map<ImportEntityType, Set<int>>`), `duplicateActions` (`Map<ImportEntityType, Map<int, DuplicateAction>>`), `importPhase`, `importCurrent`, `importTotal`, `importResult`, `isImporting`, `error`.

- [ ] **Step 4: Implement ImportWizardNotifier**

`StateNotifier<ImportWizardState>` with `ImportSourceAdapter` and `Ref` parameters. Implement `setBundle()` (initializes selections from bundle's duplicate indices and match results), `toggleSelection()`, `selectAll()`, `deselectAll()`, `setDuplicateAction()`, `performImport()` (delegates to adapter, updates progress, invalidates providers on success), `reset()`.

- [ ] **Step 5: Define providers**

Create `importWizardProvider` as `StateNotifierProvider` with `adapter` parameter. This will be overridden in `ProviderScope` per wizard instance.

- [ ] **Step 6: Run build_runner for mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

- [ ] **Step 8: Commit**

```
feat: add ImportWizardNotifier with selection and duplicate state management
```

---

## Task 4: Provider Invalidation Helper

**Files:**
- Create: `lib/features/import_wizard/data/services/import_provider_invalidator.dart`
- Test: `test/features/import_wizard/data/services/import_provider_invalidator_test.dart`

- [ ] **Step 1: Read existing invalidation logic**

Read `lib/features/dive_import/presentation/providers/uddf_import_providers.dart` to find `_invalidateProviders()` and identify all providers that need invalidation per entity type.

- [ ] **Step 2: Write tests**

Test that `invalidateImportRelatedProviders()` calls `ref.invalidate()` on the correct providers based on which `ImportEntityType`s are in the imported set.

- [ ] **Step 3: Implement invalidation helper**

```dart
void invalidateImportRelatedProviders(Ref ref, Set<ImportEntityType> importedTypes) { ... }
```

Map each `ImportEntityType` to the providers it affects. Reference the existing provider names from the UDDF notifier's invalidation list.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/import_wizard/data/services/import_provider_invalidator_test.dart`

- [ ] **Step 5: Commit**

```
feat: add shared provider invalidation helper for import wizard
```

---

## Task 5: WizardStepIndicator Widget

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/wizard_step_indicator.dart`
- Test: `test/features/import_wizard/presentation/widgets/wizard_step_indicator_test.dart`

- [ ] **Step 1: Write widget tests**

Test that the indicator renders the correct number of dots based on step count. Test that the active step is visually distinguished (check for primary color). Test that completed steps show a checkmark icon. Test label text rendering.

Reference the existing pattern from `lib/features/dive_import/presentation/pages/uddf_import_page.dart` lines 59-163 (`_StepIndicator`, `_StepDot`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/presentation/widgets/wizard_step_indicator_test.dart`

- [ ] **Step 3: Implement WizardStepIndicator**

A reusable widget that accepts `List<String> labels`, `int currentStep`, and renders the dots-and-lines step indicator. Use 32px dots, 2px connecting lines, `colorScheme.primary` for active/completed, `colorScheme.outlineVariant` for future steps. Checkmark icon for completed steps, step number for active/future.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/presentation/widgets/wizard_step_indicator_test.dart`

- [ ] **Step 5: Commit**

```
feat: add reusable WizardStepIndicator widget
```

---

## Task 6: DiveComparisonCard Tri-State Refactor

**Files:**
- Modify: `lib/core/presentation/widgets/dive_comparison_card.dart`
- Create: `test/core/presentation/widgets/dive_comparison_card_test.dart` (no existing test file for this widget)

- [ ] **Step 1: Read the existing DiveComparisonCard**

Read `lib/core/presentation/widgets/dive_comparison_card.dart` fully to understand current parameters and widget structure.

- [ ] **Step 2: Create test file with tests for new tri-state behavior**

Create `test/core/presentation/widgets/dive_comparison_card_test.dart`. Test that when `selectedAction` is provided, the card renders action buttons as toggles (active button highlighted, inactive outlined). Test that `onActionChanged` fires with the correct `DuplicateAction` when a button is tapped. Test that `availableActions` controls which buttons appear (e.g., no Consolidate button when not in the set).

- [ ] **Step 3: Add new parameters to DiveComparisonCard**

Add optional parameters alongside existing ones for backwards compatibility during migration:
- `selectedAction: DuplicateAction?` — if non-null, enables tri-state mode
- `onActionChanged: Function(DuplicateAction)?` — fires when user toggles action
- `availableActions: Set<DuplicateAction>?` — which buttons to show

When `selectedAction` is non-null, render buttons as toggles instead of immediate-action buttons. When null, use existing `onSkip`/`onImportAsNew`/`onConsolidate` callbacks (backwards compatible).

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/presentation/widgets/dive_comparison_card_test.dart`

- [ ] **Step 5: Commit**

```
feat: add tri-state selector mode to DiveComparisonCard
```

---

## Task 7a: DuplicateActionCard & EntityReviewList

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart`
- Create: `lib/features/import_wizard/presentation/widgets/entity_review_list.dart`
- Create: `test/features/import_wizard/presentation/widgets/duplicate_action_card_test.dart`
- Create: `test/features/import_wizard/presentation/widgets/entity_review_list_test.dart`

- [ ] **Step 1: Write tests for DuplicateActionCard**

Test that likely duplicates default to Skip action. Test that possible duplicates default to ImportAsNew. Test that tapping an action button updates via `onActionChanged`. Test that `availableActions` controls which buttons appear. Test expandable/collapsible behavior.

- [ ] **Step 2: Implement DuplicateActionCard**

A wrapper widget that shows a collapsed duplicate summary (match percentage badge, current action badge, expand chevron) and expands to show the `DiveComparisonCard` in tri-state mode. Uses the card's border color based on match confidence (red for likely, orange for possible).

- [ ] **Step 3: Write tests for EntityReviewList**

Create `test/features/import_wizard/presentation/widgets/entity_review_list_test.dart`. Test that non-duplicate items render with checkboxes. Test that duplicate items render as `DuplicateActionCard`s (not checkboxes). Test Select All / Deselect All only affects checkbox items. Test item count display.

- [ ] **Step 4: Implement EntityReviewList**

A scrollable list for a single entity type. Accepts `EntityGroup`, `Set<int> selectedIndices`, `Map<int, DuplicateAction> duplicateActions`, `Set<DuplicateAction> availableActions`, and callbacks for selection/action changes. Renders:
- Header with item count and Select All / Deselect All links
- Non-duplicate items: checkbox + title/subtitle from EntityItem
- Duplicate items: `DuplicateActionCard` with match info from `EntityGroup.matchResults`

Divides items into sections: non-duplicates at top, then likely duplicates, then possible duplicates.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/import_wizard/presentation/widgets/duplicate_action_card_test.dart test/features/import_wizard/presentation/widgets/entity_review_list_test.dart`

- [ ] **Step 6: Commit**

```
feat: add DuplicateActionCard and EntityReviewList widgets
```

---

## Task 7b: ReviewStep (Tab Bar & Bottom Bar)

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/review_step.dart`
- Create: `test/features/import_wizard/presentation/widgets/review_step_test.dart`

- [ ] **Step 1: Write tests for ReviewStep**

Test single-entity-type: no tab bar shown, renders EntityReviewList directly. Test multi-entity-type: TabBar with correct tabs and count badges. Test bottom bar shows aggregate counts and "Import Selected" button.

- [ ] **Step 2: Implement ReviewStep**

Reads `ImportBundle` from `ImportWizardNotifier`. If single entity type, renders `EntityReviewList` directly. If multiple, renders `TabBar` + `TabBarView` with one `EntityReviewList` per type. Bottom bar shows "N importing, N consolidating, N skipping" and "Import Selected" `FilledButton`.

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/import_wizard/presentation/widgets/review_step_test.dart`

- [ ] **Step 4: Commit**

```
feat: add shared ReviewStep with tabbed entity lists and bottom bar
```

---

## Task 8: Import Progress & Summary Step Widgets

**Files:**
- Create: `lib/features/import_wizard/presentation/widgets/import_progress_step.dart`
- Create: `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`
- Create: `test/features/import_wizard/presentation/widgets/import_progress_step_test.dart`
- Create: `test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`

- [ ] **Step 1: Write tests for ImportProgressStep**

Test that phase text and progress bar render based on provider state. Test that completed phases show checkmarks. Test that pending phases are dimmed.

- [ ] **Step 2: Implement ImportProgressStep**

Reads `importPhase`, `importCurrent`, `importTotal` from `ImportWizardNotifier`. Renders:
- Circular progress indicator with percentage
- Phase text with current/total count
- Linear progress bar
- Phase list: completed (checkmark + count), active (arrow + count), pending (dimmed)

- [ ] **Step 3: Write tests for ImportSummaryStep**

Test that per-entity-type counts render. Test that consolidated and skipped counts display when > 0. Test error state renders error message and "Done" button. Test "Done" and "View Dives" button callbacks fire.

- [ ] **Step 4: Implement ImportSummaryStep**

Reads `importResult` from `ImportWizardNotifier`. Renders:
- Success icon (green circle with checkmark)
- "Successfully Imported" title
- Per-entity-type rows from `importedCounts` (icon + label + bold count)
- Consolidated count row (if > 0)
- Skipped count row
- "Done" (outlined) and "View Dives" (filled) buttons
- Error state: shows error message + "Done" button if `errorMessage` is set

Accept callbacks `onDone` and `onViewDives` for navigation.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/import_wizard/presentation/widgets/import_progress_step_test.dart test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`

- [ ] **Step 6: Commit**

```
feat: add shared Import Progress and Summary step widgets
```

---

## Task 9: UnifiedImportWizard Shell

**Files:**
- Create: `lib/features/import_wizard/presentation/pages/unified_import_wizard.dart`
- Create: `test/features/import_wizard/presentation/pages/unified_import_wizard_test.dart`

- [ ] **Step 1: Implement UnifiedImportWizard**

`ConsumerStatefulWidget` that accepts an `ImportSourceAdapter`. Wraps content in a `ProviderScope` override for `importWizardProvider`.

Structure:
- `Scaffold` with `AppBar` (close button with exit confirmation dialog)
- `Column` with `WizardStepIndicator` + `Expanded` `PageView`
- `PageView` pages: adapter's acquisition step widgets + ReviewStep + ImportProgressStep + ImportSummaryStep
- `PageController` with `NeverScrollableScrollPhysics`
- `ref.listen` on `ImportWizardNotifier` state to animate page transitions
- Watch `canAdvance` for current step to enable/disable Next button
- Auto-advance logic: when `canAdvance` becomes true and `autoAdvance` is set, animate to next page
- Bottom action bar in `SafeArea`: Back button (if not first step), Next/Import button

Exit confirmation dialog messages vary by state:
- During acquisition: "Cancel import?"
- During review: "Discard selections and cancel?"
- During import: "Import is in progress and cannot be cancelled." (disable close)
- After summary: no confirmation

- [ ] **Step 2: Create a stub adapter for manual testing**

A `StubAdapter` that provides one acquisition step (a simple "Done" button) and returns a hard-coded `ImportBundle` with 3 dive `EntityItem`s. Useful for development/testing the wizard shell without a real source.

- [ ] **Step 3: Temporarily wire up a test route**

Add a temporary route `/transfer/wizard-test` in `app_router.dart` that creates `UnifiedImportWizard(adapter: StubAdapter())`. This allows manual testing of the wizard shell.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run -d macos`
Navigate to Transfer > test the stub wizard. Verify: step indicator, page transitions, exit confirmation, review step rendering, import progress, summary.

- [ ] **Step 5: Write widget tests for the wizard shell**

Test with StubAdapter: step indicator renders correct number of steps. Test page transitions when advancing. Test auto-advance when `canAdvance` provider becomes true and `autoAdvance` is set. Test exit confirmation dialog shows correct message per state (acquisition, review, import, summary). Test that "Next" button is disabled when `canAdvance` is false.

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/import_wizard/presentation/pages/unified_import_wizard_test.dart`

- [ ] **Step 7: Remove test route, commit**

Remove the `/transfer/wizard-test` route. Keep the StubAdapter in test code only.

```
feat: add UnifiedImportWizard shell with step navigation and exit handling
```

---

## Task 10: FIT Adapter

**Files:**
- Create: `lib/features/import_wizard/data/adapters/fit_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/fit_adapter_test.dart`

- [ ] **Step 1: Write tests for FitAdapter.buildBundle()**

Test that given a list of `ImportedDive`s, `buildBundle()` returns an `ImportBundle` with:
- `sourceType: ImportSourceType.fit`
- A single `ImportEntityType.dives` group
- `EntityItem`s with correct title (formatted date), subtitle (depth, duration, temp), and `diveData` populated from `ImportedDive`

- [ ] **Step 2: Write tests for FitAdapter.checkDuplicates()**

Test that `checkDuplicates()` runs `DiveMatcher` against existing dives and populates `duplicateIndices` and `matchResults` on the dives `EntityGroup`.

- [ ] **Step 3: Write tests for FitAdapter.performImport()**

Test that `performImport()` calls `ImportedDiveConverter` for selected indices, saves via `DiveRepository`, and returns correct `UnifiedImportResult` counts. Test that deselected indices are skipped. Test that `DuplicateAction.skip` items are counted as skipped.

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/fit_adapter_test.dart`

- [ ] **Step 5: Implement FitAdapter**

Extend `ImportSourceAdapter`.

Acquisition steps:
1. "Select Files" — file picker step widget (extracted from existing `FitImportPage` step 0 logic). Uses `FitParserService` to parse selected files. Exposes a `canAdvance` provider that becomes true when at least one dive is parsed.

`buildBundle()`: convert `List<ImportedDive>` to `EntityItem`s with `IncomingDiveData` from each ImportedDive's fields.

`checkDuplicates()`: use `DiveMatcher` against existing dives (fetch from `DiveRepository`).

`performImport()`: iterate selected indices, call `ImportedDiveConverter.convert()` then `DiveRepository.insertDive()` for each. For `DuplicateAction.importAsNew` items, also import. Report progress via `onProgress`.

`supportedDuplicateActions`: `{DuplicateAction.skip, DuplicateAction.importAsNew}`.

- [ ] **Step 6: Run build_runner for mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/fit_adapter_test.dart`

- [ ] **Step 8: Commit**

```
feat: add FIT import adapter for unified import wizard
```

---

## Task 11: FIT Adapter Route Integration

**Files:**
- Modify: `lib/core/router/app_router.dart`

**Note:** The spec lists two FIT acquisition steps ("Pick files" and "Parse"). The adapter combines these into a single "Select Files" step that picks and parses in one action, since parsing is automatic and requires no user interaction. This is a practical simplification.

**Note:** `FitImportPage` has no existing test file, so removing it does not break any tests.

- [ ] **Step 1: Update the FIT import route**

Change the `/transfer/fit-import` route from `FitImportPage` to `UnifiedImportWizard(adapter: FitAdapter(...))`. Pass required dependencies (repositories, services) via Riverpod.

- [ ] **Step 2: Manual smoke test**

Run: `flutter run -d macos`
Navigate to Transfer > Import > FIT. Verify: file picker, dive list in review step, duplicate detection, import, summary.

- [ ] **Step 3: Run existing FIT tests**

Run: `flutter test test/features/dive_import/data/services/fit_parser_service_test.dart`
Verify existing tests still pass (parser unchanged).

- [ ] **Step 4: Commit**

```
feat: wire FIT import to unified import wizard
```

---

## Task 12: HealthKit Adapter

**Files:**
- Create: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/healthkit_adapter_test.dart`

- [ ] **Step 1: Write tests for HealthKitAdapter**

Test `buildBundle()` converts `List<ImportedDive>` to correct `ImportBundle`. Test `checkDuplicates()` uses `DiveMatcher`. Test `performImport()` uses `ImportedDiveConverter` and returns correct counts.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/healthkit_adapter_test.dart`

- [ ] **Step 3: Implement HealthKitAdapter**

Similar to FitAdapter but with three acquisition steps:
1. "Permissions" — request HealthKit access via `HealthKitService.requestPermissions()`. `canAdvance` true when permissions granted.
2. "Date Range" — date range picker widget (extracted from existing `HealthKitImportPage`). `canAdvance` true when range selected.
3. "Fetch" — fetch dives via `HealthKitService.fetchDives()`. `autoAdvance: true` — automatically advances to Review when fetch completes.

`supportedDuplicateActions`: `{DuplicateAction.skip, DuplicateAction.importAsNew}`.

`buildBundle()`, `checkDuplicates()`, `performImport()` — same pattern as FitAdapter (both use `ImportedDive` and `ImportedDiveConverter`).

- [ ] **Step 4: Run build_runner for mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/healthkit_adapter_test.dart`

- [ ] **Step 6: Update route and smoke test**

Change `/settings/wearable-import` route from `HealthKitImportPage` to `UnifiedImportWizard(adapter: HealthKitAdapter(...))`.

Run: `flutter run -d macos` (HealthKit only available on iOS/macOS — test on macOS if possible, otherwise verify compilation only).

- [ ] **Step 6: Commit**

```
feat: add HealthKit adapter and wire to unified import wizard
```

**Note for all adapter tasks:** Each adapter's acquisition step widgets must include inline error handling — error messages with retry buttons for failures (file parse errors, permission denials, connection timeouts). The wizard shell does not manage acquisition errors; each step widget handles its own via the source-specific notifier. The `canAdvance` provider stays `false` until errors are resolved.

---

## Task 13: UDDF Adapter

**Files:**
- Create: `lib/features/import_wizard/data/adapters/uddf_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/uddf_adapter_test.dart`

This is the most data-rich adapter — it produces up to 11 entity types.

- [ ] **Step 1: Write tests for UddfAdapter.buildBundle()**

Test that given a `UddfImportResult`, `buildBundle()` returns an `ImportBundle` with the correct entity types populated (dives, sites, buddies, equipment, trips, certifications, diveCenters, tags, diveTypes, equipmentSets, courses). Test `EntityItem` title/subtitle formatting for each entity type. Test that empty entity lists are omitted from the bundle (no empty tabs).

- [ ] **Step 2: Write tests for UddfAdapter.checkDuplicates()**

Test that `checkDuplicates()` calls `UddfDuplicateChecker` and maps the result into `duplicateIndices` per entity type and `matchResults` for dives.

- [ ] **Step 3: Write tests for UddfAdapter.performImport()**

Test that `performImport()` calls `UddfEntityImporter.import()` with the correct `UddfImportSelections` built from the wizard's selections map. Test that `DuplicateAction.skip` items are excluded from selections. Test that `DuplicateAction.importAsNew` items are included. Test progress callback forwarding.

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/uddf_adapter_test.dart`

- [ ] **Step 5: Implement UddfAdapter**

Acquisition steps:
1. "Select File" — file picker for .uddf/.xml files (extracted from existing `UddfImportPage` step 0). `canAdvance` true when file parsed successfully.

`buildBundle()`: iterate each entity type in `UddfImportResult`, create `EntityItem` per item using map keys for title/subtitle. For dives, populate `diveData` via `IncomingDiveData.fromImportMap()`. Skip entity types with empty lists.

`checkDuplicates()`: call `UddfDuplicateChecker.check()` with existing entities from repositories. Map `UddfDuplicateCheckResult` fields to `EntityGroup.duplicateIndices` per type. Map `diveMatches` to `EntityGroup.matchResults`.

`performImport()`: build `UddfImportSelections` from the selections map. For dive duplicates with `DuplicateAction.importAsNew`, include in selection set. For `DuplicateAction.skip`, exclude. Call `UddfEntityImporter.import()`. Convert `UddfEntityImportResult` to `UnifiedImportResult`.

`supportedDuplicateActions`: `{DuplicateAction.skip, DuplicateAction.importAsNew}`.

- [ ] **Step 6: Run build_runner for mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/uddf_adapter_test.dart`

- [ ] **Step 8: Update route and smoke test**

Change `/transfer/uddf-import` route to `UnifiedImportWizard(adapter: UddfAdapter(...))`.

Run: `flutter run -d macos`. Test with a UDDF file: verify all entity tabs appear, duplicate badges, selection, import, summary counts.

- [ ] **Step 8: Commit**

```
feat: add UDDF adapter with multi-entity-type support for unified import wizard
```

---

## Task 13b: Slim Down DownloadNotifier

This must be done **after** the dive computer route is updated (Task 14 Step 8), so the old pages no longer reference these methods.

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`

- [ ] **Step 1: Remove auto-import from DownloadNotifier**

Remove from `DownloadState`: `importResult`, `pendingConsolidations`, `candidatesResolved`, `totalImported` getter.

Remove from `DownloadNotifier`: `_persistDeviceInfoAndImport()` auto-import call from `_onDownloadComplete`, `importDives()`, `consolidateDive()`, `importCandidateAsNew()`, `skipConsolidation()`.

Keep: download phase management, progress tracking, PIN handling, serialNumber/firmwareVersion extraction.

- [ ] **Step 2: Run existing download notifier tests**

Run: `flutter test test/features/dive_computer/`
Update or remove tests that reference removed methods/state.

- [ ] **Step 3: Commit**

```
refactor: slim DownloadNotifier to acquisition-only (remove auto-import)
```

---

## Task 14: Dive Computer Adapter

**Files:**
- Create: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`

This is the most complex adapter and the biggest behavioral change. DownloadNotifier slimming is deferred to Task 13b (after route update).

- [ ] **Step 1: Write tests for DiveComputerAdapter.buildBundle()**

Test that given `List<DownloadedDive>` and a `DiveComputer`, `buildBundle()` returns an `ImportBundle` with dives group. Test `EntityItem` title (formatted date), subtitle (depth, duration), and `diveData` populated via `IncomingDiveData.fromDownloadedDive()`.

- [ ] **Step 2: Write tests for DiveComputerAdapter.checkDuplicates()**

Test that `checkDuplicates()` uses `DiveImportService.detectDuplicate()` to find matches and populates `duplicateIndices` and `matchResults`.

- [ ] **Step 3: Write tests for DiveComputerAdapter.performImport()**

Test four cases:

1. Selected non-duplicate dive — calls `DiveImportService` to import as new dive
2. `DuplicateAction.importAsNew` — imports as a separate new dive
3. `DuplicateAction.consolidate` — calls `DiveRepository.consolidateComputer()` with secondary reading
4. `DuplicateAction.skip` — skipped, counted in result

Test progress callback. Test fingerprint update on computer record after import.

- [ ] **Step 4: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`

- [ ] **Step 5: Implement DiveComputerAdapter**

Extend `ImportSourceAdapter`. Two variants based on `knownComputer` parameter:

**Discovery (new computer)** acquisition steps:
1. "Scan" — `ScanStepWidget` (reuse existing). `canAdvance` when device selected.
2. "Pair" — connection/pairing step. `autoAdvance: true` when connected.
3. "Confirm" — device confirmation with custom name. `canAdvance` when user taps confirm.
4. "Download" — `DownloadStepWidget` (reuse existing, but do NOT auto-import). `autoAdvance: true` when download completes.

**Quick download (known computer)** acquisition steps:
1. "Download" — auto-scan for known device + download. `autoAdvance: true`.

`buildBundle()`: convert `List<DownloadedDive>` to `EntityItem`s with `IncomingDiveData.fromDownloadedDive()`.

`checkDuplicates()`: use `DiveImportService.detectDuplicate()` for each dive.

`performImport()`: for each selected dive, route by action:
- Normal import or `importAsNew`: call `DiveImportService.importDives()` with single dive
- `consolidate`: call `DiveRepository.consolidateComputer()` with secondary reading data (extracted from `DownloadedDive`)
Update computer fingerprint after successful import.

`supportedDuplicateActions`: `{DuplicateAction.skip, DuplicateAction.importAsNew, DuplicateAction.consolidate}`.

- [ ] **Step 6: Run build_runner for mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`

- [ ] **Step 8: Update routes**

Change `/dive-computers/discover` route to `UnifiedImportWizard(adapter: DiveComputerAdapter())`.
Change `/dive-computers/:computerId/download` route to `UnifiedImportWizard(adapter: DiveComputerAdapter(known: computer))`.

**Important:** Do this BEFORE Task 13b (slim DownloadNotifier), so old pages are no longer referenced when methods are removed.

- [ ] **Step 9: Manual smoke test**

Run: `flutter run -d macos`
Test both flows: discovery (new computer) and quick download (saved computer). Verify: BLE scan, download progress, review step with duplicates, consolidation action, import, summary.

- [ ] **Step 10: Commit**

```
feat: add dive computer adapter with consolidation support for unified import wizard
```

After this commit, proceed to **Task 13b** to slim down `DownloadNotifier`.

---

## Task 15: Universal Adapter

**Files:**
- Create: `lib/features/import_wizard/data/adapters/universal_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/universal_adapter_test.dart`

- [ ] **Step 1: Write tests for UniversalAdapter**

Test `buildBundle()` for CSV-detected format (dives only). Test `checkDuplicates()`. Test `performImport()` routes to correct format-specific importer.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`

- [ ] **Step 3: Implement UniversalAdapter**

Acquisition steps:
1. "Select File" — `FileSelectionStep` (reuse from existing `universal_import/presentation/widgets/file_selection_step.dart`)
2. "Confirm Source" — `SourceConfirmationStep` (reuse from existing)
3. "Field Mapping" — `FieldMappingStep` (reuse from existing, shown only for CSV). `canAdvance` when mapping confirmed. For non-CSV formats, use `autoAdvance: true` to skip.

`buildBundle()`, `checkDuplicates()`, `performImport()`: delegate to the existing universal import service logic based on detected format.

`supportedDuplicateActions`: `{DuplicateAction.skip, DuplicateAction.importAsNew}`.

- [ ] **Step 4: Run build_runner for mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`

- [ ] **Step 6: Update route**

Change `/transfer/import-wizard` from `UniversalImportPage` to `UnifiedImportWizard(adapter: UniversalAdapter(...))`.

- [ ] **Step 6: Commit**

```
feat: add universal adapter for unified import wizard
```

---

## Task 16: Cleanup Old Import Pages

**Files:**
- Remove: old import page files (see File Map above)
- Modify: `lib/core/router/app_router.dart` — remove old imports

- [ ] **Step 1: Verify all routes use new wizard**

Grep for any remaining references to `FitImportPage`, `HealthKitImportPage`, `UddfImportPage`, `DeviceDiscoveryPage`, `DeviceDownloadPage`, `UniversalImportPage` in router and ensure all are replaced.

- [ ] **Step 2: Delete old page files**

Delete the files listed in "Files Removed After Full Migration" in the File Map. Keep the old notifiers' parse/acquisition logic if it was extracted into separate files; delete the review/import/summary logic that moved to `ImportWizardNotifier`.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Verify no test failures from removed files. Update or remove tests that reference deleted pages/notifiers.

- [ ] **Step 4: Run format and analyze**

Run: `dart format lib/ test/ && flutter analyze`

- [ ] **Step 5: Commit**

```
refactor: remove old import pages replaced by unified import wizard
```

---

## Task 17: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
All tests must pass.

- [ ] **Step 2: Run format and analyze**

Run: `dart format --set-exit-if-changed lib/ test/ && flutter analyze`
No warnings or formatting issues.

- [ ] **Step 3: Manual smoke test all five flows**

Run: `flutter run -d macos`
Test each import source end-to-end:
1. Transfer > Import > Auto-Detect (Universal)
2. Transfer > Import > UDDF
3. Transfer > Import > FIT
4. Transfer > Computers > Connect New Computer
5. Transfer > Computers > Download from Saved Computer
6. Transfer > Computers > Apple Watch (HealthKit, iOS only)

Verify for each: acquisition steps, review step, duplicate handling, import progress, summary, Done/View Dives navigation.

- [ ] **Step 4: Commit any final fixes**

```
fix: address issues found in final verification
```
