# Bulk Media Selection & Unlink Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add drag-to-range-select for linking photos to dives, and multi-select mode with bulk unlink for the dive media section.

**Architecture:** A shared `DragSelectGridView` widget encapsulates all drag-selection gesture logic (long-press anchor, drag-to-range, auto-scroll). Both the PhotoPickerPage (linking) and DiveMediaSection (unlinking) consume this widget. Batch delete uses a single Drift transaction in the repository layer.

**Tech Stack:** Flutter, Riverpod, Drift ORM, HapticFeedback

---

### Task 1: Localization Strings

**Files:**

- Modify: `lib/l10n/arb/app_en.arb`

**Step 1: Add new l10n strings to the English ARB file**

Add these entries to `lib/l10n/arb/app_en.arb`, alphabetically within the existing `media_` section. Insert after the existing `media_diveMediaSection_` entries (around line 4490) and `media_photoPicker_` entries (around line 4517):

```json
  "media_diveMediaSection_cancelSelectionButton": "Cancel",
  "media_diveMediaSection_selectAllButton": "Select All",
  "media_diveMediaSection_selectedCount": "{count} selected",
  "@media_diveMediaSection_selectedCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "media_diveMediaSection_unlinkSelectedButton": "Unlink {count}",
  "@media_diveMediaSection_unlinkSelectedButton": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "media_diveMediaSection_unlinkSelectedContent": "This will remove {count} media items from this dive. The original files won't be deleted.",
  "@media_diveMediaSection_unlinkSelectedContent": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "media_diveMediaSection_unlinkSelectedSuccess": "Unlinked {count} items",
  "@media_diveMediaSection_unlinkSelectedSuccess": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "media_diveMediaSection_unlinkSelectedTitle": "Unlink {count} items?",
  "@media_diveMediaSection_unlinkSelectedTitle": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "media_photoPicker_clearSelectionButton": "Clear",
  "media_photoPicker_selectAllButton": "Select All",
  "media_photoPicker_selectedCount": "{count} selected",
  "@media_photoPicker_selectedCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
```text
Also update the existing thumbnail label to mention drag:

```json
  "media_diveMediaSection_thumbnailLabel": "View photo. Long press to select",
```text
**Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Code generation completes successfully, new l10n getters appear in generated files.

**Step 3: Verify build**

Run: `flutter analyze`
Expected: No new analysis errors.

**Step 4: Commit**

```

git add lib/l10n/
git commit -m "feat: add l10n strings for bulk media selection"

```text
---

### Task 2: Batch Delete in MediaRepository

**Files:**

- Modify: `lib/features/media/data/repositories/media_repository.dart:170-181`
- Test: `test/features/media/data/repositories/media_repository_test.dart`

**Step 1: Write the failing test**

Add to the end of `test/features/media/data/repositories/media_repository_test.dart`, inside the existing `main()` block:

```dart
  group('deleteMultipleMedia', () {
    test('deletes multiple media items in a single transaction', () async {
      final dive = await createTestDiveInDb();

      final item1 = await repository.createMedia(
        createTestMediaItem(diveId: dive.id, filePath: '/photo1.jpg'),
      );
      final item2 = await repository.createMedia(
        createTestMediaItem(diveId: dive.id, filePath: '/photo2.jpg'),
      );
      final item3 = await repository.createMedia(
        createTestMediaItem(diveId: dive.id, filePath: '/photo3.jpg'),
      );

      await repository.deleteMultipleMedia([item1.id, item2.id]);

      final remaining = await repository.getMediaForDive(dive.id);
      expect(remaining, hasLength(1));
      expect(remaining.first.id, item3.id);
    });

    test('handles empty list without error', () async {
      await repository.deleteMultipleMedia([]);
      // Should not throw
    });

    test('handles non-existent IDs without error', () async {
      await repository.deleteMultipleMedia(['non-existent-id']);
      // Should not throw
    });
  });
```text
**Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart --name "deleteMultipleMedia"`
Expected: FAIL with "NoSuchMethodError" or "not defined"

**Step 3: Write minimal implementation**

Add to `lib/features/media/data/repositories/media_repository.dart`, after the existing `deleteMedia` method (after line 181):

```dart
  /// Delete multiple media items in a single transaction.
  /// Logs each deletion for sync tracking.
  Future<void> deleteMultipleMedia(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      _log.info('Deleting ${ids.length} media items');
      await _db.transaction(() async {
        for (final id in ids) {
          await (_db.delete(_db.media)..where((t) => t.id.equals(id))).go();
          await _syncRepository.logDeletion(
            entityType: 'media',
            recordId: id,
          );
        }
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted ${ids.length} media items');
    } catch (e, stackTrace) {
      _log.error('Failed to delete multiple media', e, stackTrace);
      rethrow;
    }
  }
```text
**Step 4: Run test to verify it passes**

Run: `flutter test test/features/media/data/repositories/media_repository_test.dart --name "deleteMultipleMedia"`
Expected: All 3 tests PASS.

**Step 5: Commit**

```

git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/repositories/media_repository_test.dart
git commit -m "feat: add deleteMultipleMedia to MediaRepository"

```text
---

### Task 3: Batch Delete in MediaListNotifier

**Files:**

- Modify: `lib/features/media/presentation/providers/media_providers.dart:117-120`

**Step 1: Add deleteMultipleMedia to MediaListNotifier**

Add after the existing `deleteMedia` method (after line 120) in `lib/features/media/presentation/providers/media_providers.dart`:

```dart
  /// Delete multiple media items at once
  Future<void> deleteMultipleMedia(List<String> ids) async {
    await _repository.deleteMultipleMedia(ids);
    await refresh();
  }
```text
**Step 2: Verify build**

Run: `flutter analyze`
Expected: No new analysis errors.

**Step 3: Commit**

```

git add lib/features/media/presentation/providers/media_providers.dart
git commit -m "feat: add deleteMultipleMedia to MediaListNotifier"

```dart
---

### Task 4: DragSelectGridView Widget

This is the core shared widget. It's a pure Flutter widget with no Riverpod dependency — it communicates via callbacks.

**Files:**

- Create: `lib/shared/widgets/drag_select_grid_view.dart`
- Create: `test/shared/widgets/drag_select_grid_view_test.dart`

**Step 1: Write the failing tests**

Create `test/shared/widgets/drag_select_grid_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

void main() {
  Widget buildTestGrid({
    int itemCount = 12,
    Set<int> initialSelection = const {},
    ValueChanged<Set<int>>? onSelectionChanged,
    ValueChanged<bool>? onSelectionModeChanged,
    bool startInSelectionMode = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DragSelectGridView<int>(
          items: List.generate(itemCount, (i) => i),
          initialSelection: initialSelection,
          startInSelectionMode: startInSelectionMode,
          onSelectionChanged: onSelectionChanged ?? (_) {},
          onSelectionModeChanged: onSelectionModeChanged ?? (_) {},
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, item, isSelected) {
            return Container(
              key: ValueKey('item_$item'),
              color: isSelected ? Colors.blue : Colors.grey,
              child: Center(child: Text('$item')),
            );
          },
        ),
      ),
    );
  }

  group('DragSelectGridView', () {
    testWidgets('renders all items', (tester) async {
      await tester.pumpWidget(buildTestGrid(itemCount: 8));
      for (var i = 0; i < 8; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('shows initial selection', (tester) async {
      await tester.pumpWidget(buildTestGrid(
        itemCount: 4,
        initialSelection: {0, 2},
        startInSelectionMode: true,
      ));
      // Items 0 and 2 should be blue (selected), 1 and 3 grey
      final item0 = tester.widget<Container>(
        find.byKey(const ValueKey('item_0')),
      );
      expect(item0.color, Colors.blue);
      final item1 = tester.widget<Container>(
        find.byKey(const ValueKey('item_1')),
      );
      expect(item1.color, Colors.grey);
    });

    testWidgets('long press enters selection mode', (tester) async {
      bool selectionModeActive = false;
      await tester.pumpWidget(buildTestGrid(
        onSelectionModeChanged: (active) => selectionModeActive = active,
      ));

      await tester.longPress(find.text('0'));
      await tester.pumpAndSettle();
      expect(selectionModeActive, isTrue);
    });

    testWidgets('long press selects the pressed item', (tester) async {
      Set<int> selection = {};
      await tester.pumpWidget(buildTestGrid(
        onSelectionChanged: (s) => selection = s,
      ));

      await tester.longPress(find.text('3'));
      await tester.pumpAndSettle();
      expect(selection, contains(3));
    });

    testWidgets('tap toggles selection when in selection mode', (tester) async {
      Set<int> selection = {};
      await tester.pumpWidget(buildTestGrid(
        initialSelection: {0},
        startInSelectionMode: true,
        onSelectionChanged: (s) => selection = s,
      ));

      // Tap item 2 to select it
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(selection, contains(2));

      // Tap item 0 to deselect it
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(selection.contains(0), isFalse);
    });

    testWidgets('tap passes through when not in selection mode', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DragSelectGridView<int>(
            items: List.generate(4, (i) => i),
            initialSelection: const {},
            onSelectionChanged: (_) {},
            onSelectionModeChanged: (_) {},
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
            onItemTap: (index) => tapped = true,
            itemBuilder: (context, item, isSelected) {
              return Container(
                key: ValueKey('item_$item'),
                color: Colors.grey,
                child: Center(child: Text('$item')),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('exits selection mode when selection becomes empty', (tester) async {
      bool selectionModeActive = true;
      await tester.pumpWidget(buildTestGrid(
        initialSelection: {0},
        startInSelectionMode: true,
        onSelectionModeChanged: (active) => selectionModeActive = active,
        onSelectionChanged: (_) {},
      ));

      // Deselect the only selected item
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(selectionModeActive, isFalse);
    });
  });
}
```text
**Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/widgets/drag_select_grid_view_test.dart`
Expected: FAIL because the widget doesn't exist yet.

**Step 3: Write the DragSelectGridView widget**

Create `lib/shared/widgets/drag_select_grid_view.dart`:

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A grid view that supports long-press-to-start drag-to-range-select.
///
/// In normal mode, taps fire [onItemTap]. Long-pressing an item enters
/// selection mode and makes that item the drag anchor. Dragging from the
/// anchor selects all items between anchor and finger position.
///
/// In selection mode, taps toggle individual items. When selection becomes
/// empty, selection mode exits automatically.
class DragSelectGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, bool isSelected)
      itemBuilder;
  final SliverGridDelegate gridDelegate;
  final Set<int> initialSelection;
  final ValueChanged<Set<int>> onSelectionChanged;
  final ValueChanged<bool> onSelectionModeChanged;
  final ValueChanged<int>? onItemTap;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool startInSelectionMode;

  const DragSelectGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    this.initialSelection = const {},
    required this.onSelectionChanged,
    required this.onSelectionModeChanged,
    this.onItemTap,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.startInSelectionMode = false,
  });

  @override
  State<DragSelectGridView<T>> createState() => _DragSelectGridViewState<T>();
}

class _DragSelectGridViewState<T> extends State<DragSelectGridView<T>> {
  late Set<int> _selectedIndices;
  late bool _isSelectionMode;
  int? _dragAnchorIndex;
  Set<int> _previewDragIndices = {};
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  /// Edge zone in pixels where auto-scroll triggers during drag
  static const double _autoScrollEdgeZone = 50.0;

  /// Auto-scroll speed in pixels per tick
  static const double _autoScrollSpeed = 8.0;

  @override
  void initState() {
    super.initState();
    _selectedIndices = Set<int>.from(widget.initialSelection);
    _isSelectionMode = widget.startInSelectionMode;
  }

  @override
  void didUpdateWidget(covariant DragSelectGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelection != oldWidget.initialSelection) {
      _selectedIndices = Set<int>.from(widget.initialSelection);
    }
    if (widget.startInSelectionMode != oldWidget.startInSelectionMode) {
      _isSelectionMode = widget.startInSelectionMode;
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _enterSelectionMode(int anchorIndex) {
    setState(() {
      _isSelectionMode = true;
      _dragAnchorIndex = anchorIndex;
      _selectedIndices = {anchorIndex};
    });
    widget.onSelectionModeChanged(true);
    widget.onSelectionChanged(_selectedIndices);
    HapticFeedback.mediumImpact();
  }

  void _toggleSelection(int index) {
    setState(() {
      final newSelection = Set<int>.from(_selectedIndices);
      if (newSelection.contains(index)) {
        newSelection.remove(index);
      } else {
        newSelection.add(index);
      }
      _selectedIndices = newSelection;

      if (_selectedIndices.isEmpty) {
        _isSelectionMode = false;
        widget.onSelectionModeChanged(false);
      }
    });
    widget.onSelectionChanged(_selectedIndices);
  }

  /// Replaces the current selection with the given set.
  /// Called externally via [DragSelectGridViewController].
  void setSelection(Set<int> indices) {
    setState(() {
      _selectedIndices = Set<int>.from(indices);
      if (_selectedIndices.isEmpty && _isSelectionMode) {
        _isSelectionMode = false;
        widget.onSelectionModeChanged(false);
      } else if (_selectedIndices.isNotEmpty && !_isSelectionMode) {
        _isSelectionMode = true;
        widget.onSelectionModeChanged(true);
      }
    });
    widget.onSelectionChanged(_selectedIndices);
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices = {};
      _isSelectionMode = false;
    });
    widget.onSelectionModeChanged(false);
    widget.onSelectionChanged(_selectedIndices);
  }

  int? _indexAtPosition(Offset globalPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final result = BoxHitTestResult();
    renderBox.hitTest(result, position: localPosition);

    // Walk hit test entries to find items with ValueKey<int>
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderBox) {
        // Walk up the element tree from the render object
        // We can't directly get the key from render objects,
        // so we use a simpler approach: compute grid cell from position
      }
    }

    // Compute grid cell index from position using grid geometry
    return _computeIndexFromLocalPosition(localPosition);
  }

  int? _computeIndexFromLocalPosition(Offset localPosition) {
    final delegate = widget.gridDelegate;
    if (delegate is! SliverGridDelegateWithFixedCrossAxisCount) return null;

    final crossAxisCount = delegate.crossAxisCount;
    final spacing = delegate.crossAxisSpacing;
    final mainAxisSpacing = delegate.mainAxisSpacing;

    final padding = widget.padding;
    double padLeft = 0;
    double padTop = 0;
    if (padding is EdgeInsets) {
      padLeft = padding.left;
      padTop = padding.top;
    }

    // Account for scroll offset
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    final adjustedX = localPosition.dx - padLeft;
    final adjustedY = localPosition.dy + scrollOffset - padTop;

    if (adjustedX < 0 || adjustedY < 0) return null;

    // Calculate cell size
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final gridWidth = renderBox.size.width - padLeft * 2;
    final cellWidth = (gridWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final cellHeight = cellWidth; // Square cells (aspect ratio 1:1)

    final col = (adjustedX / (cellWidth + spacing)).floor();
    final row = (adjustedY / (cellHeight + mainAxisSpacing)).floor();

    if (col < 0 || col >= crossAxisCount) return null;

    final index = row * crossAxisCount + col;
    if (index < 0 || index >= widget.items.length) return null;

    return index;
  }

  void _onDragUpdate(Offset globalPosition) {
    if (_dragAnchorIndex == null) return;

    final currentIndex = _indexAtPosition(globalPosition);
    if (currentIndex == null) return;

    final rangeStart = min(_dragAnchorIndex!, currentIndex);
    final rangeEnd = max(_dragAnchorIndex!, currentIndex);
    final newDragIndices = Set<int>.from(
      List.generate(rangeEnd - rangeStart + 1, (i) => rangeStart + i),
    );

    if (newDragIndices != _previewDragIndices) {
      // Haptic feedback on new items entering selection
      if (newDragIndices.length != _previewDragIndices.length) {
        HapticFeedback.selectionClick();
      }

      setState(() {
        _previewDragIndices = newDragIndices;
        _selectedIndices = newDragIndices;
      });
      widget.onSelectionChanged(_selectedIndices);
    }

    // Auto-scroll when near edges
    _handleAutoScroll(globalPosition);
  }

  void _onDragEnd() {
    _dragAnchorIndex = null;
    _previewDragIndices = {};
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _handleAutoScroll(Offset globalPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !_scrollController.hasClients) return;

    final localY = renderBox.globalToLocal(globalPosition).dy;
    final height = renderBox.size.height;

    double scrollDelta = 0;
    if (localY < _autoScrollEdgeZone) {
      // Near top - scroll up
      final proximity = 1.0 - (localY / _autoScrollEdgeZone).clamp(0.0, 1.0);
      scrollDelta = -_autoScrollSpeed * proximity;
    } else if (localY > height - _autoScrollEdgeZone) {
      // Near bottom - scroll down
      final proximity =
          1.0 - ((height - localY) / _autoScrollEdgeZone).clamp(0.0, 1.0);
      scrollDelta = _autoScrollSpeed * proximity;
    }

    if (scrollDelta != 0) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) {
          if (!_scrollController.hasClients) return;
          final newOffset = (_scrollController.offset + scrollDelta).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(newOffset);
        },
      );
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) {
        if (_isSelectionMode) return;
        final index = _indexAtPosition(details.globalPosition);
        if (index != null) {
          _enterSelectionMode(index);
          _dragAnchorIndex = index;
        }
      },
      onLongPressMoveUpdate: (details) {
        _onDragUpdate(details.globalPosition);
      },
      onLongPressEnd: (_) {
        _onDragEnd();
      },
      child: GridView.builder(
        controller: widget.shrinkWrap ? null : _scrollController,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: widget.padding,
        gridDelegate: widget.gridDelegate,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedIndices.contains(index);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(index);
              } else {
                widget.onItemTap?.call(index);
              }
            },
            child: widget.itemBuilder(context, widget.items[index], isSelected),
          );
        },
      ),
    );
  }
}
```text
**Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/widgets/drag_select_grid_view_test.dart`
Expected: All tests PASS.

