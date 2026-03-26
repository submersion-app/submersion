# Unified Import Wizard

**Date:** 2026-03-23
**Status:** Design

## Problem

Submersion has five separate import flows (UDDF, FIT, HealthKit, Universal/CSV, Dive Computer) with inconsistent UIs and different behavioral patterns. The dive computer flow auto-imports on download completion, while file imports let the user review and select before saving. Each flow has its own wizard implementation with duplicated step indicator, navigation, and summary code.

## Goal

Unify all import flows into a single shared wizard component. Multiple entry points feed source-specific acquisition steps into identical Review, Import, and Summary steps. The user always reviews and selects before anything is saved.

## Architecture: Shared Wizard Shell with Source Adapters

### Two-Phase Flow

Every import follows the same pattern:

1. **Source-specific acquisition** - Each source handles data acquisition differently (BLE discovery, file picking, HealthKit permissions, etc.)
2. **Shared wizard steps** - Once data is acquired and normalized, all sources use identical Review, Import Progress, and Summary steps.

Sources produce an `ImportBundle` at the boundary between phases. The wizard shell renders the step indicator, manages navigation, and hosts both acquisition and shared steps.

### UnifiedImportWizard Widget

A single `UnifiedImportWizard` widget provides:

- **Step indicator** - Standardized 32px dot-and-line stepper. Step labels and count adapt based on the source's acquisition steps plus the 3 shared steps.
- **PageView navigation** - Animated transitions (300ms easeInOut). No manual swiping.
- **Cancel/close handling** - AppBar close button with confirmation dialog. If import is in progress, warns about data loss.
- **Bottom action bar** - Consistent SafeArea bar with back/next buttons, selection counts.

## ImportBundle Data Model

The contract between source adapters and the shared wizard steps.

### ImportBundle

```dart
class ImportBundle {
  final ImportSourceInfo source;
  final Map<ImportEntityType, EntityGroup> groups;

  bool hasType(ImportEntityType type) => groups.containsKey(type);
  List<ImportEntityType> get availableTypes => groups.keys.toList();
}

class ImportSourceInfo {
  final ImportSourceType type; // diveComputer, uddf, fit, healthKit, universal
  final String displayName;   // "Shearwater Perdix", "dive_log.uddf", etc.
  final Map<String, dynamic> metadata; // Source-specific extras
}

enum ImportSourceType { diveComputer, uddf, fit, healthKit, universal }

enum ImportEntityType {
  dives, sites, buddies, equipment, trips,
  certifications, diveCenters, tags, diveTypes,
  equipmentSets, courses,
}
```

### EntityGroup & EntityItem

```dart
class EntityGroup {
  final List<EntityItem> items;
  final Set<int> duplicateIndices;              // Auto-deselected duplicates
  final Map<int, DiveMatchResult>? matchResults; // Dives only: per-item match scores + matched dive ID
}

class EntityItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final IncomingDiveData? diveData; // Present for dive items, enables comparison cards
}
```

The adapter normalizes its native data into `EntityItem` display models for the Review step, but retains the raw source data internally. The `diveData` field on dive items enables the existing `DiveComparisonCard` and `OverlaidProfileChart` widgets for duplicate review.

**Duplicate detection varies by entity type:**

- **Dives** use scored fuzzy matching via `DiveMatcher`. The `matchResults` map provides per-item scores. Items with score >= 0.7 are "likely" duplicates (auto-deselected, three-action card). Items with score >= 0.5 are "possible" duplicates (three-action card, defaults to Import as New).
- **Non-dive entities** (sites, buddies, tags, etc.) use binary exact matching via `UddfDuplicateChecker` (name match, agency+level match, etc.). Detected duplicates go into `duplicateIndices` and are auto-deselected. They use simple checkbox UI, not the three-action card — "consolidate" is not meaningful for non-dive entities.

## Source Adapters

### WizardStepDef

