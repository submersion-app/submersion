# Map View Toggle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Map View a toggle button on desktop that switches the right pane between detail view and map view, instead of navigating to a separate page.

**Architecture:** Extend `MasterDetailScaffold` with an optional `mapBuilder` parameter. When provided, a Map View toggle button appears in the compact app bar. The toggle state is tracked via URL query params (`?view=map`) for consistency with the existing URL-driven state pattern. When map view is active, the right pane shows the map instead of detail/summary.

**Tech Stack:** Flutter, Riverpod, GoRouter (URL query params), flutter_map

---

## Task 1: Extend MasterDetailScaffold with Map Support

**Files:**
- Modify: `lib/shared/widgets/master_detail/master_detail_scaffold.dart`
- Test: `test/shared/widgets/master_detail/master_detail_scaffold_test.dart`

**Context:** The `MasterDetailScaffold` currently supports detail/edit/create modes via URL params. We need to add map view as another mode.

**Step 1: Add mapBuilder parameter to MasterDetailScaffold**

Add to the class parameters (after line 93):

```dart
/// Builder for the map pane when map view is active.
/// If provided, a map toggle button will appear in the master pane header.
///
/// Receives:
/// - [selectedId]: Currently selected item ID (for highlighting on map)
/// - [onItemSelected]: Callback when map marker is tapped
final Widget Function(
  BuildContext context,
  String? selectedId,
  void Function(String?) onItemSelected,
)?
mapBuilder;
```

**Step 2: Add _isMapView getter**

Add after `_mode` getter (around line 151):

```dart
/// Check if map view is active from URL query params
bool get _isMapView {
  final state = GoRouterState.of(context);
  return state.uri.queryParameters['view'] == 'map';
}
```

**Step 3: Add _toggleMapView method**

Add after `_onCancel` method (around line 217):

```dart
/// Toggle between map view and list/detail view
void _toggleMapView() {
  final router = GoRouter.of(context);
  final state = GoRouterState.of(context);
  final currentPath = state.uri.path;
  final selectedId = _selectedId;

  if (_isMapView) {
    // Switch back to detail view
    if (selectedId != null) {
      router.go('$currentPath?selected=$selectedId');
    } else {
      router.go(currentPath);
    }
  } else {
    // Switch to map view
    if (selectedId != null) {
      router.go('$currentPath?selected=$selectedId&view=map');
    } else {
      router.go('$currentPath?view=map');
    }
  }
}
```

**Step 4: Update desktop build method to show map in right pane**

In the `build` method, update the desktop layout (around line 252) to conditionally show map:

```dart
// Detail/Map pane
Expanded(
  child: widget.mapBuilder != null && _isMapView
      ? widget.mapBuilder!(context, selectedId, _onItemSelected)
      : _DetailPane(
          selectedId: selectedId,
          mode: mode,
          detailBuilder: widget.detailBuilder,
          summaryBuilder: widget.summaryBuilder,
          editBuilder: widget.editBuilder,
          createBuilder: widget.createBuilder,
          onClose: () => _onItemSelected(null),
          onSaved: _onSaved,
          onCancel: _onCancel,
        ),
),
```

**Step 5: Pass toggle callback and state to masterBuilder**

The masterBuilder needs to know if map view is active and have access to toggle. Update the signature to include these. We'll do this via a new parameter object or by passing the toggle callback through the existing callbacks.

Actually, simpler approach: Add `isMapView` and `onToggleMapView` parameters to the constructor and pass them to the content widget directly in the list page.

**Step 6: Run tests to verify no regressions**

Run: `flutter test test/shared/widgets/master_detail/`
Expected: All existing tests pass

**Step 7: Commit**

```bash
git add lib/shared/widgets/master_detail/master_detail_scaffold.dart
git commit -m "feat(master-detail): add mapBuilder parameter for map view toggle"
```

---

## Task 2: Create MapViewToggleButton Widget