**Step 5: Run full analysis**

Run: `flutter analyze`
Expected: No analysis errors.

**Step 6: Commit**

```

git add lib/shared/widgets/drag_select_grid_view.dart test/shared/widgets/drag_select_grid_view_test.dart
git commit -m "feat: add DragSelectGridView shared widget"

```typescript
---

### Task 5: Integrate DragSelectGridView into PhotoPickerPage

**Files:**

- Modify: `lib/features/media/presentation/pages/photo_picker_page.dart`

**Step 1: Add import for the shared widget**

At the top of `photo_picker_page.dart`, add:

```dart
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';
```text
**Step 2: Add selection toolbar below date range header**

In `_buildBody`, replace the existing `Column` (lines 156-174) with a version that includes a selection toolbar:

```dart
    // Show grid
    return Column(
      children: [
        // Date range header
        _DateRangeHeader(startTime: widget.startTime, endTime: widget.endTime),
        // Selection toolbar (shown when items are selected)
        if (state.selectionCount > 0)
          _SelectionToolbar(
            selectedCount: state.selectionCount,
            totalCount: _assets!.length,
            onSelectAll: () {
              ref
                  .read(photoPickerNotifierProvider.notifier)
                  .selectAll(_assets!.map((a) => a.id).toList());
            },
            onClearSelection: () {
              ref.read(photoPickerNotifierProvider.notifier).clearSelection();
            },
          ),
        // Photo grid
        Expanded(
          child: DragSelectGridView<AssetInfo>(
            items: _assets!,
            startInSelectionMode: state.selectionCount > 0,
            initialSelection: _computeSelectedIndices(state.selectedIds),
            onSelectionChanged: (indices) {
              _syncSelectionToNotifier(indices);
            },
            onSelectionModeChanged: (_) {},
            onItemTap: (index) {
              ref
                  .read(photoPickerNotifierProvider.notifier)
                  .toggleSelection(_assets![index].id);
            },
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, asset, isSelected) {
              return _PhotoThumbnail(
                asset: asset,
                isSelected: isSelected,
                onTap: () {}, // Handled by DragSelectGridView
              );
            },
          ),
        ),
      ],
    );
```text
**Step 3: Add helper methods to _PhotoPickerPageState**

