# Table Mode: Full-Width Default, Details Toggle, and Entity Settings

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make table mode full-width by default in all sections, add a Details toggle to show/hide the detail pane, and expand Settings > Appearance with field configuration for all entity types.

**Architecture:** A shared `TableModeLayout` widget encapsulates the layout state machine (full-width / details / map / details+map / profile). Each section's list page routes table mode through this widget instead of MasterDetailScaffold. A persisted `tableDetailsPaneProvider` manages the toggle state. Settings > Appearance gets an entity-aware ColumnConfigPage and new card view config models.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Drift ORM, go_router, Material 3

**Spec:** `docs/superpowers/specs/2026-04-06-table-mode-full-width-details-toggle-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/shared/widgets/table_mode_layout/table_mode_layout.dart` | Shared layout widget managing the table mode state machine |
| `lib/shared/providers/table_details_pane_provider.dart` | Per-section details pane toggle, persisted per-diver |
| `lib/shared/models/entity_card_view_config.dart` | Generic `EntityCardViewConfig<F>` model for card field configuration |
| `test/shared/widgets/table_mode_layout/table_mode_layout_test.dart` | Widget tests for TableModeLayout |
| `test/shared/providers/table_details_pane_provider_test.dart` | Provider tests |
| `test/shared/models/entity_card_view_config_test.dart` | Model serialization tests |

### Modified Files (per section)

Each section modifies 2-3 files:
- `lib/features/<section>/presentation/pages/*_list_page.dart` -- table mode bypass
- `lib/features/<section>/presentation/widgets/*_list_content.dart` -- simplified table scaffold
- `lib/features/<section>/presentation/providers/*_providers.dart` -- card config providers (later phase)
- `test/features/<section>/presentation/widgets/*_list_content_test.dart` -- updated tests

### Modified Files (settings/infrastructure)

| File | Change |
|------|--------|
| `lib/features/settings/presentation/pages/column_config_page.dart` | Add entity section selector |
| `lib/features/settings/presentation/pages/appearance_page.dart` | Add details pane toggles per section |
| `lib/features/settings/data/repositories/diver_settings_repository.dart` | New per-section toggle fields |
| `lib/core/database/database.dart` | New columns in `diver_settings` table for per-section toggles |
| `lib/features/dive_log/presentation/providers/view_config_providers.dart` | Expose card config providers via generic interface |

---

## Phase 1: Foundation

### Task 1: Details Pane Toggle Provider

Create the persisted per-section toggle provider that controls whether the detail pane is shown in table mode.

**Files:**
- Create: `lib/shared/providers/table_details_pane_provider.dart`
- Create: `test/shared/providers/table_details_pane_provider_test.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart`
- Modify: `lib/core/database/database.dart`

- [ ] **Step 1: Add database columns for per-section details pane toggles**

Add new boolean columns to the `diverSettings` table in `lib/core/database/database.dart`. Follow the existing `showProfilePanelInTableView` pattern:

```dart
// In DiverSettings table definition, add after showProfilePanelInTableView:
BoolColumn get showTableDetailsPaneDives =>
    boolean().withDefault(const Constant(false))();
BoolColumn get showTableDetailsPaneSites =>
    boolean().withDefault(const Constant(false))();
BoolColumn get showTableDetailsPaneBuddies =>
    boolean().withDefault(const Constant(false))();
BoolColumn get showTableDetailsPaneTrips =>
    boolean().withDefault(const Constant(false))();
BoolColumn get showTableDetailsPaneEquipment =>
    boolean().withDefault(const Constant(false))();
BoolColumn get showTableDetailsPaneDiveCenters =>
    boolean().withDefault(const Constant(false))();
BoolColumn get showTableDetailsPaneCertifications =>
    boolean().withDefault(const Constant(false))();
BoolColumn get showTableDetailsPaneCourses =>
    boolean().withDefault(const Constant(false))();
```

Bump the schema version and add the migration. Run `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 2: Add settings repository read/write for the new columns**

In `diver_settings_repository.dart`, add the new fields to the `_mapRowToAppSettings` method and the `updateSettingsForDiver` method. Also add the fields to `AppSettings` if not already present. Follow the pattern of `showProfilePanelInTableView`.

- [ ] **Step 3: Write the provider test**

```dart
// test/shared/providers/table_details_pane_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

void main() {
  group('tableDetailsPaneProvider', () {
    test('defaults to false for unknown section', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final value = container.read(tableDetailsPaneProvider('sites'));
      expect(value, isFalse);
    });

    test('can be toggled to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tableDetailsPaneProvider('sites').notifier).state = true;
      expect(container.read(tableDetailsPaneProvider('sites')), isTrue);
    });

    test('sections are independent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tableDetailsPaneProvider('sites').notifier).state = true;
      expect(container.read(tableDetailsPaneProvider('buddies')), isFalse);
    });
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/shared/providers/table_details_pane_provider_test.dart`
Expected: FAIL (provider not defined)

- [ ] **Step 5: Implement the provider**

```dart
// lib/shared/providers/table_details_pane_provider.dart
import 'package:submersion/core/providers/provider.dart';

