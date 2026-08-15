import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Signature for the item builder used by [DragSelectGridView].
///
/// [context] is the build context, [item] is the data item of type [T],
/// and [isSelected] indicates whether the item is currently selected.
typedef DragSelectItemBuilder<T> =
    Widget Function(BuildContext context, T item, bool isSelected);

/// A grid view that supports drag-to-range-select inside selection mode.
///
/// In normal mode, selection mode is entered only through the surface's own
/// Select control, never by a gesture on an item. No long-press recognizer is
/// registered at all, so a hold falls through to the tap recognizer -- which
/// has no upper duration bound -- and fires [onItemTap] on release, exactly as
/// a quick tap would.
///
/// In selection mode, taps toggle individual items, and long-pressing an item
/// anchors a drag; dragging from the anchor adds every item between anchor and
/// finger position to the existing selection. When selection becomes empty,
/// selection mode exits automatically.
///
/// This widget is a pure Flutter widget with no Riverpod dependency.
/// It communicates entirely via callbacks.
class DragSelectGridView<T> extends StatefulWidget {
  /// The list of data items to display in the grid.
  final List<T> items;

  /// Builder that creates a widget for each item.
  final DragSelectItemBuilder<T> itemBuilder;

  /// Delegate that controls the layout of the grid.
  final SliverGridDelegate gridDelegate;

  /// The initial set of selected indices.
  final Set<int> initialSelection;

  /// Called whenever the selection changes.
  final ValueChanged<Set<int>> onSelectionChanged;

  /// Called when selection mode is entered or exited.
  final ValueChanged<bool> onSelectionModeChanged;

  /// Called when an item is tapped while not in selection mode.
  final ValueChanged<int>? onItemTap;

  /// Padding around the grid.
  final EdgeInsetsGeometry? padding;

  /// Whether the grid should shrink-wrap its contents.
  final bool shrinkWrap;

  /// Custom scroll physics for the grid.
  final ScrollPhysics? physics;

  /// Whether to start in selection mode.
  final bool startInSelectionMode;

  /// Indices of items that cannot be selected (e.g., already-linked items).
  final Set<int> disabledIndices;

  /// Whether unchecking the last item leaves selection mode on its own.
  ///
  /// Set false when an outer selection controller owns the mode: it alone
  /// knows whether the mode was entered deliberately (Select button, which
  /// must survive at zero checked) or incidentally (which must evaporate),
  /// and the grid cannot tell those apart. The owner then drives the grid back
  /// out through [startInSelectionMode].
  final bool exitOnEmptySelection;

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
    this.disabledIndices = const {},
    this.exitOnEmptySelection = true,
  });

  @override
  State<DragSelectGridView<T>> createState() => _DragSelectGridViewState<T>();
}

class _DragSelectGridViewState<T> extends State<DragSelectGridView<T>> {
  late Set<int> _selectedIndices;
  late bool _isSelectionMode;
  int? _dragAnchorIndex;
  Set<int> _preDragSelection = {};
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  /// Keys for each grid item, used for hit-testing during drag.
  final Map<int, GlobalKey> _itemKeys = {};

  /// Edge zone in pixels where auto-scroll triggers during drag.
  static const double _autoScrollEdgeZone = 50.0;