Add these methods to `_PhotoPickerPageState`:

```dart
  Set<int> _computeSelectedIndices(Set<String> selectedIds) {
    if (_assets == null) return {};
    final indices = <int>{};
    for (var i = 0; i < _assets!.length; i++) {
      if (selectedIds.contains(_assets![i].id)) {
        indices.add(i);
      }
    }
    return indices;
  }

  void _syncSelectionToNotifier(Set<int> indices) {
    if (_assets == null) return;
    final ids = indices
        .where((i) => i < _assets!.length)
        .map((i) => _assets![i].id)
        .toList();
    ref.read(photoPickerNotifierProvider.notifier).selectAll(ids);
  }
```text
**Step 4: Add the _SelectionToolbar widget**

Add this widget class in the same file, after `_DateRangeHeader`:

```dart
/// Toolbar showing selection count with Select All and Clear buttons.
class _SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  const _SelectionToolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            context.l10n.media_photoPicker_selectedCount(selectedCount),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (selectedCount < totalCount)
            TextButton(
              onPressed: onSelectAll,
              child: Text(context.l10n.media_photoPicker_selectAllButton),
            ),
          TextButton(
            onPressed: onClearSelection,
            child: Text(context.l10n.media_photoPicker_clearSelectionButton),
          ),
        ],
      ),
    );
  }
}
```text
**Step 5: Remove the old _PhotoGrid class**