/// Per-section toggle for showing the details pane in table mode.
///
/// Keyed by section name (e.g., 'dives', 'sites', 'buddies').
/// Defaults to false (details pane hidden). Initialized from persisted
/// settings in each section's list page initState.
final tableDetailsPaneProvider = StateProvider.family<bool, String>(
  (ref, sectionKey) => false,
);
```

Note: The initial value is always `false`. Each section's list page will override this from persisted settings in `initState`, following the same pattern as `showProfilePanelProvider` which defaults to `true` but gets overridden from settings.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/shared/providers/table_details_pane_provider_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```
feat: add details pane toggle provider and database columns

Per-section boolean toggle for showing/hiding the detail pane in
table mode. Defaults to hidden. Persisted per-diver via settings.
```

---

### Task 2: `TableModeLayout` Widget -- Core Structure

Build the shared layout widget that manages the table mode state machine.

**Files:**
- Create: `lib/shared/widgets/table_mode_layout/table_mode_layout.dart`
- Create: `test/shared/widgets/table_mode_layout/table_mode_layout_test.dart`

- [ ] **Step 1: Write failing test for default full-width layout**

```dart
// test/shared/widgets/table_mode_layout/table_mode_layout_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

import '../../../helpers/test_app.dart';

Widget _buildLayout({
  bool detailsOn = false,
  Widget? mapBuilder,
  Widget? profilePanelBuilder,
  String sectionKey = 'test',
}) {
  return testApp(
    overrides: [
      tableDetailsPaneProvider(sectionKey).overrideWith(
        (ref) => detailsOn,
      ),
    ],
    child: TableModeLayout(
      sectionKey: sectionKey,
      appBarTitle: 'Test Section',
      tableContent: const Text('TABLE_CONTENT'),
      detailBuilder: (id) => Text('DETAIL_$id'),
      summaryBuilder: () => const Text('SUMMARY'),
      selectedId: 'item-1',
      onEntitySelected: (_) {},
      mapContent: mapBuilder,
      profilePanelContent: profilePanelBuilder,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.view_column_outlined),
          onPressed: () {},
        ),
      ],
    ),
  );
}

