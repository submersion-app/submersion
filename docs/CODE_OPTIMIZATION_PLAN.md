# Submersion - Code Optimization & Improvement Plan

> Generated 2026-03-10 from comprehensive analysis of 560 Dart source files (~436K lines)
> Excludes test files, generated files (*.g.dart), and localization output files

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Critical: Oversized Files](#2-critical-oversized-files)
3. [Cross-Feature Code Duplication](#3-cross-feature-code-duplication)
4. [Immutability Violations](#4-immutability-violations)
5. [State Management Improvements](#5-state-management-improvements)
6. [Error Handling Standardization](#6-error-handling-standardization)
7. [Performance Optimizations](#7-performance-optimizations)
8. [Service Layer Improvements](#8-service-layer-improvements)
9. [Domain Entity Refactoring](#9-domain-entity-refactoring)
10. [Theme & Styling Deduplication](#10-theme--styling-deduplication)
11. [Dependency Injection](#11-dependency-injection)
12. [Miscellaneous Improvements](#12-miscellaneous-improvements)
13. [Priority Matrix](#13-priority-matrix)

---

## 1. Executive Summary

### Strengths

The codebase demonstrates strong architectural consistency:

- **Domain/Data/Presentation separation** is rigorous across all 22+ features
- **Riverpod state management** is consistently applied (watch/read patterns correct)
- **Entity design** is excellent: all use `Equatable`, `copyWith()`, `props`
- **Sync tracking** is universal: every mutation calls `markRecordPending()`
- **Responsive design** via `MasterDetailScaffold` works well across device sizes
- **Diver-scoped data** is consistently filtered via `validatedCurrentDiverIdProvider`
- **Localization** is 100% adopted via `context.l10n`

### Key Problem Areas

| Category | Severity | Estimated Lines Recoverable |
|----------|----------|----------------------------|
| Oversized files (25 files > 800 lines) | CRITICAL | N/A (splitting, not removing) |
| Cross-feature list/detail/edit duplication | HIGH | ~5,000+ lines |
| Immutability violations (setState mutations) | HIGH | ~200 lines of fixes |
| Service layer duplication (UDDF, PDF) | MEDIUM | ~2,000+ lines |
| Theme duplication | LOW | ~500 lines |
| Error handling inconsistency | LOW | ~300 lines of standardization |

---

## 2. Critical: Oversized Files

The project convention is 200-400 lines typical, 800 max. **25 files** exceed that limit.

### Tier 1: Extreme (>2000 lines) - Split Immediately

| File | Lines | Recommended Split |
|------|-------|-------------------|
| `features/dive_log/presentation/pages/dive_detail_page.dart` | 5,051 | 4-5 files |
| `features/dive_log/presentation/pages/dive_edit_page.dart` | 4,249 | 7 files |
| `features/dive_log/data/repositories/dive_repository_impl.dart` | 3,283 | 5 files |
| `features/dive_log/presentation/widgets/dive_profile_chart.dart` | 3,032 | 4 files |
| `features/settings/presentation/pages/settings_page.dart` | 2,682 | 10 files |
| `core/database/database.dart` | 2,189 | Extract utility methods |

### Tier 2: Large (1000-2000 lines) - Split Soon

| File | Lines | Recommended Split |
|------|-------|-------------------|
| `core/services/sync/sync_data_serializer.dart` | 1,866 | By entity type |
| `core/services/export/uddf/uddf_full_import_service.dart` | 1,801 | By entity parser |
| `features/dive_log/data/repositories/dive_computer_repository_impl.dart` | 1,562 | 2-3 files |
| `features/dive_log/data/services/profile_analysis_service.dart` | 1,557 | 3 files |
| `features/dive_log/presentation/widgets/dive_list_content.dart` | 1,518 | Extract selection logic |
| `features/equipment/presentation/pages/equipment_detail_page.dart` | 1,514 | 3-4 files |
| `core/services/export/uddf/uddf_export_builders.dart` | 1,481 | By builder type |
| `features/dive_sites/presentation/pages/site_edit_page.dart` | 1,450 | 3-4 files |
| `features/statistics/data/repositories/statistics_repository.dart` | 1,420 | 6 files |
| `features/dive_sites/presentation/pages/site_detail_page.dart` | 1,415 | 2-3 files |
| `features/dive_import/data/services/uddf_entity_importer.dart` | 1,399 | 8-10 entity importers |
| `features/settings/presentation/providers/export_providers.dart` | 1,362 | 3 files |
| `features/dive_log/presentation/pages/dive_list_page.dart` | 1,328 | 2 files |
| `features/settings/presentation/providers/settings_providers.dart` | 1,203 | 5 files |
| `features/dive_sites/presentation/widgets/site_list_content.dart` | 1,173 | Extract nested classes |
| `features/media/presentation/pages/photo_viewer_page.dart` | 1,100 | 4-5 files |
| `features/dive_log/presentation/widgets/o2_toxicity_card.dart` | 1,100 | 2-3 files |
| `features/dive_centers/presentation/pages/dive_center_edit_page.dart` | 1,048 | 2-3 files |
| `features/statistics/presentation/widgets/statistics_summary_widget.dart` | 1,031 | 4 files |

### Tier 3: Over Limit (800-1000 lines) - Split When Touched

| File | Lines |
|------|-------|
| `features/dive_log/domain/entities/dive.dart` | 990 |
| `core/services/sync/sync_service.dart` | 978 |
| `core/router/app_router.dart` | 889 |
| `features/dive_sites/presentation/pages/site_import_page.dart` | 852 |

### Detailed Split Recommendations

#### dive_detail_page.dart (5,051 lines) -> 4 files

```
dive_detail_page.dart           (~300)  Container/router, loading states
dive_detail_content.dart        (~1200) Main content sections
dive_detail_export_service.dart (~400)  PNG/PDF export logic
dive_profile_playback.dart      (~300)  Profile interaction/heatmap state
```

**Key issues in this file:**
- 261+ `setState` calls triggering full rebuilds of massive widget tree
- Export functionality embedded in UI widget (should be a service)
- 22 boolean visibility flags synced from provider state via mutation in `build()`
- Profile playback state management mixed with display logic

#### dive_edit_page.dart (4,249 lines) -> 7 files

```
dive_edit_page.dart             (~300)  Container/router
dive_edit_form.dart             (~400)  Main form scaffold
dive_edit_times_section.dart    (~300)  Entry/exit time management
dive_edit_tanks_section.dart    (~400)  Tank configuration
dive_edit_conditions_section.dart (~300) Environment conditions
dive_edit_rebreather_section.dart (~300) CCR/SCR settings
dive_edit_sightings_section.dart (~400) Marine life + nested picker/editor sheets
```

**Key issues in this file:**
- 30+ `TextEditingController` instances — verify proper `dispose()` pattern
- 50+ direct list/set mutations via `setState` (`.add()`, `.clear()`, `[i] =`)
- Nested `_SpeciesPickerSheet` and `_EditSightingSheet` classes embedded in file
- 300+ line `_saveDive()` method

#### dive_repository_impl.dart (3,283 lines) -> 5 files

```
dive_repository_impl.dart       (~600)  Core CRUD only
dive_profile_repository.dart    (~500)  Profile data read/write/edit
dive_tank_repository.dart       (~400)  Tank pressure, gas switches
dive_metadata_repository.dart   (~400)  Sightings, buddies, custom fields
dive_mapper.dart                (~300)  _mapRowToDive, _mapRowToDiveWithPreloadedData
```

#### dive_profile_chart.dart (3,032 lines) -> 4 files

```
dive_profile_chart.dart         (~200)  Container widget
dive_profile_chart_state.dart   (~400)  Zoom/pan/legend state management
dive_profile_chart_painter.dart (~1200) Build logic, chart rendering
dive_profile_chart_helpers.dart (~200)  Color maps, interpolation, dash patterns
```

**Key issues:**
- 50+ constructor parameters (extract to config object)
- 30+ mutable state variables
- State sync from provider to local vars via mutation in `build()`

#### settings_page.dart (2,682 lines) -> 10 files

```
settings_page.dart              (~200)  Main shell + section factory
settings_units_section.dart     (~200)  Unit preferences
settings_deco_section.dart      (~200)  Decompression settings
settings_appearance_section.dart (~200) Theme, display options
settings_notifications_section.dart (~200)
settings_manage_section.dart    (~200)
settings_data_section.dart      (~200)
settings_about_section.dart     (~200)
settings_section_factory.dart   (~100)  Maps section key -> widget
```

#### statistics_repository.dart (1,420 lines) -> 6 files

```
statistics_repository.dart      (~200)  Facade/orchestrator
gas_statistics_repository.dart  (~250)  SAC, ppO2, gas stats
dive_statistics_repository.dart (~250)  Count, depth, duration
species_statistics_repository.dart (~200)
site_statistics_repository.dart (~200)
equipment_statistics_repository.dart (~200)
```

#### uddf_entity_importer.dart (1,399 lines) -> 6+ files

```
uddf_entity_importer.dart       (~200)  Orchestrator
trip_importer.dart              (~150)
equipment_importer.dart         (~150)
dive_importer.dart              (~400)  Largest - core dive data
buddy_importer.dart             (~100)
site_importer.dart              (~150)
dive_center_importer.dart       (~100)
```

#### sync_data_serializer.dart (1,866 lines) -> By entity type

```
sync_data_serializer.dart       (~200)  Orchestrator
dive_serializer.dart            (~400)
site_serializer.dart            (~200)
equipment_serializer.dart       (~200)
buddy_serializer.dart           (~150)
trip_serializer.dart            (~150)
```

---

## 3. Cross-Feature Code Duplication

This is the single highest-impact improvement opportunity. Multiple features repeat identical structural patterns that could be extracted to shared base classes.

### 3.1 List Content Widget Duplication (~2,500 lines recoverable)

**9 features** have nearly identical `*_list_content.dart` widgets with duplicated:
- `ScrollController` management and auto-scroll-to-selected logic
- Selection mode toggle (`_isSelectionMode`, `_selectedIds`)
- Multi-select with undo/restore
- `AppBar` variants (normal + selection mode)
- Filter chips display
- Sort bottom sheet integration
- Empty/error state rendering

**Affected files:**
- `dive_log/presentation/widgets/dive_list_content.dart`
- `dive_sites/presentation/widgets/site_list_content.dart`
- `equipment/presentation/widgets/equipment_list_content.dart`
- `buddies/presentation/widgets/buddy_list_content.dart`
- `certifications/presentation/widgets/certification_list_content.dart`
- `courses/presentation/widgets/course_list_content.dart`
- `dive_centers/presentation/widgets/dive_center_list_content.dart`
- `trips/presentation/widgets/trip_list_content.dart`
- `divers/presentation/widgets/diver_list_content.dart`

**Recommendation:** Extract `shared/widgets/list_content_base.dart`:

```dart
abstract class ListContentBase<T> extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;

  // Subclasses override:
  Widget buildListItem(BuildContext context, T item, bool selected, bool checked);
  Widget buildEmptyState(BuildContext context);
  Widget? buildFilterChips(BuildContext context);
  Future<void> onBulkDelete(List<String> ids);
}
```

### 3.2 Detail Page Duplication (~2,000 lines recoverable)

**8 features** have identical detail page boilerplate:
- `_hasRedirected` flag for desktop redirect
- Embedded vs. full-screen mode handling
- `ResponsiveBreakpoints.isMasterDetail()` conditional
- Loading/error/not-found state scaffolds
- Deletion handling with callback

**Affected files:**
- `dive_log/presentation/pages/dive_detail_page.dart`
- `dive_sites/presentation/pages/site_detail_page.dart`
- `equipment/presentation/pages/equipment_detail_page.dart`
- `buddies/presentation/pages/buddy_detail_page.dart`
- `trips/presentation/pages/trip_detail_page.dart`
- `dive_centers/presentation/pages/dive_center_detail_page.dart`
- `certifications/presentation/pages/certification_detail_page.dart`
- `divers/presentation/pages/diver_detail_page.dart`

**Recommendation:** Extract `shared/widgets/detail_page_base.dart`:

```dart
abstract class DetailPageBase<T> extends ConsumerStatefulWidget {
  final String itemId;
  final bool embedded;
  final VoidCallback? onDeleted;

  @protected
  Widget buildContent(BuildContext context, T item);

  @protected
  AsyncValue<T?> watchItem(WidgetRef ref);
}
```

### 3.3 Selection Mode AppBar (~180 lines recoverable)

Identical selection AppBar code appears in multiple list content widgets:
- Close button
- Selection count display
- Select all / Deselect all buttons
- Delete button with confirmation

**Recommendation:** Extract `shared/widgets/selection_mode_app_bar.dart`

### 3.4 Edit Page Form Patterns (~500+ lines recoverable)

Multiple edit pages share identical patterns:
- `GlobalKey<FormState>` management
- `_hasChanges`, `_isLoading`, `_isSaving` state tracking
- `TextEditingController` creation and disposal
- Save/cancel button pair with loading state
- Validation patterns

**Recommendation:** Extract a `FormPageMixin` or base class to standardize lifecycle management.

### 3.5 List Page Responsive Scaffolding

All list pages repeat the `ResponsiveBreakpoints.isMasterDetail()` conditional with `MasterDetailScaffold` vs simple scaffold. Consider a factory function or wrapper widget.

---

## 4. Immutability Violations

### 4.1 StatefulWidget Mutation Patterns (HIGH priority)

Multiple large files directly mutate lists, sets, and maps inside `setState()`:

**dive_edit_page.dart (50+ mutations):**
```dart
// VIOLATION: Direct list mutation
setState(() => _selectedEquipment.add(equipment));
setState(() => _selectedEquipment.clear());
setState(() => _tanks[index] = updatedTank);
setState(() => _sightings.add(newSighting));
setState(() => _sightings.removeAt(index));
setState(() => _weights.add(newWeight));
setState(() => _weights[index] = weight.copyWith(...));
```

**Should be:**
```dart
// CORRECT: Create new collections
setState(() => _selectedEquipment = {..._selectedEquipment, equipment});
setState(() => _selectedEquipment = <String>{});
setState(() => _tanks = [
  ..._tanks.sublist(0, index),
  updatedTank,
  ..._tanks.sublist(index + 1),
]);
setState(() => _sightings = [..._sightings, newSighting]);
setState(() => _weights = [..._weights, newWeight]);
```

**Other affected files:**
- `dive_detail_page.dart` — 22 boolean flags mutated from provider state in `build()`
- `dive_list_content.dart` — selection set mutations
- `site_list_content.dart` — similar selection mutations

### 4.2 Service Layer Mutations (MEDIUM priority)

**sync_data_serializer.dart:**
```dart
// VIOLATION: Mutating imported data dictionaries
diveData['dateTime'] = dateTime;
diveData.remove('date');
diveData.remove('time');
```

**Should be:**
```dart
final transformed = {
  ...diveData,
  'dateTime': dateTime,
}..remove('date')..remove('time');
// Or better: create new map without removed keys
```

**csv_import_service.dart:** Same pattern of mutating input dictionaries.

**uddf_full_export_service.dart:**
```dart
// VIOLATION: Mutating shared map
uniqueComputers[computerId] = { 'model': ..., 'serial': ... };
```

### 4.3 Profile Chart State Sync (HIGH priority)

**dive_profile_chart.dart** syncs provider state to local mutable state in `build()`:
```dart
// VIOLATION: Mutation during build
_showTemperature = legendState.showTemperature;
_showPressure = legendState.showPressure;
_showHeartRate = legendState.showHeartRate;
// ... 20 more direct mutations
for (final entry in legendState.showTankPressure.entries) {
  _showTankPressure[entry.key] = entry.value;
}
```

**Should use:** `didChangeDependencies()` or derive state in `build()` without mutation. Better yet, read directly from the provider state without local copies.

---

## 5. State Management Improvements

### 5.1 Replace Excessive setState with Riverpod StateNotifier

**dive_detail_page.dart** has 261+ `setState` calls. Many of these manage interaction state that should live in a dedicated provider:

```dart
// Current: scattered setState calls
setState(() => _isExportingProfile = true);
setState(() => _heatMapHoverIndex = index);
setState(() => _selectedPointNotifier.value = point);

// Better: dedicated state notifier
class DiveDetailInteractionNotifier extends StateNotifier<DiveDetailInteractionState> {
  void startExport() => state = state.copyWith(isExporting: true);
  void setHeatMapIndex(int? index) => state = state.copyWith(heatMapIndex: index);
  void selectProfilePoint(ProfilePoint? point) => state = state.copyWith(selectedPoint: point);
}
```

### 5.2 Provider Cache Invalidation

Several features rely on manual `ref.invalidate()` after CRUD operations, which is fragile:

```dart
// Current: easy to forget invalidation
await repository.createBuddy(buddy);
ref.invalidate(allBuddiesProvider);
ref.invalidate(sortedBuddiesProvider);
// Miss one? Stale data.
```

**Recommendation:** Consider using `ref.listen` or automatic invalidation chains where the mutation provider invalidates dependent providers automatically.

### 5.3 Missing Pagination

All list features load complete datasets at once. This works for small datasets but will degrade with 10,000+ dives or 1,000+ sites. Consider lazy-loading with offset/limit pagination for:
- `diveListProvider`
- `siteListProvider`
- `equipmentListProvider`

### 5.4 Provider Inconsistency Across Features

Most features use `FutureProvider` for reads and `StateNotifierProvider` for mutations — this is correct. However, error handling diverges:

- **Pattern A** (most features): Let `FutureProvider` wrap errors as `AsyncError`
- **Pattern B** (backup, export): Custom state objects with `error`/`message` fields

**Recommendation:** Standardize on Pattern A for data providers, reserve Pattern B for multi-step operations with progress tracking.

---

## 6. Error Handling Standardization

### 6.1 Custom Exception Hierarchy

13 files throw generic `Exception()` instead of domain-specific types. Create:

```dart
// core/errors/app_exceptions.dart
sealed class AppException implements Exception {
  final String userMessage;
  final String? technicalMessage;
  final StackTrace? stackTrace;
}

class DatabaseException extends AppException { ... }
class SyncException extends AppException { ... }
class ImportException extends AppException { ... }
class ExportException extends AppException { ... }
class ValidationException extends AppException { ... }
class NetworkException extends AppException { ... }
```

### 6.2 Empty Catch Blocks (23 files)

Most have inline comments explaining why the exception is ignored. For the ones that don't, add either:
- A comment explaining the rationale, or
- `LoggerService` debug-level logging for troubleshooting

**Key files to audit:**
- `core/services/database_migration_service.dart` (3 empty catches)
- `features/backup/presentation/providers/backup_providers.dart` (2 empty catches)
- `features/dive_import/data/services/uddf_entity_importer.dart` (multiple)
- `core/services/export/csv/csv_import_service.dart` (multiple)

### 6.3 Missing Error Handling in Import Pipeline

**uddf_entity_importer.dart** has sparse error handling:
- No validation of parsed data before entity creation
- No transaction semantics (partial imports possible on failure)
- No rollback mechanism
- Generic error messages surfaced to UI

**Recommendation:** Wrap entity import in database transactions and add validation before creation.

### 6.4 Dive Computer Error Handling

- Native platform errors pass through as generic strings
- Timeout scenarios not handled
- Device disconnection during download not gracefully recovered
- Stream completion detection is fragile

---

## 7. Performance Optimizations

### 7.1 Missing `const` Constructors

Many `SizedBox`, `Padding`, `Divider`, `Container`, and `EdgeInsets` widgets are not declared `const` where they could be. This causes unnecessary rebuilds and memory allocation.

**High-impact files (large widget trees):**
- `dive_detail_page.dart` — 261+ non-const widgets in tree
- `dive_edit_page.dart` — large form with many spacers
- `settings_page.dart` — repeated section separators

**Fix:** Audit and add `const` to all trivial widget constructors.

### 7.2 Large Build Methods

While the code quality audit found most build methods are well-factored, the oversized files contain build methods that exceed 50 lines due to inline data checks and widget construction. Splitting these files (Section 2) will naturally resolve this.

### 7.3 Mini-Map Rendering in Lists

**site_list_content.dart** renders a `FlutterMap` widget for each list item with a location:
```dart
if (shouldShowMap) {
  return FlutterMap(...);  // New FlutterMap per item
}
```

With 100+ sites, this creates 100 FlutterMap instances in the ListView. Consider:
- Using static map tile images instead of interactive maps for list items
- Implementing the existing `showMapBackgroundOnSiteCardsProvider` toggle
- Using `ListView.builder` with `cacheExtent` limits

### 7.4 Photo Viewer Caching

**photo_viewer_page.dart** reloads full-resolution images on every page swipe:
```dart
final bytes = await ref.read(
  assetFullResolutionProvider(item.platformAssetId!).future,
);
```

**Recommendation:** Implement image caching with `FutureProvider.family` autoDispose plus `keepAlive` for adjacent pages, or use Flutter's `ImageCache`.

### 7.5 Scroll Position Calculation

**site_list_content.dart** calculates item heights dynamically on every selection:
```dart
final avgItemHeight = totalContentHeight / sites.length;
final targetOffset = (index * avgItemHeight) - (viewportHeight / 3);
```

With 1,000+ items, this is wasteful. Cache heights or use `ScrollablePositionedList`.

### 7.6 Dive Computer Event Debouncing

Auto-import triggered by `DownloadCompleteEvent` has no debouncing. Rapid events could trigger multiple imports:

```dart
// Add guard:
bool _importInProgress = false;
void _onDownloadComplete(DownloadCompleteEvent event) {
  if (_importInProgress) return;
  _importInProgress = true;
  try { /* import */ } finally { _importInProgress = false; }
}
```

---

## 8. Service Layer Improvements

### 8.1 UDDF Service Duplication (~70% overlap)

The codebase has parallel implementations:
- `uddf_export_service.dart` (552 lines) vs `uddf_full_export_service.dart` (546 lines)
- `uddf_import_service.dart` (877 lines) vs `uddf_full_import_service.dart` (1,801 lines)

~70% code overlap between standard and full variants.

**Recommendation:** Merge into a single configurable export/import service with an `ExportScope` enum (`standard`, `full`) that controls which entities are included.

### 8.2 PDF Template Duplication

5 PDF template files (1,910 lines total) repeat structural patterns:

- `pdf_template_padi.dart` (447 lines)
- `pdf_template_professional.dart` (515 lines)
- `pdf_template_naui.dart` (505 lines)
- `pdf_template_simple.dart` (243 lines)
- `pdf_template_detailed.dart` (200 lines)

All repeat page setup, margin definitions, component assembly.

**Recommendation:** Extract a `PdfTemplateBase` class with template method pattern:

```dart
abstract class PdfTemplateBase {
  pw.Document build(List<Dive> dives, PdfConfig config) {
    final doc = pw.Document();
    for (final dive in dives) {
      doc.addPage(buildPage(dive, config));
    }
    return doc;
  }

  pw.Page buildPage(Dive dive, PdfConfig config);  // Override per template
  pw.Widget buildHeader(Dive dive);                  // Override per template
  pw.Widget buildBody(Dive dive);                    // Shared or override
}
```

### 8.3 dive_import vs universal_import Overlap

Two separate import systems exist:
- **dive_import**: Specialized for UDDF format, application-specific
- **universal_import**: Generic framework for CSV, FIT, UDDF

Both handle UDDF but with different code paths.

**Recommendation (long-term):** Migrate UDDF handling into `universal_import` and deprecate the `dive_import` feature's UDDF path. Keep `dive_import` only for dive computer downloads.

### 8.4 Backup Service Split

`backup_service.dart` (542 lines) handles both export and import operations in one class.

**Recommendation:** Split into `backup_export_service.dart` and `backup_import_service.dart`.

---

## 9. Domain Entity Refactoring

### 9.1 Dive Entity Decomposition (990 lines, 100+ fields)

The `Dive` entity is a monolithic class with fields for:
- Basic dive info (id, dateTime, duration, depth)
- Equipment (tanks, weights, gear)
- Conditions (current, swell, temperature, visibility)
- Deco settings (GF Low/High, algorithm, CNS, OTU)
- Rebreather config (CCR/SCR setpoints, diluent, scrubber)
- Wearable integration (HealthKit fields)
- Training/course references
- Custom fields

**Recommendation:** Refactor to composition:

```dart
class Dive extends Equatable {
  final String id;
  final DateTime diveDateTime;
  final Duration duration;
  final double maxDepth;
  // ... core fields

  final DiveConditions conditions;
  final DecoSettings decoSettings;
  final RebreatherConfig? rebreatherConfig;  // null for OC dives
  final WearableInfo? wearableInfo;
  final List<DiveTank> tanks;
  final List<Weight> weights;
}

class DiveConditions extends Equatable {
  final String? current;
  final String? swell;
  final double? waterTemp;
  final double? visibility;
  // ... condition fields
}

class DecoSettings extends Equatable {
  final int? gfLow;
  final int? gfHigh;
  final String? algorithm;
  final double? cns;
  final double? otu;
}

class RebreatherConfig extends Equatable {
  final String mode;  // 'CCR' or 'SCR'
  final double? setpointLow;
  final double? setpointHigh;
  final String? diluentGas;
  final double? scrubberDuration;
}
```

### 9.2 AppSettings Decomposition

`settings_providers.dart` (1,203 lines) contains an `AppSettings` class with 100+ properties.

**Recommendation:** Split into topic-specific settings:

```dart
class UnitSettings extends Equatable { ... }
class DecoSettings extends Equatable { ... }
class AppearanceSettings extends Equatable { ... }
class NotificationSettings extends Equatable { ... }
class DiveNumberingSettings extends Equatable { ... }
```

### 9.3 DiveProfileChart Config Object

The chart widget takes 50+ constructor parameters. Extract to a configuration object:

```dart
class ProfileChartConfig extends Equatable {
  final bool showTemperature;
  final bool showPressure;
  final bool showHeartRate;
  final bool showNdl;
  // ... 20+ visibility toggles

  final double zoomLevel;
  final Offset panOffset;
  // ... interaction state
}
```

---

## 10. Theme & Styling Deduplication

### 10.1 Full Theme Files

5 theme files (150-156 lines each) repeat identical component overrides:

```dart
// Repeated in ALL 5 themes:
cardTheme: CardThemeData(
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
),
floatingActionButtonTheme: FloatingActionButtonThemeData(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
),
```

**Recommendation:** Create a `ThemeBuilder` utility:

```dart
class ThemeBuilder {
  static ThemeData build({
    required ColorScheme colorScheme,
    required AppColors appColors,
    // Theme-specific overrides only
  }) {
    return ThemeData(
      colorScheme: colorScheme,
      // Shared component themes applied here
      cardTheme: _sharedCardTheme,
      inputDecorationTheme: _sharedInputTheme,
      // ...
    );
  }
}
```

---

## 11. Dependency Injection

### 11.1 Current Pattern: Static Singletons

Services use static singleton pattern:
```dart
class DatabaseService {
  static final instance = DatabaseService._();
  DatabaseService._();
}
```

**Issues:**
- Test setup requires `@visibleForTesting` reset methods
- Initialization order is implicit
- Services depend on static instances rather than injectable dependencies

### 11.2 Recommendation

Consider migrating to Riverpod-based DI where services are provided via `Provider`:

```dart
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return SyncService(db);
});
```

This makes services injectable and testable without `@visibleForTesting` hacks. However, this is a large refactor — only undertake if test coverage justifies it.

---

## 12. Miscellaneous Improvements

### 12.1 debugPrint Statements (10 files)

`debugPrint()` calls exist in production code paths. While Flutter strips these in release builds, they add noise in debug builds:

- `main.dart` — 9 calls for startup diagnostics
- `dive_computer/presentation/providers/download_providers.dart`
- `media/presentation/pages/photo_viewer_page.dart`
- `maps/data/services/tile_cache_service.dart`
- `core/tide/tide_calculator.dart`
- `core/services/database_location_service.dart`

**Recommendation:** Replace with `LoggerService` calls for consistent logging.

### 12.2 TODO/FIXME Comments (9 files)

Localization TODOs that should be tracked:

- `dive_log/presentation/pages/dive_list_page.dart:208` — `// TODO: l10n - needs context for SearchDelegate.searchFieldLabel`
- `dive_log/presentation/widgets/dive_list_content.dart:744, 754` — `// TODO: l10n` for snackbar messages
- `dive_planner/presentation/pages/dive_planner_page.dart`
- `certifications/presentation/widgets/certification_list_content.dart`

### 12.3 Species Repository Seed Data

`species_repository.dart` (657 lines) contains both repository logic and seed data. Extract seed data to `species_seed_data.dart`.

### 12.4 Tile Cache URL Hardcoding

`tile_cache_service.dart` has hardcoded OpenStreetMap tile URL. Extract to constants.

### 12.5 Route Parameter Validation

Navigation route parameters are not validated before use. Consider adding route guards for invalid/missing IDs.

### 12.6 TextEditingController Disposal

Verify that all edit pages properly dispose of `TextEditingController` instances. `dive_edit_page.dart` has 30+ controllers — ensure `dispose()` method covers all of them.

### 12.7 Form Validation Library

The project uses manual form validation with `TextFormField` validators. Consider adopting a form validation library for consistency across edit pages, though the current approach works.

---

## 13. Priority Matrix

### Phase 1: Highest Impact, Lowest Risk (1-2 sprints)

| # | Task | Impact | Files Affected | Lines Saved |
|---|------|--------|----------------|-------------|
| 1 | Extract `ListContentBase` shared widget | HIGH | 9 features | ~2,500 |
| 2 | Extract `DetailPageBase` shared widget | HIGH | 8 features | ~2,000 |
| 3 | Extract `SelectionModeAppBar` widget | MEDIUM | 3 features | ~180 |
| 4 | Create custom exception hierarchy | MEDIUM | 13 files | ~300 |
| 5 | Fix list/set mutations in `setState` | HIGH | 5 files | ~200 fixes |

### Phase 2: Critical File Splits (2-3 sprints)

| # | Task | Impact | Complexity |
|---|------|--------|-----------|
| 6 | Split `dive_detail_page.dart` (5,051 lines) | CRITICAL | HIGH |
| 7 | Split `dive_edit_page.dart` (4,249 lines) | CRITICAL | HIGH |
| 8 | Split `dive_repository_impl.dart` (3,283 lines) | CRITICAL | MEDIUM |
| 9 | Split `dive_profile_chart.dart` (3,032 lines) | CRITICAL | HIGH |
| 10 | Split `settings_page.dart` (2,682 lines) | HIGH | MEDIUM |

### Phase 3: Service Layer Cleanup (3-4 sprints)

| # | Task | Impact | Complexity |
|---|------|--------|-----------|
| 11 | Merge UDDF export/import variants | HIGH | MEDIUM |
| 12 | Extract PDF template base class | MEDIUM | LOW |
| 13 | Split `sync_data_serializer.dart` | MEDIUM | MEDIUM |
| 14 | Split `statistics_repository.dart` | MEDIUM | LOW |
| 15 | Split `uddf_entity_importer.dart` | MEDIUM | MEDIUM |

### Phase 4: Entity & State Refactoring (4-5 sprints)

| # | Task | Impact | Complexity |
|---|------|--------|-----------|
| 16 | Decompose `Dive` entity to composition | HIGH | HIGH |
| 17 | Decompose `AppSettings` to topic objects | MEDIUM | MEDIUM |
| 18 | Extract `ProfileChartConfig` object | MEDIUM | MEDIUM |
| 19 | Replace `setState` with `StateNotifier` in dive pages | HIGH | HIGH |
| 20 | Standardize provider error handling | MEDIUM | LOW |

### Phase 5: Performance & Polish (5+ sprints)

| # | Task | Impact | Complexity |
|---|------|--------|-----------|
| 21 | Add pagination for large lists | MEDIUM | HIGH |
| 22 | Implement photo viewer caching | LOW | LOW |
| 23 | Extract theme builder utility | LOW | LOW |
| 24 | Replace `debugPrint` with `LoggerService` | LOW | LOW |
| 25 | Add const constructors audit | LOW | LOW |
| 26 | Migrate dive_import UDDF to universal_import | MEDIUM | HIGH |
| 27 | Riverpod-based DI for services | MEDIUM | HIGH |
| 28 | Route parameter validation guards | LOW | LOW |
| 29 | Dive computer error handling improvements | MEDIUM | MEDIUM |
| 30 | Add import transaction/rollback | MEDIUM | MEDIUM |

---

## Appendix: Files By Size

All non-generated Dart files exceeding 800 lines:

```
5,051  features/dive_log/presentation/pages/dive_detail_page.dart
4,249  features/dive_log/presentation/pages/dive_edit_page.dart
3,283  features/dive_log/data/repositories/dive_repository_impl.dart
3,032  features/dive_log/presentation/widgets/dive_profile_chart.dart
2,682  features/settings/presentation/pages/settings_page.dart
2,189  core/database/database.dart
1,866  core/services/sync/sync_data_serializer.dart
1,801  core/services/export/uddf/uddf_full_import_service.dart
1,562  features/dive_log/data/repositories/dive_computer_repository_impl.dart
1,557  features/dive_log/data/services/profile_analysis_service.dart
1,518  features/dive_log/presentation/widgets/dive_list_content.dart
1,514  features/equipment/presentation/pages/equipment_detail_page.dart
1,481  core/services/export/uddf/uddf_export_builders.dart
1,450  features/dive_sites/presentation/pages/site_edit_page.dart
1,420  features/statistics/data/repositories/statistics_repository.dart
1,415  features/dive_sites/presentation/pages/site_detail_page.dart
1,399  features/dive_import/data/services/uddf_entity_importer.dart
1,362  features/settings/presentation/providers/export_providers.dart
1,328  features/dive_log/presentation/pages/dive_list_page.dart
1,203  features/settings/presentation/providers/settings_providers.dart
1,173  features/dive_sites/presentation/widgets/site_list_content.dart
1,100  features/media/presentation/pages/photo_viewer_page.dart
1,100  features/dive_log/presentation/widgets/o2_toxicity_card.dart
1,048  features/dive_centers/presentation/pages/dive_center_edit_page.dart
1,031  features/statistics/presentation/widgets/statistics_summary_widget.dart
  990  features/dive_log/domain/entities/dive.dart
  978  core/services/sync/sync_service.dart
  889  core/router/app_router.dart
  852  features/dive_sites/presentation/pages/site_import_page.dart
```