**Files:**
- Create: `lib/shared/widgets/master_detail/map_view_toggle_button.dart`
- Test: `test/shared/widgets/master_detail/map_view_toggle_button_test.dart`

**Context:** A reusable toggle button that shows active state and handles the toggle.

**Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';

void main() {
  testWidgets('shows map icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              MapViewToggleButton(
                isActive: false,
                onToggle: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.map), findsOneWidget);
  });

  testWidgets('shows filled icon when active', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              MapViewToggleButton(
                isActive: true,
                onToggle: () {},
              ),
            ],
          ),
        ),
      ),
    );

    // When active, uses filled background
    expect(find.byType(IconButton), findsOneWidget);
    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.style?.backgroundColor, isNotNull);
  });

  testWidgets('calls onToggle when pressed', (tester) async {
    var toggleCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              MapViewToggleButton(
                isActive: false,
                onToggle: () => toggleCount++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.map));
    expect(toggleCount, 1);
  });

  testWidgets('shows correct tooltip based on active state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              MapViewToggleButton(
                isActive: false,
                onToggle: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.tooltip, 'Map View');
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/master_detail/map_view_toggle_button_test.dart`
Expected: FAIL with "Target of URI hasn't been generated"

**Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';

/// A toggle button for switching between list/detail view and map view.
///
/// Shows a map icon that is highlighted when map view is active.
class MapViewToggleButton extends StatelessWidget {
  /// Whether map view is currently active.
  final bool isActive;

  /// Callback when the button is pressed.
  final VoidCallback onToggle;

  /// Icon size (default 20 for compact app bars).
  final double iconSize;

  const MapViewToggleButton({
    super.key,
    required this.isActive,
    required this.onToggle,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(Icons.map, size: iconSize),
      tooltip: 'Map View',
      onPressed: onToggle,
      style: isActive
          ? IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/master_detail/map_view_toggle_button_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/shared/widgets/master_detail/map_view_toggle_button.dart test/shared/widgets/master_detail/map_view_toggle_button_test.dart
git commit -m "feat: add MapViewToggleButton widget"
```

---

## Task 3: Update DiveCenterListContent to Support Map Toggle

**Files:**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`
- Test: Existing tests should still pass

**Context:** The list content's compact app bar needs to show the MapViewToggleButton instead of navigating to `/dive-centers/map`.

**Step 1: Add parameters for map toggle**

Add new parameters after `isMapMode` (around line 36):

```dart
/// Whether map view is currently active (for toggle button highlight).
final bool isMapViewActive;

/// Callback when map view toggle is pressed.
/// If null, the map icon will navigate to the map page (mobile behavior).
final VoidCallback? onMapViewToggle;
```

Update constructor to include defaults:

```dart
const DiveCenterListContent({
  // ... existing params
  this.isMapViewActive = false,
  this.onMapViewToggle,
});
```

**Step 2: Update _buildCompactAppBar to use toggle**

Replace the map IconButton (lines 222-226) with conditional logic:

```dart
if (widget.onMapViewToggle != null)
  MapViewToggleButton(
    isActive: widget.isMapViewActive,
    onToggle: widget.onMapViewToggle!,
  )
else
  IconButton(
    icon: const Icon(Icons.map, size: 20),
    tooltip: 'Map View',
    onPressed: () => context.go('/dive-centers/map'),
  ),
```

**Step 3: Add import for MapViewToggleButton**

Add at top of file:

```dart
import 'package:submersion/shared/widgets/master_detail/map_view_toggle_button.dart';
```

**Step 4: Run tests to verify no regressions**

Run: `flutter test test/features/dive_centers/`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart
git commit -m "feat(dive-center-list): add map view toggle support"
```

---

## Task 4: Create DiveCenterMapContent Widget (Extracted from DiveCenterMapPage)

**Files:**
- Create: `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart`
- Test: `test/features/dive_centers/presentation/widgets/dive_center_map_content_test.dart`