void main() {
  group('TableModeLayout', () {
    testWidgets('renders full-width table by default', (tester) async {
      await tester.pumpWidget(_buildLayout());
      await tester.pumpAndSettle();

      expect(find.text('TABLE_CONTENT'), findsOneWidget);
      expect(find.text('Test Section'), findsOneWidget);
      // Detail pane should not be visible
      expect(find.text('DETAIL_item-1'), findsNothing);
      expect(find.text('SUMMARY'), findsNothing);
    });

    testWidgets('shows details toggle button', (tester) async {
      await tester.pumpWidget(_buildLayout());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.vertical_split), findsOneWidget);
    });

    testWidgets('shows column settings action', (tester) async {
      await tester.pumpWidget(_buildLayout());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/table_mode_layout/table_mode_layout_test.dart`
Expected: FAIL (widget not defined)

- [ ] **Step 3: Implement the widget skeleton**

```dart
// lib/shared/widgets/table_mode_layout/table_mode_layout.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Shared layout widget for table mode across all entity sections.
///
/// Manages the layout state machine:
/// - Default: full-width table
/// - Details ON: MasterDetailScaffold with table as master, detail right
/// - Map ON: Row with table left, map right
/// - Details + Map: MasterDetailScaffold with map-above-table as master
/// - Profile ON: profile panel above full-width table (Dives only)
/// - Profile + Map: Row with profile-above-table left, map right (Dives only)
class TableModeLayout extends ConsumerWidget {
  final String sectionKey;
  final String appBarTitle;
  final Widget tableContent;
  final Widget Function(String id) detailBuilder;
  final Widget Function() summaryBuilder;
  final Widget Function(BuildContext context, String id,
      void Function(String) onSaved, VoidCallback onCancel)? editBuilder;
  final Widget Function(BuildContext context,
      void Function(String) onSaved, VoidCallback onCancel)? createBuilder;
  final Widget? mapContent;
  final Widget? profilePanelContent;
  final List<Widget>? appBarActions;
  final String? selectedId;
  final void Function(String) onEntitySelected;
  final void Function(String)? onEntityDoubleTap;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final void Function(String)? onSelectionChanged;
  final PreferredSizeWidget? selectionAppBar;
  final Widget? floatingActionButton;
  final bool isMapViewActive;
  final VoidCallback? onMapViewToggle;

  const TableModeLayout({
    super.key,
    required this.sectionKey,
    required this.appBarTitle,
    required this.tableContent,
    required this.detailBuilder,
    required this.summaryBuilder,
    this.editBuilder,
    this.createBuilder,
    this.mapContent,
    this.profilePanelContent,
    this.appBarActions,
    this.selectedId,
    required this.onEntitySelected,
    this.onEntityDoubleTap,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.selectionAppBar,
    this.floatingActionButton,
    this.isMapViewActive = false,
    this.onMapViewToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
    final showDetails = isDesktop &&
        ref.watch(tableDetailsPaneProvider(sectionKey));
    final showMap = isDesktop && isMapViewActive && mapContent != null;
    final showProfile = profilePanelContent != null &&
        !showDetails &&
        ref.watch(showProfilePanelProvider);

    // Build toggle buttons for the app bar
    final toggleActions = _buildToggleActions(
      context, ref, isDesktop, showDetails, showMap, showProfile,
    );

    final allActions = [
      ...toggleActions,
      if (appBarActions != null) ...[
        SizedBox(
          height: 24,
          child: VerticalDivider(
            width: 16,
            thickness: 1,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.5),
          ),
        ),
        ...appBarActions!,
      ],
    ];

    // Build the table content with optional profile panel
    final tableWithProfile = showProfile
        ? Column(
            children: [
              profilePanelContent!,
              Expanded(child: tableContent),
            ],
          )
        : tableContent;

    // --- Layout state machine ---

    // State: Details ON (with or without map)
    if (showDetails) {
      final masterContent = showMap
          ? Column(
              children: [
                Expanded(child: mapContent!),
                Expanded(flex: 2, child: tableContent),
              ],
            )
          : tableContent;

      return MasterDetailScaffold(
        sectionId: sectionKey,
        masterBuilder: (context, onItemSelected, selId) {
          return Scaffold(
            appBar: isSelectionMode
                ? selectionAppBar
                : AppBar(
                    title: Text(appBarTitle),
                    actions: allActions,
                  ),
            body: masterContent,
          );
        },
        detailBuilder: (context, id) => detailBuilder(id),
        summaryBuilder: (context) => summaryBuilder(),
        editBuilder: editBuilder,
        createBuilder: createBuilder,
        floatingActionButton: isSelectionMode ? null : floatingActionButton,
      );
    }

    // State: Map ON only (no details)
    if (showMap) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    title: Text(appBarTitle),
                    actions: allActions,
                  ),
                  Expanded(child: tableWithProfile),
                ],
              ),
            ),
            Expanded(child: mapContent!),
          ],
        ),
        floatingActionButton: isSelectionMode ? null : floatingActionButton,
      );
    }

    // State: Default full-width (possibly with profile panel)
    return Scaffold(
      appBar: isSelectionMode
          ? selectionAppBar
          : AppBar(
              title: Text(appBarTitle),
              actions: allActions,
            ),
      body: tableWithProfile,
      floatingActionButton: isSelectionMode ? null : floatingActionButton,
    );
  }

  // showProfilePanelProvider is imported from:
  // package:submersion/features/dive_log/presentation/providers/highlight_providers.dart

  List<Widget> _buildToggleActions(
    BuildContext context,
    WidgetRef ref,
    bool isDesktop,
    bool showDetails,
    bool showMap,
    bool showProfile,
  ) {
    if (!isDesktop) return [];

    final primary = Theme.of(context).colorScheme.primary;
    final actions = <Widget>[];

    // Profile toggle (Dives only)
    if (profilePanelContent != null) {
      actions.add(
        IconButton(
          icon: Icon(
            Icons.area_chart,
            color: showProfile ? primary : null,
          ),
          tooltip: 'Toggle profile panel',
          onPressed: () {
            final newValue = !ref.read(showProfilePanelProvider);
            ref.read(showProfilePanelProvider.notifier).state = newValue;
            // Mutual exclusion: turn off details if turning on profile
            if (newValue) {
              ref.read(
                tableDetailsPaneProvider(sectionKey).notifier,
              ).state = false;
            }
          },
        ),
      );
    }

    // Details toggle
    actions.add(
      IconButton(
        icon: Icon(
          Icons.vertical_split,
          color: showDetails ? primary : null,
        ),
        tooltip: 'Toggle details pane',
        onPressed: () {
          final newValue = !ref.read(
            tableDetailsPaneProvider(sectionKey),
          );
          ref.read(
            tableDetailsPaneProvider(sectionKey).notifier,
          ).state = newValue;
          // Mutual exclusion: turn off profile if turning on details
          if (newValue && profilePanelContent != null) {
            ref.read(showProfilePanelProvider.notifier).state = false;
          }
        },
      ),
    );

    // Map toggle (sections with map support)
    if (mapContent != null || onMapViewToggle != null) {
      actions.add(
        IconButton(
          icon: Icon(
            Icons.map,
            color: showMap ? primary : null,
          ),
          tooltip: 'Toggle map view',
          onPressed: onMapViewToggle,
        ),
      );
    }

    return actions;
  }
}
```

Note: The `showProfilePanelProvider` static reference should be replaced with the actual import from `highlight_providers.dart`. The implementation above is a skeleton -- the exact MasterDetailScaffold builder signatures need to match the constructor (see Task 2 Step 5 for refinements).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/table_mode_layout/table_mode_layout_test.dart`
Expected: PASS (may need adjustments to test helpers and builder signatures)

- [ ] **Step 5: Add tests for details toggle and map states**

Add these tests to the same test file:

```dart
    testWidgets('details toggle shows detail pane', (tester) async {
      await tester.pumpWidget(_buildLayout(detailsOn: true));
      await tester.pumpAndSettle();

      expect(find.text('TABLE_CONTENT'), findsOneWidget);
      // Detail or summary should be visible in the right pane
      expect(
        find.text('DETAIL_item-1').evaluate().isNotEmpty ||
            find.text('SUMMARY').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('map toggle shows side-by-side layout', (tester) async {
      await tester.pumpWidget(
        _buildLayout(mapBuilder: const Text('MAP_CONTENT')),
      );
      // Manually set map active via the widget params
      // This requires adjusting _buildLayout to accept isMapViewActive
      await tester.pumpAndSettle();

      // In the default state (map not active), map should not show
      expect(find.text('MAP_CONTENT'), findsNothing);
    });

    testWidgets('hides details toggle on mobile', (tester) async {
      // Set screen size to mobile
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildLayout());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.vertical_split), findsNothing);
    });
```

