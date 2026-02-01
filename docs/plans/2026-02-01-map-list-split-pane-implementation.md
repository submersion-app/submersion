# Map-List Split Pane Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** On desktop (>=1100px), show the list in a left pane and the map in the right pane when viewing Dives/Sites/Dive Centers in map mode.

**Architecture:** Create a new `MapListScaffold` widget that combines the existing list content widgets with the map, using the same breakpoint system as `MasterDetailScaffold`. Add an info card overlay for selection details and a collapse toggle for full-screen map mode.

**Tech Stack:** Flutter, Riverpod for state management, FlutterMap for maps, go_router for navigation.

---

## Task 1: Create MapListSelectionState and Provider

**Files:**
- Create: `lib/shared/providers/map_list_selection_provider.dart`
- Test: `test/shared/providers/map_list_selection_provider_test.dart`

**Step 1: Write the failing test**

```dart
// test/shared/providers/map_list_selection_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

void main() {
  group('MapListSelectionState', () {
    test('initial state has null selectedId and isCollapsed false', () {
      const state = MapListSelectionState();
      expect(state.selectedId, isNull);
      expect(state.isCollapsed, isFalse);
    });

    test('copyWith updates selectedId', () {
      const state = MapListSelectionState();
      final updated = state.copyWith(selectedId: 'test-id');
      expect(updated.selectedId, 'test-id');
      expect(updated.isCollapsed, isFalse);
    });

    test('copyWith updates isCollapsed', () {
      const state = MapListSelectionState();
      final updated = state.copyWith(isCollapsed: true);
      expect(updated.selectedId, isNull);
      expect(updated.isCollapsed, isTrue);
    });

    test('copyWith can clear selectedId with clearSelectedId', () {
      const state = MapListSelectionState(selectedId: 'test-id');
      final updated = state.copyWith(clearSelectedId: true);
      expect(updated.selectedId, isNull);
    });
  });

  group('MapListSelectionNotifier', () {
    test('select updates selectedId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        mapListSelectionProvider('sites').notifier,
      );
      notifier.select('site-123');

      final state = container.read(mapListSelectionProvider('sites'));
      expect(state.selectedId, 'site-123');
    });

    test('deselect clears selectedId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        mapListSelectionProvider('sites').notifier,
      );
      notifier.select('site-123');
      notifier.deselect();

      final state = container.read(mapListSelectionProvider('sites'));
      expect(state.selectedId, isNull);
    });

    test('toggleCollapse toggles isCollapsed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        mapListSelectionProvider('sites').notifier,
      );
      expect(container.read(mapListSelectionProvider('sites')).isCollapsed, isFalse);

      notifier.toggleCollapse();
      expect(container.read(mapListSelectionProvider('sites')).isCollapsed, isTrue);

      notifier.toggleCollapse();
      expect(container.read(mapListSelectionProvider('sites')).isCollapsed, isFalse);
    });

    test('different section keys have independent state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapListSelectionProvider('sites').notifier).select('site-1');
      container.read(mapListSelectionProvider('dive-centers').notifier).select('center-1');

      expect(container.read(mapListSelectionProvider('sites')).selectedId, 'site-1');
      expect(container.read(mapListSelectionProvider('dive-centers')).selectedId, 'center-1');
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/shared/providers/map_list_selection_provider_test.dart`
Expected: FAIL - file not found

**Step 3: Write minimal implementation**

```dart
// lib/shared/providers/map_list_selection_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for map-list split pane selection and collapse state.
class MapListSelectionState {
  final String? selectedId;
  final bool isCollapsed;

  const MapListSelectionState({
    this.selectedId,
    this.isCollapsed = false,
  });

  MapListSelectionState copyWith({
    String? selectedId,
    bool? isCollapsed,
    bool clearSelectedId = false,
  }) {
    return MapListSelectionState(
      selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }
}

/// Notifier for managing map-list selection state.
class MapListSelectionNotifier extends StateNotifier<MapListSelectionState> {
  MapListSelectionNotifier() : super(const MapListSelectionState());

  void select(String id) {
    state = state.copyWith(selectedId: id);
  }

  void deselect() {
    state = state.copyWith(clearSelectedId: true);
  }

  void toggleCollapse() {
    state = state.copyWith(isCollapsed: !state.isCollapsed);
  }

  void setCollapsed(bool collapsed) {
    state = state.copyWith(isCollapsed: collapsed);
  }
}

/// Provider for map-list selection state, keyed by section (e.g., 'sites', 'dive-centers').
final mapListSelectionProvider = StateNotifierProvider.family<
    MapListSelectionNotifier, MapListSelectionState, String>(
  (ref, sectionKey) => MapListSelectionNotifier(),
);
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/shared/providers/map_list_selection_provider_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/shared/providers/map_list_selection_provider.dart test/shared/providers/map_list_selection_provider_test.dart
git commit -m "feat: add MapListSelectionProvider for split-pane state management"
```