  /// Auto-scroll speed in pixels per tick.
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
    if (!setEquals(widget.initialSelection, oldWidget.initialSelection)) {
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

  /// Anchor a range drag on [anchorIndex], keeping what is already checked.
  ///
  /// Only reachable in selection mode, so the drag extends a selection the
  /// user already opened rather than starting one. [_preDragSelection] is the
  /// set as it stood before the anchor was added, because [_onDragUpdate]
  /// re-unions it with the whole anchor-to-finger span on every move.
  void _beginRangeDrag(int anchorIndex) {
    if (widget.disabledIndices.contains(anchorIndex)) return;
    final priorSelection = Set<int>.from(_selectedIndices);
    setState(() {
      _dragAnchorIndex = anchorIndex;
      _preDragSelection = priorSelection;
      _selectedIndices = Set<int>.from(priorSelection)..add(anchorIndex);
    });
    widget.onSelectionChanged(_selectedIndices);
    HapticFeedback.mediumImpact();
  }

  void _toggleSelection(int index) {
    if (widget.disabledIndices.contains(index)) return;
    final newSelection = Set<int>.from(_selectedIndices);
    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }

    setState(() {
      _selectedIndices = newSelection;
      if (_selectedIndices.isEmpty && widget.exitOnEmptySelection) {
        _isSelectionMode = false;
        widget.onSelectionModeChanged(false);
      }
    });
    widget.onSelectionChanged(_selectedIndices);
  }

  /// Finds the item index at a global position by hit-testing item keys.
  int? _indexAtPosition(Offset globalPosition) {
    for (final entry in _itemKeys.entries) {
      final renderBox =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) continue;

      final localPosition = renderBox.globalToLocal(globalPosition);
      if (renderBox.paintBounds.contains(localPosition)) {
        return entry.key;
      }
    }
    return null;
  }

  void _onDragUpdate(Offset globalPosition) {
    if (_dragAnchorIndex == null) return;

    final currentIndex = _indexAtPosition(globalPosition);
    if (currentIndex == null) return;

    final rangeStart = min(_dragAnchorIndex!, currentIndex);
    final rangeEnd = max(_dragAnchorIndex!, currentIndex);
    final dragRangeIndices = Set<int>.from(
      List.generate(
        rangeEnd - rangeStart + 1,
        (i) => rangeStart + i,
      ).where((i) => !widget.disabledIndices.contains(i)),
    );

    final newSelection = Set<int>.from(_preDragSelection)
      ..addAll(dragRangeIndices);

    if (!setEquals(newSelection, _selectedIndices)) {
      if (newSelection.length != _selectedIndices.length) {
        HapticFeedback.selectionClick();
      }

      setState(() {
        _selectedIndices = newSelection;
      });
      widget.onSelectionChanged(_selectedIndices);
    }

    _handleAutoScroll(globalPosition);
  }

  void _onDragEnd() {
    _dragAnchorIndex = null;
    _preDragSelection = {};
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
      final proximity = 1.0 - (localY / _autoScrollEdgeZone).clamp(0.0, 1.0);
      scrollDelta = -_autoScrollSpeed * proximity;
    } else if (localY > height - _autoScrollEdgeZone) {
      final proximity =
          1.0 - ((height - localY) / _autoScrollEdgeZone).clamp(0.0, 1.0);
      scrollDelta = _autoScrollSpeed * proximity;
    }

    if (scrollDelta != 0) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!_scrollController.hasClients) return;
        final newOffset = (_scrollController.offset + scrollDelta).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(newOffset);
      });
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  GlobalKey _keyForIndex(int index) {
    return _itemKeys.putIfAbsent(index, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    // Clean up keys for indices that no longer exist.
    _itemKeys.removeWhere((key, _) => key >= widget.items.length);

    return GridView.builder(
      controller: widget.shrinkWrap ? null : _scrollController,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      gridDelegate: widget.gridDelegate,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          key: _keyForIndex(index),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(index);
            } else {
              widget.onItemTap?.call(index);
            }
          },
          // All three are null outside selection mode so no long-press
          // recognizer is registered at all, leaving the gesture free for
          // whatever the item itself wants to do with it.
          onLongPressStart: _isSelectionMode
              ? (_) => _beginRangeDrag(index)
              : null,
          onLongPressMoveUpdate: _isSelectionMode
              ? (details) => _onDragUpdate(details.globalPosition)
              : null,
          onLongPressEnd: _isSelectionMode ? (_) => _onDragEnd() : null,
          child: widget.itemBuilder(context, widget.items[index], isSelected),
        );
      },
    );
  }
}