- [ ] **Step 6: Run tests, iterate until passing**

Run: `flutter test test/shared/widgets/table_mode_layout/table_mode_layout_test.dart`
Iterate on the widget implementation until all tests pass. The builder signatures for MasterDetailScaffold need to match exactly.

- [ ] **Step 7: Commit**

```
feat: add TableModeLayout shared widget

Layout state machine for table mode: full-width default, details
toggle, map side-by-side, and profile panel support. Manages mutual
exclusion between details and profile toggles.
```

---

## Phase 2: Dives Migration

### Task 3: Migrate Dives to TableModeLayout

The Dives section is the reference implementation and the most complex (has profile panel + map + details).

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Modify: `test/features/dive_log/presentation/widgets/dive_list_content_test.dart`

- [ ] **Step 1: Update `dive_list_page.dart` to route table mode through `TableModeLayout`**

Replace the existing table mode code path (lines 200-212 and `_buildTableMapView`) with `TableModeLayout`. The page should:
- Check `viewMode == ListViewMode.table`
- Return `TableModeLayout` with `sectionKey: 'dives'`
- Pass `mapContent` (DiveMapContent) when `_isMapView` is true
- Pass `profilePanelContent` (DiveProfilePanel)
- Pass all existing builders (detailBuilder, editBuilder, createBuilder, summaryBuilder)
- Pass `isMapViewActive: _isMapView` and `onMapViewToggle: _toggleMapView`
- Remove `_buildTableMapView` method (logic now in TableModeLayout)

Key code change -- replace the table mode section of the `build` method:

```dart
if (viewMode == ListViewMode.table) {
  return TableModeLayout(
    sectionKey: 'dives',
    appBarTitle: context.l10n.nav_dives,
    tableContent: DiveListContent(
      showAppBar: false,
      isMapViewActive: _isMapView,
      onMapViewToggle: _toggleMapView,
    ),
    detailBuilder: (id) => DiveDetailPage(
      diveId: id,
      embedded: true,
      onDeleted: () {
        final state = GoRouterState.of(context);
        context.go(state.uri.path);
      },
    ),
    summaryBuilder: () => const DiveSummaryWidget(),
    editBuilder: (id, onSaved, onCancel) => DiveEditPage(
      diveId: id,
      embedded: true,
      onSaved: onSaved,
      onCancel: onCancel,
    ),
    createBuilder: (onSaved, onCancel) => DiveEditPage(
      embedded: true,
      onSaved: onSaved,
      onCancel: onCancel,
    ),
    mapContent: DiveMapContent(
      selectedId: ref.watch(highlightedDiveIdProvider),
      onItemSelected: (diveId) {
        ref.read(highlightedDiveIdProvider.notifier).state = diveId;
      },
      onDetailsTap: (diveId) {
        context.push('/dives/$diveId');
      },
    ),
    profilePanelContent: const DiveProfilePanel(),
    selectedId: ref.watch(highlightedDiveIdProvider),
    onEntitySelected: (id) {
      ref.read(highlightedDiveIdProvider.notifier).state = id;
    },
    isMapViewActive: _isMapView,
    onMapViewToggle: _toggleMapView,
    appBarActions: [
      IconButton(
        icon: const Icon(Icons.view_column_outlined),
        tooltip: 'Column settings',
        onPressed: () => showTableColumnPicker(context),
      ),
    ],
    floatingActionButton: fab,
  );
}
```

- [ ] **Step 2: Simplify `dive_list_content.dart` table scaffold**

The `_buildTableModeScaffold` method no longer needs the `showAppBar: true` path with its own Scaffold, profile panel toggle, and column settings. When used inside `TableModeLayout`, `showAppBar` is always `false`. Simplify to only return the table content (filter bar + DiveTableView):

```dart
Widget _buildTableModeScaffold(BuildContext context, DiveFilterState filter) {
  final content = _buildTableView(context, filter);

  // When embedded in TableModeLayout (showAppBar: false)
  if (!widget.showAppBar) {
    return Column(
      children: [
        if (_isSelectionMode)
          _buildSelectionBar(const [])
        else
          _buildCompactAppBar(context, filter),
        Expanded(child: content),
      ],
    );
  }

  // Standalone fallback (mobile)
  return Scaffold(
    appBar: _isSelectionMode
        ? _buildSelectionAppBar(const [])
        : _buildAppBar(context, filter, title: context.l10n.nav_dives),
    body: content,
    floatingActionButton: _isSelectionMode ? null : widget.floatingActionButton,
  );
}
```

Remove the profile panel toggle and column settings from the `_buildTableModeScaffold` since `TableModeLayout` handles those.

- [ ] **Step 3: Update existing tests**

Update `test/features/dive_log/presentation/widgets/dive_list_content_test.dart` to account for the simplified table scaffold. The table mode tests that previously checked for profile panel toggle icons and column settings icons in the dive list content may need to move to `TableModeLayout` tests.

- [ ] **Step 4: Run all dive-related tests**

Run: `flutter test test/features/dive_log/`
Expected: PASS (all tests should still pass after migration)