---

## Task 2: Create MapInfoCard Widget

**Files:**
- Create: `lib/shared/widgets/map_list_layout/map_info_card.dart`
- Test: `test/shared/widgets/map_list_layout/map_info_card_test.dart`

**Step 1: Write the failing test**

```dart
// test/shared/widgets/map_list_layout/map_info_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

void main() {
  Widget buildTestWidget({
    required String title,
    String? subtitle,
    Widget? leading,
    VoidCallback? onTap,
    VoidCallback? onDetailsTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: MapInfoCard(
                title: title,
                subtitle: subtitle,
                leading: leading,
                onTap: onTap,
                onDetailsTap: onDetailsTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('displays title', (tester) async {
    await tester.pumpWidget(buildTestWidget(title: 'Test Site'));
    expect(find.text('Test Site'), findsOneWidget);
  });

  testWidgets('displays subtitle when provided', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      title: 'Test Site',
      subtitle: 'Location info',
    ));
    expect(find.text('Location info'), findsOneWidget);
  });

  testWidgets('hides subtitle when null', (tester) async {
    await tester.pumpWidget(buildTestWidget(title: 'Test Site'));
    expect(find.text('Location info'), findsNothing);
  });

  testWidgets('displays leading widget when provided', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      title: 'Test Site',
      leading: const Icon(Icons.location_on, key: Key('leading-icon')),
    ));
    expect(find.byKey(const Key('leading-icon')), findsOneWidget);
  });

  testWidgets('shows chevron_right icon for details navigation', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      title: 'Test Site',
      onDetailsTap: () {},
    ));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('calls onTap when card is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildTestWidget(
      title: 'Test Site',
      onTap: () => tapped = true,
    ));
    await tester.tap(find.byType(MapInfoCard));
    expect(tapped, isTrue);
  });

  testWidgets('calls onDetailsTap when chevron is tapped', (tester) async {
    var detailsTapped = false;
    await tester.pumpWidget(buildTestWidget(
      title: 'Test Site',
      onDetailsTap: () => detailsTapped = true,
    ));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(detailsTapped, isTrue);
  });

  testWidgets('has correct styling', (tester) async {
    await tester.pumpWidget(buildTestWidget(title: 'Test Site'));

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.elevation, 4);
    expect(card.shape, isA<RoundedRectangleBorder>());
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/map_list_layout/map_info_card_test.dart`
Expected: FAIL - file not found

**Step 3: Write minimal implementation**

```dart
// lib/shared/widgets/map_list_layout/map_info_card.dart
import 'package:flutter/material.dart';

/// Info card overlay for displaying selected item details on a map.
///
/// Positioned at the bottom of the map pane, shows a summary of the selected
/// item with a tap action to navigate to details.
class MapInfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onDetailsTap;

  const MapInfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap ?? onDetailsTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              if (leading != null) ...[
                SizedBox(width: 48, height: 48, child: leading),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onDetailsTap != null)
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onDetailsTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/map_list_layout/map_info_card_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/shared/widgets/map_list_layout/map_info_card.dart test/shared/widgets/map_list_layout/map_info_card_test.dart
git commit -m "feat: add MapInfoCard widget for map selection overlay"
```

---

## Task 3: Create CollapsibleListPane Widget

**Files:**
- Create: `lib/shared/widgets/map_list_layout/collapsible_list_pane.dart`
- Test: `test/shared/widgets/map_list_layout/collapsible_list_pane_test.dart`

**Step 1: Write the failing test**