Delete the `_PhotoGrid` class (lines 226-257 in the original) since `DragSelectGridView` replaces it. Keep `_PhotoThumbnail` as-is since it's still used by `DragSelectGridView`'s `itemBuilder`.

**Step 6: Verify build**

Run: `flutter analyze`
Expected: No analysis errors.

**Step 7: Format**

Run: `dart format lib/features/media/presentation/pages/photo_picker_page.dart`

**Step 8: Commit**

```

git add lib/features/media/presentation/pages/photo_picker_page.dart
git commit -m "feat: integrate DragSelectGridView into PhotoPickerPage"

```sql
---

### Task 6: DiveMediaSection Multi-Select Mode

This is the most complex task. Convert `DiveMediaSection` from `ConsumerWidget` to `ConsumerStatefulWidget` with local selection state, and replace `_MediaGrid` with `DragSelectGridView`.

**Files:**

- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart`

**Step 1: Convert DiveMediaSection to ConsumerStatefulWidget**

Replace the class definition (lines 13-82) with:

```dart
/// Section widget displaying media (photos/videos) for a dive.
/// Supports multi-select mode for bulk unlinking.
class DiveMediaSection extends ConsumerStatefulWidget {
  final String diveId;
  final VoidCallback? onAddPressed;

  const DiveMediaSection({super.key, required this.diveId, this.onAddPressed});