- [ ] **Step 5: Manual smoke test**

Run: `flutter run -d macos`
Verify:
- Dives table mode shows full-width table by default
- Details toggle button appears in the app bar
- Toggling details shows the detail pane on the right with the selected dive
- Profile panel toggle still works and is mutually exclusive with details
- Map toggle still works in all combinations
- Column settings button works

- [ ] **Step 6: Commit**

```
refactor: migrate Dives table mode to TableModeLayout

Dives now routes table mode through the shared TableModeLayout widget.
Profile panel toggle is mutually exclusive with the new Details toggle.
Map view integration preserved.
```

---

## Phase 3: Map-Enabled Section Migrations

### Task 4: Migrate Sites to TableModeLayout

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_list_page.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- Modify: `test/features/dive_sites/presentation/widgets/site_list_content_table_test.dart`

- [ ] **Step 1: Update `site_list_page.dart` to route table mode through TableModeLayout**

Add `viewMode` check before `MasterDetailScaffold`. When table, return `TableModeLayout`:

```dart
final viewMode = ref.watch(siteListViewModeProvider);
if (viewMode == ListViewMode.table) {
  return FocusTraversalGroup(
    child: TableModeLayout(
      sectionKey: 'sites',
      appBarTitle: context.l10n.nav_diveSites,
      tableContent: SiteListContent(
        showAppBar: false,
        isMapViewActive: _isMapView,
        onMapViewToggle: _toggleMapView,
      ),
      detailBuilder: (id) => SiteDetailPage(
        siteId: id,
        embedded: true,
        onDeleted: () {
          final state = GoRouterState.of(context);
          context.go(state.uri.path);
        },
      ),
      summaryBuilder: () => const SiteSummaryWidget(),
      editBuilder: (id, onSaved, onCancel) => SiteEditPage(
        siteId: id,
        embedded: true,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      createBuilder: (onSaved, onCancel) => SiteEditPage(
        embedded: true,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      mapContent: SiteMapContent(
        selectedId: null, // Will be connected to highlighted provider
        onItemSelected: (siteId) {},
        onDetailsTap: (siteId) {
          context.push('/sites/$siteId');
        },
      ),
      selectedId: null, // Sites needs a highlighted ID provider (create if needed)
      onEntitySelected: (id) {},
      isMapViewActive: _isMapView,
      onMapViewToggle: _toggleMapView,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.view_column_outlined),
          tooltip: 'Column settings',
          onPressed: () => showEntityTableColumnPicker<SiteField>(
            context,
            config: ref.read(siteTableConfigProvider),
            adapter: SiteFieldAdapter.instance,
            onToggleColumn: ref.read(siteTableConfigProvider.notifier).toggleColumn,
            onReorderColumn: ref.read(siteTableConfigProvider.notifier).reorderColumn,
            onTogglePin: ref.read(siteTableConfigProvider.notifier).togglePin,
          ),
        ),
      ],
      floatingActionButton: fab,
    ),
  );
}
```

Note: Sites may need a `highlightedSiteIdProvider` similar to `highlightedDiveIdProvider`. Create one if it doesn't exist.

- [ ] **Step 2: Simplify `site_list_content.dart` table scaffold**

Same pattern as Dives: remove the standalone Scaffold path from `_buildTableModeScaffold`, keep only the embedded Column path. Remove column settings and map toggle from the content widget since `TableModeLayout` handles those.

- [ ] **Step 3: Update site table tests**

Update `test/features/dive_sites/presentation/widgets/site_list_content_table_test.dart` to reflect the simplified content widget.

- [ ] **Step 4: Run site tests**

Run: `flutter test test/features/dive_sites/`
Expected: PASS

- [ ] **Step 5: Commit**

```
refactor: migrate Sites table mode to TableModeLayout

Sites now uses full-width table by default with Details and Map toggles.
```

---

### Task 5: Migrate Dive Centers to TableModeLayout

**Files:**
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_list_page.dart`
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`
- Modify: `test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart`

- [ ] **Step 1: Update `dive_center_list_page.dart`**

Same pattern as Sites. Route table mode through `TableModeLayout` with `sectionKey: 'diveCenters'`. Pass `DiveCenterMapContent` as `mapContent`. Pass existing detail/edit/create/summary builders.

- [ ] **Step 2: Simplify `dive_center_list_content.dart` table scaffold**

Remove standalone Scaffold path from `_buildTableModeScaffold`. Keep embedded Column path only.

- [ ] **Step 3: Update dive center table tests**

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_centers/`
Expected: PASS

- [ ] **Step 5: Commit**

```
refactor: migrate Dive Centers table mode to TableModeLayout
```

---

## Phase 4: Non-Map Section Migrations

### Task 6: Migrate Buddies to TableModeLayout

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart`
- Modify: `test/features/buddies/presentation/widgets/buddy_list_content_test.dart`

- [ ] **Step 1: Update `buddy_list_page.dart`**

Route table mode through `TableModeLayout` with `sectionKey: 'buddies'`. No `mapContent` or `profilePanelContent`. Pass existing detail/edit/create/summary builders.