```dart
// test/shared/widgets/map_list_layout/collapsible_list_pane_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/map_list_layout/collapsible_list_pane.dart';

void main() {
  Widget buildTestWidget({
    required bool isCollapsed,
    required VoidCallback onToggle,
    required Widget child,
    double width = 440,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            CollapsibleListPane(
              isCollapsed: isCollapsed,
              onToggle: onToggle,
              width: width,
              child: child,
            ),
            const Expanded(child: Placeholder()),
          ],
        ),
      ),
    );
  }

  testWidgets('shows child when not collapsed', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      isCollapsed: false,
      onToggle: () {},
      child: const Text('List Content'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('List Content'), findsOneWidget);
  });

  testWidgets('hides child when collapsed', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      isCollapsed: true,
      onToggle: () {},
      child: const Text('List Content'),
    ));
    await tester.pumpAndSettle();
    // When collapsed, width should animate to 0
    final animatedContainer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animatedContainer.constraints?.maxWidth, 0);
  });

  testWidgets('shows collapse button when expanded', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      isCollapsed: false,
      onToggle: () {},
      child: const Text('List Content'),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });

  testWidgets('calls onToggle when button pressed', (tester) async {
    var toggled = false;
    await tester.pumpWidget(buildTestWidget(
      isCollapsed: false,
      onToggle: () => toggled = true,
      child: const Text('List Content'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(toggled, isTrue);
  });

  testWidgets('uses specified width when expanded', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      isCollapsed: false,
      onToggle: () {},
      width: 500,
      child: const Text('List Content'),
    ));
    await tester.pumpAndSettle();
    final animatedContainer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animatedContainer.constraints?.maxWidth, 500);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/map_list_layout/collapsible_list_pane_test.dart`
Expected: FAIL - file not found

**Step 3: Write minimal implementation**

```dart
// lib/shared/widgets/map_list_layout/collapsible_list_pane.dart
import 'package:flutter/material.dart';

/// An animated collapsible container for the list pane in map-list layouts.
///
/// Animates between full width and collapsed (zero width) states.
/// Shows a toggle button to collapse/expand.
class CollapsibleListPane extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;
  final double width;
  final Widget child;

  const CollapsibleListPane({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
    required this.child,
    this.width = 440,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(
        maxWidth: isCollapsed ? 0 : width,
        minWidth: isCollapsed ? 0 : width,
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: width,
          minWidth: width,
          child: Stack(
            children: [
              child,
              // Collapse toggle button
              Positioned(
                right: 0,
                top: 8,
                child: Material(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                  elevation: 2,
                  child: InkWell(
                    onTap: onToggle,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/map_list_layout/collapsible_list_pane_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/shared/widgets/map_list_layout/collapsible_list_pane.dart test/shared/widgets/map_list_layout/collapsible_list_pane_test.dart
git commit -m "feat: add CollapsibleListPane widget for animated collapse"
```

---

## Task 4: Create MapListScaffold Widget

**Files:**
- Create: `lib/shared/widgets/map_list_layout/map_list_scaffold.dart`
- Test: `test/shared/widgets/map_list_layout/map_list_scaffold_test.dart`

**Step 1: Write the failing test**

```dart
// test/shared/widgets/map_list_layout/map_list_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

void main() {
  Widget buildTestWidget({
    required double width,
    Widget? infoCard,
    Widget? floatingActionButton,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Scaffold(
            body: MapListScaffold(
              sectionKey: 'test',
              title: 'Test Map',
              listPane: const Text('List Content'),
              mapPane: Container(color: Colors.blue, child: const Text('Map')),
              infoCard: infoCard,
              floatingActionButton: floatingActionButton,
              actions: const [Icon(Icons.settings)],
              onBackPressed: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows split layout on desktop (>=1100px)', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    // Both list and map should be visible
    expect(find.text('List Content'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('shows only map on mobile (<1100px)', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 800));
    await tester.pumpAndSettle();

    // Only map should be visible
    expect(find.text('List Content'), findsNothing);
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('shows info card when provided', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      width: 1200,
      infoCard: const Card(child: Text('Info Card')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Info Card'), findsOneWidget);
  });

  testWidgets('shows FAB when provided', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      width: 1200,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shows app bar with title', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Test Map'), findsOneWidget);
  });

  testWidgets('shows app bar actions', (tester) async {
    await tester.pumpWidget(buildTestWidget(width: 1200));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/map_list_layout/map_list_scaffold_test.dart`