  @override
  ConsumerState<DiveMediaSection> createState() => _DiveMediaSectionState();
}

class _DiveMediaSectionState extends ConsumerState<DiveMediaSection> {
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices = {};
    });
  }

  void _selectAll(int totalCount) {
    setState(() {
      _selectedIndices = Set<int>.from(List.generate(totalCount, (i) => i));
    });
  }

  Future<void> _unlinkSelected(
    BuildContext context,
    List<MediaItem> media,
  ) async {
    final selectedIds =
        _selectedIndices.map((i) => media[i].id).toList();
    final count = selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.media_diveMediaSection_unlinkSelectedTitle(count)),
        content: Text(
          ctx.l10n.media_diveMediaSection_unlinkSelectedContent(count),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.media_diveMediaSection_cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              ctx.l10n.media_diveMediaSection_unlinkSelectedButton(count),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(mediaListNotifierProvider(widget.diveId).notifier)
            .deleteMultipleMedia(selectedIds);

        _exitSelectionMode();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.media_diveMediaSection_unlinkSelectedSuccess(count),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.media_diveMediaSection_unlinkError(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaForDiveProvider(widget.diveId));
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row (changes in selection mode)
            if (_isSelectionMode)
              _SelectionHeader(
                selectedCount: _selectedIndices.length,
                totalCount: mediaAsync.valueOrNull?.length ?? 0,
                onSelectAll: () =>
                    _selectAll(mediaAsync.valueOrNull?.length ?? 0),
                onCancel: _exitSelectionMode,
                onUnlinkSelected: () {
                  final media = mediaAsync.valueOrNull;
                  if (media != null) {
                    _unlinkSelected(context, media);
                  }
                },
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.media_diveMediaSection_title,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  if (widget.onAddPressed != null)
                    IconButton(
                      icon: Icon(
                        Icons.add_photo_alternate,
                        color: colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip:
                          context.l10n.media_diveMediaSection_addTooltip,
                      onPressed: widget.onAddPressed,
                    ),
                ],
              ),
            const SizedBox(height: 16),
            // Content
            mediaAsync.when(
              data: (media) {
                if (media.isEmpty) {
                  return const _EmptyMediaState();
                }
                return DragSelectGridView<MediaItem>(
                  items: media,
                  initialSelection: _selectedIndices,
                  startInSelectionMode: _isSelectionMode,
                  onSelectionChanged: (indices) {
                    setState(() => _selectedIndices = indices);
                  },
                  onSelectionModeChanged: (active) {
                    setState(() => _isSelectionMode = active);
                  },
                  onItemTap: (index) {
                    // Navigate to photo viewer
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => PhotoViewerPage(
                          diveId: widget.diveId,
                          initialMediaId: media[index].id,
                        ),
                      ),
                    );
                  },
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, item, isSelected) {
                    return _MediaThumbnailContent(
                      item: item,
                      settings: settings,
                      isSelected: isSelected,
                      isSelectionMode: _isSelectionMode,
                    );
                  },
                );
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, stack) => Text(
                context.l10n.media_diveMediaSection_errorLoading,
                style:
                    textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```text
**Step 2: Add the _SelectionHeader widget**

Replace the old `_MediaGrid` and `_MediaThumbnail` classes with:

```dart
/// Header shown in selection mode with count, Select All, Unlink, and Cancel.
class _SelectionHeader extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback onUnlinkSelected;

  const _SelectionHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onCancel,
    required this.onUnlinkSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.media_diveMediaSection_cancelSelectionButton,
          onPressed: onCancel,
        ),
        Text(
          context.l10n.media_diveMediaSection_selectedCount(selectedCount),
          style: textTheme.titleMedium,
        ),
        const Spacer(),
        if (selectedCount < totalCount)
          TextButton(
            onPressed: onSelectAll,
            child: Text(context.l10n.media_diveMediaSection_selectAllButton),
          ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.media_diveMediaSection_unlinkSelectedButton(
            selectedCount,
          ),
          onPressed: selectedCount > 0 ? onUnlinkSelected : null,
        ),
      ],
    );
  }
}
```dart
**Step 3: Replace _MediaThumbnail with _MediaThumbnailContent**

The old `_MediaThumbnail` was a `ConsumerWidget` that handled taps/long-presses and managed its own gestures. The new version is just the visual content — gestures are handled by `DragSelectGridView`:

```dart
/// Visual content for a media thumbnail (no gesture handling).
/// Used inside DragSelectGridView which handles all gestures.
class _MediaThumbnailContent extends ConsumerWidget {
  final MediaItem item;
  final AppSettings settings;
  final bool isSelected;
  final bool isSelectionMode;

