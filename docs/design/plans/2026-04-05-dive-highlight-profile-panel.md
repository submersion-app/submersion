# Dive Highlight & Profile Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add highlight-without-navigate interaction to all dive list views and an optional profile chart preview panel that auto-updates on highlight change.

**Architecture:** Two new Riverpod `StateProvider`s (`highlightedDiveIdProvider`, `showProfilePanelProvider`) drive all behavior. A new `DiveProfilePanel` widget watches the highlighted ID and renders the existing `DiveProfileChart`. Single-tap highlights, double-tap navigates, long-press enters bulk selection (unchanged).

**Tech Stack:** Flutter, Riverpod, fl_chart (via existing DiveProfileChart)

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `lib/features/dive_log/presentation/providers/highlight_providers.dart` | `highlightedDiveIdProvider` and `showProfilePanelProvider` |
| `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart` | Profile panel widget with chart, header, empty state |
| `test/features/dive_log/presentation/providers/highlight_providers_test.dart` | Unit tests for highlight providers |
| `test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart` | Widget tests for profile panel |

### Modified files

| File | Change |
|------|--------|
| `lib/features/dive_log/presentation/widgets/dive_table_view.dart` | Add `onDiveDoubleTap` callback |
| `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart` | Add `onDoubleTap`, `isHighlighted` |
| `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart` | Add `onDoubleTap`, `isHighlighted` |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | Add `onDoubleTap`, `isHighlighted` to `DiveListTile` |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | Wire providers, toggle button, tap/double-tap handlers, insert panel |
| `test/features/dive_log/presentation/widgets/dive_table_view_test.dart` | Test double-tap callback |
| `test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart` | Test double-tap and highlight |
| `test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart` | Test double-tap and highlight |

---

### Task 1: Create Highlight Providers

**Files:**
- Create: `lib/features/dive_log/presentation/providers/highlight_providers.dart`
- Test: `test/features/dive_log/presentation/providers/highlight_providers_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/presentation/providers/highlight_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';

void main() {
  group('highlightedDiveIdProvider', () {
    test('defaults to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(highlightedDiveIdProvider), isNull);
    });

    test('can be set and read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(highlightedDiveIdProvider.notifier).state = 'dive-123';
      expect(container.read(highlightedDiveIdProvider), 'dive-123');
    });

    test('can be cleared back to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(highlightedDiveIdProvider.notifier).state = 'dive-123';
      container.read(highlightedDiveIdProvider.notifier).state = null;
      expect(container.read(highlightedDiveIdProvider), isNull);
    });
  });

  group('showProfilePanelProvider', () {
    test('defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(showProfilePanelProvider), isFalse);
    });

    test('can be toggled on', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(showProfilePanelProvider.notifier).state = true;
      expect(container.read(showProfilePanelProvider), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/highlight_providers_test.dart`
Expected: FAIL -- cannot resolve import `highlight_providers.dart`

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_log/presentation/providers/highlight_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently highlighted dive ID in the list view.
///
/// Set on single-tap, cleared when entering bulk selection mode.
/// Watched by [DiveProfilePanel] to auto-update the chart preview.
final highlightedDiveIdProvider = StateProvider<String?>((ref) => null);

/// Whether the profile chart preview panel is visible above the dive list.
final showProfilePanelProvider = StateProvider<bool>((ref) => false);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/highlight_providers_test.dart`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```
feat(highlight): add highlightedDiveIdProvider and showProfilePanelProvider
```

---

### Task 2: Add Double-Tap to DiveTableView

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_table_view.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_table_view_test.dart`

- [ ] **Step 1: Write the failing test**

Add to the end of `dive_table_view_test.dart`:

```dart
  testWidgets('fires onDiveDoubleTap on double-tap', (tester) async {
    String? doubleTappedId;
    await tester.pumpWidget(
      _buildTable(
        dives: [_makeDive(id: 'a', diveNumber: 1)],
        onDiveTap: (_) {},
        onDiveDoubleTap: (id) => doubleTappedId = id,
      ),
    );
    await tester.pump();

    // Double-tap on a row cell
    final cell = find.text('#1');
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(doubleTappedId, 'a');
  });
```