Expected: FAIL - file not found

**Step 3: Write minimal implementation**

```dart
// lib/shared/widgets/map_list_layout/map_list_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/collapsible_list_pane.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// A scaffold for map pages that shows list + map split on desktop.
///
/// On desktop (>=1100px): Shows collapsible list pane on left, map on right.
/// On mobile (<1100px): Shows only the map (existing behavior).
class MapListScaffold extends ConsumerWidget {
  final String sectionKey;
  final String title;
  final Widget listPane;
  final Widget mapPane;
  final Widget? infoCard;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final double listWidth;

  const MapListScaffold({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.listPane,
    required this.mapPane,
    this.infoCard,
    this.floatingActionButton,
    this.actions,
    this.onBackPressed,
    this.listWidth = 440,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
    final selectionState = ref.watch(mapListSelectionProvider(sectionKey));
    final colorScheme = Theme.of(context).colorScheme;

    if (!isDesktop) {
      // Mobile: Show only map with info card overlay
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: onBackPressed != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBackPressed,
                )
              : null,
          actions: actions,
        ),
        body: Stack(
          children: [
            mapPane,
            if (infoCard != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 80,
                child: infoCard!,
              ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    // Desktop: Show list + map split
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed,
              )
            : null,
        actions: [
          // Expand button when collapsed
          if (selectionState.isCollapsed)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Show List',
              onPressed: () => ref
                  .read(mapListSelectionProvider(sectionKey).notifier)
                  .toggleCollapse(),
            ),
          ...?actions,
        ],
      ),
      body: Row(
        children: [
          // Collapsible list pane
          CollapsibleListPane(
            isCollapsed: selectionState.isCollapsed,
            onToggle: () => ref
                .read(mapListSelectionProvider(sectionKey).notifier)
                .toggleCollapse(),
            width: listWidth,
            child: listPane,
          ),
          // Vertical divider
          if (!selectionState.isCollapsed)
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
          // Map pane
          Expanded(
            child: Stack(
              children: [
                mapPane,
                // Info card at bottom center
                if (infoCard != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: infoCard!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/map_list_layout/map_list_scaffold_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/shared/widgets/map_list_layout/map_list_scaffold.dart test/shared/widgets/map_list_layout/map_list_scaffold_test.dart
git commit -m "feat: add MapListScaffold for desktop split-pane map view"
```

---

## Task 5: Add onItemTap callback to SiteListContent

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart`

**Step 1: Review current implementation**

Current `SiteListContent` already has `onItemSelected` and `selectedId` props. We need to add a new `onItemTapForMap` callback that pans the map without navigating, and make the list work in "map mode" where tapping pans instead of navigates.

**Step 2: Modify SiteListContent**

Add new props and modify the tap handler:

```dart
// In site_list_content.dart, add to the class parameters (around line 19):

  /// Called when an item is tapped in map mode (to pan map, not navigate).
  final void Function(DiveSite site)? onItemTapForMap;

  /// Whether the list is in map mode (tap to pan, not navigate).
  final bool isMapMode;
```

**Step 3: Update constructor (around line 24):**

```dart
  const SiteListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
    this.onItemTapForMap,
    this.isMapMode = false,
  });
```

**Step 4: Update _handleItemTap method (around line 103):**

```dart
  void _handleItemTap(DiveSite site) {
    if (_isSelectionMode) {
      _toggleSelection(site.id);
      return;
    }

    // Map mode: pan to location without navigation
    if (widget.isMapMode && widget.onItemTapForMap != null) {
      _selectionFromList = true;
      widget.onItemTapForMap!(site);
      // Also update selection for visual feedback
      if (widget.onItemSelected != null) {
        widget.onItemSelected!(site.id);
      }
      return;
    }

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(site.id);
    } else {
      context.push('/sites/${site.id}');
    }
  }
```

**Step 5: Run existing tests**

Run: `flutter test test/features/dive_sites/`
Expected: PASS (existing tests should still pass)

**Step 6: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_list_content.dart
git commit -m "feat: add map mode tap handling to SiteListContent"
```