```dart
final viewMode = ref.watch(buddyListViewModeProvider);
if (viewMode == ListViewMode.table) {
  return FocusTraversalGroup(
    child: TableModeLayout(
      sectionKey: 'buddies',
      appBarTitle: context.l10n.nav_buddies,
      tableContent: const BuddyListContent(showAppBar: false),
      detailBuilder: (id) => BuddyDetailPage(
        buddyId: id,
        embedded: true,
        onDeleted: () {
          final state = GoRouterState.of(context);
          context.go(state.uri.path);
        },
      ),
      summaryBuilder: () => const BuddySummaryWidget(),
      editBuilder: (id, onSaved, onCancel) => BuddyEditPage(
        buddyId: id,
        embedded: true,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      createBuilder: (onSaved, onCancel) => BuddyEditPage(
        embedded: true,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      selectedId: null,
      onEntitySelected: (id) {},
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.view_column_outlined),
          tooltip: 'Column settings',
          onPressed: () => showEntityTableColumnPicker<BuddyField>(
            context,
            config: ref.read(buddyTableConfigProvider),
            adapter: BuddyFieldAdapter.instance,
            onToggleColumn: ref.read(buddyTableConfigProvider.notifier).toggleColumn,
            onReorderColumn: ref.read(buddyTableConfigProvider.notifier).reorderColumn,
            onTogglePin: ref.read(buddyTableConfigProvider.notifier).togglePin,
          ),
        ),
      ],
      floatingActionButton: fab,
    ),
  );
}
```

- [ ] **Step 2: Simplify `buddy_list_content.dart` table scaffold**

- [ ] **Step 3: Update buddy table tests**

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/buddies/`
Expected: PASS

- [ ] **Step 5: Commit**

```
refactor: migrate Buddies table mode to TableModeLayout
```

---

### Task 7: Migrate Trips to TableModeLayout

**Files:**
- Modify: `lib/features/trips/presentation/pages/trip_list_page.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart`
- Modify: `test/features/trips/presentation/widgets/trip_list_content_test.dart`

- [ ] **Step 1: Update `trip_list_page.dart`** -- same pattern with `sectionKey: 'trips'`
- [ ] **Step 2: Simplify `trip_list_content.dart` table scaffold**
- [ ] **Step 3: Update trip table tests**
- [ ] **Step 4: Run tests**: `flutter test test/features/trips/` -- Expected: PASS
- [ ] **Step 5: Commit**: `refactor: migrate Trips table mode to TableModeLayout`

---

### Task 8: Migrate Equipment to TableModeLayout

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_list_page.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart`
- Modify: `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`

Note: Equipment has a tabbed UI (Equipment / Equipment Sets). Table mode applies to the Equipment tab. Ensure the tab structure is preserved.

- [ ] **Step 1: Update `equipment_list_page.dart`** -- `sectionKey: 'equipment'`
- [ ] **Step 2: Simplify `equipment_list_content.dart` table scaffold**
- [ ] **Step 3: Update equipment table tests**
- [ ] **Step 4: Run tests**: `flutter test test/features/equipment/` -- Expected: PASS
- [ ] **Step 5: Commit**: `refactor: migrate Equipment table mode to TableModeLayout`

---

### Task 9: Migrate Certifications to TableModeLayout

**Files:**
- Modify: `lib/features/certifications/presentation/pages/certification_list_page.dart`
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart`
- Modify: `test/features/certifications/presentation/widgets/certification_list_content_test.dart`

Note: Certifications only has Detailed + Table modes (no Compact).

- [ ] **Step 1: Update `certification_list_page.dart`** -- `sectionKey: 'certifications'`
- [ ] **Step 2: Simplify `certification_list_content.dart` table scaffold**
- [ ] **Step 3: Update certification table tests**
- [ ] **Step 4: Run tests**: `flutter test test/features/certifications/` -- Expected: PASS
- [ ] **Step 5: Commit**: `refactor: migrate Certifications table mode to TableModeLayout`

---

### Task 10: Migrate Courses to TableModeLayout

**Files:**
- Modify: `lib/features/courses/presentation/pages/course_list_page.dart`
- Modify: `lib/features/courses/presentation/widgets/course_list_content.dart`
- Modify: `test/features/courses/presentation/widgets/course_list_content_test.dart`

Note: Courses only has Detailed + Table modes (no Compact).

- [ ] **Step 1: Update `course_list_page.dart`** -- `sectionKey: 'courses'`
- [ ] **Step 2: Simplify `course_list_content.dart` table scaffold**
- [ ] **Step 3: Update course table tests**
- [ ] **Step 4: Run tests**: `flutter test test/features/courses/` -- Expected: PASS
- [ ] **Step 5: Commit**: `refactor: migrate Courses table mode to TableModeLayout`

---

## Phase 5: Settings Expansion

### Task 11: EntityCardViewConfig Model

Create the generic card view config model that non-Dives sections will use.

**Files:**
- Create: `lib/shared/models/entity_card_view_config.dart`
- Create: `test/shared/models/entity_card_view_config_test.dart`

- [ ] **Step 1: Write serialization tests**

```dart
// test/shared/models/entity_card_view_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';

// Use a test field implementation
import '../../shared/widgets/entity_table/entity_table_view_test.dart'
    show TestField; // Or create a minimal test field