Also update the `_buildTable` helper to accept the new parameter:

```dart
Widget _buildTable({
  required List<Dive> dives,
  Map<String, Duration?>? surfaceIntervals,
  void Function(String)? onDiveTap,
  void Function(String)? onDiveDoubleTap,
  void Function(String)? onDiveLongPress,
  Set<String>? selectedIds,
  bool isSelectionMode = false,
  TableViewConfig? config,
}) {
  return testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      tableViewConfigProvider.overrideWith(
        (ref) => _TestTableConfigNotifier(config ?? _testConfig),
      ),
    ],
    child: DiveTableView(
      dives: dives,
      surfaceIntervals: surfaceIntervals ?? const {},
      onDiveTap: onDiveTap ?? (_) {},
      onDiveDoubleTap: onDiveDoubleTap,
      onDiveLongPress: onDiveLongPress,
      selectedIds: selectedIds ?? const {},
      isSelectionMode: isSelectionMode,
    ),
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_table_view_test.dart`
Expected: FAIL -- `onDiveDoubleTap` not a named parameter

- [ ] **Step 3: Add onDiveDoubleTap to DiveTableView**

In `lib/features/dive_log/presentation/widgets/dive_table_view.dart`, add the parameter to the widget class (after `onDiveLongPress`):

```dart
  final void Function(String diveId)? onDiveDoubleTap;
```

Add to the constructor (after `this.onDiveLongPress`):

```dart
    this.onDiveDoubleTap,
```

Then in both `GestureDetector` widgets (pinned body at ~line 348, scrollable body at ~line 415), add the `onDoubleTap` callback:

For the pinned body GestureDetector:
```dart
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onDiveTap(dive.id),
                      onDoubleTap: widget.onDiveDoubleTap != null
                          ? () => widget.onDiveDoubleTap!(dive.id)
                          : null,
                      onLongPress: widget.onDiveLongPress != null
                          ? () => widget.onDiveLongPress!(dive.id)
                          : null,
```

For the scrollable body GestureDetector:
```dart
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onDiveTap(dive.id),
                          onDoubleTap: widget.onDiveDoubleTap != null
                              ? () => widget.onDiveDoubleTap!(dive.id)
                              : null,
                          onLongPress: widget.onDiveLongPress != null
                              ? () => widget.onDiveLongPress!(dive.id)
                              : null,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_table_view_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```
feat(table): add onDiveDoubleTap callback to DiveTableView
```

---

### Task 3: Add Double-Tap and Highlight to CompactDiveListTile

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart`
- Test: `test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to the end of `compact_dive_list_tile_test.dart`:

```dart
    testWidgets('fires onDoubleTap on double-tap gesture', (tester) async {
      bool doubleTapped = false;
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Site',
            onTap: () {},
            onDoubleTap: () => doubleTapped = true,
          ),
        ),
      );

      final tile = find.text('Test Site');
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(doubleTapped, isTrue);
    });

    testWidgets('shows highlight styling when isHighlighted is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: CompactDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Site',
            isHighlighted: true,
            onTap: () {},
          ),
        ),
      );

      // The Card should have a highlight border decoration
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CompactDiveListTile),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration;
      expect(decoration, isNotNull);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart`
Expected: FAIL -- `onDoubleTap` / `isHighlighted` not named parameters

- [ ] **Step 3: Add onDoubleTap and isHighlighted to CompactDiveListTile**

In `compact_dive_list_tile.dart`, add two new parameters to the class fields (after `isSelected`):

```dart
  final bool isHighlighted;
  final VoidCallback? onDoubleTap;
```

Add to the constructor (after `this.isSelected = false`):

```dart
    this.isHighlighted = false,
    this.onDoubleTap,
```

Update the `cardColor` logic in `build()` to include highlight state. Replace:

```dart
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : attributeColor;
```

With:

```dart
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : isHighlighted
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : attributeColor;
```

Add `onDoubleTap` to the `InkWell` widget. Replace:

```dart
          child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
```

With:

```dart
          child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