---

## Task 6: Update SiteMapPage to use MapListScaffold

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart`

**Step 1: Import new widgets**

```dart
// Add imports at top of file
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
```

**Step 2: Update build method to use MapListScaffold**

Replace the current `build` method with one that uses `MapListScaffold` on desktop:

```dart
  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);
    final selectionState = ref.watch(mapListSelectionProvider('sites'));

    // Find selected site from selection state
    DiveSite? selectedSite;
    if (selectionState.selectedId != null) {
      selectedSite = sitesAsync.value
          ?.where((s) => s.site.id == selectionState.selectedId)
          .firstOrNull
          ?.site;
    }

    return MapListScaffold(
      sectionKey: 'sites',
      title: 'Dive Sites',
      onBackPressed: () => context.go('/sites'),
      listPane: SiteListContent(
        showAppBar: false,
        selectedId: selectionState.selectedId,
        isMapMode: true,
        onItemSelected: (id) {
          if (id != null) {
            ref.read(mapListSelectionProvider('sites').notifier).select(id);
          } else {
            ref.read(mapListSelectionProvider('sites').notifier).deselect();
          }
        },
        onItemTapForMap: (site) {
          if (site.hasCoordinates) {
            _animateToLocation(site.location!.latitude, site.location!.longitude);
          }
        },
      ),
      mapPane: sitesAsync.when(
        data: (sitesWithCounts) => _buildMap(context, sitesWithCounts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading sites: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(sitesWithCountsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      infoCard: selectedSite != null
          ? _buildMapInfoCard(context, selectedSite)
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sites/new'),
        icon: const Icon(Icons.add_location),
        label: const Text('Add Site'),
      ),
      actions: [
        const HeatMapToggleButton(),
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'List View',
          onPressed: () => context.go('/sites'),
        ),
        IconButton(
          icon: const Icon(Icons.my_location),
          tooltip: 'Fit All Sites',
          onPressed: () => _fitAllSites(
            sitesAsync.value?.map((s) => s.site).toList() ?? [],
          ),
        ),
      ],
    );
  }
```

**Step 3: Add _buildMapInfoCard method**

```dart
  Widget _buildMapInfoCard(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final sitesWithCounts = ref.read(sitesWithCountsProvider).value ?? [];
    final diveCount = sitesWithCounts
        .where((s) => s.site.id == site.id)
        .firstOrNull
        ?.diveCount ?? 0;

    String subtitle = site.locationString;
    if (diveCount > 0) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += '$diveCount ${diveCount == 1 ? 'dive' : 'dives'}';
    }
    if (site.rating != null) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += '\u2605 ${site.rating!.toStringAsFixed(1)}';
    }

    return MapInfoCard(
      title: site.name,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.location_on, color: colorScheme.primary),
      ),
      onDetailsTap: () => context.push('/sites/${site.id}'),
    );
  }
```

**Step 4: Add _animateToLocation method**

```dart
  void _animateToLocation(double lat, double lng) {
    _mapController.move(
      LatLng(lat, lng),
      _mapController.camera.zoom.clamp(10.0, 14.0),
    );
  }
```

**Step 5: Update _onMarkerTapped to use provider**

```dart
  void _onMarkerTapped(DiveSite site) {
    final currentId = ref.read(mapListSelectionProvider('sites')).selectedId;

    if (currentId == site.id) {
      ref.read(mapListSelectionProvider('sites').notifier).deselect();
    } else {
      ref.read(mapListSelectionProvider('sites').notifier).select(site.id);
      _mapController.move(
        LatLng(site.location!.latitude, site.location!.longitude),
        _mapController.camera.zoom,
      );
    }
  }
```

**Step 6: Update _buildMap to use provider for selection**

Update marker selection check:
```dart
final selectionState = ref.watch(mapListSelectionProvider('sites'));
// ...
final isSelected = selectionState.selectedId == site.id;
```

**Step 7: Remove old _selectedSite state variable and _buildSiteInfoCard method**

They are replaced by the provider and MapInfoCard.

**Step 8: Run tests and app**

Run: `flutter test`
Run: `flutter run -d macos` to test visually

**Step 9: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_map_page.dart
git commit -m "feat: integrate MapListScaffold into SiteMapPage"
```