  const _MediaThumbnailContent({
    required this.item,
    required this.settings,
    required this.isSelected,
    required this.isSelectionMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = UnitFormatter(settings);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail or placeholder
          if (item.isOrphaned)
            const _OrphanedPlaceholder()
          else if (item.platformAssetId != null)
            _buildAssetThumbnail(ref, colorScheme)
          else
            _buildPlaceholder(colorScheme),

          // Dimming overlay for unselected items in selection mode
          if (isSelectionMode && !isSelected)
            Container(color: Colors.black.withValues(alpha: 0.3)),

          // Selection overlay
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.primary, width: 3),
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),

          // Checkmark for selected items
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),

          // Video icon (top-right, shifted when checkmark present)
          if (item.isVideo && !isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.videocam,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),

          // Depth badge (bottom-left)
          if (item.enrichment?.depthMeters != null)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatter.formatDepth(
                    item.enrichment!.depthMeters,
                    decimals: 0,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssetThumbnail(WidgetRef ref, ColorScheme colorScheme) {
    final thumbnailAsync = ref.watch(
      assetThumbnailProvider(item.platformAssetId!),
    );

    return thumbnailAsync.when(
      data: (bytes) {
        if (bytes == null) {
          return _buildPlaceholder(colorScheme);
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 200,
          cacheHeight: 200,
          errorBuilder: (context, error, stack) =>
              _buildPlaceholder(colorScheme),
        );
      },
      loading: () => Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) => _buildPlaceholder(colorScheme),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.photo, color: colorScheme.onSurfaceVariant),
    );
  }
}
```text
**Step 4: Add the DragSelectGridView import**

At the top of `dive_media_section.dart`:

```dart
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';
```text
**Step 5: Remove the old _MediaGrid and _MediaThumbnail classes**

Delete the `_MediaGrid` class (lines 122-153 in original) and the `_MediaThumbnail` class (lines 156-339 in original). Keep `_EmptyMediaState` and `_OrphanedPlaceholder`.

**Step 6: Verify build**

Run: `flutter analyze`
Expected: No analysis errors.

**Step 7: Format**

Run: `dart format lib/features/media/presentation/widgets/dive_media_section.dart`

**Step 8: Commit**

```