**Context:** Extract the map rendering logic from `DiveCenterMapPage` into a reusable widget that can be embedded in the master-detail right pane.

**Step 1: Create the map content widget**

Extract the map building logic from `DiveCenterMapPage._buildMap()` into a standalone widget:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

/// Map content widget for displaying dive centers on a map.
///
/// This is designed to be embedded in the master-detail right pane
/// when map view is active.
class DiveCenterMapContent extends ConsumerStatefulWidget {
  /// Currently selected dive center ID (for highlighting marker).
  final String? selectedId;

  /// Callback when a marker is tapped.
  final void Function(String?) onItemSelected;

  /// Callback when info card details button is tapped.
  final void Function(String centerId)? onDetailsTap;

  const DiveCenterMapContent({
    super.key,
    this.selectedId,
    required this.onItemSelected,
    this.onDetailsTap,
  });

  @override
  ConsumerState<DiveCenterMapContent> createState() =>
      _DiveCenterMapContentState();
}

class _DiveCenterMapContentState extends ConsumerState<DiveCenterMapContent>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  Widget build(BuildContext context) {
    final centersAsync = ref.watch(diveCenterListNotifierProvider);

    return centersAsync.when(
      data: (centers) => _buildMapWithInfoCard(context, centers),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading dive centers: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.read(diveCenterListNotifierProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWithInfoCard(BuildContext context, List<DiveCenter> centers) {
    final selectedCenter = widget.selectedId != null
        ? centers.where((c) => c.id == widget.selectedId).firstOrNull
        : null;

    return Stack(
      children: [
        _buildMap(context, centers),
        if (selectedCenter != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildMapInfoCard(context, selectedCenter),
              ),
            ),
          ),
      ],
    );
  }

  // ... rest of map building methods extracted from DiveCenterMapPage
  // Include: _buildMap, _buildMarker, _buildClusterMarker, _getMarkerColor,
  // _onMarkerTapped, _animateToCluster, _fitAllCenters, _calculateBounds
}
```

**Step 2: Write basic test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';

void main() {
  testWidgets('shows loading indicator when loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DiveCenterMapContent(
              onItemSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

**Step 3: Run tests**

Run: `flutter test test/features/dive_centers/presentation/widgets/dive_center_map_content_test.dart`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart test/features/dive_centers/presentation/widgets/dive_center_map_content_test.dart
git commit -m "feat: extract DiveCenterMapContent for embedded map view"
```

---

## Task 5: Update DiveCenterListPage to Use Map Toggle

**Files:**
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_list_page.dart`

**Context:** Wire up the `mapBuilder` in `MasterDetailScaffold` and pass toggle state to list content.

**Step 1: Import required files**

Add imports:

```dart
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
```

**Step 2: Convert to StatefulWidget to access GoRouterState**

The page needs to read URL params for `view=map`. Convert from `ConsumerWidget` to `ConsumerStatefulWidget`:

```dart
class DiveCenterListPage extends ConsumerStatefulWidget {
  const DiveCenterListPage({super.key});

  @override
  ConsumerState<DiveCenterListPage> createState() => _DiveCenterListPageState();
}

class _DiveCenterListPageState extends ConsumerState<DiveCenterListPage> {
  bool get _isMapView {
    final state = GoRouterState.of(context);
    return state.uri.queryParameters['view'] == 'map';
  }