Each step (acquisition or shared) is defined by a `WizardStepDef`:

```dart
class WizardStepDef {
  final String label;                        // Step indicator label ("Scan", "Review", etc.)
  final IconData? icon;                      // Optional icon for the step dot
  final Widget Function(BuildContext) builder; // Step content widget
  final ProviderListenable<bool> canAdvance;  // Wizard enables "Next" when true
  final bool autoAdvance;                     // Auto-transition when canAdvance becomes true
}
```

The `canAdvance` provider is how acquisition steps communicate completion to the wizard shell. For example, the dive computer download step exposes a provider that emits `true` when `DownloadPhase.complete` is reached. The wizard shell watches `canAdvance` for the current step: when it becomes `true`, it either enables the "Next" button or auto-advances (if `autoAdvance` is set).

Auto-advance is useful for steps that complete without user interaction (e.g., file parsing, download completion). Steps requiring explicit user action (e.g., device selection, date range picking) leave `autoAdvance: false`.

### ImportSourceAdapter Interface

```dart
abstract class ImportSourceAdapter {
  ImportSourceType get sourceType;
  String get displayName;

  /// Source-specific acquisition step definitions
  List<WizardStepDef> get acquisitionSteps;

  /// Normalize acquired data into the common model
  Future<ImportBundle> buildBundle();

  /// Run duplicate detection against existing database
  Future<ImportBundle> checkDuplicates(ImportBundle bundle);

  /// Which duplicate actions are available for this source's dives
  Set<DuplicateAction> get supportedDuplicateActions;

  /// Save selected items using raw source data
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    void Function(String phase, int current, int total)? onProgress,
  });
}
```

### Adapter Implementations

#### DiveComputerAdapter

- **Acquisition steps:** Scan for devices, Select & pair, Confirm device, Download dives
- **Retains:** `List<DownloadedDive>`, computer info
- **Duplicate detection:** Fingerprint + DiveMatcher
- **Import via:** DiveImportService
- **Bundle contents:** dives only (extensible for future entity types)
- **Quick download variant:** Accepts optional `knownComputer` parameter that collapses acquisition to a single "Connecting & Downloading" step (auto-scans for known device by address/serial).

**Behavioral change:** Download no longer auto-imports. When download completes, the adapter packages the `DownloadedDive` list into an `ImportBundle` and the wizard transitions to the Review step.

**Supported duplicate actions:** Skip, Import as New, Consolidate. The "Consolidate" action is meaningful here because two dive computers may record the same physical dive — consolidation adds the incoming computer's reading as a secondary record on the matched dive.

#### UddfAdapter

- **Acquisition steps:** Pick UDDF/XML file, Parse file contents
- **Retains:** `UddfImportResult` (raw maps)
- **Duplicate detection:** UddfDuplicateChecker
- **Import via:** UddfEntityImporter
- **Bundle contents:** dives, sites, buddies, equipment, trips, certifications, dive centers, tags, dive types, equipment sets, courses
- **Supported duplicate actions:** Skip, Import as New. No Consolidate — UDDF dives are not from a second physical computer on the same dive.

#### FitAdapter

- **Acquisition steps:** Pick .fit file(s), Parse binary FIT data
- **Retains:** `List<ImportedDive>`
- **Duplicate detection:** DiveMatcher
- **Import via:** ImportedDiveConverter + DiveRepository
- **Bundle contents:** dives only
- **Supported duplicate actions:** Skip, Import as New. No Consolidate.

#### HealthKitAdapter

- **Acquisition steps:** Request HealthKit permissions, Select date range, Fetch dive workouts
- **Retains:** `List<ImportedDive>`
- **Duplicate detection:** DiveMatcher
- **Import via:** ImportedDiveConverter + DiveRepository
- **Bundle contents:** dives only
- **Supported duplicate actions:** Skip, Import as New. No Consolidate.

#### UniversalAdapter