git add lib/features/media/presentation/widgets/dive_media_section.dart
git commit -m "feat: add multi-select mode with bulk unlink to DiveMediaSection"

```sql
---

### Task 7: Manual Testing & Polish

**Files:** None (testing only)

**Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass.

**Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No analysis errors.

**Step 3: Format all changed files**

Run: `dart format lib/ test/`
Expected: No formatting changes needed (already formatted in prior steps).

**Step 4: Manual testing checklist**

Run: `flutter run -d macos`

Test the following scenarios:

**PhotoPickerPage (linking):**

- [ ] Open a dive detail, tap the + button on the media section
- [ ] Verify photos load in the picker
- [ ] Tap to toggle individual photos (existing behavior still works)
- [ ] Long-press a photo, verify selection mode activates with haptic feedback
- [ ] Drag from long-press across multiple photos, verify range selection
- [ ] Verify "X selected" toolbar appears with Select All and Clear buttons
- [ ] Tap Select All, verify all photos selected
- [ ] Tap Clear, verify selection cleared
- [ ] Tap Done to import selected photos

**DiveMediaSection (unlinking):**

- [ ] On a dive with linked photos, long-press a thumbnail
- [ ] Verify selection mode activates (header changes to show count, Select All, trash icon, X)
- [ ] Tap other thumbnails to toggle selection
- [ ] Long-press + drag across thumbnails for range selection
- [ ] Tap Select All, verify all media selected
- [ ] Tap trash icon, verify confirmation dialog with correct count
- [ ] Confirm unlink, verify items removed and success snackbar shown
- [ ] Verify Cancel (X) exits selection mode without deleting
- [ ] Verify tapping a photo in normal mode still opens the photo viewer

**Step 5: Commit any polish fixes**

If any fixes were needed:

```bash

git add -A
git commit -m "fix: polish bulk media selection interactions"

```

---

## Summary of All Tasks

| Task | Description | Files |
|------|-------------|-------|
| 1 | Localization strings | `app_en.arb` |
| 2 | Batch delete in MediaRepository | `media_repository.dart`, test |
| 3 | Batch delete in MediaListNotifier | `media_providers.dart` |
| 4 | DragSelectGridView widget | New shared widget, test |
| 5 | PhotoPickerPage integration | `photo_picker_page.dart` |
| 6 | DiveMediaSection multi-select | `dive_media_section.dart` |
| 7 | Manual testing & polish | Testing only |