  void _toggleMapView() {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;
    final selectedId = state.uri.queryParameters['selected'];

    if (_isMapView) {
      if (selectedId != null) {
        router.go('$currentPath?selected=$selectedId');
      } else {
        router.go(currentPath);
      }
    } else {
      if (selectedId != null) {
        router.go('$currentPath?selected=$selectedId&view=map');
      } else {
        router.go('$currentPath?view=map');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... existing build logic with additions
  }
}
```

**Step 3: Add mapBuilder to MasterDetailScaffold**

In the desktop branch, add `mapBuilder`:

```dart
return MasterDetailScaffold(
  sectionId: 'dive-centers',
  masterBuilder: (context, onItemSelected, selectedId) =>
      DiveCenterListContent(
        onItemSelected: onItemSelected,
        selectedId: selectedId,
        showAppBar: false,
        isMapViewActive: _isMapView,
        onMapViewToggle: _toggleMapView,
      ),
  detailBuilder: (context, centerId) => DiveCenterDetailPage(
    // ... existing
  ),
  summaryBuilder: (context) => const DiveCenterSummaryWidget(),
  mapBuilder: (context, selectedId, onItemSelected) => DiveCenterMapContent(
    selectedId: selectedId,
    onItemSelected: onItemSelected,
    onDetailsTap: (centerId) => context.push('/dive-centers/$centerId'),
  ),
  // ... rest of existing params
);
```

**Step 4: Run tests**

Run: `flutter test test/features/dive_centers/`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/features/dive_centers/presentation/pages/dive_center_list_page.dart
git commit -m "feat(dive-centers): integrate map view toggle in list page"
```

---

## Task 6: Repeat for SiteListContent and SiteListPage

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_list_page.dart`

**Context:** Apply same pattern as dive centers to sites.

**Steps:** Follow same pattern as Tasks 3-5 for sites.

**Commit:**

```bash
git add lib/features/dive_sites/
git commit -m "feat(sites): integrate map view toggle in list page"
```

---

## Task 7: Repeat for DiveListContent and DiveListPage

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Create: `lib/features/dive_log/presentation/widgets/dive_map_content.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart`

**Context:** Apply same pattern as dive centers to dives.

**Steps:** Follow same pattern as Tasks 3-5 for dives.

**Commit:**

```bash
git add lib/features/dive_log/
git commit -m "feat(dives): integrate map view toggle in list page"
```

---

## Task 8: Update Mobile App Bar to Keep Navigation Behavior

**Files:**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`

**Context:** On mobile (when `showAppBar: true`), the Map View button should still navigate to the full map page, not toggle.

**Step 1: Update full AppBar map button**

In the full `AppBar` section of each list content, keep the navigation behavior:

```dart
IconButton(
  icon: const Icon(Icons.map),
  tooltip: 'Map View',
  onPressed: () => context.go('/dive-centers/map'),  // Keep navigation
),
```

Only the compact app bar (desktop master pane) should use the toggle.

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 3: Commit**

```bash
git add lib/features/*/presentation/widgets/*_list_content.dart
git commit -m "fix: keep map navigation on mobile, toggle only on desktop"
```

---

## Task 9: Format Code and Run Full Test Suite

**Step 1: Format all code**

```bash
dart format lib/ test/
```

**Step 2: Run analyzer**

```bash
flutter analyze
```

**Step 3: Run full test suite**

```bash
flutter test
```

Expected: All tests pass, no analyzer issues

**Step 4: Commit any formatting changes**

```bash
git add -A
git commit -m "style: format code"
```

---

## Task 10: Manual Testing and Final Review

**Step 1: Test on desktop**

- Open app at >=1100px width
- Navigate to Dive Centers
- Click Map View toggle - right pane should show map
- Click a list item - map should pan and highlight marker
- Click Map View toggle again - right pane should show detail view
- Verify URL shows `?view=map` when map is active

**Step 2: Test on mobile**

- Open app at <1100px width
- Navigate to Dive Centers
- Click Map View icon - should navigate to `/dive-centers/map` (separate page)

**Step 3: Repeat for Sites and Dives**

**Step 4: Commit final changes**

```bash
git add -A
git commit -m "feat: map view toggle in master-detail layout

- Add mapBuilder parameter to MasterDetailScaffold
- Create MapViewToggleButton widget
- Extract map content widgets for embedding
- Toggle switches right pane between detail and map
- URL param ?view=map tracks state
- Mobile retains full-page map navigation"
```