- **Acquisition steps:** Pick file, Auto-detect source app, Field mapping (CSV only)
- **Retains:** Parsed data per detected format
- **Duplicate detection:** DiveMatcher
- **Import via:** Format-specific importer
- **Bundle contents:** varies by detected format
- **Supported duplicate actions:** Skip, Import as New. No Consolidate.

## Shared Review Step

The review step is the core of the unified experience. It has two distinct interaction models based on whether an item is a duplicate.

### Tab Bar

- Only entity types present in the `ImportBundle` get tabs.
- Single entity type (dive computer, FIT, HealthKit): tab bar is hidden entirely; shows dive list directly.
- Multiple entity types (UDDF): scrollable tab bar with count badges per tab.

### Non-Duplicate Items

Simple checkbox toggle. Binary choice: import or skip. Selected by default.

### Duplicate Items (Likely & Possible)

No checkbox. Instead, a three-action card (or two-action for sources that don't support Consolidate):

| Action | Description | Available For |
|--------|-------------|---------------|
| **Skip** | Don't import this item | All sources |
| **Import as New** | Create a separate dive entry | All sources |
| **Consolidate** | Add as secondary computer reading on the matched dive | Dive computer only |

The adapter's `supportedDuplicateActions` determines which buttons appear. The review step queries this to render the appropriate actions per source.

Default action varies by confidence:

- **Likely duplicates** (score >= 0.7): defaults to **Skip**
- **Possible duplicates** (score >= 0.5): defaults to **Import as New**

Cards are expandable to reveal the `DiveComparisonCard` with:

- Incoming vs. existing field comparison
- Overlaid dive profile chart
- Action buttons as tri-state (or bi-state) toggles (active action highlighted)

The collapsed card shows a compact badge with the current action and match percentage.

### Select All / Deselect All

Applies to non-duplicate checkbox items only. Duplicate items retain their individual three-action state.

### Bottom Bar

Shows aggregate counts: "9 importing, 1 consolidating, 2 skipping" and an "Import Selected" button.

## Import Progress Step

- Circular percentage indicator + linear progress bar
- Current phase highlighted with item count ("Importing dives... 8 of 12")
- Completed phases shown with checkmarks and final counts
- Pending phases shown dimmed
- Adapter's `performImport` drives progress via `onProgress(phase, current, total)` callback
- No cancel once import begins (data integrity)

## Summary Step

- Success icon with per-entity-type import counts
- Consolidated dives counted separately from new imports
- Skipped duplicates shown for transparency
- Two actions:
  - **Done** - returns to Transfer page
  - **View Dives** - navigates to `/dives`

## State Management

### Source-Specific Providers (Acquisition Only)

Each source retains its own notifier for acquisition state:

| Provider | Responsibility | Changes |
|----------|---------------|---------|
| `DiscoveryNotifier` | BLE scan, device selection, pairing | Unchanged |
| `DownloadNotifier` | Download progress, PIN handling | Slimmed: no longer auto-imports |
| `UddfParseNotifier` | File picking, UDDF parsing | Extracted from UddfImportNotifier |
| `FitParseNotifier` | FIT file picking & binary parsing | Extracted from DiveImportNotifier |
| `HealthKitNotifier` | Permissions, date range, fetch | Extracted from DiveImportNotifier |

### ImportWizardNotifier (Shared)

Manages everything after acquisition:

```dart
class ImportWizardState {
  final int currentStep;
  final ImportBundle? bundle;
  final Map<ImportEntityType, Set<int>> selections;
  final Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions;
  final String? importPhase;
  final int importCurrent;
  final int importTotal;
  final UnifiedImportResult? importResult;
  final bool isImporting;
  final String? error;
}

enum DuplicateAction { skip, importAsNew, consolidate }

class ImportWizardNotifier extends StateNotifier<ImportWizardState> {
  final ImportSourceAdapter adapter;
  final Ref ref; // For provider invalidation

  void setBundle(ImportBundle bundle);
  void toggleSelection(ImportEntityType type, int index);
  void selectAll(ImportEntityType type);
  void deselectAll(ImportEntityType type);
  void setDuplicateAction(ImportEntityType type, int index, DuplicateAction action);
  Future<void> performImport(); // Delegates to adapter, then invalidates providers
  void reset();
}
```

Scoped per wizard instance via `ProviderScope` override. Each import session gets independent state.

### UnifiedImportResult

A new result type that accommodates both per-entity-type counts (UDDF) and simple dive-only counts:

```dart
class UnifiedImportResult {
  final Map<ImportEntityType, int> importedCounts; // Per-type: {dives: 9, sites: 4, ...}
  final int consolidatedCount;                      // Dives merged as secondary readings
  final int skippedCount;                           // Duplicates skipped
  final String? errorMessage;
}
```

This avoids name collision with the existing `ImportResult` in `dive_import_service.dart` and the `MediaImportResult` in `media_import_service.dart`.

## Routing

Existing routes stay the same. Each route instantiates `UnifiedImportWizard` with the appropriate adapter:

| Route | Widget |
|-------|--------|
| `/transfer/uddf-import` | `UnifiedImportWizard(adapter: UddfAdapter)` |
| `/transfer/fit-import` | `UnifiedImportWizard(adapter: FitAdapter)` |
| `/transfer/import-wizard` | `UnifiedImportWizard(adapter: UniversalAdapter)` |
| `/dive-computers/discover` | `UnifiedImportWizard(adapter: DiveComputerAdapter())` |
| `/dive-computers/:id/download` | `UnifiedImportWizard(adapter: DiveComputerAdapter(known: computer))` |
| `/settings/wearable-import` | `UnifiedImportWizard(adapter: HealthKitAdapter)` |

No URL changes. Transfer page entry points remain unchanged.

## Error Handling

### Acquisition Step Errors

Each acquisition step handles errors inline within the step widget:

- **File parse failure** (UDDF, FIT): error message displayed in the step body with a "Try Again" button. The wizard stays on the current step.
- **BLE scan timeout / connection failure**: error message in the step with "Retry Scan" option. Back button returns to previous acquisition step.
- **HealthKit permission denied**: explanation shown with "Open Settings" button and option to cancel.
- **Download interrupted** (device out of range, timeout): error displayed in the download step with "Retry" option. Downloaded-so-far dives are not lost — the adapter can offer to proceed with partial data or retry.

The wizard shell does not manage acquisition errors directly. Each acquisition step widget handles its own error display and retry logic via its source-specific notifier. The wizard's `canAdvance` provider for that step remains `false` until the error is resolved.

### Import Step Errors

If `performImport` throws during the import step:

- The wizard transitions to an error state within the import step (not a separate step).
- Shows the error message with a count of how many items were successfully imported before the failure.
- Offers "Done" (exit with partial import) — no retry, since partial data is already committed.

### Wizard Exit Confirmation

The close button shows a confirmation dialog. The message varies by state:

- During acquisition: "Cancel import?"
- During review: "Discard selections and cancel?"
- During import: "Import is in progress and cannot be cancelled."
- After summary: no confirmation needed.

## Provider Invalidation

After `performImport` completes successfully, `ImportWizardNotifier.performImport()` invalidates all providers that may have been affected by the imported data. This uses a shared helper:

```dart
void invalidateImportRelatedProviders(Ref ref, Set<ImportEntityType> importedTypes) {
  // Always invalidate dives if any were imported
  if (importedTypes.contains(ImportEntityType.dives)) {
    ref.invalidate(diveSummariesProvider);
    ref.invalidate(allDiveComputersProvider);
    // ... other dive-related providers
  }
  if (importedTypes.contains(ImportEntityType.sites)) {
    ref.invalidate(allSitesProvider);
  }
  // ... etc. for each entity type
}
```

The notifier determines which types were imported from the `UnifiedImportResult.importedCounts` keys and invalidates only the relevant providers. This replaces the existing ad-hoc invalidation in `UddfImportNotifier._invalidateProviders()`.

## Key Refactoring

The existing notifiers that manage both acquisition and import (`UddfImportNotifier`, `DiveImportNotifier`, `DownloadNotifier`) will be decomposed:

- Acquisition logic stays in source-specific notifiers (may be simplified)
- Review, import, and summary logic moves to the shared `ImportWizardNotifier`
- Existing import services (`UddfEntityImporter`, `DiveImportService`, `ImportedDiveConverter`) are called by adapters unchanged

### DiveComparisonCard Refactor

The existing `DiveComparisonCard` widget uses immediate-action buttons — tapping "Consolidate" writes to the database right away. In the unified wizard, the card must behave as a **tri-state selector**: tapping an action button sets the selected action visually (highlighted border/fill) but does not execute it. Execution happens later when the user taps "Import Selected."

Changes required:

- Add `selectedAction: DuplicateAction` parameter to show current state
- Add `onActionChanged: Function(DuplicateAction)` callback (replaces `onSkip`/`onImportAsNew`/`onConsolidate`)
- Add `availableActions: Set<DuplicateAction>` parameter to control which buttons appear (Consolidate hidden for non-dive-computer sources)
- Action buttons become toggles with visual state (active = filled/highlighted, inactive = outlined)

## Existing Code Reused

| Component | Current Location | Role in New Architecture |
|-----------|-----------------|------------------------|
| `IncomingDiveData` | `core/domain/models/` | Bridge type for dive comparison cards |
| `DiveComparisonCard` | `core/presentation/widgets/` | Inline duplicate review in shared Review step (refactored to tri-state selector) |
| `OverlaidProfileChart` | `core/presentation/widgets/` | Profile overlay in comparison cards |
| `UddfDuplicateChecker` | `dive_import/data/services/` | Called by UddfAdapter.checkDuplicates |
| `DiveMatcher` | `dive_import/domain/services/` | Called by FIT/HealthKit/Computer adapters |
| `UddfEntityImporter` | `dive_import/data/services/` | Called by UddfAdapter.performImport |
| `DiveImportService` | `dive_computer/data/services/` | Called by DiveComputerAdapter.performImport |
| `ImportedDiveConverter` | `dive_import/domain/services/` | Called by FIT/HealthKit adapters |
| `FitParserService` | `dive_import/data/services/` | Used in FitAdapter acquisition step |
| `HealthKitService` | `dive_import/data/services/` | Used in HealthKitAdapter acquisition step |

## Migration Strategy

This refactoring can be implemented incrementally, one adapter at a time, without a big-bang switchover.

### Recommended Order

1. **Wizard shell + shared steps** - Build `UnifiedImportWizard`, `WizardStepDef`, `ImportBundle`, `ImportWizardNotifier`, and the shared Review/Import/Summary step widgets. Test with a stub adapter.

2. **FIT adapter** (simplest) - Two acquisition steps, dives only, no Consolidate action. Validates the full pipeline end-to-end with minimal complexity.

3. **HealthKit adapter** - Similar to FIT but with permission and date range acquisition steps. Validates multi-step acquisition flow.

4. **UDDF adapter** - Multi-entity-type import with tabs. Validates the tabbed review UI and non-dive duplicate handling.

5. **Dive computer adapter** (most complex) - BLE discovery, download streaming, PIN handling, Consolidate action. Validates the full feature set including the behavioral change (removing auto-import).

6. **Universal adapter** - Field mapping step. May be last since it has the most unique acquisition logic.

### Coexistence

During migration, old and new implementations coexist. Each source's route can be switched from the old page to `UnifiedImportWizard` independently. Old notifiers (`UddfImportNotifier`, `DiveImportNotifier`) are removed only after their corresponding adapter is complete and tested. This avoids any period where an import flow is broken.