```

Wrap the `Card` in a `Container` to add a left accent border when highlighted. Replace the `return Card(` section with:

```dart
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: isHighlighted
          ? BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colorScheme.primary,
                  width: 3,
                ),
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: cardColor,
        child: Semantics(
```

And update the closing brackets accordingly. The `Card`'s existing `margin` is moved to the outer `Container`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```
feat(compact-tile): add onDoubleTap and isHighlighted to CompactDiveListTile
```

---

### Task 4: Add Double-Tap and Highlight to DenseDiveListTile

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart`
- Test: `test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to the end of `dense_dive_list_tile_test.dart`:

```dart
    testWidgets('fires onDoubleTap on double-tap gesture', (tester) async {
      bool doubleTapped = false;
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Site',
            onTap: () {},
            onDoubleTap: () => doubleTapped = true,
          ),
        ),
      );

      final tile = find.text('Test Site');
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(doubleTapped, isTrue);
    });

    testWidgets('shows left accent border when isHighlighted is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          ],
          child: DenseDiveListTile(
            diveId: 'test-id',
            diveNumber: 42,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Test Site',
            isHighlighted: true,
            onTap: () {},
          ),
        ),
      );

      // Find the DecoratedBox and check for highlight border
      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(DenseDiveListTile),
          matching: find.byType(DecoratedBox),
        ),
      );
      // The first DecoratedBox should have a left border when highlighted
      final decoration = decoratedBoxes.first.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`
Expected: FAIL -- `onDoubleTap` / `isHighlighted` not named parameters

- [ ] **Step 3: Add onDoubleTap and isHighlighted to DenseDiveListTile**

In `dense_dive_list_tile.dart`, add two new parameters (after `isSelected`):

```dart
  final bool isHighlighted;
  final VoidCallback? onDoubleTap;
```

Add to the constructor (after `this.isSelected = false`):

```dart
    this.isHighlighted = false,
    this.onDoubleTap,
```

Update the `rowColor` logic in `build()`. Replace:

```dart
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : attributeColor;
```

With:

```dart
    final rowColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : isHighlighted
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : attributeColor;
```

Update the `DecoratedBox` decoration to add a left accent border when highlighted. Replace:

```dart
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
```

With:

```dart
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            left: isHighlighted
                ? BorderSide(color: colorScheme.primary, width: 3)
                : BorderSide.none,
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
```

Add `onDoubleTap` to the `InkWell`. Replace:

```dart
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
```

With:

```dart
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```
feat(dense-tile): add onDoubleTap and isHighlighted to DenseDiveListTile
```

---

### Task 5: Add Double-Tap and Highlight to DiveListTile (Detailed View)

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (the `DiveListTile` class, ~line 363)

- [ ] **Step 1: Add parameters to DiveListTile**

In `dive_list_page.dart`, add two new fields to the `DiveListTile` class (after `onLongPress`):

```dart
  final VoidCallback? onDoubleTap;
  final bool isHighlighted;
```

Add to the constructor (after `this.onLongPress`):

```dart
    this.onDoubleTap,
    this.isHighlighted = false,
```

- [ ] **Step 2: Add highlight styling and onDoubleTap to the build method**

Find the `DiveListTile.build()` method. It has two layout paths (compact and expanded) each with an `InkWell`. In both `InkWell` widgets, add `onDoubleTap`:

```dart
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
```