---

## Task 7: Update DiveCenterListContent for map mode

**Files:**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`

Follow the same pattern as Task 5:
- Add `onItemTapForMap` callback
- Add `isMapMode` boolean
- Update tap handler to call `onItemTapForMap` in map mode

**Step 1: Add new parameters**

```dart
  final void Function(DiveCenter center)? onItemTapForMap;
  final bool isMapMode;
```

**Step 2: Update constructor**

```dart
  const DiveCenterListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
    this.onItemTapForMap,
    this.isMapMode = false,
  });
```

**Step 3: Update tap handler**

```dart
  void _handleItemTap(DiveCenter center) {
    if (_isSelectionMode) {
      _toggleSelection(center.id);
      return;
    }

    if (widget.isMapMode && widget.onItemTapForMap != null) {
      _selectionFromList = true;
      widget.onItemTapForMap!(center);
      if (widget.onItemSelected != null) {
        widget.onItemSelected!(center.id);
      }
      return;
    }

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(center.id);
    } else {
      context.push('/dive-centers/${center.id}');
    }
  }
```

**Step 4: Commit**

```bash
git add lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart
git commit -m "feat: add map mode tap handling to DiveCenterListContent"
```

---

## Task 8: Update DiveCenterMapPage to use MapListScaffold

**Files:**
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart`

Follow the same pattern as Task 6:

**Step 1: Add imports**

```dart
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
```

**Step 2: Update build method**

Use `MapListScaffold` with `DiveCenterListContent` as `listPane`.

**Step 3: Add _buildMapInfoCard method**

Create info card for dive centers showing name, location, rating.

**Step 4: Update marker selection to use provider**

**Step 5: Commit**

```bash
git add lib/features/dive_centers/presentation/pages/dive_center_map_page.dart
git commit -m "feat: integrate MapListScaffold into DiveCenterMapPage"
```

---

## Task 9: Update DiveListContent for map mode

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`

Same pattern as Tasks 5 and 7.

**Commit:**
```bash
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart
git commit -m "feat: add map mode tap handling to DiveListContent"
```

---

## Task 10: Update DiveActivityMapPage to use MapListScaffold

**Files:**
- Modify: `lib/features/maps/presentation/pages/dive_activity_map_page.dart`

Same pattern as Tasks 6 and 8.

**Commit:**
```bash
git add lib/features/maps/presentation/pages/dive_activity_map_page.dart
git commit -m "feat: integrate MapListScaffold into DiveActivityMapPage"
```

---

## Task 11: Format code and run full test suite

**Step 1: Format all code**

Run: `dart format lib/ test/`

**Step 2: Run analyzer**

Run: `flutter analyze`
Fix any issues.

**Step 3: Run all tests**

Run: `flutter test`
Ensure all tests pass.

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "chore: format code and fix analyzer issues"
```

---

## Task 12: Manual testing and final commit

**Step 1: Test on macOS**

Run: `flutter run -d macos`

Test:
- [ ] Sites map shows split pane on wide window
- [ ] Collapse toggle works
- [ ] Selecting list item pans map
- [ ] Selecting marker highlights list item
- [ ] Info card appears on selection
- [ ] Details button navigates to detail page
- [ ] Mobile/narrow window shows map only (existing behavior)

**Step 2: Test Dive Centers map**

Same tests as above.

**Step 3: Test Dive Activity map**

Same tests as above.

**Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create selection provider | 1 new + 1 test |
| 2 | Create MapInfoCard | 1 new + 1 test |
| 3 | Create CollapsibleListPane | 1 new + 1 test |
| 4 | Create MapListScaffold | 1 new + 1 test |
| 5 | Update SiteListContent | 1 modify |
| 6 | Update SiteMapPage | 1 modify |
| 7 | Update DiveCenterListContent | 1 modify |
| 8 | Update DiveCenterMapPage | 1 modify |
| 9 | Update DiveListContent | 1 modify |
| 10 | Update DiveActivityMapPage | 1 modify |
| 11 | Format and test | - |
| 12 | Manual testing | - |

**Total: 4 new files, 6 modified files, 4 test files**
