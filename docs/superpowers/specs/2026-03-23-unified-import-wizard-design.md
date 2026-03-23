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
  final Set<int> likelyDuplicateIndices;   // Auto-deselected, score >= 0.7
  final Set<int> possibleDuplicateIndices; // Warning badge, score >= 0.5
  final Map<int, DiveMatchResult>? matchResults; // Dives only: per-item match details
}

class EntityItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final IncomingDiveData? diveData; // Present for dive items, enables comparison cards
}
```

The adapter normalizes its native data into `EntityItem` display models for the Review step, but retains the raw source data internally. The `diveData` field on dive items enables the existing `DiveComparisonCard` and `OverlaidProfileChart` widgets for duplicate review.

## Source Adapters

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

  /// Save selected items using raw source data
  Future<ImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<int, DuplicateAction> duplicateActions, {
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

#### UddfAdapter

- **Acquisition steps:** Pick UDDF/XML file, Parse file contents
- **Retains:** `UddfImportResult` (raw maps)
- **Duplicate detection:** UddfDuplicateChecker
- **Import via:** UddfEntityImporter
- **Bundle contents:** dives, sites, buddies, equipment, trips, certifications, dive centers, tags, dive types, equipment sets, courses

#### FitAdapter

- **Acquisition steps:** Pick .fit file(s), Parse binary FIT data
- **Retains:** `List<ImportedDive>`
- **Duplicate detection:** DiveMatcher
- **Import via:** ImportedDiveConverter + DiveRepository
- **Bundle contents:** dives only

#### HealthKitAdapter

- **Acquisition steps:** Request HealthKit permissions, Select date range, Fetch dive workouts
- **Retains:** `List<ImportedDive>`
- **Duplicate detection:** DiveMatcher
- **Import via:** ImportedDiveConverter + DiveRepository
- **Bundle contents:** dives only

#### UniversalAdapter

- **Acquisition steps:** Pick file, Auto-detect source app, Field mapping (CSV only)
- **Retains:** Parsed data per detected format
- **Duplicate detection:** DiveMatcher
- **Import via:** Format-specific importer
- **Bundle contents:** varies by detected format

## Shared Review Step

The review step is the core of the unified experience. It has two distinct interaction models based on whether an item is a duplicate.

### Tab Bar

- Only entity types present in the `ImportBundle` get tabs.
- Single entity type (dive computer, FIT, HealthKit): tab bar is hidden entirely; shows dive list directly.
- Multiple entity types (UDDF): scrollable tab bar with count badges per tab.

### Non-Duplicate Items

Simple checkbox toggle. Binary choice: import or skip. Selected by default.

### Duplicate Items (Likely & Possible)

No checkbox. Instead, a three-action card:

| Action | Description |
|--------|-------------|
| **Skip** | Don't import this item |
| **Import as New** | Create a separate dive entry |
| **Consolidate** | Add as secondary computer reading on the matched dive |

Default action varies by confidence:
- **Likely duplicates** (score >= 0.7): defaults to **Skip**
- **Possible duplicates** (score >= 0.5): defaults to **Import as New**

Cards are expandable to reveal the `DiveComparisonCard` with:
- Incoming vs. existing field comparison
- Overlaid dive profile chart
- Three action buttons (active action highlighted)

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
  final Map<int, DuplicateAction> duplicateActions;
  final String? importPhase;
  final int importCurrent;
  final int importTotal;
  final ImportResult? importResult;
  final bool isImporting;
  final String? error;
}

enum DuplicateAction { skip, importAsNew, consolidate }

class ImportWizardNotifier extends StateNotifier<ImportWizardState> {
  final ImportSourceAdapter adapter;

  void setBundle(ImportBundle bundle);
  void toggleSelection(ImportEntityType type, int index);
  void selectAll(ImportEntityType type);
  void deselectAll(ImportEntityType type);
  void setDuplicateAction(int index, DuplicateAction action);
  Future<void> performImport(); // Delegates to adapter
  void reset();
}
```

Scoped per wizard instance via `ProviderScope` override. Each import session gets independent state.

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

## Key Refactoring

The existing notifiers that manage both acquisition and import (`UddfImportNotifier`, `DiveImportNotifier`, `DownloadNotifier`) will be decomposed:

- Acquisition logic stays in source-specific notifiers (may be simplified)
- Review, import, and summary logic moves to the shared `ImportWizardNotifier`
- Existing import services (`UddfEntityImporter`, `DiveImportService`, `ImportedDiveConverter`) are called by adapters unchanged

## Existing Code Reused

| Component | Current Location | Role in New Architecture |
|-----------|-----------------|------------------------|
| `IncomingDiveData` | `core/domain/models/` | Bridge type for dive comparison cards |
| `DiveComparisonCard` | `dive_computer/presentation/widgets/` | Inline duplicate review in shared Review step |
| `OverlaidProfileChart` | `dive_computer/presentation/widgets/` | Profile overlay in comparison cards |
| `UddfDuplicateChecker` | `dive_import/data/services/` | Called by UddfAdapter.checkDuplicates |
| `DiveMatcher` | `dive_import/domain/services/` | Called by FIT/HealthKit/Computer adapters |
| `UddfEntityImporter` | `dive_import/data/services/` | Called by UddfAdapter.performImport |
| `DiveImportService` | `dive_computer/data/services/` | Called by DiveComputerAdapter.performImport |
| `ImportedDiveConverter` | `dive_import/domain/services/` | Called by FIT/HealthKit adapters |
| `FitParserService` | `dive_import/data/services/` | Used in FitAdapter acquisition step |
| `HealthKitService` | `dive_import/data/services/` | Used in HealthKitAdapter acquisition step |