For highlight styling, find where the card background color is determined. Add highlight support to the card color logic. The detailed tile uses a `Card` widget. Find the `cardColor` computation (similar to compact tile's `isSelected` check) and add the highlight state:

Where the tile computes its background/selection state, add after the `isSelected` color:
```dart
    : isHighlighted
        ? colorScheme.primaryContainer.withValues(alpha: 0.15)
```

Wrap the outer `Card` in a `Container` with left accent border when highlighted, same pattern as CompactDiveListTile in Task 3.

- [ ] **Step 3: Run existing tests to verify no regressions**

Run: `flutter test test/features/dive_log/presentation/pages/dive_list_page_test.dart`
Expected: PASS (existing tests should not break since new params have defaults)

- [ ] **Step 4: Commit**

```
feat(detailed-tile): add onDoubleTap and isHighlighted to DiveListTile
```

---

### Task 6: Create DiveProfilePanel Widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart`

- [ ] **Step 1: Write the failing test for empty state**

```dart
// test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_panel.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('DiveProfilePanel', () {
    testWidgets('shows empty state when no dive is highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            highlightedDiveIdProvider.overrideWith((ref) => null),
          ],
          child: const SizedBox(
            height: 250,
            child: DiveProfilePanel(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Select a dive to view its profile'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart`
Expected: FAIL -- cannot resolve import `dive_profile_panel.dart`

- [ ] **Step 3: Implement DiveProfilePanel**

```dart
// lib/features/dive_log/presentation/widgets/dive_profile_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Fixed-height panel that displays the dive profile chart for the currently
/// highlighted dive. Shows an empty state when no dive is selected.
class DiveProfilePanel extends ConsumerWidget {
  const DiveProfilePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightedId = ref.watch(highlightedDiveIdProvider);

    if (highlightedId == null) {
      return _buildEmptyState(context);
    }

    return _DiveProfilePanelContent(diveId: highlightedId);
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 32,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a dive to view its profile',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inner widget that loads and displays the profile for a specific dive.
///
/// Separated from [DiveProfilePanel] so that the providers are scoped to a
/// non-null dive ID, avoiding null checks throughout the build.
class _DiveProfilePanelContent extends ConsumerWidget {
  final String diveId;

  const _DiveProfilePanelContent({required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveAsync = ref.watch(diveProvider(diveId));
    final colorScheme = Theme.of(context).colorScheme;

    return diveAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading dive', style: TextStyle(color: colorScheme.error)),
      ),
      data: (dive) {
        if (dive == null || dive.profile.isEmpty) {
          return Center(
            child: Text(
              'No profile data for this dive',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        return _buildProfileContent(context, ref, dive);
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, Dive dive) {
    final analysis = ref.watch(profileAnalysisProvider(diveId)).valueOrNull;
    final gasSwitches = ref.watch(gasSwitchesProvider(diveId)).valueOrNull;
    final tankPressures = ref.watch(tankPressuresProvider(diveId)).valueOrNull;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;

    final siteName = dive.siteName ?? 'Unknown Site';
    final diveNumber = dive.diveNumber;
    final depthText = units.formatDepth(dive.maxDepth);
    final durationText = dive.effectiveRuntime != null
        ? '${dive.effectiveRuntime!.inMinutes} min'
        : '--';
    final dateText = units.formatDateTime(dive.dateTime, l10n: null);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar with dive info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                if (diveNumber != null)
                  Text(
                    '#$diveNumber',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (diveNumber != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    siteName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  depthText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  durationText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Profile chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
              child: DiveProfileChart(
                profile: dive.profile,
                diveDuration: dive.effectiveRuntime,
                maxDepth: dive.maxDepth,
                ceilingCurve: analysis?.ceilingCurve,
                ascentRates: analysis?.ascentRates,
                events: analysis?.events,
                ndlCurve: analysis?.ndlCurve,
                sacCurve: analysis?.smoothedSacCurve,
                ppO2Curve: analysis?.ppO2Curve,
                ppN2Curve: analysis?.ppN2Curve,
                ppHeCurve: analysis?.ppHeCurve,
                modCurve: analysis?.modCurve,
                densityCurve: analysis?.densityCurve,
                gfCurve: analysis?.gfCurve,
                surfaceGfCurve: analysis?.surfaceGfCurve,
                meanDepthCurve: analysis?.meanDepthCurve,
                ttsCurve: analysis?.ttsCurve,
                cnsCurve: analysis?.cnsCurve,
                otuCurve: analysis?.otuCurve,
                tanks: dive.tanks,
                tankPressures: tankPressures,
                gasSwitches: gasSwitches,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```
feat(profile-panel): create DiveProfilePanel widget with chart and empty state
```

---

### Task 7: Wire Highlight and Profile Panel into DiveListContent

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`

This task wires everything together: the providers, the tap/double-tap handlers, the toggle button, and the panel insertion.

- [ ] **Step 1: Add imports**

Add these imports to `dive_list_content.dart`:

```dart
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_panel.dart';
```

- [ ] **Step 2: Remove local _tableHighlightedId state**

In `_DiveListContentState`, remove the field:

```dart
  String? _tableHighlightedId; // Last-tapped dive in table mode
```

It is replaced by `highlightedDiveIdProvider`.

- [ ] **Step 3: Update _enterSelectionMode to clear highlight**

In `_enterSelectionMode`, add a line to clear the highlight provider:

```dart
  void _enterSelectionMode(String? initialId) {
    ref.read(highlightedDiveIdProvider.notifier).state = null;
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }
```

- [ ] **Step 4: Update _handleItemTap for card/list views**

Replace the navigation logic in `_handleItemTap` for non-selection, non-map cases. Change the section starting at the `if (widget.onItemSelected != null)` block (~line 802):

Replace:

```dart
    if (widget.onItemSelected != null) {
      // Master-detail mode: notify parent
      // Mark that selection came from list tap (don't scroll)
      _selectionFromList = true;
      widget.onItemSelected!(dive.id);
    } else {
      // Standalone mode: navigate
      context.go('/dives/${dive.id}');
    }
```

With:

```dart
    // Highlight the dive only -- do NOT open detail pane on single tap.
    // The detail pane is opened on double-tap via _handleItemDoubleTap.
    ref.read(highlightedDiveIdProvider.notifier).state = dive.id;
```

- [ ] **Step 5: Add _handleItemDoubleTap for card/list views**

Add a new method after `_handleItemTap`:

```dart
  void _handleItemDoubleTap(DiveSummary dive) {
    if (_isSelectionMode) return;

    if (widget.onItemSelected != null) {
      // Master-detail mode: notify parent to open detail pane
      _selectionFromList = true;
      widget.onItemSelected!(dive.id);
    } else {
      // Standalone mode: navigate to detail page
      context.go('/dives/${dive.id}');
    }
  }
```

- [ ] **Step 6: Update table view tap handler in _buildTableView**

In `_buildTableView`, find the `onDiveTap` callback inside `DiveTableView(...)` (~line 1254). Replace the entire handler and add `onDiveDoubleTap`:

Replace:

```dart
                onDiveTap: (id) {
                  if (_isSelectionMode) {
                    _toggleSelection(id);
                  } else {
                    setState(() => _tableHighlightedId = id);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiveDetailPage(diveId: id),
                      ),
                    );
                  }
                },
```

With:

```dart
                onDiveTap: (id) {
                  if (_isSelectionMode) {
                    _toggleSelection(id);
                  } else {
                    ref.read(highlightedDiveIdProvider.notifier).state = id;
                  }
                },
                onDiveDoubleTap: (id) {
                  if (_isSelectionMode) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiveDetailPage(diveId: id),
                    ),
                  );
                },
```

Update the `highlightedId` parameter:

Replace:

```dart
                highlightedId: _tableHighlightedId,
```

With:

```dart
                highlightedId: ref.watch(highlightedDiveIdProvider),
```

- [ ] **Step 7: Pass onDoubleTap and isHighlighted to card/list tile widgets**

In `_buildDiveList`, update the `return switch (viewMode)` block to pass the new callbacks and state to each tile.

For each tile type, add `onDoubleTap` and `isHighlighted`. For the highlight state, read the provider:

At the top of the `itemBuilder` (after `final isMasterSelected`), add:

```dart
                final isHighlighted = !_isSelectionMode &&
                    ref.watch(highlightedDiveIdProvider) == dive.id;
```

For `ListViewMode.detailed` (`DiveListTile`), add:

```dart
                    onDoubleTap: () => _handleItemDoubleTap(dive),
                    isHighlighted: isHighlighted,
```

For `ListViewMode.compact` (`CompactDiveListTile`), add:

```dart
                    onDoubleTap: () => _handleItemDoubleTap(dive),
                    isHighlighted: isHighlighted,
```

For `ListViewMode.dense || ListViewMode.table` (`DenseDiveListTile`), add:

```dart
                    onDoubleTap: () => _handleItemDoubleTap(dive),
                    isHighlighted: isHighlighted,
```

- [ ] **Step 8: Add profile panel toggle button to toolbars**

In `_buildAppBar`, add the toggle button to the `extraActions` area. In the `actions` list, add before the map button:

```dart
        IconButton(
          icon: Icon(
            Icons.show_chart,
            color: ref.watch(showProfilePanelProvider)
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          tooltip: 'Toggle profile panel',
          onPressed: () {
            ref.read(showProfilePanelProvider.notifier).state =
                !ref.read(showProfilePanelProvider);
          },
        ),
```

In `_buildCompactAppBar`, add the same toggle button to the `Row` children, before the map button:

```dart
          IconButton(
            icon: Icon(
              Icons.show_chart,
              size: 20,
              color: ref.watch(showProfilePanelProvider)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Toggle profile panel',
            onPressed: () {
              ref.read(showProfilePanelProvider.notifier).state =
                  !ref.read(showProfilePanelProvider);
            },
          ),
```

- [ ] **Step 9: Insert DiveProfilePanel into table mode layout**

In `_buildTableView`, wrap the existing content to include the panel. Find where it returns the `Column` with the filter bar and `Expanded(child: DiveTableView(...))`.

Replace the data callback:

```dart
      data: (dives) {
        if (dives.isEmpty) {
          return _buildEmptyState(context, filter.hasActiveFilters);
        }
        final showPanel = ref.watch(showProfilePanelProvider);
        return Column(
          children: [
            if (filter.hasActiveFilters) _buildActiveFiltersBar(context),
            if (showPanel)
              LayoutBuilder(
                builder: (context, constraints) {
                  final panelHeight = (constraints.maxHeight * 0.3)
                      .clamp(150.0, 250.0);
                  return SizedBox(
                    height: panelHeight,
                    child: const DiveProfilePanel(),
                  );
                },
              ),
            Expanded(
              child: DiveTableView(
```

(The rest of the DiveTableView construction stays the same.)

- [ ] **Step 10: Insert DiveProfilePanel into card/list mode layout**

In `_buildDiveList`, find the `return RefreshIndicator(` section and wrap the list content to include the panel.

Replace the `Column` inside `RefreshIndicator` > `child`:

```dart
      child: Column(
        children: [
          if (hasActiveFilters) _buildActiveFiltersBar(context),
          if (ref.watch(showProfilePanelProvider))
            LayoutBuilder(
              builder: (context, constraints) {
                final panelHeight = (constraints.maxHeight * 0.3)
                    .clamp(150.0, 250.0);
                return SizedBox(
                  height: panelHeight,
                  child: const DiveProfilePanel(),
                );
              },
            ),
          Expanded(
            child: ListView.builder(
```

- [ ] **Step 11: Run dart format**

Run: `dart format lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/features/dive_log/presentation/widgets/dive_profile_panel.dart lib/features/dive_log/presentation/providers/highlight_providers.dart`

- [ ] **Step 12: Run full test suite**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 13: Run analyzer**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 14: Commit**

```
feat(highlight): wire highlight providers, profile panel, and tap/double-tap into dive list
```

---

### Task 8: Manual Smoke Test & Polish

- [ ] **Step 1: Run the app and test on macOS**

Run: `flutter run -d macos`

Verify:
1. Open dive log in table view
2. Single-tap a dive -- row highlights, no navigation
3. Double-tap a dive -- navigates to dive detail
4. Toggle profile panel button in toolbar -- panel appears/disappears
5. With panel visible, tap different dives -- chart updates
6. Panel shows empty state when first toggled on with no selection
7. Switch to compact view -- same highlight/double-tap behavior
8. Switch to dense view -- same behavior
9. Switch to detailed view -- same behavior
10. Long press a dive -- enters selection mode, highlight clears
11. Exit selection mode -- previous highlight is gone (expected)

- [ ] **Step 2: Fix any visual or behavioral issues found during testing**

- [ ] **Step 3: Run full test suite one final time**

Run: `flutter test && flutter analyze`
Expected: PASS, no issues

- [ ] **Step 4: Final commit if any polish changes were made**

```
fix(highlight): polish from manual testing
```