void main() {
  group('EntityCardViewConfig', () {
    test('toJson roundtrips correctly', () {
      final config = EntityCardViewConfig<_TestField>(
        slots: [
          EntityCardSlotConfig(slotId: 'title', field: _TestField.entityName),
          EntityCardSlotConfig(slotId: 'stat1', field: _TestField.entityCount),
        ],
        extraFields: [_TestField.entityName],
      );

      final json = config.toJson();
      final restored = EntityCardViewConfig.fromJson<_TestField>(
        json,
        (name) => _TestField.values.firstWhere((f) => f.name == name),
      );

      expect(restored.slots.length, 2);
      expect(restored.slots[0].slotId, 'title');
      expect(restored.extraFields.length, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement the model**

```dart
// lib/shared/models/entity_card_view_config.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/shared/constants/entity_field.dart';

/// Configuration for a single named slot in a card view.
class EntityCardSlotConfig<F extends EntityField> extends Equatable {
  final String slotId;
  final F field;

  const EntityCardSlotConfig({required this.slotId, required this.field});

  EntityCardSlotConfig<F> copyWith({String? slotId, F? field}) {
    return EntityCardSlotConfig(
      slotId: slotId ?? this.slotId,
      field: field ?? this.field,
    );
  }

  Map<String, dynamic> toJson() {
    return {'slotId': slotId, 'field': field.name};
  }

  static EntityCardSlotConfig<F> fromJson<F extends EntityField>(
    Map<String, dynamic> json,
    F Function(String) fieldFromName,
  ) {
    return EntityCardSlotConfig<F>(
      slotId: json['slotId'] as String,
      field: fieldFromName(json['field'] as String),
    );
  }

  @override
  List<Object?> get props => [slotId, field];
}

/// Configuration for a card-based list view (compact or detailed).
class EntityCardViewConfig<F extends EntityField> extends Equatable {
  final List<EntityCardSlotConfig<F>> slots;
  final List<F> extraFields;

  const EntityCardViewConfig({
    required this.slots,
    this.extraFields = const [],
  });

  EntityCardViewConfig<F> copyWith({
    List<EntityCardSlotConfig<F>>? slots,
    List<F>? extraFields,
  }) {
    return EntityCardViewConfig(
      slots: slots ?? this.slots,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slots': slots.map((s) => s.toJson()).toList(),
      'extraFields': extraFields.map((f) => f.name).toList(),
    };
  }

  static EntityCardViewConfig<F> fromJson<F extends EntityField>(
    Map<String, dynamic> json,
    F Function(String) fieldFromName,
  ) {
    return EntityCardViewConfig<F>(
      slots: (json['slots'] as List<dynamic>)
          .map(
            (s) => EntityCardSlotConfig.fromJson<F>(
              s as Map<String, dynamic>,
              fieldFromName,
            ),
          )
          .toList(),
      extraFields: (json['extraFields'] as List<dynamic>?)
              ?.map((f) => fieldFromName(f as String))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [slots, extraFields];
}
```

- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

```
feat: add EntityCardViewConfig generic model

Generic card view configuration for non-Dives entity sections.
Supports named slots and extra fields with JSON serialization.
```

---

### Task 12: Per-Section Card Config Providers

Add card view configuration providers for each non-Dives section, following the existing Dives `CardViewConfig` pattern.

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart`
- Modify: `lib/features/buddies/presentation/providers/buddy_providers.dart`
- Modify: `lib/features/trips/presentation/providers/trip_providers.dart`
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart`
- Modify: `lib/features/dive_centers/presentation/providers/dive_center_providers.dart`
- Modify: `lib/features/certifications/presentation/providers/certification_providers.dart`
- Modify: `lib/features/courses/presentation/providers/course_providers.dart`

- [ ] **Step 1: Add card config providers for Sites**

In `site_providers.dart`, add default card configs using `EntityCardViewConfig<SiteField>`:

```dart
final siteDetailedCardConfigProvider = StateProvider<EntityCardViewConfig<SiteField>>(
  (ref) => EntityCardViewConfig<SiteField>(
    slots: [
      EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
      EntityCardSlotConfig(slotId: 'date', field: SiteField.location),
      EntityCardSlotConfig(slotId: 'stat1', field: SiteField.maxDepth),
      EntityCardSlotConfig(slotId: 'stat2', field: SiteField.diveCount),
    ],
    extraFields: [],
  ),
);

final siteCompactCardConfigProvider = StateProvider<EntityCardViewConfig<SiteField>>(
  (ref) => EntityCardViewConfig<SiteField>(
    slots: [
      EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
      EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
      EntityCardSlotConfig(slotId: 'stat1', field: SiteField.maxDepth),
      EntityCardSlotConfig(slotId: 'stat2', field: SiteField.diveCount),
    ],
  ),
);
```

- [ ] **Step 2: Add card config providers for remaining sections**

Repeat for Buddies, Trips, Equipment, Dive Centers, Certifications, Courses. Each gets sensible default slot assignments based on their current hardcoded list tile layouts.

- [ ] **Step 3: Run tests to verify no regressions**

Run: `flutter test`
Expected: PASS

- [ ] **Step 4: Commit**

```
feat: add card view config providers for all entity sections

Default slot assignments for detailed and compact card views,
enabling user customization via Settings > Appearance.
```

---

### Task 13: Entity-Aware ColumnConfigPage

Expand the existing `ColumnConfigPage` with a section selector dropdown.

**Files:**
- Modify: `lib/features/settings/presentation/pages/column_config_page.dart`
- Modify: `test/features/settings/presentation/pages/column_config_page_test.dart`

- [ ] **Step 1: Add section selector dropdown**

Add a dropdown above the existing view mode dropdown that lets users select which entity section to configure. Options: Dives, Sites, Buddies, Trips, Equipment, Dive Centers, Certifications, Courses.

```dart
// New state variable
String _selectedSection = 'dives';

// In build(), add before the view mode dropdown:
Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
  child: Row(
    children: [
      Text('Section'),
      const SizedBox(width: 16),
      DropdownButton<String>(
        value: _selectedSection,
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedSection = value);
          }
        },
        items: const [
          DropdownMenuItem(value: 'dives', child: Text('Dives')),
          DropdownMenuItem(value: 'sites', child: Text('Sites')),
          DropdownMenuItem(value: 'buddies', child: Text('Buddies')),
          DropdownMenuItem(value: 'trips', child: Text('Trips')),
          DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
          DropdownMenuItem(value: 'diveCenters', child: Text('Dive Centers')),
          DropdownMenuItem(value: 'certifications', child: Text('Certifications')),
          DropdownMenuItem(value: 'courses', child: Text('Courses')),
        ],
      ),
    ],
  ),
),
```

- [ ] **Step 2: Route the view mode sections to the correct providers based on selected section**

The `_buildModeSection()` method needs to use the section-specific providers. For the table tab, use the section's `EntityTableViewConfig` provider. For detailed/compact tabs, use the section's `EntityCardViewConfig` provider.

This requires parameterizing `_TableColumnConfigSection`, `_DetailedCardConfigSection`, and `_SlotCardConfigSection` to accept the section's providers and field adapter.

- [ ] **Step 3: Adjust available view modes per section**

Certifications and Courses only have Detailed + Table (no Compact). The view mode dropdown should filter based on the selected section:

```dart
List<ListViewMode> _availableModes() {
  return switch (_selectedSection) {
    'certifications' || 'courses' => [ListViewMode.table, ListViewMode.detailed],
    _ => [ListViewMode.table, ListViewMode.detailed, ListViewMode.compact],
  };
}
```

- [ ] **Step 4: Update tests**

Update `column_config_page_test.dart` to verify:
- Section selector renders with all 8 options
- Switching section changes which providers are used
- Available view modes adjust for certifications/courses

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/settings/`
Expected: PASS

- [ ] **Step 6: Commit**

```
feat: make ColumnConfigPage entity-aware with section selector

Users can now configure table columns, presets, and card view fields
for all entity sections from Settings > Appearance.
```

---

### Task 14: Details Pane Toggles in Appearance Page

Add per-section toggles for the details pane default state.

**Files:**
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart`
- Modify: `test/features/settings/presentation/pages/settings_page_test.dart`

- [ ] **Step 1: Add "Table View" section to Appearance page**

Below the existing column config entry, add a new section with `SwitchListTile` for each entity section:

```dart
// Table View section header
_buildSectionHeader(context, 'Table View'),

// Existing column config link
ListTile(
  title: Text(context.l10n.settings_appearance_columnConfig),
  subtitle: Text(context.l10n.settings_appearance_columnConfig_subtitle),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/appearance/column-config'),
),

// Details pane toggles
const Divider(),
Padding(
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
  child: Text(
    'Show details pane in table mode',
    style: theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    ),
  ),
),
for (final entry in [
  ('dives', 'Dives'),
  ('sites', 'Sites'),
  ('buddies', 'Buddies'),
  ('trips', 'Trips'),
  ('equipment', 'Equipment'),
  ('diveCenters', 'Dive Centers'),
  ('certifications', 'Certifications'),
  ('courses', 'Courses'),
])
  SwitchListTile(
    title: Text(entry.$2),
    value: ref.watch(tableDetailsPaneProvider(entry.$1)),
    onChanged: (value) {
      ref.read(tableDetailsPaneProvider(entry.$1).notifier).state = value;
      // Persist to diver settings
      _saveDetailsPaneToggle(entry.$1, value);
    },
  ),
```

- [ ] **Step 2: Implement `_saveDetailsPaneToggle` persistence**

Write the toggle value to the diver settings repository using the fields added in Task 1.

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/settings/`
Expected: PASS

- [ ] **Step 4: Commit**

```
feat: add details pane toggles to Settings > Appearance

Per-section toggles for showing the details pane by default in
table mode. Persisted per-diver.
```

---

## Phase 6: Full Verification

### Task 15: Full Test Suite and Formatting

- [ ] **Step 1: Run dart format**

Run: `dart format lib/ test/`

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 4: Fix any failures, then commit**

```
fix: address test failures and formatting from table mode migration
```

- [ ] **Step 5: Manual smoke test all sections**

Run: `flutter run -d macos`

Verify for each section (Dives, Sites, Buddies, Trips, Equipment, Dive Centers, Certifications, Courses):
- Table mode defaults to full-width
- Details toggle button appears (desktop only)
- Toggling details shows the detail pane with the selected entity
- Editing works from the detail pane overflow menu
- Column settings button works
- For Dives: profile panel toggle is mutually exclusive with details
- For Sites, Dive Centers: map toggle works in all combinations
- Settings > Appearance: section selector in column config works
- Settings > Appearance: details pane toggles persist
